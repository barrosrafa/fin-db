# SDD — Complementos ao fin-db para Cobertura de Sites de Análise

**Versão:** 1.0
**Escopo:** Apenas **adições** (novas tabelas, novas colunas, novos seeds). Nenhuma remoção, rename ou alteração de colunas existentes.
**Base:** Análise de gap entre os schemas atuais (`canonical`, `asset_details`, `market`, `analytics`, `core`, `raw`, `system`, `social`, `wealth`) e os sites: Status Invest, Investidor10, Fundamentei, Fundamentus, Clube FII, Funds Explorer, FIIs.com.br, maisretorno.com, analisedeacoes.com, brick360.com.br, br.advfn.com, etfsbrasil.com.br.

> **Convenções adotadas neste documento** (assumidas por não estarem explícitas no README do repositório, devem ser confirmadas no início da execução):
> - Migrações em `db/migrations/` no padrão `YYYYMMDD_NNN__descricao.sql`.
> - Modelos dbt em `dbt/models/<schema>/`.
> - Seeds em `dbt/seeds/`.
> - Testes dbt em `dbt/tests/` e `schema.yml` por modelo.
> - PKs UUID com `gen_random_uuid()`; timestamps `timestamptz default now()`; `created_at`/`updated_at` em todas as novas tabelas.
> - Foreign keys para `core.instrument(id)`, `core.emissor_companhia(id)`, `canonical.legal_entity(id)`.

---

## 1. Visão geral das mudanças

| # | Mudança | Site(s) alvo | Tipo | Fase |
|---|---|---|---|---|
| M1 | Nova tabela `canonical.government_bond_quote` | Status Invest | Tabela nova | 1 |
| M2 | Nova tabela `asset_details.mercado_imobiliario_indicador` | Clube FII | Tabela nova | 1 |
| M3 | Nova tabela `canonical.news_article` | Funds Explorer, Investidor10 | Tabela nova | 1 |
| M4 | Nova tabela `analytics.valuation` | analisedeacoes.com | Tabela nova | 1 |
| M5 | Nova tabela `analytics.score_eixo` | brick360 | Tabela nova | 1 |
| M6 | Nova tabela `canonical.insider_transaction` | br.advfn.com | Tabela nova | 1 |
| M7 | Nova tabela `canonical.institutional_holding` | br.advfn.com | Tabela nova | 1 |
| M8 | Colunas novas em `canonical.fund_profile` | Status Invest (FI-Infra/FIAGRO) | ALTER ADD | 2 |
| M9 | Colunas novas em `asset_details.detalhe_fii` | Clube FII | ALTER ADD | 2 |
| M10 | Seeds de `canonical.metric_definition` (novos indicadores) | Fundamentus, Fundamentei, analisedeacoes | Seed | 3 |
| M11 | Reuso de `canonical.fund_holding` para composição de ETF (sem nova tabela) | etfsbrasil.com.br | Documentação + índice | 3 |
| M12 | Índices e `schema.yml` dos modelos novos | Todos | Infra | 3 |

> **Fora de escopo (não duplicar):** `analytics.screener_result` (derivar como view materializada sobre `analytics.filtro_salvo` + `canonical.metric_observation`); comparador de ETFs (view sobre `asset_details.etf_detalhe`); mapa de FIIs (view sobre `asset_details.composicao_carteira_fii` + `core.emissor_companhia`). Esses itens já são deriváveis.

---

## 2. Fase 1 — Novas tabelas (migrações `20261026_001` a `20261026_007`)

### M1 — `canonical.government_bond_quote`

**Objetivo:** armazenar cotações/duration/taxa de compra e venda do Tesouro Direto, exibidos pelo Status Invest. `canonical.government_bond` já tem `indexer`, `maturity_date`, `coupon_rate` — não alterar.

**Arquivo criado:** `db/migrations/20261026_001__create_government_bond_quote.sql`

