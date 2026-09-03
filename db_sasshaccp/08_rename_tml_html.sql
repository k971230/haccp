-- ============================================================
--  08_rename_tml_html.sql — HTML 양식코드 tml_ccp_ → html_ccp_
--
--  개발자: 박승우
--  일자: 2026-09-03
--  코멘트:
--    1) CCP HTML 4계열이 tml_ 로 채번돼 있었다. html_hyg_prc_ 와 맞춘다
--    2) 행은 지우지 않는다. varchar/text 전 칸을 UPDATE 하고 표·제약·시퀀스를 RENAME
--    3) apply-all.sh 에 넣지 않는다. 이미 깔린 DB 전용. 빈 DB 는 00+01+02 가 처음부터 html_
--
--  적용 (01_sp.sql 보다 먼저 — 표 이름을 바꾼 뒤 새 SP 를 깐다)
--    node tools/q.mjs --db sasshaccp_test @db_sasshaccp/08_rename_tml_html.sql
--    node tools/q.mjs --db sasshaccp      @db_sasshaccp/08_rename_tml_html.sql
-- ============================================================
SET search_path TO sasshaccp;

BEGIN;

-- ------------------------------------------------------------
-- 1. 값 — 스키마 전 varchar/text 칸에서 tml_ccp_ 를 html_ccp_ 로
--    표를 나열하지 않는다. 칸이 늘어도 빠지지 않는다
-- ------------------------------------------------------------
DO $$
DECLARE
    r record;
    v_sql text;
    v_n bigint;
    v_total bigint := 0;
BEGIN
    FOR r IN
        SELECT c.table_schema, c.table_name, c.column_name
          FROM information_schema.columns c
          JOIN information_schema.tables t
            ON t.table_schema = c.table_schema
           AND t.table_name = c.table_name
         WHERE c.table_schema = 'sasshaccp'
           AND t.table_type = 'BASE TABLE'
           AND c.data_type IN ('character varying', 'text', 'character')
    LOOP
        -- html_ccp_ 안에 tml_ccp_ 가 들어 있다. 앞이 소문자가 아닐 때만 바꾼다
        v_sql := format(
            'UPDATE %I.%I SET %I = regexp_replace(%I, %L, %L, %L) WHERE %I ~ %L',
            r.table_schema, r.table_name, r.column_name, r.column_name,
            '(^|[^a-z])tml_ccp_', '\1html_ccp_', 'g',
            r.column_name, '(^|[^a-z])tml_ccp_'
        );
        EXECUTE v_sql;
        GET DIAGNOSTICS v_n = ROW_COUNT;
        v_total := v_total + v_n;
    END LOOP;
    RAISE NOTICE '08 값 UPDATE % 행', v_total;
END $$;

-- ------------------------------------------------------------
-- 2. 표 이름 — tbl_tml_ccp_* → tbl_html_ccp_*
-- ------------------------------------------------------------
DO $$
DECLARE
    r record;
    v_new text;
BEGIN
    FOR r IN
        SELECT c.relname
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'sasshaccp'
           AND c.relkind = 'r'
           AND c.relname ~ '(^|[^a-z])tml_ccp_'
    LOOP
        v_new := regexp_replace(r.relname, '(^|[^a-z])tml_ccp_', '\1html_ccp_', 'g');
        IF to_regclass('sasshaccp.' || v_new) IS NOT NULL THEN
            RAISE EXCEPTION '대상 표 % 가 이미 있다 — 수동 확인', v_new
                USING ERRCODE = '45000';
        END IF;
        EXECUTE format('ALTER TABLE sasshaccp.%I RENAME TO %I', r.relname, v_new);
        RAISE NOTICE '08 표 RENAME % → %', r.relname, v_new;
    END LOOP;
END $$;

-- ------------------------------------------------------------
-- 3. 시퀀스 · 제약 · 인덱스 이름
-- ------------------------------------------------------------
DO $$
DECLARE
    r record;
    v_new text;
