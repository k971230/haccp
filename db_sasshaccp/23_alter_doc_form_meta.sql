-- ============================================================
-- 23_alter_doc_form_meta.sql
-- PDF 문서형 메타·푸터 컬럼 보강 (기존 DB 적용용)
-- ============================================================

ALTER TABLE tbl_ccp_limit
    ADD COLUMN IF NOT EXISTS form_title text NULL;
ALTER TABLE tbl_ccp_limit
    ADD COLUMN IF NOT EXISTS cycle_rmk text NULL;

COMMENT ON COLUMN tbl_ccp_limit.form_title IS '일지 상단 제목 — CCP 콤보 변경 시 DocPaper 제목에 표시';
COMMENT ON COLUMN tbl_ccp_limit.cycle_rmk  IS '주기 서술 문구 — A4 문서 상단 주기란에 그대로 출력';

ALTER TABLE tbl_corrective_action
    ADD COLUMN IF NOT EXISTS action_user_nm varchar(50) NULL;
ALTER TABLE tbl_corrective_action
    ADD COLUMN IF NOT EXISTS confirm_user_nm varchar(50) NULL;

COMMENT ON COLUMN tbl_corrective_action.action_user_nm  IS '조치자 표시명 — A4 푸터 서명란 자유입력';
COMMENT ON COLUMN tbl_corrective_action.confirm_user_nm IS '확인자 표시명 — A4 푸터 확인란 자유입력';

-- DEMO 등 기존 한계기준 문구·제목 보강
-- form_title은 회사마다 CCP 코드(1B·2P 등)가 다르므로 코드 없는 일반 명칭만 쓴다
-- 냉장·냉동 통합 명칭으로 맞춘다(구 '냉장보관' 제목도 교체)
UPDATE tbl_ccp_limit SET
    form_title = 'CCP 냉장·냉동 보관 모니터링 일지',
    cycle_rmk  = COALESCE(NULLIF(cycle_rmk, ''), '작업 시작 시, 작업 종료 전, 작업 중 2시간마다(또는 작업 중 0회)'),
    limit_rmk  = COALESCE(NULLIF(limit_rmk, ''), '보관온도 : -2 ~ 5℃'),
    method_rmk = COALESCE(NULLIF(method_rmk, ''), '냉장보관고 온도표시기의 온도를 확인하고 기록한다.')
 WHERE ccp_cd = 'CCP-1B'
    OR (limit_type = 'TEMP_RANGE' AND ccp_cd NOT IN ('CCP-3B', 'CCP-2P'));

-- 완제품 냉장·냉동 CCP — 콤보 변경 시 한계·방법이 구분되도록 문구를 분리한다
UPDATE tbl_ccp_limit SET
    form_title = 'CCP 냉장·냉동 보관 모니터링 일지',
    ccp_nm     = COALESCE(NULLIF(ccp_nm, ''), '완제품 냉장·냉동보관'),
    proc_nm    = COALESCE(NULLIF(proc_nm, ''), '완제품 냉장·냉동보관'),
    cycle_rmk  = COALESCE(NULLIF(cycle_rmk, ''), '작업 시작 시, 작업 종료 전, 작업 중 2시간마다(또는 작업 중 0회)'),
    limit_rmk  = '보관온도 : -2 ～ 5℃ (냉장) / -18℃ 이하 (냉동)',
    method_rmk = '모니터링담당자는 냉장·냉동보관고 온도표시장치의 표시된 온도를 확인하고 일지에 기록한다.'
 WHERE ccp_cd = 'CCP-3B';

-- 화면·양식·업체 메뉴 표시명 — 냉장·냉동 보관
UPDATE tbl_screen SET scrn_nm = '냉장·냉동 보관'
 WHERE scrn_cd = 'ccp-cold-monitor';
UPDATE tbl_template SET tmpl_nm = 'CCP 냉장·냉동 보관 모니터링 일지'
 WHERE tmpl_cd = 'CCP_COLD';
UPDATE tbl_menu SET menu_nm = '냉장·냉동 보관'
 WHERE scrn_cd = 'ccp-cold-monitor'
    OR menu_cd = 'ccp-cold-monitor';

-- 샘플 냉동 보관고 — 없으면 추가(기존 회사 DEMO 포함)
INSERT INTO tbl_storage (
    co_cd, storage_cd, storage_nm, storage_type, ccp_cd, temp_min, temp_max, sort_no, use_yn, ins_id, ins_dt
)
SELECT c.co_cd, 'ST04', '완제품냉동1', 'FROZEN', 'CCP-3B', -23, -18, 4, 'Y', 'system', now()
  FROM tbl_company c
 WHERE NOT EXISTS (
       SELECT 1 FROM tbl_storage s
        WHERE s.co_cd = c.co_cd AND s.storage_cd = 'ST04'
   );

