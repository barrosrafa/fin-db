-- =========================================================
-- 0. CORREÇÕES NA v3.0
-- =========================================================

-- 0.1 Adicionar FKs ausentes
ALTER TABLE analytics.historico_indicador_fundamentalista
    ADD CONSTRAINT fk_hist_ind_fund_ativo
    FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE analytics.historico_indicador_tecnico
    ADD CONSTRAINT fk_hist_ind_tec_ativo
    FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE analytics.historico_risco
    ADD CONSTRAINT fk_hist_risco_ativo
    FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE analytics.matriz_correlacao_historico
    ADD CONSTRAINT fk_matriz_ativo1 FOREIGN KEY (id_ativo_1) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    ADD CONSTRAINT fk_matriz_ativo2 FOREIGN KEY (id_ativo_2) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE analytics.preco_alvo
    ADD CONSTRAINT fk_preco_alvo_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE analytics.score_ativo
    ADD CONSTRAINT fk_score_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE market.calendario_proventos
    ADD CONSTRAINT fk_cal_prov_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE market.previsao_provento
    ADD CONSTRAINT fk_prev_prov_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE market.antecipacao_dividendo
    ADD CONSTRAINT fk_antecip_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    ADD CONSTRAINT fk_antecip_provento FOREIGN KEY (id_provento) REFERENCES market.provento(id_provento) ON DELETE RESTRICT;

ALTER TABLE wealth.instituicao_conectada
    ADD CONSTRAINT fk_inst_conn_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.conta_bancaria
    ADD CONSTRAINT fk_conta_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    ADD CONSTRAINT fk_conta_inst FOREIGN KEY (id_instituicao_conectada)
        REFERENCES wealth.instituicao_conectada(id_instituicao_conectada) ON DELETE CASCADE;

ALTER TABLE wealth.transacao_bancaria
    ADD CONSTRAINT fk_trans_banc_conta FOREIGN KEY (id_conta) REFERENCES wealth.conta_bancaria(id_conta) ON DELETE CASCADE;

ALTER TABLE wealth.cartao_credito
    ADD CONSTRAINT fk_cartao_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.emprestimo
    ADD CONSTRAINT fk_emprest_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.financiamento
    ADD CONSTRAINT fk_financ_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.imovel
    ADD CONSTRAINT fk_imovel_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.veiculo
    ADD CONSTRAINT fk_veiculo_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.outros_bens
    ADD CONSTRAINT fk_bens_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.seguro
    ADD CONSTRAINT fk_seguro_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.previdencia_privada
    ADD CONSTRAINT fk_prev_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.consorcio
    ADD CONSTRAINT fk_consorcio_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.investimento_exterior
    ADD CONSTRAINT fk_inv_ext_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    ADD CONSTRAINT fk_inv_ext_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE SET NULL;

ALTER TABLE wealth.divida_externa
    ADD CONSTRAINT fk_div_ext_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.meta_financeira
    ADD CONSTRAINT fk_meta_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.simulador
    ADD CONSTRAINT fk_simul_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.rebalanceamento
    ADD CONSTRAINT fk_rebal_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.apuracao_ir
    ADD CONSTRAINT fk_ir_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.planejamento_tributario
    ADD CONSTRAINT fk_plan_trib_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE social.comparacao_ativo
    ADD CONSTRAINT fk_comp_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE social.assembleia
    ADD CONSTRAINT fk_assembleia_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE social.progresso_aula
    ADD CONSTRAINT fk_prog_aula FOREIGN KEY (id_aula) REFERENCES social.aula(id_aula) ON DELETE CASCADE,
    ADD CONSTRAINT fk_prog_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE social.certificado
    ADD CONSTRAINT fk_cert_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    ADD CONSTRAINT fk_cert_curso FOREIGN KEY (id_curso) REFERENCES social.curso(id_curso) ON DELETE CASCADE;

ALTER TABLE social.topico
    ADD CONSTRAINT fk_topico_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE social.comentario
    ADD CONSTRAINT fk_coment_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE social.curtida
    ADD CONSTRAINT fk_curtida_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE social.seguidor
    ADD CONSTRAINT fk_seg_seguidor FOREIGN KEY (id_usuario_seguidor) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    ADD CONSTRAINT fk_seg_seguido FOREIGN KEY (id_usuario_seguido) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE social.gamificacao
    ADD CONSTRAINT fk_gamif_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE system.alerta
    ADD CONSTRAINT fk_alerta_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE system.notificacao
    ADD CONSTRAINT fk_notif_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE system.exportacao
    ADD CONSTRAINT fk_export_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE system.usuario_role
    ADD CONSTRAINT fk_ur_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    ADD CONSTRAINT fk_ur_role FOREIGN KEY (id_role) REFERENCES system.role(id_role) ON DELETE CASCADE;

ALTER TABLE dw.historico_posicao
    ADD CONSTRAINT fk_hist_pos_carteira FOREIGN KEY (id_carteira) REFERENCES core.carteira(id_carteira) ON DELETE CASCADE;

