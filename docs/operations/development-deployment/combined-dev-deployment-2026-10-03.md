# Combined guest/report/retention development deployment — 3 October 2026

Founder requested confirmation of Copilot completion, verification and moving on under the agreed development-only workflow. No production merge or release.

## Exact source confirmation

Submitted PR12 head df6bcd3026295e9f492d140282376c927bb66844 was fetched in Codespace. Its entire repository tree equals independently tested local c28d694b5b34f128a0bc445e6932cb013170c894: tree2576fea24ef30ecbe2e8cba27572e861e9e739a4, git diff --exit-code zero. Both report printing APIs and retention delta are retained. Existing independent evidence applies to this identical source tree:75 backend tests,56 Flutter tests, configured release build pass, analyzer six existing infos and zero errors/warnings.

## Development deployment

Backend Docker context contained only reviewed app source, requirements and non-root Dockerfile, with secret-excluding dockerignore. Cloud Build580f287d-a71f-4058-8a3a-d87d3ada1a3f SUCCESS. Image:
europe-west2-docker.pkg.dev/intqaflow-dev/cloud-run-source-deploy/intqaflow-dev-api@sha256:2af1bbe9861d83313ff1f6b00bdf836ad52cf84f4f787c75019d7c784a9be966.

Created revision intqaflow-dev-api-guestdf6bcd3 with zero traffic, then routed100% development traffic to it. Readback confirms latestReadyRevision and100% traffic. Runtime service identity, environment (including database secret binding/App Check observe/fake embeddings), and resources compare equal to the previous configuration. No IAM/access change or migration.

Live API smoke: /health200; /api/v1/auth/me401 without credentials; /api/v1/guest/groups401 without credentials. URL https://intqaflow-dev-api-bycdjb22qq-nw.a.run.app.

Published the independently built Flutter artifact using explicit intqaflow-dev Hosting helper:
- release sites/intqaflow-dev/releases/1791028423122000
- version sites/intqaflow-dev/versions/d6f1722e1d603e67
-35 files
- public https://intqaflow-dev.web.app/ main.dart.js, flutter_bootstrap.js and index.html all return200 and SHA256-match tested build bytes.
Browser opened the deployed URL and visibly rendered IntQAFlow guest workspace, Knowledge and Interact controls, browser-local storage notice and enabled sharing/sign-in controls. Browser CPU-rendering fallback warning observed; no application startup error was observed in the inspected console sample. This is startup smoke only.

## Rollback and remaining acceptance

Previous API revision intqaflow-dev-api-00003-2bz and image digest55402b0c7b726c8960deedeb43ee222d1f368204782d3299cdde7a8f3377fdca saved before deployment. Previous Hosting release sites/intqaflow-dev/releases/1790975158224000 / version sites/intqaflow-dev/versions/3fa7c27eb9520559 recorded. Rollback can route dev API traffic to that prior revision and release that prior Hosting version if acceptance fails; no rollback executed.

Hosted database remains0011. No cleanup deletion/apply, schedule, IAM/Firebase/App Check changes, production changes or merge performed. Retention command is present but unscheduled and dry-run-first. Browser account linking/conflicts, identity/cache transitions, complete cross-group/organisation matrix and rendered PDF pagination acceptance remain pending. Published build/startup are not those acceptance tests.

Sanitized deployment logs and receipts: /home/vscode/.local/share/intqaflow/deploy-df6bcd3-{build,run,hosting}.log; api-smoke.json, web-smoke.json, hosting-before.json.
