# Correções de segurança do ecossistema FIN — 29/10/2026

Alterações locais preparadas a partir de `auditoria_ecossistema_fin.md`, confrontando os exemplos com o código atual. Nenhum deploy, alteração de dados reais ou migração em produção foi executado.

## Resultado por item do anexo

| Item | Resultado |
| --- | --- |
| Idempotência de ordens | Migração aditiva preparada e validada em PostgreSQL descartável. Não existe `/api/v1/portfolio/orders` nem execução de ordens nos routers atuais. O simulador calcula cenários, sem debitar saldo. Replay HTTP e chave por intenção ficam condicionados à futura implementação dessa operação. |
| Isolamento RLS | Substituído `SET LOCAL ... = :param` por `set_config(..., true)` parametrizado. O subject autenticado é resolvido para `core.usuario.id_usuario`, compatível com as políticas SQL. O contexto é reaplicado em cada transação pelo evento `after_begin`, inclusive após commit/rollback. Sessões anônimas recebem contexto vazio; o encerramento faz rollback explícito. Falhas de sincronização JIT também fazem rollback. |
| Rate limiter distribuído da ingestão | Token bucket atômico em Redis com relógio do servidor, estado compartilhado por host, expiração proporcional à capacidade/taxa e espera assíncrona. O limite declarado pelo coletor, antes ignorado, passa a ser respeitado. |
| Circuit breaker distribuído | Estado compartilhado, uma tentativa de recuperação por vez e geração que impede sucesso antigo de reabrir tráfego. Se Redis falhar com modo distribuído ativo, a chamada externa é interrompida. Falhas HTTP 429 deixam de ser contadas duas vezes; HTTP 5xx interrompe processamento; bloqueios 401/403 iniciam cooldown corretamente. |
| Rate limiting na aplicação | Middleware ativo por padrão em `/api/v1/`, Redis atômico, resposta 429/Retry-After e fallback local com memória limitada em indisponibilidade. Health/readiness e preflight não consomem tokens. Cabeçalhos encaminhados não são interpretados diretamente pelo middleware. |
| Sparklines e CLS | Memoização por valores dos dados, dimensões reservadas quando o histórico está ausente/inválido e descrição acessível de alta/baixa/estabilidade. Não foi realizada medição de FPS por dez minutos. |
| P&L e IndexedDB | Achado não corresponde ao código atual: IndexedDB guarda somente histórico público; carteira usa o serviço do backend, que já valida fonte/horário e não apresenta consolidação completa com cotações vencidas. Não foi criado um novo ledger no frontend. |
| Boleta e daltonismo | Não há boleta real para acrescentar confirmação de compra. Não foram inventados valores de taxas/slippage. Sparklines ganharam descrição textual; uma revisão completa de cores da interface continua fora desta correção de segurança. |
| Cache de borda | API protege respostas autenticadas, cookies, mutações, auth/portfolio/billing com `private, no-store`. Gateways usam política conservadora sem cache compartilhado. Traefik passa a permitir `Idempotency-Key` no CORS. Cache público prolongado exige rotas públicas comprovadas e foi mantido fora desta alteração. |
| Schema.org / SEO | Não alterado: não é correção de segurança. |

Também corrigidos `/ready` (import de `status` e chamadas incompatíveis com o logger, que causavam 500 durante falhas) e reutilização do cliente Redis entre event loops diferentes.

## Evidências de validação

