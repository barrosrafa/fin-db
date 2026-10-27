# REA — Engenharia Reversa dos 12 Sites de Análise Financeira & 4 Fontes Oficiais/Regulatórias

**Versão:** 1.0  
**Data:** 2026-10-26  
**Repositório de Ingestão:** `https://github.com/barrosrafa/fin-ingestion`  
**Repositório do Banco de Dados:** `https://github.com/barrosrafa/fin-db`  
**Escopo:** Mapeamento exaustivo de endpoints, payloads, cabeçalhos, estratégias de extração, mitigação anti-bot e modelagem para o pipeline de dados `fin-ingestion`.

---

## 1. Matriz de Fontes & Tecnologias Identificadas

| # | Fonte / Plataforma | URL Base | Tipo / Tecnologia | Autenticação / Proteção |
|---|---|---|---|---|
| **OF1** | **B3** | `https://www.b3.com.br` | Arquivos posicionais BVBG, CotHist, APIs Market Data | Nenhuma (dados públicos) / Akamai |
| **OF2** | **CVM** | `https://dados.cvm.gov.br` | Portal de Dados Abertos (CSV/ZIP) | Nenhuma (HTTP direto) |
| **OF3** | **BCB** | `https://api.bcb.gov.br` | API REST SGS + Portal Olinda OData | Nenhuma (HTTP direto REST/OData) |
| **OF4** | **ANBIMA** | `https://www.anbima.com.br` | Web scraping + feeds estruturados CSV/JSON | Nenhuma (sessão HTTP) |
| **S01** | **Status Invest** | `https://statusinvest.com.br` | MVC ASP.NET Core + Endpoints XHR JSON | Cloudflare Bot Management (User-Agent + Headers) |
| **S02** | **Investidor10** | `https://investidor10.com.br` | Laravel 10 + API REST interna + JS inline | Cloudflare + CSRF token + Cookies de sessão |
| **S03** | **Fundamentei** | `https://fundamentei.com` | Next.js (SSR/SSG) + Apollo GraphQL Client | Cloudflare + JWT Bearer anon/user |
| **S04** | **Fundamentus** | `https://fundamentus.com.br` | PHP clássico + LiteSpeed Web Server | Cookies de sessão (`_uac`, `_qn`) + Latin-1 charset |
| **S05** | **Clube FII** | `https://www.clubefii.com.br` | ASP.NET MVC + GraphQL API (`api.clubefii.dev.br`) | JWT Token Bearer + Headers de origin |
| **S06** | **Funds Explorer** | `https://www.fundsexplorer.com.br`| WordPress Headless + AJAX REST endpoints | Cloudflare + WAF + Nonce AJAX WordPress |
| **S07** | **FIIs.com.br** | `https://fiis.com.br` | WordPress Sage + Vue 3 Client Islands | Cloudflare + dataLayer SSR hydration |
| **S08** | **Mais Retorno** | `https://maisretorno.com` | Next.js + Microserviços REST (`data`/`ms`/`api`) | AWS CloudFront + Rate Limiting por IP |
| **S09** | **Análise de Ações** | `https://www.analisedeacoes.com` | Gatsby Static Site + API REST v2 backend | Cloudflare + JSON estático por rota (`page-data`) |
| **S10** | **Brick360** | `https://brick360.com.br` | Vue 3 Single Page Application + REST API v2 | Cloudflare + Bearer Token / API Public v2 |
| **S11** | **ADVFN Brasil** | `https://br.advfn.com` | Multi-bolsa Server-Rendered + AJAX WebSockets | Incapsula / Cloudflare + User-Agent Browser |
| **S12** | **ETFs Brasil** | `https://www.etfsbrasil.com.br` | Next.js Frontend + FastAPI Python Backend | Nenhuma / CORS aberto para API Backend |

---

## 2. REA Detalhado: Órgãos Reguladores e Oficiais

### OF1. B3 (Brasil, Bolsa, Balcão)
* **Domínios & Protocolos:**
  - Cotações Históricas Anuais: `https://bvmf.bmfbovespa.com.br/InstDados/SerHist/COTAHIST_A{ANO}.ZIP`
  - Arquivo de Instrumentos Cadastrados (BVBG.028): `https://www.b3.com.br/data/files/.../Instruments_BVBG028.zip`
  - Posições de Empréstimo de Ações (BTC): `https://sistemasweb.b3.com.br/EmprestimoAtivos/Consulta/`
  - Índices B3 (Composição de Carteira IBOV, IFIX, SMLL): `https://sistemaswebb3-listados.b3.com.br/indexProxy/indexCall/GetPortfolioDay/`
* **Formato de Dados:**
  - `COTAHIST`: Texto plano posicional com cabeçalho `00`, registros de dados `01` e rodapé `99`. Campos: Data do pregão, código BDI, código de negociação (ticker), tipo de mercado (010=vista, 020=fracionário, 070=opções de compra, 080=opções de venda), nome resumido da empresa, especificação da ação (ON, PN, UNT), preço de abertura, máximo, mínimo, médio, fechamento, melhor oferta de compra/venda, total de negócios, quantidade de títulos e volume financeiro.
  - `Index Proxy API`: JSON com array de componentes: `codAtivo`, `acao`, `tipo`, `qtdeTeorica`, `partPct`.
* **Frequência & Destino:**
  - `COTAHIST` diário/anual -> `market.cotacao_diaria` e `market.after_market`
  - BTC -> `market.aluguel_acoes`
  - Índices -> `market.benchmark` e `market.benchmark_componente`

