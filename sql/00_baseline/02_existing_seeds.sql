-- =========================================================
-- EXISTING SEEDS: canonical.currency, canonical.venue, canonical.source
-- =========================================================

-- canonical.currency
INSERT INTO canonical.currency (currency_code, name, minor_digits) VALUES
    ('BRL', 'Real brasileiro', 2),
    ('EUR', 'Euro', 2),
    ('USD', 'Dólar americano', 2)
ON CONFLICT (currency_code) DO NOTHING;

-- canonical.venue
INSERT INTO canonical.venue (venue_id, code, name, country_code, timezone) VALUES
    ('2d9e904d-fb8b-461d-80a0-297aec052385', 'B3', 'B3 Brasil, Bolsa, Balcão', 'BR', 'America/Sao_Paulo'),
    ('22bd7eb3-12f4-4f20-a03e-23b9210bec8b', 'CVM', 'Comissão de Valores Mobiliários', 'BR', 'America/Sao_Paulo'),
    ('7276af66-b793-43bc-b5ae-0af0861a504f', 'FNET', 'FNet / B3', 'BR', 'America/Sao_Paulo'),
    ('1dd59ca6-4421-4962-bdde-a0fbd6420287', 'NASDAQ', 'Nasdaq', 'US', 'America/New_York'),
    ('b86dad51-f902-4613-9b40-16477b682518', 'NYSE', 'New York Stock Exchange', 'US', 'America/New_York'),
    ('571034ab-c519-4efc-af0b-ae9610e341b7', 'TESOURO', 'Tesouro Direto', 'BR', 'America/Sao_Paulo')
ON CONFLICT (venue_id) DO NOTHING;

-- canonical.source
INSERT INTO canonical.source (source_id, name, kind, base_url, license_note, active, created_at) VALUES
    ('0c8112c2-62e6-418f-a8cb-51fe7b1ca4d2', 'ADVFN Brasil', 'PLATFORM', 'https://br.advfn.com', 'Verificar termos e licença antes de ingestão', True, '2026-10-26 22:28:16.950755+00:00'),
    ('fc910eef-e948-49c5-80a5-0f15e9305ec7', 'Análise de Ações', 'PLATFORM', 'https://www.analisedeacoes.com', 'Verificar termos e licença antes de ingestão', True, '2026-10-26 22:28:16.950755+00:00'),
    ('25fbdab3-b036-4c07-9e64-352f03cb50a7', 'B3', 'B3', 'https://www.b3.com.br', 'Fonte oficial; validar licença e uso', True, '2026-10-26 22:28:16.950755+00:00'),
    ('420c01c2-8ba0-4e84-9252-306a39693b33', 'Brick360', 'PLATFORM', 'https://brick360.com.br', 'Verificar termos e licença antes de ingestão', True, '2026-10-26 22:28:16.950755+00:00'),
    ('1f65e62f-6b0f-4b7d-8192-804cd63246fb', 'CVM', 'CVM', 'https://www.gov.br/cvm', 'Fonte oficial; validar licença e uso', True, '2026-10-26 22:28:16.950755+00:00'),
    ('ec371513-6f8f-418c-9ddf-6bc52845d1e8', 'Clube FII', 'PLATFORM', 'https://www.clubefii.com.br', 'Verificar termos e licença antes de ingestão', True, '2026-10-26 22:28:16.950755+00:00'),
    ('899eaeb8-3136-4347-9fdb-141436f6419f', 'ETFs Brasil', 'PLATFORM', 'https://www.etfsbrasil.com.br', 'Verificar termos e licença antes de ingestão', True, '2026-10-26 22:28:16.950755+00:00'),
    ('dc5feb5d-a326-4c09-971b-3f544b1307dd', 'FIIs.com.br', 'PLATFORM', 'https://fiis.com.br', 'Verificar termos e licença antes de ingestão', True, '2026-10-26 22:28:16.950755+00:00'),
    ('7f67fe17-70e4-4adc-9d48-d536d37465ef', 'FNet/B3', 'FNET', 'https://fnet.bmfbovespa.com.br/fnet/publico/', 'Fonte oficial; validar licença e uso', True, '2026-10-26 22:28:16.950755+00:00'),
    ('302231cd-f5fa-4fc8-a103-2826c215ace5', 'Fundamentei', 'PLATFORM', 'https://fundamentei.com', 'Verificar termos e licença antes de ingestão', True, '2026-10-26 22:28:16.950755+00:00'),
    ('a6237fc6-9131-4e9d-87fc-b1f960f56655', 'Fundamentus', 'PLATFORM', 'https://fundamentus.com.br', 'Verificar termos e licença antes de ingestão', True, '2026-10-26 22:28:16.950755+00:00'),
    ('b24c1ae3-444b-4d75-9075-991c209c62b5', 'Funds Explorer', 'PLATFORM', 'https://www.fundsexplorer.com.br', 'Verificar termos e licença antes de ingestão', True, '2026-10-26 22:28:16.950755+00:00'),
    ('e982d856-2910-42e3-b495-b5610481d3b0', 'Investidor10', 'PLATFORM', 'https://investidor10.com.br', 'Verificar termos e licença antes de ingestão', True, '2026-10-26 22:28:16.950755+00:00'),
    ('64b0e4e7-e1fd-4956-8803-d776531325bc', 'Mais Retorno', 'PLATFORM', 'https://maisretorno.com', 'Verificar termos e licença antes de ingestão', True, '2026-10-26 22:28:16.950755+00:00'),
    ('a43b096b-c697-41c7-b2c9-887c06b03172', 'Status Invest', 'PLATFORM', 'https://statusinvest.com.br', 'Verificar termos e licença antes de ingestão', True, '2026-10-26 22:28:16.950755+00:00'),
    ('453e981f-16b0-47e4-95e7-c6d827cac105', 'Tesouro Direto', 'TESOURO', 'https://www.tesourodireto.com.br', 'Fonte oficial; validar licença e uso', True, '2026-10-26 22:28:16.950755+00:00')
ON CONFLICT (source_id) DO NOTHING;
