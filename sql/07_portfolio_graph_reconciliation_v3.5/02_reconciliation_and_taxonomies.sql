-- ==============================================================================
-- Migration: 02_reconciliation_and_taxonomies.sql
-- Description: Multi-source metric reconciliation, divergence taxonomy catalog,
--              snapshot ingestion, and deterministic canonical arbitration.
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS reconciliation;

-- 1. Finite Divergence Taxonomies Catalog
CREATE TABLE IF NOT EXISTS reconciliation.divergence_taxonomies (
    code VARCHAR(64) PRIMARY KEY,
    display_name VARCHAR(128) NOT NULL,
    description TEXT NOT NULL,
    typical_impact_level VARCHAR(16) NOT NULL DEFAULT 'MEDIUM', -- LOW, MEDIUM, HIGH
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Multi-Source Metric Snapshots
CREATE TABLE IF NOT EXISTS reconciliation.metric_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticker VARCHAR(32) NOT NULL,
    source_id VARCHAR(64) NOT NULL, -- STATUS_INVEST, FUNDS_EXPLORER, INVESTIDOR10, CLUBE_FII
    metric_name VARCHAR(64) NOT NULL, -- DY_12M, P_VP, VACANCY_PHYSICAL, CAP_RATE
    raw_value NUMERIC(16,4) NOT NULL,
    as_of_date DATE NOT NULL,
    scraped_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    methodology_notes TEXT,
    CONSTRAINT uq_metric_snapshot UNIQUE (ticker, source_id, metric_name, as_of_date)
);

CREATE INDEX IF NOT EXISTS idx_metric_snapshots_lookup ON reconciliation.metric_snapshots(ticker, metric_name, as_of_date);

-- 3. Identified Metric Divergences
CREATE TABLE IF NOT EXISTS reconciliation.divergences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticker VARCHAR(32) NOT NULL,
    metric_name VARCHAR(64) NOT NULL,
    baseline_source VARCHAR(64) NOT NULL,
    comparison_source VARCHAR(64) NOT NULL,
    baseline_value NUMERIC(16,4) NOT NULL,
    comparison_value NUMERIC(16,4) NOT NULL,
    delta_pct NUMERIC(7,4) NOT NULL,
    taxonomy_code VARCHAR(64) NOT NULL REFERENCES reconciliation.divergence_taxonomies(code),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_divergences_ticker_active ON reconciliation.divergences(ticker, is_active);

-- 4. Canonical Arbitrated Metrics (Interval + Anchor)
CREATE TABLE IF NOT EXISTS reconciliation.canonical_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticker VARCHAR(32) NOT NULL,
    metric_name VARCHAR(64) NOT NULL,
    consensus_min NUMERIC(16,4) NOT NULL,
    consensus_max NUMERIC(16,4) NOT NULL,
    consensus_iqr NUMERIC(16,4) NOT NULL,
    anchor_source VARCHAR(64) NOT NULL,
    anchor_value NUMERIC(16,4) NOT NULL,
    confidence_score NUMERIC(5,2) NOT NULL DEFAULT 100.00,
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    methodology_version VARCHAR(32) NOT NULL DEFAULT 'v1.0.0',
    CONSTRAINT uq_canonical_metric UNIQUE (ticker, metric_name, calculated_at)
);

CREATE INDEX IF NOT EXISTS idx_canonical_metrics_lookup ON reconciliation.canonical_metrics(ticker, metric_name);
