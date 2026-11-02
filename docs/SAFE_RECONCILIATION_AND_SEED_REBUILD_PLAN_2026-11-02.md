# Plano seguro de reconciliação do Neon e reconstrução de seeds

**Estado:** plano; nenhuma migration, seed, importação, refresh ou alteração de ledger executada no Neon.

## Evidências atuais

A auditoria somente leitura de 02/11/2026 no Neon `fin-app` / branch `production` encontrou:

- `system.schema_migrations` ausente e schema de metadados `fin_db_migrations` ausente. Portanto, os checksums das migrations não podem ser classificados como MATCH ou DRIFT: o estado é UNKNOWN.
- O banco contém schemas e objetos financeiros, mas os dois formatos de histórico consultados não existem. Não assumir que o banco é novo nem que é vazio apenas porque faltam os ledgers.
- Nenhuma política `scheduled_%` nem linha em `ingestion.source_policy` foi encontrada.
- Contagens exatas zero nas tabelas `core.moeda`, `core.fuso_horario`, `market.benchmark`, `analytics.tag`, `system.oauth_provider` e `canonical.metric_definition`; também zero em amostras de instrumentos, cotações, proventos e payload raw. Estatísticas aproximadas indicaram zero linhas nas tabelas de `core`, `market`, `analytics` e `system`, mas não substituem uma contagem exata de todas as tabelas.

## Bloqueio imediato

Não executar `scripts/migrate.py`, `scripts/apply_runtime_migrations.py`, seeders, importadores, `REFRESH MATERIALIZED VIEW` nem escrita manual de checksums até completar os passos abaixo. Em particular, não usar a ausência de ledger como justificativa para marcar todas as migrations antigas como aplicadas: o runner do `fin-db` poderia interpretar todas como pendentes e reaplicar DDL histórico.

O `system.schema_migrations` aparece como objeto criado em `sql/19_merge_base_b/01_merge_generated_structure.sql`, mas sua ausência atual não prova que essa migration nunca foi parcialmente aplicada; é preciso comparar objetos reais e história de implantação.

## Plano por fases

### 1. Preservar e conferir evidências

1. Manter o pacote `fin-db-legacy-assets-review.zip` fora do caminho de execução/deploy. Ele preserva, como texto não executável, os arquivos removidos no commit `c6e7e35` e inclui manifesto SHA-256.
2. Registrar o estado atual de tabelas, views, tipos, funções, grants e extensões a partir de consultas de catálogo somente leitura. Não consultar dados pessoais desnecessários.
3. Recuperar recibos de deploy, logs de migrations, backups/snapshots e branches Neon. Identificar de qual snapshot/ambiente veio `production` e quem provisionou o schema.
4. Comparar o catálogo real com as versões históricas do SQL, incluindo `c6e7e35` e as migrations posteriores. Classificar cada unidade como equivalente, divergente, ausente ou inconclusiva; não inferir equivalência só pelo nome do objeto.

### 2. Reconciliar o histórico sem falsificar checksums

1. Revisar e integrar o preflight fail-closed adicionado nesta proposta ao runner `fin-db`: se houver objetos de aplicação sem ledger reconhecido, o comando recusa executar antes de qualquer `CREATE EXTENSION` ou DDL.
2. Reconstruir o ledger somente a partir de recibos/backup confiáveis e comparação de schema. Um checksum atual não prova qual conteúdo foi aplicado no passado.
3. Se não houver evidência suficiente, elaborar um baseline novo, versionado e revisado, em vez de editar checksums antigos ou marcar migrations como aplicadas sem prova. Executar primeiro numa cópia/branch descartável e comparar catálogo, constraints, grants e funções.
4. Registrar quem aprovou o baseline, os objetos cobertos, checksums de origem, limitações e plano de rollback. Só então definir uma janela de aplicação à branch de produção.

### 3. Reconstituir os seeds como dados versionados

O `fin-db` mantém política schema-only e a validação de CI recusa DML em migrations. Portanto, seeds não devem ser copiados para uma migration DDL desse repositório. Antes de implementar qualquer carga:

1. Fazer o inventário por arquivo do pacote: seeds SQL de currencies/timezones, benchmarks, tags, OAuth, metric definitions, metrics/benchmarks e ANBIMA/CRIs; scripts Python de seed, sincronização e ingestão; CSVs históricos. Conferir a finalidade, fontes, licença, frescor, schema de destino e dependências de cada arquivo.
2. Comparar `data/statusinvest-busca-avancada*.csv` com os equivalentes atuais em `fin-ingestion/data`. Não duplicar a fonte de verdade. Para `fiis.csv` e dados sem equivalente, buscar origem oficial atual e validar esquema, encoding, datas e cobertura antes de reconstruir.
3. Separar **seed determinístico de referência** (por exemplo, catálogos e definições) de **ingestão de mercado** (que deve buscar dados atualizados e registrar proveniência). Não transformar scripts antigos de scraping/backfill em jobs de deploy.
4. Preparar PRs por domínio com cargas idempotentes, checksum/fonte/versionamento, `ON CONFLICT` compatível, limites de lote e relatórios de contagem. Exigir testes em PostgreSQL descartável e comparação antes/depois; não habilitar execução automática em produção.
5. Para qualquer rebuild completo, usar um ambiente isolado, aplicar DDL reconciliado, executar os seeds propostos e validar contagens, FKs, views e consultas da aplicação antes de planejar produção.

### 4. Manter ownership claro de migrations

- `fin-db` continua dono de DDL/schema-only.
- `fin-ingestion` continua dono das migrations runtime/dados 21/22 e da recuperação proposta das políticas agendadas. Não registrar 21/22 de novo no runner `fin-db` sem reconciliar ambos os ledgers.
- `18_empty_materialized_views` e `18_runtime_security` são chaves de estágio distintas. Não renumerar nem renomear migrations aplicadas; isso pode mudar as chaves do ledger. O runner deve preservar os identificadores históricos e explicar o prefixo duplicado.
- A recuperação das políticas foi proposta no PR #10 de `fin-ingestion`; fica inativa e não pode ser aplicada até que o ledger-base esteja reconciliado.

## Critérios de saída

O bloqueio de deploy só pode ser removido quando: (a) o ledger e o catálogo forem conciliados; (b) migrations aplicadas tiverem correspondência demonstrável com SQL histórico ou baseline aprovado; (c) cada seed tiver fonte, checksum e validação; (d) runner e testes falharem sem alterar banco diante de ledger ausente/drift; (e) testes de integração passarem numa cópia descartável; e (f) houver plano explícito de janela, observabilidade e reversão.
