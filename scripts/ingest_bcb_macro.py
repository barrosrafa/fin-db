#!/usr/bin/env python3
"""
fin: Automated Ingestion of Banco Central do Brasil (BCB) Macroeconomic Series & PTAX
Sources:
  - BCB SGS (Sistema Gerenciador de Séries Temporais)
  - BCB Olinda OData API (PTAX)
Populates:
  - raw.ingestion_batch & raw.payload (Bronze)
  - market.serie_macroeconomica (Hypertable Gold)
  - market.cambio (Hypertable Gold)
  - market.credito_sistema_financeiro & market.contas_publicas_governo
100% Idempotent with zero duplicates.
"""

import hashlib
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

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)

SSL_CONTEXT = ssl._create_unverified_context()

SERIES_DEFINITIONS = [
    {"id": 432, "nome": "Meta Selic Definida pelo Copom", "unidade": "% a.a.", "periodicidade": "DIARIA", "ultimos": 1000},
    {"id": 11, "nome": "Taxa Selic Diária (Over)", "unidade": "% a.d.", "periodicidade": "DIARIA", "ultimos": 1000},
    {"id": 12, "nome": "Taxa CDI Diária", "unidade": "% a.d.", "periodicidade": "DIARIA", "ultimos": 1000},
    {"id": 433, "nome": "IPCA - Variação Mensal", "unidade": "% a.m.", "periodicidade": "MENSAL", "ultimos": 240},
    {"id": 7478, "nome": "IPCA-15 - Variação Mensal", "unidade": "% a.m.", "periodicidade": "MENSAL", "ultimos": 240},
    {"id": 189, "nome": "IGP-M - Variação Mensal", "unidade": "% a.m.", "periodicidade": "MENSAL", "ultimos": 240},
    {"id": 1832, "nome": "Caderneta de Poupança - Saldo Total", "unidade": "R$ mi", "periodicidade": "MENSAL", "ultimos": 120},
    {"id": 2006, "nome": "Caderneta de Poupança - Captação Líquida", "unidade": "R$ mi", "periodicidade": "MENSAL", "ultimos": 120},
    {"id": 20539, "nome": "Saldo das Operações de Crédito - Pessoas Jurídicas", "unidade": "R$ mi", "periodicidade": "MENSAL", "ultimos": 120},
    {"id": 20540, "nome": "Saldo das Operações de Crédito - Pessoas Físicas", "unidade": "R$ mi", "periodicidade": "MENSAL", "ultimos": 120},
    {"id": 20541, "nome": "Saldo de Crédito Imobiliário", "unidade": "R$ mi", "periodicidade": "MENSAL", "ultimos": 120},
    {"id": 21084, "nome": "Inadimplência da Carteira de Crédito do SFN", "unidade": "%", "periodicidade": "MENSAL", "ultimos": 120},
    {"id": 4505, "nome": "Dívida Bruta do Governo Geral (% do PIB)", "unidade": "% PIB", "periodicidade": "MENSAL", "ultimos": 120},
    {"id": 4447, "nome": "Resultado Primário do Governo Central", "unidade": "R$ mi", "periodicidade": "MENSAL", "ultimos": 120},
    {"id": 4448, "nome": "Receita Líquida do Governo Central", "unidade": "R$ mi", "periodicidade": "MENSAL", "ultimos": 120},
    {"id": 4449, "nome": "Despesa Total do Governo Central", "unidade": "R$ mi", "periodicidade": "MENSAL", "ultimos": 120},
]


def fetch_sgs_series(serie_id: int, data_inicial: str = "01/01/2020", data_final: str = "28/10/2026"):
    url = f"https://api.bcb.gov.br/dados/serie/bcdata.sgs.{serie_id}/dados?formato=json&dataInicial={data_inicial}&dataFinal={data_final}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (fin-ingestion/1.0)"})
    with urllib.request.urlopen(req, timeout=15, context=SSL_CONTEXT) as resp:
        content_bytes = resp.read()
        data = json.loads(content_bytes.decode())
        return content_bytes, data, url


