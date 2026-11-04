# Interact deep follow-up layout review — 2026-10-02

Status: inspected in the deployed development app; recommendation only, not implemented.

## Reproduction and finding

Private synthetic session c5fc0611-fb14-4cdf-958b-0765fc223ba0 contains eight consecutive follow-ups for Synthetic layout participant, with long question text. At 1363 × 936 desktop viewport, the deep question narrows to a thin column and wraps nearly one character per line. Earlier two-level scenario also progressively narrows.

Source: apps/flutter_app/lib/features/guided/presentation/guided_session_page.dart. GuidedQuestionNode applies left padding of depth * 24.0 (line 657), then an additional inner 16-pixel padding. Children are recursively rendered inside their parent with depth + 1 (line 755). Therefore depth offsets accumulate, rather than applying one small offset to each sibling row. At depth eight, the depth-dependent portions alone total 864 logical pixels, before inner padding. The report node repeats depth-dependent indentation (line 901), so report layout needs review too.

## Recommended design

1. Render visible question/answer cards in a flat list with a capped absolute indentation. Keep editor width independent of logical depth. Do not merely cap padding on recursively nested parents, which still compounds.
2. Show hierarchy using a compact numbered path, parent-question preview, and a thin connector. Allow selecting an ancestor and returning to the previous branch. Preserve full logical nesting in the data.
3. Provide a focused branch view for deep paths: a wide question and answer editor with breadcrumb navigation. On wide screens, optionally show a collapsible outline beside the editor. On narrow screens, use one full-width editor and a branch navigation sheet.
4. Keep siblings collapsed when helpful, show follow-up counts, and retain participant-specific branches and unsaved edits when navigating or resizing. Never collapse or hide data in exports.
5. Use wrapping action controls or an overflow menu so Add follow-up, Check Knowledge, and delete remain reachable. Do not shrink text to fit.

Start with the flat list and capped indentation as the smallest correction; add the focused branch navigation without changing storage or privacy rules.

## Acceptance checks for implementation

- Long questions and answers at depths 0, 1, 3, 8, and 12 remain readable at 360, 768, and 1366 logical pixel widths; no overflow or single-character columns.
- All actions remain keyboard accessible and labels identify the current participant and parent path.
- Participant switching, sibling branches, collapse/expand, soft delete/undo, autosave, reload, and JSON/CSV/report output retain the same data.
- Resizing or selecting an ancestor preserves the current edit and active participant.
- Private sessions remain owner-only; UI changes do not alter tenant checks.

Official implementation guidance: https://docs.flutter.dev/ui/adaptive-responsive/general (LayoutBuilder measures the available parent constraints) and https://docs.flutter.dev/learn/pathway/tutorial/adaptive-layout (wide-screen sidebar/detail and small-screen navigation). The design choices above are our recommendation for this app.

## Remaining Phase 6 acceptance

Template creation passed in the hosted browser. A new version with revised questions was created through the live API; the original session kept its original template version and two question texts, while a new session used v3 and its one revised question. Immutable snapshot behavior passes. The UI Save as new version action cloned the existing version; editing version contents in the UI was not verified.

All-participant report displays Alice's nested answers and Bob's persisted edit. Print / Save PDF calls window.print(), but no preview or PDF file was observable in the cloud browser after clicking it. PDF output remains unverified; this does not establish an application defect. Separate-account live checks remain pending; participants within one admin session are not independent authenticated users.
