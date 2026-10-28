"""
Seeds a rich set of official CVM/B3 disclosure documents into canonical.disclosure_document
covering Fatos Relevantes, Comunicados ao Mercado, ITR/Resultados, and Relatórios Gerenciais.
"""
import asyncio
import uuid
import datetime
from sqlalchemy import text
from app.core.database import get_session_factory

DOCUMENTS_SEED = [
    # PETR4
    ("PETR4", "Fato Relevante", "Descoberta de acumulação de petróleo de excelente qualidade na Bacia de Santos", "2026-09-15", "https://ri.petrobras.com.br/cvm/fato-relevante-bacia-santos-2026.pdf", "CVM-FR-2026-0915-01", "Descoberta comprova potencial produtivo adicional no cluster do Pré-Sal.", "POSITIVO"),
    ("PETR4", "Demonstrações ITR", "Informações Trimestrais — ITR 2T2026 Auditadas", "2026-08-08", "https://ri.petrobras.com.br/cvm/itr-2t2026-petrobras.pdf", "CVM-ITR-2026-0808-01", "Lucro líquido de R$ 28,7 bilhões e fluxo de caixa livre de R$ 34,2 bilhões no trimestre.", "POSITIVO"),
    ("PETR4", "Comunicado ao Mercado", "Esclarecimento sobre notícias veiculadas na mídia acerca do plano de investimentos", "2026-10-10", "https://ri.petrobras.com.br/cvm/comunicado-esclarecimento-plano.pdf", "CVM-COM-2026-1010-01", "Companhia esclarece que premissas do Plano Estratégico 2026-2030 seguem rigor de governança.", "NEUTRO"),
    
    # VALE3
    ("VALE3", "Fato Relevante", "Conclusão de acordo definitivo para reparação e desenvolvimento sustentável", "2026-10-25", "https://vale.com/cvm/fato-relevante-acordo-reparacao-definitivo.pdf", "CVM-FR-2026-1025-01", "Acordo estabelece cronograma plurianual definitivo de desembolsos, eliminando incertezas judiciais.", "POSITIVO"),
    ("VALE3", "Demonstrações ITR", "Relatório de Produção e Vendas 3T2026", "2026-10-18", "https://vale.com/cvm/relatorio-producao-vendas-3t26.pdf", "CVM-ITR-2026-1018-01", "Produção de minério de ferro atingiu 91,0 Mt no 3T26, crescimento de 5,5% a/a.", "POSITIVO"),
    ("VALE3", "Comunicado ao Mercado", "Pagamento de Juros sobre o Capital Próprio aos Acionistas", "2026-09-02", "https://vale.com/cvm/aviso-jcp-setembro-2026.pdf", "CVM-COM-2026-0902-01", "Conselho de Administração aprova distribuição de R$ 2,15 por ação em JCP.", "POSITIVO"),

    # ITUB4
    ("ITUB4", "Demonstrações ITR", "Divulgação de Resultados do 2T2026 — DFP / ITR", "2026-08-06", "https://www.itau.com.br/relacoes-com-investidores/download/itr-2t26.pdf", "CVM-ITR-2026-0806-01", "Lucro líquido recorrente gerencial de R$ 10,1 bilhões, com ROE de 22,4%.", "POSITIVO"),
    ("ITUB4", "Comunicado ao Mercado", "Programa de Recompra de Ações Ordinárias e Preferenciais", "2026-08-25", "https://www.itau.com.br/relacoes-com-investidores/download/recompra-acoes-2026.pdf", "CVM-COM-2026-0825-01", "Aprovada renovação do programa de recompra de até 75 milhões de ações PN.", "POSITIVO"),

    # BBAS3
    ("BBAS3", "Demonstrações ITR", "Apresentação de Resultados do 2T2026", "2026-08-07", "https://ri.bb.com.br/download/itr-2t26-apresentacao.pdf", "CVM-ITR-2026-0807-01", "Carteira de crédito ampliada alcança R$ 1,18 trilhão, com forte expansão no Agronegócio.", "POSITIVO"),
    ("BBAS3", "Fato Relevante", "Eleição de Novos Membros do Conselho de Administração e Comitês Estatutários", "2026-07-30", "https://ri.bb.com.br/download/fr-eleicao-conselho-2026.pdf", "CVM-FR-2026-0730-01", "Assembleia Geral aprova composição do colegiado para mandato 2026-2028.", "NEUTRO"),

    # WEGE3
    ("WEGE3", "Fato Relevante", "Aquisição estratégica de fabricante internacional de transformadores elétricos", "2026-09-22", "https://ri.weg.net/cvm/fato-relevante-aquisicao-transformadores-2026.pdf", "CVM-FR-2026-0922-01", "WEG consolida liderança na cadeia de geração e distribuição de energia na América do Norte.", "POSITIVO"),
    ("WEGE3", "Demonstrações ITR", "Divulgação de Informações Trimestrais — 2T2026", "2026-07-28", "https://ri.weg.net/cvm/itr-2t2026-weg.pdf", "CVM-ITR-2026-0728-01", "Receita líquida consolidada de R$ 9,27 bilhões (+13,8% a/a) e margem EBITDA de 22,1%.", "POSITIVO"),

    # MXRF11
    ("MXRF11", "Relatório Gerencial", "Relatório Gerencial Mensal — Carteira de CRIs e FIIs Setembro 2026", "2026-10-05", "https://fnet.bmfbovespa.com.br/fnet/publico/visualizarDocumento?id=mxrf11-rg-0926", "B3-RG-2026-1005-01", "Taxa média ponderada da carteira de CRIs em IPCA + 8,45% e CDI + 2,65% com 100% de adimplência.", "POSITIVO"),
    ("MXRF11", "Aviso aos Cotistas", "Aviso aos Cotistas: Rendimentos referentes a Setembro de 2026", "2026-09-30", "https://fnet.bmfbovespa.com.br/fnet/publico/visualizarDocumento?id=mxrf11-aviso-0926", "B3-AV-2026-0930-01", "Distribuição de R$ 0,10 por cota aos titulares com base na posição de 30/09/2026.", "POSITIVO"),

    # HGLG11
    ("HGLG11", "Relatório Gerencial", "Relatório de Gestão e Desempenho Operacional — Setembro 2026", "2026-10-06", "https://fnet.bmfbovespa.com.br/fnet/publico/visualizarDocumento?id=hglg11-rg-0926", "B3-RG-2026-1006-01", "Vacância física reduzida para 5,2% após nova locação no Parque Logístico Betim.", "POSITIVO"),
    ("HGLG11", "Fato Relevante", "Assinatura de Memorando de Entendimentos para Expansão de Ativo Logístico em Itupeva", "2026-08-14", "https://fnet.bmfbovespa.com.br/fnet/publico/visualizarDocumento?id=hglg11-fr-0826", "B3-FR-2026-0814-01", "Expansão de 32.000 m² de ABL com contrato atípico pré-locado por 10 anos.", "POSITIVO"),

    # BOVA11 & IVVB11
    ("BOVA11", "Aviso aos Cotistas", "Informativo Mensal de Composição e Rebalanceamento do Índice Ibovespa", "2026-09-01", "https://www.blackrock.com/br/literature/etf-monthly/bova11-rebalanceamento-set-2026.pdf", "B3-AV-2026-0901-01", "Atualização da carteira teórica de ativos do fundo BOVA11.", "NEUTRO"),
    ("IVVB11", "Aviso aos Cotistas", "Demonstrativo Semestral de Despesas e Total Expense Ratio (TER)", "2026-07-15", "https://www.blackrock.com/br/literature/etf-monthly/ivvb11-ter-report-2026.pdf", "B3-AV-2026-0715-01", "Taxa total de administração confirmada em 0,23% a.a., sem taxa de performance.", "NEUTRO"),
]

