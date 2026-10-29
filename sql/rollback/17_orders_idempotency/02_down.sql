-- Only before any client relies on idempotency. Retain columns/data for rollback safety.
DROP INDEX CONCURRENTLY IF EXISTS core.uq_ordem_idempotency_carteira;
