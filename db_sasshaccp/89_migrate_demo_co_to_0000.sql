-- ============================================================
-- 89 — DEMO 테넌트 폐기, 개발 회사는 0000(데모식품)
--
-- 파일번호: 89
-- 이전번호: 88
-- 개발자: 박승우
-- 일자: 2026-08-18
-- 코멘트:
--   1) tbl_company 에 0000 이 없고 DEMO 만 있으면 DEMO 행을 0000(데모식품)으로 바꾼다
--   2) 사용자·나머지 테이블의 DEMO 행을 0000으로 옮긴다. 이후 개발 테넌트는 0000만
--   3) 0000이 업무 회사이므로 공통코드 저장의 0000 금지를 푼다. 신규 업체 생성·자기복제 금지는 13에 남긴다
--
-- Jenkins는 migrate를 안 돌리므로 적용은 DBeaver/수동
-- 적용 후 로그아웃·재로그인 — JWT coCd 가 DEMO 로 남아 있으면 콤보는 그대로 비다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 회사 0000(데모식품) — tbl_company 에 0000 행이 없을 수 있다
--    표준코드만 0000 이고 로그인 회사는 DEMO 인 DB가 그 경우다
--    0000이 없고 DEMO만 있으면 DEMO 행의 회사코드를 0000으로 바꾼다
-- ------------------------------------------------------------
UPDATE sasshaccp.tbl_company
   SET co_cd  = '0000',
       co_nm  = '데모식품',
       upd_id = 'system',
       upd_dt = now()
 WHERE co_cd = 'DEMO'
   AND NOT EXISTS (
         SELECT 1 FROM sasshaccp.tbl_company x WHERE x.co_cd = '0000'
       );

INSERT INTO sasshaccp.tbl_company (co_cd, co_nm, use_yn, ins_id, ins_dt)
SELECT '0000', '데모식품', 'Y', 'system', now()
 WHERE NOT EXISTS (
         SELECT 1 FROM sasshaccp.tbl_company x WHERE x.co_cd = '0000'
       );

UPDATE sasshaccp.tbl_company
   SET co_nm  = '데모식품',
       upd_id = 'system',
       upd_dt = now()
 WHERE co_cd = '0000';

-- ------------------------------------------------------------
-- 2. 로그인 계정부터 — tbl_user 는 전역 user_id UNIQUE 라 회사코드만 바꾸면 된다
--    ux_tbl_user_co_emp (co_cd, emp_cd) 충돌이면 DEMO 쪽 사번만 비운다
--    이 문은 DO 밖에 둔다. 이후 루프가 실패해도 로그인은 0000 이다
-- ------------------------------------------------------------
UPDATE sasshaccp.tbl_user d
   SET emp_cd = NULL
 WHERE d.co_cd = 'DEMO'
   AND d.emp_cd IS NOT NULL
   AND EXISTS (
         SELECT 1
           FROM sasshaccp.tbl_user z
          WHERE z.co_cd = '0000'
            AND z.emp_cd = d.emp_cd
       );

UPDATE sasshaccp.tbl_user
   SET co_cd  = '0000',
       upd_id = 'system',
       upd_dt = now()
 WHERE co_cd = 'DEMO';

-- ------------------------------------------------------------
-- 3. 나머지 테이블 DEMO 행 → 0000
--    UNIQUE(co_cd, ...) 충돌이면 DEMO 쪽만 지운다. 스키마를 붙여 search_path 와 무관하게 한다
--    한 테이블이 실패해도 다음을 이어 가고, 마지막 잔여 검사가 모은다
--    tbl_company 는 0000 행이 이미 있어 여기서 빼다
-- ------------------------------------------------------------
DO $$
DECLARE
    -- 대상 테이블 oid·이름
    v_tbl   record;
    -- UNIQUE 제약 oid
    v_con   record;
    -- UNIQUE 컬럼 중 co_cd 를 뺀 나머지
    v_other text[];
    -- EXISTS 절 — 0000에 같은 업무키가 있는지
    v_pred  text;
    -- 컬럼명 하나
    v_col   text;
    -- 동적 SQL
    v_sql   text;
    -- 테이블별 실패 문구
    v_err   text;
