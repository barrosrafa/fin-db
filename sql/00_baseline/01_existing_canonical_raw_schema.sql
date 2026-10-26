-- =========================================================
-- EXISTING SCHEMA: canonical, raw, analytics, public
-- Dumped from Neon DB (sparkling-glade-58085855)
-- =========================================================

CREATE SCHEMA IF NOT EXISTS canonical;
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS analytics;

-- 1. ENUMS
DO $$ BEGIN
    CREATE TYPE canonical.asset_class AS ENUM ('EQUITY', 'FII', 'FIAGRO', 'FI_INFRA', 'FUND', 'ETF', 'BDR', 'REIT', 'OPTION', 'GOVERNMENT_BOND', 'FIXED_INCOME', 'CRYPTO', 'INDEX', 'FUTURE', 'OTHER');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE canonical.event_kind AS ENUM ('DIVIDEND', 'JCP', 'RENT', 'AMORTIZATION', 'BONUS', 'SPLIT', 'REVERSE_SPLIT', 'SUBSCRIPTION', 'RIGHTS', 'TENDER', 'OTHER');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE canonical.source_kind AS ENUM ('B3', 'CVM', 'FNET', 'TESOURO', 'SEC', 'EXCHANGE', 'ISSUER_RI', 'PLATFORM', 'DATA_VENDOR', 'USER_PROVIDED', 'OTHER');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------
-- Table: analytics.ranking_item
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.ranking_item (
    ranking_id                uuid NOT NULL,
    instrument_id             uuid NOT NULL,
    rank                      integer NOT NULL,
    score                     numeric(38,16),
    metric_code               text,
    metric_value              numeric(38,16),
    CONSTRAINT ranking_item_ranking_id_rank_key UNIQUE (ranking_id, rank),
    CONSTRAINT ranking_item_pkey PRIMARY KEY (ranking_id, instrument_id),
    CONSTRAINT ranking_item_rank_check CHECK ((rank > 0))
);

-- ---------------------------------------------------------
-- Table: analytics.ranking_snapshot
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.ranking_snapshot (
    ranking_id                uuid NOT NULL DEFAULT gen_random_uuid(),
    ranking_name              text NOT NULL,
    methodology_version       text NOT NULL,
    as_of_date                date NOT NULL,
    asset_class               canonical.asset_class,
    filters                   jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at                timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT ranking_snapshot_ranking_name_methodology_version_as_of_dat_key UNIQUE (ranking_name, methodology_version, as_of_date, asset_class),
    CONSTRAINT ranking_snapshot_pkey PRIMARY KEY (ranking_id)
);

-- ---------------------------------------------------------
-- Table: canonical.corporate_event
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.corporate_event (
    event_id                  uuid NOT NULL DEFAULT gen_random_uuid(),
    instrument_id             uuid NOT NULL,
    source_id                 uuid NOT NULL,
    event_kind                canonical.event_kind NOT NULL,
    announcement_date         date,
    record_date               date,
    ex_date                   date,
    payment_date              date,
    reference_period          text,
    amount_per_unit           numeric(24,10),
    currency_code             character(3),
    ratio                     numeric(24,10),
    notes                     text,
    observed_at               timestamp with time zone NOT NULL DEFAULT now(),
    payload_id                uuid,
    CONSTRAINT corporate_event_instrument_id_event_kind_ex_date_payment_da_key UNIQUE (instrument_id, event_kind, ex_date, payment_date, amount_per_unit, source_id),
    CONSTRAINT corporate_event_pkey PRIMARY KEY (event_id)
);

-- ---------------------------------------------------------
-- Table: canonical.currency
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.currency (
    currency_code             character(3) NOT NULL,
    name                      text NOT NULL,
    minor_digits              smallint NOT NULL DEFAULT 2,
    CONSTRAINT currency_pkey PRIMARY KEY (currency_code),
    CONSTRAINT currency_minor_digits_check CHECK (((minor_digits >= 0) AND (minor_digits <= 8)))
);