```sql
create table if not exists canonical.government_bond_quote (
    id                  uuid primary key default gen_random_uuid(),
    government_bond_id  uuid not null references canonical.government_bond(id) on delete cascade,
    quote_date          date not null,
    buy_rate            numeric(12,6),
    sell_rate           numeric(12,6),
    buy_price           numeric(18,6),
    sell_price          numeric(18,6),
    duration_years      numeric(8,4),
    source              text not null,
    raw_payload_id      uuid references raw.payload(id),
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    unique (government_bond_id, quote_date, source)
);

create index ix_gbq_bond_date
    on canonical.government_bond_quote (government_bond_id, quote_date desc);
```

**Modelo dbt:** `dbt/models/canonical/government_bond_quote.sql` (staging do `raw.payload` do Status Invest → `canonical.government_bond_quote`).
**Teste:** `dbt/tests/canonical/test_gbq_dates_not_future.sql` (`quote_date <= current_date`).

---

### M2 — `asset_details.mercado_imobiliario_indicador`

**Objetivo:** indicadores de mercado imobiliário por cidade/região/tipo de imóvel (preço/m², nº de transações) usados pelo Clube FII.

**Arquivo criado:** `db/migrations/20261026_002__create_mercado_imobiliario_indicador.sql`

```sql
create table if not exists asset_details.mercado_imobiliario_indicador (
    id              uuid primary key default gen_random_uuid(),
    uf              char(2) not null,
    cidade          text not null,
    regiao          text,
    tipo_imovel     text not null check (tipo_imovel in ('residencial','comercial','logistico','rural','outro')),
    data_referencia date not null,
    preco_m2        numeric(18,2),
    variacao_12m    numeric(10,6),
    transacoes      integer,
    source          text not null,
    raw_payload_id  uuid references raw.payload(id),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    unique (uf, cidade, coalesce(regiao,''), tipo_imovel, data_referencia, source)
);

create index ix_mii_uf_cidade_tipo
    on asset_details.mercado_imobiliario_indicador (uf, cidade, tipo_imovel, data_referencia desc);
```

> **Nota:** o `unique` com `coalesce` pode ser trocado por um índice único parcial (`where regiao is null`) se preferível. Manter um dos dois.

---

### M3 — `canonical.news_article`

**Objetivo:** notícias de FIIs e ativos (Funds Explorer, Investidor10). Nada no schema atual armazena conteúdo editorial.

**Arquivo criado:** `db/migrations/20261026_003__create_news_article.sql`

```sql
create table if not exists canonical.news_article (
    id              uuid primary key default gen_random_uuid(),
    external_id     text,
    source          text not null,
    url             text not null,
    title           text not null,
    summary         text,
    body            text,
    published_at    timestamptz not null,
    author          text,
    tags            text[],
    raw_payload_id  uuid references raw.payload(id),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    unique (source, url)
);

create index ix_news_published on canonical.news_article (published_at desc);
create index ix_news_tags      on canonical.news_article using gin (tags);
```

**Tabela de ligação (nova, necessária):** `canonical.news_article_instrument`

```sql
create table if not exists canonical.news_article_instrument (
    news_article_id uuid not null references canonical.news_article(id) on delete cascade,
    instrument_id   uuid not null references core.instrument(id) on delete cascade,
    primary key (news_article_id, instrument_id)
);
```

---

### M4 — `analytics.valuation`

**Objetivo:** registrar preço justo por metodologia (Graham, Bazin, DCF, etc.) e margem de segurança (analisedeacoes.com). `metric_observation` guarda o valor, mas não a metodologia/parâmetros.

**Arquivo criado:** `db/migrations/20261026_004__create_valuation.sql`

