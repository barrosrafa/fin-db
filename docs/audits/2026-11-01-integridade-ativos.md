# Plano e execução — integridade dos ativos FIN (01/11/2026)

## Diagnóstico e evidências

Auditoria recebida: anexo `Texto colado.txt`. Investigação em fin-web, fin-api e
fin-ingestion; consultas ao banco estritamente somente leitura. Nenhum preço do
anexo será gravado como correção: as comparações misturam datas e bases.

Evidência observada no banco: FTCE11B 38133,72, PBLV11 663,11 e ANCR11B 3221,00
vêm da tabela legada market.cotacao_diaria, última referência 28/10/2026.
AXIA5/6 têm registros posteriores ao encerramento. A tabela legada não tem coluna
de fonte; `is_backtest_simulado=false` não comprova origem. Já market.nominal_bar
preserva fonte e sessão: TRXF11 66,45 e XPML11 96,80 em 30/10 têm source=b3.
Portanto esses preços não devem ser substituídos por valores de outros dias.
PBLV11: 663,11 / 1620,63 = 0,409; ANCR11B: 3221 / 120,29 = 26,777.
As razões do relatório são aritmeticamente coerentes com os insumos; a autenticidade
ou compatibilidade da base patrimonial continua exigindo documentação.

Fonte oficial de encerramento AXIA5/6, efetivo 08/06/2026:
https://www.b3.com.br/data/files/CB/71/43/E8/FC56E91064BF82E9AC094EA8/OC%20035-2026-VNC%20TRATAMENTO%20DAS%20CARTEIRAS%20DE%20INDICES%20DA%20B3_PT.pdf

## Causas e desenvolvimento, em ordem

1. **Serving sem prova da origem**. Criar `fin-api/app/market/quality.py` com uma
   relação SQL compartilhada que aceita cotações legadas apenas quando coincidem
   com OHLC nominal B3 da mesma identidade/sessão; recusar futuro e simulação.
   Aplicar a todos os leitores públicos de cotacao_diaria, inclusive comparador,
   rankings, ETFs e simulador. Preservar os registros originais para investigação.
   Resultado: dado não verificável fica indisponível, sem inventar preço ou fonte.
2. **Ausência de ciclo de negociação**. Centralizar eventos oficiais confirmados
   e status cadastral em `fin-api/app/market/lifecycle.py`. Expor status nos
   detalhes/listas e bloquear valuation atual para instrumento encerrado. Histórico
   permanece consultável. Não inferir deslistagem apenas da falta de negócios.
3. **Fallbacks fictícios em FIIs**. Reescrever `fin-api/app/fiis/service.py` para
   propagar NULL, retirar carteiras, DRE, score, cadastro e datas constantes.
   Ajustar `app/fiis/schemas.py`; preservar zeros reais. Recalcular P/VP somente
   com preço verificável e VP positivo. Não inferir DY anual a partir do último
   rendimento: falta de histórico completo significa indicador indisponível.
4. **Proveniência perdida**. Incluir fonte e sessão de cotação nos schemas de
   ações, FIIs e resumo; propagar para `src/lib/api.ts` e `DataStatus`. Separar a
   referência de preço da base patrimonial, cuja fonte legada não é comprovada.
   Não rotular dado diário como tempo real nem usar hora da requisição como pregão.
5. **Carregamento e mistura de páginas**. Em `fin-web/src/lib/api.ts`, combinar
   cancelamento com timeout por requisição. Em `FIIDetailClient.tsx`, carregar
   somente o detalhe do ticker, com cancelamento e estado final de ausência/erro;
   remover busca na primeira página, série sintética e preço padrão. Em
   `FundamentalIndicatorsGrid.tsx`, retirar o conjunto inteiro de números exemplo.
6. **Cobertura de navegação**. Preservar busca no servidor e paginação já existentes
   (`getAssetsPaginated`, `useInfiniteScroll`, `InfiniteScrollFooter`). 24 é tamanho
   de página, não limite de cobertura. Testar busca fora da primeira página e
   adicionar contagem clara. Não renderizar centenas de cartões de uma só vez.
7. **Prevenção na escrita**. Em `fin-ingestion/fin_ingestion/dw/dw_writer.py`, recusar
   sessões futuras antes de abrir conexão. O fator COTAHIST já é normalizado por
   `MarketGateway.normalize_official`; testar fator !=1 e evitar nova divisão.
8. **Validação e recuperação**. Testes de ausência, zero, ticker inexistente,
   encerramento, divergência, futuro, cancelamento e cobertura. Executar suites,
   tipos/lint/build e consultas reais somente leitura. Registrar resultados aqui.
   Para recuperação de preços sem prova: reprocessar COTAHIST oficial da sessão
   no runtime existente; nunca ajustar preços manualmente nem usar medianas de
   datas diferentes. Investigar eventos societários antes de reprovar variações.

## Segurança e critérios de aceite

Sem remoção de históricos, alteração de carteiras do usuário ou carga de valores
copiados de portais. Nenhuma nova infraestrutura paga. Mudanças de fonte devem
falhar com ausência explícita; preço alto isolado não reprova um ativo ilíquido.
Testes não podem escrever no banco de produção. Entrega local e implantação são
estados distintos e serão registrados separadamente. Rollback: reverter o commit
nos repositórios afetados, preservando dados e recibos; não reativar serving sem
proveniência como medida automática.