async def seed_disclosures():
    session_factory = get_session_factory()
    async with session_factory() as session:
        source_id = "1f65e62f-6b0f-4b7d-8192-804cd63246fb"
        print(f"Using source_id: {source_id}")

        inserted_count = 0
        for ticker, doc_type, title, doc_date_str, source_url, ext_id, summary, sentiment in DOCUMENTS_SEED:
            # Get canonical_instrument_id
            inst_res = await session.execute(
                text("SELECT canonical_instrument_id FROM core.ativo WHERE ticker = :ticker LIMIT 1;"),
                {"ticker": ticker}
            )
            instrument_id = inst_res.scalar_one_or_none()
            if not instrument_id:
                print(f"Warning: instrument_id not found for {ticker}")
                continue

            doc_id = str(uuid.uuid4())
            doc_date = datetime.datetime.strptime(doc_date_str, "%Y-%m-%d").date()
            published_at = datetime.datetime.combine(doc_date, datetime.time(9, 30))

            stmt = text("""
            INSERT INTO canonical.disclosure_document (
                document_id, source_id, instrument_id, document_type, title,
                document_date, source_url, external_id, ai_summary, ai_sentiment, published_at
            )
            VALUES (
                :doc_id, :source_id, :instrument_id, :doc_type, :title,
                :doc_date, :source_url, :ext_id, :summary, :sentiment, :published_at
            )
            ON CONFLICT (document_id) DO NOTHING;
            """)
            await session.execute(stmt, {
                "doc_id": doc_id,
                "source_id": source_id,
                "instrument_id": instrument_id,
                "doc_type": doc_type,
                "title": title,
                "doc_date": doc_date,
                "source_url": source_url,
                "ext_id": ext_id,
                "summary": summary,
                "sentiment": sentiment,
                "published_at": published_at,
            })
            inserted_count += 1

        await session.commit()
        print(f"Seeded {inserted_count} official disclosure documents successfully.")

if __name__ == "__main__":
    asyncio.run(seed_disclosures())
