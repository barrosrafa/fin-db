-- =========================================================
-- SEED: core.moeda, core.fuso_horario, core.bolsa
-- =========================================================

INSERT INTO core.moeda (codigo, nome, simbolo, pais) VALUES
    ('BRL','Real Brasileiro','R$','Brasil'),
    ('USD','Dólar Americano','$','EUA'),
    ('EUR','Euro','€','União Europeia'),
    ('GBP','Libra Esterlina','£','Reino Unido'),
    ('JPY','Iene Japonês','¥','Japão'),
    ('ARS','Peso Argentino','$','Argentina'),
    ('CAD','Dólar Canadense','$','Canadá'),
    ('AUD','Dólar Australiano','$','Austrália'),
    ('CHF','Franco Suíço','Fr','Suíça'),
    ('CNY','Yuan Chinês','¥','China')
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO core.fuso_horario (nome, offset_utc, dst) VALUES
    ('America/Sao_Paulo', -3, FALSE),
    ('America/New_York', -5, TRUE),
    ('Europe/London', 0, TRUE),
    ('Asia/Tokyo', 9, FALSE),
    ('UTC', 0, FALSE)
ON CONFLICT (nome) DO NOTHING;

INSERT INTO core.bolsa (codigo, nome, pais, fuso_horario, horario_abertura, horario_fechamento) VALUES
    ('B3','B3 - Brasil Bolsa Balcão','Brasil','America/Sao_Paulo','10:00','17:00'),
    ('NYSE','New York Stock Exchange','EUA','America/New_York','09:30','16:00'),
    ('NASDAQ','NASDAQ','EUA','America/New_York','09:30','16:00'),
    ('LSE','London Stock Exchange','Reino Unido','Europe/London','08:00','16:30'),
    ('TSE','Tokyo Stock Exchange','Japão','Asia/Tokyo','09:00','15:00')
ON CONFLICT (codigo) DO NOTHING;
