-- Alterações aditivas de estrutura; o executor controla lock/statement timeout e transação.
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';

ALTER TABLE core.ordem
    ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(64),
    ADD COLUMN IF NOT EXISTS client_order_id UUID;

ALTER TABLE core.ordem
    ALTER COLUMN client_order_id SET DEFAULT gen_random_uuid();

CREATE UNIQUE INDEX IF NOT EXISTS uq_ordem_idempotency_carteira
    ON core.ordem (id_carteira, idempotency_key)
    WHERE idempotency_key IS NOT NULL;
