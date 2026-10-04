import subprocess
import sys
from pathlib import Path


def test_provision_organisation_admin_help_starts_without_provisioning() -> None:
    backend_root = Path(__file__).resolve().parents[1]
    result = subprocess.run(
        [sys.executable, "-m", "scripts.provision_organisation_admin", "--help"],
        cwd=backend_root,
        capture_output=True,
        check=True,
        text=True,
        timeout=30,
    )

    assert "Provision an organisation and its first verified admin." in result.stdout
    assert "--admin-email" in result.stdout
    assert "--confirm-operator-provisioning" in result.stdout
