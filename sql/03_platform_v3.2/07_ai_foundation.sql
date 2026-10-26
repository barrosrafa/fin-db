-- =========================================================
-- BLOCO 7: IA / ML (Fase Futura)
-- =========================================================

-- 7.1 Recomendações personalizadas
CREATE TABLE analytics.recomendacao (
    id_recomendacao BIGSERIAL,
    id_usuario      UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_ativo        INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    score           NUMERIC(6,4),
    motivo          VARCHAR(30) CHECK (motivo IN ('COLLABORATIVE','CONTENT_BASED','HYBRID','TRENDING')),
    data_geracao    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    clique          BOOLEAN DEFAULT FALSE,
    feedback        INT CHECK (feedback BETWEEN -1 AND 1)
);
SELECT create_hypertable('analytics.recomendacao','data_geracao', chunk_time_interval => INTERVAL '3 months');
CREATE INDEX idx_recomend_user ON analytics.recomendacao(id_usuario, data_geracao DESC);

-- 7.2 Modelos ML registrados
CREATE TABLE analytics.modelo_ml (
    id_modelo      SERIAL PRIMARY KEY,
    nome           VARCHAR(80) NOT NULL,
    versao         VARCHAR(20) NOT NULL,
    tipo           VARCHAR(30),
    data_treino    TIMESTAMPTZ,
    metricas_json  JSONB,
    ativo          BOOLEAN DEFAULT FALSE,
    UNIQUE (nome, versao)
);

-- 7.3 Embeddings (requer extensão pgvector)
-- CREATE EXTENSION IF NOT EXISTS vector;
-- CREATE TABLE analytics.embedding_ativo (
--     id_ativo    INT PRIMARY KEY REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
--     modelo      VARCHAR(50) NOT NULL,
--     vetor       vector(768),
--     data_geracao TIMESTAMPTZ DEFAULT NOW()
-- );
-- CREATE INDEX idx_emb_ativo ON analytics.embedding_ativo USING ivfflat (vetor vector_cosine_ops);
