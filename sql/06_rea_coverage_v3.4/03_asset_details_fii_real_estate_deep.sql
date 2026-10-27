-- =========================================================
-- ESTÁGIO 06 (v3.4) - PARTE 3: FIIs - IMÓVEIS FÍSICOS, SIILA VENDAS/LOCAÇÕES, CONTRATOS, CRIS, DRE E GESTORAS
-- Cobertura REA: Clube FII (CR Data + SiiLA), Funds Explorer, FIIs.com.br, Brick360, Status Invest, Fundamentus
-- Estritamente aditivo e idempotente (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS)
-- =========================================================

-- 1. Expansão de asset_details.detalhe_fii com Governança, Métricas por m², Carteira CRI e Inquilinos
ALTER TABLE asset_details.detalhe_fii
    ADD COLUMN IF NOT EXISTS avaliador_imobiliario       VARCHAR(150),
    ADD COLUMN IF NOT EXISTS escriturador                VARCHAR(150),
    ADD COLUMN IF NOT EXISTS taxa_gerenciamento          VARCHAR(100),
    ADD COLUMN IF NOT EXISTS taxa_consultoria            VARCHAR(100),
    ADD COLUMN IF NOT EXISTS taxa_adm_paga_ano_pct       NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_adm_sobre_receita_pct  NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS dia_habitual_anuncio_div    INT,
    ADD COLUMN IF NOT EXISTS dia_habitual_pagamento_div  INT,
    ADD COLUMN IF NOT EXISTS qtd_imoveis                 INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS preco_m2                    NUMERIC(14,2),
    ADD COLUMN IF NOT EXISTS aluguel_m2                  NUMERIC(14,2),
    ADD COLUMN IF NOT EXISTS cap_rate_medio              NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS inadimplencia_pct           NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS prazo_medio_contratos_anos  NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS percentual_contratos_atipicos NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS maior_inquilino_nome        VARCHAR(150),
    ADD COLUMN IF NOT EXISTS maior_inquilino_receita_pct NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS top5_inquilinos_receita_pct NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS top10_inquilinos_receita_pct NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS qtd_cris_carteira           INT,
    ADD COLUMN IF NOT EXISTS duration_media_carteira_anos NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS ltv_medio_carteira_pct      NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS taxa_media_ponderada_carteira NUMERIC(8,4);

-- 2. Informe Mensal CVM Estruturado: 4 Buckets de Caixa e 10 Rubricas de Passivo/Alavancagem (Clube FII, Funds Explorer, Brick360)
ALTER TABLE asset_details.historico_patrimonio_fii
    ADD COLUMN IF NOT EXISTS caixa_disponibilidades      NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS caixa_titulos_publicos      NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS caixa_titulos_privados      NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS caixa_fundos_renda_fixa     NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS ativos_imobiliarios_reais   NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS ativos_papel_cri_lci        NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS ativos_cotas_outros_fiis    NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS passivo_rendimentos_distribuir NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS passivo_taxa_administracao  NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS passivo_taxa_performance    NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS passivo_aquisicao_imoveis   NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS passivo_adiantamento_alugueis NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS passivo_adiantamento_vendas NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS passivo_obrigacoes_securitizacao_cri NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS passivo_instrumentos_derivativos NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS passivo_contingencias       NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS passivo_outros_pagar        NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS divida_onerosa              NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS indice_alavancagem_pct      NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS numero_cotistas             INT;

-- 3. Inadimplência Histórica, DY Patrimonial e Composição de Carteira FII
ALTER TABLE asset_details.historico_vacancia_fii
    ADD COLUMN IF NOT EXISTS inadimplencia_pct           NUMERIC(6,2);

ALTER TABLE asset_details.rentabilidade_fii
    ADD COLUMN IF NOT EXISTS dy_patrimonial              NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS variacao_patrimonial        NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS rentabilidade_patrimonial_periodo NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS rentabilidade_patrimonial_acumulada NUMERIC(10,4);

ALTER TABLE asset_details.composicao_carteira_fii
    ADD COLUMN IF NOT EXISTS uf                          CHAR(2),
    ADD COLUMN IF NOT EXISTS cidade                      TEXT,
    ADD COLUMN IF NOT EXISTS bairro                      TEXT,
    ADD COLUMN IF NOT EXISTS area_m2                     NUMERIC(14,2),
    ADD COLUMN IF NOT EXISTS numero_unidades             INT,
    ADD COLUMN IF NOT EXISTS caracteristicas             TEXT,
    ADD COLUMN IF NOT EXISTS taxa_ocupacao_pct           NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS inadimplencia_pct           NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS percentual_receitas_fii     NUMERIC(8,4);

