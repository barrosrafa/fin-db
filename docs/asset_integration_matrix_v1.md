# Matriz de integração de ativos financeiros — fin-db v1

## 1. Objetivo e escopo

Este documento descreve, para cada classe de ativo suportada pelo repositório, as tabelas, campos de identificação, chaves, relacionamentos, cotações, eventos, proventos, holdings, analytics, carteira, raw/staging e serving envolvidos no cadastro e no ciclo de vida do ativo.

Classes cobertas:

- FII;
- ação brasileira;
- REIT;
- stock internacional;
- criptomoeda;
- ETF brasileiro;
- ETF internacional/UCITS;
- Tesouro Direto;
- renda fixa privada;
- BDR;
- índice;
- FIAGRO;
- FI-Infra;
- fundo de investimento genérico;
- opção e demais instrumentos relacionados.

A documentação é baseada exclusivamente no DDL existente no repositório. Não foram inventados endpoints, tabelas, campos ou dados.

## 2. Regra fundamental de identidade

O repositório atual possui duas linhagens de identidade. Elas devem ser consideradas no cadastro:

### 2.1 Identidade operacional — `core.ativo`

Arquivo: `sql/01_core_schema/01_core.sql:71-93`.

| Campo | Tipo/função |
|---|---|
| `id_ativo` | PK operacional `SERIAL`; é a FK usada por `market`, `asset_details`, `analytics`, carteira e DW legado |
| `id_emissor` | FK para `core.emissor_companhia(id_emissor)` |
| `ticker` | `UNIQUE NOT NULL`; código operacional, não adequado como identidade global para venues diferentes |
| `isin` | `UNIQUE`, quando disponível |
| `codigo_cetip` | `UNIQUE`, quando disponível |
| `tipo_ativo` | `core.tipo_ativo_enum` |
| `tipo_mercado` | `core.tipo_mercado_enum` |
| `moeda` | moeda de referência, default BRL |
| `data_ipo`, `data_inicio_negociacao` | datas de mercado |
| `data_vencimento`, `data_emissao` | principalmente renda fixa/títulos |
| `quantidade_emitida` | quantidade emitida |
| `volume_medio`, `liquidez` | métricas de liquidez |
| `indexador` | indexador de título/renda fixa |
| `mercado_balcao` | indica balcão |
| `segmento_listagem` | segmento de listagem |
| `tipo_titulo` | classificação textual de título |
| `canonical_instrument_id` | coluna adicionada por `19_merge_base_b`, FK opcional para `canonical.instrument` |

Valores observados em `core.tipo_ativo_enum`: `ACAO`, `FII`, `ETF`, `TESOURO`, `RENDA_FIXA`, `FUNDO`, `CRIPTO`, além de extensões como `REIT`, `STOCK_EXTERIOR`, `ETF_EXTERIOR`, `ETF_EUA`, `STOCK_EUA`, `FI_INFRA`, `BDR_ETF` e `INDICE`.

### 2.2 Identidade canônica — `canonical.instrument`

Arquivo: `sql/00_baseline/01_existing_canonical_raw_schema.sql:225-263`.

| Campo | Função |
|---|---|
| `instrument_id` | PK UUID canônica |
| `asset_class` | enum canônico: `EQUITY`, `FII`, `FIAGRO`, `FI_INFRA`, `FUND`, `ETF`, `BDR`, `REIT`, `OPTION`, `GOVERNMENT_BOND`, `FIXED_INCOME`, `CRYPTO`, `INDEX`, `FUTURE`, `OTHER` |
| `legal_entity_id` | FK lógica para entidade legal relacionada |
| `issuer_id` | emissor canônico |
| `name`, `short_name` | nomes do instrumento |
| `isin` | identificador internacional; `UNIQUE` no modelo atual |
| `currency_code` | moeda canônica |
| `venue_id` | bolsa/venue |
| `status` | `ACTIVE`, `INACTIVE`, `MATURED`, `UNKNOWN` |
| `first_seen_at`, `last_seen_at` | vigência observada |
| `attributes` | atributos adicionais em JSONB |

Aliases e códigos ficam em `canonical.instrument_alias`:

- `instrument_id` → `canonical.instrument`;
- `alias_type`: `TICKER`, `CNPJ`, `ISIN`, `CUSIP`, `RIC`, `SYMBOL`, `SOURCE_ID`, `NAME`;
- `alias_value`, `normalized_value`;
- `venue_id`, `source_id`;
- `valid_from`, `valid_to`;
- `is_primary`.

## 3. Grafo comum a praticamente todas as classes

O cadastro de qualquer instrumento negociável deve seguir estes nós e arestas existentes.

### 3.1 Emissor e entidade legal

