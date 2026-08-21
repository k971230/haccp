-- ============================================================
-- 105 — HTML 양식 입력유형·예/아니오 공통코드
--
-- 파일번호: 105
-- 이전번호: 104
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) 예/아니오 라디오 문구는 judge-yn(y/n). 입력유형 5종은 html-input-ty
--   2) html_sys_001·버전·작성 항목의 옛 YN/YN_NUM/NUM/TEXT 를 kebab 로 치환
--   3) 104 재실행 금지. 코드는 0000 후 전 업체 복제
--
-- ============================================================

SET search_path TO sasshaccp;

ALTER TABLE tbl_check_item
    ALTER COLUMN input_type TYPE varchar(20);
ALTER TABLE tbl_html_form_ver_item
    ALTER COLUMN input_type TYPE varchar(20);
ALTER TABLE tbl_html_form_ver_item
    ALTER COLUMN input_type SET DEFAULT 'radio';
ALTER TABLE tbl_hyg_process_item
    ALTER COLUMN input_type TYPE varchar(20);
ALTER TABLE tbl_hyg_process_item
    ALTER COLUMN input_type SET DEFAULT 'radio';

COMMENT ON COLUMN tbl_html_form_ver_item.input_type IS
    'html-input-ty — radio / radio-num / radio-text / num / text';
COMMENT ON COLUMN tbl_hyg_process_item.input_type IS
    'html-input-ty — radio / radio-num / radio-text / num / text';

INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, sys_yn, use_yn, ins_id) VALUES
    ('0000', 'judge-yn', '*',          '예아니오',     0, 'Y', 'Y', 'system'),
    ('0000', 'judge-yn', 'y',          '예',           1, 'Y', 'Y', 'system'),
    ('0000', 'judge-yn', 'n',          '아니오',       2, 'Y', 'Y', 'system'),
    ('0000', 'html-input-ty', '*',     'HTML입력유형', 0, 'Y', 'Y', 'system'),
    ('0000', 'html-input-ty', 'radio',      '라디오',       1, 'Y', 'Y', 'system'),
    ('0000', 'html-input-ty', 'radio-num',  '라디오 숫자',  2, 'Y', 'Y', 'system'),
    ('0000', 'html-input-ty', 'radio-text', '라디오 문자',  3, 'Y', 'Y', 'system'),
    ('0000', 'html-input-ty', 'num',        '숫자',         4, 'Y', 'Y', 'system'),
    ('0000', 'html-input-ty', 'text',       '문자',         5, 'Y', 'Y', 'system')
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE
    SET code_nm = EXCLUDED.code_nm,
        sort_no = EXCLUDED.sort_no,
        use_yn  = 'Y',
        upd_id  = 'system',
        upd_dt  = now();

DO $$
DECLARE
    v_co record;
BEGIN
    FOR v_co IN
        SELECT co_cd FROM tbl_company WHERE co_cd <> '0000' ORDER BY co_cd
    LOOP
        -- 업체가 없는 (main,sub)만 넣는다 — 이미 고친 코드명은 유지
        CALL sp_tbl_company_code_copy_c_000(v_co.co_cd, 'system');
    END LOOP;
END$$;

UPDATE tbl_check_item
   SET input_type = CASE upper(input_type)
            WHEN 'YN' THEN 'radio'
            WHEN 'YN_NUM' THEN 'radio-num'
            WHEN 'YN_TEXT' THEN 'radio-text'
            WHEN 'NUM' THEN 'num'
            WHEN 'TEXT' THEN 'text'
            ELSE input_type
        END,
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'html_sys_001'
   AND upper(input_type) IN ('YN', 'YN_NUM', 'YN_TEXT', 'NUM', 'TEXT');

UPDATE tbl_html_form_ver_item
   SET input_type = CASE upper(input_type)
            WHEN 'YN' THEN 'radio'
            WHEN 'YN_NUM' THEN 'radio-num'
            WHEN 'YN_TEXT' THEN 'radio-text'
            WHEN 'NUM' THEN 'num'
            WHEN 'TEXT' THEN 'text'
            ELSE input_type
        END
 WHERE upper(input_type) IN ('YN', 'YN_NUM', 'YN_TEXT', 'NUM', 'TEXT');

UPDATE tbl_hyg_process_item
   SET input_type = CASE upper(input_type)
            WHEN 'YN' THEN 'radio'
            WHEN 'YN_NUM' THEN 'radio-num'
            WHEN 'YN_TEXT' THEN 'radio-text'
            WHEN 'NUM' THEN 'num'
            WHEN 'TEXT' THEN 'text'
            ELSE input_type
        END
 WHERE upper(input_type) IN ('YN', 'YN_NUM', 'YN_TEXT', 'NUM', 'TEXT');