-- 4. Expansão de asset_details.mercado_imobiliario_indicador para Séries SiiLA (Clube FII)
ALTER TABLE asset_details.mercado_imobiliario_indicador
    ADD COLUMN IF NOT EXISTS submercado                  TEXT,
    ADD COLUMN IF NOT EXISTS classe_imovel               VARCHAR(20),
    ADD COLUMN IF NOT EXISTS vacancia_pct                NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS espaco_vago_m2              NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS estoque_total_m2            NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS novo_estoque_m2             NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS absorcao_bruta_m2           NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS absorcao_liquida_m2         NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS cap_rate_medio_pct          NUMERIC(8,4);

-- 5. Cadastro de Imóveis Físicos e Participação Multi-FII (Clube FII, Funds Explorer, Fundamentus, Brick360)
CREATE TABLE IF NOT EXISTS asset_details.fii_imovel (
    id_imovel             BIGSERIAL PRIMARY KEY,
    codigo_externo        VARCHAR(50),
    nome                  VARCHAR(200) NOT NULL,
    tipo_imovel           VARCHAR(60),
    classe_siila          VARCHAR(20),
    endereco              TEXT,
    bairro                VARCHAR(100),
    regiao_imobiliaria    VARCHAR(100),
    cidade                VARCHAR(100),
    uf                    CHAR(2),
    cep                   VARCHAR(12),
    latitude              NUMERIC(10,7),
    longitude             NUMERIC(10,7),
    abl_total_m2          NUMERIC(14,2),
    numero_unidades       INT,
    numero_andares        INT,
    vagas_garagem         INT,
    ano_construcao        INT,
    status_imovel         VARCHAR(40) CHECK (status_imovel IN ('CONCLUIDO','EM_CONSTRUCAO','PROJETO','TERRENO','VENDIDO','OUTRO')),
    certificacao_sustentavel VARCHAR(60),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_fii_imovel_nome_cid_uf
    ON asset_details.fii_imovel(nome, COALESCE(cidade, ''), COALESCE(uf, ''));
CREATE INDEX IF NOT EXISTS idx_fii_imovel_uf_cidade ON asset_details.fii_imovel(uf, cidade);

CREATE TABLE IF NOT EXISTS asset_details.fii_imovel_participacao (
    id_participacao       BIGSERIAL PRIMARY KEY,
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_imovel             BIGINT NOT NULL REFERENCES asset_details.fii_imovel(id_imovel) ON DELETE CASCADE,
    data_referencia       DATE NOT NULL,
    participacao_pct      NUMERIC(8,4),
    abl_propria_m2        NUMERIC(14,2),
    vacancia_fisica_pct   NUMERIC(8,4),
    vacancia_financeira_pct NUMERIC(8,4),
    inadimplencia_pct     NUMERIC(8,4),
    participacao_receita_fii_pct NUMERIC(8,4),
    valor_laudo           NUMERIC(18,2),
    data_laudo            DATE,
    custo_aquisicao       NUMERIC(18,2),
    data_aquisicao        DATE,
    aluguel_m2_estimado   NUMERIC(12,2),
    preco_m2_regiao_siila NUMERIC(12,2),
    vacancia_regiao_siila_pct NUMERIC(8,4),
    eficiencia_vs_regiao  VARCHAR(20),
    inquilinos_principais TEXT,
    UNIQUE (id_ativo, id_imovel, data_referencia)
);
CREATE INDEX IF NOT EXISTS idx_fii_imovel_part_ativo ON asset_details.fii_imovel_participacao(id_ativo, data_referencia DESC);

-- 6. Transações de Venda e Locação de Imóveis Comercias SiiLA (Clube FII)
CREATE TABLE IF NOT EXISTS asset_details.fii_transacao_venda_imovel (
    id_transacao_venda    BIGSERIAL PRIMARY KEY,
    id_imovel             BIGINT REFERENCES asset_details.fii_imovel(id_imovel) ON DELETE SET NULL,
    id_ativo_comprador    INT REFERENCES core.ativo(id_ativo) ON DELETE SET NULL,
    id_ativo_vendedor     INT REFERENCES core.ativo(id_ativo) ON DELETE SET NULL,
    nome_imovel           VARCHAR(200) NOT NULL,
    classe_siila          VARCHAR(20),
    regiao_imobiliaria    VARCHAR(100),
    cidade                VARCHAR(100),
    uf                    CHAR(2),
    comprador_nome        VARCHAR(150),
    vendedor_nome         VARCHAR(150),
    data_transacao        DATE NOT NULL,
    tipo_transacao        VARCHAR(60),
    participacao_negociada_pct NUMERIC(8,4),
    area_negociada_m2     NUMERIC(14,2),
    valor_total           NUMERIC(18,2),
    preco_m2              NUMERIC(14,2),
    cap_rate_pct          NUMERIC(8,4),
    ocupacao_no_momento_pct NUMERIC(8,4),
    fonte                 VARCHAR(40) DEFAULT 'SIILA',
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_fii_venda_imovel_data ON asset_details.fii_transacao_venda_imovel(data_transacao DESC);

CREATE TABLE IF NOT EXISTS asset_details.fii_transacao_locacao_imovel (
    id_transacao_locacao  BIGSERIAL PRIMARY KEY,
    id_imovel             BIGINT REFERENCES asset_details.fii_imovel(id_imovel) ON DELETE SET NULL,
    id_ativo              INT REFERENCES core.ativo(id_ativo) ON DELETE SET NULL,
    nome_imovel           VARCHAR(200) NOT NULL,
    classe_siila          VARCHAR(20),
    regiao_imobiliaria    VARCHAR(100),
    cidade                VARCHAR(100),
    uf                    CHAR(2),
    locatario_nome        VARCHAR(150),
    setor_locatario       VARCHAR(100),
    proprietario_nome     VARCHAR(150),
    trimestre_referencia  VARCHAR(10) NOT NULL,
    area_locada_m2        NUMERIC(14,2),
    preco_pedido_m2       NUMERIC(12,2),
    ocupacao_imovel_pct   NUMERIC(8,4),
    fonte                 VARCHAR(40) DEFAULT 'SIILA',
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_fii_locacao_imovel_ativo ON asset_details.fii_transacao_locacao_imovel(id_ativo);

-- 7. Cronograma de Vencimento e Revisional de Contratos de Locação e Indexadores CVM (Status Invest, Clube FII, Brick360)
CREATE TABLE IF NOT EXISTS asset_details.fii_cronograma_contratos (
    id_cronograma         BIGSERIAL PRIMARY KEY,
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_referencia       DATE NOT NULL,
    tipo_cronograma       VARCHAR(20) NOT NULL CHECK (tipo_cronograma IN ('VENCIMENTO','REVISIONAL')),
    faixa_prazo           VARCHAR(30) NOT NULL CHECK (faixa_prazo IN (
                              'ATE_3M','3M_A_6M','6M_A_9M','9M_A_12M','12M_A_15M','15M_A_18M','18M_A_21M',
                              '21M_A_24M','24M_A_27M','27M_A_30M','30M_A_33M','33M_A_36M','ACIMA_36M','INDETERMINADO'
                          )),
    percentual_receita    NUMERIC(8,4),
    percentual_area_abl   NUMERIC(8,4),
    idx_igpm_pct          NUMERIC(8,4),
    idx_ipca_pct          NUMERIC(8,4),
    idx_inpc_pct          NUMERIC(8,4),
    idx_incc_pct          NUMERIC(8,4),
    idx_outros_pct        NUMERIC(8,4),
    UNIQUE (id_ativo, data_referencia, tipo_cronograma, faixa_prazo)
);
CREATE INDEX IF NOT EXISTS idx_fii_cron_contratos_ativo ON asset_details.fii_cronograma_contratos(id_ativo, data_referencia DESC);

-- 8. Carteira Detalhada de CRIs / Recebíveis de FIIs de Papel (Status Invest /fii/cridetail/, Clube FII CR Data, Brick360)
CREATE TABLE IF NOT EXISTS asset_details.fii_cri_carteira (
    id_cri_posicao        BIGSERIAL PRIMARY KEY,
    id_ativo_fii          INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_referencia       DATE NOT NULL,
    codigo_if_cetip       VARCHAR(30),
    isin                  VARCHAR(12),
    securitizadora_nome   VARCHAR(150),
    securitizadora_cnpj   VARCHAR(18),
    devedor_nome          VARCHAR(150),
    serie                 VARCHAR(20),
    emissao               VARCHAR(20),
    indexador             VARCHAR(30),
    taxa_emissao_spread   NUMERIC(8,4),
    periodicidade_juros   VARCHAR(30),
    duration_anos         NUMERIC(6,2),
    ltv_pct               NUMERIC(6,2),
    subordinacao_tipo     VARCHAR(30) CHECK (subordinacao_tipo IN ('SENIOR','MEZANINO','SUBORDINADA','UNICA')),
    garantias_resumo      TEXT,
    data_emissao          DATE,
    data_vencimento       DATE,
    quantidade            NUMERIC(18,4),
    valor_mercado         NUMERIC(18,2),
    percentual_pl         NUMERIC(8,4),
    inadimplente          BOOLEAN DEFAULT FALSE
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_fii_cri_carteira_pos
    ON asset_details.fii_cri_carteira(id_ativo_fii, data_referencia, COALESCE(codigo_if_cetip, ''), COALESCE(serie, ''), COALESCE(emissao, ''));
CREATE INDEX IF NOT EXISTS idx_fii_cri_carteira_fii ON asset_details.fii_cri_carteira(id_ativo_fii, data_referencia DESC);

-- 9. Demonstrativo Trimestral Estruturado de FIIs (Brick360 /analysis/quarterly-result e Fundamentus Resultado FII)
CREATE TABLE IF NOT EXISTS asset_details.fii_demonstrativo_trimestral (
    id_demonstrativo_fii  BIGSERIAL PRIMARY KEY,
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_referencia       DATE NOT NULL,
    trimestre_label       VARCHAR(10),
    receita_alugueis_contabil NUMERIC(18,2),
    receita_alugueis_caixa NUMERIC(18,2),
    receita_venda_imoveis_contabil NUMERIC(18,2),
    receita_venda_imoveis_caixa NUMERIC(18,2),
    receita_cri_contabil  NUMERIC(18,2),
    receita_cri_caixa     NUMERIC(18,2),
    receita_fii_contabil  NUMERIC(18,2),
    receita_fii_caixa     NUMERIC(18,2),
    receita_lci_lca_contabil NUMERIC(18,2),
    receita_lci_lca_caixa NUMERIC(18,2),
    receita_total_contabil NUMERIC(18,2),
    receita_total_caixa   NUMERIC(18,2),
    despesas_operacionais_contabil NUMERIC(18,2),
    despesas_operacionais_caixa NUMERIC(18,2),
    ajustes_nao_caixa     NUMERIC(18,2),
    resultado_liquido_contabil NUMERIC(18,2),
    resultado_liquido_caixa NUMERIC(18,2),
    resultado_financeiro_liquido_contabil NUMERIC(18,2),
    resultado_financeiro_liquido_caixa NUMERIC(18,2),
    resultado_distribuido NUMERIC(18,2),
    payout_trimestral_pct NUMERIC(8,4),
    resultado_nao_distribuido_acumulado NUMERIC(18,2),
    UNIQUE (id_ativo, data_referencia)
);
CREATE INDEX IF NOT EXISTS idx_fii_dem_trim_ativo ON asset_details.fii_demonstrativo_trimestral(id_ativo, data_referencia DESC);

-- 10. Auditoria e Governança de Gestora de FII (Brick360 manager_axis)
CREATE TABLE IF NOT EXISTS asset_details.fii_avaliacao_gestora (
    id_avaliacao_gestora  BIGSERIAL PRIMARY KEY,
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_gestora            INT REFERENCES core.instituicao_financeira(id_instituicao) ON DELETE SET NULL,
    data_referencia       DATE NOT NULL,
    alinhamento_interesses_status VARCHAR(30),
    taxa_performance_adequada BOOLEAN,
    conflitos_interesse_identificados BOOLEAN,
    conflitos_interesse_detalhes TEXT,
    reputacao_cvm_status  VARCHAR(30),
    reputacao_anbima_status VARCHAR(30),
    reputacao_judicial_status VARCHAR(30),
    reputacao_midia_status VARCHAR(30),
    track_record_consistente BOOLEAN,
    transparencia_relatorios_score NUMERIC(6,2),
    checklist_transparencia JSONB DEFAULT '{}'::jsonb,
    resumo_comite_ia      TEXT,
    UNIQUE (id_ativo, data_referencia)
);
CREATE INDEX IF NOT EXISTS idx_fii_aval_gestora_ativo ON asset_details.fii_avaliacao_gestora(id_ativo, data_referencia DESC);
