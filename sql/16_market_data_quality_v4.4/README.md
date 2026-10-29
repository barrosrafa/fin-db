# Qualidade de cotações — lote 16

Migração aditiva preparada para execução após revisão e ensaio em PostgreSQL isolado. Não foi aplicada nesta entrega.

Adiciona metadados sem atribuir fonte presumida ao legado; preserva cópia JSON dos registros B3 em fim de semana e altera somente sua classificação de qualidade. Não remove cotações. Calendário oficial, feriados, exceções e OHLC precisam de validação adicional. Uma data útil isolada não comprova que um preço seja fechamento oficial.

Os leitores locais de histórico já filtram fins de semana independentemente dessa migração. Os demais consumidores da tabela precisam adotar a política de qualidade antes da liberação dos dados saneados. Escritores de snapshots não devem reclassificar registros como `daily_close` por conta própria.