BEGIN
    FOR v_tbl IN
        SELECT c.oid AS relid, c.relname
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'sasshaccp'
           AND c.relkind = 'r'
           AND c.relname NOT IN ('tbl_company', 'tbl_user')
           AND EXISTS (
                 SELECT 1
                   FROM pg_attribute a
                  WHERE a.attrelid = c.oid
                    AND a.attname = 'co_cd'
                    AND NOT a.attisdropped
               )
         ORDER BY c.relname
    LOOP
        BEGIN
            FOR v_con IN
                SELECT con.oid
                  FROM pg_constraint con
                 WHERE con.conrelid = v_tbl.relid
                   AND con.contype = 'u'
            LOOP
                SELECT coalesce(array_agg(a.attname ORDER BY u.ord)
                                FILTER (WHERE a.attname <> 'co_cd'), ARRAY[]::text[])
                  INTO v_other
                  FROM pg_constraint con
                  JOIN unnest(con.conkey) WITH ORDINALITY AS u(attnum, ord) ON true
                  JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = u.attnum
                 WHERE con.oid = v_con.oid
                   AND EXISTS (
                         SELECT 1
                           FROM unnest(con.conkey) AS k(attnum)
                           JOIN pg_attribute x ON x.attrelid = con.conrelid AND x.attnum = k.attnum
                          WHERE x.attname = 'co_cd'
                       );

                -- co_cd 가 키에 없거나, co_cd 단독 UNIQUE 면 건너뛴다
                IF v_other IS NULL OR array_length(v_other, 1) IS NULL THEN
                    CONTINUE;
                END IF;

                v_pred := '';
                FOREACH v_col IN ARRAY v_other
                LOOP
                    -- NULL 끼리도 같은 키로 본다
                    v_pred := v_pred || format(' AND d.%I IS NOT DISTINCT FROM z.%I', v_col, v_col);
                END LOOP;

                v_sql := format(
                    'DELETE FROM sasshaccp.%I AS d WHERE d.co_cd = %L AND EXISTS (SELECT 1 FROM sasshaccp.%I AS z WHERE z.co_cd = %L%s)',
                    v_tbl.relname, 'DEMO', v_tbl.relname, '0000', v_pred
                );
                EXECUTE v_sql;
            END LOOP;

            EXECUTE format(
                'UPDATE sasshaccp.%I SET co_cd = %L WHERE co_cd = %L',
                v_tbl.relname, '0000', 'DEMO'
            );
            RAISE NOTICE 'DEMO→0000 이전 — %', v_tbl.relname;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
            RAISE NOTICE 'DEMO→0000 실패 — % : %', v_tbl.relname, v_err;
        END;
    END LOOP;
END$$;

-- ------------------------------------------------------------
-- 4. DEMO 잔여 확인 후 회사 행 삭제
--    EXCEPTION 으로 막지 않는다. 막으면 2의 tbl_user 이전까지 롤백된다
-- ------------------------------------------------------------
DO $$
DECLARE
    v_tbl   record;
    v_cnt   bigint;
    v_total bigint := 0;
BEGIN
    FOR v_tbl IN
        SELECT c.relname
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'sasshaccp'
           AND c.relkind = 'r'
           AND c.relname <> 'tbl_company'
           AND EXISTS (
                 SELECT 1
                   FROM pg_attribute a
                  WHERE a.attrelid = c.oid
                    AND a.attname = 'co_cd'
                    AND NOT a.attisdropped
               )
         ORDER BY c.relname
    LOOP
        EXECUTE format('SELECT count(*) FROM sasshaccp.%I WHERE co_cd = %L', v_tbl.relname, 'DEMO') INTO v_cnt;
        -- v_cnt > 0일 때(= 이전 누락) 합산해 알린다
        IF v_cnt > 0 THEN
            RAISE NOTICE 'DEMO 잔여 % = %', v_tbl.relname, v_cnt;
            v_total := v_total + v_cnt;
        END IF;
    END LOOP;
    RAISE NOTICE 'DEMO 잔여 합계 = %', v_total;
    -- 자식이 남아 있을 때(= 회사 행만 지우면 고아) 삭제를 건너뛴다
    IF v_total = 0 THEN
        DELETE FROM sasshaccp.tbl_company WHERE co_cd = 'DEMO';
        RAISE NOTICE 'DEMO 회사 행 삭제';
    ELSE
        RAISE NOTICE 'DEMO 회사 삭제를 건너뜀 — 자식 잔여 %건', v_total;
    END IF;
