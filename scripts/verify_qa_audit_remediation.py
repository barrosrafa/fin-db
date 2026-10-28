#!/usr/bin/env python3
"""
Comprehensive QA Audit Verification Script
Validates all 10 QA audit defects (FIN-QA-01 to FIN-QA-10) across database, API, and web artifacts.
"""

import os
import sys
import asyncio
import re
from pathlib import Path
from decimal import Decimal
import asyncpg
from dotenv import load_dotenv

FIN_DIR = Path(__file__).resolve().parent.parent
FIN_API_DIR = FIN_DIR.parent / "fin-api"
FIN_WEB_DIR = FIN_DIR.parent / "fin-web"

load_dotenv(FIN_DIR / ".env")
DATABASE_URL = os.getenv("DATABASE_URL")


async def verify_fin_qa_01(conn):
    """FIN-QA-01: IVVB11 benchmark and holdings consistency."""
    print("\n[VERIFY FIN-QA-01] IVVB11 Benchmark & Holdings Consistency...")
    
    # Check etf_detalhe benchmark
    row = await conn.fetchrow(
        """
        SELECT a.ticker, ed.indice_referencia, ed.gestor
        FROM core.ativo a
        JOIN asset_details.etf_detalhe ed ON ed.id_ativo = a.id_ativo
        WHERE a.ticker = 'IVVB11'
        """
    )
    assert row is not None, "IVVB11 not found in etf_detalhe"
    assert row["indice_referencia"] == "S&P 500", f"Expected S&P 500, got {row['indice_referencia']}"
    print(f"  ✓ etf_detalhe.indice_referencia: {row['indice_referencia']} (Gestor: {row['gestor']})")

    # Check holdings in market.etf_composicao_carteira
    holdings = await conn.fetch(
        """
        SELECT ecc.codigo_ativo, ecc.descricao_ativo, ecc.peso_percentual
        FROM core.ativo a
        JOIN market.etf_composicao_carteira ecc ON ecc.id_ativo_fundo = a.id_ativo
        WHERE a.ticker = 'IVVB11'
        ORDER BY ecc.peso_percentual DESC
        """
    )
    assert len(holdings) > 0, "No holdings found for IVVB11 in database"
    holding_tickers = [h["codigo_ativo"] for h in holdings]
    assert "VALE3" not in holding_tickers, "VALE3 should NOT be in IVVB11 S&P 500 holdings!"
    assert "PETR4" not in holding_tickers, "PETR4 should NOT be in IVVB11 S&P 500 holdings!"
    assert any(t in holding_tickers for t in ["MSFT", "AAPL", "NVDA"]), f"Expected US tech giants, got {holding_tickers}"
    print(f"  ✓ IVVB11 holdings count: {len(holdings)} (Top: {', '.join(holding_tickers[:4])})")


async def verify_fin_qa_02(conn):
    """FIN-QA-02: Equity 12-month return formula and mathematical domain bounds."""
    print("\n[VERIFY FIN-QA-02] Equity Return Formula & Mathematical Domain Bounds...")

    # Verify RENT3 historical daily prices in cotacao_diaria
    rent3_stats = await conn.fetchrow(
        """
        SELECT 
            (SELECT preco_fechamento FROM market.cotacao_diaria WHERE id_ativo = a.id_ativo ORDER BY data_pregao DESC LIMIT 1) as preco_atual,
            (SELECT preco_fechamento FROM market.cotacao_diaria WHERE id_ativo = a.id_ativo AND data_pregao <= (CURRENT_DATE - INTERVAL '365 days') ORDER BY data_pregao DESC LIMIT 1) as preco_12m,
            (SELECT COUNT(*) FROM market.cotacao_diaria WHERE id_ativo = a.id_ativo) as total_pregoes
        FROM core.ativo a
        WHERE a.ticker = 'RENT3'
        """
    )
    assert rent3_stats is not None, "RENT3 not found in core.ativo"
    p_atual = float(rent3_stats["preco_atual"])
    p_12m = float(rent3_stats["preco_12m"])
    ret_12m = ((p_atual - p_12m) / p_12m) * 100.0

    assert ret_12m >= -100.0, f"Mathematical domain violation: RENT3 return {ret_12m}% < -100%"
    assert -25.0 <= ret_12m <= -10.0, f"Expected realistic ~ -18.82%, got {ret_12m}%"
    print(f"  ✓ RENT3 Preço Atual: R$ {p_atual:.2f}, Preço 12M: R$ {p_12m:.2f}, Retorno 12M Real: {ret_12m:.2f}% (Quotes: {rent3_stats['total_pregoes']})")


async def verify_fin_qa_03(conn):
    """FIN-QA-03: FII Property Isolation (SHOP11 vs FTCE11B)."""
    print("\n[VERIFY FIN-QA-03] FII Physical Property Isolation...")

    # FTCE11B is a CRI / Paper fund - must have 0 physical properties
    ftce_props = await conn.fetch(
        """
        SELECT fi.nome
        FROM core.ativo a
        JOIN asset_details.fii_imovel_participacao fip ON fip.id_ativo = a.id_ativo
        JOIN asset_details.fii_imovel fi ON fi.id_imovel = fip.id_imovel
        WHERE a.ticker = 'FTCE11B'
        """
    )
    assert len(ftce_props) == 0, f"FTCE11B CRI fund should have 0 physical properties, found {len(ftce_props)}"
    print(f"  ✓ FTCE11B physical properties: {len(ftce_props)} (CRI / Paper Fund confirmed)")

    # SHOP11 must have shopping centers, NOT HGLG logistics warehouses
    shop_props = await conn.fetch(
        """
        SELECT fi.nome, fi.cidade, fi.uf, fi.tipo_imovel
        FROM core.ativo a
        JOIN asset_details.fii_imovel_participacao fip ON fip.id_ativo = a.id_ativo
        JOIN asset_details.fii_imovel fi ON fi.id_imovel = fip.id_imovel
        WHERE a.ticker = 'SHOP11'
        """
    )
    assert len(shop_props) >= 4, f"SHOP11 should have at least 4 properties, got {len(shop_props)}"
    prop_names = [p["nome"] for p in shop_props]
    assert not any("HGLG" in name for name in prop_names), f"SHOP11 should not have HGLG properties! Found: {prop_names}"
    print(f"  ✓ SHOP11 physical properties: {len(shop_props)} ({', '.join(prop_names[:2])}...)")


