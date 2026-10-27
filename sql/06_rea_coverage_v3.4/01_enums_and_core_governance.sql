-- =========================================================
-- ESTÁGIO 06 (v3.4) - PARTE 1: ENUMS, GOVERNANÇA, DIRETORIA, REMUNERAÇÃO EXECUTIVA E CORRETORAS
-- Cobertura REA: Status Invest, Investidor10, Fundamentei, Fundamentus, Análise de Ações, Mais Retorno, ETFs Brasil
-- Estritamente aditivo e idempotente (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS)
-- =========================================================

-- 1. Expansão de ENUMs para cobrir todas as classes de ativos das 12 plataformas
ALTER TYPE canonical.asset_class ADD VALUE IF NOT EXISTS 'FIP';
ALTER TYPE canonical.asset_class ADD VALUE IF NOT EXISTS 'FIP_IE';
ALTER TYPE canonical.asset_class ADD VALUE IF NOT EXISTS 'FIDC';
ALTER TYPE canonical.asset_class ADD VALUE IF NOT EXISTS 'FIA';

ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'FI_INFRA';
ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'FIP';
ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'FIP_IE';
ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'FIDC';
ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'FIA';
ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'REIT';
ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'STOCK_EXTERIOR';
ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'ETF_EXTERIOR';
ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'INDICE';

-- 2. Governança, Estrutura de Capital, Auditoria e Reputação de Emissores (Status Invest, Investidor10, Fundamentei, Fundamentus, Análise de Ações)
ALTER TABLE core.emissor_companhia
    ADD COLUMN IF NOT EXISTS segmento_listagem           VARCHAR(50),
    ADD COLUMN IF NOT EXISTS free_float_on               NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS free_float_pn               NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS tag_along_on                NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS tag_along_pn                NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS tag_along_unit              NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS acoes_tesouraria_on         BIGINT,
    ADD COLUMN IF NOT EXISTS acoes_tesouraria_pn         BIGINT,
    ADD COLUMN IF NOT EXISTS acoes_tesouraria_total      BIGINT,
    ADD COLUMN IF NOT EXISTS dividendo_obrigatorio_pct   NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS em_recuperacao_judicial     BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS em_opa                      BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS auditor_independente        VARCHAR(150),
    ADD COLUMN IF NOT EXISTS auditor_codigo_cvm          VARCHAR(20),
    ADD COLUMN IF NOT EXISTS banco_escriturador          VARCHAR(150),
    ADD COLUMN IF NOT EXISTS numero_funcionarios         INT,
    ADD COLUMN IF NOT EXISTS ano_fundacao                INT,
    ADD COLUMN IF NOT EXISTS ceo_nome                    VARCHAR(150),
    ADD COLUMN IF NOT EXISTS site_ri                     TEXT,
    ADD COLUMN IF NOT EXISTS reclame_aqui_url            TEXT,
    ADD COLUMN IF NOT EXISTS reclame_aqui_nota           NUMERIC(4,2),
    ADD COLUMN IF NOT EXISTS reclame_aqui_classificacao  VARCHAR(40),
    ADD COLUMN IF NOT EXISTS glassdoor_url               TEXT,
    ADD COLUMN IF NOT EXISTS glassdoor_nota              NUMERIC(4,2);

-- 3. Pirâmide Societária e Protocolo FRE (Fundamentus acionistas.php, Fundamentei shareholders, Status Invest)
ALTER TABLE core.grupo_acionista
    ADD COLUMN IF NOT EXISTS nacionalidade               VARCHAR(60),
    ADD COLUMN IF NOT EXISTS is_controlador              BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_estatal                  BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS tipo_pessoa                 VARCHAR(20),
    ADD COLUMN IF NOT EXISTS parent_grupo_id             BIGINT REFERENCES core.grupo_acionista(id_grupo) ON DELETE SET NULL;

ALTER TABLE core.historico_acionista
    ADD COLUMN IF NOT EXISTS protocolo_fre               VARCHAR(40),
    ADD COLUMN IF NOT EXISTS is_tesouraria               BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_free_float               BOOLEAN DEFAULT FALSE;

-- 4. Cadastro CVM e Avaliação de Corretoras/Gestoras/Administradoras (Mais Retorno /gestores, Análise de Ações /corretoras)
ALTER TABLE core.instituicao_financeira
    ADD COLUMN IF NOT EXISTS diretor_responsavel         VARCHAR(150),
    ADD COLUMN IF NOT EXISTS email                       VARCHAR(150),
    ADD COLUMN IF NOT EXISTS endereco_completo           TEXT,
    ADD COLUMN IF NOT EXISTS cidade                      VARCHAR(100),
    ADD COLUMN IF NOT EXISTS uf                          CHAR(2),
    ADD COLUMN IF NOT EXISTS cep                         VARCHAR(12),
    ADD COLUMN IF NOT EXISTS nota_geral                  NUMERIC(4,2),
    ADD COLUMN IF NOT EXISTS nota_recomendacao           NUMERIC(4,2),
    ADD COLUMN IF NOT EXISTS nota_abertura_conta         NUMERIC(4,2),
    ADD COLUMN IF NOT EXISTS nota_usabilidade            NUMERIC(4,2),
    ADD COLUMN IF NOT EXISTS nota_estabilidade           NUMERIC(4,2),
    ADD COLUMN IF NOT EXISTS nota_atendimento            NUMERIC(4,2),
    ADD COLUMN IF NOT EXISTS nota_taxas                  NUMERIC(4,2),
    ADD COLUMN IF NOT EXISTS nota_necessidade            NUMERIC(4,2),
    ADD COLUMN IF NOT EXISTS total_avaliacoes            INT DEFAULT 0;

