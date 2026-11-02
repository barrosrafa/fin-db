-- Evidence contains public exchange OHLC, no customer or portfolio records.
DO $grants$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fin_api_rw') THEN
        GRANT SELECT ON market.nominal_bar TO fin_api_rw;
    END IF;
END $grants$;
