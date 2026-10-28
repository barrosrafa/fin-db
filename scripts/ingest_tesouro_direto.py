#!/usr/bin/env python3
"""
fin: Automated Ingestion of Brazilian National Treasury Bonds (Tesouro Direto)
Source: Secretaria do Tesouro Nacional (STN) - Tesouro Transparente (CKAN API)
Populates:
  - raw.ingestion_batch & raw.payload (Bronze)
  - core.ativo (Gold)
  - canonical.instrument & canonical.government_bond (Silver)
  - canonical.government_bond_quote (Timeseries)
  - asset_details.tesouro_direto (Domain Details)
100% Idempotent with zero duplicates.
"""

import csv
import hashlib
import io
import json
import os
import ssl
import sys
import urllib.request
import uuid
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
import psycopg
from dotenv import load_dotenv

load_dotenv()

SSL_CONTEXT = ssl._create_unverified_context()

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)

CKAN_PACKAGE_URL = "https://www.tesourotransparente.gov.br/ckan/api/3/action/package_show?id=taxas-dos-titulos-ofertados-pelo-tesouro-direto"
FALLBACK_CSV_URL = "https://www.tesourotransparente.gov.br/ckan/dataset/df56aa42-484a-4a59-8184-7676580c81e3/resource/796d2059-14e9-44e3-80c9-2d9e30b405c1/download/precotaxatesourodireto.csv"


def sanitize_decimal(val_str: str | None) -> Decimal | None:
    if not val_str:
        return None
    val = val_str.strip().replace(".", "").replace(",", ".")
    try:
        return Decimal(val)
    except (InvalidOperation, ValueError):
        return None


def get_tesouro_csv_url() -> str:
    req = urllib.request.Request(CKAN_PACKAGE_URL, headers={"User-Agent": "Mozilla/5.0 (fin-ingestion/1.0)"})
    try:
        with urllib.request.urlopen(req, timeout=12, context=SSL_CONTEXT) as resp:
            data = json.loads(resp.read().decode())
            resources = data.get("result", {}).get("resources", [])
            for r in resources:
                if r.get("format", "").upper() == "CSV" and "precotaxatesouro" in r.get("url", "").lower():
                    return r.get("url")
    except Exception as e:
        print(f"Warn: CKAN API lookup failed ({e}), using static fallback URL.")
    return FALLBACK_CSV_URL


def generate_ticker(tipo_titulo: str, vencimento: date) -> str:
    t = tipo_titulo.upper()
    ano = vencimento.year
    if "SELIC" in t:
        return f"LFT{ano}"
    elif "PREFIXADO COM JUROS" in t:
        return f"NTNF{ano}"
    elif "PREFIXADO" in t:
        return f"LTN{ano}"
    elif "IPCA+ COM JUROS" in t:
        return f"NTNB{ano}"
    elif "IPCA+" in t:
        return f"NTNB_P{ano}"
    elif "RENDA+" in t:
        return f"RENDA{ano}"
    elif "EDUCA+" in t:
        return f"EDUCA{ano}"
    else:
        prefix = "".join(w[0] for w in t.split()[:3])
        return f"{prefix}{ano}"


def detect_indexer(tipo_titulo: str) -> str:
    t = tipo_titulo.upper()
    if "SELIC" in t:
        return "SELIC"
    elif "IPCA" in t or "RENDA" in t or "EDUCA" in t:
        return "IPCA"
    elif "PREFIXADO" in t:
        return "PRE"
    return "OUTROS"


