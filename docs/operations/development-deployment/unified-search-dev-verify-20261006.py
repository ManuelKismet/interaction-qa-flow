"""Read-only exact bundle/runtime checks after DEV publication."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen
ROOT = Path("/home/vscode/.local/share/intqaflow")
BUILD = Path("/workspaces/intqaflow-unified-search-dev-20261006/apps/flutter_app/build/web")
SHA = "105a528f19b2383545b5cfae17197439ce065279"
ORIGINS = ("https://intqaflow-dev.web.app", "https://intqaflow-dev.firebaseapp.com")
API = "https://intqaflow-dev-api-bycdjb22qq-nw.a.run.app"
def main():
    receipt = {"source": SHA, "origins": {}}
    for origin in ORIGINS:
        hashes = {}
        for filename in ("index.html", "flutter_bootstrap.js", "main.dart.js"):
            expected = (BUILD / filename).read_bytes()
            request = Request(origin + "/" + filename + "?review=" + SHA,
                              headers={"Cache-Control": "no-cache"})
            with urlopen(request, timeout=90) as response:
                assert response.status == 200
                actual = response.read()
            assert actual == expected, "Published bundle differs from tested source"
            hashes[filename] = {"sha256": hashlib.sha256(actual).hexdigest(), "bytes": len(actual)}
        receipt["origins"][origin] = hashes
    for path in ("/health", "/ready"):
        with urlopen(API + path, timeout=30) as response:
            assert response.status == 200
            if path == "/ready":
                assert json.load(response)["status"] == "ready"
    try:
        urlopen(API + "/api/v1/personal/items/search?query=needle&limit=5", timeout=30)
        raise AssertionError("Unauthenticated private search unexpectedly accepted")
    except HTTPError as exc:
        assert exc.code in (401, 403)
        receipt["unauthenticated_private_search"] = exc.code
    gcloud = str(ROOT / "gcloud/google-cloud-sdk/bin/gcloud")
    revision = json.loads(subprocess.check_output([
        gcloud, "run", "revisions", "describe", "intqaflow-dev-api-review105a528",
        "--project=intqaflow-dev", "--region=europe-west2", "--format=json"
    ], text=True))
    receipt["backend_revision"] = revision["metadata"]["name"]
    receipt["backend_image"] = revision["spec"]["containers"][0]["image"]
    receipt["backend_image_digest"] = revision["status"].get("imageDigest")
    (ROOT / "search-105a528-publication-verified.json").write_text(json.dumps(receipt, indent=2))
    print(json.dumps(receipt, indent=2), flush=True)
    print("DEV_BOTH_HOSTING_EXACT_BYTES_HEALTH_READY_PRIVATE_REJECTION_PASS", flush=True)
if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("DEV_PUBLICATION_GATE_FAILED", type(exc).__name__, flush=True)
        sys.exit(1)
