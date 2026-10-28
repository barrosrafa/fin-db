#!/usr/bin/env python3
"""
fin: Automated Historical Dividends, JCP, Rendimentos & Splits Pipeline
Fetches 5-year corporate action events (dividends and stock splits) for all 1,242 assets.
Populates:
  - market.provento (Gold Dividends/JCP/Rendimentos)
  - market.desdobramento_split (Gold Stock Splits / Inplits)
  - canonical.corporate_event (Silver Bitemporal Events)
  - analytics.mapa_sazonalidade_dividendo (Heatmap Matrix)
100% Idempotent with zero duplicates.
"""

import argparse
import concurrent.futures
import json
import os
import sys
import time
import urllib.request
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
import psycopg
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)


def fetch_yahoo_events(asset_info: tuple, range_str: str = "5y") -> tuple[tuple, list[dict], list[dict]]:
    """
    asset_info: (id_ativo, ticker, tipo_ativo, canonical_inst_id)
    Returns: (asset_info, dividends, splits)
    """
    id_ativo, ticker, tipo_ativo, canonical_inst_id = asset_info
    symbol = f"{ticker}.SA" if not ticker.startswith("^") and "." not in ticker else ticker
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?interval=1mo&range={range_str}&events=div%7Csplit"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (fin-ingestion/1.0)"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            results = data.get("chart", {}).get("result", [])
            if not results:
                return asset_info, [], []
            res = results[0]
            raw_events = res.get("events", {})
            raw_divs = raw_events.get("dividends", {})
            raw_splits = raw_events.get("splits", {})

            div_records = []
            for ts_str, d in raw_divs.items():
                amt = d.get("amount")
                if amt is None or amt <= 0:
                    continue
                dt_ex = datetime.fromtimestamp(int(ts_str), tz=timezone.utc).date()
                dt_com = dt_ex - timedelta(days=1)
                dt_pag = dt_ex  # Default payment date to ex-date if exact settlement not provided

                # Classify tipo_provento
                if tipo_ativo == "FII":
                    tipo_prov = "RENDIMENTO"
                    canon_kind = "RENT"
                else:
                    tipo_prov = "DIVIDENDO"
                    canon_kind = "DIVIDEND"

                div_records.append({
                    "data_com": dt_com,
                    "data_ex": dt_ex,
                    "data_pagamento": dt_pag,
                    "valor_por_acao": Decimal(str(round(amt, 6))),
                    "tipo_provento": tipo_prov,
                    "canon_kind": canon_kind,
                    "mes_referencia": dt_com.strftime("%Y-%m"),
                })

            split_records = []
            for ts_str, s in raw_splits.items():
                num = s.get("numerator")
                denom = s.get("denominator")
                if not num or not denom or num <= 0 or denom <= 0:
                    continue
                dt_ex = datetime.fromtimestamp(int(ts_str), tz=timezone.utc).date()
                if num > denom:
                    tipo_split = "SPLIT"
                    fator = Decimal(str(round(num / denom, 6)))
                else:
                    tipo_split = "INPLIT"
                    fator = Decimal(str(round(denom / num, 6)))

                split_records.append({
                    "data_ex": dt_ex,
                    "tipo": tipo_split,
                    "fator": fator,
                    "numerator": int(num),
                    "denominator": int(denom),
                })

            return asset_info, div_records, split_records
    except Exception:
        return asset_info, [], []


