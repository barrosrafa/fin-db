-- 07_auth_saas_extensions.sql
-- Additive columns to core.usuario for SaaS external identity and tier management

ALTER TABLE core.usuario ADD COLUMN IF NOT EXISTS id_externo VARCHAR(100);
ALTER TABLE core.usuario ADD COLUMN IF NOT EXISTS role VARCHAR(30) DEFAULT 'user';
ALTER TABLE core.usuario ADD COLUMN IF NOT EXISTS tier VARCHAR(30) DEFAULT 'free';
ALTER TABLE core.usuario ALTER COLUMN cpf_cnpj DROP NOT NULL;
CREATE INDEX IF NOT EXISTS idx_usuario_id_externo ON core.usuario(id_externo);
