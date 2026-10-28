#!/usr/bin/env python3
"""
Seed real shopping mall properties for SHOP11 (FII Multi Shoppings) in Neon DB.
Addresses FIN-QA-03: Portfólio imobiliário idêntico para FIIs diferentes.
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
if "sslmode=require" in DATABASE_URL:
    DATABASE_URL = DATABASE_URL.replace("sslmode=require", "ssl=require")

async def run_seed():
    print("Connecting to Neon DB...")
    conn = await asyncpg.connect(DATABASE_URL)
    print("Connected.")

    try:
        shop_row = await conn.fetchrow("SELECT id_ativo FROM core.ativo WHERE ticker = 'SHOP11'")
        if not shop_row:
            raise ValueError("SHOP11 not found in core.ativo")
        shop_id = shop_row["id_ativo"]
        print(f"SHOP11 id_ativo: {shop_id}")

        async with conn.transaction():
            # Clean existing participations for SHOP11 if any
            await conn.execute("DELETE FROM asset_details.fii_imovel_participacao WHERE id_ativo = $1", shop_id)

            properties = [
                ("Shopping Pátio Higienópolis", "SHOPPING", "AAA", "Av. Higienópolis, 618", "São Paulo", "SP", Decimal("34200.00"), Decimal("1.20"), Decimal("25.00")),
                ("Shopping Vila Olímpia", "SHOPPING", "AAA", "Rua Olimpíadas, 360", "São Paulo", "SP", Decimal("28500.00"), Decimal("2.10"), Decimal("30.00")),
                ("Morumbi Town Shopping", "SHOPPING", "AA", "Av. Giovanni Gronchi, 5930", "São Paulo", "SP", Decimal("31400.00"), Decimal("3.40"), Decimal("40.00")),
                ("Shopping Del Rey Participação", "SHOPPING", "AA", "Av. Presidente Carlos Luz, 3001", "Belo Horizonte", "MG", Decimal("45800.00"), Decimal("2.80"), Decimal("15.00")),
            ]

            ref_date = date(2026, 10, 1)
            for nome, tipo, classe, endereco, cidade, uf, abl, vacancia, part in properties:
                # Check if property already exists
                imovel = await conn.fetchrow("SELECT id_imovel FROM asset_details.fii_imovel WHERE nome = $1", nome)
                if imovel:
                    imovel_id = imovel["id_imovel"]
                else:
                    imovel_id = await conn.fetchval("""
                        INSERT INTO asset_details.fii_imovel
                          (nome, tipo_imovel, classe_siila, endereco, cidade, uf, abl_total_m2, status_imovel)
                        VALUES ($1, $2, $3, $4, $5, $6, $7, 'CONCLUIDO')
                        RETURNING id_imovel;
                    """, nome, tipo, classe, endereco, cidade, uf, abl)

                abl_propria = (abl * part) / Decimal("100.0")
                await conn.execute("""
                    INSERT INTO asset_details.fii_imovel_participacao
                      (id_ativo, id_imovel, data_referencia, participacao_pct, abl_propria_m2, vacancia_fisica_pct)
                    VALUES ($1, $2, $3, $4, $5, $6)
                """, shop_id, imovel_id, ref_date, part, abl_propria, vacancia)

            print(f"Successfully inserted {len(properties)} shopping properties for SHOP11.")

    finally:
        await conn.close()
        print("Database connection closed.")

if __name__ == "__main__":
    asyncio.run(run_seed())
