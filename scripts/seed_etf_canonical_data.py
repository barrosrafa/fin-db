#!/usr/bin/env python3
"""
Seed canonical ETF metadata and open holdings for Neon DB.
Addresses FIN-QA-01: IVVB11 benchmark and holdings consistency.
"""
import os
import asyncio
import asyncpg
from decimal import Decimal
from datetime import date

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://neondb_owner:npg_pwONKPD13RiC@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)
# Ensure asyncpg-compatible URL (sslmode -> ssl)
if "sslmode=require" in DATABASE_URL:
    DATABASE_URL = DATABASE_URL.replace("sslmode=require", "ssl=require")

async def run_seed():
    print("Connecting to Neon DB...")
    conn = await asyncpg.connect(DATABASE_URL)
    print("Connected.")

    try:
        async with conn.transaction():
            # 1. Update etf_detalhe for IVVB11
            print("Updating asset_details.etf_detalhe for IVVB11, SMAL11, HASH11, BOVA11...")
            await conn.execute("""
                UPDATE asset_details.etf_detalhe ed
                SET 
                    indice_referencia = 'S&P 500',
                    benchmark = 'S&P 500',
                    provedor_indice = 'S&P Dow Jones Indices',
                    gestor = 'BlackRock Brasil',
                    taxa_administracao = 0.23,
                    taxa_administracao_total = 0.23,
                    politica_dividendos = 'ACUMULACAO',
                    regiao_exposicao = 'Estados Unidos',
                    categoria_etf = 'Renda Variável Internacional'
                FROM core.ativo a
                WHERE ed.id_ativo = a.id_ativo AND a.ticker = 'IVVB11';
            """)

            await conn.execute("""
                UPDATE asset_details.etf_detalhe ed
                SET 
                    indice_referencia = 'SMLL',
                    benchmark = 'SMLL',
                    provedor_indice = 'B3',
                    gestor = 'BlackRock Brasil',
                    taxa_administracao = 0.50,
                    taxa_administracao_total = 0.50,
                    regiao_exposicao = 'Brasil',
                    categoria_etf = 'Small Caps Brasil'
                FROM core.ativo a
                WHERE ed.id_ativo = a.id_ativo AND a.ticker = 'SMAL11';
            """)

            await conn.execute("""
                UPDATE asset_details.etf_detalhe ed
                SET 
                    indice_referencia = 'Nasdaq Crypto Index',
                    benchmark = 'NCI',
                    provedor_indice = 'Nasdaq',
                    gestor = 'Hashdex Gestora',
                    taxa_administracao = 1.30,
                    taxa_administracao_total = 1.30,
                    regiao_exposicao = 'Global',
                    categoria_etf = 'Criptoativos'
                FROM core.ativo a
                WHERE ed.id_ativo = a.id_ativo AND a.ticker = 'HASH11';
            """)

            await conn.execute("""
                UPDATE asset_details.etf_detalhe ed
                SET 
                    indice_referencia = 'IBOVESPA',
                    benchmark = 'IBOVESPA',
                    provedor_indice = 'B3',
                    gestor = 'BlackRock Brasil',
                    regiao_exposicao = 'Brasil',
                    categoria_etf = 'Renda Variável Brasil'
                FROM core.ativo a
                WHERE ed.id_ativo = a.id_ativo AND a.ticker = 'BOVA11';
            """)

            # 2. Insert IVVB11 S&P 500 holdings
            ivvb_row = await conn.fetchrow("SELECT id_ativo FROM core.ativo WHERE ticker = 'IVVB11'")
            if not ivvb_row:
                raise ValueError("IVVB11 not found in core.ativo")
            ivvb_id = ivvb_row["id_ativo"]

            print(f"Seeding holdings for IVVB11 (id_ativo: {ivvb_id})...")
            await conn.execute("DELETE FROM market.etf_composicao_carteira WHERE id_ativo_fundo = $1", ivvb_id)

            sp500_holdings = [
                ("MSFT", "Microsoft Corporation", "Tecnologia da Informação", "Estados Unidos", Decimal("6.80")),
                ("AAPL", "Apple Inc.", "Tecnologia da Informação", "Estados Unidos", Decimal("6.50")),
                ("NVDA", "NVIDIA Corporation", "Tecnologia da Informação", "Estados Unidos", Decimal("6.20")),
                ("AMZN", "Amazon.com Inc.", "Consumo Discricionário", "Estados Unidos", Decimal("3.60")),
                ("GOOGL", "Alphabet Inc. Class A", "Serviços de Comunicação", "Estados Unidos", Decimal("2.30")),
                ("META", "Meta Platforms Inc.", "Serviços de Comunicação", "Estados Unidos", Decimal("2.20")),
                ("GOOG", "Alphabet Inc. Class C", "Serviços de Comunicação", "Estados Unidos", Decimal("2.00")),
                ("BRK.B", "Berkshire Hathaway Inc.", "Financeiro", "Estados Unidos", Decimal("1.70")),
                ("AVGO", "Broadcom Inc.", "Tecnologia da Informação", "Estados Unidos", Decimal("1.60")),
                ("LLY", "Eli Lilly and Company", "Saúde", "Estados Unidos", Decimal("1.50")),
            ]

            today = date.today()
            for ticker, desc, setor, pais, peso in sp500_holdings:
                await conn.execute("""
                    INSERT INTO market.etf_composicao_carteira
                      (id_ativo_fundo, data_referencia, codigo_ativo, descricao_ativo, setor_economico, pais_origem, peso_percentual)
                    VALUES ($1, $2, $3, $4, $5, $6, $7)
                """, ivvb_id, today, ticker, desc, setor, pais, peso)

            print(f"Successfully inserted {len(sp500_holdings)} holdings for IVVB11.")

    finally:
        await conn.close()
        print("Database connection closed.")

if __name__ == "__main__":
    asyncio.run(run_seed())
