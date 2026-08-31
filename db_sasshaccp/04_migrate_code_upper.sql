-- ============================================================
--  04_migrate_code_upper.sql — 공통코드 sub_cd 와 저장값을 UPPER_SNAKE 로
--
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) sub_cd 는 업무 표에 저장되는 값을 미러한다. 그래서 코드와 데이터를 같이 올린다
--       한쪽만 올리면 라벨이 안 붙고 콤보가 빈 값이 된다
--    2) input_type 은 이미 뒤섞여 있었다 — 구형 대문자(JUDGE·NUM2·OX·YN)와
--       신형 소문자(num·radio·text)가 같은 컬럼에 공존했다. 이번에 한 벌로 맞춘다
--    3) 한 번 돌린 DB 에 다시 돌려도 안전하다 — 이미 대문자면 그대로다
--
--  AUDIT_TARGET 은 sp_audit_log_r_000 이 읽는다. 03_code_seed.sql 에 두고 지우지 않는다.
--  sub_cd 는 테이블명(tbl_code)이라 소문자 그대로 둔다 — 04 의 UPPER 변환 대상이 아니다.
--
--  적용: psql -f 04_migrate_code_upper.sql   (03_code_seed.sql 보다 먼저)
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

-- ------------------------------------------------------------
-- 1. 지면 입력유형 — 구형·신형 혼재를 한 벌로
--    JUDGE·OX·YN → RADIO · NUM2 → RADIO_NUM · radio-num → RADIO_NUM
-- ------------------------------------------------------------
CREATE TEMP TABLE tmp_input_ty(old_v varchar(20), new_v varchar(20)) ON COMMIT DROP;
INSERT INTO tmp_input_ty VALUES
    ('radio', 'RADIO'), ('YN', 'RADIO'), ('OX', 'RADIO'), ('JUDGE', 'RADIO'),
    ('radio-num', 'RADIO_NUM'), ('YN_NUM', 'RADIO_NUM'), ('NUM2', 'RADIO_NUM'),
    ('radio-text', 'RADIO_TEXT'), ('YN_TEXT', 'RADIO_TEXT'),
    ('num', 'NUM'), ('text', 'TEXT');

DO $$
DECLARE
    v_tbl text;
BEGIN
    FOREACH v_tbl IN ARRAY ARRAY[
        'tbl_check_item', 'tbl_html_form_ver_item', 'tbl_html_hyg_prc_ver_item',
        'tbl_hyg_process_item', 'tbl_ccp_verify_item',
        'tbl_tml_ccp_chk_ver_item', 'tbl_tml_ccp_pkg_ver_item',
        'tbl_tml_ccp_htg_ver_item', 'tbl_tml_ccp_mtl_ver_item'
    ]
    LOOP
        EXECUTE format(
            'UPDATE %I t SET input_type = m.new_v FROM tmp_input_ty m WHERE t.input_type = m.old_v',
            v_tbl
        );
        -- 표에 없던 값은 라디오로 모은다 (지면이 기본으로 삼는 유형)
        EXECUTE format(
            'UPDATE %I SET input_type = ''RADIO'' WHERE input_type IS NOT NULL '
            || 'AND input_type <> '''' AND input_type !~ ''^[A-Z_]+$''',
            v_tbl
        );
    END LOOP;
END$$;

-- ------------------------------------------------------------
-- 2. 비영업일 처리 — tbl_schedule_rule.nonwork_rule
-- ------------------------------------------------------------
UPDATE tbl_schedule_rule
   SET nonwork_rule = upper(nonwork_rule), upd_id = 'system', upd_dt = now()
 WHERE nonwork_rule IS NOT NULL AND nonwork_rule <> upper(nonwork_rule);

-- ------------------------------------------------------------
-- 3. 양식 타입 — doc_kind. FE lib/docKind.ts 상수와 같이 올린다
-- ------------------------------------------------------------
UPDATE tbl_template  SET doc_kind = upper(doc_kind) WHERE doc_kind <> upper(doc_kind);
UPDATE tbl_document  SET doc_kind = upper(doc_kind) WHERE doc_kind <> upper(doc_kind);

-- ------------------------------------------------------------
-- 4. 지면 예/아니오 — tbl_*_item.yn
-- ------------------------------------------------------------
UPDATE tbl_hyg_process_item SET yn = upper(yn)
 WHERE yn IS NOT NULL AND yn <> upper(yn);
-- 검증점검은 칸 이름이 answer_cd 다
UPDATE tbl_ccp_verify_item  SET answer_cd = upper(answer_cd)
 WHERE answer_cd IS NOT NULL AND answer_cd <> upper(answer_cd);

-- ------------------------------------------------------------
-- 5. 공통코드 sub_cd — 위 데이터와 같은 규칙으로
-- ------------------------------------------------------------
UPDATE tbl_code
   SET sub_cd = replace(upper(sub_cd), '-', '_'), upd_id = 'system', upd_dt = now()
 WHERE sub_cd <> '*'
   AND sub_cd <> replace(upper(sub_cd), '-', '_');

COMMIT;

-- 확인용 — 모두 대문자여야 한다
-- SELECT DISTINCT input_type FROM tbl_check_item ORDER BY 1;
-- SELECT DISTINCT nonwork_rule FROM tbl_schedule_rule;
-- SELECT DISTINCT doc_kind FROM tbl_document UNION SELECT DISTINCT doc_kind FROM tbl_template;
-- SELECT main_cd, sub_cd FROM tbl_code WHERE sub_cd ~ '[a-z]' ORDER BY 1,2;   -- 0건이어야 한다
