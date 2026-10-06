from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory


def test_unified_search_migration_follows_personal_workspace_revision() -> None:
    backend_root = Path(__file__).resolve().parents[1]
    config = Config(str(backend_root / "alembic.ini"))
    config.set_main_option("script_location", str(backend_root / "alembic"))
    scripts = ScriptDirectory.from_config(config)

    personal_workspace = scripts.get_revision("0013")
    unified_search = scripts.get_revision("0014")

    assert personal_workspace is not None
    assert unified_search is not None
    assert personal_workspace.down_revision == "0012"
    assert unified_search.down_revision == "0013"
    assert scripts.get_heads() == ["0014"]
