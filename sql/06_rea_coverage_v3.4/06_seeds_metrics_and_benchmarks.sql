-- =========================================================
-- ESTÁGIO 06 (v3.4) - PARTE 6: SEEDS DE MÉTRICAS CANÔNICAS E BENCHMARKS (ANBIMA, TEVA, B3)
-- Cobertura REA: Todas as 12 plataformas analisadas
-- Estritamente idempotente (ON CONFLICT DO NOTHING)
-- =========================================================

-- 1. Novos Indicadores em canonical.metric_definition descobertos no REA dos 12 sites
INSERT INTO canonical.metric_definition (code, name, description, default_unit, category, higher_is_better) VALUES
    -- Múltiplos de Valuation e Fluxo de Caixa (Status Invest, Investidor10, Fundamentus, Fundamentei, Análise de Ações, ADVFN)
    ('PEG_RATIO', 'PEG Ratio', 'Price/Earnings to Growth (P/L dividido pelo crescimento esperado/histórico de lucros)', 'ratio', 'valuation', false),
    ('P_EBITDA', 'Preço / EBITDA', 'Cotação da ação dividida pelo EBITDA por ação', 'ratio', 'valuation', false),
    ('P_EBIT', 'Preço / EBIT', 'Cotação da ação dividida pelo EBIT por ação', 'ratio', 'valuation', false),
    ('P_ATIVO', 'Preço / Ativo Total', 'Valor de mercado dividido pelo Ativo Total da companhia', 'ratio', 'valuation', false),
    ('P_CAP_GIRO', 'Preço / Capital de Giro', 'Valor de mercado dividido pelo Capital de Giro (Ativo Circulante - Passivo Circulante)', 'ratio', 'valuation', false),
    ('P_ATIVO_CIRC_LIQ', 'Preço / Ativo Circulante Líquido', 'Valor de mercado dividido pelo Ativo Circulante líquido de todos os passivos (NCAV de Graham)', 'ratio', 'valuation', false),
    ('P_FCO', 'Preço / Fluxo de Caixa Operacional', 'Valor de mercado dividido pelo Fluxo de Caixa Operacional (FCO)', 'ratio', 'valuation', false),
    ('P_FCL', 'Preço / Fluxo de Caixa Livre', 'Valor de mercado dividido pelo Fluxo de Caixa Livre (FCL)', 'ratio', 'valuation', false),
    ('EV_RECEITA', 'EV / Receita Líquida', 'Enterprise Value dividido pela Receita Líquida anual', 'ratio', 'valuation', false),
    ('VPTA', 'Valor Patrimonial Tangível por Ação', 'Patrimônio Líquido excluindo intangíveis e ágio dividido pelo total de ações', 'currency', 'valuation', true),
    ('BUYBACK_YIELD', 'Buyback Yield', 'Volume financeiro recomprado em 12 meses dividido pelo Valor de Mercado', 'percent', 'yield', true),
    ('TOTAL_YIELD', 'Total Shareholder Yield', 'Soma do Dividend Yield com o Buyback Yield nos últimos 12 meses', 'percent', 'yield', true),
    ('EARNINGS_YIELD', 'Earnings Yield (L/P ou EBIT/EV)', 'Inverso do P/L ou EBIT dividido pelo Enterprise Value', 'percent', 'yield', true),

    -- Endividamento, Liquidez e Estrutura de Capital
    ('DIVIDA_LIQ_EBIT', 'Dívida Líquida / EBIT', 'Dívida líquida dividida pelo EBIT acumulado em 12 meses', 'ratio', 'debt', false),
    ('DIVIDA_BRUTA_PL', 'Dívida Bruta / Patrimônio Líquido', 'Dívida bruta total dividida pelo Patrimônio Líquido', 'ratio', 'debt', false),
    ('PATRIMONIO_ATIVOS', 'Patrimônio / Ativos', 'Patrimônio Líquido dividido pelo Ativo Total', 'percent', 'debt', true),
    ('PASSIVOS_ATIVOS', 'Passivos / Ativos', 'Passivo Total dividido pelo Ativo Total', 'percent', 'debt', false),
    ('LIQUIDEZ_SECA', 'Liquidez Seca', '(Ativo Circulante - Estoques) / Passivo Circulante', 'ratio', 'liquidity', true),
    ('LIQUIDEZ_IMEDIATA', 'Liquidez Imediata', 'Disponibilidades de Caixa / Passivo Circulante', 'ratio', 'liquidity', true),
    ('COBERTURA_JUROS', 'Índice de Cobertura de Juros', 'EBIT dividido pelas Despesas Financeiras', 'ratio', 'debt', true),
    ('GIRO_ATIVOS', 'Giro do Ativo', 'Receita Líquida anual dividida pelo Ativo Total médio', 'ratio', 'efficiency', true),
    ('CAPEX_FCO', 'Capex / Fluxo de Caixa Operacional', 'Proporção do Fluxo de Caixa Operacional consumida por investimentos em Capex', 'percent', 'efficiency', false),
    ('FCL_LUCRO_LIQUIDO', 'Fluxo de Caixa Livre / Lucro Líquido', 'Conversão de lucro contábil em Fluxo de Caixa Livre (Cash Conversion)', 'percent', 'efficiency', true),

    -- Indicadores Bancários e Seguradoras (Fundamentei, Investidor10, Status Invest)
    ('INDICE_BASILEIA', 'Índice de Basileia', 'Capital regulatório dividido pelos ativos ponderados pelo risco (RWA)', 'percent', 'banking', true),
    ('INDICE_IMOBILIZACAO', 'Índice de Imobilização', 'Ativo Permanente dividido pelo Patrimônio de Referência', 'percent', 'banking', false),
    ('INDICE_EFICIENCIA_BANCARIA', 'Índice de Eficiência Bancária', 'Despesas Administrativas e de Pessoal divididas pela Margem Financeira e Receita de Serviços', 'percent', 'banking', false),
    ('NIM_MARGEM_FINANCEIRA', 'Margem Financeira Líquida (NIM)', 'Resultado da Intermediação Financeira sobre ativos geradores de juros', 'percent', 'banking', true),
    ('INADIMPLENCIA_90D', 'Índice de Inadimplência > 90 dias (NPL)', 'Operações de crédito vencidas há mais de 90 dias sobre o total da carteira de crédito', 'percent', 'banking', false),
    ('COBERTURA_PDD', 'Índice de Cobertura de PDD', 'Provisão para Devedores Duvidosos sobre a carteira inadimplente acima de 90 dias', 'percent', 'banking', true),
    ('CUSTO_CREDITO', 'Custo do Crédito', 'Despesa de PDD anualizada dividida pela carteira de crédito média', 'percent', 'banking', false),
    ('SINISTRALIDADE', 'Índice de Sinistralidade (Loss Ratio)', 'Sinistros retidos divididos pelos prêmios ganhos (Seguradoras/Saúde)', 'percent', 'insurance', false),
    ('COMBINED_RATIO', 'Índice Combinado (Combined Ratio)', 'Soma de sinistralidade, despesas comerciais e administrativas sobre prêmios ganhos', 'percent', 'insurance', false),

    -- Governança e Remuneração Executiva (Status Invest, Fundamentei, Fundamentus)
    ('REMUNERACAO_EXEC_LUCRO', 'Remuneração da Diretoria / Lucro Líquido', 'Remuneração total anual dos administradores dividida pelo Lucro Líquido da companhia', 'percent', 'governance', false),
    ('FREE_FLOAT_ON', 'Free Float ON (%)', 'Percentual de ações ordinárias em livre circulação no mercado', 'percent', 'governance', true),
    ('FREE_FLOAT_PN', 'Free Float PN (%)', 'Percentual de ações preferenciais em livre circulação no mercado', 'percent', 'governance', true),
    ('TAG_ALONG_ON', 'Tag Along ON (%)', 'Percentual de proteção de Tag Along para ações ordinárias', 'percent', 'governance', true),
    ('TAG_ALONG_PN', 'Tag Along PN (%)', 'Percentual de proteção de Tag Along para ações preferenciais', 'percent', 'governance', true),
    ('RECLAME_AQUI_SCORE', 'Nota Reclame Aqui', 'Nota média de reputação da empresa/gestora no Reclame Aqui (0 a 10)', 'score', 'governance', true),

    -- Indicadores de FIIs e Mercado Imobiliário (Clube FII, Funds Explorer, FIIs.com.br, Brick360, Fundamentus)
    ('FII_DY_PATRIMONIAL', 'Dividend Yield Patrimonial (FII)', 'Rendimento distribuído dividido pelo Valor Patrimonial por Cota (VPC)', 'percent', 'fii', true),
    ('FII_RENTABILIDADE_PATRIMONIAL', 'Rentabilidade Patrimonial (FII)', 'Variação do VPC somada ao DY Patrimonial no período', 'percent', 'fii', true),
    ('FII_CAP_RATE', 'Cap Rate Imobiliário', 'Receita imobiliária anualizada dividida pelo valor de avaliação/mercado dos imóveis', 'percent', 'fii', true),
    ('FII_PRECO_M2', 'Preço por m² (FII)', 'Valor de mercado ou de laudo dos ativos imobiliários dividido pela ABL própria em m²', 'currency', 'fii', false),
    ('FII_ALUGUEL_M2', 'Aluguel por m² (FII)', 'Receita mensal de locação dividida pela ABL locada em m²', 'currency', 'fii', true),
    ('FII_INADIMPLENCIA', 'Taxa de Inadimplência (FII)', 'Percentual da receita contratada de aluguéis ou CRIs em atraso', 'percent', 'fii', false),
    ('FII_WAULT_PRAZO_CONTRATOS', 'Prazo Médio dos Contratos (WAULT)', 'Prazo médio ponderado de vencimento dos contratos de locação em anos', 'years', 'fii', true),
    ('FII_CONTRATOS_ATIPICOS_PCT', 'Percentual de Contratos Atípicos (BTS/SLB)', 'Proporção da receita imobiliária proveniente de contratos atípicos', 'percent', 'fii', true),
    ('FII_ALAVANCAGEM_PCT', 'Índice de Alavancagem (FII)', 'Obrigações por aquisição de imóveis e securitização divididas pelo Ativo Total do FII', 'percent', 'fii', false),
    ('FII_CAIXA_PL_PCT', 'Caixa / Patrimônio Líquido (FII)', 'Total de disponibilidades e renda fixa líquida dividido pelo Patrimônio Líquido do FII', 'percent', 'fii', true),
    ('FII_TAXA_ADM_RECEITA_PCT', 'Taxa de Administração / Receita Bruta (FII)', 'Despesa anual com taxa de administração dividida pela receita bruta do fundo', 'percent', 'fii', false),
    ('FII_TOP1_INQUILINO_PCT', 'Concentração no Maior Inquilino (%)', 'Percentual da receita total do FII proveniente do seu maior locatário/devedor', 'percent', 'fii', false),
    ('FII_CRI_DURATION', 'Duration Média da Carteira de CRIs', 'Prazo médio ponderado (duration de Macaulay/modificada) da carteira de CRIs em anos', 'years', 'fii', false),
    ('FII_CRI_LTV_MEDIO', 'LTV Médio da Carteira de CRIs', 'Loan-to-Value médio ponderado das garantias reais da carteira de CRIs', 'percent', 'fii', false),
    ('BRICK_SCORE_GLOBAL', 'Brick Score Global (0-100)', 'Score multidimensional de qualidade de FIIs (Financeiro, Imóveis, Inquilinos, Gestora, Riscos, Projeções)', 'score', 'fii', true),

    -- Indicadores de Fundos, ETFs e Risco Avançado (Mais Retorno, ETFs Brasil)
    ('ALFA_JENSEN', 'Alfa de Jensen', 'Retorno excedente ajustado ao risco sistemático (Beta) em relação ao benchmark', 'percent', 'risk', true),
    ('TRACKING_ERROR', 'Tracking Error', 'Desvio-padrão da diferença de retorno entre o ativo/ETF e seu índice de referência', 'percent', 'risk', false),
    ('INFORMATION_RATIO', 'Information Ratio', 'Retorno ativo acima do benchmark dividido pelo Tracking Error', 'ratio', 'risk', true),
    ('CONSISTENCIA_MESES_ACIMA_BENCH', 'Meses Acima do Benchmark', 'Quantidade ou percentual de meses em que o ativo superou o seu benchmark de referência', 'percent', 'risk', true),
    ('ROLLING_WIN_RATE', 'Taxa de Sucesso em Janelas Móveis', 'Percentual de janelas móveis históricas em que o fundo/ativo superou o benchmark', 'percent', 'risk', true),
    ('RECOVERY_TIME_DAYS', 'Tempo de Recuperação de Drawdown (Dias)', 'Número de dias úteis necessários para recuperar o topo histórico após o Max Drawdown', 'days', 'risk', false),
    ('ETF_TER_TOTAL', 'Taxa de Administração Total Efetiva (TER)', 'Soma da taxa de administração primária com a taxa secundária dos fundos investidos pelo ETF', 'percent', 'etf', false),
    ('ETF_PREMIO_DESCONTO_NAV', 'Prêmio / Desconto sobre o NAV (ETF)', 'Diferença percentual entre a cotação de mercado do ETF e o seu valor patrimonial intrínseco (NAV)', 'percent', 'etf', false),
    ('ETF_LIMITE_ALUGUEL_PL', 'Limite de Aluguel da Carteira (% PL)', 'Percentual máximo do patrimônio do ETF autorizado para empréstimo de ativos', 'percent', 'etf', true),
    ('ETF_FLUXO_LIQUIDO_30D', 'Fluxo Líquido de Capitais 30d (ETF)', 'Criação líquida menos resgate de cotas do ETF nos últimos 30 dias em moeda', 'currency', 'etf', true),

    -- Indicadores de Criptoativos / DeFi (Investidor10, Status Invest)
    ('CRYPTO_FDV', 'Fully Diluted Valuation (FDV)', 'Capitalização de mercado totalmente diluída considerando o fornecimento máximo de tokens', 'currency', 'crypto', false),
    ('CRYPTO_TVL', 'Total Value Locked (TVL)', 'Valor total bloqueado nos contratos inteligentes do protocolo DeFi', 'currency', 'crypto', true),
    ('CRYPTO_MCAP_TVL', 'Market Cap / TVL', 'Razão entre o valor de mercado do token e o valor total bloqueado (TVL) no protocolo', 'ratio', 'crypto', false)