### OF2. CVM (Comissão de Valores Mobiliários)
* **Domínios & Protocolos:**
  - Portal de Dados Abertos: `https://dados.cvm.gov.br/dados/`
  - Companhias Abertas (DFP, ITR, FRE, FCA):
    - `https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/dfp_cia_aberta_{ANO}.zip`
    - `https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/ITR/DADOS/itr_cia_aberta_{ANO}.zip`
    - `https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/FRE/DADOS/fre_cia_aberta_{ANO}.zip`
    - `https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/cad_cia_aberta.csv`
  - Fundos Imobiliários (FII):
    - Informe Mensal: `https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/inf_mensal_fii_{ANO}.zip`
    - Informe Trimestral: `https://dados.cvm.gov.br/dados/FII/DOC/INF_TRIMESTRAL/DADOS/inf_trimestral_fii_{ANO}.zip`
  - Fundos de Investimento (CVM 175):
    - Composição de Carteira (CDA): `https://dados.cvm.gov.br/dados/FI/DOC/CDA/DADOS/cda_fi_{ANO}{MES}.zip`
    - Lâminas e Informes Diários: `https://dados.cvm.gov.br/dados/FI/DOC/INF_DIARIO/DADOS/inf_diario_fi_{ANO}{MES}.zip`
* **Formato de Dados:**
  - Arquivos CSV separados por `;`, codificação ISO-8859-1 (Latin-1).
  - Tabelas DFP/ITR: `BPA` (Ativo), `BPP` (Passivo), `DRE` (Resultado), `DFC_MD` / `DFC_MI` (Fluxo de Caixa), `DVA` (Valor Adicionado).
  - Tabelas FRE: Remuneração máxima/média/mínima de executivos, membros do conselho e diretoria estatutária, acordos de acionistas e pirâmide de controle.
  - Tabelas FII: Detalhamento de imóveis, vacância física e financeira, inadimplência, passivos de alavancagem (CRI emitido, financiamentos), demonstrativo contábil trimestral.
* **Frequência & Destino:**
  - Cadastros e DFP/ITR -> `core.emissor_companhia`, `analytics.demonstrativo_financeiro`, `canonical.legal_entity`
  - FRE Governança -> `core.administrador_companhia`, `core.remuneracao_administradores`, `core.grupo_acionista`
  - FII Mensal/Trimestral -> `asset_details.historico_patrimonio_fii`, `asset_details.historico_vacancia_fii`, `asset_details.fii_imovel`, `asset_details.fii_demonstrativo_trimestral`
  - CDA Fundos -> `asset_details.fundo_investimento`, `asset_details.fundo_carteira`, `canonical.fund_holding`

### OF3. BCB (Banco Central do Brasil)
* **Domínios & Protocolos:**
  - SGS API (Sistema Gerenciador de Séries Temporais):
    - Endpoint: `https://api.bcb.gov.br/dados/serie/bcdata.sgs.{SERIE}/dados?formato=json`
    - Séries Primárias:
      - `11`: Taxa Selic Over diária (% a.d.)
      - `432`: Meta Selic definida pelo Copom (% a.a.)
      - `433`: IPCA mensal (% a.m.)
      - `189`: IGP-M mensal (% a.m.)
      - `12`: Taxa CDI diária (% a.d.)
      - `226`: TR diária
  - API Olinda Câmbio PTAX:
    - Endpoint: `https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoMoedaDia(moeda=@moeda,dataCotacao=@dataCotacao)?@moeda='USD'&@dataCotacao='{MM-DD-YYYY}'&$format=json`
  - API Olinda Expectativas de Mercado (Focus):
    - Endpoint: `https://olinda.bcb.gov.br/olinda/servico/Expectativas/versao/v1/odata/ExpectativaMercadoMensais?$filter=Indicador eq 'IPCA'&$orderby=Data desc&$top=50&$format=json`
* **Formato de Dados:**
  - JSON nativo com arrays contendo `data` (formato `DD/MM/YYYY`) e `valor` (string com ponto ou vírgula decimal).
* **Frequência & Destino:**
  - Diário e Mensal -> `market.serie_macroeconomica`, `market.benchmark_serie`, `canonical.macroeconomic_indicator`

### OF4. ANBIMA (Associação Brasileira das Entidades dos Mercados Financeiro e de Capitais)
* **Domínios & Protocolos:**
  - Preços e Taxas de Títulos Públicos Federais (TPF):
    - URL: `https://www.anbima.com.br/informacoes/merc-sec/arqs/ms{YYMMDD}.txt`
    - Titulos cobertos: LTN, LFT, NTN-B, NTN-B Principal, NTN-F.
  - Taxas Indicativas de Debêntures:
    - URL: `https://www.anbima.com.br/informacoes/merc-sec-debentures/arqs/db{YYMMDD}.txt`
  - Estrutura a Termo da Taxa de Juros (ETTJ / Curva Zero):
    - URL: `https://www.anbima.com.br/informacoes/est-termo/arqs/curvas.txt`
  - Índices de Mercado ANBIMA (IMA):
    - URL: `https://www.anbima.com.br/informacoes/ima/ima-sh.asp` (IMA Geral, IMA-B, IMA-B 5, IMA-B 5+, IRF-M, IDA)
* **Formato de Dados:**
  - Arquivos posicionais ou delimitados por `@`/tabulação com cabeçalhos de metadados. Campos: Código SELIC, Código ISIN, Data de Vencimento, Taxa Compra/Venda, Taxa Indicativa, Desvio Padrão, PU Compra/Venda, Intervalo Mínimo/Máximo.
* **Frequência & Destino:**
  - Diário D+1 -> `canonical.government_bond_quote`, `asset_details.tesouro_direto`, `market.curva_juros_zero`, `market.benchmark_serie`

---

## 3. REA Detalhado: Os 12 Sites de Análise Financeira

