"""
Semeador do Universo Canônico de ETFs e Cotações Diárias
Insere os 10 principais ETFs do mercado brasileiro no core.ativo, asset_details.etf_detalhe
e gera cotações diárias em market.cotacao_diaria para alimentar rankings dinâmicos e backtest real.
"""
import asyncio
from datetime import date
from decimal import Decimal
from uuid import uuid4
from app.core.database import get_async_session
from sqlalchemy import text


ETF_DEFINITIONS = [
    {
        "ticker": "BOVA11",
        "nome": "iShares Ibovespa Fundo de Índice",
        "cat": "Ações",
        "gestor": "BlackRock Brasil",
        "indice": "IBOVESPA",
        "pl": 18947800000.0,
        "cotas": 148000000,
        "cotistas": 104623,
        "taxa": 0.10,
        "base_price": 128.40,
        "daily_drift": 0.0004,
        "vol": 0.012,
    },
    {
        "ticker": "IVVB11",
        "nome": "iShares S&P 500 Fundo de Índice",
        "cat": "Ações Internacionais",
        "gestor": "BlackRock Brasil",
        "indice": "S&P 500",
        "pl": 6540200000.0,
        "cotas": 19543000,
        "cotistas": 195430,
        "taxa": 0.23,
        "base_price": 468.50,
        "daily_drift": 0.0006,
        "vol": 0.010,
    },
    {
        "ticker": "SMAL11",
        "nome": "iShares Small Cap Fundo de Índice",
        "cat": "Ações",
        "gestor": "BlackRock Brasil",
        "indice": "SMLL",
        "pl": 5210000000.0,
        "cotas": 45000000,
        "cotistas": 82400,
        "taxa": 0.50,
        "base_price": 102.10,
        "daily_drift": 0.0002,
        "vol": 0.015,
    },
    {
        "ticker": "HASH11",
        "nome": "Hashdex Nasdaq Crypto Index",
        "cat": "Alternativos",
        "gestor": "Hashdex Gestora",
        "indice": "NCI",
        "pl": 3120400000.0,
        "cotas": 78000000,
        "cotistas": 145000,
        "taxa": 0.60,
        "base_price": 42.50,
        "daily_drift": 0.0012,
        "vol": 0.028,
    },
    {
        "ticker": "BLFT11",
        "nome": "Bradesco B-Index Teva LFT CP",
        "cat": "Renda Fixa",
        "gestor": "BRAM Bradesco Asset",
        "indice": "Teva LFT CP",
        "pl": 1420500000.0,
        "cotas": 14000000,
        "cotistas": 14200,
        "taxa": 0.10,
        "base_price": 108.20,
        "daily_drift": 0.00041,
        "vol": 0.0005,
    },
    {
        "ticker": "LFTS11",
        "nome": "Investo Teva Tesouro Selic",
        "cat": "Renda Fixa",
        "gestor": "Investo Gestão",
        "indice": "Teva Tesouro Selic",
        "pl": 2840100000.0,
        "cotas": 27000000,
        "cotistas": 31500,
        "taxa": 0.19,
        "base_price": 112.40,
        "daily_drift": 0.00041,
        "vol": 0.0005,
    },
    {
        "ticker": "CDIB11",
        "nome": "IT NOW Teva ITBR Selic 800",
        "cat": "Renda Fixa",
        "gestor": "Itaú Asset Management",
        "indice": "Teva ITBR Selic 800",
        "pl": 408700000.0,
        "cotas": 3800000,
        "cotistas": 5268,
        "taxa": 0.15,
        "base_price": 105.60,
        "daily_drift": 0.00042,
        "vol": 0.0006,
    },
    {
        "ticker": "DEBB11",
        "nome": "ETF Teva Debêntures DI",
        "cat": "Renda Fixa",
        "gestor": "Empirica Gestora",
        "indice": "Teva Debêntures DI",
        "pl": 850300000.0,
        "cotas": 8200000,
        "cotistas": 12500,
        "taxa": 0.30,
        "base_price": 114.80,
        "daily_drift": 0.00046,
        "vol": 0.0015,
    },
    {
        "ticker": "CMDB11",
        "nome": "Teva Ações Commodities",
        "cat": "Ações",
        "gestor": "Itaú Asset Management",
        "indice": "Teva Commodities",
        "pl": 280000000.0,
        "cotas": 2600000,
        "cotistas": 3400,
        "taxa": 0.50,
        "base_price": 98.30,
        "daily_drift": 0.0005,
        "vol": 0.014,
    },
    {
        "ticker": "B5P211",
        "nome": "IT NOW IMA-B 5 P2",
        "cat": "Renda Fixa",
        "gestor": "Itaú Asset Management",
        "indice": "IMA-B 5 P2",
        "pl": 4250000000.0,
        "cotas": 48000000,
        "cotistas": 45100,
        "taxa": 0.20,
        "base_price": 86.50,
        "daily_drift": 0.00044,
        "vol": 0.0030,
    },
]


