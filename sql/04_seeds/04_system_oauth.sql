-- =========================================================
-- SEED: system.oauth_provider
-- =========================================================

INSERT INTO system.oauth_provider (nome, ativo) VALUES
    ('GOOGLE', FALSE),
    ('APPLE', FALSE),
    ('FACEBOOK', FALSE),
    ('GITHUB', FALSE)
ON CONFLICT (nome) DO NOTHING;
