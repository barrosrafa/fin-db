-- =========================================================
-- M3: canonical.news_article & canonical.news_article_instrument
-- Cobertura: Funds Explorer, Investidor10 (Notícias editoriais)
-- =========================================================

CREATE TABLE IF NOT EXISTS canonical.news_article (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_id     TEXT,
    source          TEXT NOT NULL,
    url             TEXT NOT NULL,
    title           TEXT NOT NULL,
    summary         TEXT,
    body            TEXT,
    published_at    TIMESTAMPTZ NOT NULL,
    author          TEXT,
    tags            TEXT[],
    raw_payload_id  UUID REFERENCES raw.payload(payload_id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (source, url)
);

CREATE INDEX IF NOT EXISTS ix_news_published ON canonical.news_article (published_at DESC);
CREATE INDEX IF NOT EXISTS ix_news_tags      ON canonical.news_article USING gin (tags);

-- Tabela associativa entre notícias e instrumentos canônicos
CREATE TABLE IF NOT EXISTS canonical.news_article_instrument (
    news_article_id UUID NOT NULL REFERENCES canonical.news_article(id) ON DELETE CASCADE,
    instrument_id   UUID NOT NULL REFERENCES canonical.instrument(instrument_id) ON DELETE CASCADE,
    PRIMARY KEY (news_article_id, instrument_id)
);

CREATE INDEX IF NOT EXISTS ix_news_inst_instrument ON canonical.news_article_instrument (instrument_id);
