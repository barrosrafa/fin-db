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
   `--apply`. A execução oficial de outubro foi aplicada com backup e recibo, conforme evidências abaixo.
7. **Cobertura pretendida** — busca e paginação no servidor foram preservadas.
   Os gates SQL são aplicados à consulta, não a uma lista especial dos exemplos
   do relatório, para alcançar todas as identidades cobertas pelos dados oficiais.

### Segurança e alcance da execução

Foram aplicados ao banco os dois arquivos aditivos do estágio 23, com histórico
transacional e checksum do runner. O preview oficial de outubro encontrou 31.014
candles de 2.016 tickers; 12.882 candles correspondem a instrumentos cadastrados,
com 1.284 fechamentos diferentes da base legada. O replay de outubro foi aplicado:
31.014 registros nominais e 12.882 de serving, status `SUCCEEDED`. Nenhum histórico
foi apagado. O arquivo fonte e uma preimage de 478 KB foram preservados antes da
escrita. Não houve alteração de carteiras, autenticação ou infraestrutura paga.

Evidências locais: `/Users/rafaelaparecido/fin-run/verification/asset-audit-2026-11-01/`:

- `apply.json`: recibo, contagens e URL oficial do arquivo.
- `preimage-20261101T170451694396.json.gz`: valores públicos anteriores ao replay.
- `serving-after.json`: validação somente leitura dos exemplos, sem erros.
- `universe-validation.json`: busca/paginação cobrindo todos os cadastros.

Cobertura validada: 606 FIIs (331 com cotação comprovada, 281 com P/VP CVM não
ambíguo), 617 ações (385 com cotação comprovada; dois encerramentos confirmados) e
10 ETFs (cinco com cotação comprovada). Todos os cadastros permanecem pesquisáveis.
Ausência de evidência não vira preço zero nem provoca inferência de deslistagem.
O total do ranking FII é preservado inclusive em offset além da última página.

Os testes novos de integridade passaram em PostgreSQL isolado. Frontend: 46 testes,
TypeScript e build de produção passaram; lint sem erros, com 21 avisos preexistentes.
Banco: 67 SQLs validados e seis testes do plano de migração passaram. API: 189 testes passaram em PostgreSQL descartável; dois testes de integração
com serviços opcionais ficaram para a CI. Ingestão: 27 testes passaram, incluindo
PostgreSQL real, replay, fator de cotação, datas e proteção do backfill. Os ambientes
de teste foram atualizados com evidência pública B3 e CVM e cenários sintéticos
restritos ao banco fin_ci. Total local: 268 testes aprovados e dois condicionais.

As alterações estão versionadas e enviadas em PRs:
[fin-db #8](https://github.com/barrosrafa/fin-db/pull/8),
[fin-api #5](https://github.com/barrosrafa/fin-api/pull/5),
[fin-web #5](https://github.com/barrosrafa/fin-web/pull/5) e
[fin-ingestion #9](https://github.com/barrosrafa/fin-ingestion/pull/9).
A execução de banco acima não equivale à publicação dos serviços: o estado de
release será registrado separadamente, com os checks do SHA correspondente.

A auditoria contém outros achados independentes (autenticação, Docker, CSP,
migrações, IA/regulação, scraping, navegação, infraestrutura e streaming). Eles
não são pré-requisitos para proteger a leitura de preços de todos os ativos e
permanecem fora desta remediação focada em integridade de ativos. Filtros fixos
de ADTV/P/VP sugeridos no anexo não foram adotados: preço alto ou baixa liquidez
isolados não provam erro de mercado e tais cortes ocultariam ativos legítimos.

## Trechos centrais da correção

### Preço: `fin-api/app/market/quality.py`

Antes, a existência de uma linha em `market.cotacao_diaria` bastava. Agora o
compilador das consultas de leitura exige evidência independente:

```sql
WHERE official.ticker = identity.ticker
  AND official.reference_date = legacy.data_pregao
  AND official.source = 'b3' AND official.currency = 'BRL'
  AND official.interval = 'day'
  AND official.close = legacy.preco_fechamento
```

A mesma consulta compara OHLC quando informado, reprova simulação e datas
futuras. A porta nunca é usada para INSERT/UPDATE de carteira: essas operações
continuam usando `sqlalchemy.text`, preservando autenticação e transações.

### Patrimônio: migração 23 e `fin-api/app/fiis/service.py`

```sql
GROUP BY ticker
HAVING count(DISTINCT cnpj_fundo) = 1
   AND count(DISTINCT valor_patrimonial_cota) <= 1
   AND count(DISTINCT patrimonio_liquido) <= 1
```

```python
vp = number(row.get("official_vpa"))
pvp = price / vp if price is not None and vp is not None and vp > 0 else None
```

É uma razão de preço nominal atual por patrimônio do informe identificado; as
duas datas são exibidas separadamente. Não se atribui o preço de uma fonte à data
de outra. Fundos sem identidade CVM unívoca ficam sem VPA/P/VP comprováveis.

### Cancelamento: `fin-web/src/lib/api.ts` e `snapshots.ts`

```typescript
signal: options?.signal
  ? AbortSignal.any([options.signal, AbortSignal.timeout(15_000)])
  : AbortSignal.timeout(15_000)
```

`FIIDetailClient` usa somente `getFIIDetail(ticker, signal)`, valida a identidade
da resposta, ignora respostas canceladas e encerra loading em `finally`. Nunca
consulta a primeira página para adivinhar o preço do ticker. O `DataStatus`
avalia envelhecimento depois da hidratação, preservando o prerender do Next 16.

### Negociação: `fin-api/app/market/lifecycle.py`

```python
if trading_status(t, asset_row.get("registry_status")).status == "inactive":
    raise HTTPException(status_code=409, detail="Trading ended; current valuation unavailable")
```

Eventos confirmados têm vigência, sucessor e documento de origem. A data de negócio
é avaliada em `America/Sao_Paulo`, inclusive nos testes de cobertura da carteira.
Ausência de negociação em outubro não equivale a encerramento.

### Recuperação: `fin-ingestion/fin_ingestion/operations/replay_official_quotes.py`

```bash
python -m fin_ingestion.operations.replay_official_quotes \
  --year 2026 --month 10 --output /caminho/para/evidencias
# Após conferir o preview, a mesma operação com --apply preserva preimage
# e publica primeiro a evidência nominal, depois a projeção legada.
```

O arquivo anual de 2026 ultrapassou o limite de descompressão do coletor e foi
recusado sem escrita. Foi usado o arquivo mensal oficial, mantendo o limite de
segurança. O replay não cria classificações para tickers ainda não cadastrados.
O backfill secundário passa a preservar registros cuja sessão já tem prova B3.
