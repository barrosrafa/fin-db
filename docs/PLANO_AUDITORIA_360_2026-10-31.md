# Plano de melhoria FIN — auditoria 360°

Data: 31/10/2026. Base: AUD-360-FIN-2026-V4, confrontada com os checkouts locais.

O relatório é uma fonte de hipóteses, não uma instrução executável. Seus IDs FIN-007 e FIN-008 são reutilizados para temas diferentes; este plano identifica cada tema pelo nome. Nenhuma nota de prontidão é recalculada sem evidência operacional. Não se fabricam dados, calendário de pregão, hashes de imagens nem integrações externas.

## Diagnóstico confirmado

- `fin-api/Dockerfile` já usa Python 3.12: FIN-004 está resolvido no código local.
- `fin-infra/koyeb.yaml` usa build Git, não imagem `:latest`. Registrar commit de deploy/rollback; não trocar por digest inventado.
- `fin/scripts/migrate.py` já declara ordem explícita e checksums: o prefixo 18 duplicado não implica ordem alfabética. Renomear migrações aplicadas pode romper histórico.
- `fin-api/app/stocks/service.py`, métodos `get_us_stocks`/`get_reits`: preços/PTAX/indicadores constantes e listas fictícias confirmados.
- `fin-web/src/lib/api.ts` e páginas de login/cadastro: JWT persistido em JS confirmado. Cookie da API já existe, mas `app/auth/dependencies.py` só aceita Bearer; portanto remover o Bearer sem uma ponte quebraria a carteira.
- `fin-api/app/screener/router.py`: aceita DY extremo e ignora filtro setor. A sanidade precisa ocorrer antes de LIMIT/filtros, evitando preenchimento por leituras anômalas.

## Etapa 1 — segurança da sessão (execução local)

1. Criar `fin-web/src/app/api/v1/[...path]/route.ts`: BFF para a API fixa em `API_BACKEND_URL`; ler cookie HttpOnly e criar Bearer somente no servidor; preservar query e métodos. Bloquear mutações sem Origin igual ao da aplicação; não encaminhar cookies, Authorization do navegador, redirects ou Set-Cookie do upstream. Timeout e erros sem dados sensíveis. Respostas privadas `no-store`.
2. Em login/cadastro, consumir JWT do upstream no BFF, guardar em cookie `auth_token`, HttpOnly, SameSite=Strict, Secure fora de desenvolvimento, vida limitada à expiração informada. Remover JWT do corpo devolvido ao navegador. Logout apaga cookie mesmo com upstream indisponível.
3. `fin-web/src/lib/api.ts`: retirar leitura/escrita do token, usar credenciais same-origin; respostas de auth passam a conter somente usuário/expiração. Remover token legado do armazenamento ao autenticar/sair.
4. `fin-web/src/app/(frontend)/{login,cadastro}/page.tsx`: redirecionar pelo usuário retornado; remover `document.cookie`.
5. `fin-web/next.config.ts`: remover rewrite que contorna BFF. Adicionar CSP compatível com o render atual (base-uri, object-src, frame-ancestors, form-action), sem alegar proteção de script por nonce. CSP estrita com nonce exige investigar renderização estática/PPR antes de ativação.
6. Testar sucesso/erro de login, token ausente no JSON, flags do cookie, Bearer upstream, bloqueio CSRF, falha/expiração/logout e proteção de cache.
7. Renovação silenciosa fica dependente de refresh token revogável: criar tabela por dispositivo no fin-db, hash do segredo, rotação transacional e detecção de reuso; adicionar `/auth/refresh` e `/auth/revoke` na API e testes de concorrência/replay antes de habilitar. Não renovar o próprio access token indefinidamente.

## Etapa 2 — integridade dos números (execução local)

