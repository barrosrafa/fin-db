#!/usr/bin/env python3
"""
Pipeline de Ingestão de Demonstrações Financeiras CVM (DFP / ITR)
Fin Ecosystem - Abastecimento e Povoamento Automático

Fontes:
- CVM Dados Abertos: Demonstrações Financeiras Padronizadas (DFP)
  https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/dfp_cia_aberta_{ANO}.zip
- Cadastro de Companhias Abertas (cad_cia_aberta.csv)
- Formulário Cadastral (fca_cia_aberta_valor_mobiliario_{ANO}.csv)

Alvos:
- raw.ingestion_batch / raw.payload (Auditoria e rastreabilidade com SHA-256)
- core.emissor_companhia / canonical.legal_entity (Mapeamento canônico)
- canonical.financial_statement / canonical.financial_line (Raw canônico padronizado)
- analytics.demonstrativo_financeiro (Normalizado por emissor/ano)
- analytics.indicador_fundamentalista / analytics.indicador_media_setorial (Recálculo derivado)
"""

import os
import sys
import io
import re
import ssl
import csv
import gzip
import json
import uuid
import hashlib
import zipfile
import urllib.request
from datetime import datetime, date
from decimal import Decimal, InvalidOperation
from typing import Dict, List, Tuple, Optional, Any

import psycopg
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("ERRO: DATABASE_URL não encontrada no ambiente (.env).")
    sys.exit(1)

CVM_SOURCE_ID = uuid.UUID("1f65e62f-6b0f-4b7d-8192-804cd63246fb")
CVM_BASE_URL = "https://dados.cvm.gov.br/dados/CIA_ABERTA"
SSL_CTX = ssl._create_unverified_context()

def get_db_connection():
    return psycopg.connect(DATABASE_URL)

def clean_cnpj(raw: str) -> str:
    return re.sub(r"\D", "", raw or "").strip()

def parse_decimal(val: Any) -> Optional[Decimal]:
    if val is None or val == "":
        return None
    try:
        return Decimal(str(val))
    except (InvalidOperation, ValueError):
        return None

def download_bytes(url: str, timeout: int = 120) -> bytes:
    print(f"  [GET] Baixando: {url} ...")
    req = urllib.request.Request(url, headers={"User-Agent": "Fin-Ingestion/2.0 (CVM-Financials)"})
    with urllib.request.urlopen(req, context=SSL_CTX, timeout=timeout) as resp:
        data = resp.read()
    size_mb = len(data) / (1024 * 1024)
    print(f"  [OK] Baixado: {size_mb:.2f} MB")
    return data

