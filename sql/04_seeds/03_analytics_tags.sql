-- =========================================================
-- SEED: analytics.tag
-- =========================================================

INSERT INTO analytics.tag (nome, tipo) VALUES
    ('Dividendos','ESTRATEGIA'),
    ('Value','ESTRATEGIA'),
    ('Growth','ESTRATEGIA'),
    ('Small Caps','PERFIL'),
    ('Blue Chips','PERFIL'),
    ('ESG','TEMA'),
    ('Turnaround','TEMA'),
    ('Papel','SETOR'),
    ('Logística','SETOR'),
    ('Shopping','SETOR'),
    ('Híbrido','SETOR'),
    ('Fiagro','SETOR')
ON CONFLICT (nome) DO NOTHING;