```sql
create table if not exists analytics.valuation (
    id               uuid primary key default gen_random_uuid(),
    instrument_id    uuid not null references core.instrument(id) on delete cascade,
    data_referencia  date not null,
    metodologia      text not null,
    parametros       jsonb not null default '{}'::jsonb,
    preco_justo      numeric(18,6) not null,
    preco_mercado    numeric(18,6),
    margem_seguranca numeric(10,6),
    source           text not null,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    unique (instrument_id, data_referencia, metodologia, source)
);

create index ix_valuation_instrument_data
    on analytics.valuation (instrument_id, data_referencia desc);
```

---

### M5 — `analytics.score_eixo`

**Objetivo:** decomposição do score do Brick360 em eixos (financeiro, imóveis, inquilinos, gestores, riscos, projeções). `analytics.score_ativo` continua sendo o score agregado — não alterar.

**Arquivo criado:** `db/migrations/20261026_005__create_score_eixo.sql`

```sql
create table if not exists analytics.score_eixo (
    id            uuid primary key default gen_random_uuid(),
    score_ativo_id uuid not null references analytics.score_ativo(id) on delete cascade,
    eixo          text not null check (eixo in (
                     'financeiro','imoveis','inquilinos','gestores','riscos','projecoes','outro')),
    pontuacao     numeric(10,4) not null,
    peso          numeric(6,4),
    detalhes      jsonb not null default '{}'::jsonb,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    unique (score_ativo_id, eixo)
);

create index ix_score_eixo_ativo on analytics.score_eixo (score_ativo_id);
```

> **Premissa:** `analytics.score_ativo` possui coluna `id` (PK). Se a PK for composta (`instrument_id, data`), a FK deve ser ajustada para a chave composta correspondente — validar antes da migração.

---

### M6 — `canonical.insider_transaction`

**Objetivo:** transações de insiders (diretores/controladores) exibidas pelo ADVFN. Não existe no schema atual.

**Arquivo criado:** `db/migrations/20261026_006__create_insider_transaction.sql`

```sql
create table if not exists canonical.insider_transaction (
    id             uuid primary key default gen_random_uuid(),
    instrument_id  uuid not null references core.instrument(id) on delete cascade,
    pessoa_nome    text not null,
    cargo          text,
    tipo           text not null check (tipo in ('compra','venda','opcao','doacao','outro')),
    quantidade     numeric(20,4) not null,
    preco_unitario numeric(18,6),
    data_negocio   date not null,
    fonte_documento text,
    source         text not null,
    raw_payload_id uuid references raw.payload(id),
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    unique (instrument_id, pessoa_nome, data_negocio, tipo, quantidade, source)
);

create index ix_insider_instrument_data
    on canonical.insider_transaction (instrument_id, data_negocio desc);
```

---

### M7 — `canonical.institutional_holding`

**Objetivo:** participação institucional (fundos, gestoras) por ativo, com histórico.

**Arquivo criado:** `db/migrations/20261026_007__create_institutional_holding.sql`

```sql
create table if not exists canonical.institutional_holding (
    id              uuid primary key default gen_random_uuid(),
    instrument_id   uuid not null references core.instrument(id) on delete cascade,
    instituicao_id  uuid references canonical.legal_entity(id),
    instituicao_nome text not null,
    data_referencia date not null,
    quantidade      numeric(20,4) not null,
    participacao_pct numeric(10,6),
    variacao_pct    numeric(10,6),
    source          text not null,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    unique (instrument_id, instituicao_nome, data_referencia, source)
);

create index ix_inst_holding_inst_data
    on canonical.institutional_holding (instrument_id, data_referencia desc);
```

---

## 3. Fase 2 — Extensões a tabelas existentes (ALTER ADD apenas)

### M8 — `canonical.fund_profile`

**Objetivo:** cobrir FI-Infra e FIAGRO do Status Invest com benchmark, taxa de administração e performance.

**Arquivo criado:** `db/migrations/20261026_008__alter_fund_profile_add_fees.sql`

```sql
alter table canonical.fund_profile
    add column if not exists benchmark        text,
    add column if not exists management_fee   numeric(10,6),
    add column if not exists performance_fee  numeric(10,6),
    add column if not exists performance_benchmark text;
```

