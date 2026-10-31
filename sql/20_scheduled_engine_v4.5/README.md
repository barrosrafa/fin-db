# Scheduled engine schema (DDL only)

This stage contains only the additive schema and filtered task reservation function.
It preserves legacy financial statements and null-source intraday rows; known-source
duplicates cause a failure rather than automatic deletion. No catalogs, policies or
market data are populated. Operational policies and deployment belong to fin-ingestion.

The existing deployed engine ledger retains its historical `17_scheduled_engine_v4.5`
identifiers and checksums. These DDL definitions are also safe on that expanded schema.
Do not rewrite or delete the historical engine ledger to renumber an existing database.

Rollback is expand-only: disable the producer/reader, retain the additive data and schema.
No destructive contraction is run automatically.