Critérios: nenhum dado fictício nos detalhes FII; requests terminam ou cancelam;
preço e data com fonte verificável; encerrados identificados sem valuation atual;
listagem e detalhe usam mesma referência; alterações cobrem todas as identidades,
sem uma lista de preços especiais para os exemplos do relatório.

## Resultados da execução

### Causa raiz confirmada no código

O problema não é um conjunto de preços isolados por ticker. Leituras públicas
usavam `market.cotacao_diaria` sem prova de origem, e parte do front-end e do
serviço de FIIs preenchia lacunas com números demonstrativos ou métricas legadas.
Assim, uma linha antiga, simulada ou fora de sessão podia parecer cotação atual;
P/VP podia vir de uma base sem proveniência; status de negociação não era
propagado de modo uniforme. A causa alcança a consulta comum de ativos, detalhes,
históricos, screener, rankings, comparador, simuladores e carteiras.

### Etapas implementadas localmente

1. **Porta comum de cotações** — `fin-api/app/market/quality.py` aceita preço
   legado somente quando ele coincide com `market.nominal_bar` de fonte B3, em
   BRL, intervalo diário, mesma sessão e ticker. Rejeita fechamento não positivo,
   sessão futura e linha marcada como simulação. Os serviços que leem cotações
   importam essa porta; os registros históricos permanecem intactos.
2. **Exposição de preço e ciclo de negociação** — `fin-api/app/market/service.py`,
   `app/stocks/service.py`, `app/stocks/schemas.py`, `app/fiis/service.py` e
   `app/market/lifecycle.py` propagam fonte, sessão e status. AXIA5/AXIA6 usam o
   evento B3 documentado; outros ativos dependem do cadastro canônico. Valuation
   de ação encerrada responde indisponível e históricos continuam consultáveis.
3. **Remoção de indicadores FII sem base demonstrável** — `fin-api/app/fiis/service.py`
   não inventa cadastros, vacância, imóveis, carteira, DRE ou Brick Score. P/VP
   usa preço aceito e VPA positivo de informe CVM não ambíguo, na view aditiva
   `fin/sql/23_asset_serving_integrity/01_verified_fii_reference.sql`. DY 12M e
   filtros por DY ficam indisponíveis sem cobertura verificável da janela.
   Ausência fica `null`; zero observado permanece zero.
4. **Redução de bypasses e declarações falsas** — `fin-api/app/market/service.py`
   deixa de aceitar cotações Redis sem contrato de proveniência, não troca
   variação ausente por 0, não anuncia DY de FII incompleto e calcula P/VP de FII
   apenas com VPA positivo. `app/portfolio/service.py` e
   `app/worker/tasks/cache.py` usam a mesma porta para preços de carteira/cache.
   `app/fiis/schemas.py` representa campos ausentes como opcionais.
5. **Interface e contratos** — `fin-web/src/lib/api.ts` aplica prazo limite às
   requisições e permite cancelamento; `src/schemas/financial.ts` aceita valores
   ausentes; detalhes de FIIs e ETFs carregam apenas o ticker pedido e mostram estados
   de indisponibilidade. Home e listas de ações, FIIs e ETFs mostram fonte/data/status.
   `FIIDetailClient.tsx`, `FundamentalIndicatorsGrid.tsx`,
   `CadastralGovernanceCard.tsx`, `FinancialStatementsTable.tsx`,
   `DividendHistoryTable.tsx` e `TradingStatusNotice.tsx` removem valores exemplo,
   comunicam proveniência/status e não projetam renda sem insumos.
6. **Proteção de escrita** — `fin-ingestion/fin_ingestion/dw/dw_writer.py` recusa
   sessão futura antes de abrir conexão; a normalização oficial de fator segue
   como responsabilidade do `MarketGateway.normalize_official`. O script
   `fin-ingestion/fin_ingestion/operations/replay_official_quotes.py` prepara um
   preview padrão e grava preimage/arquivo fonte antes de escrita idempotente com
   `--apply`; nenhum modo apply foi executado.
7. **Cobertura pretendida** — busca e paginação no servidor foram preservadas.
   Os gates SQL são aplicados à consulta, não a uma lista especial dos exemplos
   do relatório, para alcançar todas as identidades cobertas pelos dados oficiais.

### Segurança e alcance da execução

As alterações ficaram locais nos worktrees existentes. Nenhuma consulta de
correção foi executada no banco, nenhum histórico foi apagado e nenhuma
infraestrutura ou segredo foi alterado. Testes de regressão locais existem em
`fin-api/tests/test_audit_remediation.py`,
`fin-api/tests/test_audit_quote_evidence_postgres.py`,
`fin-web/src/lib/__tests__/audit-remediation.test.ts` e
`fin-ingestion/tests/test_audit_quote_dates.py`; não foram executados. Também
não houve build, deploy, push nem reprocessamento; produção ainda não foi
corrigida. A migração 23 precisa ser aplicada antes do deploy da API que lê sua
view CVM.

A auditoria contém outros achados independentes (autenticação, Docker, CSP,
migrações, IA/regulação, scraping, navegação, infraestrutura e streaming). Eles
não são pré-requisitos para proteger a leitura de preços de todos os ativos e
permanecem fora desta remediação focada em integridade de ativos. Filtros fixos
de ADTV/P/VP sugeridos no anexo não foram adotados: preço alto ou baixa liquidez
isolados não provam erro de mercado e tais cortes ocultariam ativos legítimos.