BEGIN
    FOR r IN
        SELECT c.relname
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'sasshaccp'
           AND c.relkind = 'S'
           AND c.relname ~ '(^|[^a-z])tml_ccp_'
    LOOP
        v_new := regexp_replace(r.relname, '(^|[^a-z])tml_ccp_', '\1html_ccp_', 'g');
        EXECUTE format('ALTER SEQUENCE sasshaccp.%I RENAME TO %I', r.relname, v_new);
    END LOOP;

    FOR r IN
        SELECT con.conname, rel.relname AS tbl
          FROM pg_constraint con
          JOIN pg_class rel ON rel.oid = con.conrelid
          JOIN pg_namespace n ON n.oid = con.connamespace
         WHERE n.nspname = 'sasshaccp'
           AND con.conname ~ '(^|[^a-z])tml_ccp_'
    LOOP
        v_new := regexp_replace(r.conname, '(^|[^a-z])tml_ccp_', '\1html_ccp_', 'g');
        EXECUTE format(
            'ALTER TABLE sasshaccp.%I RENAME CONSTRAINT %I TO %I',
            r.tbl, r.conname, v_new
        );
    END LOOP;

    FOR r IN
        SELECT c.relname
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'sasshaccp'
           AND c.relkind = 'i'
           AND c.relname ~ '(^|[^a-z])tml_ccp_'
    LOOP
        v_new := regexp_replace(r.relname, '(^|[^a-z])tml_ccp_', '\1html_ccp_', 'g');
        EXECUTE format('ALTER INDEX sasshaccp.%I RENAME TO %I', r.relname, v_new);
    END LOOP;
END $$;

-- ------------------------------------------------------------
-- 4. 옛 SP — 새 이름 SP 는 01_sp.sql 이 만든다. 여기선 옛 이름만 지운다
-- ------------------------------------------------------------
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prokind
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'sasshaccp'
           AND (p.proname ~ '(^|[^a-z])tml_ccp_' OR p.proname LIKE 'sp_tbl_tml_%')
    LOOP
        IF r.prokind = 'p' THEN
            EXECUTE format('DROP PROCEDURE IF EXISTS sasshaccp.%I(%s)', r.proname, r.args);
        ELSE
            EXECUTE format('DROP FUNCTION IF EXISTS sasshaccp.%I(%s)', r.proname, r.args);
        END IF;
        RAISE NOTICE '08 DROP %', r.proname;
    END LOOP;
END $$;

-- ------------------------------------------------------------
-- 5. 잔존 검사 — 값·표·시퀀스·제약·인덱스·루틴에 tml_ccp_ 가 있으면 실패
-- ------------------------------------------------------------
DO $$
DECLARE
    r record;
    v_sql text;
    v_n bigint;
    v_left text := '';
BEGIN
    FOR r IN
        SELECT c.table_name, c.column_name
          FROM information_schema.columns c
          JOIN information_schema.tables t
            ON t.table_schema = c.table_schema
           AND t.table_name = c.table_name
         WHERE c.table_schema = 'sasshaccp'
           AND t.table_type = 'BASE TABLE'
           AND c.data_type IN ('character varying', 'text', 'character')
    LOOP
        v_sql := format(
            'SELECT count(*) FROM %I.%I WHERE %I ~ %L',
            'sasshaccp', r.table_name, r.column_name, '(^|[^a-z])tml_ccp_'
        );
        EXECUTE v_sql INTO v_n;
        IF v_n > 0 THEN
            v_left := v_left || format(' 값 %s.%s %s행;', r.table_name, r.column_name, v_n);
        END IF;
    END LOOP;

    FOR r IN
        SELECT c.relname, c.relkind
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'sasshaccp'
           AND c.relname ~ '(^|[^a-z])tml_ccp_'
    LOOP
        v_left := v_left || format(' 객체 %s;', r.relname);
    END LOOP;

    FOR r IN
        SELECT con.conname
          FROM pg_constraint con
          JOIN pg_namespace n ON n.oid = con.connamespace
         WHERE n.nspname = 'sasshaccp'
           AND con.conname ~ '(^|[^a-z])tml_ccp_'
    LOOP
        v_left := v_left || format(' 제약 %s;', r.conname);
    END LOOP;

    FOR r IN
        SELECT p.proname
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'sasshaccp'
           AND (p.proname ~ '(^|[^a-z])tml_ccp_' OR p.proname LIKE 'sp_tbl_tml_%')
    LOOP
        v_left := v_left || format(' 루틴 %s;', r.proname);
    END LOOP;

    IF v_left <> '' THEN
        RAISE EXCEPTION '08 잔존 tml_ccp_ — %', v_left USING ERRCODE = '45000';
    END IF;
    RAISE NOTICE '08 잔존 0건';
END $$;

COMMIT;
