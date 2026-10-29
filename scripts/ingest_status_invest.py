#!/usr/bin/env python3
"""
fin: Standalone Ingestion Script for Status Invest Data
Reads statusinvest-busca-avancada.csv (617 stocks) and statusinvest-busca-avancada-2.csv (606 FIIs).
Sanitizes Brazilian number formats, normalizes data types, and performs transactional
batch inserts (chunks of 150) into Neon PostgreSQL.
"""

import sys
import os
import csv
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
import psycopg

DEFAULT_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)


def sanitize_decimal(raw_val):
    if raw_val is None:
        return None
    val = str(raw_val).strip()
    if not val or val in ("-", "--", "null", "None", "NaN"):
        return None
    val = val.replace("R$", "").replace("%", "").strip()
    val = val.replace(".", "").replace(",", ".")
    try:
        return Decimal(val)
    except (InvalidOperation, ValueError):
        return None


def sanitize_int(raw_val):
    d = sanitize_decimal(raw_val)
    if d is None:
        return None
    try:
        return int(round(d))
    except (ValueError, TypeError):
        return None


def read_csv(path):
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"CSV file not found: {p.resolve()}")
    with open(p, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f, delimiter=";")
        clean_rows = []
        for row in reader:
            clean_rows.append({
                (k.strip() if k else ""): (v.strip() if v else "")
                for k, v in row.items()
            })
        return clean_rows