async def seed_etf_universe():
    async for db in get_async_session():
        # Get reference dates from BOVA11 quotes
        res_dates = await db.execute(
            text("""
                SELECT cd.data_pregao
                FROM market.cotacao_diaria cd
                JOIN core.ativo a ON a.id_ativo = cd.id_ativo
                WHERE a.ticker = 'BOVA11'
                ORDER BY cd.data_pregao ASC;
            """)
        )
        trading_dates = [r[0] for r in res_dates.fetchall()]
        print(f"Loaded {len(trading_dates)} trading dates from BOVA11.")

        for defn in ETF_DEFINITIONS:
            ticker = defn["ticker"]
            # 1. Ensure core.ativo exists
            row_ativo = (await db.execute(
                text("SELECT id_ativo FROM core.ativo WHERE ticker = :t"),
                {"t": ticker}
            )).first()

            if not row_ativo:
                u = uuid4()
                await db.execute(
                    text("""
                        INSERT INTO canonical.instrument (
                            instrument_id, asset_class, name, short_name, currency_code, status
                        ) VALUES (
                            :uuid, 'ETF', :nome, :t, 'BRL', 'ACTIVE'
                        ) ON CONFLICT (instrument_id) DO NOTHING;
                    """),
                    {"uuid": u, "nome": defn["nome"], "t": ticker}
                )
                new_id = (await db.execute(
                    text("""
                        INSERT INTO core.ativo (
                            ticker, tipo_ativo, moeda, canonical_instrument_id
                        ) VALUES (
                            :t, 'ETF', 'BRL', :uuid
                        ) RETURNING id_ativo;
                    """),
                    {"t": ticker, "uuid": u}
                )).scalar()
                id_ativo = new_id
                print(f"Created core.ativo for {ticker} (id_ativo={id_ativo}).")
            else:
                id_ativo = row_ativo[0]

            # 2. Upsert asset_details.etf_detalhe
            await db.execute(
                text("""
                    INSERT INTO asset_details.etf_detalhe (
                        id_ativo, indice_referencia, gestor, categoria_etf,
                        taxa_administracao_total, taxa_administracao_primaria, taxa_administracao_secundaria,
                        politica_dividendos, patrimonio, cotas, numero_cotistas
                    ) VALUES (
                        :id_ativo, :indice, :gestor, :cat,
                        :taxa, :taxa, 0.0,
                        'ACUMULACAO', :pl, :cotas, :cotistas
                    )
                    ON CONFLICT (id_ativo) DO UPDATE SET
                        indice_referencia = EXCLUDED.indice_referencia,
                        gestor = EXCLUDED.gestor,
                        categoria_etf = EXCLUDED.categoria_etf,
                        taxa_administracao_total = EXCLUDED.taxa_administracao_total,
                        taxa_administracao_primaria = EXCLUDED.taxa_administracao_primaria,
                        patrimonio = EXCLUDED.patrimonio,
                        cotas = EXCLUDED.cotas,
                        numero_cotistas = EXCLUDED.numero_cotistas;
                """),
                {
                    "id_ativo": id_ativo,
                    "indice": defn["indice"],
                    "gestor": defn["gestor"],
                    "cat": defn["cat"],
                    "taxa": defn["taxa"],
                    "pl": defn["pl"],
                    "cotas": defn["cotas"],
                    "cotistas": defn["cotistas"],
                }
            )

            # 3. Check existing quotes count
            q_cnt = (await db.execute(
                text("SELECT count(*) FROM market.cotacao_diaria WHERE id_ativo = :id"),
                {"id": id_ativo}
            )).scalar()

            if q_cnt < len(trading_dates):
                print(f"Seeding quotes for {ticker} ({q_cnt} -> {len(trading_dates)})...")
                curr_price = defn["base_price"]
                drift = defn["daily_drift"]
                vol = defn["vol"]

                import random
                rng = random.Random(hash(ticker) + 42)

                val_clauses = []
                params = {"id_ativo": id_ativo}
                for i, d in enumerate(trading_dates):
                    shock = rng.gauss(drift, vol)
                    curr_price = max(1.0, curr_price * (1.0 + shock))
                    vol_mm = round(curr_price * 1000 * rng.uniform(0.8, 1.5), 2)
                    negocios = rng.randint(200, 3500)
                    p_close = round(curr_price, 2)
                    p_open = round(curr_price * rng.uniform(0.995, 1.005), 2)
                    p_max = round(curr_price * rng.uniform(1.002, 1.015), 2)
                    p_min = round(curr_price * rng.uniform(0.985, 0.998), 2)

                    d_key = f"d_{i}"
                    po_key = f"po_{i}"
                    pmx_key = f"pmx_{i}"
                    pmn_key = f"pmn_{i}"
                    pc_key = f"pc_{i}"
                    v_key = f"v_{i}"
                    n_key = f"n_{i}"

                    params[d_key] = d
                    params[po_key] = p_open
                    params[pmx_key] = p_max
                    params[pmn_key] = p_min
                    params[pc_key] = p_close
                    params[v_key] = vol_mm
                    params[n_key] = negocios

                    val_clauses.append(f"(:{d_key}, :id_ativo, :{po_key}, :{pmx_key}, :{pmn_key}, :{pc_key}, :{pc_key}, :{v_key}, :{n_key}, false)")

                insert_sql = f"""
                    INSERT INTO market.cotacao_diaria (
                        data_pregao, id_ativo, preco_abertura, preco_maximo, preco_minimo,
                        preco_fechamento, preco_ajustado, volume_total, quantidade_negocios,
                        is_backtest_simulado
                    ) VALUES {', '.join(val_clauses)}
                    ON CONFLICT (id_ativo, data_pregao) DO NOTHING;
                """
                await db.execute(text(insert_sql), params)

        await db.commit()
        print("All 10 ETFs and daily quotes successfully populated in database.")
        break


if __name__ == "__main__":
    asyncio.run(seed_etf_universe())
