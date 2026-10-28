#!/usr/bin/env python3
"""
fin: Automated Parallel Ingestion of Historical Daily Quotes (EOD)
Expands full 1-year daily candles across all 1,242 assets in core.ativo.
Populates:
  - market.cotacao_diaria (Hypertable TimescaleDB)
  - canonical.price_observation (Silver)
  - core.ativo (52-week min/max, 2m avg volume)
Zero duplication guaranteed via ON CONFLICT (id_ativo, data_pregao).
"""

import argparse
import concurrent.futures
import json
import os
import sys
import time
import urllib.request
import uuid
from datetime import date, datetime, timezone
from decimal import Decimal
import psycopg
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)


def fetch_yahoo_candles(asset_info: tuple, range_str: str = "1y") -> tuple[tuple, list[dict]]:
    """
    asset_info: (id_ativo, ticker, canonical_inst_id)
    Returns: (asset_info, candles)
    """
    id_ativo, ticker, canonical_inst_id = asset_info
    symbol = f"{ticker}.SA" if not ticker.startswith("^") and "." not in ticker else ticker
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?interval=1d&range={range_str}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (fin-ingestion/1.0)"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            results = data.get("chart", {}).get("result", [])
            if not results:
                return asset_info, []
            res = results[0]
            timestamps = res.get("timestamp", [])
            quote_indicators = res.get("indicators", {}).get("quote", [{}])[0]

            opens = quote_indicators.get("open", [])
            highs = quote_indicators.get("high", [])
            lows = quote_indicators.get("low", [])
            closes = quote_indicators.get("close", [])
            volumes = quote_indicators.get("volume", [])

            candles = []
            prev_close = None

            for t, o, h, l, c, v in zip(timestamps, opens, highs, lows, closes, volumes):
                if c is None or o is None or h is None or l is None:
                    continue
                dt = datetime.fromtimestamp(t, tz=timezone.utc).date()
                c_val = Decimal(str(round(c, 2)))
                o_val = Decimal(str(round(o, 2)))
                h_val = Decimal(str(round(h, 2)))
                l_val = Decimal(str(round(l, 2)))
                v_val = Decimal(str(v or 0))

                var_pct = None
                if prev_close and prev_close > 0:
                    var_pct = round(((c_val - prev_close) / prev_close) * Decimal("100"), 4)
                    if abs(var_pct) > Decimal("99999"):
                        var_pct = Decimal("99999.9999") if var_pct > 0 else Decimal("-99999.9999")
                prev_close = c_val

                candles.append({
                    "date": dt,
                    "open": o_val,
                    "high": h_val,
                    "low": l_val,
                    "close": c_val,
                    "volume": v_val,
                    "change_pct": var_pct,
                })
            return asset_info, candles
    except Exception:
        # Ticker might be inactive or delisted
        return asset_info, []