### S01. Status Invest (`https://statusinvest.com.br`)
* **Arquitetura & Stack:** ASP.NET Core MVC com SSR e chamadas XHR assíncronas para gráficos e dados pesados.
* **Proteção & Anti-Bot:** Cloudflare Bot Protection. Requer cabeçalhos válidos de browser (`User-Agent`, `Accept: application/json, text/plain, */*`, `Sec-Fetch-Mode: cors`, `Sec-Fetch-Site: same-origin`).
* **Catálogo de Endpoints XHR:**
  1. **Cotação Histórica e Volume:**
     `GET /acao/tickerprice?ticker={TICKER}&type=4`
     Retorno: Array de `{Date: "YYYY-MM-DD", Value: 12.34}`.
  2. **Demonstrações Contábeis DRE (5 anos):**
     `GET /acao/getdre?code={TICKER}&type=0`
     Retorno: JSON estruturado com rubricas contábeis anualizadas: Receita Líquida, Custos, Lucro Bruto, Despesas Operacionais, EBITDA, EBIT, Resultado Financeiro, LAIR, Impostos, Lucro Líquido.
  3. **Demonstrações Fluxo de Caixa (DFC):**
     `GET /acao/getfluxocaixa?code={TICKER}&type=0`
     Retorno: FCO (Operacional), FCI (Investimento), FCF (Financiamento), Fluxo de Caixa Livre e Variação de Caixa.
  4. **Empréstimo de Ações (Aluguel BTC):**
     `GET /category/borrowhistory?ticker={TICKER}`
     Retorno: Séries temporais de Taxa Média Tomador/Doador, Contratos Abertos, Ações Emprestadas e % do Free Float alugado.
  5. **FII Detalhe de CRIs & Inadimplência:**
     `GET /fii/cridetail/{TICKER}`
     Retorno: Títulos securitizados, devedor, indexador (IPCA, CDI), spread médio, taxa de juros, garantias e status de adimplência.
  6. **Fundos de Investimento (Histórico de Cotas & PL):**
     `GET /fundoinvestimento/historicofund?codigo={CNPJ_OR_SLUG}&type=0`
     Retorno: Cota diária, PL, captação líquida e número de cotistas.
  7. **Opções & Gregas:**
     `GET /opcoes/getexpirationbyunderlying?code={TICKER}`
     Retorno: Vencimentos ativos, strikes, call/put, volume e volatilidade implícita.
* **Mapeamento para `fin-db`:**
  - DRE/DFC -> `analytics.demonstrativo_financeiro`
  - BTC -> `market.aluguel_acoes`
  - CRIs do FII -> `asset_details.fii_cri_carteira`
  - Opções -> `asset_details.opcao_detalhe`, `market.fluxo_opcoes`

### S02. Investidor10 (`https://investidor10.com.br`)
* **Arquitetura & Stack:** Laravel 10 PHP no backend com Blade SSR e componentes JavaScript dinâmicos (Chart.js / ApexCharts).
* **Proteção & Anti-Bot:** Cloudflare + proteção de sessão por cookie. Requisições REST necessitam de `X-Requested-With: XMLHttpRequest` e `Referer: https://investidor10.com.br/acoes/{TICKER}/`.
* **Catálogo de Endpoints REST & Inline State:**
  1. **Histórico de Indicadores Fundamentalistas:**
     `GET /api/historico-indicadores/{TICKER}/anual/`
     Retorno: Séries de 10 anos de P/L, P/VP, EV/EBITDA, Margem Bruta, Margem EBITDA, Margem Líquida, ROE, ROIC, Dívida Líquida/EBITDA, Dívida Líquida/PL, Liquidez Corrente, Payout.
  2. **Balanços & Demonstrações Financeiras:**
     `GET /api/balancos/receitas/{TICKER}/anual/`
     `GET /api/balancos/lucros/{TICKER}/anual/`
     `GET /api/balancos/dividas/{TICKER}/anual/`
  3. **Mapa Anual de Dividendos:**
     `GET /api/acoes/dividends-map/{TICKER}/`
     Retorno: Pagamentos agrupados por mês de pagamento e data-com, valores nominais e Dividend Yield anualizado.
  4. **Receitas por Segmento e Geografia (Inline JS):**
     Extraído das tags `<script>` na página da ação:
     `window.companyRevenues` e `window.companyBussinesRevenues`.
  5. **Checklist Buy & Hold (Regras de Scoring):**
     Identificado nas tags `<div class="checklist">` com 6 critérios objetivos:
     - Empresa com mais de 5 anos de bolsa;
     - Lucro líquido nos últimos 5 anos;
     - Lucros crescentes nos últimos 5 anos;
     - Dívida menor que o patrimônio líquido;
     - Margem líquida maior que 10%;
     - ROE maior que 10%.
* **Mapeamento para `fin-db`:**
  - Histórico de Múltiplos -> `analytics.historico_indicador_fundamentalista`
  - Segmentos -> `analytics.receita_segmento_negocio`, `analytics.receita_geografia`
  - Checklist -> `analytics.checklist_avaliacao_ativo`
  - Médias Setoriais -> `analytics.indicador_media_setorial`

### S03. Fundamentei (`https://fundamentei.com`)
* **Arquitetura & Stack:** Next.js Server-Side Rendering integrado a cliente Apollo GraphQL.
* **Proteção & Anti-Bot:** Cloudflare Turnstile nas rotas de login; páginas públicas contêm o estado completo hidratado no DOM em `window.__NEXT_DATA__.props.pageProps.apolloState.data`.
* **Mapeamento do Apollo GraphQL State:**
  - O grafo contém entidades normalizadas por chave única de cache:
    1. `BrazilianCompanyIssuer:{ID}`: CNPJ, CVM Code, Setor, Subsetor, Listagem, Tag Along, Free Float, Site RI.
    2. `Indicator:{ID}`: 102 definições formais de indicadores financeiros e operacionais com séries temporais de 15 a 20 anos.
    3. `financialGeographicSegments` & `financialBusinessSegments`: Detalhamento percentual e nominal de faturamento por mercado interno vs. externo e unidades de negócio.
    4. `kpis`: Métricas operacionais proprietárias por setor (ex: Produção de barris de óleo BOE/dia para Petrobras, Toneladas de celulose para Suzano, Vendas Mesmas Lojas SSS para Varejo, Passageiros-quilômetro RPK para Aviação).
    5. `reclameAquiRatings`: Reputação do consumidor (Score, % Reclamações Respondidas, Índice de Solução, Voltaria a Fazer Negócio).
    6. `officers`: Diretoria executiva, membros do conselho, tempo de mandato e histórico de cargos.
    7. `cvmMaterialFacts`: Fatos relevantes CVM com resumo e categorização de impacto.