1. `fin-api/app/stocks/service.py`: retirar COALESCE com cotações constantes, PTAX default, indicadores por ticker e listas fake. Preservar preço USD real; BRL somente quando preço e PTAX reais positivos existem. Indicadores sem fonte são null; não inferir DY nem imposto líquido universal.
2. `fin-api/app/stocks/schemas.py`: campos internacionais ausentes passam a `Optional` com default None. Não converter ausência em zero.
3. `fin-web/src/lib/api.ts` e páginas stocks/reits: refletir opcionais, renderizar travessão sem toFixed em undefined.
4. `fin-api/app/screener/router.py`: DY percentual fora de 0..100 ou não finito bloqueia registro, sem dividir automaticamente por 100. Limite é uma política conservadora de publicação, não prova de erro financeiro; exceções requerem revisão/proveniência. Aplicar antes de LIMIT; limitar volume da requisição, aplicar setor e filtros em SQL.
5. `fin-ingestion/dbt/tests/screener_dividend_yield_sanity.sql`: gate bloqueante para os dois marts, DY finito em 0..100; null permitido por representar ausência. Falha impede promover publicação, preservando último snapshot bom.
6. Gerar contrato em `fin-api/contracts/openapi.json` e `fin-web/src/generated/api.d.ts`; testar fonte ausente, zeros verdadeiros, preços distintos e outliers NaN/Infinity/41200.
7. Quarentena persistente completa: rastrear escrita dos indicadores e exportador, guardar payload bruto/source/as_of/motivo na estrutura de quarentena existente, e testar que nenhum snapshot é publicado quando o dbt falha. Não apagar registros históricos para esconder o problema.

## Etapa 3 — canonicalização (execução local)

`fin-web/src/proxy.ts`: ampliar matcher para acoes/fiis/etfs/stocks/reits/bdrs; normalizar somente ticker final e sufixo opengraph-image. Manter query, 308 e excluir rotas estáticas como comparador/rankings. Para mercados internacionais aceitar letras/ponto/hífen; para B3 exigir padrão com número. Testar query e nomes reservados.

## Etapa 4 — recuperar dados e conteúdo (operação controlada)

1. `fin-ingestion/fin_ingestion/pipelines/historical_backfill.py`: inventariar cobertura por ticker/dia, fontes e ajustes corporativos, reexecução idempotente. Executar primeiro em banco descartável, validar geometria e comparação com fonte.
2. `fin-api/app/simulator/service.py`: manter indisponibilidade explícita quando falta série; exigir benchmark e histórico reais. Testar eventos corporativos e janelas incompletas.
3. `fin-api/app/rankings/router.py` e SQL de views: verificar dependências, índices únicos, contagens e freshness. REFRESH CONCURRENTLY só em views elegíveis; rodar uma por vez fora de transação, com timeout, baseline e plano de recuperação.
4. `fin-api/app/content/service.py`/`router.py`: validar publicação e idioma; localizar seed editorial existente e versionar conteúdo aprovado, sem gerar análises financeiras atribuídas a autores reais. Testar artigos/glossário com banco vazio e conteúdo publicado.
5. `fin-ingestion/fin_ingestion/scheduler/market_calendar.py` e header web: fonte oficial de feriados/sessões, timezone America/Sao_Paulo, validade do calendário e distinção entre sessão estimada e verificada. Não substituir desconhecido por dia útil presumido.
6. `fin-infra/scripts/verify_ecosystem_e2e.py`: gate de rotas com dados válidos, proveniência, freshness e sem outliers; estabelecer baseline em staging antes de bloquear deploy.
7. Antes de qualquer mutação remota: identificar alvo, backup recuperável, ensaio, diff de contagens, prazo/timeout e rollback. Publicação depende da validação integrada; não foi autorizada exclusão de dados de clientes.

## Etapa 5 — governança e operação

1. `fin/scripts/migrate.py`, `fin/tests/test_migrate_plan.py`: manifesto versionado de ordem/hash sem renomear IDs aplicados; verificar se a migração 21 é coberta no runner oficial e comparar cópias antes de consolidar. DDL canônico neste repo; não modificar o checkout aninhado `fin/fin-db` sem determinar sua função.
2. `fin-ingestion/migrations/21_ingestion_schedule_reliability/01_runtime_ledger.sql`: comparar com banco e CI; migrar ownership após prova de equivalência. Remover cópia só quando consumidores mudarem.
3. `fin-api/app/collectors/`, `app/ingestion/`, workers e testes: mapear imports, tarefas ARQ e chamadas. Extrair por adaptador compatível para fin-ingestion; manter API de controle. Remover dependências scraping somente quando nenhum import existir. Aceite: paridade de jobs e deploy independente.
4. `fin-api/Dockerfile`: pin uv e base com versão/digest real verificado; lock reprodutível e build em CI. `fin-infra/koyeb.yaml`: registrar commit e rollback verificado. Terraform referencial não deve ser aplicado como se fosse produção.
5. `fin-infra/observability/`: correlacionar request/job/batch, redigir PII/tokens, configurar OTLP por segredo e testar propagação. Medir latência e custo antes de compressão Timescale; verificar suporte real no provedor.