END$$;

-- ------------------------------------------------------------
-- 6. 공통코드 저장 — 0000 저장 금지 제거
--    72 본문에서 IF p_co_cd = '0000' 만 뺀다. 시스템코드 코드명·사용여부 제한은 그대로다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_common_code_management_c_000(
    -- p_co_cd: JWT 회사코드 — 개발 테넌트는 0000(데모식품)
    p_co_cd   varchar,
    -- p_idx: 수정 대상 대리키. 신규면 NULL
    p_idx     bigint,
    -- p_main_cd: 대분류 코드
    p_main_cd varchar,
    -- p_sub_cd: 세부 코드
    p_sub_cd  varchar,
    -- p_code_nm: 코드명
    p_code_nm varchar,
    -- p_sort_no: 정렬순서
    p_sort_no int,
    -- p_ref1: 참조값1
    p_ref1    varchar,
    -- p_ref2: 참조값2
    p_ref2    varchar,
    -- p_use_yn: 사용여부
    p_use_yn  varchar,
    -- p_id: JWT 작업자 ID — 감사 컬럼
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 수정 대상의 시스템코드 여부. NULL이면 대상 없음
    v_sys_yn varchar(10);
    -- 중복 검사 건수
    v_cnt    int;
BEGIN
    -- 코드명이 비면(= 화면이 값을 빠뜨림) 기존 이름을 공백으로 덮어쓰게 되므로 막는다
    IF COALESCE(trim(p_code_nm), '') = '' THEN
        RAISE EXCEPTION '코드명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    -- p_idx가 NULL일 때(= 신규 행) 업무키 중복부터 막는다
    IF p_idx IS NULL THEN
        SELECT COUNT(*) INTO v_cnt FROM tbl_code
         WHERE co_cd = p_co_cd AND main_cd = p_main_cd AND sub_cd = p_sub_cd;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 등록된 코드입니다: % / %', p_main_cd, p_sub_cd USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_code(co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, ref2, sys_yn, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_main_cd, p_sub_cd, p_code_nm, COALESCE(p_sort_no, 0),
                p_ref1, p_ref2, 'N', COALESCE(NULLIF(p_use_yn, ''), 'Y'), p_id, now());
        RETURN;
    END IF;

    -- 수정 대상 확인 — 자기 업체 행만 본다. 없으면 테넌트 위반이든 오타든 같은 메시지로 끝낸다
    SELECT sys_yn INTO v_sys_yn
      FROM tbl_code
     WHERE idx = p_idx AND co_cd = p_co_cd;
    IF v_sys_yn IS NULL THEN
        RAISE EXCEPTION '수정할 코드를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 시스템코드일 때(= 시드 고정코드) 코드명·사용여부만 허용한다
    IF v_sys_yn IN ('Y', 'y', 'sys') THEN
        UPDATE tbl_code
           SET code_nm = p_code_nm,
               use_yn  = COALESCE(NULLIF(p_use_yn, ''), use_yn),
               upd_id  = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;
        RETURN;
    END IF;

    UPDATE tbl_code
       SET code_nm = p_code_nm,
           sort_no = COALESCE(p_sort_no, sort_no),
           ref1    = p_ref1,
           ref2    = p_ref2,
           use_yn  = COALESCE(NULLIF(p_use_yn, ''), use_yn),
           upd_id  = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_common_code_management_c_000(varchar, bigint, varchar, varchar, varchar, int, varchar, varchar, varchar, varchar) IS
  '공통코드 저장 — 신규는 업무키 중복 검사, 시스템코드는 코드명·사용여부만. 0000(데모식품) 저장 허용';

-- ------------------------------------------------------------
-- 7. 검증 — 회사는 0000 데모식품만, admin 은 0000, src-ty 는 0000 3건
-- ------------------------------------------------------------
SELECT co_cd, co_nm FROM sasshaccp.tbl_company ORDER BY co_cd;

SELECT user_id, co_cd FROM sasshaccp.tbl_user ORDER BY user_id;

SELECT co_cd, count(*) AS src_ty_cnt
  FROM sasshaccp.tbl_code
 WHERE main_cd = 'src-ty'
 GROUP BY co_cd
 ORDER BY co_cd;