* **Estratégia de Ingestão:**
  - Extração em tempo de execução via parser de AST do JSON do `__NEXT_DATA__`. Não necessita de token autenticado para empresas públicas.
* **Mapeamento para `fin-db`:**
  - Segmentos -> `analytics.receita_segmento_negocio`, `analytics.receita_geografia`
  - KPIs Operacionais -> `analytics.kpi_operacional_emissor`
  - Reclame Aqui -> colunas em `core.emissor_companhia`
  - Diretoria -> `core.administrador_companhia`

### S04. Fundamentus (`https://fundamentus.com.br`)
* **Arquitetura & Stack:** Aplicação clássica em PHP sobre servidor LiteSpeed, renderizando HTML puro e tabelas com codificação `ISO-8859-1`.
* **Proteção & Anti-Bot:** Requer User-Agent moderno e suporte a cookies de sessão (`_uac`, `_qn`, `fundamentus_ad_salarios2`). Requisições muito rápidas (taxa > 5 req/s) recebem HTTP 403 temporário.
* **Rotas & Parâmetros Estruturados:**
  1. **Visão Consolidada da Ação:**
     `GET /detalhes.php?papel={TICKER}`
     Tabelas HTML organizadas em 5 blocos: Cotação/Valor de Mercado, Informações Básicas, Indicadores Fundamentalistas, Balanço Patrimonial e DRE (12 meses e 3 meses).
  2. **Screener Completo de Ações (Tabela Geral):**
     `GET /resultado.php`
     Retorno: Tabela HTML com todas as ações negociadas na B3 com 20 colunas de múltiplos fundamentalistas.
  3. **Screener de Fundos Imobiliários:**
     `GET /fii_resultado.php`
     Retorno: Tabela HTML com todos os FIIs, Cotação, FFO Yield, Dividend Yield, P/VP, Valor de Mercado, Liquidez, Quantidade de Imóveis, Preço do m², Aluguel por m², Vacância Média.
  4. **Detalhamento de Imóveis dos FIIs:**
     `GET /fii_imoveis_detalhes.php?papel={TICKER}`
     Retorno: Nome do imóvel, endereço completo, bairro, cidade, UF, área bruta locável (ABL), percentual de participação do fundo.
  5. **Composição Acionária & Controladores:**
     `GET /acionistas.php?papel={TICKER}`
     Retorno: Acionistas ordinários e preferenciais com percentual de ações ON, PN e Total.
  6. **Programas de Recompra de Ações:**
     `GET /recompras.php?papel={TICKER}`
     Retorno: Datas de aprovação pelo conselho, prazo de vigência, quantidade aprovada e executada.
  7. **Negociações de Insiders:**
     `GET /insiders.php?papel={TICKER}`
     Retorno: Compras e vendas declaradas por controladores, conselheiros e diretores.
* **Mapeamento para `fin-db`:**
  - Imóveis FII -> `asset_details.fii_imovel`, `asset_details.fii_imovel_participacao`
  - Acionistas -> `core.grupo_acionista`, `core.historico_acionista`
  - Recompras -> `market.programa_recompra`
  - Insiders -> `canonical.insider_transaction`

### S05. Clube FII (`https://www.clubefii.com.br`)
* **Arquitetura & Stack:** ASP.NET Core no portal público + **CR Data GraphQL API (`https://api.clubefii.dev.br/graphql`)** no backend de dados e analytics.
* **Proteção & Anti-Bot:** GraphQL protegido por token de autenticação e validação de `Origin: https://www.clubefii.com.br` e `Referer`. As rotas web tradicionais usam AJAX com antiforgery token.
* **Catálogo de Endpoints GraphQL & AJAX:**
  1. **CR Data GraphQL API (`https://api.clubefii.dev.br/graphql`):**
     Query de Fundo Imobiliário com schema completo:
     ```graphql
     query GetFiiDetails($ticker: String!) {
       fundo(ticker: $ticker) {
         cnpj
         razaoSocial
         gestora { nome cnpj reputacao }
         administradora { nome cnpj }
         tipoGestao
         publicoAlvo
         taxaAdministracao
         taxaGestao
         taxaPerformance
         patrimonioLiquido
         valorPatrimonialCota
         cotistasQuantidade
         imoveis {
           nome
           endereco
           cidade
           uf
           ablTotal
           vacanciaFisica
           vacanciaFinanceira
           tipoContrato # TIPICO, ATIPICO
           reajusteIndexador # IPCA, IGP-M, INPC
         }
       }
     }
     ```
  2. **Transações Imobiliárias de Venda:**
     `GET /ajax/transacoes-de-venda-de-imoveis?fundo={TICKER}`
     Retorno: Data da venda, comprador, valor nominal, valor por m², lucro imobiliário apurado, taxa interna de retorno (TIR) da operação e Cap Rate de saída.
  3. **Transações de Locação & Inquilinos:**
     `GET /ajax/transacoes-de-locacoes?fundo={TICKER}`
     Retorno: Locatário, área locada, prazo de vigência, término do contrato, garantias e índice de reajuste.
  4. **Dados de Mercado Imobiliário Brasileiro (Parceria SiiLA):**
     `GET /ajax/dados-do-mercado-imobiliario-brasileiro/{REGIAO}`
     Retorno: Vacância regional corporativa e logística, novo estoque projetado, absorção líquida no trimestre, valor médio de aluguel pedido.
  5. **Novas Emissões e Ofertas Públicas:**
     `GET /novas-emissoes-de-fundos-imobiliarios-oferta-publica`
     Retorno: Número da emissão, instrução CVM (400, 476, 160), preço da cota na emissão, taxa de distribuição, fator de proporção para direitos de preferência, sobras e rateio.