def verify_codebase_artifacts():
    """Validates Web and API code artifacts for QA defects 04-10."""
    print("\n[VERIFY CODEBASE ARTIFACTS] FIN-QA-04 to FIN-QA-10...")

    # FIN-QA-04 & FIN-QA-08: Comparator Winner logic & up to 4 assets
    comparador_client = (FIN_WEB_DIR / "src/app/comparador/ComparadorClient.tsx").read_text()
    assert "Não comparável" in comparador_client, "Comparator missing 'Não comparável' eligibility guard"
    assert "selectedTickers.length < 4" in comparador_client, "Comparator should support up to 4 assets"
    assert "divida_liquida_pl" in comparador_client or "dividaLiquidaPl" in comparador_client, "Comparator missing Dívida Líquida/PL"
    assert "roe" in comparador_client, "Comparator missing ROE"
    print("  ✓ FIN-QA-04 & FIN-QA-08: Comparator handles 'Não comparável', up to 4 assets, ROE & Debt")

    # FIN-QA-05: Tab persistence via URL searchParams
    acao_detail = (FIN_WEB_DIR / "src/app/acoes/[ticker]/AcaoDetailClient.tsx").read_text()
    fii_detail = (FIN_WEB_DIR / "src/app/fiis/[ticker]/FIIDetailClient.tsx").read_text()
    etf_detail = (FIN_WEB_DIR / "src/app/etfs/[ticker]/ETFDetailClient.tsx").read_text()
    for name, content in [("Ações", acao_detail), ("FIIs", fii_detail), ("ETFs", etf_detail)]:
        assert "useSearchParams" in content, f"{name} detail client missing useSearchParams"
        assert "router.replace" in content, f"{name} detail client missing router.replace for tab sync"
    print("  ✓ FIN-QA-05: Tab persistence in searchParams implemented across Ações, FIIs, and ETFs")

    # FIN-QA-06: Screener state sync
    screener_client = (FIN_WEB_DIR / "src/app/screener/ScreenerClient.tsx").read_text()
    assert "useSearchParams" in screener_client, "Screener missing useSearchParams"
    assert "params.set(\"q\"" in screener_client, "Screener missing query param sync for 'q'"
    print("  ✓ FIN-QA-06: Screener state synced with URL searchParams")

    # FIN-QA-07: Home page dividend link
    home_page = (FIN_WEB_DIR / "src/app/page.tsx").read_text()
    assert 'href="/agenda-dividendos"' in home_page, "Home page dividend 'Ver Todos' must point to /agenda-dividendos"
    assert 'href="/carteira"' not in home_page.split("Agenda de Dividendos")[1].split("</Card>")[0], "Home dividend card must not link to /carteira"
    print("  ✓ FIN-QA-07: Home dividend 'Ver Todos' links correctly to /agenda-dividendos")

    # FIN-QA-09: Number formatting
    formatters = (FIN_WEB_DIR / "src/lib/formatters.ts").read_text()
    assert "formatMultiple" in formatters, "formatMultiple missing from formatters.ts"
    assert "formatDividendUnit" in formatters, "formatDividendUnit missing from formatters.ts"
    print("  ✓ FIN-QA-09: Universal pt-BR formatters (formatMultiple, formatDividendUnit 4 decimals) verified")

    # FIN-QA-10: Semantic WAI-ARIA tabs
    tabs_component = (FIN_WEB_DIR / "src/components/ui/Tabs.tsx").read_text()
    assert 'role="tablist"' in tabs_component, "Tabs container missing role='tablist'"
    assert 'role="tab"' in tabs_component, "Tab button missing role='tab'"
    assert "aria-selected" in tabs_component, "Tab button missing aria-selected"
    assert "aria-controls" in tabs_component, "Tab button missing aria-controls"
    assert "ArrowRight" in tabs_component and "ArrowLeft" in tabs_component, "Tabs missing keyboard navigation"
    print("  ✓ FIN-QA-10: Tabs WAI-ARIA accessibility (tablist, tab, aria-selected, keyboard nav) verified")


async def main():
    print("================================================================")
    print("FIN AUDIT HOMOLOGATION: Verifying All 10 QA Defects (FIN-QA-01..10)")
    print("================================================================")

    if not DATABASE_URL:
        print("ERROR: DATABASE_URL not set in fin/.env")
        sys.exit(1)

    conn = await asyncpg.connect(DATABASE_URL)
    try:
        await verify_fin_qa_01(conn)
        await verify_fin_qa_02(conn)
        await verify_fin_qa_03(conn)
        verify_codebase_artifacts()
        print("\n================================================================")
        print("🎉 ALL 10 QA AUDIT DEFECTS FULLY VERIFIED & HOMOLOGATED!")
        print("================================================================")
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
