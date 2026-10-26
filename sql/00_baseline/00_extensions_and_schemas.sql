-- =========================================================
-- 00. EXTENSÕES E SCHEMAS BASE
-- =========================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS timescaledb;

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