* **Mapeamento para `fin-db`:**
  - Imóveis e Participações -> `asset_details.fii_imovel`, `asset_details.fii_imovel_participacao`
  - Vendas de Imóveis -> `asset_details.fii_transacao_venda_imovel`
  - Locações e Contratos -> `asset_details.fii_transacao_locacao_imovel`, `asset_details.fii_cronograma_contratos`
  - Séries SiiLA -> `asset_details.mercado_imobiliario_indicador`
  - Emissões -> `market.subscricao_acao`, `canonical.offering`

### S06. Funds Explorer (`https://www.fundsexplorer.com.br`)
* **Arquitetura & Stack:** WordPress headless com camada de dados customizada em PHP e renderização Next.js/React.
* **Proteção & Anti-Bot:** Cloudflare WAF. Endpoints AJAX requerem headers de emulação de navegador e cookies transitórios.
* **Catálogo de Endpoints REST & AJAX:**
  1. **Ranking Completo de FIIs:**
     `GET /ranking`
     Retorno: Tabela/JSON com mais de 30 colunas de métricas consolidadas: Código do fundo, Setor, Preço Atual, Liquidez Diária, Último Rendimento, Dividend Yield (1M, 3M, 6M, 12M, Anualizado), Variação de Preço, Rentabilidade do Período, Rentabilidade Patrimonial, Variação Patrimonial, P/VP, VP por Cota, P/Ativo, Quantidade de Ativos, Vacância Física, Vacância Financeira.
  2. **Histórico de Proventos (Income):**
     `GET /wp-json/funds-explorer/v1/funds-get-income?ticker={TICKER}`
     Retorno: Data-com, Data-base, Data de Pagamento, Valor Provento por Cota, Cotação Base, Rendimento mensal em % e Rendimento acumulado.
  3. **Histórico Patrimonial:**
     `GET /wp-json/funds-explorer/v1/funds-get-patrimonials?ticker={TICKER}`
     Retorno: Valor Patrimonial da Cota (VPC), Patrimônio Líquido total, Ativo Total e Alavancagem/Passivo CVM.
  4. **Emissões & Subscrições:**
     `GET /wp-json/funds-explorer/v1/funds-get-paginated-emissoes?ticker={TICKER}`
  5. **Vacância Histórica por Fundo:**
     `GET /wp-json/funds-explorer/v1/funds-get-vacancia?ticker={TICKER}`
     Retorno: Série temporal mensal de vacância física (%) e financeira (%).
  6. **Imóveis Mapeados:**
     `GET /wp-json/funds-explorer/v1/funds-get-all-properties?ticker={TICKER}`
* **Mapeamento para `fin-db`:**
  - Ranking & Indicadores -> `asset_details.rentabilidade_fii`, `dw.ranking`
  - Proventos -> `market.provento`
  - Patrimônio -> `asset_details.historico_patrimonio_fii`
  - Vacância -> `asset_details.historico_vacancia_fii`

### S07. FIIs.com.br (`https://fiis.com.br`)
* **Arquitetura & Stack:** WordPress Sage moderno com Vite, Tailwind CSS e ilhas de hidratação Vue 3 (`data-island="invest-simulator"`).
* **Proteção & Anti-Bot:** Cloudflare + cache reverso na CDN. Extração direta por parsing das ilhas Vue e dos objetos `dataLayer_content.pagePostTerms.meta`.
* **Rotas e Dados Estruturados:**
  1. **Lupa de FIIs (Screener Interativo):**
     `GET /lupa-de-fiis/`
     Extração de JSON embutido na view de screening com filtros por segmento (Logística, Lajes Corporativas, Papel/CRI, FOF, Shopping, Renda Urbana, Agronegócio Fiagro, Infraestrutura FI-Infra).
  2. **Agenda de Dividendos com Competência:**
     `GET /agenda-de-dividendos/`
     Retorno: Registro com campo essencial de **competência mensal de apuração (`mes_referencia`)**, além de data-com, data-pagamento e valor.
  3. **Notificações e Fatos Relevantes Recentes:**
     `GET /atualizacoes/`
     Feed cronológico de comunicados ao mercado, emissões e relatórios gerenciais com links de download direto de PDFs da CVM.
* **Mapeamento para `fin-db`:**
  - Agenda com competência -> `market.provento` (coluna `mes_referencia`)
  - Feed de comunicados -> `canonical.disclosure_document`, `canonical.news_article`

### S08. Mais Retorno (`https://maisretorno.com`)
* **Arquitetura & Stack:** Next.js App Router / Pages Router conectando a três clusters de microserviços dedicados:
  - `data.maisretorno.com/mr-data/v4`
  - `data.maisretorno.com/ms/v2`
  - `api.maisretorno.com/v3`