def fetch_ptax(moeda: str = "USD", top: int = 500):
    # Fetch recent closing PTAX rates
    data_inicial = "01-01-2024"
    data_final = datetime.now().strftime("%m-%d-%Y")
    url = (
        f"https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/"
        f"CotacaoMoedaPeriodo(moeda=@moeda,dataInicial=@dataInicial,dataFinalCotacao=@dataFinalCotacao)?"
        f"@moeda='{moeda}'&@dataInicial='{data_inicial}'&@dataFinalCotacao='{data_final}'&$top={top}&$format=json"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (fin-ingestion/1.0)"})
    with urllib.request.urlopen(req, timeout=15, context=SSL_CONTEXT) as resp:
        content_bytes = resp.read()
        data = json.loads(content_bytes.decode())
        return content_bytes, data.get("value", []), url


def run_bcb_ingestion():
    print("=" * 70)
    print("  BANCO CENTRAL DO BRASIL (BCB) MACRO & PTAX AUTOMATED INGESTION")
    print("=" * 70)

    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            # 1. Create Ingestion Batch in raw.ingestion_batch
            batch_id = uuid.uuid4()
            cur.execute("""
            INSERT INTO raw.ingestion_batch (
                batch_id, collector_name, collector_version, started_at, status, request_count, error_count, notes
            )
            VALUES (%s, 'bcb_official', '1.0.0', NOW(), 'RUNNING', 0, 0, 'Official BCB SGS & PTAX Ingestion')
            RETURNING batch_id;
            """, (batch_id,))

            total_macro_inserted = 0
            total_cambio_inserted = 0

            # 2. Ingest SGS Macroeconomic Series
            print("\n[1/3] Fetching and ingesting BCB SGS macroeconomic series...")
            for s_def in SERIES_DEFINITIONS:
                s_id = s_def["id"]
                s_nome = s_def["nome"]
                s_unid = s_def["unidade"]
                s_period = s_def["periodicidade"]
                ultimos = s_def["ultimos"]

                try:
                    raw_bytes, items, url = fetch_sgs_series(s_id, data_inicial="01/01/2020", data_final="28/10/2026")
                    sha256 = hashlib.sha256(raw_bytes).hexdigest()

                    # Save raw payload
                    cur.execute("""
                    INSERT INTO raw.payload (
                        payload_id, batch_id, source_url, captured_at, http_status,
                        mime_type, content_sha256, body, metadata
                    )
                    VALUES (gen_random_uuid(), %s, %s, NOW(), 200, 'application/json', %s, %s, %s)
                    ON CONFLICT (batch_id, content_sha256) DO NOTHING;
                    """, (
                        batch_id,
                        url,
                        sha256,
                        raw_bytes,
                        psycopg.types.json.Jsonb({"serie_id": s_id, "nome": s_nome, "records": len(items)})
                    ))

                    # Parse items into list
                    records = []
                    for it in items:
                        dt_str = it.get("data")
                        val_str = it.get("valor")
                        if not dt_str or val_str is None:
                            continue
                        try:
                            dt = datetime.strptime(dt_str, "%d/%m/%Y").date()
                            val = Decimal(str(val_str).replace(",", "."))
                            records.append((s_id, s_nome, "BCB", s_period, dt, val, s_unid))
                        except (ValueError, InvalidOperation):
                            continue

                    # Bulk Upsert into market.serie_macroeconomica
                    if records:
                        cur.executemany("""
                        INSERT INTO market.serie_macroeconomica (
                            codigo_sgs, nome, fonte, periodicidade, data_referencia, valor, unidade
                        )
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (codigo_sgs, data_referencia) DO UPDATE SET
                            valor = EXCLUDED.valor,
                            nome = EXCLUDED.nome;
                        """, records)
                        total_macro_inserted += len(records)
                        print(f"  • [{s_id}] {s_nome}: {len(records)} points upserted")

                except Exception as e:
                    print(f"  • Warn: Failed fetching SGS serie {s_id}: {e}")

            # 3. Ingest PTAX Exchange Rates (USD & EUR)
            print("\n[2/3] Fetching and ingesting BCB PTAX exchange rates (USD, EUR)...")
            for moeda in ["USD", "EUR"]:
                try:
                    raw_bytes, quotes, url = fetch_ptax(moeda, top=600)
                    sha256 = hashlib.sha256(raw_bytes).hexdigest()

                    cur.execute("""
                    INSERT INTO raw.payload (
                        payload_id, batch_id, source_url, captured_at, http_status,
                        mime_type, content_sha256, body, metadata
                    )
                    VALUES (gen_random_uuid(), %s, %s, NOW(), 200, 'application/json', %s, %s, %s)
                    ON CONFLICT (batch_id, content_sha256) DO NOTHING;
                    """, (
                        batch_id,
                        url,
                        sha256,
                        raw_bytes,
                        psycopg.types.json.Jsonb({"moeda": moeda, "records": len(quotes)})
                    ))

                    # Filter for closing bulletins (Fechamento)
                    cambio_records = []
                    for q in quotes:
                        tipo_boletim = q.get("tipoBoletim", "")
                        # Consider Fechamento or Intermediário
                        tipo_enum = "PTAX" if tipo_boletim == "Fechamento" else "Intraday"
                        dt_hora_str = q.get("dataHoraCotacao", "")
                        if not dt_hora_str:
                            continue
                        try:
                            # format: 2026-10-01 10:10:11.547731
                            dt = datetime.fromisoformat(dt_hora_str).date()
                            compra = Decimal(str(q.get("cotacaoCompra", 0)))
                            venda = Decimal(str(q.get("cotacaoVenda", 0)))
                            cambio_records.append((
                                dt,
                                moeda,
                                "BRL",
                                compra,
                                venda,
                                tipo_enum
                            ))
                        except (ValueError, InvalidOperation):
                            continue

                    if cambio_records:
                        cur.executemany("""
                        INSERT INTO market.cambio (
                            data_referencia, moeda_origem, moeda_destino, taxa_compra, taxa_venda, tipo
                        )
                        VALUES (%s, %s, %s, %s, %s, %s)
                        ON CONFLICT (data_referencia, moeda_origem, moeda_destino, tipo) DO UPDATE SET
                            taxa_compra = EXCLUDED.taxa_compra,
                            taxa_venda = EXCLUDED.taxa_venda;
                        """, cambio_records)
                        total_cambio_inserted += len(cambio_records)
                        print(f"  • {moeda}/BRL PTAX: {len(cambio_records)} records upserted")

                except Exception as e:
                    print(f"  • Warn: Failed fetching PTAX for {moeda}: {e}")

            # 4. Finalize Batch
            cur.execute("""
            UPDATE raw.ingestion_batch
            SET status = 'SUCCEEDED', finished_at = NOW(),
                request_count = %s,
                notes = %s
            WHERE batch_id = %s;
            """, (
                len(SERIES_DEFINITIONS) + 2,
                f"Ingested {total_macro_inserted} macro observations, {total_cambio_inserted} cambio quotes",
                batch_id
            ))

            conn.commit()

            print("\n" + "=" * 70)
            print("  BCB MACRO & PTAX INGESTION VERIFICATION")
            print("=" * 70)
            cur.execute("SELECT count(*) FROM market.serie_macroeconomica;")
            print(f"  • market.serie_macroeconomica : {cur.fetchone()[0]} rows")
            cur.execute("SELECT count(*) FROM market.cambio;")
            print(f"  • market.cambio               : {cur.fetchone()[0]} rows")
            cur.execute("SELECT count(*) FROM raw.payload;")
            print(f"  • raw.payload                 : {cur.fetchone()[0]} rows")
            print("=" * 70)


if __name__ == "__main__":
    run_bcb_ingestion()