ALTER TABLE dw.historico_carteira
    ADD CONSTRAINT fk_hist_cart_carteira FOREIGN KEY (id_carteira) REFERENCES core.carteira(id_carteira) ON DELETE CASCADE;

ALTER TABLE dw.historico_rentabilidade
    ADD CONSTRAINT fk_hist_rent_carteira FOREIGN KEY (id_carteira) REFERENCES core.carteira(id_carteira) ON DELETE CASCADE;

ALTER TABLE dw.ranking
    ADD CONSTRAINT fk_ranking_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE dw.historico_indicador
    ADD CONSTRAINT fk_hist_ind_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

-- 0.2 Corrigir PKs inconsistentes
ALTER TABLE wealth.patrimonio_global DROP CONSTRAINT patrimonio_global_pkey;
ALTER TABLE wealth.patrimonio_global DROP COLUMN id_patrimonio;
ALTER TABLE wealth.patrimonio_global
    ADD CONSTRAINT patrimonio_global_pkey PRIMARY KEY (id_usuario, data_referencia);

ALTER TABLE market.curva_juros DROP CONSTRAINT curva_juros_pkey;
ALTER TABLE market.curva_juros DROP COLUMN id_curva;
ALTER TABLE market.curva_juros
    ADD CONSTRAINT curva_juros_pkey PRIMARY KEY (data_referencia, tipo, vertice);

ALTER TABLE market.cambio DROP CONSTRAINT cambio_pkey;
ALTER TABLE market.cambio DROP COLUMN id_cambio;
ALTER TABLE market.cambio
    ADD CONSTRAINT cambio_pkey PRIMARY KEY (data_referencia, moeda_origem, moeda_destino, tipo);

ALTER TABLE market.commodity DROP CONSTRAINT commodity_pkey;
ALTER TABLE market.commodity DROP COLUMN id_commodity;
ALTER TABLE market.commodity
    ADD CONSTRAINT commodity_pkey PRIMARY KEY (data_referencia, nome);

ALTER TABLE market.serie_macroeconomica DROP CONSTRAINT serie_macroeconomica_pkey;
ALTER TABLE market.serie_macroeconomica DROP COLUMN id_serie;
ALTER TABLE market.serie_macroeconomica
    ADD CONSTRAINT serie_macroeconomica_pkey PRIMARY KEY (codigo_sgs, data_referencia);

ALTER TABLE market.aluguel_acoes DROP CONSTRAINT aluguel_acoes_pkey;
ALTER TABLE market.aluguel_acoes DROP COLUMN id_aluguel;
ALTER TABLE market.aluguel_acoes
    ADD CONSTRAINT aluguel_acoes_pkey PRIMARY KEY (id_ativo, data);

-- 0.3 Adicionar NOT NULL em colunas críticas
ALTER TABLE social.topico ALTER COLUMN id_forum SET NOT NULL;
ALTER TABLE social.comentario ALTER COLUMN id_topico SET NOT NULL;
ALTER TABLE analytics.item_carteira_recomendada ALTER COLUMN id_carteira_recomendada SET NOT NULL;

-- 0.4 Adicionar colunas de auditoria em tabelas transacionais
ALTER TABLE core.carteira ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE core.carteira ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE core.posicao_custodia ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 0.5 Ajustar exportacao com status
ALTER TABLE system.exportacao
    ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE','PROCESSANDO','CONCLUIDO','ERRO')),
    ADD COLUMN IF NOT EXISTS url_download TEXT,
    ADD COLUMN IF NOT EXISTS tamanho_bytes BIGINT,
    ADD COLUMN IF NOT EXISTS erro_mensagem TEXT,
    ADD COLUMN IF NOT EXISTS data_conclusao TIMESTAMPTZ;

-- 0.6 Políticas de retenção Timescale
-- [Timescale Cloud Only]: SELECT add_retention_policy('market.cotacao_intraday', INTERVAL '90 days');
-- [Timescale Cloud Only]: SELECT add_retention_policy('market.book_ordens',      INTERVAL '30 days');
-- [Timescale Cloud Only]: SELECT add_retention_policy('market.negocio_intraday', INTERVAL '90 days');
-- [Timescale Cloud Only]: SELECT add_retention_policy('market.after_market',     INTERVAL '365 days');
-- [Timescale Cloud Only]: SELECT add_retention_policy('system.uso_api',          INTERVAL '365 days');
-- [Timescale Cloud Only]: SELECT add_retention_policy('system.auditoria_log',    INTERVAL '1825 days');
-- [Timescale Cloud Only]: SELECT add_retention_policy('system.log_acesso',       INTERVAL '365 days');

-- 0.7 Compressão Timescale (executar em produção, não em dev)
-- ALTER TABLE market.cotacao_diaria SET (timescaledb.compress, timescaledb.compress_segmentby = 'id_ativo');
-- -- [Timescale Cloud Only]: SELECT add_compression_policy('market.cotacao_diaria', INTERVAL '90 days');