> **Segurança:** `ADD COLUMN IF NOT EXISTS` é idempotente e não quebra leitura existente. Não remover nem renomear nada.

### M9 — `asset_details.detalhe_fii`

**Objetivo:** taxas e benchmark de performance para o Clube FII (`detalhe_fii` já tem gestor/administrador, faltam taxas).

**Arquivo criado:** `db/migrations/20261026_009__alter_detalhe_fii_add_fees.sql`

```sql
alter table asset_details.detalhe_fii
    add column if not exists management_fee   numeric(10,6),
    add column if not exists performance_fee  numeric(10,6),
    add column if not exists performance_benchmark text,
    add column if not exists taxa_total       numeric(10,6);
```

---

## 4. Fase 3 — Seeds, reuso e infraestrutura

### M10 — Seeds de `canonical.metric_definition`

**Objetivo:** popular o catálogo com os indicadores exibidos por Fundamentus, Fundamentei e analisedeacoes que ainda não existam. **Não alterar** `metric_definition`; apenas inserir linhas.

**Arquivo criado:** `dbt/seeds/metric_definition_additional.csv`

```csv
code,name,description,unit,category,higher_is_better
pl,Preço/Lucro,Relação preço sobre lucro,ratio,valuation,false
pvp,Preço/Valor Patrimonial,Preço sobre valor patrimonial,ratio,valuation,false
psr,Preço/Receita,Preço sobre receita,ratio,valuation,false
dy,Dividend Yield,Dividendos sobre preço,percent,proventos,true
roe,ROE,Retorno sobre patrimônio líquido,percent,rentabilidade,true
roic,ROIC,Retorno sobre capital investido,percent,rentabilidade,true
roa,ROA,Retorno sobre ativos,percent,rentabilidade,true
ev_ebitda,EV/EBITDA,Enterprise value sobre EBITDA,ratio,valuation,false
ev_ebit,EV/EBIT,Enterprise value sobre EBIT,ratio,valuation,false
margem_bruta,Margem Bruta,Lucro bruto sobre receita,percent,rentabilidade,true
margem_ebit,Margem EBIT,EBIT sobre receita,percent,rentabilidade,true
margem_liquida,Margem Líquida,Lucro líquido sobre receita,percent,rentabilidade,true
liquidez_corrente,Liquidez Corrente,Ativo circulante sobre passivo circulante,ratio,liquidez,true
divida_ebitda,Dívida Líquida/EBITDA,Dívida líquida sobre EBITDA,ratio,endividamento,false
divida_pl,Dívida/Patrimônio,Dívida sobre patrimônio líquido,ratio,endividamento,false
cagr_receita_5a,CAGR Receita 5a,Crescimento anual composto da receita em 5 anos,percent,crescimento,true
cagr_lucro_5a,CAGR Lucro 5a,Crescimento anual composto do lucro em 5 anos,percent,crescimento,true
payout,Payout,Payout de dividendos,percent,proventos,null
graham_preco_justo,Preço Justo Graham,Preço justo pela fórmula de Graham,currency,valuation,true
bazin_preco_justo,Preço Justo Bazin,Preço justo pelo método Bazin,currency,valuation,true
```

**Modelo dbt de carga:** `dbt/models/canonical/metric_definition_seed.sql` — `insert ... on conflict (code) do nothing` sobre `canonical.metric_definition`.

> **Verificação prévia obrigatória:** rodar `select code from canonical.metric_definition` e remover do CSV os códigos já existentes (o `on conflict do nothing` garante idempotência, mas evita poluição).

---

### M11 — Reuso de `canonical.fund_holding` para ETFs (etfsbrasil.com.br)

**Sem criar tabela nova** — ETFs são fundos e a composição deve entrar em `canonical.fund_holding` (campo `composicao_carteira_url` em `etf_detalhe` permanece como está).