- API: **40 testes selecionados passaram**, incluindo autenticação, carteira, P&L, CORS, cache privado, rate limiting e readiness.
- PostgreSQL real e descartável: **1 teste de integração passou**, usando papel sem superuser/BYPASSRLS e pool com uma conexão. Cobriu usuários A/B, sessão anônima, IDs internos/externos, commits/rollbacks e 30 requisições concorrentes. A migração foi aplicada duas vezes e cinco inserções simultâneas produziram uma ordem e quatro violações de unicidade. Chaves NULL e carteiras distintas foram preservadas.
- API completa em ambiente isolado sem o banco financeiro: **97 passaram e 42 falharam**. Uma cópia limpa do HEAD anterior, com a mesma configuração, apresentou **93 passaram e as mesmas 42 falhas**. Comparação dos identificadores confirmou zero novas falhas. Esses 42 testes dependem de banco/dados e não constituem validação de produção.
- Ingestão: **80 testes passaram**, incluindo 13 novos casos de proteção/resiliência. Testes concorrentes executaram os scripts Lua em Redis real com dois clientes independentes.
- Frontend: **11 testes passaram**; TypeScript, ESLint do componente alterado e build de produção passaram, gerando 84 páginas.
- Infraestrutura: os três arquivos YAML alterados foram carregados com parser e referências de middleware do Traefik foram verificadas. `nginx -t`, Docker Compose e inicialização dos gateways ainda precisam ser executados no ambiente de staging; não há Docker/Nginx instalado neste host.
- Redis e PostgreSQL dos testes foram instâncias temporárias locais. Não foi usado o banco real para os testes de escrita.

## Implantação gradual

1. Publicar as versões dos repositórios em staging. Manter a migração de ordens separada do deploy da API: as correções atuais não dependem das novas colunas.
2. Validar login, cadastro, criação/listagem de carteiras e respostas privadas com o papel real de banco. RLS exige papel sem `SUPERUSER`/`BYPASSRLS` e que não ignore políticas por ser proprietário das tabelas. Este trabalho não revogou privilégios nem aplicou `FORCE RLS` indiscriminadamente; isso precisa considerar cadastro, jobs e migrações.
3. Validar a identidade de cliente entregue pelo servidor ASGI atrás do gateway. Por padrão são 120 requisições/minuto e burst 200 por endereço recebido pelo ASGI; proxies devem ser confiados somente quando seus endereços forem conhecidos e o acesso direto estiver controlado. Se o ASGI apresentar apenas o IP do proxy, o limite será compartilhado entre seus usuários. Ajustar a topologia antes de promover.
4. Ingestão: `DISTRIBUTED_SOURCE_CONTROLS=true` já está nos manifests dos workers/schedulers. O Compose principal fornece Redis autenticado e aguarda healthcheck. O Compose independente exige `REDIS_URL` explicitamente. Desenvolvimento fora desses manifests mantém o recurso desligado por padrão. Confirmar que todas as réplicas usam o mesmo Redis e configurações de taxa por fonte.
5. Aplicar `sql/17_orders_idempotency/01_up.sql` somente com o procedimento do README do diretório. Confirmar índice válido após execução. A futura rota de ordens precisa persistir/verificar chave e payload atomicamente antes de liberar negociação.
6. Executar os testes dependentes do dataset de staging e os cenários SSE/rolagem do anexo. O teste de RLS local não substitui a checagem dos privilégios e políticas do ambiente real.

## Reversão

- API: reverter o código; o rate limiter pode ser desligado com `API_RATE_LIMIT_ENABLED=false` durante diagnóstico. Ajustar limites pelos parâmetros `API_RATE_LIMIT_PER_MINUTE` e `API_RATE_LIMIT_BURST`.
- Ingestão: reverter o código/manifests ou desligar `DISTRIBUTED_SOURCE_CONTROLS`; durante essa reversão reduzir a uma réplica para não multiplicar o limite local. Não deixar múltiplos workers com proteção apenas em memória.
- Banco: preferir manter colunas/índice aditivos ao reverter aplicação. `02_down.sql` remove apenas o índice e preserva dados, e só deve ser usado antes de clientes dependerem da garantia.
- Infra/frontend: reverter os arquivos alterados e repetir validação de configuração/build.

## Reprodução dos testes novos

API: executar `tests/test_audit_hardening.py` com `TEST_REDIS_URL` apontando para Redis descartável. Para `tests/test_audit_postgres.py`, criar banco **fin_audit_test** em PostgreSQL isolado e definir `TEST_POSTGRES_URL=postgresql://.../fin_audit_test`; o papel de preparação precisa criar schema/role. O teste cria e remove seus próprios objetos e usa a migração no repositório irmão `fin`.

Ingestão: executar `tests/test_audit_resilience.py` com `TEST_REDIS_URL` descartável. Sem a variável, os testes reais de Redis são explicitamente ignorados. Nunca apontar estes testes para serviços de produção.
