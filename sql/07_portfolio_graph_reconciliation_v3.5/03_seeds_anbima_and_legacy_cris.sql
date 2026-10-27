-- ==============================================================================
-- Migration: 03_seeds_anbima_and_legacy_cris.sql
-- Description: Seed initial divergence taxonomies, canonical debtor groups,
--              legacy CRI mappings, and bitemporal look-through edges.
-- ==============================================================================

-- 1. Insert Finite Divergence Taxonomies
INSERT INTO reconciliation.divergence_taxonomies (code, display_name, description, typical_impact_level)
VALUES
    ('PRICE_TIMESTAMP_MISMATCH', 'Defasagem de Timestamp do Preço', 'Divergência entre preço oficial de fechamento vs último negócio intraday vs VWAP.', 'LOW'),
    ('DIVIDEND_WINDOW_MISMATCH', 'Janela de Dividendos Divergente', 'Diferença entre janela de 12 meses corridos (LTM), ano fiscal fechado (YTD) ou anualização do último provento.', 'HIGH'),
    ('TAX_TREATMENT_MISMATCH', 'Tratamento Tributário (Bruto vs Líquido)', 'Discrepância gerada por retenção de imposto na fonte (IR sobre JCP ou proventos tributáveis em certos fundos).', 'MEDIUM'),
    ('CAPITAL_BASE_MISMATCH', 'Base de Capital e Diluição', 'Uso de lucro básico vs lucro diluído ou patrimônio líquido contábil vs valor patrimonial a mercado.', 'MEDIUM'),
    ('AMORTIZATION_ACCOUNTING', 'Contabilização de Amortização', 'Tratamento de amortização de principal como provento/rendimento versus dedução de custo de aquisição.', 'HIGH'),
    ('SOURCE_STALENESS_OR_ERROR', 'Desatualização ou Falha na Fonte', 'Fonte parceira com mais de 48h sem atualização de dados cadastrais ou proventos.', 'HIGH')
ON CONFLICT (code) DO UPDATE
SET display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    typical_impact_level = EXCLUDED.typical_impact_level;

-- 2. Insert Core Canonical Debtor Groups
INSERT INTO graph.entities (id, canonical_name, entity_type, root_cnpj, country)
VALUES
    ('a0000000-0000-0000-0000-000000000001', 'Grupo JHSF', 'ECONOMIC_GROUP', '61.274.529/0001-00', 'BRA'),
    ('a0000000-0000-0000-0000-000000000002', 'MRV Engenharia & Participações', 'ECONOMIC_GROUP', '08.343.492/0001-20', 'BRA'),
    ('a0000000-0000-0000-0000-000000000003', 'Rede D''Or São Luiz', 'ECONOMIC_GROUP', '06.047.087/0001-39', 'BRA'),
    ('a0000000-0000-0000-0000-000000000004', 'Grupo Pão de Açúcar (GPA)', 'ECONOMIC_GROUP', '47.508.411/0001-56', 'BRA')
ON CONFLICT (id) DO NOTHING;

-- 3. Insert Entity Aliases (SPEs / Trade Names / SiiLA codes)
INSERT INTO graph.entity_aliases (entity_id, alias, source, confidence_score)
VALUES
    ('a0000000-0000-0000-0000-000000000001', 'JHSF Participações S.A.', 'CVM', 100.00),
    ('a0000000-0000-0000-0000-000000000001', 'Shopping Cidade Jardim SPE', 'SIILA', 95.00),
    ('a0000000-0000-0000-0000-000000000001', 'Fazenda Boa Vista Empreendimentos', 'CVM', 95.00),
    ('a0000000-0000-0000-0000-000000000002', 'MRV Prime SPE Ltda', 'CVM', 95.00),
    ('a0000000-0000-0000-0000-000000000003', 'Hospital Brasil Santo André SPE', 'SIILA', 95.00)
ON CONFLICT DO NOTHING;

-- 4. Seed Legacy CRIs (Pre-Dec/2025) Held by Main FIIs
INSERT INTO canonical.cri_legacy_seeds (isin, debenture_or_cri_code, devedor_cnpj, devedor_razao_social, canonical_group_id, sector)
VALUES
    ('BRSTNNCRI001', 'CRI JHSF Fasano 129S', '61.274.529/0001-00', 'JHSF PARTICIPACOES S.A.', 'a0000000-0000-0000-0000-000000000001', 'HOSPITALITY_LUXURY'),
    ('BRSTNNCRI002', 'CRI JHSF Catarina 184S', '61.274.529/0001-00', 'JHSF PARTICIPACOES S.A.', 'a0000000-0000-0000-0000-000000000001', 'OUTLET_RETAIL'),
    ('BROPEACRI010', 'CRI MRV Luggo Residencial', '08.343.492/0001-20', 'MRV ENGENHARIA E PARTICIPACOES SA', 'a0000000-0000-0000-0000-000000000002', 'RESIDENTIAL_MULTIFAMILY'),
    ('BRVIRGCRI044', 'CRI Rede D''Or Hospitalar', '06.047.087/0001-39', 'REDE D OR SAO LUIZ S.A.', 'a0000000-0000-0000-0000-000000000003', 'HEALTHCARE')
ON CONFLICT (isin) DO NOTHING;

-- 5. Seed Bitemporal Edges for KNIP11 and KNCR11
INSERT INTO graph.edges_bitemporal (
    source_asset_id,
    target_entity_id,
    edge_type,
    weight_pct,
    valid_range,
    transaction_range,
    provenance_source_id,
    confidence_score,
    coverage_category,
    metadata
)
VALUES
    (
        'KNIP11',
        'a0000000-0000-0000-0000-000000000001',
        'CREDIT_RECEIVABLE',
        18.5000,
        tstzrange('2026-08-01 00:00:00+00', '2026-09-01 00:00:00+00', '[)'),
        tstzrange('2026-09-15 14:30:00+00', 'infinity', '[)'),
        'CVM_CDA_175',
        0.98,
        'RESOLVED',
        '{"cri_isin": "BRSTNNCRI001", "rating": "AA", "rating_agency": "FITCH"}'::jsonb
    ),
    (
        'KNCR11',
        'a0000000-0000-0000-0000-000000000001',
        'CREDIT_RECEIVABLE',
        12.0000,
        tstzrange('2026-08-01 00:00:00+00', '2026-09-01 00:00:00+00', '[)'),
        tstzrange('2026-09-15 14:30:00+00', 'infinity', '[)'),
        'CVM_CDA_175',
        0.95,
        'RESOLVED',
        '{"cri_isin": "BRSTNNCRI002", "rating": "AA-", "rating_agency": "MOODYS"}'::jsonb
    ),
    (
        'KNIP11',
        'a0000000-0000-0000-0000-000000000002',
        'CREDIT_RECEIVABLE',
        9.2500,
        tstzrange('2026-08-01 00:00:00+00', '2026-09-01 00:00:00+00', '[)'),
        tstzrange('2026-09-15 14:30:00+00', 'infinity', '[)'),
        'CVM_CDA_175',
        0.92,
        'RESOLVED',
        '{"cri_isin": "BROPEACRI010", "rating": "A+", "rating_agency": "S&P"}'::jsonb
    )
ON CONFLICT DO NOTHING;