-- ---------------------------------------------------------
-- Table: canonical.disclosure_document
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.disclosure_document (
    document_id               uuid NOT NULL DEFAULT gen_random_uuid(),
    source_id                 uuid NOT NULL,
    instrument_id             uuid,
    legal_entity_id           uuid,
    document_type             text NOT NULL,
    title                     text,
    document_date             date,
    reference_period          text,
    source_url                text NOT NULL,
    external_id               text,
    mime_type                 text,
    content_sha256            text,
    payload_id                uuid,
    published_at              timestamp with time zone,
    retrieved_at              timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT disclosure_document_source_id_external_id_key UNIQUE (source_id, external_id),
    CONSTRAINT disclosure_document_source_id_source_url_document_date_key UNIQUE (source_id, source_url, document_date),
    CONSTRAINT disclosure_document_pkey PRIMARY KEY (document_id)
);

-- ---------------------------------------------------------
-- Table: canonical.financial_line
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.financial_line (
    statement_id              uuid NOT NULL,
    line_code                 text NOT NULL,
    line_label                text NOT NULL,
    value_numeric             numeric(38,8),
    unit                      text NOT NULL DEFAULT 'BRL'::text,
    source_label              text,
    CONSTRAINT financial_line_pkey PRIMARY KEY (statement_id, line_code)
);

-- ---------------------------------------------------------
-- Table: canonical.financial_statement
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.financial_statement (
    statement_id              uuid NOT NULL DEFAULT gen_random_uuid(),
    legal_entity_id           uuid,
    instrument_id             uuid,
    source_id                 uuid NOT NULL,
    statement_type            text NOT NULL,
    period_start              date,
    period_end                date NOT NULL,
    filing_date               date,
    currency_code             character(3),
    consolidation             text,
    payload_id                uuid,
    CONSTRAINT financial_statement_legal_entity_id_instrument_id_statement_key UNIQUE (legal_entity_id, instrument_id, statement_type, period_end, consolidation, source_id),
    CONSTRAINT financial_statement_pkey PRIMARY KEY (statement_id),
    CONSTRAINT financial_statement_statement_type_check CHECK ((statement_type = ANY (ARRAY['BALANCE_SHEET'::text, 'INCOME_STATEMENT'::text, 'CASH_FLOW'::text, 'OTHER'::text]))),
    CONSTRAINT financial_statement_consolidation_check CHECK ((consolidation = ANY (ARRAY['CONSOLIDATED'::text, 'INDIVIDUAL'::text, 'UNKNOWN'::text])))
);

-- ---------------------------------------------------------
-- Table: canonical.fund_holding
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.fund_holding (
    fund_instrument_id        uuid NOT NULL,
    holding_instrument_id     uuid NOT NULL,
    holding_name              text NOT NULL,
    reference_date            date NOT NULL,
    weight                    numeric(18,10),
    quantity                  numeric(38,10),
    market_value              numeric(38,8),
    currency_code             character(3),
    source_id                 uuid NOT NULL,
    CONSTRAINT fund_holding_pkey PRIMARY KEY (fund_instrument_id, holding_instrument_id, holding_name, reference_date, source_id),
    CONSTRAINT fund_holding_check CHECK (((holding_instrument_id IS NOT NULL) OR (holding_name IS NOT NULL)))
);

-- ---------------------------------------------------------
-- Table: canonical.fund_profile
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.fund_profile (
    instrument_id             uuid NOT NULL,
    fund_type                 text,
    segment                   text,
    administrator_id          uuid,
    manager_id                uuid,
    custodian_id              uuid,
    inception_date            date,
    tax_regime                text,
    attributes                jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT fund_profile_pkey PRIMARY KEY (instrument_id)
);

-- ---------------------------------------------------------
-- Table: canonical.government_bond
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.government_bond (
    instrument_id             uuid NOT NULL,
    bond_program              text NOT NULL DEFAULT 'TESOURO_DIRETO'::text,
    indexer                   text,
    maturity_date             date,
    coupon_rate               numeric(18,8),
    CONSTRAINT government_bond_pkey PRIMARY KEY (instrument_id),
    CONSTRAINT government_bond_maturity_date_check CHECK (((maturity_date IS NULL) OR (maturity_date >= '1900-01-01'::date)))
);