def record_raw_payload(conn, url: str, content_bytes: bytes, mime_type: str = "application/zip") -> uuid.UUID:
    content_hash = hashlib.sha256(content_bytes).hexdigest()
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO raw.ingestion_batch (source_id, collector_name, collector_version, status, notes)
            VALUES (%s, %s, %s, 'COMPLETED', %s)
            RETURNING batch_id;
        """, (CVM_SOURCE_ID, "cvm_dfp_collector", "2.0.0", f"Download de {url}"))
        batch_id = cur.fetchone()[0]

        cur.execute("""
            INSERT INTO raw.payload (
                batch_id, source_url, http_status, mime_type, content_sha256, body
            )
            VALUES (%s, %s, 200, %s, %s, %s)
            ON CONFLICT (content_sha256) DO UPDATE
            SET captured_at = CURRENT_TIMESTAMP
            RETURNING payload_id;
        """, (batch_id, url, mime_type, content_hash, content_bytes))
        payload_id = cur.fetchone()[0]
        conn.commit()
    return payload_id

def sync_cvm_companies(conn) -> Dict[str, Tuple[str, str]]:
    """
    Sincroniza todas as companhias abertas da CVM em core.emissor_companhia e canonical.legal_entity.
    Retorna mapa de ticker/prefixo -> (cnpj, segmento_listagem).
    """
    print("\n" + "="*70)
    print("ETAPA 1: Sincronização Canônica de Companhias e Emissores CVM")
    print("="*70)

    # 1. Download cad_cia_aberta.csv
    cad_url = f"{CVM_BASE_URL}/CAD/DADOS/cad_cia_aberta.csv"
    cad_bytes = download_bytes(cad_url)
    record_raw_payload(conn, cad_url, cad_bytes, "text/csv")

    cad_reader = csv.DictReader(io.StringIO(cad_bytes.decode("latin1")), delimiter=";")
    companies = {}
    for r in cad_reader:
        cnpj = clean_cnpj(r.get("CNPJ_CIA", ""))
        if len(cnpj) == 14:
            sit_emissor = r.get("SIT_EMISSOR", "").upper()
            denom = r.get("DENOM_SOCIAL", "").strip()[:150]
            companies[cnpj] = {
                "nome": denom,
                "cvm": r.get("CD_CVM", "").strip()[:10],
                "setor": r.get("SETOR_ATIV", "").strip()[:50],
                "auditor": r.get("AUDITOR", "").strip()[:150],
                "recup_jud": ("RECUPERAÇÃO JUDICIAL" in sit_emissor or "RECUPERAÇÃO JUDICIAL" in denom.upper())
            }

    print(f"Total de companhias CVM carregadas: {len(companies)}")

    # 2. Download FCA 2024 e 2023 para mapear Tickers B3 -> CNPJ
    ticker_to_cnpj: Dict[str, Tuple[str, str]] = {}
    root_to_cnpj: Dict[str, Tuple[str, str]] = {}

    for yr in [2024, 2023]:
        fca_url = f"{CVM_BASE_URL}/DOC/FCA/DADOS/fca_cia_aberta_{yr}.zip"
        try:
            fca_bytes = download_bytes(fca_url)
            zf = zipfile.ZipFile(io.BytesIO(fca_bytes))
            v_name = f"fca_cia_aberta_valor_mobiliario_{yr}.csv"
            if v_name in zf.namelist():
                with zf.open(v_name) as f:
                    rdr = csv.DictReader(io.TextIOWrapper(f, encoding="latin1"), delimiter=";")
                    for row in rdr:
                        t = row.get("Codigo_Negociacao", "").strip().upper()
                        c = clean_cnpj(row.get("CNPJ_Companhia", ""))
                        seg = row.get("Segmento", "").strip()[:50]
                        if t and len(c) == 14 and t != "000000":
                            ticker_to_cnpj[t] = (c, seg)
                            root = t[:4]
                            if root not in root_to_cnpj:
                                root_to_cnpj[root] = (c, seg)
        except Exception as e:
            print(f"  [AVISO] Erro ao carregar FCA {yr}: {e}")

    # Mapeamento manual para casos especiais conhecidos
    root_to_cnpj["BPAC"] = ("30306294000145", "Nível 2")
    ticker_to_cnpj["BPAC11"] = ("30306294000145", "Nível 2")
    ticker_to_cnpj["BPAC3"] = ("30306294000145", "Nível 2")
    ticker_to_cnpj["BPAC5"] = ("30306294000145", "Nível 2")

    print(f"Mapeamento de Tickers B3 -> CNPJ: {len(ticker_to_cnpj)} exatos, {len(root_to_cnpj)} raízes.")

    # 3. Upsert em core.emissor_companhia e canonical.legal_entity
    with conn.cursor() as cur:
        emissor_rows = [
            (cnpj, d["nome"], d["cvm"], d["setor"], d["auditor"], d["recup_jud"])
            for cnpj, d in companies.items()
        ]
        cur.executemany("""
            INSERT INTO core.emissor_companhia (cnpj, nome_empresarial, codigo_cvm, setor, auditor_independente, em_recuperacao_judicial)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (cnpj) DO UPDATE SET
                nome_empresarial = EXCLUDED.nome_empresarial,
                codigo_cvm = COALESCE(EXCLUDED.codigo_cvm, core.emissor_companhia.codigo_cvm),
                setor = COALESCE(EXCLUDED.setor, core.emissor_companhia.setor),
                auditor_independente = COALESCE(EXCLUDED.auditor_independente, core.emissor_companhia.auditor_independente),
                em_recuperacao_judicial = EXCLUDED.em_recuperacao_judicial;
        """, emissor_rows)

        le_rows = [
            (d["nome"], cnpj, cnpj, "BR")
            for cnpj, d in companies.items()
        ]
        cur.executemany("""
            INSERT INTO canonical.legal_entity (legal_entity_id, legal_name, cnpj, tax_id, country_code)
            VALUES (gen_random_uuid(), %s, %s, %s, %s)
            ON CONFLICT (country_code, tax_id) DO UPDATE SET
                legal_name = EXCLUDED.legal_name,
                cnpj = EXCLUDED.cnpj;
        """, le_rows)

        # 4. Vincular core.ativo.id_emissor e canonical.instrument.legal_entity_id
        cur.execute("SELECT cnpj, id_emissor FROM core.emissor_companhia")
        cnpj_to_emissor = {r[0]: r[1] for r in cur.fetchall()}

        cur.execute("SELECT tax_id, legal_entity_id FROM canonical.legal_entity WHERE country_code = 'BR'")
        cnpj_to_le = {r[0]: r[1] for r in cur.fetchall()}

        cur.execute("SELECT id_ativo, ticker, canonical_instrument_id FROM core.ativo WHERE id_emissor IS NULL")
        unlinked = cur.fetchall()

        ativo_up = []
        inst_up = []
        for id_ativo, ticker, inst_id in unlinked:
            t = ticker.upper()
            match = ticker_to_cnpj.get(t) or root_to_cnpj.get(t[:4])
            if match:
                c, seg = match
                eid = cnpj_to_emissor.get(c)
                leid = cnpj_to_le.get(c)
                if eid:
                    ativo_up.append((eid, seg if seg else None, id_ativo))
                    if inst_id and leid:
                        inst_up.append((leid, inst_id))

        if ativo_up:
            cur.execute("CREATE TEMP TABLE tmp_at_up (id_emissor int, seg varchar(50), id_ativo int) ON COMMIT DROP")
            cur.executemany("INSERT INTO tmp_at_up VALUES (%s, %s, %s)", ativo_up)
            cur.execute("""
                UPDATE core.ativo a
                SET id_emissor = t.id_emissor,
                    segmento_listagem = COALESCE(a.segmento_listagem, t.seg)
                FROM tmp_at_up t
                WHERE a.id_ativo = t.id_ativo;
            """)

        if inst_up:
            cur.execute("CREATE TEMP TABLE tmp_in_up (le_id uuid, inst_id uuid) ON COMMIT DROP")
            cur.executemany("INSERT INTO tmp_in_up VALUES (%s, %s)", inst_up)
            cur.execute("""
                UPDATE canonical.instrument i
                SET legal_entity_id = t.le_id
                FROM tmp_in_up t
                WHERE i.instrument_id = t.inst_id;
            """)

        conn.commit()

        cur.execute("SELECT count(*) FROM core.emissor_companhia")
        tot_em = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM core.ativo WHERE id_emissor IS NOT NULL")
        tot_at_linked = cur.fetchone()[0]
        print(f"Total core.emissor_companhia: {tot_em}")
        print(f"Total core.ativo vinculados a emissores: {tot_at_linked}")

    return ticker_to_cnpj

def ingest_cvm_dfp_years(conn, years: List[int]):
    """
    Ingesta anos DFP (Demonstrações Financeiras Padronizadas).
    Popula:
      - canonical.financial_statement
      - canonical.financial_line
      - analytics.demonstrativo_financeiro
    """
    print("\n" + "="*70)
    print(f"ETAPA 2: Ingestão de Demonstrações Financeiras DFP CVM ({years})")
    print("="*70)

    # Buscar mapeamentos canônicos
    with conn.cursor() as cur:
        cur.execute("SELECT tax_id, legal_entity_id FROM canonical.legal_entity WHERE country_code = 'BR'")
        cnpj_to_le = {r[0]: r[1] for r in cur.fetchall()}

        cur.execute("SELECT cnpj, id_emissor FROM core.emissor_companhia")
        cnpj_to_emissor = {r[0]: r[1] for r in cur.fetchall()}

        # Mapa de legal_entity_id -> instrumento principal de capital
        cur.execute("""
            SELECT i.legal_entity_id, i.instrument_id
            FROM canonical.instrument i
            WHERE i.legal_entity_id IS NOT NULL AND i.asset_class = 'EQUITY'
            ORDER BY i.status = 'ACTIVE' DESC
        """)
        le_to_primary_inst = {}
        for le_id, inst_id in cur.fetchall():
            if le_id not in le_to_primary_inst:
                le_to_primary_inst[le_id] = inst_id

    total_statements_upserted = 0
    total_lines_upserted = 0
    total_demonstrativos_upserted = 0

    for yr in sorted(years):
        print(f"\n---> Processando Ano DFP: {yr} <---")
        dfp_url = f"{CVM_BASE_URL}/DOC/DFP/DADOS/dfp_cia_aberta_{yr}.zip"
        try:
            zip_bytes = download_bytes(dfp_url)
        except Exception as e:
            print(f"  [ERRO] Falha ao baixar {dfp_url}: {e}")
            continue

        payload_id = record_raw_payload(conn, dfp_url, zip_bytes, "application/zip")
        zf = zipfile.ZipFile(io.BytesIO(zip_bytes))
        file_list = zf.namelist()

        # 1. Metadados do documento: dfp_cia_aberta_{yr}.csv
        meta_by_cnpj_dt: Dict[Tuple[str, str], Dict[str, Any]] = {}
        meta_fname = f"dfp_cia_aberta_{yr}.csv"
        if meta_fname in file_list:
            with zf.open(meta_fname) as f:
                rdr = csv.DictReader(io.TextIOWrapper(f, encoding="latin1"), delimiter=";")
                for r in rdr:
                    c = clean_cnpj(r.get("CNPJ_CIA", ""))
                    dt = r.get("DT_REFER", "").strip()
                    if c and dt:
                        meta_by_cnpj_dt[(c, dt)] = {
                            "dt_receb": r.get("DT_RECEB", "").strip() or None,
                            "versao": int(r.get("VERSAO", 1) or 1),
                            "id_doc": r.get("ID_DOC", "").strip(),
                        }

        # 2. Composição de Capital: dfp_cia_aberta_composicao_capital_{yr}.csv
        shares_by_cnpj_dt: Dict[Tuple[str, str], int] = {}
        cap_fname = f"dfp_cia_aberta_composicao_capital_{yr}.csv"
        if cap_fname in file_list:
            with zf.open(cap_fname) as f:
                rdr = csv.DictReader(io.TextIOWrapper(f, encoding="latin1"), delimiter=";")
                for r in rdr:
                    c = clean_cnpj(r.get("CNPJ_CIA", ""))
                    dt = r.get("DT_REFER", "").strip()
                    tot = r.get("QT_ACAO_TOTAL_CAP_INTEGR", "").strip()
                    if c and dt and tot:
                        try:
                            shares_by_cnpj_dt[(c, dt)] = int(tot)
                        except ValueError:
                            pass

        # 3. Estruturas para acumular statements e linhas
        # key: (clean_cnpj, dt_refer, statement_type) -> list of line dicts
        statements_data: Dict[Tuple[str, str, str], Dict[str, Any]] = {}
        # key: (clean_cnpj, dt_refer) -> dict of analytical KPIs
        analytics_data: Dict[Tuple[str, str], Dict[str, Any]] = {}

        def get_or_create_analytics(c: str, dt: str):
            key = (c, dt)
            if key not in analytics_data:
                analytics_data[key] = {
                    "receita_liquida": None,
                    "ebit": None,
                    "lucro_liquido": None,
                    "ativo_total": None,
                    "ativo_circulante": None,
                    "disponibilidades": None,
                    "patrimonio_liquido": None,
                    "divida_bruta": Decimal(0),
                    "fco": None,
                    "fci": None,
                    "fcf": None,
                    "depreciacao": Decimal(0),
                    "carteira_credito": None,
                    "depositos": None,
                    "resultado_intermediacao_financeira": None,
                    "receita_servicos": None,
                    "pdd": None,
                    "contas": {},
                }
            return analytics_data[key]

        def scale_val(val_str: str, escala: str) -> Decimal:
            v = Decimal(val_str.strip() or "0")
            if escala.strip().upper() == "MIL":
                return v * 1000
            return v

        # Processar DRE_con (Demonstração do Resultado - INCOME_STATEMENT)
        dre_fname = f"dfp_cia_aberta_DRE_con_{yr}.csv"
        if dre_fname in file_list:
            print(f"  Lendo {dre_fname}...")
            with zf.open(dre_fname) as f:
                rdr = csv.DictReader(io.TextIOWrapper(f, encoding="latin1"), delimiter=";")
                for r in rdr:
                    if r.get("ORDEM_EXERC") != "ÚLTIMO":
                        continue
                    c = clean_cnpj(r.get("CNPJ_CIA", ""))
                    dt = r.get("DT_REFER", "").strip()
                    if not c or not dt or c not in cnpj_to_le:
                        continue
                    
                    cd = r.get("CD_CONTA", "").strip()
                    ds = r.get("DS_CONTA", "").strip()
                    val = scale_val(r.get("VL_CONTA", "0"), r.get("ESCALA_MOEDA", ""))
                    dt_ini = r.get("DT_INI_EXERC", "").strip()
                    dt_fim = r.get("DT_FIM_EXERC", "").strip()

                    stmt_key = (c, dt, "INCOME_STATEMENT")
                    if stmt_key not in statements_data:
                        statements_data[stmt_key] = {
                            "period_start": dt_ini or None,
                            "period_end": dt_fim or dt,
                            "lines": {}
                        }
                    statements_data[stmt_key]["lines"][cd] = (cd, ds, val)

                    # Mapear analítico
                    an = get_or_create_analytics(c, dt)
                    an["contas"][f"DRE_{cd}"] = {"label": ds, "valor": float(val)}

                    if cd in ("3.01", "3.01.01"):
                        if an["receita_liquida"] is None:
                            an["receita_liquida"] = val
                    elif cd == "3.05":
                        an["ebit"] = val
                    elif cd in ("3.11", "3.11.01"):
                        if an["lucro_liquido"] is None or cd == "3.11":
                            an["lucro_liquido"] = val
                    elif cd == "3.01" and "intermediação" in ds.lower():
                        an["resultado_intermediacao_financeira"] = val
                    elif "serviço" in ds.lower() and "prestação" in ds.lower():
                        an["receita_servicos"] = val
                    elif "provisão" in ds.lower() and ("crédito" in ds.lower() or "perda" in ds.lower()):
                        an["pdd"] = val

        # Processar BPA_con (Balanço Patrimonial Ativo - BALANCE_SHEET)
        bpa_fname = f"dfp_cia_aberta_BPA_con_{yr}.csv"
        if bpa_fname in file_list:
            print(f"  Lendo {bpa_fname}...")
            with zf.open(bpa_fname) as f:
                rdr = csv.DictReader(io.TextIOWrapper(f, encoding="latin1"), delimiter=";")
                for r in rdr:
                    if r.get("ORDEM_EXERC") != "ÚLTIMO":
                        continue
                    c = clean_cnpj(r.get("CNPJ_CIA", ""))
                    dt = r.get("DT_REFER", "").strip()
                    if not c or not dt or c not in cnpj_to_le:
                        continue

                    cd = r.get("CD_CONTA", "").strip()
                    ds = r.get("DS_CONTA", "").strip()
                    val = scale_val(r.get("VL_CONTA", "0"), r.get("ESCALA_MOEDA", ""))

                    stmt_key = (c, dt, "BALANCE_SHEET")
                    if stmt_key not in statements_data:
                        statements_data[stmt_key] = {
                            "period_start": None,
                            "period_end": dt,
                            "lines": {}
                        }
                    statements_data[stmt_key]["lines"][cd] = (cd, ds, val)

                    an = get_or_create_analytics(c, dt)
                    an["contas"][f"BPA_{cd}"] = {"label": ds, "valor": float(val)}

                    if cd == "1":
                        an["ativo_total"] = val
                    elif cd == "1.01":
                        an["ativo_circulante"] = val
                    elif cd in ("1.01.01", "1.01.02"):
                        if an["disponibilidades"] is None:
                            an["disponibilidades"] = val
                        else:
                            an["disponibilidades"] += val
                    elif "operações de crédito" in ds.lower():
                        an["carteira_credito"] = val

        # Processar BPP_con (Balanço Patrimonial Passivo - BALANCE_SHEET)
        bpp_fname = f"dfp_cia_aberta_BPP_con_{yr}.csv"
        if bpp_fname in file_list:
            print(f"  Lendo {bpp_fname}...")
            with zf.open(bpp_fname) as f:
                rdr = csv.DictReader(io.TextIOWrapper(f, encoding="latin1"), delimiter=";")
                for r in rdr:
                    if r.get("ORDEM_EXERC") != "ÚLTIMO":
                        continue
                    c = clean_cnpj(r.get("CNPJ_CIA", ""))
                    dt = r.get("DT_REFER", "").strip()
                    if not c or not dt or c not in cnpj_to_le:
                        continue

                    cd = r.get("CD_CONTA", "").strip()
                    ds = r.get("DS_CONTA", "").strip()
                    val = scale_val(r.get("VL_CONTA", "0"), r.get("ESCALA_MOEDA", ""))

                    stmt_key = (c, dt, "BALANCE_SHEET")
                    if stmt_key not in statements_data:
                        statements_data[stmt_key] = {
                            "period_start": None,
                            "period_end": dt,
                            "lines": {}
                        }
                    statements_data[stmt_key]["lines"][cd] = (cd, ds, val)

                    an = get_or_create_analytics(c, dt)
                    an["contas"][f"BPP_{cd}"] = {"label": ds, "valor": float(val)}

                    if cd == "2.03":
                        an["patrimonio_liquido"] = val
                    elif cd in ("2.01.04", "2.02.01"):
                        an["divida_bruta"] += val
                    elif "depósito" in ds.lower() and len(cd) <= 7:
                        an["depositos"] = val

        # Processar DFC_MI_con (Demonstração do Fluxo de Caixa Método Indireto - CASH_FLOW)
        dfc_fname = f"dfp_cia_aberta_DFC_MI_con_{yr}.csv"
        if dfc_fname in file_list:
            print(f"  Lendo {dfc_fname}...")
            with zf.open(dfc_fname) as f:
                rdr = csv.DictReader(io.TextIOWrapper(f, encoding="latin1"), delimiter=";")
                for r in rdr:
                    if r.get("ORDEM_EXERC") != "ÚLTIMO":
                        continue
                    c = clean_cnpj(r.get("CNPJ_CIA", ""))
                    dt = r.get("DT_REFER", "").strip()
                    if not c or not dt or c not in cnpj_to_le:
                        continue

                    cd = r.get("CD_CONTA", "").strip()
                    ds = r.get("DS_CONTA", "").strip()
                    val = scale_val(r.get("VL_CONTA", "0"), r.get("ESCALA_MOEDA", ""))

                    stmt_key = (c, dt, "CASH_FLOW")
                    if stmt_key not in statements_data:
                        statements_data[stmt_key] = {
                            "period_start": None,
                            "period_end": dt,
                            "lines": {}
                        }
                    statements_data[stmt_key]["lines"][cd] = (cd, ds, val)

                    an = get_or_create_analytics(c, dt)
                    an["contas"][f"DFC_{cd}"] = {"label": ds, "valor": float(val)}

                    if cd == "6.01":
                        an["fco"] = val
                    elif cd == "6.02":
                        an["fci"] = val
                    elif cd == "6.03":
                        an["fcf"] = val
                    elif cd.startswith("6.01.01") and any(w in ds.lower() for w in ["deprec", "amortiz", "deple"]):
                        an["depreciacao"] += abs(val)

        # 4. Inserção em Lote no Banco de Dados
        print(f"  Preparando inserção de {len(statements_data)} demonstrativos e analíticos...")

        with conn.cursor() as cur:
            # 4.1 Inserir canonical.financial_statement via Staging Table
            cur.execute("""
                CREATE TEMP TABLE tmp_stmt_in (
                    legal_entity_id uuid,
                    instrument_id uuid,
                    source_id uuid,
                    statement_type text,
                    period_start date,
                    period_end date,
                    filing_date date,
                    currency_code char(3),
                    consolidation text,
                    payload_id uuid,
                    clean_cnpj text
                ) ON COMMIT DROP;
            """)

            stmt_rows = []
            for (c, dt, s_type), s_info in statements_data.items():
                le_id = cnpj_to_le[c]
                inst_id = le_to_primary_inst.get(le_id)
                meta = meta_by_cnpj_dt.get((c, dt), {})
                f_date = meta.get("dt_receb")
                stmt_rows.append((
                    le_id,
                    inst_id,
                    CVM_SOURCE_ID,
                    s_type,
                    s_info["period_start"],
                    s_info["period_end"],
                    f_date,
                    "BRL",
                    "CONSOLIDATED",
                    payload_id,
                    c
                ))

            cur.executemany("""
                INSERT INTO tmp_stmt_in VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, stmt_rows)

            cur.execute("""
                INSERT INTO canonical.financial_statement (
                    statement_id, legal_entity_id, instrument_id, source_id, statement_type,
                    period_start, period_end, filing_date, currency_code, consolidation, payload_id
                )
                SELECT
                    gen_random_uuid(), legal_entity_id, instrument_id, source_id, statement_type,
                    period_start, period_end, filing_date, currency_code, consolidation, payload_id
                FROM tmp_stmt_in
                ON CONFLICT (legal_entity_id, instrument_id, statement_type, period_end, consolidation, source_id)
                DO UPDATE SET
                    filing_date = COALESCE(EXCLUDED.filing_date, canonical.financial_statement.filing_date),
                    payload_id = EXCLUDED.payload_id;
            """)

            # Mapear statement_id gerados
            cur.execute("""
                SELECT statement_id, legal_entity_id, statement_type, period_end
                FROM canonical.financial_statement
                WHERE source_id = %s AND consolidation = 'CONSOLIDATED'
            """, (CVM_SOURCE_ID,))
            stmt_id_map = {
                (r[1], r[2], str(r[3])): r[0]
                for r in cur.fetchall()
            }

            total_statements_upserted += len(stmt_rows)

            # 4.2 Inserir canonical.financial_line em Lote
            line_rows = []
            for (c, dt, s_type), s_info in statements_data.items():
                le_id = cnpj_to_le[c]
                stmt_id = stmt_id_map.get((le_id, s_type, s_info["period_end"]))
                if not stmt_id:
                    continue
                for cd, ds, val in s_info["lines"].values():
                    line_rows.append((
                        stmt_id,
                        cd,
                        ds[:255],
                        val,
                        "BRL",
                        f"CVM DFP {yr}"
                    ))

            if line_rows:
                cur.execute("""
                    CREATE TEMP TABLE tmp_line_in (
                        statement_id uuid,
                        line_code text,
                        line_label text,
                        value_numeric numeric,
                        unit text,
                        source_label text
                    ) ON COMMIT DROP;
                """)
                cur.executemany("""
                    INSERT INTO tmp_line_in VALUES (%s, %s, %s, %s, %s, %s)
                """, line_rows)

                cur.execute("""
                    INSERT INTO canonical.financial_line (
                        statement_id, line_code, line_label, value_numeric, unit, source_label
                    )
                    SELECT statement_id, line_code, line_label, value_numeric, unit, source_label
                    FROM tmp_line_in
                    ON CONFLICT (statement_id, line_code)
                    DO UPDATE SET
                        value_numeric = EXCLUDED.value_numeric,
                        line_label = EXCLUDED.line_label;
                """)
                total_lines_upserted += len(line_rows)

            # 4.3 Inserir analytics.demonstrativo_financeiro
            demonstrativo_rows = []
            for (c, dt), an in analytics_data.items():
                emissor_id = cnpj_to_emissor.get(c)
                if not emissor_id:
                    continue

                meta = meta_by_cnpj_dt.get((c, dt), {})
                pub_date = meta.get("dt_receb")
                versao = meta.get("versao", 1)
                num_acoes = shares_by_cnpj_dt.get((c, dt))

                rec_liq = an["receita_liquida"]
                ebit = an["ebit"]
                lucro_liq = an["lucro_liquido"]
                patr_liq = an["patrimonio_liquido"]
                at_tot = an["ativo_total"]
                at_circ = an["ativo_circulante"]
                disp = an["disponibilidades"]
                div_bruta = an["divida_bruta"] if an["divida_bruta"] > 0 else None
                div_liq = (div_bruta - disp) if (div_bruta is not None and disp is not None) else None
                fco = an["fco"]
                fci = an["fci"]
                fcf = an["fcf"]
                fcl = (fco + fci) if (fco is not None and fci is not None) else None
                deprec = an["depreciacao"] if an["depreciacao"] > 0 else None
                ebitda = (ebit + deprec) if (ebit is not None and deprec is not None) else ebit

                demonstrativo_rows.append((
                    emissor_id,
                    dt,
                    pub_date,
                    "DFP",
                    versao,
                    json.dumps(an["contas"]),
                    num_acoes,
                    rec_liq,
                    ebitda,
                    lucro_liq,
                    patr_liq,
                    div_bruta,
                    div_liq,
                    ebit,
                    at_tot,
                    at_circ,
                    disp,
                    fco,
                    fci,
                    fcf,
                    fcl,
                    deprec,
                    an["carteira_credito"],
                    an["depositos"],
                    an["resultado_intermediacao_financeira"],
                    an["receita_servicos"],
                    an["pdd"]
                ))

            if demonstrativo_rows:
                cur.execute("""
                    CREATE TEMP TABLE tmp_dem_in (
                        id_emissor int,
                        data_referencia date,
                        data_publicacao date,
                        tipo_documento varchar(10),
                        versao int,
                        contas_detalhadas jsonb,
                        numero_acoes bigint,
                        receita_liquida numeric(18,2),
                        ebitda numeric(18,2),
                        lucro_liquido numeric(18,2),
                        patrimonio_liquido numeric(18,2),
                        divida_bruta numeric(18,2),
                        divida_liquida numeric(18,2),
                        ebit numeric(18,2),
                        ativo_total numeric(18,2),
                        ativo_circulante numeric(18,2),
                        disponibilidades numeric(18,2),
                        fluxo_caixa_operacional numeric(18,2),
                        fluxo_caixa_investimento numeric(18,2),
                        fluxo_caixa_financiamento numeric(18,2),
                        fluxo_caixa_livre numeric(18,2),
                        depreciacao_amortizacao numeric(18,2),
                        carteira_credito numeric(18,2),
                        depositos numeric(18,2),
                        resultado_intermediacao_financeira numeric(18,2),
                        receita_servicos numeric(18,2),
                        pdd numeric(18,2)
                    ) ON COMMIT DROP;
                """)
                cur.executemany("""
                    INSERT INTO tmp_dem_in VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                    )
                """, demonstrativo_rows)

                cur.execute("""
                    INSERT INTO analytics.demonstrativo_financeiro (
                        id_emissor, data_referencia, data_publicacao, tipo_documento, versao,
                        contas_detalhadas, numero_acoes, receita_liquida, ebitda, lucro_liquido,
                        patrimonio_liquido, divida_bruta, divida_liquida, ebit, ativo_total,
                        ativo_circulante, disponibilidades, fluxo_caixa_operacional,
                        fluxo_caixa_investimento, fluxo_caixa_financiamento, fluxo_caixa_livre,
                        depreciacao_amortizacao, carteira_credito, depositos,
                        resultado_intermediacao_financeira, receita_servicos, pdd
                    )
                    SELECT
                        id_emissor, data_referencia, data_publicacao, tipo_documento, versao,
                        contas_detalhadas, numero_acoes, receita_liquida, ebitda, lucro_liquido,
                        patrimonio_liquido, divida_bruta, divida_liquida, ebit, ativo_total,
                        ativo_circulante, disponibilidades, fluxo_caixa_operacional,
                        fluxo_caixa_investimento, fluxo_caixa_financiamento, fluxo_caixa_livre,
                        depreciacao_amortizacao, carteira_credito, depositos,
                        resultado_intermediacao_financeira, receita_servicos, pdd
                    FROM tmp_dem_in
                    ON CONFLICT (id_emissor, data_referencia, tipo_documento, versao)
                    DO UPDATE SET
                        data_publicacao = EXCLUDED.data_publicacao,
                        contas_detalhadas = EXCLUDED.contas_detalhadas,
                        numero_acoes = COALESCE(EXCLUDED.numero_acoes, analytics.demonstrativo_financeiro.numero_acoes),
                        receita_liquida = EXCLUDED.receita_liquida,
                        ebitda = EXCLUDED.ebitda,
                        lucro_liquido = EXCLUDED.lucro_liquido,
                        patrimonio_liquido = EXCLUDED.patrimonio_liquido,
                        divida_bruta = EXCLUDED.divida_bruta,
                        divida_liquida = EXCLUDED.divida_liquida,
                        ebit = EXCLUDED.ebit,
                        ativo_total = EXCLUDED.ativo_total,
                        ativo_circulante = EXCLUDED.ativo_circulante,
                        disponibilidades = EXCLUDED.disponibilidades,
                        fluxo_caixa_operacional = EXCLUDED.fluxo_caixa_operacional,
                        fluxo_caixa_investimento = EXCLUDED.fluxo_caixa_investimento,
                        fluxo_caixa_financiamento = EXCLUDED.fluxo_caixa_financiamento,
                        fluxo_caixa_livre = EXCLUDED.fluxo_caixa_livre,
                        depreciacao_amortizacao = EXCLUDED.depreciacao_amortizacao,
                        carteira_credito = EXCLUDED.carteira_credito,
                        depositos = EXCLUDED.depositos,
                        resultado_intermediacao_financeira = EXCLUDED.resultado_intermediacao_financeira,
                        receita_servicos = EXCLUDED.receita_servicos,
                        pdd = EXCLUDED.pdd;
                """)
                total_demonstrativos_upserted += len(demonstrativo_rows)

            conn.commit()
            print(f"  [OK] Ano {yr}: {len(stmt_rows)} statements, {len(line_rows)} linhas, {len(demonstrativo_rows)} demonstrativos gravados.")

    print("\n" + "="*70)
    print("TOTAL GERAL DFP INGESTADO COM SUCESSO:")
    print(f"  - Canonical Statements: {total_statements_upserted}")
    print(f"  - Canonical Lines: {total_lines_upserted}")
    print(f"  - Analytics Demonstrativos: {total_demonstrativos_upserted}")
    print("="*70)