* **Proteção & Anti-Bot:** AWS CloudFront com rate limit por IP e token de sessão de navegação.
* **Catálogo de Endpoints de Dados:**
  1. **Fundos de Investimento (Hierarquia CVM 175 & CDA):**
     `GET https://data.maisretorno.com/mr-data/v4/funds/{CNPJ_OR_SLUG}`
     Retorno: Hierarquia completa CVM 175 (Fundo Mãe -> Classe de Cotas -> Subclasse), regras de aplicação inicial, movimentação mínima, taxa de administração mínima/máxima, taxa de performance, benchmark de referência, benchmark hurdle rate, cotização de aplicação (D+0/D+1) e cotização de resgate (D+X) com liquidação financeira.
  2. **Carteira de Ativos (CDA Aberto):**
     `GET https://data.maisretorno.com/mr-data/v4/funds/{CNPJ_OR_SLUG}/holdings`
     Retorno: Posições abertas de ativos (Ações, Títulos Públicos, Títulos Privados, Derivativos, Cotas de outros fundos), com volume financeiro e percentual do PL alocado, incluindo histórico de compras e vendas declaradas à CVM.
  3. **Motor Analítico de Risco em Janelas Móveis:**
     `GET https://data.maisretorno.com/ms/v2/funds/{CNPJ_OR_SLUG}/risk-metrics`
     Retorno: 10 janelas temporais (1M, 3M, 6M, 12M, 24M, 36M, 60M, 120M, Ano Atual, Desde o Início) cruzadas com 10 métricas de risco estatístico:
     - Volatilidade Anualizada
     - Índice de Sharpe
     - Índice de Sortino
     - Índice de Treynor
     - Alfa de Jensen em relação ao CDI e IBOV
     - Beta em relação ao IBOV
     - Tracking Error
     - Information Ratio
     - Drawdown Máximo, Data de Início, Fundo e Tempo de Recuperação
     - Meses Positivos vs. Meses Negativos e Taxa de Sucesso em janelas móveis de 12 meses.
  4. **Catálogo de 170 Benchmarks & Índices:**
     `GET https://api.maisretorno.com/v3/indexes`
     Retorno: Séries históricas de índices de ações, renda fixa, inflação, commodities e moedas (ex: IBOV, IFIX, IDIV, SMLL, CDI, Selic, IPCA, IGP-M, IMA-B, IRF-M, S&P 500, Nasdaq, Ouro, Dólar PTAX).
  5. **Diretório de Gestoras e Administradores:**
     `GET https://api.maisretorno.com/v3/gestores`
     Retorno: CNPJ da gestora, AUM (Ativos sob Gestão), histórico de fundos lançados e equipe de gestão.
  6. **Títulos Públicos do Tesouro Direto:**
     `GET https://api.maisretorno.com/v3/titulos-publicos`
* **Mapeamento para `fin-db`:**
  - CVM 175 -> `asset_details.fundo_investimento`, `canonical.fund_profile`
  - CDA Carteira -> `asset_details.fundo_carteira`, `canonical.fund_holding`
  - Métricas de Risco -> `analytics.historico_risco`
  - Benchmarks -> `market.benchmark`, `market.benchmark_serie`
  - Gestoras -> `core.instituicao_financeira`, `core.instituicao_diretoria_socios`

### S09. Análise de Ações (`https://www.analisedeacoes.com`)
* **Arquitetura & Stack:** Gatsby.js (gerador de sites estáticos com hidratação React) acoplado a backend REST v2 em `https://api.analisedeacoes.com`.
* **Proteção & Anti-Bot:** Cloudflare CDN. Os dados estruturados estáticos estão disponíveis em arquivos JSON por rota: `/page-data/{ROTA}/page-data.json`. A API v2 responde requisições REST autenticadas ou com referer do domínio.
* **Catálogo de Endpoints REST & Gatsby Data:**
  1. **Checklist dos 5 Pilares de Valuation:**
     `GET https://api.analisedeacoes.com/companies/v2/{TICKER}/checklist`
     Retorno: Pontuação e status detalhado nos 5 pilares do investidor fundamentalista:
     - Pilar 1: Crescimento e Consistência (CAGR Lucro > 5%, CAGR Receita > 5%);
     - Pilar 2: Endividamento Saudável (Dívida Líquida / EBITDA < 2.5x);
     - Pilar 3: Eficiência Operacional (Margem Líquida > 10%, ROE > 15%, ROIC > 12%);
     - Pilar 4: Retorno ao Acionista (DY consistente, Payout entre 25% e 75%);
     - Pilar 5: Preço Atrativo (Preço Justo de Graham e Preço Teto de Bazin).
  2. **Modelos de Preço Justo e Preço Teto:**
     - Preço Justo de Graham: $V = \sqrt{22.5 \times LPA \times VPA}$
     - Preço Teto de Bazin: $P_{teto} = \frac{DPA_{medio}}{0.06}$
     - Fluxo de Caixa Descontado (DCF simplificado)
  3. **Histórico Fundamentalista de 10 Anos:**
     `GET https://api.analisedeacoes.com/companies/{TICKER}/v2/historical`
  4. **Médias Setoriais:**
     `GET https://api.analisedeacoes.com/companies/sectors/{SETOR_SLUG}/indicators`
     Retorno: Médias e medianas de P/L, P/VP, EV/EBITDA e margens para comparação direta com o ativo.
  5. **Datas Habituais de Proventos de FIIs:**
     `GET https://api.analisedeacoes.com/fiis/{TICKER}/dividends`
     Retorno: Dia do mês típico para corte da Data-Com (ex: último dia útil do mês) e dia do mês típico de pagamento (ex: 10º a 15º dia útil).
  6. **Diretório de Avaliações de Corretoras:**
     `GET https://api.analisedeacoes.com/corretoras/{CORRETORA_SLUG}`
     Retorno: Taxas de corretagem, custódia, plataformas suportadas (Profit, Trader, Home Broker), nota de suporte e atendimento.
* **Mapeamento para `fin-db`:**
  - Valuation (Graham, Bazin, DCF) -> `analytics.valuation`
  - Checklist dos 5 Pilares -> `analytics.checklist_avaliacao_ativo`
  - Médias Setoriais -> `analytics.indicador_media_setorial`
  - Dias habituais de FII -> colunas em `asset_details.detalhe_fii`
  - Corretoras -> `core.instituicao_financeira`

