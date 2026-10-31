# Scheduled engine 4.5: expand, verify, activate

Apply after stages 14–16, using the migration ledger. No historical SQL is edited.
Migration 01 preserves all rows, refuses known-source duplicates, and creates identities
for new writers. Old null-source writers remain compatible during the rollout window.
Migration 02 adds disabled policies and never reactivates an operator-disabled policy.

Before production: inspect duplicate groups, prove replay idempotency on an isolated
database, migrate writers, configure credentials and quotas, then activate one scheduler
per dataset. Intraday requires an explicit ticker universe and fresh timestamped quotes.

Rollback: disable policies, roll back readers/writers, retain additive tables/indexes and
data. No automatic DROP, DELETE, provenance reassignment or data truncation is provided.
Gold uses the latest CVM version per full identity. Historical point-in-time accounting
must additionally constrain captured_at to an as-of instant.
