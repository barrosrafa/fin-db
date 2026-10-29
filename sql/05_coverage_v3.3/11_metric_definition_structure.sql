-- Campo estrutural para classificar a direção preferível de uma métrica.
-- Nullable e sem default para manter as tabelas vazias e não inventar valores.
ALTER TABLE canonical.metric_definition
    ADD COLUMN IF NOT EXISTS higher_is_better BOOLEAN;
