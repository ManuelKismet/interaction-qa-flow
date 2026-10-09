# Unified Knowledge and Interact search

Guest search stays on the current device. Personal and Organisation search use the same sources: device-local Knowledge and Interact, the verified user's private account, active accessible Groups, and their active Organisation. Every remote result remains subject to the existing source permissions. An organisation membership is not required to search private account or Group content.

Interact matches current session titles, question text, answers and recursive follow-ups, including collapsed branches. Deleted questions and their orphaned descendants are excluded. Opening a result focuses its matched question and participant; Show all questions returns to the full session. Search does not expand saved branches, publish session content into Knowledge, or upload device-local content.

The All / Knowledge / Interact filter and source labels distinguish session work from Knowledge. Knowledge is listed first. Department, team and session visibility labels appear where available. Remote limits and source failures are disclosed, and retry retains successful results within the same account and organisation scope.

Private Interact uses the verified Firebase UID; Group Interact requires active membership in a live, unarchived Group. Organisation Interact reuses Guided session visibility for creators, organisation, department and team access. Database user IDs are distinct from Firebase UIDs: membership provenance records the authenticated Firebase identity instead of comparing those different identifiers.

## API

- GET /api/v1/personal/interact/search: verified registered identity, private account and authorised Group copies.
- GET /api/v1/guided/sessions/search: authenticated tenant membership, visible organisation sessions.

Both accept query (2–100 characters) and limit (1–50, default 25). Results contain source, destination, session_id, optional question_id and participant_id, snippet, relevance_score and available scope labels. partial reports truncation. Interact search is read-only keyword retrieval; it is not added to the shared Knowledge embedding index.

Frontend and backend must be deployed together for the new endpoints. This feature is not deployed by the implementation commit.