-- ---------------------------------------------------------
-- Table: canonical.index_constituent
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.index_constituent (
    index_id                  uuid NOT NULL,
    instrument_id             uuid NOT NULL,
    valid_from                date NOT NULL,
    valid_to                  date,
    weight                    numeric(18,10),
    rank                      integer,
    source_id                 uuid,
    CONSTRAINT index_constituent_pkey PRIMARY KEY (index_id, instrument_id, valid_from)
);

-- ---------------------------------------------------------
-- Table: canonical.index_profile
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.index_profile (
    index_id                  uuid NOT NULL DEFAULT gen_random_uuid(),
    instrument_id             uuid NOT NULL,
    methodology_url           text,
    provider                  text,
    rebalance_frequency       text,
    CONSTRAINT index_profile_instrument_id_key UNIQUE (instrument_id),
    CONSTRAINT index_profile_pkey PRIMARY KEY (index_id)
);

-- ---------------------------------------------------------
-- Table: canonical.instrument
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.instrument (
    instrument_id             uuid NOT NULL DEFAULT gen_random_uuid(),
    asset_class               canonical.asset_class NOT NULL,
    legal_entity_id           uuid,
    issuer_id                 uuid,
    name                      text NOT NULL,
    short_name                text,
    isin                      text,
    currency_code             character(3),
    venue_id                  uuid,
    status                    text NOT NULL DEFAULT 'ACTIVE'::text,
    first_seen_at             timestamp with time zone NOT NULL DEFAULT now(),
    last_seen_at              timestamp with time zone,
    attributes                jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT instrument_isin_key UNIQUE (isin),
    CONSTRAINT instrument_pkey PRIMARY KEY (instrument_id),
    CONSTRAINT instrument_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'INACTIVE'::text, 'MATURED'::text, 'UNKNOWN'::text])))
);

-- ---------------------------------------------------------
-- Table: canonical.instrument_alias
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.instrument_alias (
    alias_id                  uuid NOT NULL DEFAULT gen_random_uuid(),
    instrument_id             uuid NOT NULL,
    alias_type                text NOT NULL,
    alias_value               text NOT NULL,
    normalized_value          text NOT NULL,
    venue_id                  uuid,
    source_id                 uuid,
    valid_from                date,
    valid_to                  date,
    is_primary                boolean NOT NULL DEFAULT false,
    CONSTRAINT instrument_alias_alias_type_normalized_value_venue_id_valid_key UNIQUE (alias_type, normalized_value, venue_id, valid_from),
    CONSTRAINT instrument_alias_pkey PRIMARY KEY (alias_id),
    CONSTRAINT instrument_alias_alias_type_check CHECK ((alias_type = ANY (ARRAY['TICKER'::text, 'CNPJ'::text, 'ISIN'::text, 'CUSIP'::text, 'RIC'::text, 'SYMBOL'::text, 'SOURCE_ID'::text, 'NAME'::text])))
);

-- ---------------------------------------------------------
-- Table: canonical.legal_entity
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.legal_entity (
    legal_entity_id           uuid NOT NULL DEFAULT gen_random_uuid(),
    legal_name                text NOT NULL,
    cnpj                      text,
    tax_id                    text,
    country_code              character(2) NOT NULL DEFAULT 'BR'::bpchar,
    website                   text,
    valid_from                date,
    valid_to                  date,
    CONSTRAINT legal_entity_country_code_tax_id_key UNIQUE (country_code, tax_id),
    CONSTRAINT legal_entity_pkey PRIMARY KEY (legal_entity_id)
);

