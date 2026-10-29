-- Additive preparation only: no order execution endpoint exists yet.
-- Run during a maintenance window. A short lock timeout aborts instead of blocking traffic.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';
ALTER TABLE core.ordem
    ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(64),
    ADD COLUMN IF NOT EXISTS client_order_id UUID;
-- Existing orders keep NULL; new orders receive a client ID without rewriting history.
ALTER TABLE core.ordem ALTER COLUMN client_order_id SET DEFAULT gen_random_uuid();
COMMIT;

-- Execute outside a transaction (including migration wrappers).
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_ordem_idempotency_carteira
    ON core.ordem (id_carteira, idempotency_key)
    WHERE idempotency_key IS NOT NULL;