| Tabela | Campos de ligação | Campos relevantes |
|---|---|---|
| `core.emissor_companhia` | `id_emissor` | `cnpj`, `nome_empresarial`, `codigo_cvm`, `setor`, `subsetor`, `cnae`, `gics`, `free_float`, `tag_along`, `data_ipo`, `data_registro_cvm` |
| `canonical.legal_entity` | `legal_entity_id` | `legal_name`, `cnpj`, `tax_id`, `country_code`, `website`, `valid_from`, `valid_to` |
| `core.grupo_acionista` | `id_emissor` | `id_grupo`, `nome_grupo`, `tipo` |
| `core.historico_acionista` | `id_acionista`, `id_emissor` | `data_posicao`, `quantidade_ordinarias`, `quantidade_preferenciais`, `percentual_total` |
| `market.calendario_resultados` | `id_emissor` | `data_prevista`, `data_confirmada`, `periodo_referencia`, `tipo` |
| `analytics.demonstrativo_financeiro` | `id_emissor` | `data_referencia`, `data_publicacao`, `tipo_documento`, `contas_detalhadas`, `receita_liquida`, `ebitda`, `lucro_liquido`, `patrimonio_liquido`, `divida_bruta`, `divida_liquida` |
| `analytics.demonstrativo_padronizado_serie` | `id_emissor` | período, moeda, receitas, EBITDA, lucro, dívida, patrimônio, fluxo de caixa, LPA, VPA e proventos |
| `analytics.demonstrativo_snapshot_fundamentus` | `id_emissor` | balanço processado, ativos, dívida, patrimônio, receita/lucro 3M/12M |
| `analytics.receita_segmento_negocio` | `id_emissor` | `data_referencia`, `tipo_periodo`, `nome_segmento`, `receita_liquida`, `ebitda_segmento`, `lucro_segmento`, `participacao_pct`, `moeda`, `fonte` |
| `analytics.receita_geografia` | `id_emissor` | região/país, receita, participação, moeda, fonte |
| `analytics.kpi_operacional_emissor` | `id_emissor` | KPI, categoria, valor, unidade, variações YoY/QoQ, fonte |
| `analytics.insider_transaction` | `id_emissor` | insider, cargo, operação, quantidade, preço e data |

A camada canônica equivalente usa `canonical.financial_statement`, `canonical.financial_line`, `canonical.disclosure_document`, `canonical.metric_observation` e `canonical.corporate_event`, sempre preferencialmente por `instrument_id`, `legal_entity_id`, `source_id` e `payload_id`.

### 3.2 Mercado, preço e negociação

| Tabela | Campo de ligação | Campos de fato |
|---|---|---|
| `market.cotacao_diaria` | `id_ativo` → `core.ativo` | `data_pregao`, OHLC, `preco_medio`, `volume_total`, `quantidade_negocios`, `preco_ajustado`, variação e ajustes; PK `(id_ativo, data_pregao)` |
| `market.cotacao_intraday` | `id_ativo` → `core.ativo` | `id_tick`, `timestamp`, `preco_atual`, `variacao`, `volume` |
| `market.book_ordens` | `id_ativo` sem FK declarada no DDL base | `tipo_oferta`, `preco`, `quantidade`, `corretora`, `timestamp` |
| `market.negocio_intraday` | `id_ativo` sem FK declarada | `timestamp`, `preco`, `quantidade`, comprador/vendedor/agressor |
| `market.leilao` | `id_ativo` sem FK declarada | `data`, tipo, preço teórico e quantidade teórica |
| `market.after_market` | `id_ativo` sem FK declarada | `timestamp`, `preco`, `volume` |
| `market.ajuste_intraday` | `id_ativo` sem FK declarada | `data`, `valor_ajuste` |
| `canonical.price_observation` | `instrument_id`, `source_id`, `payload_id` | `observed_at`, `trading_date`, OHLC, adjusted close, bid/ask, volume e quality |
| `market.estatistica_mercado` | `id_ativo` opcional | `data_referencia`, tipo, valor e posição |

### 3.3 Eventos e proventos

| Tabela | Campos de ligação | Campos relevantes |
|---|---|---|
| `market.evento_corporativo` | `id_ativo` | `tipo_evento`, `data_aprovacao`, `data_ex`, `fator_proporcao`, `observacao` |
| `market.desdobramento_split` | `id_ativo` | `tipo`, `data_ex`, `quantidade_antes`, `quantidade_depois`, `fator` |
| `market.subscricao_acao` | `id_ativo` | tipo, datas, preço de emissão, quantidade ofertada, fator |
| `market.provento` | `id_ativo` | tipo, anúncio, data-com, ex, registro, pagamento, valor, moeda, imposto |
| `market.calendario_proventos` | `id_ativo`, `id_provento` | datas, valor estimado/confirmado, status |
| `market.previsao_provento` | `id_ativo` | data de referência, valor estimado, método e confiança |
| `market.historico_provento_recebido` | `id_provento`, `id_usuario`, `id_carteira` | quantidade, bruto, imposto, líquido, crédito e status |
| `market.antecipacao_dividendo` | `id_provento`, `id_usuario` | valor antecipado, desconto, datas |
| `canonical.corporate_event` | `instrument_id`, `source_id`, `payload_id` | tipo canônico, anúncio, record/ex/payment date, valor, moeda, ratio e observação |

### 3.4 Carteira, custódia e operações

