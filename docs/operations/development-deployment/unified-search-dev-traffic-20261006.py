"""Guarded DEV zero-traffic verification and traffic switch for exact105a528."""
import copy
import json
import subprocess
import sys
from pathlib import Path
from urllib.request import urlopen

ROOT = Path("/home/vscode/.local/share/intqaflow")
GCLOUD = str(ROOT / "gcloud/google-cloud-sdk/bin/gcloud")
FLAGS = ["--project=intqaflow-dev", "--region=europe-west2"]
SOURCE = "/workspaces/intqaflow-unified-search-dev-20261006"
SHA = "105a528f19b2383545b5cfae17197439ce065279"
OLD = "intqaflow-dev-api-reviewaafc112"
NEW = "intqaflow-dev-api-review105a528"
TAG = "search105a528"
API = "https://intqaflow-dev-api-bycdjb22qq-nw.a.run.app"
def run(args):
    return subprocess.check_output([GCLOUD, "run"] + args + FLAGS, text=True)
def revision(name):
    return json.loads(run(["revisions", "describe", name, "--format=json"]))
def health(base):
    for path in ("/health", "/ready"):
        with urlopen(base + path, timeout=30) as response:
            assert response.status == 200
            result = json.load(response)
            if path == "/ready":
                assert result["status"] == "ready"
def preflight():
    assert subprocess.check_output(["git", "-C", SOURCE, "rev-parse", "HEAD"], text=True).strip() == SHA
    assert not subprocess.check_output(["git", "-C", SOURCE, "status", "--porcelain"], text=True).strip()
    old, new = revision(OLD), revision(NEW)
    assert any(c.get("type") == "Ready" and c.get("status") == "True" for c in new["status"]["conditions"])
    specs = [copy.deepcopy(r["spec"]) for r in (old, new)]
    for spec in specs:
        for container in spec["containers"]:
            container.pop("image", None)
    assert specs[0] == specs[1], "Runtime spec differs beyond image"
    for key in ("run.googleapis.com/cloudsql-instances", "run.googleapis.com/vpc-access-connector",
                "run.googleapis.com/vpc-access-egress", "run.googleapis.com/execution-environment",
                "run.googleapis.com/cpu-throttling"):
        assert old["metadata"].get("annotations", {}).get(key) == new["metadata"].get("annotations", {}).get(key)
    service = json.loads(run(["services", "describe", "intqaflow-dev-api", "--format=json"]))
    assert sum(t.get("percent", 0) for t in service["status"]["traffic"] if t.get("revisionName") == OLD) == 100
    assert sum(t.get("percent", 0) for t in service["status"]["traffic"] if t.get("revisionName") == NEW) == 0
    baseline = json.loads((ROOT / "search-105a528-service-before.json").read_text())
    for key in ("run.googleapis.com/ingress", "run.googleapis.com/invoker-iam-disabled"):
        assert service["metadata"].get("annotations", {}).get(key) == baseline["metadata"].get("annotations", {}).get(key)
    run(["services", "update-traffic", "intqaflow-dev-api", "--update-tags=" + TAG + "=" + NEW, "--quiet"])
    service = json.loads(run(["services", "describe", "intqaflow-dev-api", "--format=json"]))
    url = next(t["url"] for t in service["status"]["traffic"] if t.get("tag") == TAG)
    health(url)
    (ROOT / "search-105a528-stage-verified.json").write_text(json.dumps({
        "source": SHA, "revision": NEW, "zero_traffic": True,
        "runtime_preserved": True, "stage_health_ready": 200, "stage_url": url
    }, indent=2))
    print("DEV_ZERO_TRAFFIC_RUNTIME_PRESERVED_HEALTH_READY_200", flush=True)
def main():
    mode = sys.argv[1]
    assert mode in ("preflight", "switch")
    preflight()
    if mode == "switch":
        receipt = json.loads((ROOT / "search-105a528-migration-result.json").read_text())
        assert receipt["candidate"] == SHA and receipt["after"]["revision"] == "0014"
        assert receipt["before"]["counts"] == receipt["after"]["counts"]
        run(["services", "update-traffic", "intqaflow-dev-api", "--to-revisions=" + NEW + "=100", "--quiet"])
        try:
            health(API)
            service = json.loads(run(["services", "describe", "intqaflow-dev-api", "--format=json"]))
            assert sum(t.get("percent", 0) for t in service["status"]["traffic"] if t.get("revisionName") == NEW) == 100
            (ROOT / "search-105a528-service-after.json").write_text(json.dumps(service))
            print("DEV_TRAFFIC_100_HEALTH_READY_200", flush=True)
        except Exception:
            run(["services", "update-traffic", "intqaflow-dev-api", "--to-revisions=" + OLD + "=100", "--quiet"])
            print("DEV_TRAFFIC_ROLLED_BACK_SCHEMA_RETAINED", flush=True)
            raise
if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("DEV_TRAFFIC_GATE_FAILED", type(exc).__name__, flush=True)
        sys.exit(1)
