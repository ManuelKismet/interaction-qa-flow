# Development recovery and rollback

This runbook describes the hosted **development** environment only. It is an
operator procedure, not authorization to run a restore or change traffic. No
restore rehearsal is claimed. Production is out of scope.

## Prerequisites and safeguards

- Obtain explicit approval from the development environment owner and name the
  recovery operator and incident/change record.
- Confirm the active project, source instance, region, PostgreSQL version,
  database name, backup retention, and the exact backup ID using non-secret
  metadata. The current recorded development baseline is project
  `intqaflow-dev`, instance `intqaflow-dev-pg`, PostgreSQL 16 in `europe-west2`,
  with seven daily backups and PITR disabled; verify that state before relying
  on it.
- Confirm a recent successful backup and its timestamp. Identify the expected
  recovery point and obtain approval for the data-loss window.
- Have a separately designated, existing recovery Cloud SQL instance with
  compatible PostgreSQL version, region, storage/network policy, and required
  pgvector extension. The restore command overwrites the destination instance.
  Never select the live source as the destination unless an owner explicitly
  approved a destructive in-place restore.
- Ensure the operator is authenticated to the approved Google Cloud project
  with the minimum Cloud SQL permissions. Do not print, paste, or commit
  connection strings, access tokens, or credential files.
- Before moving application traffic to recovered data, validate the recovery
  instance privately, confirm the expected schema/migrations and data, and
  obtain a separate approval for any connection/configuration change.

## Inspect and restore a development backup

Set and verify identifiers explicitly. `BACKUP_ID` must be selected from the
reviewed backup inventory; `RECOVERY_INSTANCE` must be the approved isolated
destination, not the application’s source instance.

```sh
PROJECT=intqaflow-dev
SOURCE_INSTANCE=intqaflow-dev-pg
REGION=europe-west2
RECOVERY_INSTANCE="<approved-existing-recovery-instance>"

gcloud config get-value project
gcloud sql instances describe "$SOURCE_INSTANCE" \
  --project="$PROJECT" \
  --format="yaml(name,region,databaseVersion,settings.backupConfiguration)"
gcloud sql backups list \
  --instance="$SOURCE_INSTANCE" \
  --project="$PROJECT" \
  --sort-by="~endTime" \
  --format="table(id,status,type,startTime,endTime)"
gcloud sql instances describe "$RECOVERY_INSTANCE" \
  --project="$PROJECT" \
  --format="yaml(name,region,databaseVersion)"
```

After reviewing the output and recording the chosen backup ID:

```sh
BACKUP_ID="<reviewed-backup-id>"
gcloud sql backups restore "$BACKUP_ID" \
  --backup-instance="$SOURCE_INSTANCE" \
  --restore-instance="$RECOVERY_INSTANCE" \
  --project="$PROJECT"
```

This procedure does not use point-in-time recovery: PITR is recorded as disabled
for the development database. Restoring a backup replaces the destination
instance’s contents. Stop if the source/destination, backup status, or expected
recovery point is ambiguous. Do not perform a restore as a test or against the
live application instance.

## Roll back an API revision

First identify the service, region, and a known-good revision from the approved
deployment record. Confirm the candidate revision uses the intended compatible
database schema and preserved runtime configuration. Do not guess service names
or modify IAM, environment variables, secrets, App Check, or database settings.

```sh
PROJECT=intqaflow-dev
REGION="<verified-cloud-run-region>"
SERVICE="<verified-cloud-run-service>"

gcloud run revisions list \
  --service="$SERVICE" \
  --region="$REGION" \
  --project="$PROJECT" \
  --format="table(metadata.name,metadata.creationTimestamp)"
```

After recording and reviewing the exact known-good revision:

```sh
PREVIOUS_REVISION="<reviewed-known-good-revision>"
gcloud run services update-traffic "$SERVICE" \
  --to-revisions="$PREVIOUS_REVISION=100" \
  --region="$REGION" \
  --project="$PROJECT"
```

Verify the resulting traffic allocation, service health, and application
readiness before closing the change record. This rolls application traffic
back; it does not roll back database migrations. Never run an Alembic downgrade
or restore the live database as an automatic companion to an application
rollback. If a schema change is incompatible, stop and follow a separately
reviewed database recovery plan.

## Evidence and rehearsal status

Record the project and resource identifiers, selected backup/revision,
approvals, operator, timestamps, health/readiness checks, and outcome without
recording secrets or user data. A successful command or healthy endpoint alone
is not evidence that the recovered application data is complete. A rehearsal
requires separate approval, an isolated destination, a reviewed data-validation
plan, and documented results. No restore, IAM change, or live database action
was performed while adding this runbook.
