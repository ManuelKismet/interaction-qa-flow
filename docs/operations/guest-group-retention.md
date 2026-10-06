# Shared guest-group retention operation

Guest-group access expires after 90 days without an authorized request in the
application service. Expiry does not itself delete data. When explicitly run in
apply mode, the cleanup command removes expired groups and their memberships,
invitations, entries, and entry revisions. It does not delete account identities,
rate-limit records, organisation data, private Interact sessions, or copies
already exported by members. No automatic deletion schedule is configured in the
repository; hosted scheduler configuration has not been verified. Expired data
is deleted only by a reviewed apply-mode run in this repository.

This is group-access retention, not a universal account or local-work retention
period. Solo guest drafts on web are stored in origin-scoped browser
`localStorage` at `intqaflow.guest.workspace.v1`; the app sets no expiry and
does not clear them on sign-in or account creation. The browser may evict data;
users can also clear the local copy or browser/site data. Same-origin tabs share
that browser storage and auth context; tabs are not separate guest profiles.
The current non-web storage implementation is process-memory only. Firebase
identity persistence is managed by the Firebase SDK; this app does not set an
identity-expiry policy, and actual hosted/device persistence has not been
independently verified. Firebase anonymous-account cleanup/project retention
configuration is also unverified. The backend stores only explicitly shared
group content, not private solo drafts. Introducing backend draft storage would
require a separate design for identity binding, access control, expiry, and
cleanup.

Invitations are individually time-limited (24 hours by default; API limits are
one hour to seven days) and revoked/expired invitations cannot be redeemed.
The default lifetime is not a guarantee of automatic deletion of the invitation
row or its group.

## Review and execution

No cleanup schedule is configured in this repository; hosted scheduler state is
unverified. The command must be reviewed with the environment owner before use.
From `backend/`, with the intended `DATABASE_URL` and the normal application
settings loaded:

```sh
python -m app.maintenance.guest_retention --batch-size 100
python -m app.maintenance.guest_retention --batch-size 100 --apply
```

The first command is a dry run and is the default. Output contains aggregate
counts only; it does not print group identifiers, names, invitation tokens, or
content. Each invocation inspects at most 100 groups; `--batch-size` accepts
1–500. Repeat dry runs to review the backlog, then obtain explicit approval
before using `--apply`. Apply mode rechecks expiry while holding a row lock and
deletes each group's dependent rows in one transaction. A failed group
transaction rolls back and can be retried; previously committed groups are
idempotently absent on retry. Requests that renew a group's expiry take the
same group-row lock, so a concurrent renewal is ordered against deletion.

## Backup, recovery, and permissions

Before the first apply run, verify a recent recoverable database backup and
document the restore/PITR procedure and recovery owner. For an accidental
deletion, restore the affected database state using the approved recovery
procedure; downloaded/exported copies are outside server control. Start with a
small batch and compare the aggregate dry-run and apply reports.

The command needs database connectivity and `SELECT`/`DELETE` on
`guest_groups`, `guest_group_memberships`, `guest_group_invitations`,
`guest_group_entries`, and `guest_group_entry_revisions`. It does not require
schema creation, migration, or access to organisation/private-session tables.
Use the existing restricted runtime identity only after the database owner
confirms its grants; do not broaden IAM or database privileges for this task.

## Account identity continuity

Shared-group membership and administrator roles are keyed to the Firebase UID.
Creating an account from the current guest identity links credentials to that
same UID; signing into or creating a separate identity does not transfer group
membership or local browser work. Registered identities without an organisation
can still use their local workspace and any groups already linked to their UID.
Organisation membership and roles are independent of shared-group membership.

Administration transfer is recipient-accepted. An active group admin may request
transfer to an active member; the request expires after seven days. The requester
remains an admin until that exact recipient accepts. Acceptance changes both
roles in one transaction: the recipient becomes admin and the requester becomes
contributor. Decline, cancellation, and expiry do not change roles. The group
row is locked before membership/transfer rows are rechecked and updated, so
acceptance serializes against other lifecycle mutations.

An active admin can archive a group as a recoverable closure. Archiving blocks
normal group and invitation operations, revokes outstanding invitations, cancels
pending transfer requests, and retains members, entries, and revisions. Only the
same Firebase UID recorded as the archiving admin, while still an active admin,
can restore it within 30 days. A different account, including a new account
created after archiving, does not inherit recovery rights. Restore reopens the
group for 90 days of access and does not revive invitations or change membership
statuses: pending and removed members do not regain access automatically.

After 30 days, the archived data remains stored unless its recorded archiving
administrator still has an active administrator membership and explicitly
deletes the group. This permanent deletion is available before and after the
restore window; the 30-day window limits restoration, not deletion. The operation
removes group memberships, invitations, transfers, entries, and revisions in one
transaction. It does not delete account identities, rate-limit records,
organisation data, private Interact sessions, or copies already exported or
saved locally by members. A failed transaction rolls back all group cleanup.
Archived groups remain excluded from the existing expiry cleanup, including when
their 90-day group expiry passes; no scheduled deletion is configured.
The API locks the archived group row before rechecking the recorded archiver's
active administrator membership, serializing permanent deletion against restore.
Archived listings expose server-derived `can_delete` separately from the
30-day-window `can_restore` value.

The Shared groups UI explains the member impact, irreversibility, and retained
local/exported copies before permanent deletion. It also explains the member
impact and same-UID recovery limit before archive and account departure. A
sole-admin identity may leave only after another active member accepts a transfer
or the group is archived. No group data is automatically migrated, imported, or
deleted by account creation or sign-in.

## Scheduler review

Do not enable a scheduler as part of this change. Before proposing one, the
service owner must approve cadence, batch size, dry-run monitoring, apply
authorization, alerting on transaction failures, output retention, backup
recovery, and the least-privilege execution identity. App Check and Firebase
settings are unrelated and must not be changed for this operation.
