"""
Seeds realistic daily historical CDI series into market.benchmark_serie
from 2023-01-02 to 2026-10-28 (business days).
"""
import asyncio
import datetime
from sqlalchemy import text
from app.core.database import get_session_factory

async def seed_cdi():
    session_factory = get_session_factory()
    async with session_factory() as session:
        id_benchmark = 1  # CDI
        start_date = datetime.date(2023, 1, 2)
        end_date = datetime.date(2026, 10, 28)

        # Generate business days (Mon-Fri)
        curr = start_date
        dates = []
        while curr <= end_date:
            if curr.weekday() < 5:  # Mon to Fri
                dates.append(curr)
            curr += datetime.timedelta(days=1)

        print(f"Generating {len(dates)} daily CDI points...")

        # Cumulative factor starting at 100.0
        cum_value = 100.0
        batch = []
        for d in dates:
            # Determine annualized rate based on year
            if d.year == 2023:
                annual_rate = 0.1365 if d.month <= 7 else 0.1225
            elif d.year == 2024:
                annual_rate = 0.1125 if d.month <= 6 else 0.1065
            elif d.year == 2025:
                annual_rate = 0.1100
            else:  # 2026
                annual_rate = 0.1150

            # Daily factor
            daily_factor = (1.0 + annual_rate) ** (1.0 / 252.0)
            cum_value *= daily_factor

            batch.append({
                "id_bm": id_benchmark,
                "dt": d,
                "val": round(annual_rate * 100, 4),  # annual rate %
                "val_norm": round(cum_value, 4),      # cumulative index base 100
            })

        # Insert in batches
        chunk_size = 200
        for i in range(0, len(batch), chunk_size):
            chunk = batch[i:i + chunk_size]
            val_strs = []
            params = {}
            for j, item in enumerate(chunk):
                val_strs.append(f"(:id_{j}, :dt_{j}, :val_{j}, :val_norm_{j})")
                params[f"id_{j}"] = item["id_bm"]
                params[f"dt_{j}"] = item["dt"]
                params[f"val_{j}"] = item["val"]
                params[f"val_norm_{j}"] = item["val_norm"]

            stmt = text(f"""
            INSERT INTO market.benchmark_serie (id_benchmark, data_referencia, valor, valor_normalizado)
            VALUES {', '.join(val_strs)}
            ON CONFLICT (id_benchmark, data_referencia) DO UPDATE 
            SET valor = EXCLUDED.valor, valor_normalizado = EXCLUDED.valor_normalizado;
            """)
            await session.execute(stmt, params)

        await session.commit()
        print(f"Inserted {len(batch)} CDI daily points into market.benchmark_serie successfully.")

if __name__ == "__main__":
    asyncio.run(seed_cdi())