| Tabela | Campos de ligação | Campos relevantes |
|---|---|---|
| `core.carteira` | `id_carteira`, `id_usuario` | nome, tipo, benchmark, objetivo, moeda e status |
| `core.posicao_custodia` | `id_carteira`, `id_ativo` | quantidades total/disponível/bloqueada, preço médio, preço atual, valor, rentabilidade e datas; UNIQUE `(id_carteira, id_ativo)` |
| `core.nota_corretagem` | usuário/instituição | número, data pregão/liquidação, taxas, corretagem, IRRF e valor líquido |
| `core.transacao_operacao` | `id_nota`, `id_carteira`, `id_ativo` | compra/venda, quantidade, preço unitário, total, custos e liquidação |
| `core.lote_ativo` | `id_carteira`, `id_ativo` | lote fiscal, quantidade original/restante e custo |
| `core.lote_consumo` | `id_lote`, `id_transacao` | quantidade consumida e custo consumido |
| `core.ordem` | `id_carteira`, `id_ativo` | ordem, status, lado, quantidade e preço |
| `wealth.aporte_programado` | `id_usuario`, `id_carteira`, `id_ativo` | recorrência, quantidade/valor e status |
| `wealth.aporte_execucao` | `id_aporte`, `id_transacao` | execução, data e resultado |
| `dw.historico_posicao` | `id_carteira`, `id_ativo` | snapshot, quantidade e valor |
| `dw.historico_carteira` | `id_carteira` | evolução agregada |
| `dw.historico_provento` | `id_usuario`, `id_ativo` | mês, provento recebido e acumulados |
| `dw.historico_ir` | carteira/usuário e ativo conforme DDL | apuração histórica |

### 3.5 Analytics e produto

Qualquer ativo ligado por `id_ativo` pode aparecer em:

- `analytics.indicador_fundamentalista`: `id_ativo`, `data_referencia`, P/L, P/VP, ROE, ROIC, DY, EV/EBITDA, margens, dívida e múltiplos;
- `analytics.historico_indicador_fundamentalista`: série por `id_ativo` e `data_referencia`;
- `analytics.indicador_tecnico`: `id_ativo`, data, médias, IFR, MACD, bandas, suporte/resistência e timeframe;
- `analytics.historico_indicador_tecnico`: série técnica;
- `analytics.historico_risco`: beta, volatilidade, Sharpe, Treynor, Sortino, VaR, drawdown e janelas;
- `analytics.score_ativo`: metodologia, pontuação, classificação e JSON de detalhes;
- `analytics.preco_alvo`: preços-alvo, analistas, recomendação e upside;
- `analytics.modelo_precificacao`: DCF, Gordon, comparáveis, RNAV, DDM e parâmetros JSON;
- `analytics.relatorio_analise`: emissor, ativo, relatório, analista, URL e nota;
- `analytics.item_carteira_recomendada`: ativo, peso, tese e datas;
- `analytics.ativo_tag`, `analytics.colecao_item`, `social.favorito`, `social.comparacao_ativo`, `social.watchlist_item`, `social.anotacao_ativo`;
- `social.noticia_ativo`: ativo, notícia, publicação e sentimento;
- `analytics.ranking_item`/`ranking_snapshot`: no ramo canônico, `instrument_id`, score, rank e métrica;
- `analytics.valuation`: `instrument_id`, data, metodologia, parâmetros, preço justo, preço de mercado, margem e source.

## 4. Fluxo de cadastro comum

1. Criar/identificar `core.emissor_companhia` ou `canonical.legal_entity`.
2. Criar `core.ativo` com `ticker`, identificadores, `tipo_ativo`, moeda e datas.
3. Criar `canonical.instrument` com `asset_class`, nome, ISIN, currency, venue e status.
4. Criar `canonical.instrument_alias` para ticker, símbolo, CNPJ, código de fonte e aliases históricos.
5. Preencher `core.ativo.canonical_instrument_id`.
6. Criar o detalhe 1:1 em `asset_details.*`, quando existir para a classe.
7. Cadastrar preço em `market.*` operacional e/ou `canonical.price_observation` canônico, mantendo source/payload.
8. Cadastrar eventos/proventos.
9. Cadastrar holdings se o ativo for fundo/ETF/FII/FIAGRO/FI-Infra.
10. Conectar à carteira somente quando houver custódia/operação.
11. Inserir documentos, métricas e analytics usando o identificador correto.
12. Atualizar os marts/DW derivados, sem inserir manualmente uma segunda captura do fato.

## 5. FII — Fundo de Investimento Imobiliário

### 5.1 Identidade e classificação

- `core.ativo.tipo_ativo = 'FII'`.
- `canonical.instrument.asset_class = 'FII'`.
- Campos mínimos: `id_ativo`, `ticker`, `isin` quando houver, `codigo_cetip` quando houver, `moeda`, `segmento_listagem`, `id_emissor` se houver emissor formal.

### 5.2 Cadastro específico

`asset_details.detalhe_fii` é 1:1 por `id_ativo`:

- `id_detalhe_fii` PK;
- `id_ativo` UNIQUE/FK;
- `id_segmento` → `asset_details.segmento_fii(id_segmento)`;
- `id_tipo_gestao` → `asset_details.tipo_gestao_fii(id_tipo_gestao)`;
- `gestor`, `administrador`, `numero_cotistas`, `prazo_duracao`;
- extensões: avaliador, escriturador, taxas, dias habituais de anúncio/pagamento, `qtd_imoveis`, `preco_m2`, `aluguel_m2`, `cap_rate_medio`, inadimplência, contratos, concentração de inquilinos, CRIs, duration e LTV.

### 5.3 Histórico e composição

