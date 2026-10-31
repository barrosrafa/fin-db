-- Automatic, additive security fence. Runtime passwords are provisioned separately.
-- Financial domain only; never run against the isolated Aiven CMS database.
DO $roles$
DECLARE role_name text;
BEGIN
  IF current_database() = 'fin_cms' THEN RAISE EXCEPTION 'Financial migration forbidden on CMS database'; END IF;
  FOREACH role_name IN ARRAY ARRAY['fin_api_rw','fin_ingestion_rw','fin_migration_owner','fin_readonly_public'] LOOP
    IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=role_name) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS', role_name);
    END IF;
    IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=role_name AND (rolsuper OR rolbypassrls)) THEN
      RAISE EXCEPTION 'Runtime/migration role % has forbidden bypass privileges',role_name;
    END IF;
  END LOOP;
END $roles$;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

DO $grants$
DECLARE item record; predicate text; schema_name text; target text;
BEGIN
  -- Financial/public datasets contain no customer ownership columns. Runtime
  -- ingestion never receives private wallet, billing, support or auth grants.
  FOREACH schema_name IN ARRAY ARRAY['market','asset_details','canonical','analytics','dw','public_dw','raw','ingestion','graph'] LOOP
    IF EXISTS(SELECT 1 FROM pg_namespace WHERE nspname=schema_name) THEN
      EXECUTE format('GRANT USAGE ON SCHEMA %I TO fin_api_rw,fin_ingestion_rw',schema_name);
      IF schema_name NOT IN ('raw','ingestion','graph') THEN
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO fin_readonly_public',schema_name);
      END IF;
      FOR item IN SELECT c.relname,c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname=schema_name AND c.relkind IN ('r','p','v','m') LOOP
        target := format('%I.%I',schema_name,item.relname);
        IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema=schema_name AND table_name=item.relname
          AND column_name IN ('id_usuario','user_id','id_carteira','id_conta_bancaria')) THEN
          IF schema_name NOT IN ('raw','ingestion','graph') THEN
            EXECUTE format('GRANT SELECT ON %s TO fin_api_rw,fin_ingestion_rw,fin_readonly_public',target);
          ELSIF schema_name='graph' THEN
            EXECUTE format('GRANT SELECT ON %s TO fin_api_rw,fin_ingestion_rw',target);
          ELSE
            EXECUTE format('GRANT SELECT ON %s TO fin_ingestion_rw',target);
          END IF;
          IF item.relkind='v' THEN EXECUTE format('ALTER VIEW %s SET (security_invoker=true)',target); END IF;
          IF item.relkind IN ('r','p') AND schema_name NOT IN ('graph','suitability') THEN
            EXECUTE format('GRANT INSERT,UPDATE,DELETE ON %s TO fin_ingestion_rw',target);
          END IF;
        END IF;
      END LOOP;
    END IF;
  END LOOP;
  GRANT USAGE ON SCHEMA core,system,social,wealth TO fin_api_rw;
  GRANT USAGE ON SCHEMA core,system TO fin_ingestion_rw;
  GRANT USAGE ON SCHEMA core TO fin_readonly_public;
  -- Core market master data is an explicit allowlist, never ALL TABLES in core.
  FOR item IN SELECT tablename FROM pg_tables WHERE schemaname='core' AND tablename IN
    ('ativo','ativo_dupla_listagem','ativo_historico','bolsa','emissor_companhia','emissor_historico',
     'moeda','par_moeda','fuso_horario','historico_ticker','administrador_companhia','grupo_acionista',
     'historico_acionista','instituicao_diretoria_socios','instituicao_financeira','remuneracao_administradores') LOOP
    EXECUTE format('GRANT SELECT ON core.%I TO fin_api_rw,fin_ingestion_rw,fin_readonly_public',item.tablename);
    EXECUTE format('GRANT INSERT,UPDATE,DELETE ON core.%I TO fin_ingestion_rw',item.tablename);
  END LOOP;
  -- Every directly owned application table receives a restrictive tenant fence.
  FOR item IN SELECT t.table_schema,t.table_name,
    max(CASE WHEN c.column_name='id_usuario' THEN 'id_usuario' WHEN c.column_name='user_id' THEN 'user_id' END) AS owner_column
    FROM information_schema.tables t JOIN information_schema.columns c USING(table_schema,table_name)
    WHERE t.table_type='BASE TABLE' AND t.table_schema IN ('core','wealth','social','system','analytics','graph','suitability')
      AND c.column_name IN ('id_usuario','user_id')
    GROUP BY t.table_schema,t.table_name LOOP
    target := format('%I.%I',item.table_schema,item.table_name);
    predicate := format('%I::text = NULLIF(current_setting(''app.current_user_id'',true),'''')',item.owner_column);
    IF item.table_schema='core' AND item.table_name='usuario' THEN
      predicate := '(' || predicate || ' OR id_usuario::text = NULLIF(current_setting(''app.auth_subject'',true),'''')'
        || ' OR id_externo = NULLIF(current_setting(''app.auth_subject'',true),'''')'
        || ' OR lower(email) = lower(NULLIF(current_setting(''app.auth_email'',true),'''')))';
    END IF;
    EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY',target);
    EXECUTE format('ALTER TABLE %s FORCE ROW LEVEL SECURITY',target);
    EXECUTE format('DROP POLICY IF EXISTS fin_runtime_owner ON %s',target);
    EXECUTE format('DROP POLICY IF EXISTS fin_runtime_fence ON %s',target);
    EXECUTE format('CREATE POLICY fin_runtime_owner ON %s FOR ALL TO fin_api_rw USING (%s) WITH CHECK (%s)',target,predicate,predicate);
    EXECUTE format('CREATE POLICY fin_runtime_fence ON %s AS RESTRICTIVE FOR ALL TO fin_api_rw USING (%s) WITH CHECK (%s)',target,predicate,predicate);
    EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON %s TO fin_api_rw',target);
  END LOOP;
  -- Wallet child rows are protected through the already fenced wallet table.
  FOR item IN SELECT c.table_schema,c.table_name FROM information_schema.columns c
    JOIN information_schema.tables t USING(table_schema,table_name)
    WHERE c.column_name='id_carteira' AND t.table_type='BASE TABLE'
      AND c.table_schema IN ('core','wealth','social','dw','reconciliation')
      AND NOT EXISTS(SELECT 1 FROM information_schema.columns own WHERE own.table_schema=c.table_schema AND own.table_name=c.table_name AND own.column_name IN ('id_usuario','user_id')) LOOP
    target:=format('%I.%I',item.table_schema,item.table_name);
    predicate:=format('EXISTS(SELECT 1 FROM core.carteira owner WHERE owner.id_carteira=%I.id_carteira AND owner.id_usuario::text=NULLIF(current_setting(''app.current_user_id'',true),''''))',item.table_name);
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO fin_api_rw',item.table_schema);
    EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY',target);
    EXECUTE format('ALTER TABLE %s FORCE ROW LEVEL SECURITY',target);
    EXECUTE format('DROP POLICY IF EXISTS fin_runtime_owner ON %s',target);
    EXECUTE format('DROP POLICY IF EXISTS fin_runtime_fence ON %s',target);
    EXECUTE format('CREATE POLICY fin_runtime_owner ON %s FOR ALL TO fin_api_rw USING (%s) WITH CHECK (%s)',target,predicate,predicate);
    EXECUTE format('CREATE POLICY fin_runtime_fence ON %s AS RESTRICTIVE FOR ALL TO fin_api_rw USING (%s) WITH CHECK (%s)',target,predicate,predicate);
    EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON %s TO fin_api_rw',target);
  END LOOP;
  -- API can enqueue/read market commands, not control policy configuration or ETL.
  GRANT SELECT ON ingestion.ingestion_policy TO fin_api_rw;
  GRANT SELECT,INSERT,UPDATE ON ingestion.ingestion_task TO fin_api_rw;
  -- Sequence access follows an already granted table privilege.
  FOR item IN SELECT n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='S'
    AND n.nspname IN ('core','wealth','social','system','market','asset_details','canonical','analytics','dw','raw','ingestion','graph','reconciliation','suitability') LOOP
    IF EXISTS(SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid=d.refobjid
      WHERE d.objid=format('%I.%I',item.nspname,item.relname)::regclass AND d.deptype IN ('a','i') AND has_table_privilege('fin_api_rw',t.oid,'INSERT')) THEN
      EXECUTE format('GRANT USAGE,SELECT ON SEQUENCE %I.%I TO fin_api_rw',item.nspname,item.relname);
    END IF;
    IF EXISTS(SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid=d.refobjid
      WHERE d.objid=format('%I.%I',item.nspname,item.relname)::regclass AND d.deptype IN ('a','i') AND has_table_privilege('fin_ingestion_rw',t.oid,'INSERT')) THEN
      EXECUTE format('GRANT USAGE,SELECT ON SEQUENCE %I.%I TO fin_ingestion_rw',item.nspname,item.relname);
    END IF;
  END LOOP;
END $grants$;

-- Authentication may create an ordinary account and update profile fields, but
-- runtime SQL cannot grant itself a paid tier or administrative authorization.
DO $account_guard$
DECLARE profile_columns text;
BEGIN
  REVOKE UPDATE,DELETE ON core.usuario FROM fin_api_rw;
  SELECT string_agg(format('%I',column_name),',') INTO profile_columns
  FROM information_schema.columns WHERE table_schema='core' AND table_name='usuario'
    AND column_name IN ('nome','email','cpf_cnpj','data_nascimento','telefone','endereco','pais',
      'perfil_investidor','ultimo_acesso','mfa','aceite_termos','data_aceite','id_externo',
      'password_hash','salt','email_verificado');
  IF profile_columns IS NOT NULL THEN EXECUTE 'GRANT UPDATE ('||profile_columns||') ON core.usuario TO fin_api_rw'; END IF;
  DROP POLICY IF EXISTS fin_runtime_registration ON core.usuario;
  CREATE POLICY fin_runtime_registration ON core.usuario AS RESTRICTIVE FOR INSERT TO fin_api_rw
    WITH CHECK (COALESCE(role,'user')='user' AND COALESCE(tier,'free')='free');
  IF to_regclass('system.usuario_role') IS NOT NULL THEN
    REVOKE INSERT,UPDATE,DELETE ON system.usuario_role FROM fin_api_rw;
  END IF;
END $account_guard$;

-- Compatibility reads are historical editorial snapshots only. The active
-- publishing authority is Directus; support intake remains a financial API domain.
DO $legacy_content$
DECLARE name text; sequence_name text;
BEGIN
  IF EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='cms') THEN
    GRANT USAGE ON SCHEMA cms TO fin_api_rw;
    FOREACH name IN ARRAY ARRAY['termo_glossario','livro_investimento','artigo_blog'] LOOP
      IF to_regclass(format('cms.%I',name)) IS NOT NULL THEN
        EXECUTE format('GRANT SELECT ON cms.%I TO fin_api_rw',name);
      END IF;
    END LOOP;
    IF to_regclass('cms.ticket_suporte') IS NOT NULL THEN
      GRANT INSERT,SELECT(id_ticket) ON cms.ticket_suporte TO fin_api_rw;
      ALTER TABLE cms.ticket_suporte ENABLE ROW LEVEL SECURITY;
      ALTER TABLE cms.ticket_suporte FORCE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS fin_support_intake ON cms.ticket_suporte;
      CREATE POLICY fin_support_intake ON cms.ticket_suporte FOR ALL TO fin_api_rw
        USING (lower(email_contato)=lower(NULLIF(current_setting('app.auth_email',true),'')))
        WITH CHECK (lower(email_contato)=lower(NULLIF(current_setting('app.auth_email',true),'')));
      sequence_name:=pg_get_serial_sequence('cms.ticket_suporte','id_ticket');
      IF sequence_name IS NOT NULL THEN EXECUTE 'GRANT USAGE,SELECT ON SEQUENCE '||sequence_name||' TO fin_api_rw'; END IF;
    END IF;
  END IF;
END $legacy_content$;