-- ---------------------------------------------------------
-- Table: canonical.metric_definition
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.metric_definition (
    metric_id                 uuid NOT NULL DEFAULT gen_random_uuid(),
    code                      text NOT NULL,
    name                      text NOT NULL,
    category                  text,
    default_unit              text,
    description               text,
    calculation_note          text,
    CONSTRAINT metric_definition_code_key UNIQUE (code),
    CONSTRAINT metric_definition_pkey PRIMARY KEY (metric_id)
);

-- ---------------------------------------------------------
-- Table: canonical.metric_observation
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.metric_observation (
    metric_observation_id     bigint NOT NULL DEFAULT nextval('canonical.metric_observation_metric_observation_id_seq'::regclass),
    instrument_id             uuid NOT NULL,
    metric_id                 uuid NOT NULL,
    source_id                 uuid NOT NULL,
    reference_date            date,
    period_start              date,
    period_end                date,
    period_type               text,
    value_numeric             numeric(38,16),
    unit                      text,
    currency_code             character(3),
    denominator_note          text,
    observed_at               timestamp with time zone NOT NULL DEFAULT now(),
    payload_id                uuid,
    quality_status            text NOT NULL DEFAULT 'OBSERVED'::text,
    CONSTRAINT metric_observation_instrument_id_metric_id_source_id_refere_key UNIQUE (instrument_id, metric_id, source_id, reference_date, period_start, period_end, observed_at),
    CONSTRAINT metric_observation_pkey PRIMARY KEY (metric_observation_id),
    CONSTRAINT metric_observation_period_type_check CHECK ((period_type = ANY (ARRAY['POINT_IN_TIME'::text, 'DAY'::text, 'MONTH'::text, 'QUARTER'::text, 'YEAR'::text, 'TTM'::text, 'YTD'::text, 'CUSTOM'::text])))
);

-- ---------------------------------------------------------
-- Table: canonical.offering
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.offering (
    offering_id               uuid NOT NULL DEFAULT gen_random_uuid(),
    instrument_id             uuid NOT NULL,
    source_id                 uuid NOT NULL,
    offering_type             text NOT NULL,
    announcement_date         date,
    base_date                 date,
    start_date                date,
    end_date                  date,
    price_per_unit            numeric(24,8),
    discount_rate             numeric(18,8),
    subscription_ratio        numeric(24,10),
    status                    text,
    document_id               uuid,
    CONSTRAINT offering_instrument_id_offering_type_base_date_source_id_key UNIQUE (instrument_id, offering_type, base_date, source_id),
    CONSTRAINT offering_pkey PRIMARY KEY (offering_id)
);

-- ---------------------------------------------------------
-- Table: canonical.option_contract
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.option_contract (
    instrument_id             uuid NOT NULL,
    underlying_instrument_id  uuid NOT NULL,
    option_type               text NOT NULL,
    exercise_style            text,
    strike                    numeric(24,8),
    expiration_date           date,
    contract_size             numeric(24,8),
    CONSTRAINT option_contract_pkey PRIMARY KEY (instrument_id),
    CONSTRAINT option_contract_exercise_style_check CHECK ((exercise_style = ANY (ARRAY['AMERICAN'::text, 'EUROPEAN'::text, 'UNKNOWN'::text]))),
    CONSTRAINT option_contract_option_type_check CHECK ((option_type = ANY (ARRAY['CALL'::text, 'PUT'::text]))),
    CONSTRAINT option_contract_strike_check CHECK (((strike IS NULL) OR (strike >= (0)::numeric)))
);

