-- =========================================================
-- 0. EXTENSÕES E SCHEMAS
-- =========================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE SCHEMA IF NOT EXISTS core;          -- Cadastros, transacional, custódia
CREATE SCHEMA IF NOT EXISTS market;        -- Cotações, eventos, proventos, macro
CREATE SCHEMA IF NOT EXISTS asset_details; -- Extensões 1:1 por classe de ativo
CREATE SCHEMA IF NOT EXISTS analytics;     -- Fundamentos, técnico, screener, research
CREATE SCHEMA IF NOT EXISTS wealth;        -- Open Finance, IR, patrimônio
CREATE SCHEMA IF NOT EXISTS social;        -- Comunidade, educação, gamificação
CREATE SCHEMA IF NOT EXISTS dw;            -- Agregações históricas (Data Warehouse)
CREATE SCHEMA IF NOT EXISTS system;        -- Planos, segurança, LGPD, auditoria

-- Tipos enumerados (integridade + performance)
CREATE TYPE core.tipo_ativo_enum AS ENUM
    ('ACAO','FII','FIAGRO','ETF','BDR','OPCAO','FUTURO','TESOURO','RENDA_FIXA','FUNDO','CRIPTO','MOEDA');
CREATE TYPE core.tipo_mercado_enum AS ENUM
    ('A_VISTA','FRACIONARIO','OPCAO','FUTURO','TERMO','BALCAO');
CREATE TYPE core.tipo_operacao_enum AS ENUM ('C','V');
CREATE TYPE market.tipo_provento_enum AS ENUM ('DIVIDENDO','JCP','RENDIMENTO','BONIFICACAO','SUBSCRICAO');
CREATE TYPE wealth.tipo_ir_enum AS ENUM ('DAY_TRADE','SWING_TRADE','FII','RENDA_FIXA','EXTERIOR');
