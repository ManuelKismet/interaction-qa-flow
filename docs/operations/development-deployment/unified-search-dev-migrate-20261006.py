"""DEV-only additive 0013 -> 0014 rollout gate. Never downgrade hosted DB."""
import asyncio
import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path
from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import create_async_engine

ROOT = Path("/home/vscode/.local/share/intqaflow")
SOURCE = Path("/workspaces/intqaflow-unified-search-dev-20261006/backend")
CANDIDATE = "105a528f19b2383545b5cfae17197439ce065279"
GCLOUD = str(ROOT / "gcloud/google-cloud-sdk/bin/gcloud")
PREFIX = ROOT / "search-105a528"
TABLES = ("questions", "answers", "guest_groups", "guest_group_memberships",
          "guest_group_entries", "personal_workspace_items")
NEW_TABLES = ("personal_workspace_items", "guest_group_entries")
NEW_COLUMNS = ("knowledge_embedding", "embedding_model", "embedding_source_hash")

async def snapshot(url):
    engine = create_async_engine(url)
    try:
        async with engine.connect() as conn:
            revision = (await conn.execute(text("SELECT version_num FROM alembic_version"))).scalar_one()
            counts = {}
            for table in TABLES:
                counts[table] = (await conn.execute(text("SELECT count(*) FROM " + table))).scalar_one()
            return {"revision": revision, "counts": counts}
    finally:
        await engine.dispose()

async def privileges(url, after=False):
    engine = create_async_engine(url)
    try:
        async with engine.connect() as conn:
            for table in NEW_TABLES:
                for privilege in ("SELECT", "INSERT", "UPDATE", "DELETE"):
                    allowed = (await conn.execute(text(
                        "SELECT has_table_privilege(current_user, :table, :privilege)"
                    ), {"table": table, "privilege": privilege})).scalar_one()
                    assert allowed, "Runtime table privileges missing"
                if after:
                    for column in NEW_COLUMNS:
                        for privilege in ("SELECT", "INSERT", "UPDATE"):
                            allowed = (await conn.execute(text(
                                "SELECT has_column_privilege(current_user, :table, :column, :privilege)"
                            ), {"table": table, "column": column, "privilege": privilege})).scalar_one()
                            assert allowed, "Runtime column privileges missing"
                    await conn.execute(text("SELECT " + ", ".join(NEW_COLUMNS) + " FROM " + table + " LIMIT 0"))
            if after:
                extensions = (await conn.execute(text(
                    "SELECT extname FROM pg_extension WHERE extname IN ('vector', 'pg_trgm')"
                ))).scalars().all()
                assert set(extensions) == {"vector", "pg_trgm"}
                indexes = (await conn.execute(text(
                    "SELECT indexname FROM pg_indexes WHERE schemaname='public' AND indexdef LIKE '%gin%'"
                ))).scalars().all()
                assert {"ix_questions_title_trgm", "ix_questions_body_trgm", "ix_answers_body_trgm"}.issubset(indexes), "Trigram indexes missing"
    finally:
        await engine.dispose()

def main():
    assert subprocess.check_output(["git", "-C", str(SOURCE), "rev-parse", "HEAD"], text=True).strip() == CANDIDATE
    assert not subprocess.check_output(["git", "-C", str(SOURCE), "status", "--porcelain"], text=True).strip()
    env = os.environ.copy()
    env["PATH"] = str(Path(GCLOUD).parent) + ":" + env["PATH"]
    runtime = make_url(subprocess.check_output([
        GCLOUD, "secrets", "versions", "access", "latest",
        "--secret=intqaflow-dev-database-url", "--project=intqaflow-dev"
    ], env=env, text=True).strip())
    assert runtime.query["host"] == "/cloudsql/intqaflow-dev:europe-west2:intqaflow-dev-pg"
    assert runtime.database == "intqaflow_dev"
    credentials = json.loads((ROOT / "dev-db-migrator.json").read_text())
    assert credentials["user"] == "intqaflow_migrator"
    local = runtime.set(drivername="postgresql+asyncpg", host="127.0.0.1", port=55439).difference_update_query(["host"])
    migrator = local.set(username=credentials["user"], password=credentials["password"])
    env["DATABASE_URL"] = migrator.render_as_string(hide_password=False)
    with open(str(PREFIX) + "-proxy.log", "w") as log:
        proxy = subprocess.Popen([
            str(ROOT / "bin/cloud-sql-proxy"), "--gcloud-auth",
            "--address=127.0.0.1", "--port=55439",
            "intqaflow-dev:europe-west2:intqaflow-dev-pg"
        ], env=env, stdout=log, stderr=log)
        try:
            for attempt in range(50):
                try:
                    with socket.create_connection(("127.0.0.1", 55439), timeout=.2):
                        break
                except OSError:
                    time.sleep(.2)
            else:
                raise RuntimeError("DEV proxy not ready")
            before = asyncio.run(snapshot(migrator))
            assert before["revision"] == "0013", "Unexpected hosted schema; stop and rereview"
            asyncio.run(privileges(local))
            with open(str(PREFIX) + "-migrate.log", "w") as out:
                subprocess.run([
                    "/workspaces/intqaflow/backend/.venv/bin/python", "-m",
                    "alembic", "upgrade", "0014"
                ], cwd=SOURCE, env=env, stdout=out, stderr=out, check=True)
            after = asyncio.run(snapshot(migrator))
            assert after["revision"] == "0014"
            assert before["counts"] == after["counts"], "Existing data counts changed"
            asyncio.run(privileges(local, after=True))
            Path(str(PREFIX) + "-migration-result.json").write_text(json.dumps({
                "candidate": CANDIDATE, "before": before, "after": after,
                "runtime_crud_and_columns": "pass", "extensions_and_indexes": "pass"
            }, indent=2))
            print("DEV_ADDITIVE_0013_TO_0014_DATA_COUNTS_RUNTIME_PRIVILEGES_PASS", flush=True)
        finally:
            proxy.terminate()
            proxy.wait(timeout=10)

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("DEV_MIGRATION_GATE_FAILED", type(exc).__name__, flush=True)
        sys.exit(1)
