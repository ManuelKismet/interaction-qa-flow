# Responsive workspace layout

Guest, Personal, Group and Organisation share an adaptive theme through all application entry points. Widths are logical pixels. Desktop styling is retained at 600 pixels and wider; the navigation rail still begins at 760 pixels.

| Width | Workspace outer padding | Headline | Large title | Primary body |
| --- | --- | --- | --- | --- |
| Below 380 | 12 | 26 | 18 | 15 |
| 380–599 | 16 | 28 | 20 | 15 |
| 600 and wider | Existing page-specific 16/24/32 | 34 | 22 | 16 |

Phone field padding is 12/14 horizontally and 14 vertically. Shared button labels are 14 pixels with reduced horizontal padding and a minimum 48-pixel height; default icons are 20 pixels. Existing control-specific styles remain in force. Outer page padding adapts independently of inner card padding. Organisation request fields fit within phone width, and permission/member dropdowns expand inside their parent instead of imposing an intrinsic width.

Organisation account/workspace toolbar actions use icons below 600 pixels. Bottom navigation is 64 pixels high at default text size and grows with system text scaling. Below 380 pixels it labels the selected destination; destination semantics and tooltips are retained. Application code never replaces or caps TextScaler. Scroll views, wrapping controls and existing keyboard-aware editors handle reflow; the entire screen is not scaled as an image.

## Organisation permission assignment coverage

An owner opens **My organisation → Owner administration**, chooses an active member, selects a permission and scope, then **Grant permission**. Existing grants can be revoked in that section. The API validates membership and scope identifiers against the organisation.

| Explicit delegated permission | Organisation | Department | Team |
| --- | --- | --- | --- |
| Create Teams (team_create) | Yes | Yes | No |
| Manage Team membership (team_membership) | Yes | Yes | Yes |
| Review (review) | Yes | Yes | Yes |
| Approve answers (answer_approval) | Yes | Yes | Yes |

These four values cover the current grant API. They do not individually delegate every owner-only administration operation. **Appoint owner** is separate and grants owner authority; **Appoint admin** sets a title without automatically granting permissions. This UI does not mint legacy administrator grants. Department answer-owner assignments and ordinary department/team membership are separate controls. This responsive change does not modify permissions, grant access or alter backend enforcement.

## Search identity

The preceding unified Interact search implementation distinguishes the organisation database user ID from the Firebase UID. Active membership records Firebase provenance and compares it to the authenticated Firebase identity; database IDs remain database IDs. See [unified search](unified-search.md). Hosted acceptance requires a later verified frontend/backend deployment.
