-- ==============================================================================
-- Migration: 01_graph_bitemporal_and_mdm.sql
-- Description: Bitemporal look-through debtor graph, MDM canonical entities,
--              user overrides, and audit trails.
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS graph;
CREATE SCHEMA IF NOT EXISTS canonical;
CREATE SCHEMA IF NOT EXISTS wealth;
CREATE SCHEMA IF NOT EXISTS audit;

-- Coverage category enum for look-through
DO $$ BEGIN
    CREATE TYPE coverage_category_enum AS ENUM (
        'RESOLVED',
        'TEMPORARY_PENDING_CURATION',
        'STRUCTURE_OPAQUE'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Edge relationship types
DO $$ BEGIN
    CREATE TYPE edge_type_enum AS ENUM (
        'HOLDS_SHARE',
        'CREDIT_RECEIVABLE',
        'REAL_ESTATE_TENANT',
        'SUBSIDIARY_OF'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Override types
DO $$ BEGIN
    CREATE TYPE graph_override_type_enum AS ENUM (
        'EXCLUDE_EDGE',
        'REMAP_ENTITY',
        'OVERRIDE_WEIGHT'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 1. Canonical Entities (MDM Root Groups / Debtors)
CREATE TABLE IF NOT EXISTS graph.entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_name VARCHAR(255) NOT NULL,
    entity_type VARCHAR(64) NOT NULL DEFAULT 'ECONOMIC_GROUP', -- ECONOMIC_GROUP, LEGAL_ENTITY, SPE
    root_cnpj VARCHAR(18),
    country VARCHAR(3) DEFAULT 'BRA',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_graph_entities_cnpj ON graph.entities(root_cnpj);
CREATE INDEX IF NOT EXISTS idx_graph_entities_name ON graph.entities(canonical_name);

-- 2. Entity Aliases (SPEs, Trade Names, SiiLA Codes, Tickers)
CREATE TABLE IF NOT EXISTS graph.entity_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id UUID NOT NULL REFERENCES graph.entities(id) ON DELETE CASCADE,
    alias VARCHAR(255) NOT NULL,
    source VARCHAR(64) NOT NULL, -- SIILA, CVM, ANBIMA, BRICK360
    confidence_score NUMERIC(5,2) DEFAULT 100.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_graph_aliases_lookup ON graph.entity_aliases(alias, source);

-- 3. Bitemporal Graph Edges (Look-Through Connections)
CREATE TABLE IF NOT EXISTS graph.edges_bitemporal (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_asset_id VARCHAR(64) NOT NULL, -- e.g. Ticker 'KNIP11' or Asset UUID
    target_entity_id UUID NOT NULL REFERENCES graph.entities(id),
    edge_type edge_type_enum NOT NULL DEFAULT 'CREDIT_RECEIVABLE',
    weight_pct NUMERIC(7,4) NOT NULL, -- Percentage of PL or Book Value
    valid_range TSTZRANGE NOT NULL, -- When fact was true in real world
    transaction_range TSTZRANGE NOT NULL DEFAULT tstzrange(NOW(), 'infinity', '[)'), -- When system knew it
    provenance_source_id VARCHAR(64) NOT NULL, -- ANBIMA_DATA, CVM_CDA, LEGACY_SEED
    confidence_score NUMERIC(3,2) NOT NULL DEFAULT 1.00,
    coverage_category coverage_category_enum NOT NULL DEFAULT 'RESOLVED',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_edges_bitemporal_source ON graph.edges_bitemporal(source_asset_id);
CREATE INDEX IF NOT EXISTS idx_edges_bitemporal_target ON graph.edges_bitemporal(target_entity_id);
CREATE INDEX IF NOT EXISTS idx_edges_bitemporal_valid ON graph.edges_bitemporal USING GIST (valid_range);
CREATE INDEX IF NOT EXISTS idx_edges_bitemporal_trans ON graph.edges_bitemporal USING GIST (transaction_range);

-- 4. Legacy Seeds Table (Pre-Dec/2025 CRIs)
CREATE TABLE IF NOT EXISTS canonical.cri_legacy_seeds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    isin VARCHAR(12) UNIQUE NOT NULL,
    debenture_or_cri_code VARCHAR(64),
    devedor_cnpj VARCHAR(18) NOT NULL,
    devedor_razao_social VARCHAR(255) NOT NULL,
    canonical_group_id UUID REFERENCES graph.entities(id),
    sector VARCHAR(64),
    curated_by VARCHAR(64) DEFAULT 'RESEARCH_TEAM',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cri_legacy_seeds_isin ON canonical.cri_legacy_seeds(isin);

-- 5. User Graph Overrides (Persistent Decoupled User Adjustments)
CREATE TABLE IF NOT EXISTS wealth.user_graph_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    source_asset_id VARCHAR(64) NOT NULL,
    target_entity_id UUID NOT NULL REFERENCES graph.entities(id),
    override_type graph_override_type_enum NOT NULL,
    override_weight_pct NUMERIC(7,4),
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_source_target UNIQUE (user_id, source_asset_id, target_entity_id)
);

CREATE INDEX IF NOT EXISTS idx_user_overrides_lookup ON wealth.user_graph_overrides(user_id, source_asset_id);

-- 6. Audit Inference Logs (Falsifiable Statement Reproducibility)
CREATE TABLE IF NOT EXISTS audit.inference_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    portfolio_version_hash VARCHAR(64) NOT NULL,
    subgraph_snapshot JSONB NOT NULL,
    template_id VARCHAR(64) NOT NULL,
    generated_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inference_logs_user_hash ON audit.inference_logs(user_id, portfolio_version_hash);

-- 7. Audit Discrepancies (Reported Entity Discrepancies)
CREATE TABLE IF NOT EXISTS audit.discrepancies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    source_asset_id VARCHAR(64) NOT NULL,
    target_entity_id UUID REFERENCES graph.entities(id),
    reported_issue TEXT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING_REVIEW', -- PENDING_REVIEW, VALIDATED, REJECTED
    resolved_by VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