-- ---------------------------------------------------------
-- Table: canonical.price_observation
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.price_observation (
    price_observation_id      bigint NOT NULL DEFAULT nextval('canonical.price_observation_price_observation_id_seq'::regclass),
    instrument_id             uuid NOT NULL,
    source_id                 uuid NOT NULL,
    observed_at               timestamp with time zone NOT NULL,
    trading_date              date,
    price                     numeric(24,8),
    open_price                numeric(24,8),
    high_price                numeric(24,8),
    low_price                 numeric(24,8),
    close_price               numeric(24,8),
    adjusted_close            numeric(24,8),
    bid                       numeric(24,8),
    ask                       numeric(24,8),
    volume                    numeric(30,8),
    trade_count               bigint,
    currency_code             character(3),
    adjustment_basis          text,
    quality_status            text NOT NULL DEFAULT 'OBSERVED'::text,
    payload_id                uuid,
    CONSTRAINT price_observation_instrument_id_source_id_observed_at_tradi_key UNIQUE (instrument_id, source_id, observed_at, trading_date),
    CONSTRAINT price_observation_pkey PRIMARY KEY (price_observation_id),
    CONSTRAINT price_observation_quality_status_check CHECK ((quality_status = ANY (ARRAY['OBSERVED'::text, 'ESTIMATED'::text, 'REVISED'::text, 'REJECTED'::text])))
);

-- ---------------------------------------------------------
-- Table: canonical.source
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.source (
    source_id                 uuid NOT NULL DEFAULT gen_random_uuid(),
    name                      text NOT NULL,
    kind                      canonical.source_kind NOT NULL,
    base_url                  text,
    license_note              text,
    active                    boolean NOT NULL DEFAULT true,
    created_at                timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT source_name_kind_key UNIQUE (name, kind),
    CONSTRAINT source_pkey PRIMARY KEY (source_id)
);

-- ---------------------------------------------------------
-- Table: canonical.venue
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS canonical.venue (
    venue_id                  uuid NOT NULL DEFAULT gen_random_uuid(),
    code                      text NOT NULL,
    name                      text NOT NULL,
    country_code              character(2),
    timezone                  text,
    CONSTRAINT venue_code_key UNIQUE (code),
    CONSTRAINT venue_pkey PRIMARY KEY (venue_id)
);

-- ---------------------------------------------------------
-- Table: raw.ingestion_batch
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.ingestion_batch (
    batch_id                  uuid NOT NULL DEFAULT gen_random_uuid(),
    source_id                 uuid,
    collector_name            text NOT NULL,
    collector_version         text,
    started_at                timestamp with time zone NOT NULL DEFAULT now(),
    finished_at               timestamp with time zone,
    status                    text NOT NULL,
    request_count             integer NOT NULL DEFAULT 0,
    error_count               integer NOT NULL DEFAULT 0,
    notes                     text,
    CONSTRAINT ingestion_batch_pkey PRIMARY KEY (batch_id),
    CONSTRAINT ingestion_batch_error_count_check CHECK ((error_count >= 0)),
    CONSTRAINT ingestion_batch_request_count_check CHECK ((request_count >= 0)),
    CONSTRAINT ingestion_batch_status_check CHECK ((status = ANY (ARRAY['RUNNING'::text, 'SUCCEEDED'::text, 'PARTIAL'::text, 'FAILED'::text])))
);

-- ---------------------------------------------------------
-- Table: raw.payload
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.payload (
    payload_id                uuid NOT NULL DEFAULT gen_random_uuid(),
    batch_id                  uuid NOT NULL,
    source_url                text,
    captured_at               timestamp with time zone NOT NULL DEFAULT now(),
    http_status               integer,
    mime_type                 text,
    content_sha256            text NOT NULL,
    encoding                  text,
    body                      bytea,
    metadata                  jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT payload_batch_id_content_sha256_key UNIQUE (batch_id, content_sha256),
    CONSTRAINT payload_pkey PRIMARY KEY (payload_id),
    CONSTRAINT payload_content_sha256_check CHECK ((content_sha256 ~ '^[0-9a-fA-F]{64}$'::text)),
    CONSTRAINT payload_http_status_check CHECK (((http_status >= 100) AND (http_status <= 599)))
);