def ingest(db_url, stocks_path, fiis_path, batch_size=150, ref_date=None):
    if ref_date is None:
        ref_date = date(2026, 10, 26)
        observed_at = datetime.now(timezone.utc)

    stocks_rows = read_csv(stocks_path)
    fiis_rows = read_csv(fiis_path)

    print("=" * 65)
    print(f"      STATUS INVEST INGESTION: 1,223 ASSETS TO NEON")
    print("=" * 65)
    print(f"Stocks to process: {len(stocks_rows)}")
    print(f"FIIs to process:   {len(fiis_rows)}")
    print(f"Batch size:        {batch_size}")
    print(f"Reference date:    {ref_date}")
    print("-" * 65)

    with psycopg.connect(db_url) as conn:
        with conn.cursor() as cur:
            # 1. Ensure Gestao FII categories
            cur.execute("""
                INSERT INTO asset_details.tipo_gestao_fii (nome)
                VALUES ('Ativa'), ('Passiva')
                ON CONFLICT (nome) DO NOTHING;
            """)
            cur.execute("SELECT nome, id_tipo_gestao FROM asset_details.tipo_gestao_fii;")
            gestao_map = {name: gid for name, gid in cur.fetchall()}

            # 2. Ingest Stocks (617)
            print("\n▶ Ingesting Stocks (Ações)...")
            stocks_processed = 0
            for i in range(0, len(stocks_rows), batch_size):
                chunk = stocks_rows[i : i + batch_size]
                with conn.transaction():
                    # 2.1 Upsert core.ativo
                    cur.executemany(
                        """
                        INSERT INTO core.ativo (ticker, tipo_ativo, volume_medio, liquidez)
                        VALUES (%s, 'ACAO'::core.tipo_ativo_enum, %s, %s)
                        ON CONFLICT (ticker) DO UPDATE SET
                            tipo_ativo = EXCLUDED.tipo_ativo,
                            volume_medio = COALESCE(EXCLUDED.volume_medio, core.ativo.volume_medio),
                            liquidez = COALESCE(EXCLUDED.liquidez, core.ativo.liquidez);
                        """,
                        [
                            (
                                r["TICKER"].upper(),
                                sanitize_decimal(r.get("LIQUIDEZ MEDIA DIARIA")),
                                sanitize_decimal(r.get("LIQUIDEZ MEDIA DIARIA")),
                            )
                            for r in chunk
                        ],
                    )

                    # 2.2 Get id_ativo
                    chunk_tickers = [r["TICKER"].upper() for r in chunk]
                    cur.execute(
                        "SELECT ticker, id_ativo FROM core.ativo WHERE ticker = ANY(%s);",
                        (chunk_tickers,),
                    )
                    t_map = {t: aid for t, aid in cur.fetchall()}

                    # 2.3 Upsert market.cotacao_diaria
                    cotacao_batch = []
                    indicadores_batch = []

                    for r in chunk:
                        t = r["TICKER"].upper()
                        aid = t_map.get(t)
                        if not aid:
                            continue
                        preco = sanitize_decimal(r.get("PRECO"))
                        vol = sanitize_decimal(r.get("LIQUIDEZ MEDIA DIARIA"))

                        cotacao_batch.append((aid, observed_at, preco, None, vol))

                        indicadores_batch.append((
                            aid,
                            ref_date,
                            sanitize_decimal(r.get("P/L")),
                            sanitize_decimal(r.get("P/VP")),
                            sanitize_decimal(r.get("PSR")),
                            sanitize_decimal(r.get("DY")),
                            sanitize_decimal(r.get("ROE")),
                            sanitize_decimal(r.get("ROIC")),
                            sanitize_decimal(r.get("MARG. LIQUIDA")),
                            sanitize_decimal(r.get("LPA")),
                            sanitize_decimal(r.get("VPA")),
                            sanitize_decimal(r.get("EV/EBIT")),
                            sanitize_decimal(r.get("LIQ. CORRENTE")),
                            sanitize_decimal(r.get("GIRO ATIVOS")),
                            sanitize_decimal(r.get("PEG Ratio")),
                            sanitize_decimal(r.get("P/EBIT")),
                            sanitize_decimal(r.get("P/ATIVOS")),
                            sanitize_decimal(r.get("P/CAP. GIRO")),
                            sanitize_decimal(r.get("P. AT CIR. LIQ.")),
                            sanitize_decimal(r.get("DIV. LIQ. / PATRI.")),
                            sanitize_decimal(r.get("DIVIDA LIQUIDA / EBIT")),
                            sanitize_decimal(r.get("PATRIMONIO / ATIVOS")),
                            sanitize_decimal(r.get("PASSIVOS / ATIVOS")),
                            sanitize_decimal(r.get("MARGEM BRUTA")),
                            sanitize_decimal(r.get("MARGEM EBIT")),
                            sanitize_decimal(r.get("ROA")),
                            sanitize_decimal(r.get("CAGR RECEITAS 5 ANOS")),
                            sanitize_decimal(r.get("CAGR LUCROS 5 ANOS")),
                            sanitize_decimal(r.get("VALOR DE MERCADO")),
                        ))

                    cur.executemany(
                        """
                        INSERT INTO market.cotacao_intraday (
                            id_ativo, timestamp, preco_atual, variacao, volume
                        ) VALUES (%s, %s, %s, %s, %s);
                        """,
                        cotacao_batch,
                    )

                    cur.executemany(
                        """
                        INSERT INTO analytics.indicador_fundamentalista (
                            id_ativo, data_referencia, pl, pvp, psr, dividend_yield, roe, roic,
                            margem_liquida, lpa, vpa, ev_ebit, liquidez_corrente, giro_ativo,
                            peg_ratio, p_ebit, p_ativo, p_cap_giro, p_ativo_circ_liq,
                            divida_liquida_pl, divida_liquida_ebit, patrimonio_ativos, passivos_ativos,
                            margem_bruta, margem_ebit, roa, cagr_receita_5a, cagr_lucro_5a, valor_mercado
                        ) VALUES (
                            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                            %s, %s, %s, %s, %s, %s, %s, %s, %s
                        )
                        ON CONFLICT (id_ativo, data_referencia) DO UPDATE SET
                            pl = EXCLUDED.pl,
                            pvp = EXCLUDED.pvp,
                            psr = EXCLUDED.psr,
                            dividend_yield = EXCLUDED.dividend_yield,
                            roe = EXCLUDED.roe,
                            roic = EXCLUDED.roic,
                            margem_liquida = EXCLUDED.margem_liquida,
                            lpa = EXCLUDED.lpa,
                            vpa = EXCLUDED.vpa,
                            ev_ebit = EXCLUDED.ev_ebit,
                            liquidez_corrente = EXCLUDED.liquidez_corrente,
                            giro_ativo = EXCLUDED.giro_ativo,
                            peg_ratio = EXCLUDED.peg_ratio,
                            p_ebit = EXCLUDED.p_ebit,
                            p_ativo = EXCLUDED.p_ativo,
                            p_cap_giro = EXCLUDED.p_cap_giro,
                            p_ativo_circ_liq = EXCLUDED.p_ativo_circ_liq,
                            divida_liquida_pl = EXCLUDED.divida_liquida_pl,
                            divida_liquida_ebit = EXCLUDED.divida_liquida_ebit,
                            patrimonio_ativos = EXCLUDED.patrimonio_ativos,
                            passivos_ativos = EXCLUDED.passivos_ativos,
                            margem_bruta = EXCLUDED.margem_bruta,
                            margem_ebit = EXCLUDED.margem_ebit,
                            roa = EXCLUDED.roa,
                            cagr_receita_5a = EXCLUDED.cagr_receita_5a,
                            cagr_lucro_5a = EXCLUDED.cagr_lucro_5a,
                            valor_mercado = EXCLUDED.valor_mercado;
                        """,
                        indicadores_batch,
                    )
                stocks_processed += len(chunk)
                print(f"  • Stocks chunk {i // batch_size + 1}: {stocks_processed}/{len(stocks_rows)} ✓")

            # 3. Ingest FIIs (606)
            print("\n▶ Ingesting FIIs (Fundos Imobiliários)...")
            fiis_processed = 0
            for i in range(0, len(fiis_rows), batch_size):
                chunk = fiis_rows[i : i + batch_size]
                with conn.transaction():
                    # 3.1 Upsert core.ativo
                    cur.executemany(
                        """
                        INSERT INTO core.ativo (ticker, tipo_ativo, quantidade_emitida, volume_medio, liquidez)
                        VALUES (%s, 'FII'::core.tipo_ativo_enum, %s, %s, %s)
                        ON CONFLICT (ticker) DO UPDATE SET
                            tipo_ativo = EXCLUDED.tipo_ativo,
                            quantidade_emitida = COALESCE(EXCLUDED.quantidade_emitida, core.ativo.quantidade_emitida),
                            volume_medio = COALESCE(EXCLUDED.volume_medio, core.ativo.volume_medio),
                            liquidez = COALESCE(EXCLUDED.liquidez, core.ativo.liquidez);
                        """,
                        [
                            (
                                r["TICKER"].upper(),
                                sanitize_int(r.get("N COTAS")),
                                sanitize_decimal(r.get("LIQUIDEZ MEDIA DIARIA")),
                                sanitize_decimal(r.get("LIQUIDEZ MEDIA DIARIA")),
                            )
                            for r in chunk
                        ],
                    )

                    # 3.2 Get id_ativo
                    chunk_tickers = [r["TICKER"].upper() for r in chunk]
                    cur.execute(
                        "SELECT ticker, id_ativo FROM core.ativo WHERE ticker = ANY(%s);",
                        (chunk_tickers,),
                    )
                    t_map = {t: aid for t, aid in cur.fetchall()}

                    cotacao_batch = []
                    detalhe_batch = []
                    hist_patr_batch = []
                    indicadores_batch = []

                    for r in chunk:
                        t = r["TICKER"].upper()
                        aid = t_map.get(t)
                        if not aid:
                            continue

                        preco = sanitize_decimal(r.get("PRECO"))
                        ultimo_div = sanitize_decimal(r.get("ULTIMO DIVIDENDO"))
                        dy = sanitize_decimal(r.get("DY"))
                        vp_cota = sanitize_decimal(r.get("VALOR PATRIMONIAL COTA"))
                        pvp = sanitize_decimal(r.get("P/VP"))
                        vol = sanitize_decimal(r.get("LIQUIDEZ MEDIA DIARIA"))
                        pct_caixa = sanitize_decimal(r.get("PERCENTUAL EM CAIXA"))
                        cagr_div_3a = sanitize_decimal(r.get("CAGR DIVIDENDOS 3 ANOS"))
                        cagr_cota_3a = sanitize_decimal(r.get("CAGR VALOR CORA 3 ANOS"))
                        patrimonio = sanitize_decimal(r.get("PATRIMONIO"))
                        n_cotistas = sanitize_int(r.get("N COTISTAS"))
                        n_cotas = sanitize_int(r.get("N COTAS"))
                        g_str = r.get("GESTAO", "").strip()
                        gid = gestao_map.get(g_str) if g_str else None

                        cotacao_batch.append((aid, observed_at, preco, None, vol))

                        detalhe_batch.append((
                            aid,
                            gid,
                            n_cotistas,
                            ultimo_div,
                            vp_cota,
                            pvp,
                            dy,
                            pct_caixa,
                            cagr_div_3a,
                            cagr_cota_3a,
                            patrimonio,
                            n_cotas,
                        ))

                        hist_patr_batch.append((aid, ref_date, patrimonio, n_cotas, vp_cota, n_cotistas))

                        indicadores_batch.append((aid, ref_date, pvp, dy, vp_cota, patrimonio))

                    cur.executemany(
                        """
                        INSERT INTO market.cotacao_intraday (
                            id_ativo, timestamp, preco_atual, variacao, volume
                        ) VALUES (%s, %s, %s, %s, %s);
                        """,
                        cotacao_batch,
                    )

                    cur.executemany(
                        """
                        INSERT INTO asset_details.detalhe_fii (
                            id_ativo, id_tipo_gestao, numero_cotistas, ultimo_dividendo,
                            valor_patrimonial_cota, pvp, dividend_yield, percentual_em_caixa,
                            cagr_dividendos_3a, cagr_valor_cota_3a, patrimonio_liquido, quantidade_cotas
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (id_ativo) DO UPDATE SET
                            id_tipo_gestao = COALESCE(EXCLUDED.id_tipo_gestao, asset_details.detalhe_fii.id_tipo_gestao),
                            numero_cotistas = EXCLUDED.numero_cotistas,
                            ultimo_dividendo = EXCLUDED.ultimo_dividendo,
                            valor_patrimonial_cota = EXCLUDED.valor_patrimonial_cota,
                            pvp = EXCLUDED.pvp,
                            dividend_yield = EXCLUDED.dividend_yield,
                            percentual_em_caixa = EXCLUDED.percentual_em_caixa,
                            cagr_dividendos_3a = EXCLUDED.cagr_dividendos_3a,
                            cagr_valor_cota_3a = EXCLUDED.cagr_valor_cota_3a,
                            patrimonio_liquido = EXCLUDED.patrimonio_liquido,
                            quantidade_cotas = EXCLUDED.quantidade_cotas;
                        """,
                        detalhe_batch,
                    )

                    cur.executemany(
                        """
                        INSERT INTO asset_details.historico_patrimonio_fii (
                            id_ativo, data_referencia, patrimonio_liquido, quantidade_cotas,
                            valor_patrimonial_cota, numero_cotistas
                        ) VALUES (%s, %s, %s, %s, %s, %s)
                        ON CONFLICT (id_ativo, data_referencia) DO UPDATE SET
                            patrimonio_liquido = EXCLUDED.patrimonio_liquido,
                            quantidade_cotas = EXCLUDED.quantidade_cotas,
                            valor_patrimonial_cota = EXCLUDED.valor_patrimonial_cota,
                            numero_cotistas = EXCLUDED.numero_cotistas;
                        """,
                        hist_patr_batch,
                    )

                    cur.executemany(
                        """
                        INSERT INTO analytics.indicador_fundamentalista (
                            id_ativo, data_referencia, pvp, dividend_yield, vpa, valor_mercado
                        ) VALUES (%s, %s, %s, %s, %s, %s)
                        ON CONFLICT (id_ativo, data_referencia) DO UPDATE SET
                            pvp = EXCLUDED.pvp,
                            dividend_yield = EXCLUDED.dividend_yield,
                            vpa = EXCLUDED.vpa,
                            valor_mercado = EXCLUDED.valor_mercado;
                        """,
                        indicadores_batch,
                    )

                fiis_processed += len(chunk)
                print(f"  • FIIs chunk {i // batch_size + 1}: {fiis_processed}/{len(fiis_rows)} ✓")

            # 4. Refresh Materialized Views
            print("\n▶ Refreshing Materialized View analytics.busca_ativo...")
            try:
                cur.execute("REFRESH MATERIALIZED VIEW analytics.busca_ativo;")
                print("  ✓ analytics.busca_ativo refreshed successfully")
            except Exception as e:
                print(f"  ⚠️ Warning refreshing view: {e}")

    total = stocks_processed + fiis_processed
    print("\n" + "=" * 65)
    print(f"       INGESTION COMPLETED: {total} ASSETS LOADED!")
    print("=" * 65)
    return total


if __name__ == "__main__":
    stocks_csv = sys.argv[1] if len(sys.argv) > 1 else "/Users/rafaelaparecido/fin/data/statusinvest-busca-avancada.csv"
    fiis_csv = sys.argv[2] if len(sys.argv) > 2 else "/Users/rafaelaparecido/fin/data/statusinvest-busca-avancada-2.csv"
    url = os.environ.get("DATABASE_URL", DEFAULT_URL)
    ingest(url, stocks_csv, fiis_csv)
