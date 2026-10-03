# Shared guest-group retention operation

Guest-group access expires after 90 days without an authorized request. The
cleanup command removes expired groups and their memberships, invitations,
entries, and entry revisions. It does not delete account identities, rate-limit
records, organisation data, private Interact sessions, or copies already
exported by members.

## Review and execution

No cleanup schedule is configured. The command must be reviewed with the
environment owner before use. From `backend/`, with the intended `DATABASE_URL`
and the normal application settings loaded:

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

## Scheduler review

Do not enable a scheduler as part of this change. Before proposing one, the
service owner must approve cadence, batch size, dry-run monitoring, apply
authorization, alerting on transaction failures, output retention, backup
recovery, and the least-privilege execution identity. App Check and Firebase
settings are unrelated and must not be changed for this operation.