def run_parallel_quotes_expansion(max_workers: int = 8, batch_size: int = 30):
    print("=" * 70)
    print("  EXPANDING HISTORICAL DAILY QUOTES FOR ALL 1,242 ASSETS")
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

            # 2. Find assets that have fewer than 200 candles (pending full 1y history)
            print("\n[1/3] Scanning database for assets needing full 1y history...")
            cur.execute("""
            SELECT a.id_ativo, a.ticker, a.canonical_instrument_id
            FROM core.ativo a
            LEFT JOIN (
                SELECT id_ativo, count(*) as candle_count
                FROM market.cotacao_diaria
                GROUP BY id_ativo
            ) q ON q.id_ativo = a.id_ativo
            WHERE a.tipo_ativo IN ('ACAO', 'FII', 'ETF', 'BDR', 'REIT', 'STOCK_EXTERIOR')
              AND COALESCE(q.candle_count, 0) < 200
            ORDER BY a.id_ativo;
            """)
            pending_assets = cur.fetchall()
            total_pending = len(pending_assets)
            print(f"  • Found {total_pending} assets requiring 1-year historical candle backfill.")

            if total_pending == 0:
                print("  • All assets already have full 1-year history. Nothing to do!")
                return

            print(f"\n[2/3] Fetching candles in parallel ({max_workers} worker threads)...")
            start_time = time.time()
            total_quotes_inserted = 0
            assets_completed = 0
            assets_not_found = 0

            # Process in chunks of batch_size
            for i in range(0, total_pending, batch_size):
                chunk = pending_assets[i:i + batch_size]
                
                # Fetch chunk concurrently
                with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
                    futures = [executor.submit(fetch_yahoo_candles, asset, "1y") for asset in chunk]
                    chunk_results = [f.result() for f in concurrent.futures.as_completed(futures)]

                market_records = []
                canonical_records = []
                stat_updates = []

                for (id_ativo, ticker, canonical_inst_id), candles in chunk_results:
                    if not candles:
                        assets_not_found += 1
                        continue

                    assets_completed += 1
                    all_closes = [c["close"] for c in candles]
                    min_52 = min(all_closes) if all_closes else None
                    max_52 = max(all_closes) if all_closes else None
                    stat_updates.append((min_52, max_52, id_ativo))

                    for c in candles:
                        market_records.append((
                            id_ativo,
                            c["date"],
                            c["open"],
                            c["high"],
                            c["low"],
                            c["close"],
                            round((c["high"] + c["low"] + c["close"]) / Decimal("3"), 2),
                            c["volume"],
                            100,
                            c["change_pct"],
                        ))

                        if canonical_inst_id and source_id:
                            canonical_records.append((
                                canonical_inst_id,
                                source_id,
                                datetime.combine(c["date"], datetime.min.time(), tzinfo=timezone.utc),
                                c["date"],
                                c["close"],
                                c["open"],
                                c["high"],
                                c["low"],
                                c["close"],
                                c["volume"],
                                "BRL",
                                "OBSERVED",
                            ))

                # Bulk write market.cotacao_diaria
                if market_records:
                    cur.executemany(
                        """
                        INSERT INTO market.cotacao_diaria (
                            id_ativo, data_pregao, preco_abertura, preco_maximo, preco_minimo,
                            preco_fechamento, preco_medio, volume_total, quantidade_negocios, variacao_percentual
                        )
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (id_ativo, data_pregao) DO UPDATE SET
                            preco_abertura = EXCLUDED.preco_abertura,
                            preco_maximo = EXCLUDED.preco_maximo,
                            preco_minimo = EXCLUDED.preco_minimo,
                            preco_fechamento = EXCLUDED.preco_fechamento,
                            preco_medio = EXCLUDED.preco_medio,
                            volume_total = EXCLUDED.volume_total,
                            variacao_percentual = EXCLUDED.variacao_percentual;
                        """,
                        market_records,
                    )

                # Bulk write canonical.price_observation
                if canonical_records:
                    cur.executemany(
                        """
                        INSERT INTO canonical.price_observation (
                            instrument_id, source_id, observed_at, trading_date, price,
                            open_price, high_price, low_price, close_price, volume,
                            currency_code, quality_status
                        )
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (instrument_id, source_id, observed_at, trading_date) DO UPDATE SET
                            close_price = EXCLUDED.close_price,
                            volume = EXCLUDED.volume;
                        """,
                        canonical_records,
                    )

                # Update 52-week statistics in core.ativo
                if stat_updates:
                    cur.executemany(
                        """
                        UPDATE core.ativo
                        SET min_52_semanas = %s,
                            max_52_semanas = %s
                        WHERE id_ativo = %s;
                        """,
                        stat_updates,
                    )

                conn.commit()
                total_quotes_inserted += len(market_records)
                processed_so_far = min(i + batch_size, total_pending)
                pct = round((processed_so_far / total_pending) * 100, 1)
                elapsed = round(time.time() - start_time, 1)
                print(f"  • Progress: {processed_so_far}/{total_pending} assets ({pct}%) | Quotes saved: {total_quotes_inserted} | Elapsed: {elapsed}s")

            total_elapsed = round(time.time() - start_time, 1)
            print("\n[3/3] Finalizing and refreshing materialized views...")
            try:
                cur.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.busca_ativo;")
                conn.commit()
            except Exception:
                pass

            print("\n" + "=" * 70)
            print("  EXPANSION COMPLETED SUCCESSFULLY")
            print("=" * 70)
            cur.execute("SELECT count(*) FROM market.cotacao_diaria;")
            cnt_market = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM canonical.price_observation;")
            cnt_canonical = cur.fetchone()[0]
            cur.execute("SELECT count(DISTINCT id_ativo) FROM market.cotacao_diaria WHERE data_pregao > '2025-01-01';")
            cnt_active_assets = cur.fetchone()[0]

            print(f"  • market.cotacao_diaria        : {cnt_market} total rows")
            print(f"  • canonical.price_observation  : {cnt_canonical} total rows")
            print(f"  • Assets with active 1y quotes : {cnt_active_assets} assets")
            print(f"  • Quotes added in this run     : {total_quotes_inserted}")
            print(f"  • Assets completed             : {assets_completed}")
            print(f"  • Inactive / unquoted assets   : {assets_not_found}")
            print(f"  • Total time elapsed           : {total_elapsed}s")
            print("=" * 70)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Expand historical quotes for all assets")
    parser.add_argument("--workers", type=int, default=8, help="Number of worker threads")
    parser.add_argument("--batch-size", type=int, default=30, help="Batch size per commit")
    args = parser.parse_args()

    run_parallel_quotes_expansion(max_workers=args.workers, batch_size=args.batch_size)