**Ações:**
1. Validar que `canonical.fund_holding` aceita `instrument_id` do ETF (FK para `core.instrument`). Se hoje só aceita `fund_profile_id`, adicionar coluna opcional:

**Arquivo criado:** `db/migrations/20261026_010__alter_fund_holding_add_etf_support.sql`

```sql
alter table canonical.fund_holding
    add column if not exists etf_instrument_id uuid references core.instrument(id);

create index if not exists ix_fund_holding_etf
    on canonical.fund_holding (etf_instrument_id, data_referencia desc);
```

2. **Criar view de conveniência** para o comparador do site:

**Arquivo criado:** `dbt/models/asset_details/etf_composicao.sql`

```sql
{{ config(materialized='view', schema='asset_details') }}

select
    fh.etf_instrument_id      as instrument_id,
    fh.data_referencia,
    fh.ativo_id,
    fh.ativo_descricao,
    fh.percentual,
    fh.quantidade
from canonical.fund_holding fh
where fh.etf_instrument_id is not null;
```

> **Regra "sem duplicar":** não criar `asset_details.etf_composicao` como tabela — a view é derivada de `fund_holding`.

---

### M12 — Índices e `schema.yml`

**Arquivos criados:**

- `dbt/models/canonical/schema.yml` — adicionar entradas para `government_bond_quote`, `news_article`, `news_article_instrument`, `insider_transaction`, `institutional_holding`.
- `dbt/models/asset_details/schema.yml` — adicionar entradas para `mercado_imobiliario_indicador`, `etf_composicao`.
- `dbt/models/analytics/schema.yml` — adicionar entradas para `valuation`, `score_eixo`.

**Exemplo de bloco (colar dentro do `schema.yml` de cada schema, sem alterar blocos existentes):**

```yaml
models:
  - name: government_bond_quote
    description: "Cotações do Tesouro Direto (Status Invest)."
    columns:
      - name: government_bond_id
        tests: [not_null, relationships:
                  {to: ref('government_bond'), field: id}]
      - name: quote_date
        tests: [not_null]
      - name: buy_rate
        tests: [not_null]
```

**Testes SQL adicionais:**

- `dbt/tests/canonical/test_news_url_unique_per_source.sql` — `select source, url, count(*) from canonical.news_article group by 1,2 having count(*) > 1`.
- `dbt/tests/analytics/test_valuation_margem_sign.sql` — `select * from analytics.valuation where preco_justo <= 0`.
- `dbt/tests/analytics/test_score_eixo_sum.sql` — soma dos `peso` por `score_ativo_id` = 1 (tolerância 0.01) para eixos do brick360.

---

## 5. Passo a passo de desenvolvimento (ordem de execução)

**Pré-requisitos**
1. Confirmar com o time: estrutura real do repositório (`db/migrations/` vs `migrations/`), padrão de migração (Flyway/Sqitch/raw), presença de PK `id` em `analytics.score_ativo`, presença de `instrument_id` em `canonical.fund_holding`.
2. Criar branch `feature/complementos-sites-analise`.

**Fase 1 — Tabelas novas**
3. Criar `20261026_001__create_government_bond_quote.sql` → rodar em dev → validar.
4. Criar `20261026_002__create_mercado_imobiliario_indicador.sql` → idem.
5. Criar `20261026_003__create_news_article.sql` (inclui `news_article_instrument`) → idem.
6. Criar `20261026_004__create_valuation.sql` → idem.
7. Criar `20261026_005__create_score_eixo.sql` → idem.
8. Criar `20261026_006__create_insider_transaction.sql` → idem.
9. Criar `20261026_007__create_institutional_holding.sql` → idem.
10. Criar modelos dbt de staging/carga: `dbt/models/canonical/government_bond_quote.sql`, `dbt/models/asset_details/mercado_imobiliario_indicador.sql`, `dbt/models/canonical/news_article.sql`, `dbt/models/analytics/valuation.sql`, `dbt/models/analytics/score_eixo.sql`, `dbt/models/canonical/insider_transaction.sql`, `dbt/models/canonical/institutional_holding.sql` (um arquivo por modelo, referenciando `raw.payload`).