- `asset_details.historico_vacancia_fii`: `id_ativo`, `data_referencia`, `vacancia_fisica`, `vacancia_financeira`, `abl_total`, `abl_locada`, `inadimplencia_pct`.
- `asset_details.historico_patrimonio_fii`: `id_ativo`, data, patrimônio, quantidade de cotas, valor patrimonial; extensões de caixa, ativos imobiliários/papel e passivos.
- `asset_details.rentabilidade_fii`: `id_ativo`, data, rentabilidade mensal/anual/12M/desde início, benchmark, DY patrimonial e variação patrimonial.
- `asset_details.composicao_carteira_fii`: `id_ativo`, data, `tipo_ativo`, `nome_ativo`, percentual, valor, endereço, UF/cidade/bairro, área, unidades, ocupação, inadimplência e participação de receita.
- `asset_details.fii_imovel`: cadastro do imóvel; `fii_imovel_participacao` liga `id_ativo` + `id_imovel` + data, com participação, ABL, vacâncias, laudo, aquisição e métricas.
- `asset_details.fii_cronograma_contratos`: `id_ativo`, data, vencimento/revisional, faixa de prazo, percentual de receita/ABL e indexadores.
- `asset_details.fii_cri_carteira`: `id_ativo_fii`, data, código IF/CETIP, ISIN, securitizadora, devedor, série/emissão, indexador, spread, duration, LTV, garantias, vencimento, quantidade, valor e percentual do PL.
- `asset_details.fii_demonstrativo_trimestral`: `id_ativo`, data, receitas de aluguel/vendas/CRI/LCI/LCA, despesas, resultado contábil/caixa, distribuição e payout.
- `asset_details.fii_avaliacao_gestora`: `id_ativo`, data e avaliação da gestora.

### 5.4 Mercado, proventos e carteira

O FII usa todos os nós comuns de preço, provento, evento e carteira. Os proventos normalmente são `market.tipo_provento_enum = 'RENDIMENTO'` ou `DIVIDENDO`, mas o enum não impõe a classe.

### 5.5 Atenção

A composição de FII legada usa `nome_ativo` textual e não FK para o ativo subjacente. Para reconciliação exata, o cadastro deve também tentar resolver o subjacente em `core.ativo`/`canonical.instrument`.

## 6. Ação brasileira

### 6.1 Identidade

- `core.tipo_ativo_enum = 'ACAO'`.
- `canonical.asset_class = 'EQUITY'`.
- `core.ativo`: ticker, ISIN, emissor, moeda, mercado, segmento de listagem e datas.
- `core.emissor_companhia`: CNPJ, CVM, setor, subsetor, GICS, free float e tag along.

### 6.2 Dados ligados ao emissor

- demonstrações e séries contábeis em `analytics.demonstrativo_financeiro`, `analytics.demonstrativo_padronizado_serie` e snapshots Fundamentus;
- segmentos e geografia em `analytics.receita_segmento_negocio` e `analytics.receita_geografia`;
- insiders em `analytics.insider_transaction`;
- grupos acionistas em `core.grupo_acionista` e `core.historico_acionista`;
- resultados em `market.calendario_resultados`;
- documentos canônicos em `canonical.disclosure_document` e `canonical.financial_statement`/`financial_line`.

### 6.3 Dados de mercado específicos

- `market.cotacao_diaria`, `cotacao_intraday`, `book_ordens`, `negocio_intraday`, `leilao`, `after_market`, `ajuste_intraday`;
- `market.aluguel_acoes`: `id_ativo`, data, taxa média, contratos, volume e short interest;
- `market.programa_recompra`: `id_ativo`, datas, tipo, quantidade e preço, conforme extensão v3.4;
- `market.negociacao_mensal_modalidade`: `id_ativo`, data, modalidade e valores;
- `market.desdobramento_split`, `subscricao_acao`, `evento_corporativo`;
- `market.provento` e tabelas de calendário/recebimento.

### 6.4 Analytics

Usa os indicadores fundamentalistas, técnicos, risco, valuation, preço-alvo, consenso, candlestick, checklist, recomendação, ranking, notícias e carteiras recomendadas listados no grafo comum.

## 7. REIT

### 7.1 Identidade

- `core.tipo_ativo_enum = 'REIT'` quando disponível;
- `canonical.asset_class = 'REIT'`;
- cadastro em `core.ativo` com ticker, ISIN quando houver, moeda estrangeira, venue e emissor;
- alias internacional em `canonical.instrument_alias`, preferencialmente com `alias_type = 'SYMBOL'` ou `TICKER` e `venue_id`.

### 7.2 Tabelas ligadas

REIT não possui uma tabela `asset_details.reit_detalhe` específica no DDL atual. Portanto, usa:

- `core.ativo` e `canonical.instrument`;
- `core.emissor_companhia`/`canonical.legal_entity` quando o emissor estiver cadastrado;
- `market.cotacao_diaria`/`intraday` se o ativo estiver no modelo operacional;
- `canonical.price_observation` para preço canônico;
- `market.provento`/`canonical.corporate_event` para dividendos/rendimentos;
- `analytics.demonstrativo_internacional` para relatórios 10-K/10-Q/20-F/8-K e métricas em moeda estrangeira;
- `canonical.disclosure_document`, `financial_statement`, `financial_line`, `metric_observation`;
- carteira, operações, lotes, risco, valuation e notícias do grafo comum.

**Limitação:** atributos imobiliários específicos de REIT não têm tabela especializada própria; não devem ser forçados para `detalhe_fii`, porque essa tabela representa FII brasileiro.

## 8. Stock internacional

### 8.1 Identidade

