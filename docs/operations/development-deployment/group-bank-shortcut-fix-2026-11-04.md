# Group Suggestion Bank shortcut correction — 4 November 2026

The Suggestions & practices item was inside a member role-management menu, whose callback handles member mutations. The existing Group-level callback and scoped dialog were correct but had no corresponding Group options item. Move the item to Group options and remove it from member role actions. Reuse the existing account/group-scoped dialog owner and all permission checks.

Validation: 43 focused Flutter tests passed across guest_group_dialog_test.dart, suggestion_bank_navigation_test.dart and suggestion_bank_test.dart. Seven new cases cover four Group roles, round-trip navigation, member menu separation, and anonymous/unverified denial. Flutter analysis has zero errors and warnings (17 informational style hints). The prior backend/schema release is unchanged. Scope is the DEV web frontend; no native build, backend deployment or migration is required.

The exact merged source and subsequent DEV Hosting deployment receipt are recorded in the correction PR. A passing widget test does not claim a physical-device acceptance run.
