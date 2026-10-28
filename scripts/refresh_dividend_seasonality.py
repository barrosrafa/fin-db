"""
Script to refresh analytics.mapa_sazonalidade_dividendo with distinct calculations
for DATA_COM and PAGAMENTO using SQLAlchemy async session.
"""
import asyncio
import sys
from sqlalchemy import text
from app.core.database import get_session_factory

async def refresh():
    session_factory = get_session_factory()
    async with session_factory() as session:
        print("Calculating and refreshing analytics.mapa_sazonalidade_dividendo for DATA_COM...")
        query_com = text("""
        INSERT INTO analytics.mapa_sazonalidade_dividendo (
            id_ativo, mes_calendario, tipo_evento, ocorrencias_historicas,
            anos_analisados, valor_medio_provento, yield_medio_mensal, ultimo_ano_pago
        )
        SELECT 
            p.id_ativo,
            EXTRACT(MONTH FROM p.data_com)::smallint AS mes_calendario,
            'DATA_COM' AS tipo_evento,
            COUNT(DISTINCT EXTRACT(YEAR FROM p.data_com)) AS ocorrencias_historicas,
            (GREATEST(EXTRACT(YEAR FROM MAX(p.data_com)) - EXTRACT(YEAR FROM MIN(p.data_com)) + 1, 1))::int AS anos_analisados,
            ROUND(AVG(p.valor_por_acao), 6) AS valor_medio_provento,
            ROUND(COALESCE(AVG(p.valor_por_acao / NULLIF(cd.preco_fechamento, 0)), 0.0), 4) AS yield_medio_mensal,
            MAX(EXTRACT(YEAR FROM p.data_com))::int AS ultimo_ano_pago
        FROM market.provento p
        LEFT JOIN LATERAL (
            SELECT preco_fechamento 
            FROM market.cotacao_diaria 
            WHERE id_ativo = p.id_ativo AND data_pregao <= p.data_com 
            ORDER BY data_pregao DESC LIMIT 1
        ) cd ON TRUE
        WHERE p.data_com IS NOT NULL
        GROUP BY p.id_ativo, EXTRACT(MONTH FROM p.data_com)
        ON CONFLICT (id_ativo, mes_calendario, tipo_evento) DO UPDATE 
        SET 
            ocorrencias_historicas = EXCLUDED.ocorrencias_historicas,
            anos_analisados = EXCLUDED.anos_analisados,
            valor_medio_provento = EXCLUDED.valor_medio_provento,
            yield_medio_mensal = EXCLUDED.yield_medio_mensal,
            ultimo_ano_pago = EXCLUDED.ultimo_ano_pago,
            data_atualizacao = NOW();
        """)
        await session.execute(query_com)
        print("DATA_COM rows processed.")

        print("Calculating and refreshing analytics.mapa_sazonalidade_dividendo for PAGAMENTO...")
        query_pag = text("""
        INSERT INTO analytics.mapa_sazonalidade_dividendo (
            id_ativo, mes_calendario, tipo_evento, ocorrencias_historicas,
            anos_analisados, valor_medio_provento, yield_medio_mensal, ultimo_ano_pago
        )
        SELECT 
            p.id_ativo,
            EXTRACT(MONTH FROM p.data_pagamento)::smallint AS mes_calendario,
            'PAGAMENTO' AS tipo_evento,
            COUNT(DISTINCT EXTRACT(YEAR FROM p.data_pagamento)) AS ocorrencias_historicas,
            (GREATEST(EXTRACT(YEAR FROM MAX(p.data_pagamento)) - EXTRACT(YEAR FROM MIN(p.data_pagamento)) + 1, 1))::int AS anos_analisados,
            ROUND(AVG(p.valor_por_acao), 6) AS valor_medio_provento,
            ROUND(COALESCE(AVG(p.valor_por_acao / NULLIF(cd.preco_fechamento, 0)), 0.0), 4) AS yield_medio_mensal,
            MAX(EXTRACT(YEAR FROM p.data_pagamento))::int AS ultimo_ano_pago
        FROM market.provento p
        LEFT JOIN LATERAL (
            SELECT preco_fechamento 
            FROM market.cotacao_diaria 
            WHERE id_ativo = p.id_ativo AND data_pregao <= p.data_pagamento 
            ORDER BY data_pregao DESC LIMIT 1
        ) cd ON TRUE
        WHERE p.data_pagamento IS NOT NULL
        GROUP BY p.id_ativo, EXTRACT(MONTH FROM p.data_pagamento)
        ON CONFLICT (id_ativo, mes_calendario, tipo_evento) DO UPDATE 
        SET 
            ocorrencias_historicas = EXCLUDED.ocorrencias_historicas,
            anos_analisados = EXCLUDED.anos_analisados,
            valor_medio_provento = EXCLUDED.valor_medio_provento,
            yield_medio_mensal = EXCLUDED.yield_medio_mensal,
            ultimo_ano_pago = EXCLUDED.ultimo_ano_pago,
            data_atualizacao = NOW();
        """)
        await session.execute(query_pag)
        print("PAGAMENTO rows processed.")
        await session.commit()

        # Verify
        res = await session.execute(text("SELECT tipo_evento, COUNT(*) FROM analytics.mapa_sazonalidade_dividendo GROUP BY tipo_evento;"))
        print("Verification by tipo_evento:", res.fetchall())

        # Sample PETR4 comparison
        res2 = await session.execute(text("""
        SELECT a.ticker, s.mes_calendario, s.tipo_evento, s.probabilidade_pct, s.valor_medio_provento
        FROM analytics.mapa_sazonalidade_dividendo s
        JOIN core.ativo a ON a.id_ativo = s.id_ativo
        WHERE a.ticker = 'PETR4'
        ORDER BY s.mes_calendario, s.tipo_evento;
        """))
        print("\nPETR4 Seasonality Sample (DATA_COM vs PAGAMENTO):")
        for row in res2.fetchall():
            print(f"Month {row[1]:02d} | Event: {row[2]:10s} | Prob: {float(row[3]):.1f}% | Avg: R$ {float(row[4]):.4f}")

    print("Finished successfully.")

if __name__ == "__main__":
    asyncio.run(refresh())