- `core.tipo_ativo_enum = 'STOCK_EXTERIOR'`, `STOCK_EUA` ou valor equivalente existente;
- `canonical.asset_class = 'EQUITY'`;
- `core.ativo.moeda` na moeda de negociação;
- `core.bolsa` por `id_bolsa`, quando usado;
- `canonical.instrument.venue_id` e aliases por símbolo/venue.

### 8.2 Tabelas ligadas

- `analytics.demonstrativo_internacional`: `ticker_internacional`, `pais`, `id_bolsa`, tipo de documento, período, publicação, moeda e fonte;
- `core.emissor_companhia`/`canonical.legal_entity` para emissor;
- `canonical.instrument_alias` para ticker, símbolo, ISIN, CUSIP/RIC quando disponível;
- preços e operações do grafo comum;
- `market.cambio`: moeda origem/destino e taxa para conversão;
- `analytics.demonstrativo_financeiro`, indicadores, risco, valuation e documentos canônicos quando o instrumento tiver vínculo resolvido.

## 9. Criptomoeda

### 9.1 Identidade

- `core.tipo_ativo_enum = 'CRIPTO'`;
- `canonical.asset_class = 'CRYPTO'`;
- `core.ativo`: ticker/símbolo, moeda, datas e status;
- `canonical.instrument`: nome, símbolo/alias, venue quando aplicável, atributos JSON.

### 9.2 Detalhe específico

`asset_details.criptomoeda_detalhe`:

- `id_cripto` PK;
- `id_ativo` UNIQUE/FK;
- `exchange`, `wallet`, `tipo_custodia`;
- `staking_yield`;
- `algoritmo_consenso`;
- `market_cap`, `volume_24h`, `dominancia`;
- `fornecimento_maximo`, `fornecimento_total`, `fornecimento_circulante`;
- `fdv`, `tvl`, `tvl_market_cap_ratio`.

### 9.3 Mercado e custódia

- preço operacional via `market.cotacao_diaria`/`cotacao_intraday` quando a cripto for cadastrada em `core.ativo`;
- preço canônico via `canonical.price_observation`, devendo usar `venue_id` e source para diferenciar exchange/par;
- carteira via `core.posicao_custodia`, `transacao_operacao`, lotes e aportes;
- `wealth.investimento_exterior` pode ser usado quando a posição estiver modelada como investimento externo, conforme suas FKs existentes.

**Limitação:** o modelo atual não possui campos específicos para blockchain, chain, contract address, decimals ou par de negociação; esses atributos só podem ser guardados em `canonical.instrument.attributes` sem inventar nova tabela.

## 10. ETF brasileiro

### 10.1 Identidade

- `core.tipo_ativo_enum = 'ETF'`;
- `canonical.asset_class = 'ETF'`;
- `core.ativo` com ticker, ISIN, emissor/gestor, moeda e venue.

### 10.2 Perfil

`asset_details.etf_detalhe`:

- `id_etf`, `id_ativo` UNIQUE/FK;
- `indice_referencia`, `benchmark`;
- `taxa_administracao`, taxas primária/secundária/total/anualizada;
- `patrimonio`, `cotas`, `numero_cotistas`;
- `composicao_carteira_url`;
- limite de aluguel, frequência/política de dividendos;
- método de replicação;
- domicílio, região, categoria/subcategoria, provedor do índice;
- gestor, administrador, controlador;
- tracking error, fluxo líquido, P/VP e DY 12M.

### 10.3 Holdings e métricas

- `market.etf_composicao_carteira`: `id_ativo_fundo`, data, `id_ativo_subjacente`, `codigo_ativo`, descrição, setor, país, peso, quantidade e valor.
- `canonical.fund_profile`: pode representar o ETF como perfil de fundo por `instrument_id`.
- `canonical.fund_holding`: `fund_instrument_id`, `holding_instrument_id`, nome, data, peso, quantidade, valor, moeda, source e movimentações CDA.
- `market.etf_metricas_diarias`: `id_ativo`, data, preço de fechamento, NAV, spread NAV, PL, cotas emitidas, criação/resgate, cotistas, aluguel e tracking difference.
- `market.comparador_par_canonico`: comparação textual por `ticker_a`, `ticker_b`, sobreposição, taxas, tracking e correlação.

### 10.4 Simulação

- `analytics.simulador_portfolio_config` → `simulador_portfolio_carteira` → `simulador_portfolio_ativo`;
- `simulador_portfolio_ativo.id_ativo` liga o ETF ou qualquer ativo à carteira simulada;
- `simulador_portfolio_resultado` guarda retorno, CAGR, volatilidade, Sharpe, Sortino, drawdown e curvas JSON.

## 11. ETF internacional / UCITS

Usa a mesma cadeia do ETF brasileiro, com diferenças de classificação/campos:

- `core.tipo_ativo_enum = 'ETF_EXTERIOR'` ou `ETF_EUA`;
- `canonical.asset_class = 'ETF'`;
- `asset_details.etf_detalhe.domicilio_fiscal`, `regiao_exposicao`, categoria e subcategoria;
- `core.ativo.moeda` e `canonical.currency_code` na moeda do fundo/venue;
- `canonical.instrument_alias` por ticker/symbol/ISIN e venue;
- `analytics.demonstrativo_internacional` e `canonical.disclosure_document` para documentos;
- `market.etf_composicao_carteira` com `pais_origem`, `codigo_ativo` e subjacente;
- `canonical.fund_holding` para holdings resolvidos por UUID;
- `market.cambio` para conversões;
- preços, proventos, carteira, risco e analytics comuns.