### S10. Brick360 (`https://brick360.com.br`)
* **Arquitetura & Stack:** Vue 3 Single Page Application (SPA) consumindo API REST v2 em `/api/v2/`.
* **Proteção & Anti-Bot:** Cloudflare + autenticação por Bearer Token ou sessão pública v2.
* **Catálogo de Endpoints REST v2:**
  1. **Análise Avançada Modular de FIIs:**
     `GET /api/v2/funds/{TICKER}/analysis/advanced`
     Retorna objeto JSON com 12 módulos analíticos:
     - `overview`: Metadados do fundo, valor de mercado, valor patrimonial, P/VP, liquidez diária, cota patrimonial.
     - `brick_score`: Score proprietário ponderado de 0 a 100 dividido em 6 eixos de qualidade imobiliária e financeira:
       1. *Eixo Imobiliário:* Qualidade dos ativos, padrão construtivo (A+, A, B), localização prime (Faria Lima, Paulista, Chucri Zaidan, Castelo Branco, etc.).
       2. *Eixo Financeiro & Alavancagem:* Dívida bruta, obrigações por securitização CRI, cronograma de amortização, índice de cobertura de juros.
       3. *Eixo Inquilinos & Contratos:* Concentração nos top 5 inquilinos (%), índice de contratos atípicos vs. típicos, WALT (Weighted Average Lease Term) e vencimento de contratos por ano.
       4. *Eixo Gestão & Governança:* Reputação da gestora, histórico de alocação de capital, cobrança de taxas vs. retorno aos cotistas.
       5. *Eixo Risco de Crédito (para FIIs de Papel):* Distribuição de ratings dos CRIs (AAA, AA, A, BBB, High Yield), LTV (Loan-to-Value) médio das operações e garantias reais.
       6. *Eixo Preço & Desconto:* Margem de segurança em relação ao valor intrínseco e custo de reposição do metro quadrado.
     - `ai_committee`: Parecer sintético gerado por comitê de inteligência artificial com SWOT (Forças, Fraquezas, Oportunidades, Ameaças) e tese de investimento.
     - `quarterly_result`: DRE contábil padronizada CVM trimestral com receitas de locação, receitas financeiras, despesas de taxa de administração, consultoria, despesas de conservação e resultado financeiro líquido.
     - `portfolio_axis`: Detalhamento de cada imóvel, área locável própria, taxa de ocupação física e financeira, Cap Rate estimado.
     - `tenants_axis`: Lista completa de inquilinos, setor econômico do locatário e prazo de permanência.
     - `manager_axis`: Auditoria cadastral da gestora, patrimônio gerido e outros fundos sob o mesmo guarda-chuva.
  2. **Repositório de Documentos CVM Estruturados:**
     `GET /api/v2/funds/{TICKER}/documents`
     Retorno: Informes mensais, relatórios gerenciais e demonstrações financeiras com resumos semânticos e índices de sentimento.
* **Mapeamento para `fin-db`:**
  - Brick Score (6 eixos) -> `analytics.score_eixo`
  - DRE Trimestral CVM -> `asset_details.fii_demonstrativo_trimestral`
  - Carteira de CRIs -> `asset_details.fii_cri_carteira`
  - Cronograma de Contratos -> `asset_details.fii_cronograma_contratos`
  - Avaliação de Gestora -> `asset_details.fii_avaliacao_gestora`
  - Inquilinos -> colunas em `asset_details.detalhe_fii` e `fii_transacao_locacao_imovel`

### S11. ADVFN Brasil (`https://br.advfn.com`)
* **Arquitetura & Stack:** Portal multi-bolsa internacional com páginas renderizadas no servidor e serviços AJAX / streaming para cotações em tempo real.
* **Proteção & Anti-Bot:** Incapsula / Cloudflare. Requer cabeçalho padrão de navegador com cookies de tracking.
* **Catálogo de Módulos & Rotas:**
  1. **Análise Técnica Clássica & Suporte e Resistência:**
     `GET /suporte-e-resistencia/{TICKER}`
     Retorno: Cálculo matemático de pontos de pivô e níveis críticos:
     - 4 Níveis de Suporte ($S_1, S_2, S_3, S_4$)
     - Ponto de Pivô Central ($PP$)
     - 3 Níveis de Resistência ($R_1, R_2, R_3$)
     - Variação necessária para romper cada nível.
  2. **13 Indicadores de Preço em 9 Timeframes:**
     `GET /indicadores-de-preco/{TICKER}`
     Retorno: Matriz de 13 indicadores calculados em 9 intervalos de tempo (1min, 5min, 15min, 30min, 60min, Diário, Semanal, Mensal, Anual):
     - Média Móvel Simples (MMS 5, 21, 50, 200)
     - Média Móvel Exponencial (MME 9, 21)
     - IFR / RSI (14 períodos)
     - Estocástico Lento
     - MACD (12, 26, 9)
     - Bollinger Bands (20, 2)
     - Parabolic SAR
     - HiLo Activator
     - OBV (On-Balance Volume)
     - Momentum
     - TRIX
     - CCI (Commodity Channel Index)
     - ADX / DMI
     - Sinais consolidados: Contagem de indicadores em Compra Forte, Compra, Neutro, Venda e Venda Forte.
  3. **Padrões de Candlestick:**
     `GET /analise-tecnica/candlestick/{TICKER}`
     Retorno: Detecção algorítmica de padrões de velas: Doji, Martelo, Enforcado, Engolfo de Alta/Baixa, Estrela da Manhã/Tarde, Harami, Três Soldados Brancos.
  4. **Previsões de Consenso de Analistas (Sell-Side):**
     `GET /previsoes/{TICKER}`
     Retorno: Estimativas de consenso para 2026, 2027 e 2028:
     - Preço-Alvo Médio, Mínimo e Máximo
     - Quantidade de analistas com recomendação de Compra, Manutenção e Venda
     - LPA Projetado (Lucro por Ação)
     - VPA Projetado (Valor Patrimonial por Ação)
     - Receita Líquida Projetada
     - EBITDA Projetado
     - P/L Projetado e EV/EBITDA Projetado.
  5. **Transações de Insiders e Detentores Institucionais:**
     `GET /propriedade/{TICKER}` e `GET /insider/{TICKER}`
     Retorno: Transações de diretores/acionistas e posições de fundos institucionais.
  6. **Fluxo de Opções e Mercado a Termo:**
     `GET /ferramentas/fluxo-de-opcoes/{TICKER}` e `GET /termo/{TICKER}`
     Retorno: Volume financeiro negociado no mercado a termo, prazo médio dos contratos em dias, taxa de juros embutida, e posições de opções em aberto (coberto vs. descoberto vs. travas).