def recalculate_fundamental_analytics(conn):
    """
    Recalcula e atualiza:
      - analytics.indicador_fundamentalista
      - analytics.indicador_media_setorial
    a partir das cotações diárias reais e das demonstrações financeiras oficiais.
    """
    print("\n" + "="*70)
    print("ETAPA 3: Recálculo de Indicadores Fundamentalistas e Médias Setoriais")
    print("="*70)

    with conn.cursor() as cur:
        # Remover dados mock antigos de Petrobras com tipo_documento IS NULL
        cur.execute("DELETE FROM analytics.demonstrativo_financeiro WHERE tipo_documento IS NULL")
        deleted_mocks = cur.rowcount
        if deleted_mocks > 0:
            print(f"Removidas {deleted_mocks} linhas de demonstrações mock antigas.")

        # Recalcular analytics.indicador_fundamentalista para todos os ativos com emissor e demonstrativo
        print("Recalculando indicadores fundamentalistas a partir dos dados CVM mais recentes...")
        cur.execute("""
            WITH latest_demonstrativo AS (
                SELECT DISTINCT ON (id_emissor)
                    id_emissor,
                    data_referencia,
                    receita_liquida,
                    ebitda,
                    ebit,
                    lucro_liquido,
                    patrimonio_liquido,
                    divida_liquida,
                    divida_bruta,
                    numero_acoes,
                    ativo_total,
                    ativo_circulante,
                    disponibilidades,
                    fluxo_caixa_operacional,
                    fluxo_caixa_livre
                FROM analytics.demonstrativo_financeiro
                WHERE tipo_documento = 'DFP'
                ORDER BY id_emissor, data_referencia DESC, versao DESC
            ),
            latest_quote AS (
                SELECT DISTINCT ON (id_ativo)
                    id_ativo,
                    data_pregao,
                    preco_fechamento
                FROM market.cotacao_diaria
                ORDER BY id_ativo, data_pregao DESC
            )
            INSERT INTO analytics.indicador_fundamentalista (
                id_ativo, data_referencia, pl, pvp, psr, roe, roic, ebitda_margem,
                margem_liquida, margem_ebit, divida_liquida_ebitda, lpa, vpa,
                valor_mercado, enterprise_value, fco_por_acao, fcl_por_acao
            )
            SELECT
                a.id_ativo,
                q.data_pregao AS data_referencia,
                -- P/L
                CASE WHEN d.numero_acoes > 0 AND d.lucro_liquido != 0
                     THEN ROUND(q.preco_fechamento / (d.lucro_liquido / d.numero_acoes), 4)
                     ELSE NULL END AS pl,
                -- P/VP
                CASE WHEN d.numero_acoes > 0 AND d.patrimonio_liquido > 0
                     THEN ROUND(q.preco_fechamento / (d.patrimonio_liquido / d.numero_acoes), 4)
                     ELSE NULL END AS pvp,
                -- PSR
                CASE WHEN d.receita_liquida > 0 AND d.numero_acoes > 0
                     THEN ROUND((q.preco_fechamento * d.numero_acoes) / d.receita_liquida, 4)
                     ELSE NULL END AS psr,
                -- ROE (%)
                CASE WHEN d.patrimonio_liquido > 0
                     THEN ROUND((d.lucro_liquido / d.patrimonio_liquido) * 100, 4)
                     ELSE NULL END AS roe,
                -- ROIC (%)
                CASE WHEN (d.patrimonio_liquido + COALESCE(d.divida_liquida, 0)) > 0
                     THEN ROUND(((d.ebit * 0.66) / (d.patrimonio_liquido + COALESCE(d.divida_liquida, 0))) * 100, 4)
                     ELSE NULL END AS roic,
                -- Margem EBITDA (%)
                CASE WHEN d.receita_liquida > 0
                     THEN ROUND((d.ebitda / d.receita_liquida) * 100, 4)
                     ELSE NULL END AS ebitda_margem,
                -- Margem Líquida (%)
                CASE WHEN d.receita_liquida > 0
                     THEN ROUND((d.lucro_liquido / d.receita_liquida) * 100, 4)
                     ELSE NULL END AS margem_liquida,
                -- Margem EBIT (%)
                CASE WHEN d.receita_liquida > 0
                     THEN ROUND((d.ebit / d.receita_liquida) * 100, 4)
                     ELSE NULL END AS margem_ebit,
                -- Dívida Líquida / EBITDA
                CASE WHEN d.ebitda > 0
                     THEN ROUND(d.divida_liquida / d.ebitda, 4)
                     ELSE NULL END AS divida_liquida_ebitda,
                -- LPA
                CASE WHEN d.numero_acoes > 0
                     THEN ROUND(d.lucro_liquido / d.numero_acoes, 4)
                     ELSE NULL END AS lpa,
                -- VPA
                CASE WHEN d.numero_acoes > 0
                     THEN ROUND(d.patrimonio_liquido / d.numero_acoes, 4)
                     ELSE NULL END AS vpa,
                -- Valor de Mercado
                CASE WHEN d.numero_acoes > 0
                     THEN ROUND(q.preco_fechamento * d.numero_acoes, 2)
                     ELSE NULL END AS valor_mercado,
                -- Enterprise Value
                CASE WHEN d.numero_acoes > 0
                     THEN ROUND((q.preco_fechamento * d.numero_acoes) + COALESCE(d.divida_liquida, 0), 2)
                     ELSE NULL END AS enterprise_value,
                -- FCO por ação
                CASE WHEN d.numero_acoes > 0 AND d.fluxo_caixa_operacional IS NOT NULL
                     THEN ROUND(d.fluxo_caixa_operacional / d.numero_acoes, 4)
                     ELSE NULL END AS fco_por_acao,
                -- FCL por ação
                CASE WHEN d.numero_acoes > 0 AND d.fluxo_caixa_livre IS NOT NULL
                     THEN ROUND(d.fluxo_caixa_livre / d.numero_acoes, 4)
                     ELSE NULL END AS fcl_por_acao
            FROM core.ativo a
            JOIN latest_demonstrativo d ON d.id_emissor = a.id_emissor
            JOIN latest_quote q ON q.id_ativo = a.id_ativo
            ON CONFLICT (id_ativo, data_referencia)
            DO UPDATE SET
                pl = EXCLUDED.pl,
                pvp = EXCLUDED.pvp,
                psr = EXCLUDED.psr,
                roe = EXCLUDED.roe,
                roic = EXCLUDED.roic,
                ebitda_margem = EXCLUDED.ebitda_margem,
                margem_liquida = EXCLUDED.margem_liquida,
                margem_ebit = EXCLUDED.margem_ebit,
                divida_liquida_ebitda = EXCLUDED.divida_liquida_ebitda,
                lpa = EXCLUDED.lpa,
                vpa = EXCLUDED.vpa,
                valor_mercado = EXCLUDED.valor_mercado,
                enterprise_value = EXCLUDED.enterprise_value,
                fco_por_acao = EXCLUDED.fco_por_acao,
                fcl_por_acao = EXCLUDED.fcl_por_acao;
        """)
        updated_ind = cur.rowcount
        print(f"Indicadores fundamentalistas calculados/atualizados: {updated_ind}")

        # Recalcular médias setoriais: analytics.indicador_media_setorial
        print("Calculando médias e medianas setoriais em analytics.indicador_media_setorial...")
        cur.execute("""
            DELETE FROM analytics.indicador_media_setorial WHERE fonte = 'CVM/B3 Calculado';
        """)

        metrics_to_agg = [
            ('PL', 'pl'),
            ('PVP', 'pvp'),
            ('ROE', 'roe'),
            ('ROIC', 'roic'),
            ('MARGEM_LIQUIDA', 'margem_liquida'),
            ('DIVIDA_LIQUIDA_EBITDA', 'divida_liquida_ebitda')
        ]

        for code, col in metrics_to_agg:
            cur.execute(f"""
                INSERT INTO analytics.indicador_media_setorial (
                    nivel_agregacao, nome_agregacao, data_referencia, codigo_indicador,
                    valor_medio, valor_mediano, quantidade_ativos, fonte
                )
                SELECT
                    'SETOR' AS nivel_agregacao,
                    COALESCE(e.setor, 'Geral') AS nome_agregacao,
                    CURRENT_DATE AS data_referencia,
                    %s AS codigo_indicador,
                    ROUND(AVG(i.{col})::numeric, 4) AS valor_medio,
                    ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY i.{col})::numeric, 4) AS valor_mediano,
                    COUNT(i.{col}) AS quantidade_ativos,
                    'CVM/B3 Calculado' AS fonte
                FROM analytics.indicador_fundamentalista i
                JOIN core.ativo a ON a.id_ativo = i.id_ativo
                JOIN core.emissor_companhia e ON e.id_emissor = a.id_emissor
                WHERE i.{col} IS NOT NULL AND i.{col} BETWEEN -500 AND 500
                GROUP BY e.setor
                HAVING COUNT(i.{col}) >= 2
                ON CONFLICT (nivel_agregacao, nome_agregacao, data_referencia, codigo_indicador)
                DO UPDATE SET
                    valor_medio = EXCLUDED.valor_medio,
                    valor_mediano = EXCLUDED.valor_mediano,
                    quantidade_ativos = EXCLUDED.quantidade_ativos;
            """, (code,))

        conn.commit()
        cur.execute("SELECT count(*) FROM analytics.indicador_media_setorial")
        tot_setor = cur.fetchone()[0]
        print(f"Total de registros de médias setoriais gerados: {tot_setor}")

def main():
    start_time = datetime.now()
    print("="*70)
    print("INICIANDO PIPELINE DE DEMONSTRAÇÕES FINANCEIRAS CVM (DFP)")
    print(f"Timestamp: {start_time.isoformat()}")
    print("="*70)

    years = [2021, 2022, 2023, 2024]
    if len(sys.argv) > 1:
        years = [int(y) for y in sys.argv[1].split(",")]

    conn = get_db_connection()
    try:
        # Etapa 1: Sincronização Canônica
        sync_cvm_companies(conn)

        # Etapa 2: Ingestão DFP CVM
        ingest_cvm_dfp_years(conn, years)

        # Etapa 3: Recálculo Analítico
        recalculate_fundamental_analytics(conn)

        # Atualizar busca de ativos
        with conn.cursor() as cur:
            cur.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.busca_ativo;")
            conn.commit()
            print("Materialized view analytics.busca_ativo atualizada com sucesso.")

    finally:
        conn.close()

    elapsed = datetime.now() - start_time
    print("\n" + "="*70)
    print(f"PIPELINE CVM FINALIZADO COM SUCESSO! Duração: {elapsed}")
    print("="*70)

if __name__ == "__main__":
    main()