ON CONFLICT (code) DO NOTHING;

-- 2. Novos Benchmarks Oficiais ANBIMA, B3 e Teva Indices em market.benchmark (Mais Retorno, ETFs Brasil)
INSERT INTO market.benchmark (codigo, nome, tipo, frequencia, fonte) VALUES
    -- Índices ANBIMA de Renda Fixa e Multimercados (Mais Retorno)
    ('IMA-B', 'Índice de Mercado ANBIMA - NTN-B Total', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IMA-B 5', 'Índice de Mercado ANBIMA - NTN-B até 5 anos', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IMA-B 5+', 'Índice de Mercado ANBIMA - NTN-B acima de 5 anos', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IMA-GERAL', 'Índice de Mercado ANBIMA Geral', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IMA-S', 'Índice de Mercado ANBIMA - LFT (Selic)', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IRF-M', 'Índice de Renda Fixa de Mercado ANBIMA (Prefixados)', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IRF-M 1', 'Índice de Renda Fixa de Mercado ANBIMA até 1 ano', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IRF-M 1+', 'Índice de Renda Fixa de Mercado ANBIMA acima de 1 ano', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IDA-GERAL', 'Índice de Debêntures ANBIMA Geral', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IDA-DI', 'Índice de Debêntures ANBIMA Indexadas ao DI', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IDA-IPCA', 'Índice de Debêntures ANBIMA Indexadas ao IPCA', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IDKA-IPCA 2A', 'Índice de Duração Constante ANBIMA IPCA 2 Anos', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IDKA-PRE 2A', 'Índice de Duração Constante ANBIMA Prefixado 2 Anos', 'INDICE', 'DIARIA', 'ANBIMA'),
    ('IHFA', 'Índice de Hedge Funds ANBIMA (Multimercados)', 'INDICE', 'DIARIA', 'ANBIMA'),

    -- Índices B3 Setoriais e de Governança (Mais Retorno, Status Invest, ETFs Brasil)
    ('IBXX', 'Índice Brasil 100 (IBrX 100)', 'INDICE', 'DIARIA', 'B3'),
    ('IBXL', 'Índice Brasil 50 (IBrX 50)', 'INDICE', 'DIARIA', 'B3'),
    ('IBRA', 'Índice Brasil Amplo (IBrA)', 'INDICE', 'DIARIA', 'B3'),
    ('IGCX', 'Índice de Ações com Governança Corporativa Diferenciada', 'INDICE', 'DIARIA', 'B3'),
    ('ITAG', 'Índice de Ações com Tag Along Diferenciado', 'INDICE', 'DIARIA', 'B3'),
    ('ISEE', 'Índice de Sustentabilidade Empresarial B3', 'INDICE', 'DIARIA', 'B3'),
    ('ICO2', 'Índice Carbono Eficiente B3', 'INDICE', 'DIARIA', 'B3'),
    ('ICON', 'Índice de Consumo B3', 'INDICE', 'DIARIA', 'B3'),
    ('IEEX', 'Índice de Energia Elétrica B3', 'INDICE', 'DIARIA', 'B3'),
    ('IFNC', 'Índice Financeiro B3', 'INDICE', 'DIARIA', 'B3'),
    ('IMOB', 'Índice Imobiliário B3', 'INDICE', 'DIARIA', 'B3'),
    ('INDX', 'Índice do Setor Industrial B3', 'INDICE', 'DIARIA', 'B3'),
    ('IMAT', 'Índice de Materiais Básicos B3', 'INDICE', 'DIARIA', 'B3'),
    ('UTIL', 'Índice Utilidade Pública B3', 'INDICE', 'DIARIA', 'B3'),
    ('MLCX', 'Índice MidLarge Cap B3', 'INDICE', 'DIARIA', 'B3'),
    ('BDRX', 'Índice de BDRs Não Patrocinados Global B3', 'INDICE', 'DIARIA', 'B3'),
    ('IFIL', 'Índice de Fundos de Investimentos Imobiliários de Alta Liquidez B3', 'INDICE', 'DIARIA', 'B3'),

    -- Índices Teva / ETFs Brasil (FIIs, Debêntures, Títulos Públicos, Ações)
    ('TEVA-FII-TIJOLO', 'Índice Teva Fundos Imobiliários de Tijolo', 'INDICE', 'DIARIA', 'TEVA'),
    ('TEVA-FII-PAPEL', 'Índice Teva Fundos Imobiliários de Papel (CRI)', 'INDICE', 'DIARIA', 'TEVA'),
    ('TEVA-FII-HIBRIDOS', 'Índice Teva Fundos Imobiliários Híbridos', 'INDICE', 'DIARIA', 'TEVA'),
    ('TEVA-DEB-DI', 'Índice Teva Debêntures DI', 'INDICE', 'DIARIA', 'TEVA'),
    ('TEVA-DEB-IPCA', 'Índice Teva Debêntures Incentivadas IPCA', 'INDICE', 'DIARIA', 'TEVA'),
    ('TEVA-DIVIDENDOS', 'Índice Teva Ações Dividendos', 'INDICE', 'DIARIA', 'TEVA'),
    ('NASDAQ100', 'Nasdaq-100 Index', 'INDICE', 'DIARIA', 'NASDAQ')
ON CONFLICT (codigo) DO NOTHING;
