#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/intqaflow
# Environment preparation only: no migrations, synthetic seeds or server startup.
python3 -m venv backend/.venv
backend/.venv/bin/python -m pip install -r backend/requirements.txt
# Use the Flutter revision recorded in the application's committed .metadata.
iq_flutter_revision=ff37bef603469fb030f2b72995ab929ccfc227f0
iq_flutter_release=3.41.4
iq_flutter_root="$HOME/.local/share/intqaflow/flutter"
if [[ ! -d "$iq_flutter_root/.git" ]]; then
  mkdir -p "$iq_flutter_root"
  git -C "$iq_flutter_root" init
  git -C "$iq_flutter_root" remote add origin https://github.com/flutter/flutter.git
  git -C "$iq_flutter_root" fetch --depth 1 origin "$iq_flutter_revision"
  git -C "$iq_flutter_root" checkout --detach FETCH_HEAD
fi
if [[ "$(git -C "$iq_flutter_root" rev-parse HEAD)" != "$iq_flutter_revision" ]]; then
  echo "Unexpected Flutter revision; inspect before rebuilding." >&2
  exit 1
fi
# Preserve the official release tag so Flutter does not report 0.0.0-unknown.
git -C "$iq_flutter_root" fetch --depth 1 origin \
  "refs/tags/$iq_flutter_release:refs/tags/$iq_flutter_release"
if [[ "$(git -C "$iq_flutter_root" rev-parse "$iq_flutter_release^{commit}")" != "$iq_flutter_revision" ]]; then
  echo "Flutter release tag does not match the recorded revision." >&2
  exit 1
fi
export PATH="$iq_flutter_root/bin:$PATH"
flutter --version
flutter precache --web
(cd apps/flutter_app && flutter pub get --enforce-lockfile)
echo "Tooling prepared. Read docs/operations/isolated-development.md before starting services."