-- 5. Diretores Estatutários CVM (Res. 21, PLDFT, Risco, Compliance, Suitability) e Sócios de Gestoras (Mais Retorno)
CREATE TABLE IF NOT EXISTS core.instituicao_diretoria_socios (
    id_membro             BIGSERIAL PRIMARY KEY,
    id_instituicao        INT NOT NULL REFERENCES core.instituicao_financeira(id_instituicao) ON DELETE CASCADE,
    nome                  VARCHAR(150) NOT NULL,
    cpf_cnpj_parcial      VARCHAR(20),
    tipo_vinculo          VARCHAR(30) NOT NULL CHECK (tipo_vinculo IN ('DIRETOR','SOCIO','CONSELHEIRO','CONTROLADOR','OUTRO')),
    cargo_funcao          VARCHAR(100),
    data_inicio           DATE,
    data_fim              DATE,
    ativo                 BOOLEAN DEFAULT TRUE,
    fonte                 VARCHAR(40) DEFAULT 'CVM',
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (id_instituicao, nome, tipo_vinculo, cargo_funcao)
);
CREATE INDEX IF NOT EXISTS idx_inst_dir_socios_inst ON core.instituicao_diretoria_socios(id_instituicao);

-- 6. Administradores e Conselheiros de Companhias Abertas (Fundamentus administradores.php / adm.php, Fundamentei officers)
CREATE TABLE IF NOT EXISTS core.administrador_companhia (
    id_administrador      BIGSERIAL PRIMARY KEY,
    id_emissor            INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    nome                  VARCHAR(150) NOT NULL,
    cpf_parcial           VARCHAR(20),
    orgao                 VARCHAR(60) NOT NULL CHECK (orgao IN (
                              'DIRETORIA_ESTATUTARIA','CONSELHO_ADMINISTRACAO','CONSELHO_FISCAL','COMITE_AUDITORIA','OUTRO'
                          )),
    cargo                 VARCHAR(120) NOT NULL,
    profissao             VARCHAR(100),
    data_nascimento       DATE,
    data_eleicao          DATE,
    data_posse            DATE,
    prazo_mandato         VARCHAR(60),
    mandatos_consecutivos INT,
    participacao_reunioes_pct NUMERIC(5,2),
    eleito_pelo_controlador BOOLEAN,
    curriculo_resumo      TEXT,
    outros_cargos_cvm     JSONB DEFAULT '[]'::jsonb,
    condenacoes_cvm       TEXT,
    protocolo_fre         VARCHAR(40),
    data_referencia       DATE,
    ativo                 BOOLEAN DEFAULT TRUE,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (id_emissor, nome, orgao, cargo, data_eleicao)
);
CREATE INDEX IF NOT EXISTS idx_adm_cia_emissor ON core.administrador_companhia(id_emissor, ativo);
CREATE INDEX IF NOT EXISTS idx_adm_cia_nome ON core.administrador_companhia(nome);

-- 7. Remuneração de Executivos e Conselheiros (Status Invest Input #17 JSON, Fundamentei Executive Compensation)
CREATE TABLE IF NOT EXISTS core.remuneracao_administradores (
    id_remuneracao        BIGSERIAL PRIMARY KEY,
    id_emissor            INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    ano_referencia        INT NOT NULL,
    orgao                 VARCHAR(60) NOT NULL CHECK (orgao IN (
                              'DIRETORIA_ESTATUTARIA','CONSELHO_ADMINISTRACAO','CONSELHO_FISCAL','CONSOLIDADO'
                          )),
    numero_membros        NUMERIC(6,2),
    numero_membros_remunerados NUMERIC(6,2),
    remuneracao_total     NUMERIC(18,2),
    remuneracao_fixa_salario NUMERIC(18,2),
    remuneracao_fixa_beneficios NUMERIC(18,2),
    remuneracao_fixa_comites NUMERIC(18,2),
    remuneracao_variavel_bonus NUMERIC(18,2),
    remuneracao_variavel_plr NUMERIC(18,2),
    remuneracao_baseada_acoes NUMERIC(18,2),
    beneficios_pos_emprego NUMERIC(18,2),
    beneficios_cessacao_cargo NUMERIC(18,2),
    maior_remuneracao_individual NUMERIC(18,2),
    menor_remuneracao_individual NUMERIC(18,2),
    media_remuneracao_individual NUMERIC(18,2),
    remuneracao_sobre_lucro_liquido_pct NUMERIC(8,4),
    protocolo_fre         VARCHAR(40),
    fonte                 VARCHAR(40) DEFAULT 'FRE_CVM',
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (id_emissor, ano_referencia, orgao)
);
CREATE INDEX IF NOT EXISTS idx_rem_adm_emissor_ano ON core.remuneracao_administradores(id_emissor, ano_referencia DESC);