-- 3. FOREIGN KEYS
DO $$ BEGIN
    ALTER TABLE analytics.ranking_item ADD CONSTRAINT ranking_item_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE analytics.ranking_item ADD CONSTRAINT ranking_item_ranking_id_fkey FOREIGN KEY (ranking_id) REFERENCES analytics.ranking_snapshot(ranking_id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.corporate_event ADD CONSTRAINT corporate_event_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES canonical.currency(currency_code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.corporate_event ADD CONSTRAINT corporate_event_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.corporate_event ADD CONSTRAINT corporate_event_payload_id_fkey FOREIGN KEY (payload_id) REFERENCES raw.payload(payload_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.corporate_event ADD CONSTRAINT corporate_event_source_id_fkey FOREIGN KEY (source_id) REFERENCES canonical.source(source_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.disclosure_document ADD CONSTRAINT disclosure_document_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.disclosure_document ADD CONSTRAINT disclosure_document_legal_entity_id_fkey FOREIGN KEY (legal_entity_id) REFERENCES canonical.legal_entity(legal_entity_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.disclosure_document ADD CONSTRAINT disclosure_document_payload_id_fkey FOREIGN KEY (payload_id) REFERENCES raw.payload(payload_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.disclosure_document ADD CONSTRAINT disclosure_document_source_id_fkey FOREIGN KEY (source_id) REFERENCES canonical.source(source_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.financial_line ADD CONSTRAINT financial_line_statement_id_fkey FOREIGN KEY (statement_id) REFERENCES canonical.financial_statement(statement_id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.financial_statement ADD CONSTRAINT financial_statement_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES canonical.currency(currency_code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.financial_statement ADD CONSTRAINT financial_statement_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.financial_statement ADD CONSTRAINT financial_statement_legal_entity_id_fkey FOREIGN KEY (legal_entity_id) REFERENCES canonical.legal_entity(legal_entity_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.financial_statement ADD CONSTRAINT financial_statement_payload_id_fkey FOREIGN KEY (payload_id) REFERENCES raw.payload(payload_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.financial_statement ADD CONSTRAINT financial_statement_source_id_fkey FOREIGN KEY (source_id) REFERENCES canonical.source(source_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.fund_holding ADD CONSTRAINT fund_holding_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES canonical.currency(currency_code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.fund_holding ADD CONSTRAINT fund_holding_fund_instrument_id_fkey FOREIGN KEY (fund_instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.fund_holding ADD CONSTRAINT fund_holding_holding_instrument_id_fkey FOREIGN KEY (holding_instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.fund_holding ADD CONSTRAINT fund_holding_source_id_fkey FOREIGN KEY (source_id) REFERENCES canonical.source(source_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.fund_profile ADD CONSTRAINT fund_profile_administrator_id_fkey FOREIGN KEY (administrator_id) REFERENCES canonical.legal_entity(legal_entity_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.fund_profile ADD CONSTRAINT fund_profile_custodian_id_fkey FOREIGN KEY (custodian_id) REFERENCES canonical.legal_entity(legal_entity_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.fund_profile ADD CONSTRAINT fund_profile_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.fund_profile ADD CONSTRAINT fund_profile_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES canonical.legal_entity(legal_entity_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.government_bond ADD CONSTRAINT government_bond_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.index_constituent ADD CONSTRAINT index_constituent_index_id_fkey FOREIGN KEY (index_id) REFERENCES canonical.index_profile(index_id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.index_constituent ADD CONSTRAINT index_constituent_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.index_constituent ADD CONSTRAINT index_constituent_source_id_fkey FOREIGN KEY (source_id) REFERENCES canonical.source(source_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.index_profile ADD CONSTRAINT index_profile_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.instrument ADD CONSTRAINT instrument_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES canonical.currency(currency_code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.instrument ADD CONSTRAINT instrument_issuer_id_fkey FOREIGN KEY (issuer_id) REFERENCES canonical.legal_entity(legal_entity_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.instrument ADD CONSTRAINT instrument_legal_entity_id_fkey FOREIGN KEY (legal_entity_id) REFERENCES canonical.legal_entity(legal_entity_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.instrument ADD CONSTRAINT instrument_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES canonical.venue(venue_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.instrument_alias ADD CONSTRAINT instrument_alias_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.instrument_alias ADD CONSTRAINT instrument_alias_source_id_fkey FOREIGN KEY (source_id) REFERENCES canonical.source(source_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.instrument_alias ADD CONSTRAINT instrument_alias_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES canonical.venue(venue_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.metric_observation ADD CONSTRAINT metric_observation_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES canonical.currency(currency_code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.metric_observation ADD CONSTRAINT metric_observation_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.metric_observation ADD CONSTRAINT metric_observation_metric_id_fkey FOREIGN KEY (metric_id) REFERENCES canonical.metric_definition(metric_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.metric_observation ADD CONSTRAINT metric_observation_payload_id_fkey FOREIGN KEY (payload_id) REFERENCES raw.payload(payload_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.metric_observation ADD CONSTRAINT metric_observation_source_id_fkey FOREIGN KEY (source_id) REFERENCES canonical.source(source_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.offering ADD CONSTRAINT offering_document_id_fkey FOREIGN KEY (document_id) REFERENCES canonical.disclosure_document(document_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.offering ADD CONSTRAINT offering_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.offering ADD CONSTRAINT offering_source_id_fkey FOREIGN KEY (source_id) REFERENCES canonical.source(source_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.option_contract ADD CONSTRAINT option_contract_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.option_contract ADD CONSTRAINT option_contract_underlying_instrument_id_fkey FOREIGN KEY (underlying_instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.price_observation ADD CONSTRAINT price_observation_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES canonical.currency(currency_code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.price_observation ADD CONSTRAINT price_observation_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES canonical.instrument(instrument_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.price_observation ADD CONSTRAINT price_observation_payload_id_fkey FOREIGN KEY (payload_id) REFERENCES raw.payload(payload_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE canonical.price_observation ADD CONSTRAINT price_observation_source_id_fkey FOREIGN KEY (source_id) REFERENCES canonical.source(source_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE raw.ingestion_batch ADD CONSTRAINT ingestion_batch_source_id_fkey FOREIGN KEY (source_id) REFERENCES canonical.source(source_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE raw.payload ADD CONSTRAINT payload_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES raw.ingestion_batch(batch_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 4. INDEXES
CREATE INDEX corporate_event_date_idx ON canonical.corporate_event USING btree (instrument_id, ex_date DESC, payment_date DESC);
CREATE INDEX disclosure_instrument_date_idx ON canonical.disclosure_document USING btree (instrument_id, document_date DESC);
CREATE INDEX instrument_class_idx ON canonical.instrument USING btree (asset_class, status);
CREATE INDEX instrument_issuer_idx ON canonical.instrument USING btree (issuer_id);
CREATE INDEX alias_lookup_idx ON canonical.instrument_alias USING btree (alias_type, normalized_value);
CREATE UNIQUE INDEX legal_entity_cnpj_uq ON canonical.legal_entity USING btree (cnpj) WHERE (cnpj IS NOT NULL);
CREATE INDEX metric_lookup_idx ON canonical.metric_observation USING btree (instrument_id, metric_id, reference_date DESC);
CREATE INDEX price_instrument_date_idx ON canonical.price_observation USING btree (instrument_id, trading_date DESC);
CREATE INDEX raw_payload_source_time_idx ON raw.payload USING btree (source_url, captured_at DESC);

-- 5. VIEWS
CREATE OR REPLACE VIEW analytics.latest_price AS
 SELECT DISTINCT ON (instrument_id) instrument_id,
    observed_at,
    trading_date,
    close_price,
    adjusted_close,
    currency_code,
    source_id,
    quality_status
   FROM canonical.price_observation p
  WHERE quality_status <> 'REJECTED'::text
  ORDER BY instrument_id, observed_at DESC, trading_date DESC;;

CREATE OR REPLACE VIEW public.app_table_catalog AS
 SELECT table_schema,
    table_name,
    table_type
   FROM information_schema.tables
  WHERE table_schema::name = ANY (ARRAY['raw'::name, 'canonical'::name, 'analytics'::name])
  ORDER BY table_schema, table_name;;
