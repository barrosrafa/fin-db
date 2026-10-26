-- =========================================================
-- SEED: market.benchmark
-- =========================================================

INSERT INTO market.benchmark (codigo, nome, tipo, frequencia, fonte) VALUES
    ('CDI','CDI acumulado','TAXA','DIARIA','BCB'),
    ('SELIC','Taxa Selic','TAXA','DIARIA','BCB'),
    ('IPCA','IPCA','INFLACAO','MENSAL','IBGE'),
    ('IGPM','IGP-M','INFLACAO','MENSAL','FGV'),
    ('IBOV','Ibovespa','INDICE','DIARIA','B3'),
    ('IFIX','IFIX','INDICE','DIARIA','B3'),
    ('IBRX','IBRX-100','INDICE','DIARIA','B3'),
    ('SMLL','Small Caps','INDICE','DIARIA','B3'),
    ('IDIV','IDIV','INDICE','DIARIA','B3'),
    ('SP500','S&P 500','INDICE','DIARIA','Yahoo'),
    ('NASDAQ','NASDAQ Composite','INDICE','DIARIA','Yahoo'),
    ('DXY','Dollar Index','INDICE','DIARIA','Yahoo'),
    ('BTC','Bitcoin','COMMODITY','DIARIA','CoinGecko'),
    ('GOLD','Ouro','COMMODITY','DIARIA','Yahoo'),
    ('BRENT','Petróleo Brent','COMMODITY','DIARIA','Yahoo')
ON CONFLICT (codigo) DO NOTHING;
