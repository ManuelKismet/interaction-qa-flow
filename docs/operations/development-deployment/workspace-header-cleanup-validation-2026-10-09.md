# Workspace header cleanup — DEV validation, 2026-10-09

Deployed source: 8704a6d0c17517f0c636b5ae3057faa4d5870860.

Personal workspace uses one information icon containing storage, privacy and search guidance. The combined dialog scrolls on smaller screens. Organisation Interact removes the redundant heading and labels the existing compatibility import as Import session; supported formats and permissions remain unchanged.

Validation: fresh full Flutter suite 392 passed; affected account/import suites 126 passed; DEV release web build passed; analysis zero errors and warnings with 18 existing informational lints; git whitespace check passed. Earlier runs reproduced two obsolete UI assertions, which were updated for the requested presentation while retaining behavioral checks.

Firebase Hosting: HOSTING_RELEASE sites/intqaflow-dev/releases/1791535916149000 FILES 37 VERSION sites/intqaflow-dev/versions/070f7f727569b0c2. Both DEV origins match all four tested release files (eight SHA-256 comparisons). API health 200; backend source and revision remain unchanged from the independently validated 201-test release. No database or production changes.

Update: cloud-browser sign-in now works; the user confirmed the earlier regular-user failure was a credential typo. Live organisation-member, Personal-mode, group and guest acceptance results are recorded in live-workspace-acceptance-2026-10-09.md. Owner and no-organisation account checks remain pending. Codespace is stopped.