## Etapa 6 — CMS, direitos do usuário e diferenciação

1. `fin-web/cms/ui-texts.json`, `feature-flags.json`, `src/components/content/Cms.tsx`: medir bundle, identificar chaves por AST e criar mapa de migração semântico por domínio, com compatibilidade temporária. Remover `reference/payload/` apenas após buscar consumidores. Aceite: todas as rotas/textos/flags mantidos e bundle medido.
2. `fin-api/app/auth/`, portfolio e banco: endpoints de exportação e solicitação de exclusão com reautenticação, escopo RLS, fila, auditoria e tratamento das retenções aplicáveis. Ensaiar isolamento de dois tenants e exclusão sem afetar terceiros; revisão de política antes de purga.
3. Radar IA: cada resultado deve referenciar documento original, instante, modelo e limitações; exibir conteúdo informativo e incerteza. Não declarar conformidade regulatória só por um aviso.
4. MFA/email: desafio expirável, hash no banco, lockout por conta com limite e recuperação; testes anti-enumeração, replay e rate limit distribuído.
5. Integração B3/IRPF: depende de credenciais, contratos, regras homologadas e corpus fiscal revisado. Implementar adaptadores e fixtures oficiais, consentimento/revogação e reconciliação; validar splits/bonificações/cisões antes de calcular tributo exibido ao cliente.

## Validação e reversão

Executar testes unitários/de contrato, TypeScript e lint dos arquivos alterados; build web com backend de teste. Testes dbt precisam Postgres descartável: nunca assumir que parse é execução SQL. E2E da sessão precisa API real de staging e conta de teste, sem expor tokens nos logs. Registrar comandos, resultados, bloqueios e pendências abaixo. Não declarar produção pronta por testes mockados.

Alterações locais são reversíveis por diff seletivo dos arquivos listados; não usar reset global (há arquivos do usuário no vault e checkout aninhado). Para deploy: API/contratos primeiro, frontend depois, smoke de login/carteira/logout e finanças; rollback de frontend/API em conjunto. Sem migração destrutiva nesta entrega.

## Registro da execução

Implementadas localmente as etapas 1–3, exceto refresh/revogação, CSP com nonce e quarentena persistente. Adicionalmente, `fin-ingestion/fin_ingestion/quality/validator.py::validate_snapshot_indicators` é chamado em `SnapshotExporter.wrap_envelope` antes de qualquer escrita: rejeita DY fora de 0..100, valores não finitos e serialização NaN. Teste mantém arquivo anterior intacto e garante zero chamadas ao publicador remoto. A validação usa as chaves reais de DY do payload; não valida a exatidão econômica de todas as métricas.

Arquivos novos de regressão: `fin-api/tests/test_audit_360.py`, `fin-web/src/proxy.test.ts`, `fin-web/src/app/api/v1/[...path]/route.test.ts`, `fin-web/tests-session/session.spec.ts`, `fin-web/tests-e2e/fixtures/session-backend.mjs`, `fin-web/playwright.session.config.ts`, `fin-ingestion/tests/test_snapshot_indicator_quality.py` e teste dbt descrito acima. O CI web agora instala Chromium e executa o teste isolado após build.

A sessão anterior em localStorage é removida em requisições do cliente, login e logout, com tolerância a storage indisponível. Usuários existentes devem autenticar novamente para receber o cookie com as novas flags. Logout limpa o cookie local; não revoga um JWT já roubado. API direta continua Bearer para outros consumidores.

As etapas 4–6 permanecem roadmap dependente de evidências operacionais e integrações, não funcionalidades entregues. Não foram executados deploy, backfill, refresh de views ou exclusões. Não há justificativa para substituir o aviso de calendário desconhecido por horário presumido.

### Código principal entregue

