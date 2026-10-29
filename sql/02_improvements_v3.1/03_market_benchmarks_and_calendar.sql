-- =========================================================
-- 2. MARKET: Novas tabelas
-- =========================================================

-- 2.1 Benchmarks (CDI, IPCA, IBOV, etc.)
CREATE TABLE market.benchmark (
    id_benchmark SERIAL PRIMARY KEY,
    codigo       VARCHAR(20) UNIQUE NOT NULL,
    nome         VARCHAR(100) NOT NULL,
    tipo         VARCHAR(30) CHECK (tipo IN ('INDICE','TAXA','MOEDA','INFLACAO','COMMODITY')),
    moeda        VARCHAR(3) DEFAULT 'BRL',
    frequencia   VARCHAR(20) CHECK (frequencia IN ('DIARIA','MENSAL','ANUAL')),
    fonte        VARCHAR(50),
    ativo        BOOLEAN DEFAULT TRUE
);

CREATE TABLE market.benchmark_serie (
    id_benchmark     INT NOT NULL REFERENCES market.benchmark(id_benchmark) ON DELETE CASCADE,
    data_referencia  DATE NOT NULL,
    valor            NUMERIC(18,8) NOT NULL,
    valor_normalizado NUMERIC(18,8),
    PRIMARY KEY (id_benchmark, data_referencia)
);
SELECT create_hypertable('market.benchmark_serie','data_referencia', chunk_time_interval => INTERVAL '5 years');
CREATE INDEX idx_bench_serie ON market.benchmark_serie(id_benchmark, data_referencia DESC);
















                                                           ;

-- 2.2 Calendário de Negociação (feriados B3)
CREATE TABLE market.calendario_negociacao (
    data        DATE NOT NULL,
    id_bolsa    INT NOT NULL REFERENCES core.bolsa(id_bolsa) ON DELETE CASCADE,
    tipo        VARCHAR(30) NOT NULL
        CHECK (tipo IN ('PREGAO_NORMAL','FERIADO','MEIO_EXPEDIENTE','SEM_NEGOCIACAO','PONTO_FACULTATIVO')),
    descricao   VARCHAR(150),
    PRIMARY KEY (data, id_bolsa)
);

-- Calendário de negociação; os registros serão fornecidos por fonte oficial fora das migrações DDL.







                                                                      ;
