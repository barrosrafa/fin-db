# Preparação de idempotência de ordens

Migração aditiva para `core.ordem`. Não cria endpoint de negociação, não movimenta saldo e não altera ordens existentes.

## Aplicação

1. Validar em staging com o mesmo esquema e papel de banco da aplicação.
2. Executar `01_up.sql` com um cliente que não envolva o arquivo inteiro em uma transação. O `CREATE UNIQUE INDEX CONCURRENTLY` precisa ficar fora de transação. As alterações de colunas têm `lock_timeout=3s` para abortar em vez de aguardar indefinidamente.
3. Conferir que `core.uq_ordem_idempotency_carteira` existe e que `pg_index.indisvalid` é verdadeiro. Uma interrupção durante a criação concorrente pode deixar índice inválido; `IF NOT EXISTS` não o corrige. Nesse caso, remover apenas o índice inválido de forma concorrente e repetir a criação.
4. Antes de disponibilizar uma futura rota de ordens, exigir uma chave por intenção de execução, persistir a chave na mesma transação da ordem, conferir o hash do payload e retornar a ordem anterior para repetição compatível. O índice isolado não implementa replay HTTP.

Ordens antigas continuam com NULL. Novas linhas recebem `client_order_id` por padrão; a chave de idempotência será fornecida pela futura rota. Chaves iguais em carteiras diferentes são permitidas. Não há trigger de débito: o exemplo da auditoria referencia campos inexistentes (`tipo_operacao`, `preco_limite` e `wealth.conta_bancaria.id_carteira`) e não representa uma reserva de saldo atômica.

## Reversão

`02_down.sql` remove apenas o índice e preserva as colunas/dados. Só usar antes de qualquer cliente depender desta garantia. Para reversão de aplicação, normalmente manter a migração aditiva é mais seguro.

## Validação executada

PostgreSQL descartável local: aplicação da migração duas vezes, cinco conexões concorrentes com a mesma carteira/chave (uma inserção, quatro violações de unicidade), compatibilidade com chaves NULL e chaves iguais em carteiras diferentes.
