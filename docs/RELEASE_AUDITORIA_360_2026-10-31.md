# Auditoria 360 — release observada em 31/10/2026

## Código publicado e testes

- API: PR https://github.com/barrosrafa/fin-api/pull/1; commit main `bab4905c8edfe65bb5d3f5c27af82f77f0e0d65b`. CI completo: 181 passed, Docker build aprovado. Render: deploy `dep-dbj768e417fc73aksjvg`, estado observado `Deploy succeeded | Live`.
- Web: PR https://github.com/barrosrafa/fin-web/pull/1; commit main `0fb1731fff3f4254fd961fc20a28c6df044dfd1c`. CI aprovado, 40 unitários e 2 testes Chromium de sessão, TypeScript/lint/build. Vercel production `dpl_AVSvC6vkHVwNpykydEpd1Sx97XZq`, Ready, alias https://fin-web-wheat.vercel.app.
- Ingestão: PR https://github.com/barrosrafa/fin-ingestion/pull/3; main `3648ca51f8344997a81854d87fa4b158ecec2913`. CI: 202 passed. Homologação local: 186 passed/16 skipped com Postgres/Redis descartáveis. Deploy https://github.com/barrosrafa/fin-ingestion/actions/runs/41250689273 aprovado, recibo `SUCCEEDED`; ENGINE_RELEASE_SHA promovido para esse commit. Recuperação https://github.com/barrosrafa/fin-ingestion/actions/runs/41250940142 disparada, verificar seu recibo final.
- Plano: https://github.com/barrosrafa/fin-db/pull/4 integrado. Nenhum DDL novo nesta release; migrations da engine verificadas pelo workflow existente.

## Smoke em produção

- API OpenAPI confirma preços internacionais opcionais; stocks/reits retornam ausência real (`null`) em vez de preços constantes.
- Screener retornou 1000 registros com DY finito entre 0 e 100.
- Web /login HTTP 200 com CSP; /api/v1/auth/me HTTP 401 sem sessão e private/no-store; POST de login com origem externa HTTP 403; leitura internacional pelo BFF HTTP 200.
- Logout no navegador e flags HttpOnly/Secure/Strict foram verificados com backend de teste isolado. Não foi criada conta real em produção para smoke.

## Pendências explícitas

Esta release não implementa integralmente o roadmap de meses. Refresh/revogação durável de sessão, quarentena persistente de indicadores, refatoração de CMS, operações extensas de backfill, direitos LGPD e IRPF permanecem pendentes. Integração B3 bloqueada: usuário confirmou que ainda não possui acesso homologado. Não foram apagados coletores nem renomeadas migrations aplicadas.

Logs de produção mostram rate limiting em fallback local e falha de leitura do cache editorial; investigar conectividade/limite Redis antes de certificar disponibilidade distribuída. O BFF também exige validar atribuição de IP no ingress confiável.

Durante diagnóstico foram impressas indevidamente URLs de PostgreSQL e Redis contendo credenciais no registro da conversa. Não copiadas para Git. Rotação coordenada dessas credenciais permanece necessária; não incluir valores em documentos/commits.