O DDL não cria uma tabela separada `etf_internacional`; a distinção é feita por enum, domicílio, moeda, venue, região e categoria.

## 12. Tesouro Direto

### 12.1 Identidade

- `core.tipo_ativo_enum = 'TESOURO'`;
- `canonical.asset_class = 'GOVERNMENT_BOND'`;
- `core.ativo`: ticker/código, moeda, emissão, vencimento, indexador e `tipo_titulo`;
- `canonical.government_bond`: `instrument_id`, `bond_program`, `indexer`, `maturity_date`, `coupon_rate`.

### 12.2 Detalhe operacional

`asset_details.tesouro_direto`:

- `id_tesouro` PK;
- `id_ativo` UNIQUE/FK;
- `tipo_titulo`, `indexador`;
- `taxa_compra`, `taxa_venda`, `vencimento`, `pu`, `quantidade_mercado`, `rentabilidade`;
- extensões: `codigo_selic`, `isin`, taxas indicativas ANBIMA, `pu_anbima`, `vna_atual`, `duration_anos`.

### 12.3 Cotação canônica

`canonical.government_bond_quote`:

- `government_bond_id` → `canonical.government_bond(instrument_id)`;
- `quote_date`;
- `buy_rate`, `sell_rate`, `buy_price`, `sell_price`;
- `duration_years`;
- `source`, `raw_payload_id`;
- extensões ANBIMA: taxas mínima/máxima/indicativa, PU, clean price, VNA e código SELIC;
- UNIQUE `(government_bond_id, quote_date, source)`.

### 12.4 Macroeconomia

Tesouro pode consumir, sem FK direta ao ativo:

- `market.serie_macroeconomica`;
- `market.curva_juros` com tipos PRE/IPCA/DI e vértices;
- `market.cambio` se houver conversão;
- carteira, posição, transação e apuração de IR comuns.

## 13. Renda fixa privada

### 13.1 Identidade

- `core.tipo_ativo_enum = 'RENDA_FIXA'`;
- `canonical.asset_class = 'FIXED_INCOME'`;
- `core.ativo`: emissor, ISIN/CETIP, indexador, vencimento, emissão, moeda, balcão e tipo de título;
- `canonical.instrument` e aliases para ISIN, código de negociação e código de fonte.

### 13.2 Detalhe

`asset_details.renda_fixa_detalhe`:

- `id_rf` PK;
- `id_ativo` UNIQUE/FK;
- `emissor` textual;
- `indexador`, `taxa`, `vencimento`, `rating`, `garantia`, `liquidez`, `classe`, `spread`.

### 13.3 Relações

- emissor operacional: `core.emissor_companhia` quando aplicável;
- entidade canônica: `canonical.legal_entity`;
- demonstrativos/documentos/métricas se o emissor for uma companhia;
- preços e observações canônicas quando houver cotação;
- posição, transação, lote e apuração de IR;
- `market.curva_juros` e séries macro para indexadores/referências.

**Limitação:** o DDL não contém uma entidade específica de dívida privada canônica; não há `canonical.debt_instrument` no estado atual.

## 14. BDR

### 14.1 Identidade

- `core.tipo_ativo_enum = 'BDR'`/`BDR_ETF` conforme enum existente;
- `canonical.asset_class = 'BDR'`;
- `core.ativo`: ticker local, ISIN/CETIP, moeda e emissor/depositário;
- `asset_details.bdr_detalhe.id_ativo` liga o BDR ao ativo local.

### 14.2 Detalhe

`asset_details.bdr_detalhe`:

- `id_bdr` PK;
- `id_ativo` UNIQUE/FK;
- `empresa_estrangeira`;
- `pais_origem`;
- `ratio` entre recibo e ativo estrangeiro;
- `moeda_origem`, `bolsa_origem`, `setor_global`.

### 14.3 Ativo subjacente e análises

Na cobertura de análise de ações:

- `id_ativo_origem` → ativo estrangeiro/origem;
- `id_ativo_bdr` → BDR;
- `market.cotacao_diaria`/`intraday` podem existir para ambos;
- `market.cambio` converte a moeda de origem;
- `canonical.instrument_alias` guarda símbolos/ISINs de origem;
- eventos/proventos são registrados no BDR e/ou origem conforme a fonte;
- carteira e analytics usam o `id_ativo` correspondente à posição.

## 15. Índice

### 15.1 Identidade operacional

- `core.tipo_ativo_enum = 'INDICE'`;
- `market.indice` possui `id_indice`, `ticker_indice`, `nome`, `tipo`.

### 15.2 Composição

`market.composicao_indice`:

- `id_composicao` PK;
- `id_indice` → `market.indice`;
- `id_ativo` → `core.ativo`;
- `peso`, `qtde_teorica`, `data_vigencia_inicio`, `data_vigencia_fim`.

No ramo canônico:

- `canonical.index_profile`: `index_id`, `instrument_id`, metodologia, provedor, frequência de rebalanceamento;
- `canonical.index_constituent`: `index_id`, `instrument_id`, vigência, peso, rank e `source_id`.

### 15.3 Uso