**Fase 2 — ALTER ADD**
11. Criar `20261026_008__alter_fund_profile_add_fees.sql` → rodar → validar leitura existente.
12. Criar `20261026_009__alter_detalhe_fii_add_fees.sql` → idem.
13. Atualizar modelos dbt que alimentam `fund_profile` e `detalhe_fii` para preencher as novas colunas (apenas `insert/update`, sem alterar colunas existentes).

**Fase 3 — Seeds, ETF, testes**
14. Extrair lista atual de `canonical.metric_definition.code`; criar `dbt/seeds/metric_definition_additional.csv` apenas com os ausentes.
15. Criar `dbt/models/canonical/metric_definition_seed.sql` (upsert idempotente).
16. Criar `20261026_010__alter_fund_holding_add_etf_support.sql` → rodar.
17. Criar view `dbt/models/asset_details/etf_composicao.sql`.
18. Atualizar os `schema.yml` de `canonical`, `asset_details`, `analytics` (adicionar entradas, **não sobrescrever** as existentes).
19. Criar os 3 testes SQL adicionais (M12) e rodar `dbt test --select tag:complementos`.

**Finalização**
20. Rodar `dbt run` completo em dev e comparar contagens antes/depois por tabela tocada.
21. Abrir PR com a checklist abaixo.

---

## 6. Checklist de PR

- [ ] Todas as migrações usam `IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS`.
- [ ] Nenhuma coluna/tabela existente foi removida ou renomeada.
- [ ] `metric_definition` só recebeu inserts (nenhum update).
- [ ] `dbt test` verde.
- [ ] `dbt run` idempotente (rodar duas vezes, mesmos resultados).
- [ ] `schema.yml` de cada schema revisado apenas com adições.
- [ ] `canonical.fund_holding` validada com dados de ETF em dev.

---

## 7. Estratégia de rollback

Por mudança, o rollback é:

| Mudança | Rollback |
|---|---|
| M1–M7 | `drop table if exists <tabela> cascade;` (novas, sem dependentes) |
| M8–M9 | `alter table ... drop column if exists <coluna>;` |
| M10 | `delete from canonical.metric_definition where code in (<lista do seed>);` |
| M11 | `drop view if exists asset_details.etf_composicao;` + `alter table canonical.fund_holding drop column if exists etf_instrument_id;` |

Manter um arquivo `db/migrations/rollback/20261026_rollback.sql` com os comandos acima comentados por migração.

---

## 8. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| `analytics.score_ativo` não ter PK `id` | Validar antes de M5; ajustar FK para chave composta |
| `canonical.fund_holding` já ter coluna equivalente a `etf_instrument_id` | Reusar a existente e remover M11 da migração |
| `metric_definition` já conter parte dos códigos | Rodar `select` prévio e reduzir o CSV (passo 14) |
| Migrações em produção sem janela | Todas são `IF NOT EXISTS` / `ADD COLUMN` (DDL não bloqueante no PG 11+), sem rewrite de tabela |
| Divergência de padrão de migração | Confirmar no passo 1 antes de qualquer código |

---

## 9. Critérios de aceite

- Os 12 sites listados conseguem ser alimentados usando **exclusivamente** os schemas `canonical`, `asset_details`, `market` e `analytics` (via tabelas novas + views de M11 + seeds de M10).
- Nenhuma tabela/coluna pré-existente foi alterada em tipo, nome ou nulidade.
- `dbt test` cobre 100% das tabelas novas (testes de `not_null`, `unique`, `relationships` e os 3 testes SQL adicionais).
- Documentação de cada tabela nova presente no `schema.yml` correspondente.