* **Mapeamento para `fin-db`:**
  - Suporte/Resistência e Indicadores -> `analytics.indicador_tecnico`
  - Candlestick -> `analytics.padrao_candlestick`
  - Consenso de Analistas -> `analytics.previsao_consenso_analistas`, `analytics.preco_alvo`
  - Insiders -> `canonical.insider_transaction`, `canonical.institutional_holding`
  - Mercado a Termo & Fluxo de Opções -> `market.negociacao_mensal_modalidade`, `market.fluxo_opcoes`

### S12. ETFs Brasil (`https://www.etfsbrasil.com.br`)
* **Arquitetura & Stack:** Frontend Next.js consumindo backend FastAPI em Python (`https://www.etfsbrasil.com.br/api/backend/`).
* **Proteção & Anti-Bot:** API pública sem chaves secretas ou captchas, formato JSON padronizado.
* **Catálogo de Endpoints REST FastAPI:**
  1. **Rankings Multiativo e Comparador:**
     `GET /api/backend/home`
     `GET /api/backend/compare?tickers={TICKER1},{TICKER2}`
     Retorno: Universo de ETFs listados na B3 (ações, renda fixa, ouro, cripto, exterior), ETFs negociados nos EUA, Ações americanas, BDRs, FIIs, FI-Infras, Fundos CVM e 68 Índices de referência (B3 e Teva Indices).
  2. **Estrutura de Custos do ETF:**
     - Taxa de Administração Primária (cobrada pelo emissor local)
     - Taxa Secundária / Custos dos Fundos Subjacentes (ex: ETF local que compra ETF offshore como IVVB11 comprando IVV)
     - Taxa de Custo Total Efetivo (TER - Total Expense Ratio)
  3. **Composição & Carteira do ETF:**
     `GET /api/backend/etf/{TICKER}/composition`
     Retorno: Ativos subjacentes, tickers, percentual na carteira, setor e país de origem.
  4. **Métricas de Negociação & Liquidez de ETF:**
     - NAV (Net Asset Value / Valor Patrimonial da Cota)
     - Spread NAV (Ágio ou Deságio da cota de mercado em relação ao NAV da carteira)
     - Limite de Aluguel (% do PL disponível para empréstimo)
     - Volume de Fluxo de Cotas em 30 Dias (criação e destruição de cotas pelo formador de mercado)
     - Método de replicação (Física completa, Física amostral, Sintética via derivativos)
     - Política de dividendos (Acumulativa com reinvestimento automático vs. Distributiva em conta).
* **Mapeamento para `fin-db`:**
  - Taxas e características do ETF -> `asset_details.etf_detalhe`
  - Composição do ETF -> `canonical.fund_holding`
  - NAV e Fluxo de Cotas -> `asset_details.etf_nav`, `asset_details.etf_fluxo_cotas`
  - Benchmarks Teva/B3 -> `market.benchmark`, `market.benchmark_componente`

---

## 4. Estratégia de Ingestão & Pipeline Unificado (`fin-ingestion`)

### 4.1 Ciclos de Execução & SLAs

```
                                ┌─────────────────────────────────────────┐
                                │             FIN-INGESTION               │
                                │        Orquestrador de Coleta           │
                                └────────────────────┬────────────────────┘
                                                     │
             ┌────────────────────────┬──────────────┴───────────────┬────────────────────────┐
             ▼                        ▼                              ▼                        ▼
     ┌──────────────┐         ┌──────────────┐               ┌──────────────┐         ┌──────────────┐
     │   INTRADAY   │         │    DAILY     │               │   MONTHLY    │         │  QUARTERLY   │
     │ (5-15 min)   │         │  (Pós-Fech.) │               │   (Mensal)   │         │ (Trimestral) │
     └──────┬───────┘         └──────┬───────┘               └──────┬───────┘         └──────┬───────┘
            │                        │                              │                        │
            ▼                        ▼                              ▼                        ▼
     • Cotações B3            • COTHIST B3                   • Informes CVM           • DFP / ITR CVM
     • Status Invest          • Curvas ANBIMA                • CDA Fundos 175         • Balanços DRE/DFC
     • Spread NAV ETFs        • SGS BCB PTAX/Selic           • Vacância FIIs          • Brick360 DRE
     • Fluxo Opções           • Status/Inv10 Indicadores     • Mais Retorno Lâminas   • FRE Governança
                              • ADVFN Indicadores Técnicos   • Clube FII Imóveis      • Remuneração Exec.
```

### 4.2 Camada de Resiliência & Anti-Bot
1. **Cabeçalhos de Emulação Completa de Navegador:**
   - Headers padronizados com `Sec-Ch-Ua`, `Sec-Ch-Ua-Mobile`, `Sec-Ch-Ua-Platform`, `User-Agent` de navegadores modernos (Chrome 120+, Safari 17+).
2. **Backoff Exponencial com Jitter:**
   - Utilização de `tenacity` com intervalos aleatorizados entre tentativas para evitar sincronização de requisições.
3. **Circuit Breaker Distribuído:**
   - Interrupção temporária de requisições a uma fonte quando a taxa de falhas consecutivas ultrapassar o limite (ex: 5 falhas consecutivas ou HTTP 429), evitando bloqueio permanente do IP.
4. **Idempotência & Raw Landing:**
   - Todo payload capturado é gravado em `raw.payload` com hash SHA-256 para evitar duplicidade de processamento antes da normalização nos esquemas canônicos.