Índices podem ser benchmark de `core.carteira`, referência em `asset_details.etf_detalhe.indice_referencia`, base de comparação em analytics e composição histórica. O documento recomenda manter a composição canônica e operacional reconciliadas.

## 16. FIAGRO

### 16.1 Identidade

- `core.tipo_ativo_enum` deve usar o valor disponível para fundo/veículo equivalente;
- `canonical.asset_class = 'FIAGRO'`;
- `core.ativo` e `canonical.instrument` são as identidades obrigatórias.

### 16.2 Estruturas disponíveis

Não existe uma tabela `asset_details.fiagro_detalhe` específica no DDL atual. O FIAGRO deve usar, sem inventar tabela:

- `asset_details.fundo_investimento` por `id_ativo`;
- `asset_details.fundo_carteira` por `id_fundo`, data, tipo/nome do ativo e percentual;
- `asset_details.fundo_rentabilidade` por `id_fundo` e data;
- `canonical.fund_profile` por `instrument_id`;
- `canonical.fund_holding` por fundo, subjacente, data, peso, quantidade, valor e fonte;
- `market.provento`/`canonical.corporate_event` para rendimentos;
- preços, carteira, operações, analytics e DW comuns.

A classificação FIAGRO deve ficar em `asset_details.fundo_investimento.classe`/`segmento`, `canonical.fund_profile.fund_type` ou `canonical.instrument.asset_class`, conforme o ramo do dado. Esses campos precisam ser reconciliados para evitar classificações divergentes.

## 17. FI-Infra

### 17.1 Identidade

- `core.tipo_ativo_enum = 'FI_INFRA'`;
- `canonical.asset_class = 'FI_INFRA'`;
- `core.ativo` e `canonical.instrument` como chaves.

### 17.2 Detalhe específico

`asset_details.fi_infra_detalhe`:

- `id_fi_infra` PK;
- `id_ativo` UNIQUE/FK;
- `benchmark_referencia` default NTN-B;
- `spread_indicativo_ntnb`;
- `duration_media_carteira`;
- `isencao_ir_pf`;
- `taxa_administracao_total`, `taxa_performance`;
- `segmento_infra`;
- `gestor`, `administrador`;
- datas de início/atualização.

### 17.3 Composição e rendimentos

Como não existe tabela de holdings específica de FI-Infra, usar:

- `canonical.fund_profile`;
- `canonical.fund_holding`;
- `asset_details.fundo_carteira` apenas quando o registro estiver modelado também como fundo;
- `market.provento` e `canonical.corporate_event`;
- `market.cotacao_diaria`/`canonical.price_observation`;
- carteira e analytics comuns.

## 18. Fundo de investimento genérico

### 18.1 Modelo operacional

`asset_details.fundo_investimento`:

- `id_fundo` PK;
- `id_ativo` UNIQUE/FK;
- `cnpj`, `classe`, `segmento`;
- taxas, benchmark, patrimônio, cota e performance;
- cotistas, classificação ANBIMA e gestor;
- extensões CVM 175: tipo entidade, fundo/classe/subclasse, pais, códigos CVM/ANBIMA, público-alvo, cota, tributação, condomínio, taxas, mínimos, prazos, auditor, custodiante, controlador e datas.

Hierarquia operacional:

- `id_fundo_pai` → `fundo_investimento(id_fundo)`;
- `id_classe_pai` → `fundo_investimento(id_fundo)`.

### 18.2 Modelo canônico

`canonical.fund_profile`:

- `instrument_id` PK/FK lógica para instrumento;
- `fund_type`, `segment`, administrador, gestor, custodiante;
- datas, regime tributário e atributos;
- extensões CVM 175, fundo-pai, código ANBIMA, público-alvo, taxas, mínimos, prazos e lockup.

### 18.3 Carteira e rentabilidade

- `asset_details.fundo_carteira`: fundo, data, tipo/nome do ativo, percentual, dados CDA de compra/venda e confidencialidade;
- `asset_details.fundo_rentabilidade`: fundo, data, rentabilidades, Sharpe e volatilidade;
- `canonical.fund_holding`: composição canônica por UUID/source.

## 19. Opção e instrumentos relacionados

`asset_details.opcao_detalhe`:

- `id_opcao` PK;
- `id_ativo` UNIQUE/FK;
- série, strike, vencimento, tipo CALL/PUT;
- `id_ativo_objeto` → `core.ativo` subjacente;
- prêmio, contratos abertos e gregas: volatilidade implícita, delta, gamma, theta, vega.

No canônico, `canonical.asset_class = 'OPTION'` e `canonical.option_contract` usa `instrument_id` e `underlying_instrument_id`.

## 20. Raw, staging, canonical e serving

### 20.1 Raw

- `raw.ingestion_batch`: lote, source e execução;
- `raw.payload`: payload imutável, hash, URL/metadata e captura;
- `canonical.source`: catálogo de fontes;
- `canonical.disclosure_document`: documento ligado a source, instrumento/entidade e payload.

### 20.2 Staging/intermediate

O merge possui views como:

- `public_staging.*`: normalização de payloads por fonte;
- `public_intermediate.int_cotacoes_consolidadas`: projeção de cotação para ticker;
- `public_intermediate.int_proventos_ajustados`: projeção de proventos.

Essas camadas usam, em parte, `ticker` e strings de source. Elas não devem ser usadas como identidade principal.

### 20.3 DW/serving

