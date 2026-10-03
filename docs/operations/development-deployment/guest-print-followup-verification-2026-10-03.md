# Guest and printable report follow-up verification — 2026-10-03

This supersedes the current validation status in earlier same-day review checkpoints; earlier records remain snapshots of the commits tested.

## Guest PR11 — 82cda63237e15e8d3bce0f2f1e8ddc8ae638d036

- Pub get passed. Analyzer has zero errors/warnings; exit1 for six pre-existing null-aware style infos. Async guest context findings are resolved.
- Release web build passed (`--release --no-wasm-dry-run`).
- Full submitted Flutter suite: 48 pass, three failures. Guest startup, template edited content/snapshot/controller lifetime, depth8 width and branch collapse tests now pass.
- Depth12 at360 fails with No element while scrolling. Diagnostic changing only maxScrolls40->100 passes; all original editor width/path/content assertions retained. Original source restored.
- Export/History pending-dismissal tests initially fail because fake User lacks uid. Diagnostic supplying only a synthetic uid removes that exception but both tests still fail: one AlertDialog remains after dismissal and completing pending operation (line113). Original fixture restored. This requires further race investigation; do not mark dismissal behavior accepted.
- Guest worktree clean after restoring diagnostics. No application edits committed/pushed.

Logs in `/home/vscode/.local/share/intqaflow/`: guest-82cda63-{pub,analyze,test,build}.log, guest-82cda63-dialog-fixture-check.log, guest-82cda63-deep-scroll-check.log.

## Printable PR12 — 27dfa7998408cf53252078ec8676b51597edf7af

- Source fix imports dart:js_interop and passes documentHtml.toJS to document.write.
- Tested with corrected PR8 head24862283e8d0d3cd5e2748faafb55637934c537e merged only in detached local review worktree, uncommitted/unpushed. Merge clean.
- Pub get and four focused report tests pass. Analyzer zero errors/warnings with six pre-existing style infos. Release web build passes (--release --no-wasm-dry-run).
- PR12 still needs corrected base incorporated; this is an integration result, not a clean old-parent build result.
- Actual browser print/PDF pagination remains unverified: earlier Codespace preview URL blocked ERR_BLOCKED_BY_CLIENT. No browser runtimes installed; synthetic HTTP server stopped.

Logs use print-27dfa79-{pub,analyze,focused,build}.log in the same private log directory.

## Remaining acceptance

Live multi-identity guest approval, cross-group/org/private denial, linking/recovery, device cache/account transitions and deployed report/PDF acceptance remain pending. Existing hosted Cloud SQL migration0011, runtime CRUD and real Firebase anonymous token verification results remain separate. No guest or printable app merge/deployment was performed. Copilot received both follow-up findings. All activity stays in development.
