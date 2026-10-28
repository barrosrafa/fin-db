-- ============================================================================
-- FIN-DB: MIGRATION 11 - ANÁLISE DE AÇÕES FULL COVERAGE (v3.9)
-- Esquemas: cms, suitability, market, asset_details, analytics, core, system
-- Compatibilidade: PostgreSQL 18 / TimescaleDB (Neon Serverless)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS cms;
CREATE SCHEMA IF NOT EXISTS suitability;

-- ----------------------------------------------------------------------------
-- 1. CÂMBIO PTAX DIÁRIO E DUPLA LISTAGEM INTERNACIONAL (STOCKS / BDRs)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS market.cotacao_cambio_diaria (
    data_cambio         DATE NOT NULL,
    moeda_origem        VARCHAR(3) NOT NULL,
    moeda_destino       VARCHAR(3) NOT NULL DEFAULT 'BRL',
    taxa_compra         NUMERIC(14,6) NOT NULL,
    taxa_venda          NUMERIC(14,6) NOT NULL,
    boletim             VARCHAR(20) DEFAULT 'FECHAMENTO',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (data_cambio, moeda_origem, moeda_destino)
);

CREATE INDEX IF NOT EXISTS idx_cambio_data_moeda 
    ON market.cotacao_cambio_diaria(data_cambio DESC, moeda_origem);

CREATE TABLE IF NOT EXISTS core.ativo_dupla_listagem (
    id_dupla_listagem   BIGSERIAL PRIMARY KEY,
    id_ativo_origem     INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_ativo_bdr        INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    proporcao_bdr       NUMERIC(12,6) NOT NULL, -- Ex: 1 Stock = 10 BDRs
    banco_depositario   VARCHAR(100),
    is_patrocinado      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (id_ativo_origem, id_ativo_bdr)
);

