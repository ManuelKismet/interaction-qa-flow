# PDF export and sharing — founder clarification, 3 October 2026

Supplement to consolidated-solution-handoff-2026-10-03.md. This supersedes suggestions to expose JSON backups, HTML exports, or plain-text formats in the ordinary user export flow.

## Product decision
Users want a readable PDF for reference and sharing. Offer Download PDF and Share PDF. Do not present JSON or HTML as report/export/backup choices to ordinary users. Internal serialization and HTML used to render/print are implementation details. If technical restore tooling remains necessary, keep it outside the ordinary user flow and document its purpose; do not remove persisted data or break existing storage during this change.

## Current evidence
PR13 at 86ab2b140cbbfe6a599ce595f98e5dec125d2a58 is open and draft. Guest source contains a readable report and printable document implementation, but independent Codespace/browser/rendered PDF acceptance is pending. Registered Interact export still shows selectable export contents with Copy. Guest groups already support explicitly previewing and sharing selected local content; group export also exposes a copy dialog. These are source observations, not new live acceptance passes.

## Implementation
1. Reuse the readable report composition for guest solo, authorized shared-group content and registered Interact. Where Knowledge has export, use the same simple PDF flow. Avoid duplicate report engines.
2. Provide a real PDF file download with a sensible filename and application/pdf type. Browser print/save-as-PDF can remain an explicitly labelled fallback; do not claim a print popup is a completed direct PDF download.
3. Report includes title, creation/export date, participant names and actual recorded attribution, questions, answers and nested follow-ups in a readable hierarchy. Preserve Unicode, wrap long text, provide clear page breaks and avoid clipped content. Show the selected participant or all participants before export; include only the selected authorized scope. Do not invent missing authorship or timestamps.
4. Share PDF invokes device/browser file sharing when supported. Otherwise offer Download PDF and clear guidance to attach that file using the user's preferred app. Handle cancellation without an error. Do not substitute copying JSON/HTML, automatically email anyone, or silently publish a public link.
5. Keep in-app sharing distinct: Share with group/team uses explicit audience selection, preview and existing permissions; Share PDF produces a portable copy. Explain briefly when sharing a copy that recipients can retain/forward it and later membership removal cannot revoke downloaded copies.
6. Enforce current authorized view/export rules server-side on every exported resource. Preserve private owner-only content, individual guest-group boundaries, organization/department/team audiences and author-controlled edits/review/history. Exporting or sharing must not grant edit rights, change ownership or widen access.
7. Keep controls compact and consistent, with adequate spacing and touch targets. No extra format picker or technical terminology.

## Acceptance
Verify actual PDF download and readable rendering in Codespace/browser, guest and registered scopes when identities are available; nested branches, multiple participants, long/empty answers, special characters, attribution and page overflow; unauthorized/private/cross-group export rejection; supported and unsupported file-sharing paths and cancellation. Preserve existing tests and distinguish automated results from fresh manual evidence. Sign-in and independent multi-identity checks remain pending rather than marked passed.

Continue the existing Copilot implementation stream and report exact head/base and verification evidence. No merge, deployment, hosted migration apply/reset, cloud/auth configuration changes, paid providers, purge or scheduler activation. Independent review follows implementation.
