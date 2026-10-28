#!/usr/bin/env python3
"""
fin-db: Fast Set-Based Synchronization between core.ativo and canonical.instrument
Executes in < 2 seconds directly within PostgreSQL engine.
"""

import os
import psycopg
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)


def sync_identities():
    print("=" * 70)
    print("  FAST SET-BASED SYNCHRONIZATION: CORE.ATIVO <-> CANONICAL")
    print("=" * 70)

    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            # 1. Add canonical_instrument_id to core.ativo if not exists
            print("\n[1/4] Ensuring core.ativo schema has canonical_instrument_id...")
            cur.execute("""
            DO $$ BEGIN
                ALTER TABLE core.ativo ADD COLUMN IF NOT EXISTS canonical_instrument_id UUID REFERENCES canonical.instrument(instrument_id);
            EXCEPTION WHEN duplicate_column THEN NULL;
            END $$;
            CREATE INDEX IF NOT EXISTS idx_ativo_canonical_id ON core.ativo(canonical_instrument_id);
            """)

            # 2. Bulk sync core.emissor_companhia -> canonical.legal_entity
            print("\n[2/4] Bulk syncing core.emissor_companhia -> canonical.legal_entity...")
            cur.execute("""
            INSERT INTO canonical.legal_entity (legal_entity_id, legal_name, cnpj, tax_id, country_code)
            SELECT 
                gen_random_uuid(),
                ec.nome_empresarial,
                ec.cnpj,
                ec.cnpj,
                'BR'
            FROM core.emissor_companhia ec
            WHERE ec.cnpj IS NOT NULL
            ON CONFLICT (country_code, tax_id) DO UPDATE SET
                legal_name = EXCLUDED.legal_name,
                cnpj = EXCLUDED.cnpj;
            """)
            print(f"  • Legal entities processed: {cur.rowcount}")

            # 3. Bulk insert canonical.instrument for core.ativo records missing canonical_instrument_id
            print("\n[3/4] Bulk creating canonical.instrument from core.ativo...")
            cur.execute("""
            WITH b3_venue AS (
                SELECT venue_id FROM canonical.venue WHERE code = 'B3' LIMIT 1
            ),
            new_instruments AS (
                INSERT INTO canonical.instrument (
                    instrument_id, asset_class, legal_entity_id, name, short_name,
                    isin, currency_code, venue_id, status, attributes
                )
                SELECT 
                    gen_random_uuid(),
                    CASE a.tipo_ativo::text
                        WHEN 'ACAO' THEN 'EQUITY'::canonical.asset_class
                        WHEN 'FII' THEN 'FII'::canonical.asset_class
                        WHEN 'FIAGRO' THEN 'FIAGRO'::canonical.asset_class
                        WHEN 'ETF' THEN 'ETF'::canonical.asset_class
                        WHEN 'ETF_EXTERIOR' THEN 'ETF'::canonical.asset_class
                        WHEN 'ETF_EUA' THEN 'ETF'::canonical.asset_class
                        WHEN 'BDR_ETF' THEN 'ETF'::canonical.asset_class
                        WHEN 'BDR' THEN 'BDR'::canonical.asset_class
                        WHEN 'REIT' THEN 'REIT'::canonical.asset_class
                        WHEN 'FI_INFRA' THEN 'FI_INFRA'::canonical.asset_class
                        WHEN 'INDICE' THEN 'INDEX'::canonical.asset_class
                        WHEN 'TESOURO' THEN 'GOVERNMENT_BOND'::canonical.asset_class
                        WHEN 'RENDA_FIXA' THEN 'FIXED_INCOME'::canonical.asset_class
                        WHEN 'FUNDO' THEN 'FUND'::canonical.asset_class
                        WHEN 'CRIPTO' THEN 'CRYPTO'::canonical.asset_class
                        ELSE 'OTHER'::canonical.asset_class
                    END,
                    le.legal_entity_id,
                    a.ticker,
                    a.ticker,
                    a.isin,
                    'BRL',
                    (SELECT venue_id FROM b3_venue),
                    'ACTIVE',
                    jsonb_build_object('core_id_ativo', a.id_ativo, 'ticker', a.ticker)
                FROM core.ativo a
                LEFT JOIN core.emissor_companhia ec ON ec.id_emissor = a.id_emissor
                LEFT JOIN canonical.legal_entity le ON le.tax_id = ec.cnpj
                WHERE a.canonical_instrument_id IS NULL
                ON CONFLICT (isin) DO NOTHING
                RETURNING instrument_id, (attributes->>'core_id_ativo')::int AS id_ativo, short_name AS ticker
            ),
            updated_ativos AS (
                UPDATE core.ativo a
                SET canonical_instrument_id = ni.instrument_id
                FROM new_instruments ni
                WHERE a.id_ativo = ni.id_ativo
                RETURNING a.id_ativo
            )
            SELECT count(*) FROM updated_ativos;
            """)
            updated_count = cur.fetchone()[0]
            print(f"  • Canonical instruments created & linked to core.ativo: {updated_count}")

            # 4. Bulk create TICKER aliases in canonical.instrument_alias
            print("\n[4/4] Bulk syncing canonical.instrument_alias for all tickers...")
            cur.execute("""
            WITH b3_venue AS (
                SELECT venue_id FROM canonical.venue WHERE code = 'B3' LIMIT 1
            )
            INSERT INTO canonical.instrument_alias (
                alias_id, instrument_id, alias_type, alias_value, normalized_value,
                venue_id, valid_from, is_primary
            )
            SELECT 
                gen_random_uuid(),
                a.canonical_instrument_id,
                'TICKER',
                a.ticker,
                UPPER(a.ticker),
                (SELECT venue_id FROM b3_venue),
                date '2000-01-01',
                TRUE
            FROM core.ativo a
            WHERE a.canonical_instrument_id IS NOT NULL
            ON CONFLICT (alias_type, normalized_value, venue_id, valid_from) DO UPDATE SET
                instrument_id = EXCLUDED.instrument_id,
                is_primary = TRUE;
            """)
            print(f"  • Instrument aliases processed: {cur.rowcount}")

            conn.commit()

            # Verifications
            print("\n" + "=" * 70)
            print("  VERIFICATION")
            print("=" * 70)
            cur.execute("SELECT count(*) FROM canonical.instrument;")
            cnt_inst = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM canonical.instrument_alias;")
            cnt_alias = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM canonical.legal_entity;")
            cnt_entity = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM core.ativo WHERE canonical_instrument_id IS NOT NULL;")
            cnt_linked = cur.fetchone()[0]

            print(f"  • canonical.instrument        : {cnt_inst} rows")
            print(f"  • canonical.instrument_alias  : {cnt_alias} rows")
            print(f"  • canonical.legal_entity      : {cnt_entity} rows")
            print(f"  • core.ativo com canonical_id : {cnt_linked} / 1242 linked")
            print("=" * 70)


if __name__ == "__main__":
    sync_identities()