-- ----------------------------------------------------------------------------
-- 2. MÉTRICAS ESPECIALIZADAS DE REITS & DEMONSTRATIVOS US GAAP (NAREIT)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS asset_details.detalhe_reit (
    id_ativo                INT PRIMARY KEY REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    subtipo_reit            VARCHAR(50) NOT NULL, -- Industrial, Healthcare, Retail, Data Center, etc.
    ffo_12m                 NUMERIC(18,4),       -- Funds From Operations 12 meses (USD)
    affo_12m                NUMERIC(18,4),      -- Adjusted Funds From Operations 12 meses (USD)
    ffo_por_acao            NUMERIC(12,4),
    affo_por_acao           NUMERIC(12,4),
    p_ffo                   NUMERIC(10,2),
    p_affo                  NUMERIC(10,2),
    ffo_payout_ratio        NUMERIC(6,2),       -- % proventos sobre FFO
    taxa_ocupacao_pct       NUMERIC(5,2),
    total_propriedades      INT,
    alavancagem_divida_ev   NUMERIC(6,2),
    withholding_tax_pct     NUMERIC(5,2) DEFAULT 30.00,
    data_atualizacao        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 3. PROVENTOS DETALHADOS & TRIBUTAÇÃO NA FONTE UNIFICADA
-- ----------------------------------------------------------------------------

DO $$ BEGIN
    ALTER TYPE market.tipo_provento_enum ADD VALUE IF NOT EXISTS 'ORDINARY_DIVIDEND_US';
    ALTER TYPE market.tipo_provento_enum ADD VALUE IF NOT EXISTS 'RETURN_OF_CAPITAL_US';
    ALTER TYPE market.tipo_provento_enum ADD VALUE IF NOT EXISTS 'CAPITAL_GAIN_DIST_US';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE market.provento
    ADD COLUMN IF NOT EXISTS valor_bruto_usd         NUMERIC(14,6),
    ADD COLUMN IF NOT EXISTS aliquota_retencao_fonte NUMERIC(5,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS valor_liquido_moeda     NUMERIC(14,6),
    ADD COLUMN IF NOT EXISTS taxa_cambio_ptax        NUMERIC(14,6),
    ADD COLUMN IF NOT EXISTS valor_liquido_brl       NUMERIC(14,6),
    ADD COLUMN IF NOT EXISTS status_aprovacao        VARCHAR(30) DEFAULT 'CONFIRMADO',
    ADD COLUMN IF NOT EXISTS data_limite_alteracao   DATE;

CREATE INDEX IF NOT EXISTS idx_provento_data_pagamento 
    ON market.provento(data_pagamento DESC, id_ativo);

-- ----------------------------------------------------------------------------
-- 4. MATRIZ DE SAZONALIDADE E MAPA DE DIVIDENDOS (PRÉ-AGREGADA)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.mapa_sazonalidade_dividendo (
    id_ativo                INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    mes_calendario          SMALLINT NOT NULL CHECK (mes_calendario BETWEEN 1 AND 12),
    tipo_evento             VARCHAR(20) NOT NULL CHECK (tipo_evento IN ('DATA_COM', 'PAGAMENTO')),
    ocorrencias_historicas  INT NOT NULL DEFAULT 0,
    anos_analisados         INT NOT NULL DEFAULT 1,
    probabilidade_pct       NUMERIC(5,2) GENERATED ALWAYS AS (
        LEAST(100.00, ROUND((ocorrencias_historicas::numeric / GREATEST(anos_analisados, 1)) * 100, 2))
    ) STORED,
    valor_medio_provento    NUMERIC(12,6) DEFAULT 0.00,
    yield_medio_mensal      NUMERIC(6,4) DEFAULT 0.00,
    ultimo_ano_pago         INT,
    data_atualizacao        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id_ativo, mes_calendario, tipo_evento)
);

CREATE INDEX IF NOT EXISTS idx_mapa_sazonal_prob 
    ON analytics.mapa_sazonalidade_dividendo(mes_calendario, probabilidade_pct DESC);

-- ----------------------------------------------------------------------------
-- 5. CMS COMPLETO: GLOSSÁRIO (DICIONÁRIO), LIVROS, ARTIGOS E SUPORTE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS cms.termo_glossario (
    id_termo            SERIAL PRIMARY KEY,
    slug                VARCHAR(120) NOT NULL UNIQUE,
    termo               VARCHAR(150) NOT NULL,
    letra_inicial       CHAR(1) GENERATED ALWAYS AS (UPPER(SUBSTRING(termo FROM 1 FOR 1))) STORED,
    categoria           VARCHAR(60) NOT NULL, -- Valuation, Renda Fixa, Contabilidade, etc.
    definicao_curta     VARCHAR(300) NOT NULL,
    conteudo_markdown   TEXT NOT NULL,
    formula_latex       TEXT,
    meta_title          VARCHAR(100),
    meta_description    VARCHAR(200),
    total_visualizacoes BIGINT DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_glossario_letra ON cms.termo_glossario(letra_inicial, termo);

CREATE TABLE IF NOT EXISTS cms.livro_investimento (
    id_livro            SERIAL PRIMARY KEY,
    slug                VARCHAR(150) NOT NULL UNIQUE,
    titulo              VARCHAR(200) NOT NULL,
    subtitulo           VARCHAR(250),
    autor               VARCHAR(150) NOT NULL,
    editora             VARCHAR(100),
    ano_publicacao      INT,
    isbn                VARCHAR(20),
    nivel_dificuldade   VARCHAR(30) CHECK (nivel_dificuldade IN ('INICIANTE', 'INTERMEDIARIO', 'AVANCADO')),
    categoria           VARCHAR(60) NOT NULL,
    capa_url            TEXT,
    resenha_markdown    TEXT NOT NULL,
    principais_licoes   JSONB DEFAULT '[]'::jsonb,
    avaliacao_media     NUMERIC(3,2) DEFAULT 5.00,
    link_afiliado       TEXT,
    ativo               BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cms.artigo_blog (
    id_artigo           BIGSERIAL PRIMARY KEY,
    slug                VARCHAR(200) NOT NULL UNIQUE,
    titulo              VARCHAR(250) NOT NULL,
    subtitulo           TEXT,
    autor_id            UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    autor_nome          VARCHAR(120) NOT NULL,
    categoria           VARCHAR(60) NOT NULL,
    tags                TEXT[] DEFAULT ARRAY[]::TEXT[],
    conteudo_markdown   TEXT NOT NULL,
    tempo_leitura_min   SMALLINT DEFAULT 5,
    is_premium          BOOLEAN NOT NULL DEFAULT FALSE,
    banner_url          TEXT,
    publicado_em        TIMESTAMPTZ,
    status              VARCHAR(20) DEFAULT 'RASCUNHO' CHECK (status IN ('RASCUNHO', 'PUBLICADO', 'ARQUIVADO')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_artigo_publicado ON cms.artigo_blog(publicado_em DESC) WHERE status = 'PUBLICADO';

CREATE TABLE IF NOT EXISTS cms.ticket_suporte (
    id_ticket           BIGSERIAL PRIMARY KEY,
    id_usuario          UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    nome_contato        VARCHAR(120) NOT NULL,
    email_contato       VARCHAR(150) NOT NULL,
    assunto             VARCHAR(60) NOT NULL, -- ASSINATURA, ERRO_DADOS, SUGESTAO, OUTROS
    mensagem            TEXT NOT NULL,
    status              VARCHAR(20) DEFAULT 'ABERTO' CHECK (status IN ('ABERTO', 'EM_ANALISE', 'RESOLVIDO', 'FECHADO')),
    ip_origem           INET,
    resposta_admin      TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at         TIMESTAMPTZ
);

-- ----------------------------------------------------------------------------
-- 6. SUITABILITY: MOTOR DE QUESTIONÁRIO, SCORING E ALOCAÇÃO RECOMENDADA
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS suitability.pergunta (
    id_pergunta         SERIAL PRIMARY KEY,
    ordem               INT NOT NULL UNIQUE,
    titulo              VARCHAR(250) NOT NULL,
    descricao           TEXT,
    eixo_analise        VARCHAR(40) NOT NULL, -- HORIZONTE, TOLERANCIA_RISCO, CONHECIMENTO, LIQUIDEZ
    ativo               BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS suitability.opcao_resposta (
    id_opcao            SERIAL PRIMARY KEY,
    id_pergunta         INT NOT NULL REFERENCES suitability.pergunta(id_pergunta) ON DELETE CASCADE,
    ordem               INT NOT NULL,
    texto_resposta      TEXT NOT NULL,
    pontuacao_peso      INT NOT NULL, -- Pontos atribuídos (ex: 1 a 10)
    UNIQUE (id_pergunta, ordem)
);

CREATE TABLE IF NOT EXISTS suitability.categoria_risco (
    id_categoria        SERIAL PRIMARY KEY,
    codigo              VARCHAR(30) NOT NULL UNIQUE, -- CONSERVADOR, MODERADO, ARROJADO
    nome                VARCHAR(60) NOT NULL,
    score_min           INT NOT NULL,
    score_max           INT NOT NULL,
    descricao           TEXT NOT NULL,
    alocacao_alvo_json  JSONB NOT NULL -- { "renda_fixa": 45, "fiis": 30, "acoes": 20, "internacional": 5 }
);

CREATE TABLE IF NOT EXISTS suitability.historico_respostas_usuario (
    id_avaliacao        BIGSERIAL PRIMARY KEY,
    id_usuario          UUID REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    score_total         INT NOT NULL,
    id_categoria        INT NOT NULL REFERENCES suitability.categoria_risco(id_categoria),
    respostas_json      JSONB NOT NULL,
    data_avaliacao      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 7. TARIFAS DE CORRETORAS E PLATAFORMAS (EXPANSÃO core.instituicao_financeira)
-- ----------------------------------------------------------------------------

ALTER TABLE core.instituicao_financeira
    ADD COLUMN IF NOT EXISTS taxa_corretagem_acoes     NUMERIC(8,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS taxa_corretagem_fiis      NUMERIC(8,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS taxa_corretagem_opcoes    NUMERIC(8,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS custodia_mensal           NUMERIC(8,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS spread_cambial_ptax_pct   NUMERIC(5,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS plataformas_suportadas    TEXT[] DEFAULT ARRAY['Home Broker']::TEXT[],
    ADD COLUMN IF NOT EXISTS is_internacional          BOOLEAN DEFAULT FALSE;

-- ----------------------------------------------------------------------------
-- 8. ASSINATURAS, ENTITLEMENTS E WEBHOOKS IDEMPOTENTES
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS system.plano_entitlement (
    id_entitlement      SERIAL PRIMARY KEY,
    id_plano            INT NOT NULL REFERENCES system.plano(id_plano) ON DELETE CASCADE,
    recurso_chave       VARCHAR(60) NOT NULL, -- VALUATION_GRAHAM, MAPA_DIVIDENDOS, ALERTAS_TELEGRAM, EXPORT_EXCEL
    permitido           BOOLEAN NOT NULL DEFAULT TRUE,
    limite_mensal       INT, -- NULL = Ilimitado
    UNIQUE (id_plano, recurso_chave)
);

CREATE TABLE IF NOT EXISTS system.webhook_evento_processado (
    id_evento_gateway   VARCHAR(120) PRIMARY KEY, -- ID enviado pelo Asaas / Stripe
    gateway             VARCHAR(30) NOT NULL,
    tipo_evento         VARCHAR(80) NOT NULL,
    payload_json        JSONB NOT NULL,
    processado_com_sucesso BOOLEAN NOT NULL DEFAULT FALSE,
    mensagem_erro       TEXT,
    recebido_em         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processado_em       TIMESTAMPTZ
);

-- ============================================================================
-- SEEDS ESSENCIAIS PARA ANÁLISE DE AÇÕES (GLOSSÁRIO, LIVROS, SUITABILITY, CORRETORAS)
-- ============================================================================

-- A. GLOSSÁRIO TÉCNICO
INSERT INTO cms.termo_glossario (slug, termo, categoria, definicao_curta, conteudo_markdown, formula_latex)
VALUES 
('preco-justo-de-graham', 'Preço Justo de Graham', 'Valuation', 
 'Fórmula clássica de Benjamin Graham para avaliar o valor intrínseco de uma ação equilibrando lucro e patrimônio líquido.',
 'O Preço Justo de Graham é um modelo conservador de valuation que busca encontrar o valor máximo razoável a pagar por uma empresa de valor. A premissa central é que o investidor não deve pagar mais de 15 vezes os lucros (P/L <= 15) nem mais de 1.5 vezes o valor patrimonial (P/VP <= 1.5). Multiplicando 15 por 1.5 obtém-se o multiplicador histórico de 22.5.',
 'V = \sqrt{22.5 \cdot \text{LPA} \cdot \text{VPA}}')
ON CONFLICT (slug) DO UPDATE SET termo = EXCLUDED.termo;

INSERT INTO cms.termo_glossario (slug, termo, categoria, definicao_curta, conteudo_markdown, formula_latex)
VALUES 
('preco-teto-de-bazin', 'Preço Teto de Bazin', 'Valuation', 
 'Método de Décio Bazin para determinar o valor máximo de compra com base em um dividend yield mínimo de 6% ao ano.',
 'Criado pelo jornalista e investidor brasileiro Décio Bazin, o Preço Teto busca garantir uma rentabilidade mínima contínua de proventos. Divide-se a média ponderada de proventos dos últimos anos por 6% (taxa mínima de atratividade que superava historicamente a poupança). Se a cotação estiver abaixo do Preço Teto, há margem de segurança.',
 'P_{\text{teto}} = \frac{\bar{D}_{5\text{a}}}{0.06}')
ON CONFLICT (slug) DO UPDATE SET termo = EXCLUDED.termo;

INSERT INTO cms.termo_glossario (slug, termo, categoria, definicao_curta, conteudo_markdown, formula_latex)
VALUES 
('ffo-funds-from-operations', 'Funds From Operations (FFO)', 'REITs', 
 'Métrica contábil padrão Nareit para medir o fluxo de caixa operacional real de um Real Estate Investment Trust.',
 'Como os REITs possuem depreciação imobiliária contábil expressiva sem saída efetiva de caixa, o lucro líquido GAAP não reflete o caixa distribuível. O FFO adiciona a depreciação e amortização imobiliária de volta ao Lucro Líquido e subtrai ganhos na venda de imóveis.',
 '\text{FFO} = \text{Lucro Líquido} + \text{Depreciação/Amortização} - \text{Ganhos na Venda de Propriedades}')
ON CONFLICT (slug) DO UPDATE SET termo = EXCLUDED.termo;

INSERT INTO cms.termo_glossario (slug, termo, categoria, definicao_curta, conteudo_markdown, formula_latex)
VALUES 
('numero-magico-magic-number', 'Número Mágico (Magic Number)', 'Fundos Imobiliários', 
 'Quantidade de cotas necessária para que os proventos mensais comprem autonomamente 1 nova cota do ativo.',
 'O conceito de Número Mágico define o ponto de inflexão de independência financeira em que a carteira se torna autoalimentável. A partir deste ponto, o reinvestimento de proventos não depende mais de novos aportes externos para crescer exponencialmente.',
 'Q^* = \left\lceil \frac{P_{\text{cota}}}{d_{\text{mensal}}} \right\rceil')
ON CONFLICT (slug) DO UPDATE SET termo = EXCLUDED.termo;

INSERT INTO cms.termo_glossario (slug, termo, categoria, definicao_curta, conteudo_markdown, formula_latex)
VALUES 
('withholding-tax-irs', 'Withholding Tax (IRS 30%)', 'Tributação Internacional', 
 'Alíquota tributária retida automaticamente na fonte pelo governo norte-americano sobre dividendos pagos a não-residentes.',
 'Investidores brasileiros que recebem dividendos de empresas ou REITs sediados nos EUA sofrem retenção automática de 30% na fonte pelo IRS. O tratado bilateral Brasil-EUA não abrange alíquota reduzida para não-residentes em proventos de carteira.',
 '\text{Dividendo Líquido USD} = \text{Dividendo Bruto} \cdot (1 - 0.30)')
ON CONFLICT (slug) DO UPDATE SET termo = EXCLUDED.termo;

-- B. LIVROS DE INVESTIMENTO RECOMENDADOS
INSERT INTO cms.livro_investimento (slug, titulo, subtitulo, autor, editora, ano_publicacao, nivel_dificuldade, categoria, resenha_markdown, principais_licoes, avaliacao_media)
VALUES 
('o-investidor-inteligente', 'O Investidor Inteligente', 'O guia definitivo para investimento em valor', 'Benjamin Graham', 'HarperCollins', 2016, 'INTERMEDIARIO', 'Valuation & Análise Fundamentalista',
 'Considerado a bíblia do Value Investing e elogiado por Warren Buffett como o melhor livro de finanças já escrito, ensina a diferença entre investimento e especulação, a parábola do Sr. Mercado e a importância da Margem de Segurança.',
 '["A margem de segurança é o conceito central de qualquer investimento sensato.", "O Sr. Mercado oscila entre a euforia e a depressão; use o humor dele a seu favor.", "Distinga sempre o investidor defensivo do investidor empreendedor."]'::jsonb, 4.95)
ON CONFLICT (slug) DO UPDATE SET titulo = EXCLUDED.titulo;

INSERT INTO cms.livro_investimento (slug, titulo, subtitulo, autor, editora, ano_publicacao, nivel_dificuldade, categoria, resenha_markdown, principais_licoes, avaliacao_media)
VALUES 
('faca-fortuna-com-acoes', 'Faça Fortuna com Ações', 'Antes que seja tarde', 'Décio Bazin', 'Cla Cultural', 2008, 'INICIANTE', 'Ações & Dividendos B3',
 'O clássico brasileiro que popularizou a estratégia do Método Bazin na Bolsa de Valores de São Paulo. Bazin estabelece critérios objetivos baseados em dividend yield mínimo de 6%, endividamento equilibrado e notícias transparentes.',
 '["Invista apenas em empresas que pagaram dividend yield médio acima de 6% nos últimos três anos.", "Elimine empresas com dívidas excessivas ou envolvidas em escândalos de governança.", "Reinvista 100% dos dividendos recebidos no período de acumulação."]'::jsonb, 4.88)
ON CONFLICT (slug) DO UPDATE SET titulo = EXCLUDED.titulo;

INSERT INTO cms.livro_investimento (slug, titulo, subtitulo, autor, editora, ano_publicacao, nivel_dificuldade, categoria, resenha_markdown, principais_licoes, avaliacao_media)
VALUES 
('a-psicologia-financeira', 'A Psicologia Financeira', 'Lições atemporais sobre fortuna, ganância e felicidade', 'Morgan Housel', 'HarperCollins', 2021, 'INICIANTE', 'Comportamento & Mindset',
 'Mostra que o sucesso financeiro depende muito mais do seu comportamento emocional do que de inteligência matemática. Aborda como manter a calma em crises de mercado e a importância da margem de erro.',
 '["O gênio financeiro que perde o controle emocional pode quebrar rapidamente.", "Riqueza é o que você não vê: os carros não comprados e os relógios não ostentados.", "Sobrevivência financeira no longo prazo exige amar o poder dos juros compostos."]'::jsonb, 4.92)
ON CONFLICT (slug) DO UPDATE SET titulo = EXCLUDED.titulo;

INSERT INTO cms.artigo_blog (slug, titulo, subtitulo, autor_nome, categoria, tags, conteudo_markdown, tempo_leitura_min, is_premium, status, publicado_em)
VALUES 
('como-analisar-bancos-margem-financeira-basileia', 'Como Analisar Ações de Bancos na B3', 'Entenda Índice de Basileia, Margem Financeira Líquida e Custo de Crédito', 'Equipe Quant', 'AÇÕES', ARRAY['Bancos', 'Valuation'], 'Conteúdo educacional para análise bancária.', 8, FALSE, 'PUBLICADO', NOW()),
('tributacao-reits-dividendos-ir-30-por-cento', 'Tributação de REITs Americanos para Brasileiros', 'O impacto do Withholding Tax de 30% do IRS e como calcular o Yield Líquido Real', 'Mesa Internacional', 'REITS', ARRAY['REITs', 'Tributação', 'IRS'], 'Guia prático da alíquota de 30% do imposto retido na fonte nos EUA.', 6, TRUE, 'PUBLICADO', NOW())
ON CONFLICT (slug) DO UPDATE SET titulo = EXCLUDED.titulo;

-- C. SUITABILITY: CATEGORIAS DE RISCO & PERGUNTAS PONDERADAS (CVM 30)
INSERT INTO suitability.categoria_risco (codigo, nome, score_min, score_max, descricao, alocacao_alvo_json)
VALUES 
('CONSERVADOR', 'Perfil Conservador', 0, 35, 
 'Prioriza a preservação total de capital e a previsibilidade de retorno com baixa tolerância a oscilações temporárias.',
 '{"renda_fixa": 80, "fiis": 15, "acoes": 5, "internacional": 0}'::jsonb),
('MODERADO', 'Perfil Moderado', 36, 70, 
 'Equilibra segurança e crescimento de patrimônio no médio/longo prazo, tolerando volatilidade moderada em troca de dividendos.',
 '{"renda_fixa": 45, "fiis": 30, "acoes": 20, "internacional": 5}'::jsonb),
('ARROJADO', 'Perfil Arrojado', 71, 100, 
 'Focado em maximização de patrimônio e geração de renda futura, tolerando oscilações acentuadas de mercado no curto prazo.',
 '{"renda_fixa": 15, "fiis": 25, "acoes": 40, "internacional": 15, "cripto": 5}'::jsonb)
ON CONFLICT (codigo) DO UPDATE SET descricao = EXCLUDED.descricao;

INSERT INTO suitability.pergunta (ordem, titulo, descricao, eixo_analise)
VALUES 
(1, 'Por quanto tempo você pretende manter a maior parte dos seus recursos investidos?', 
 'O horizonte de tempo determina sua capacidade de superar ciclos de baixa do mercado.', 'HORIZONTE'),
(2, 'Como você reagiria se seus investimentos sofressem uma desvalorização de 20% em um mês de crise?', 
 'Sua reação emocional em momentos de estresse define sua tolerância real à volatilidade.', 'TOLERANCIA_RISCO'),
(3, 'Qual é o seu objetivo principal com seus investimentos?', 
 'Sua meta financeira determina a proporção ideal entre renda passiva e valorização.', 'OBJETIVO'),
(4, 'Qual é o seu nível de experiência com o mercado de capitais (ações, FIIs, derivativos)?', 
 'O conhecimento técnico protege o investidor contra erros operacionais e armadilhas.', 'CONHECIMENTO')
ON CONFLICT (ordem) DO UPDATE SET titulo = EXCLUDED.titulo;

-- Opções da Pergunta 1
INSERT INTO suitability.opcao_resposta (id_pergunta, ordem, texto_resposta, pontuacao_peso)
SELECT id_pergunta, 1, 'Menos de 1 ano (preciso de liquidez imediata para compras/emergência)', 2
FROM suitability.pergunta WHERE ordem = 1
ON CONFLICT (id_pergunta, ordem) DO UPDATE SET pontuacao_peso = EXCLUDED.pontuacao_peso;

INSERT INTO suitability.opcao_resposta (id_pergunta, ordem, texto_resposta, pontuacao_peso)
SELECT id_pergunta, 2, 'Entre 1 e 5 anos (médio prazo para aquisição de bens ou projetos)', 5
FROM suitability.pergunta WHERE ordem = 1
ON CONFLICT (id_pergunta, ordem) DO UPDATE SET pontuacao_peso = EXCLUDED.pontuacao_peso;

INSERT INTO suitability.opcao_resposta (id_pergunta, ordem, texto_resposta, pontuacao_peso)
SELECT id_pergunta, 3, 'Acima de 5 anos (construção de patrimônio e previdência/liberdade financeira)', 10
FROM suitability.pergunta WHERE ordem = 1
ON CONFLICT (id_pergunta, ordem) DO UPDATE SET pontuacao_peso = EXCLUDED.pontuacao_peso;

-- Opções da Pergunta 2
INSERT INTO suitability.opcao_resposta (id_pergunta, ordem, texto_resposta, pontuacao_peso)
SELECT id_pergunta, 1, 'Entraria em pânico e resgataria imediatamente todo o dinheiro restante para não perder mais.', 1
FROM suitability.pergunta WHERE ordem = 2
ON CONFLICT (id_pergunta, ordem) DO UPDATE SET pontuacao_peso = EXCLUDED.pontuacao_peso;

INSERT INTO suitability.opcao_resposta (id_pergunta, ordem, texto_resposta, pontuacao_peso)
SELECT id_pergunta, 2, 'Ficaria apreensivo, mas manteria a posição aguardando a recuperação sem vender.', 5
FROM suitability.pergunta WHERE ordem = 2
ON CONFLICT (id_pergunta, ordem) DO UPDATE SET pontuacao_peso = EXCLUDED.pontuacao_peso;

INSERT INTO suitability.opcao_resposta (id_pergunta, ordem, texto_resposta, pontuacao_peso)
SELECT id_pergunta, 3, 'Enxergaria como uma liquidação e compraria mais ativos com desconto e maior dividend yield.', 10
FROM suitability.pergunta WHERE ordem = 2
ON CONFLICT (id_pergunta, ordem) DO UPDATE SET pontuacao_peso = EXCLUDED.pontuacao_peso;

-- Opções da Pergunta 3
INSERT INTO suitability.opcao_resposta (id_pergunta, ordem, texto_resposta, pontuacao_peso)
SELECT id_pergunta, 1, 'Preservar meu capital a qualquer custo, mesmo que o rendimento seja modesto.', 2
FROM suitability.pergunta WHERE ordem = 3
ON CONFLICT (id_pergunta, ordem) DO UPDATE SET pontuacao_peso = EXCLUDED.pontuacao_peso;

INSERT INTO suitability.opcao_resposta (id_pergunta, ordem, texto_resposta, pontuacao_peso)
SELECT id_pergunta, 2, 'Obter renda passiva previsível e regular através de dividendos e juros sobre capital.', 6
FROM suitability.pergunta WHERE ordem = 3
ON CONFLICT (id_pergunta, ordem) DO UPDATE SET pontuacao_peso = EXCLUDED.pontuacao_peso;

INSERT INTO suitability.opcao_resposta (id_pergunta, ordem, texto_resposta, pontuacao_peso)
SELECT id_pergunta, 3, 'Multiplicar meu patrimônio no longo prazo com foco em empresas de alto crescimento.', 10
FROM suitability.pergunta WHERE ordem = 3
ON CONFLICT (id_pergunta, ordem) DO UPDATE SET pontuacao_peso = EXCLUDED.pontuacao_peso;

-- Opções da Pergunta 4
INSERT INTO suitability.opcao_resposta (id_pergunta, ordem, texto_resposta, pontuacao_peso)
SELECT id_pergunta, 1, 'Iniciante: nunca investi ou apenas utilizei caderneta de poupança.', 2
FROM suitability.pergunta WHERE ordem = 4
ON CONFLICT (id_pergunta, ordem) DO UPDATE SET pontuacao_peso = EXCLUDED.pontuacao_peso;

INSERT INTO suitability.opcao_resposta (id_pergunta, ordem, texto_resposta, pontuacao_peso)
SELECT id_pergunta, 2, 'Intermediário: já invisto em Tesouro Direto, CDBs e alguns Fundos Imobiliários.', 6
FROM suitability.pergunta WHERE ordem = 4
ON CONFLICT (id_pergunta, ordem) DO UPDATE SET pontuacao_peso = EXCLUDED.pontuacao_peso;

INSERT INTO suitability.opcao_resposta (id_pergunta, ordem, texto_resposta, pontuacao_peso)
SELECT id_pergunta, 3, 'Avançado: opero ações, analiso balanços trimestrais e invisto no exterior.', 10
FROM suitability.pergunta WHERE ordem = 4
ON CONFLICT (id_pergunta, ordem) DO UPDATE SET pontuacao_peso = EXCLUDED.pontuacao_peso;

-- D. CORRETORAS COM TARIFAS E SPREADS
INSERT INTO core.instituicao_financeira (nome_instituicao, tipo, cnpj, taxa_corretagem_acoes, taxa_corretagem_fiis, taxa_corretagem_opcoes, custodia_mensal, spread_cambial_ptax_pct, plataformas_suportadas, is_internacional, nota_geral, total_avaliacoes)
VALUES 
('BTG Pactual', 'CORRETORA', '30306294000145', 0.00, 0.00, 0.00, 0.00, 1.20, ARRAY['Home Broker', 'Profit Pro', 'TradingView', 'BTG Trader']::TEXT[], FALSE, 4.90, 1250)
ON CONFLICT (cnpj) DO UPDATE SET taxa_corretagem_acoes = EXCLUDED.taxa_corretagem_acoes, spread_cambial_ptax_pct = EXCLUDED.spread_cambial_ptax_pct;

INSERT INTO core.instituicao_financeira (nome_instituicao, tipo, cnpj, taxa_corretagem_acoes, taxa_corretagem_fiis, taxa_corretagem_opcoes, custodia_mensal, spread_cambial_ptax_pct, plataformas_suportadas, is_internacional, nota_geral, total_avaliacoes)
VALUES 
('XP Investimentos', 'CORRETORA', '02332886000104', 4.90, 0.00, 4.90, 0.00, 1.50, ARRAY['Home Broker', 'Profit Pro', 'TradingView']::TEXT[], FALSE, 4.75, 2340)
ON CONFLICT (cnpj) DO UPDATE SET taxa_corretagem_acoes = EXCLUDED.taxa_corretagem_acoes, spread_cambial_ptax_pct = EXCLUDED.spread_cambial_ptax_pct;

INSERT INTO core.instituicao_financeira (nome_instituicao, tipo, cnpj, taxa_corretagem_acoes, taxa_corretagem_fiis, taxa_corretagem_opcoes, custodia_mensal, spread_cambial_ptax_pct, plataformas_suportadas, is_internacional, nota_geral, total_avaliacoes)
VALUES 
('Avenue Securities', 'CORRETORA', '00000000000199', 0.00, 0.00, 0.00, 0.00, 1.40, ARRAY['Avenue Web', 'Avenue App']::TEXT[], TRUE, 4.80, 890)
ON CONFLICT (cnpj) DO UPDATE SET taxa_corretagem_acoes = EXCLUDED.taxa_corretagem_acoes, spread_cambial_ptax_pct = EXCLUDED.spread_cambial_ptax_pct;

INSERT INTO core.instituicao_financeira (nome_instituicao, tipo, cnpj, taxa_corretagem_acoes, taxa_corretagem_fiis, taxa_corretagem_opcoes, custodia_mensal, spread_cambial_ptax_pct, plataformas_suportadas, is_internacional, nota_geral, total_avaliacoes)
VALUES 
('Clear Corretora', 'CORRETORA', '02332886000105', 0.00, 0.00, 0.00, 0.00, 0.00, ARRAY['Home Broker', 'Profit Clear']::TEXT[], FALSE, 4.40, 1890)
ON CONFLICT (cnpj) DO UPDATE SET taxa_corretagem_acoes = EXCLUDED.taxa_corretagem_acoes, spread_cambial_ptax_pct = EXCLUDED.spread_cambial_ptax_pct;

-- E. ATIVOS INTERNACIONAIS (STOCKS EUA & REITS) EM core.ativo
INSERT INTO core.ativo (ticker, tipo_ativo, moeda)
VALUES 
('AAPL', 'STOCK_EXTERIOR', 'USD'),
('MSFT', 'STOCK_EXTERIOR', 'USD'),
('O', 'REIT', 'USD'),
('PLD', 'REIT', 'USD')
ON CONFLICT (ticker) DO UPDATE SET moeda = EXCLUDED.moeda;

-- Detalhes dos REITs
INSERT INTO asset_details.detalhe_reit (id_ativo, subtipo_reit, ffo_12m, affo_12m, ffo_por_acao, affo_por_acao, p_ffo, p_affo, ffo_payout_ratio, taxa_ocupacao_pct, total_propriedades, alavancagem_divida_ev, withholding_tax_pct)
SELECT id_ativo, 'Retail Net Lease', 3450000000.00, 3120000000.00, 4.12, 3.75, 12.80, 14.10, 76.50, 98.70, 15450, 32.50, 30.00
FROM core.ativo WHERE ticker = 'O'
ON CONFLICT (id_ativo) DO UPDATE SET p_ffo = EXCLUDED.p_ffo;

INSERT INTO asset_details.detalhe_reit (id_ativo, subtipo_reit, ffo_12m, affo_12m, ffo_por_acao, affo_por_acao, p_ffo, p_affo, ffo_payout_ratio, taxa_ocupacao_pct, total_propriedades, alavancagem_divida_ev, withholding_tax_pct)
SELECT id_ativo, 'Industrial Logistics', 5200000000.00, 4800000000.00, 5.56, 5.12, 19.40, 21.10, 68.20, 97.40, 5600, 24.10, 30.00
FROM core.ativo WHERE ticker = 'PLD'
ON CONFLICT (id_ativo) DO UPDATE SET p_ffo = EXCLUDED.p_ffo;

-- F. CÂMBIO PTAX DE REFERÊNCIA
INSERT INTO market.cotacao_cambio_diaria (data_cambio, moeda_origem, moeda_destino, taxa_compra, taxa_venda, boletim)
VALUES 
('2026-10-27', 'USD', 'BRL', 5.352000, 5.352600, 'FECHAMENTO'),
('2026-10-26', 'USD', 'BRL', 5.348000, 5.348600, 'FECHAMENTO')
ON CONFLICT (data_cambio, moeda_origem, moeda_destino) DO NOTHING;

-- G. SEEDS DO MAPA DE SAZONALIDADE (HISTÓRICO 5 ANOS)
INSERT INTO analytics.mapa_sazonalidade_dividendo (id_ativo, mes_calendario, tipo_evento, ocorrencias_historicas, anos_analisados, valor_medio_provento, yield_medio_mensal, ultimo_ano_pago)
SELECT id_ativo, 4, 'DATA_COM', 5, 5, 2.450000, 0.0520, 2026 FROM core.ativo WHERE ticker = 'PETR4'
ON CONFLICT (id_ativo, mes_calendario, tipo_evento) DO UPDATE SET ocorrencias_historicas = EXCLUDED.ocorrencias_historicas;

INSERT INTO analytics.mapa_sazonalidade_dividendo (id_ativo, mes_calendario, tipo_evento, ocorrencias_historicas, anos_analisados, valor_medio_provento, yield_medio_mensal, ultimo_ano_pago)
SELECT id_ativo, 8, 'DATA_COM', 5, 5, 1.850000, 0.0410, 2026 FROM core.ativo WHERE ticker = 'PETR4'
ON CONFLICT (id_ativo, mes_calendario, tipo_evento) DO UPDATE SET ocorrencias_historicas = EXCLUDED.ocorrencias_historicas;

INSERT INTO analytics.mapa_sazonalidade_dividendo (id_ativo, mes_calendario, tipo_evento, ocorrencias_historicas, anos_analisados, valor_medio_provento, yield_medio_mensal, ultimo_ano_pago)
SELECT id_ativo, 12, 'DATA_COM', 4, 5, 1.150000, 0.0280, 2025 FROM core.ativo WHERE ticker = 'PETR4'
ON CONFLICT (id_ativo, mes_calendario, tipo_evento) DO UPDATE SET ocorrencias_historicas = EXCLUDED.ocorrencias_historicas;

INSERT INTO analytics.mapa_sazonalidade_dividendo (id_ativo, mes_calendario, tipo_evento, ocorrencias_historicas, anos_analisados, valor_medio_provento, yield_medio_mensal, ultimo_ano_pago)
SELECT id_ativo, 3, 'DATA_COM', 5, 5, 3.200000, 0.0480, 2026 FROM core.ativo WHERE ticker = 'VALE3'
ON CONFLICT (id_ativo, mes_calendario, tipo_evento) DO UPDATE SET ocorrencias_historicas = EXCLUDED.ocorrencias_historicas;

INSERT INTO analytics.mapa_sazonalidade_dividendo (id_ativo, mes_calendario, tipo_evento, ocorrencias_historicas, anos_analisados, valor_medio_provento, yield_medio_mensal, ultimo_ano_pago)
SELECT id_ativo, 8, 'DATA_COM', 5, 5, 2.800000, 0.0420, 2026 FROM core.ativo WHERE ticker = 'VALE3'
ON CONFLICT (id_ativo, mes_calendario, tipo_evento) DO UPDATE SET ocorrencias_historicas = EXCLUDED.ocorrencias_historicas;

-- FIIs com distribuição em todos os meses
DO $$
DECLARE
    fii_id INT;
    m INT;
BEGIN
    SELECT id_ativo INTO fii_id FROM core.ativo WHERE ticker = 'HGLG11';
    IF fii_id IS NOT NULL THEN
        FOR m IN 1..12 LOOP
            INSERT INTO analytics.mapa_sazonalidade_dividendo (id_ativo, mes_calendario, tipo_evento, ocorrencias_historicas, anos_analisados, valor_medio_provento, yield_medio_mensal, ultimo_ano_pago)
            VALUES (fii_id, m, 'DATA_COM', 5, 5, 1.10, 0.0068, 2026)
            ON CONFLICT (id_ativo, mes_calendario, tipo_evento) DO UPDATE SET ocorrencias_historicas = EXCLUDED.ocorrencias_historicas;
        END LOOP;
    END IF;
    
    SELECT id_ativo INTO fii_id FROM core.ativo WHERE ticker = 'MXRF11';
    IF fii_id IS NOT NULL THEN
        FOR m IN 1..12 LOOP
            INSERT INTO analytics.mapa_sazonalidade_dividendo (id_ativo, mes_calendario, tipo_evento, ocorrencias_historicas, anos_analisados, valor_medio_provento, yield_medio_mensal, ultimo_ano_pago)
            VALUES (fii_id, m, 'DATA_COM', 5, 5, 0.10, 0.0095, 2026)
            ON CONFLICT (id_ativo, mes_calendario, tipo_evento) DO UPDATE SET ocorrencias_historicas = EXCLUDED.ocorrencias_historicas;
        END LOOP;
    END IF;

    SELECT id_ativo INTO fii_id FROM core.ativo WHERE ticker = 'O';
    IF fii_id IS NOT NULL THEN
        FOR m IN 1..12 LOOP
            INSERT INTO analytics.mapa_sazonalidade_dividendo (id_ativo, mes_calendario, tipo_evento, ocorrencias_historicas, anos_analisados, valor_medio_provento, yield_medio_mensal, ultimo_ano_pago)
            VALUES (fii_id, m, 'DATA_COM', 5, 5, 0.26, 0.0048, 2026)
            ON CONFLICT (id_ativo, mes_calendario, tipo_evento) DO UPDATE SET ocorrencias_historicas = EXCLUDED.ocorrencias_historicas;
        END LOOP;
    END IF;
END $$;