```ts
// fin-web/src/app/api/v1/[...path]/route.ts
// A credencial chega ao backend sem passar pelo JavaScript da página.
const token = request.cookies.get("auth_token")?.value;
if (token) headers.set("authorization", `Bearer ${token}`);
// Login: apenas publicData retorna ao browser.
response = NextResponse.json(publicData, { status: upstream.status });
response.cookies.set("auth_token", accessToken, {
  httpOnly: true, secure: process.env.NODE_ENV !== "development",
  sameSite: "strict", path: "/", maxAge: Math.min(data.expires_in, 604800),
});
```

```sql
-- fin-api/app/screener/router.py: cláusula antes do LIMIT
AND COALESCE(inf.dividend_yield, df.dividend_yield, 0.0) BETWEEN 0 AND 100
-- Valores desconhecidos ainda seguem o contrato legado do screener (DY 0).
-- Evolução futura: DY nullable com tratamento uniforme nas tabelas consumidoras.
```

```python
# fin-api/app/stocks/service.py
price_brl = round(p_usd * ptax, 2) if p_usd is not None and ptax is not None else None
# Não há mais PTAX default nem listas de AAPL/MSFT/O/PLD fictícias nesses métodos.
```

### Evidências de validação

- API: `.venv/bin/python -m pytest tests/test_audit_360.py tests/test_data_integrity.py -q`: **15 passed**. `tests/test_auth.py tests/test_auth_security.py`: **7 passed**. Ruff dos arquivos alterados passou.
- Ingestão: `.venv/bin/python -m pytest tests/test_snapshot_indicator_quality.py tests/test_snapshot_exporter.py -q`: **18 passed**. Ruff passou.
- dbt: `.venv/bin/dbt parse --project-dir dbt --profiles-dir dbt --target dev --no-partial-parse`: passou sem conexão ao banco. **Não equivale a dbt test executado em Postgres**; execução SQL permanece pendente de banco isolado.
- Web: `pnpm test`: **40 passed**, incluindo 21 regressões de BFF/proxy. `pnpm exec tsc --noEmit` e build de produção passaram. Lint dos arquivos alterados passou (aviso de loading no cadastro foi corrigido desabilitando envio duplicado).
- Chromium: `pnpm exec playwright test --config playwright.session.config.ts`: **2 passed** com Next em modo produção e backend local isolado. Testa formulário, JSON sem JWT, cookie HttpOnly/Secure/Strict, limpeza do token legado, chamada autenticada, logout e bloqueio de origem externa. Não comprova a configuração da infraestrutura publicada.
- Tentativa adicional da suíte ampla de API: **2 failed, 8 passed**, interrompida após chamadas sem isolamento de banco. Falhas: `test_get_stock_complete_details_commercial` exige `ev_ebitda` preenchido; `test_get_stock_complete_details_banking` exige `carteira_credito` preenchida. Os métodos de detalhes/múltiplos/financeiros envolvidos não foram alterados. Não foram mascarados com números fictícios. A suíte completa não está certificada.
- Ambiente Node local: v24.21.0, abaixo do mínimo declarado pelo projeto (24.22.1 para a linha 24); ferramentas passaram, mas CI usa a versão suportada 22.23.4. Não houve alteração no runtime global.

### Gates antes de promover

1. Executar dbt test e testes de integração em Postgres descartável com cenários 0, null, 100, 41200, NaN e Infinity; garantir que execução agendada pare antes de publicar.
2. Configurar/validar a cadeia de proxies confiáveis e rate limiting com o novo BFF. Ele não encaminha X-Forwarded-For fornecido pelo cliente: sem configuração de ingress autenticado, a API pode agrupar visitantes pelo IP do BFF. Não liberar confiança universal em headers de IP.
3. Verificar limites de payload, 15s de timeout e streams da API; o BFF é conservador (no-store), e performance de leituras públicas exige medição antes de reintroduzir cache compartilhado.
4. Smoke de sessão contra API/gateway de staging e verificação de cookie em HTTPS real; conferir logs sem senha/JWT. Reautenticar sessões legadas.
5. Resolver falhas de integração com fixtures confiáveis e executar suíte completa antes de qualquer publicação. As notas/score de prontidão do relatório continuam sem recertificação.