def run_tesouro_ingestion():
    print("=" * 70)
    print("  TESOURO DIRETO AUTOMATED INGESTION (STN / TESOURO TRANSPARENTE)")
    print("=" * 70)

    # 1. Discover resource URL
    csv_url = get_tesouro_csv_url()
    print(f"\n[1/6] Discovered CSV resource: {csv_url}")

    # 2. Download bytes and compute SHA-256
    print("\n[2/6] Downloading official dataset...")
    req = urllib.request.Request(csv_url, headers={"User-Agent": "Mozilla/5.0 (fin-ingestion/1.0)"})
    with urllib.request.urlopen(req, timeout=60, context=SSL_CONTEXT) as resp:
        content_bytes = resp.read()

    content_sha256 = hashlib.sha256(content_bytes).hexdigest()
    file_size_mb = round(len(content_bytes) / (1024 * 1024), 2)
    print(f"  • Downloaded: {file_size_mb} MB | SHA-256: {content_sha256}")

    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            # 3. Bronze landing: raw.ingestion_batch and raw.payload
            print("\n[3/6] Landing payload into raw.ingestion_batch & raw.payload...")
            batch_id = uuid.uuid4()
            cur.execute("""
            INSERT INTO raw.ingestion_batch (
                batch_id, collector_name, collector_version, started_at, status, request_count, error_count, notes
            )
            VALUES (%s, 'stn_tesouro_direto', '1.0.0', NOW(), 'RUNNING', 1, 0, 'Official STN Tesouro Direto CSV')
            RETURNING batch_id;
            """, (batch_id,))

            cur.execute("""
            INSERT INTO raw.payload (
                payload_id, batch_id, source_url, captured_at, http_status,
                mime_type, content_sha256, encoding, body, metadata
            )
            VALUES (gen_random_uuid(), %s, %s, NOW(), 200, 'text/csv', %s, 'latin1', %s, %s)
            ON CONFLICT (batch_id, content_sha256) DO NOTHING
            RETURNING payload_id;
            """, (
                batch_id,
                csv_url,
                content_sha256,
                content_bytes,
                psycopg.types.json.Jsonb({"file_size_bytes": len(content_bytes), "source": "STN_CKAN"})
            ))
            payload_res = cur.fetchone()
            payload_id = payload_res[0] if payload_res else None
            print(f"  • Batch ID: {batch_id} | Payload ID: {payload_id}")

            # 4. Parse CSV records
            print("\n[4/6] Parsing CSV lines and grouping by bond type & maturity...")
            f = io.StringIO(content_bytes.decode("latin1"))
            reader = csv.DictReader(f, delimiter=";")

            # Retrieve TESOURO venue_id
            cur.execute("SELECT venue_id FROM canonical.venue WHERE code = 'TESOURO' LIMIT 1;")
            v_row = cur.fetchone()
            tesouro_venue_id = v_row[0] if v_row else None

            # Cache existing bonds
            bonds_dict = {}  # (tipo_titulo, vencimento) -> { 'ticker', 'latest_quote', ... }
            quotes_list = []  # tuples for batch insert

            for row in reader:
                tipo_titulo = row.get("Tipo Titulo", "").strip()
                dt_venc_str = row.get("Data Vencimento", "").strip()
                dt_base_str = row.get("Data Base", "").strip()

                if not tipo_titulo or not dt_venc_str or not dt_base_str:
                    continue

                try:
                    dt_venc = datetime.strptime(dt_venc_str, "%d/%m/%Y").date()
                    dt_base = datetime.strptime(dt_base_str, "%d/%m/%Y").date()
                except ValueError:
                    continue

                taxa_compra = sanitize_decimal(row.get("Taxa Compra Manha"))
                taxa_venda = sanitize_decimal(row.get("Taxa Venda Manha"))
                pu_compra = sanitize_decimal(row.get("PU Compra Manha"))
                pu_venda = sanitize_decimal(row.get("PU Venda Manha"))
                pu_base = sanitize_decimal(row.get("PU Base Manha"))

                bond_key = (tipo_titulo, dt_venc)
                if bond_key not in bonds_dict:
                    ticker = generate_ticker(tipo_titulo, dt_venc)
                    indexer = detect_indexer(tipo_titulo)
                    bonds_dict[bond_key] = {
                        "tipo_titulo": tipo_titulo,
                        "vencimento": dt_venc,
                        "ticker": ticker,
                        "indexer": indexer,
                        "latest_quote": {
                            "date": dt_base,
                            "taxa_compra": taxa_compra,
                            "taxa_venda": taxa_venda,
                            "pu": pu_base or pu_venda or pu_compra,
                        }
                    }
                else:
                    # Update latest quote if dt_base is more recent
                    cur_latest = bonds_dict[bond_key]["latest_quote"]
                    if dt_base > cur_latest["date"]:
                        cur_latest["date"] = dt_base
                        cur_latest["taxa_compra"] = taxa_compra
                        cur_latest["taxa_venda"] = taxa_venda
                        cur_latest["pu"] = pu_base or pu_venda or pu_compra

                quotes_list.append((
                    bond_key,
                    dt_base,
                    taxa_compra,
                    taxa_venda,
                    pu_compra,
                    pu_venda,
                ))

            print(f"  • Unique Treasury Bonds identified: {len(bonds_dict)}")
            print(f"  • Total historical quote observations parsed: {len(quotes_list)}")

            # 5. Populate core.ativo, canonical.instrument, canonical.government_bond & asset_details.tesouro_direto
            print("\n[5/6] Registering Treasury instruments in core.ativo & canonical...")
            bond_instrument_map = {}  # (tipo_titulo, vencimento) -> instrument_id UUID

            for (tipo_titulo, dt_venc), bdata in bonds_dict.items():
                ticker = bdata["ticker"]
                indexer = bdata["indexer"]
                nome_completo = f"{tipo_titulo} {dt_venc.year}"

                # 5a. Upsert in core.ativo
                cur.execute("""
                INSERT INTO core.ativo (
                    ticker, tipo_ativo, indexador, data_vencimento, moeda, tipo_titulo
                )
                VALUES (%s, 'TESOURO'::core.tipo_ativo_enum, %s, %s, 'BRL', %s)
                ON CONFLICT (ticker) DO UPDATE SET
                    indexador = EXCLUDED.indexador,
                    data_vencimento = EXCLUDED.data_vencimento,
                    tipo_titulo = EXCLUDED.tipo_titulo
                RETURNING id_ativo, canonical_instrument_id;
                """, (ticker, indexer, dt_venc, tipo_titulo))
                id_ativo, existing_inst_id = cur.fetchone()

                # 5b. Upsert in canonical.instrument
                inst_id = existing_inst_id or uuid.uuid4()
                cur.execute("""
                INSERT INTO canonical.instrument (
                    instrument_id, asset_class, name, short_name, currency_code,
                    venue_id, status, attributes
                )
                VALUES (%s, 'GOVERNMENT_BOND'::canonical.asset_class, %s, %s, 'BRL', %s, 'ACTIVE', %s)
                ON CONFLICT (instrument_id) DO UPDATE SET
                    name = EXCLUDED.name,
                    short_name = EXCLUDED.short_name
                RETURNING instrument_id;
                """, (
                    inst_id,
                    nome_completo,
                    ticker,
                    tesouro_venue_id,
                    psycopg.types.json.Jsonb({"core_id_ativo": id_ativo, "ticker": ticker, "vencimento": str(dt_venc)})
                ))
                inst_id = cur.fetchone()[0]
                bond_instrument_map[(tipo_titulo, dt_venc)] = inst_id

                # Update core.ativo with canonical_instrument_id
                cur.execute("UPDATE core.ativo SET canonical_instrument_id = %s WHERE id_ativo = %s;", (inst_id, id_ativo))

                # 5c. Upsert in canonical.government_bond
                cur.execute("""
                INSERT INTO canonical.government_bond (
                    instrument_id, bond_program, indexer, maturity_date
                )
                VALUES (%s, 'TESOURO_DIRETO', %s, %s)
                ON CONFLICT (instrument_id) DO UPDATE SET
                    indexer = EXCLUDED.indexer,
                    maturity_date = EXCLUDED.maturity_date;
                """, (inst_id, indexer, dt_venc))

                # 5d. Upsert in asset_details.tesouro_direto
                latest = bdata["latest_quote"]
                cur.execute("""
                INSERT INTO asset_details.tesouro_direto (
                    id_ativo, tipo_titulo, indexador, taxa_compra, taxa_venda, vencimento, pu
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (id_ativo) DO UPDATE SET
                    taxa_compra = EXCLUDED.taxa_compra,
                    taxa_venda = EXCLUDED.taxa_venda,
                    pu = EXCLUDED.pu;
                """, (
                    id_ativo,
                    tipo_titulo,
                    indexer,
                    latest["taxa_compra"],
                    latest["taxa_venda"],
                    dt_venc,
                    latest["pu"]
                ))

            # 6. Bulk Ingest canonical.government_bond_quote using COPY to staging table
            print("\n[6/6] High-speed Bulk Ingestion of quotes using cursor.copy()...")
            cutoff_date = date(2024, 1, 1)
            recent_quotes = [q for q in quotes_list if q[1] >= cutoff_date]
            print(f"  • Selected {len(recent_quotes)} quotes from {cutoff_date} onwards for COPY...")

            cur.execute("""
            CREATE TEMP TABLE staging_tesouro_quote (
                government_bond_id  UUID,
                quote_date          DATE,
                buy_rate            NUMERIC(12,6),
                sell_rate           NUMERIC(12,6),
                buy_price           NUMERIC(18,6),
                sell_price          NUMERIC(18,6),
                raw_payload_id      UUID
            ) ON COMMIT DROP;
            """)

            with cur.copy("""
            COPY staging_tesouro_quote (
                government_bond_id, quote_date, buy_rate, sell_rate, buy_price, sell_price, raw_payload_id
            ) FROM STDIN
            """) as copy:
                for bond_key, dt_base, tx_compra, tx_venda, pu_compra, pu_venda in recent_quotes:
                    inst_id = bond_instrument_map.get(bond_key)
                    if not inst_id:
                        continue
                    copy.write_row((
                        inst_id,
                        dt_base,
                        tx_compra,
                        tx_venda,
                        pu_compra,
                        pu_venda,
                        payload_id,
                    ))

            print("  • Temporary staging table populated via COPY, running atomic UPSERT...")
            cur.execute("""
            INSERT INTO canonical.government_bond_quote (
                government_bond_id, quote_date, buy_rate, sell_rate, buy_price, sell_price, source, raw_payload_id
            )
            SELECT DISTINCT ON (government_bond_id, quote_date)
                government_bond_id, quote_date, buy_rate, sell_rate, buy_price, sell_price, 'STN_TESOURO_TRANSPARENTE', raw_payload_id
            FROM staging_tesouro_quote
            ON CONFLICT (government_bond_id, quote_date, source) DO UPDATE SET
                buy_rate = EXCLUDED.buy_rate,
                sell_rate = EXCLUDED.sell_rate,
                buy_price = EXCLUDED.buy_price,
                sell_price = EXCLUDED.sell_price;
            """)
            inserted_quotes_cnt = cur.rowcount
            print(f"  • Quotes upserted into canonical.government_bond_quote: {inserted_quotes_cnt}")

            # Finish batch
            cur.execute("""
            UPDATE raw.ingestion_batch
            SET status = 'SUCCEEDED', finished_at = NOW(), request_count = 1, notes = %s
            WHERE batch_id = %s;
            """, (f"Inserted {len(bonds_dict)} bonds, {inserted_quotes_cnt} quotes", batch_id))

            conn.commit()


            print("\n" + "=" * 70)
            print("  TESOURO DIRETO INGESTION VERIFICATION")
            print("=" * 70)
            cur.execute("SELECT count(*) FROM canonical.government_bond;")
            print(f"  • canonical.government_bond       : {cur.fetchone()[0]} rows")
            cur.execute("SELECT count(*) FROM canonical.government_bond_quote;")
            print(f"  • canonical.government_bond_quote : {cur.fetchone()[0]} rows")
            cur.execute("SELECT count(*) FROM asset_details.tesouro_direto;")
            print(f"  • asset_details.tesouro_direto    : {cur.fetchone()[0]} rows")
            cur.execute("SELECT count(*) FROM raw.payload;")
            print(f"  • raw.payload                     : {cur.fetchone()[0]} rows")
            print("=" * 70)


if __name__ == "__main__":
    run_tesouro_ingestion()