UPDATE tbl_ccp_limit SET
    form_title = CASE
        WHEN form_title IS NULL OR TRIM(form_title) = '' OR form_title LIKE 'CCP-%(%'
            THEN 'CCP 금속검출 모니터링 일지'
        ELSE form_title
    END,
    cycle_rmk  = COALESCE(NULLIF(cycle_rmk, ''),
        E'금속검출기 정상작동 여부 확인 : 작업시작 전, 작업 중 0시간마다, 작업 종료 후\n금속검출기에 의한 공정품 확인 : 작업 중 상시'),
    limit_rmk  = COALESCE(NULLIF(limit_rmk, ''),
        'Fe ' || COALESCE(fe_size::text, '0.0') || ' ㎜, STS ' || COALESCE(sts_size::text, '0.0') || ' ㎜ 이상 불검출'),
    method_rmk = COALESCE(NULLIF(method_rmk, ''),
        E'기기감도 : 모니터링담당자는 기기 중간에 시편을 통과시켜 검출여부를 확인하고 일지에 기록한다.\n제품감도 : 모니터링담당자는 제품 중간에 시편을 넣고 기기에 통과시켜 검출여부를 확인하고 일지에 기록한다.\n통과량 및 검출량 : 모니터링담당자는 통과된 양과 검출된 양을 일지에 기록하고 HACCP팀장에 보고한다.')
 WHERE ccp_cd = 'CCP-2P'
    OR limit_type = 'METAL';

-- ------------------------------------------------------------
-- 문서 단위 이탈 푸터 upsert — 네 칸이 모두 비면 삭제
-- p_payload: { deviationDesc, actionDesc, actionUserNm, confirmUserNm }
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_doc_corrective_u_000(
    p_co_cd   varchar,
    p_doc_idx bigint,
    p_tmpl_cd varchar,
    p_base_dt varchar,
    p_payload jsonb,
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_dev   text;
    v_act   text;
    v_anm   varchar(50);
    v_cnm   varchar(50);
    v_empty boolean;
    v_idx   bigint;
    v_no    varchar(50);
BEGIN
    IF p_doc_idx IS NULL OR p_doc_idx <= 0 THEN
        RAISE EXCEPTION '문서번호가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;

    v_dev := COALESCE(p_payload->>'deviationDesc', '');
    v_act := COALESCE(p_payload->>'actionDesc', '');
    v_anm := NULLIF(TRIM(COALESCE(p_payload->>'actionUserNm', '')), '');
    v_cnm := NULLIF(TRIM(COALESCE(p_payload->>'confirmUserNm', '')), '');
    v_empty := (TRIM(v_dev) = '' AND TRIM(v_act) = '' AND v_anm IS NULL AND v_cnm IS NULL);

    IF v_empty THEN
        DELETE FROM tbl_corrective_action
         WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx;
        RETURN;
    END IF;

    SELECT idx INTO v_idx
      FROM tbl_corrective_action
     WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx
     ORDER BY idx
     LIMIT 1;

    IF v_idx IS NULL THEN
        v_no := 'CA-' || COALESCE(NULLIF(p_base_dt, ''), to_char(current_date, 'YYYYMMDD'))
                || '-' || lpad((
                    SELECT (count(*) + 1)::text
                      FROM tbl_corrective_action
                     WHERE co_cd = p_co_cd
                       AND occur_dt = COALESCE(NULLIF(p_base_dt, ''), to_char(current_date, 'YYYYMMDD'))
                ), 3, '0');
        INSERT INTO tbl_corrective_action(
            co_cd, ca_no, src_tmpl_cd, src_doc_idx, occur_dt,
            deviation_desc, action_desc, action_user_nm, confirm_user_nm,
            status, ins_id, ins_dt
        ) VALUES (
            p_co_cd, v_no, NULLIF(p_tmpl_cd, ''), p_doc_idx,
            COALESCE(NULLIF(p_base_dt, ''), to_char(current_date, 'YYYYMMDD')),
            v_dev, NULLIF(v_act, ''), v_anm, v_cnm,
            CASE WHEN TRIM(v_act) = '' THEN 'OPEN' ELSE 'ING' END,
            p_id, now()
        );
    ELSE
        UPDATE tbl_corrective_action SET
            src_tmpl_cd     = COALESCE(NULLIF(p_tmpl_cd, ''), src_tmpl_cd),
            occur_dt        = COALESCE(NULLIF(p_base_dt, ''), occur_dt),
            deviation_desc  = v_dev,
            action_desc     = NULLIF(v_act, ''),
            action_user_nm  = v_anm,
            confirm_user_nm = v_cnm,
            status          = CASE WHEN TRIM(v_act) = '' THEN 'OPEN' ELSE 'ING' END,
            upd_id          = p_id,
            upd_dt          = now()
         WHERE idx = v_idx AND co_cd = p_co_cd;
    END IF;
END$$;

COMMENT ON PROCEDURE sp_tbl_doc_corrective_u_000(varchar, bigint, varchar, varchar, jsonb, varchar)
IS '문서형 일지 이탈 푸터 upsert — 빈 값이면 해당 문서 CA 삭제';

CREATE OR REPLACE FUNCTION sp_tbl_doc_corrective_r_000(
    p_co_cd   varchar,
    p_doc_idx bigint
)
RETURNS TABLE (
    idx             bigint,
    deviation_desc  text,
    action_desc     text,
    action_user_nm  varchar,
    confirm_user_nm varchar,
    status          varchar
)
LANGUAGE sql STABLE AS $$
    SELECT ca.idx, ca.deviation_desc, ca.action_desc,
           ca.action_user_nm, ca.confirm_user_nm, ca.status
      FROM tbl_corrective_action ca
     WHERE ca.co_cd = p_co_cd
       AND ca.src_doc_idx = p_doc_idx
     ORDER BY ca.idx
     LIMIT 1;
$$;

COMMENT ON FUNCTION sp_tbl_doc_corrective_r_000(varchar, bigint)
IS '문서형 일지 이탈 푸터 단건 조회';