O merge cria relações como:

- `public_dw.dim_ativo`;
- `public_dw.dim_emissor`;
- `public_dw.dim_fundo`;
- `public_dw.fct_cotacao_diaria`;
- `public_dw.fct_provento`;
- `public_dw.fct_fii_snapshot_mensal`;
- `public_dw.fct_indicador_fundamentalista`;
- `public_dw.mart_screener_acoes`;
- `public_dw.mart_screener_fiis`;
- `public_dw.mart_screener_etfs`.

Essas tabelas repetem dados de `core`, `market`, `asset_details` e `analytics` por ticker/texto. Devem ser tratadas como derivadas e não como novas fontes de cadastro.

## 21. Ordem prática de inserção por ativo

### Ação, stock, REIT e BDR

1. Emissor/entidade legal.
2. `core.ativo`.
3. `canonical.instrument` e aliases.
4. Detalhe BDR, se aplicável.
5. Cotações.
6. Eventos/proventos.
7. Documentos e demonstrações.
8. Indicadores/valuation/risco.
9. Posição e operações.
10. Marts derivados.

### FII, FIAGRO, FI-Infra e fundos

1. Entidade legal, gestor, administrador e custodiante quando disponíveis.
2. `core.ativo` + `canonical.instrument`.
3. `asset_details.detalhe_fii`, `fundo_investimento` ou `fi_infra_detalhe`.
4. `canonical.fund_profile`.
5. Histórico de patrimônio/vacância/rentabilidade.
6. Holdings/composição por data.
7. Imóveis, CRIs, contratos e demonstrativos quando aplicável.
8. Proventos/rendimentos.
9. Cotações.
10. Carteira e analytics.

### ETF nacional/internacional

1. Instrumento e aliases por ticker/ISIN/venue.
2. `asset_details.etf_detalhe`.
3. `canonical.fund_profile`.
4. Holdings em `canonical.fund_holding` e/ou `market.etf_composicao_carteira`.
5. NAV/tracking em `market.etf_metricas_diarias`.
6. Cotações, proventos, câmbio e analytics.
7. Simulações e marts.

### Tesouro e renda fixa

1. Emissor ou programa.
2. `core.ativo` + `canonical.instrument`.
3. `asset_details.tesouro_direto` ou `renda_fixa_detalhe`.
4. `canonical.government_bond` para Tesouro.
5. Quotes e taxas.
6. Curva de juros/indexador.
7. Custódia, transações, lotes e IR.

### Cripto

1. Instrumento e aliases.
2. `asset_details.criptomoeda_detalhe`.
3. Exchange/custódia quando disponível.
4. Preços por venue/par.
5. Custódia e transações.
6. Métricas de supply, market cap, FDV e TVL.

### Índice

1. `market.indice` e/ou `canonical.index_profile`.
2. Instrumento canônico do índice.
3. Composição operacional e canônica por vigência.
4. Pesos/rank/source.
5. Uso como benchmark, composição de ETF e comparação.

## 22. Campos obrigatórios para reconciliação

Para evitar duplicidade ou mistura entre ativos, cada carga deve possuir, sempre que disponível:

- `instrument_id` canônico;
- `id_ativo` operacional;
- `canonical_instrument_id` no vínculo de compatibilidade;
- ticker/símbolo e venue;
- ISIN, CNPJ, CUSIP, RIC ou código de fonte;
- `source_id`/source e `payload_id`;
- data de referência/observação;
- moeda;
- asset class/tipo de ativo;
- emissor/entidade legal;
- status e vigência do alias.

## 23. Limitações conhecidas do modelo atual

1. `core.ativo` usa ticker globalmente único, o que é inadequado para ativos com o mesmo símbolo em venues diferentes.
2. Parte das tabelas `market.*` possui `id_ativo` sem FK.
3. Composições legadas de FII/fundo usam nome textual sem FK de subjacente.
4. REIT, FIAGRO e renda fixa privada não possuem detalhes canônicos tão específicos quanto FII/Tesouro.
5. Cripto não possui campos dedicados para chain, contract address, rede e par.
6. `canonical.source`/`payload_id` não estão uniformemente presentes nas camadas operacionais.
7. Há duplicidade entre preço/provento operacional, canônico e DW; cargas futuras devem escolher uma fonte de verdade.
8. O documento descreve o estado atual; não significa que o modelo atual seja ideal ou que todas as FKs estejam implementadas.

## 24. Checklist de cadastro

- [ ] Classe operacional definida.
- [ ] Classe canônica definida.
- [ ] `core.ativo` criado.
- [ ] `canonical.instrument` criado.
- [ ] Alias por ticker/símbolo/ISIN/venue criado.
- [ ] `canonical_instrument_id` preenchido.
- [ ] Emissor/legal entity resolvido.
- [ ] Detalhe específico da classe criado.
- [ ] Fonte e payload registrados.
- [ ] Cotação registrada com data, moeda e fonte.
- [ ] Evento/provento registrado quando aplicável.
- [ ] Holdings registradas com data e subjacente resolvido.
- [ ] Carteira/operações/lotes ligados se houver posição do usuário.
- [ ] Analytics/documentos ligados ao instrumento ou emissor correto.
- [ ] DW/serving regenerado ou atualizado como derivação.
- [ ] Nenhum fato duplicado inserido diretamente em duas fontes de verdade.