def run_proventos_ingestion(max_workers: int = 8, batch_size: int = 40):
    print("=" * 70)
    print("  AUTOMATED HISTORICAL DIVIDENDS & CORPORATE ACTIONS PIPELINE")
    print("=" * 70)

    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            # 1. Fetch Source ID for B3
            cur.execute("SELECT source_id FROM canonical.source WHERE name = 'B3' LIMIT 1;")
            s_row = cur.fetchone()
            if not s_row:
                cur.execute("SELECT source_id FROM canonical.source LIMIT 1;")
                s_row = cur.fetchone()
            source_id = s_row[0] if s_row else None

            # 2. Select all target assets (Stocks, FIIs, ETFs, BDRs)
            print("\n[1/4] Selecting universe of listed equities and funds from core.ativo...")
            cur.execute("""
            SELECT id_ativo, ticker, tipo_ativo::text, canonical_instrument_id
            FROM core.ativo
            WHERE tipo_ativo IN ('ACAO', 'FII', 'ETF', 'BDR', 'REIT', 'STOCK_EXTERIOR')
            ORDER BY id_ativo;
            """)
            assets = cur.fetchall()
            total_assets = len(assets)
            print(f"  • Selected {total_assets} assets to inspect for 5-year dividend history.")

            # 3. Parallel fetch of corporate actions
            print(f"\n[2/4] Fetching dividend & split events in parallel ({max_workers} threads)...")
            start_time = time.time()
            total_divs_inserted = 0
            total_splits_inserted = 0
            assets_with_divs = 0

            for i in range(0, total_assets, batch_size):
                chunk = assets[i:i + batch_size]
                with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
                    futures = [executor.submit(fetch_yahoo_events, asset, "5y") for asset in chunk]
                    chunk_results = [f.result() for f in concurrent.futures.as_completed(futures)]

                provento_tuples = []
                canonical_tuples = []
                split_tuples = []

                for (id_ativo, ticker, tipo_ativo, canonical_inst_id), divs, splits in chunk_results:
                    if divs:
                        assets_with_divs += 1
                        for d in divs:
                            provento_tuples.append((
                                id_ativo,
                                d["tipo_provento"],
                                d["data_com"],
                                d["data_ex"],
                                d["data_pagamento"],
                                d["valor_por_acao"],
                                'BRL',
                                d["mes_referencia"],
                            ))

                            if canonical_inst_id and source_id:
                                canonical_tuples.append((
                                    canonical_inst_id,
                                    source_id,
                                    d["canon_kind"],
                                    d["data_com"],
                                    d["data_ex"],
                                    d["data_pagamento"],
                                    d["valor_por_acao"],
                                    'BRL',
                                ))

                    if splits:
                        for s in splits:
                            split_tuples.append((
                                id_ativo,
                                s["tipo"],
                                s["data_ex"],
                                s["fator"],
                                s["denominator"],
                                s["numerator"],
                            ))

                # Bulk insert into market.provento with strict deduplication
                if provento_tuples:
                    cur.executemany("""
                    INSERT INTO market.provento (
                        id_ativo, tipo_provento, data_com, data_ex, data_pagamento, valor_por_acao, moeda, mes_referencia
                    )
                    VALUES (%s, %s::market.tipo_provento_enum, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (id_ativo, tipo_provento, data_ex, valor_por_acao) DO NOTHING;
                    """, provento_tuples)

                # Bulk insert into canonical.corporate_event
                if canonical_tuples:
                    cur.executemany("""
                    INSERT INTO canonical.corporate_event (
                        instrument_id, source_id, event_kind, announcement_date, ex_date, payment_date, amount_per_unit, currency_code
                    )
                    VALUES (%s, %s, %s::canonical.event_kind, %s, %s, %s, %s, %s)
                    ON CONFLICT (instrument_id, event_kind, ex_date, payment_date, amount_per_unit, source_id) DO NOTHING;
                    """, canonical_tuples)

                # Bulk insert into market.desdobramento_split
                if split_tuples:
                    cur.executemany("""
                    INSERT INTO market.desdobramento_split (
                        id_ativo, tipo, data_ex, fator, quantidade_antes, quantidade_depois
                    )
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT (id_ativo, data_ex, tipo) DO UPDATE SET
                        fator = EXCLUDED.fator;
                    """, split_tuples)

                conn.commit()
                total_divs_inserted += len(provento_tuples)
                total_splits_inserted += len(split_tuples)
                processed = min(i + batch_size, total_assets)
                pct = round((processed / total_assets) * 100, 1)
                elapsed = round(time.time() - start_time, 1)
                print(f"  • Progress: {processed}/{total_assets} ({pct}%) | Proventos: {total_divs_inserted} | Splits: {total_splits_inserted} | Time: {elapsed}s")

            # 4. Refresh Dividend Seasonality Heatmap
            print("\n[3/4] Re-aggregating analytics.mapa_sazonalidade_dividendo for all assets...")
            seasonality_query = """
            INSERT INTO analytics.mapa_sazonalidade_dividendo (
                id_ativo, mes_calendario, tipo_evento, ocorrencias_historicas,
                anos_analisados, valor_medio_provento, yield_medio_mensal, ultimo_ano_pago
            )
            SELECT 
                p.id_ativo,
                EXTRACT(MONTH FROM p.data_ex)::smallint AS mes_calendario,
                'DATA_COM' AS tipo_evento,
                COUNT(DISTINCT EXTRACT(YEAR FROM p.data_ex)) AS ocorrencias_historicas,
                (GREATEST(EXTRACT(YEAR FROM MAX(p.data_ex)) - EXTRACT(YEAR FROM MIN(p.data_ex)) + 1, 1))::int AS anos_analisados,
                ROUND(AVG(p.valor_por_acao), 6) AS valor_medio_provento,
                ROUND(COALESCE(AVG(p.valor_por_acao / NULLIF(cd.preco_fechamento, 0)), 0.0), 4) AS yield_medio_mensal,
                MAX(EXTRACT(YEAR FROM p.data_ex))::int AS ultimo_ano_pago
            FROM market.provento p
            LEFT JOIN LATERAL (
                SELECT preco_fechamento 
                FROM market.cotacao_diaria 
                WHERE id_ativo = p.id_ativo AND data_pregao <= p.data_ex 
                ORDER BY data_pregao DESC LIMIT 1
            ) cd ON TRUE
            WHERE p.data_ex IS NOT NULL
            GROUP BY p.id_ativo, EXTRACT(MONTH FROM p.data_ex)
            ON CONFLICT (id_ativo, mes_calendario, tipo_evento) DO UPDATE 
            SET 
                ocorrencias_historicas = EXCLUDED.ocorrencias_historicas,
                anos_analisados = EXCLUDED.anos_analisados,
                valor_medio_provento = EXCLUDED.valor_medio_provento,
                yield_medio_mensal = EXCLUDED.yield_medio_mensal,
                ultimo_ano_pago = EXCLUDED.ultimo_ano_pago,
                data_atualizacao = NOW();
            """
            cur.execute(seasonality_query)
            conn.commit()
            print(f"  • Dividend Seasonality Heatmap matrix updated ({cur.rowcount} entries aggregated).")

            # 5. Verification
            print("\n[4/4] Verifying proventos & corporate events tables...")
            cur.execute("SELECT count(*) FROM market.provento;")
            cnt_prov = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM market.desdobramento_split;")
            cnt_split = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM canonical.corporate_event;")
            cnt_canon_event = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM analytics.mapa_sazonalidade_dividendo;")
            cnt_seasonality = cur.fetchone()[0]
            cur.execute("SELECT count(DISTINCT id_ativo) FROM market.provento;")
            cnt_payers = cur.fetchone()[0]

            print("\n" + "=" * 70)
            print("  PROVENTOS INGESTION SUMMARY")
            print("=" * 70)
            print(f"  • market.provento                     : {cnt_prov} rows")
            print(f"  • market.desdobramento_split          : {cnt_split} rows")
            print(f"  • canonical.corporate_event           : {cnt_canon_event} rows")
            print(f"  • analytics.mapa_sazonalidade_dividendo: {cnt_seasonality} rows")
            print(f"  • Distinct dividend-paying assets     : {cnt_payers} assets")
            print(f"  • Total time elapsed                  : {round(time.time() - start_time, 1)}s")
            print("=" * 70)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest historical dividends and splits")
    parser.add_argument("--workers", type=int, default=8, help="Number of worker threads")
    parser.add_argument("--batch-size", type=int, default=40, help="Batch size per commit")
    args = parser.parse_args()

    run_proventos_ingestion(max_workers=args.workers, batch_size=args.batch_size)
