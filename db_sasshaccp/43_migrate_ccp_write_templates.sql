-- ============================================================
-- 43 — CCP 작성 템플릿 정합 (가열·멸균·여과 회사양식 ON + 멸균 diary)
--
-- 개발자: 박승우
-- 일자: 2026-08-07
-- 코멘트:
--   1) DEMO 등 업체에서 tmpl_ccp-heat-log/SANITIZE/FILTER 사용양식이 N이라 템플릿 API가 비었다
--   2) 멸균(LMTITMST)을 소독/헹굼(LMTITMCP)과 분리한 공공 기준일지를 추가한다
--   3) tmpl_ccp-sanitize-log 대표 매핑을 멸균 일지로 바꾼다 (화면명 멸균관리)
-- ============================================================

SET search_path TO sasshaccp;

-- 1) 멸균 전용 공공 기준일지
INSERT INTO tbl_smart_diary_type (
    diary_no, diary_nm, diary_type, limit_item_kind, infra_use_yn, question_use_yn, archive_year_cnt,
    critical_limit_cn, monitoring_cycle_cn, monitoring_method_cn, improvement_method_cn, use_yn, sort_no, ins_id
) VALUES
    ('W0061', '중요관리점관리(멸균-수기)', 'CCP_DOC', 'LMTITMST', 'N', 'N', 0,
     '○ 시작온도·종료온도·총 멸균시간',
     '배치마다(작업 시작·종료)',
     '멸균기 판넬 온도와 타이머로 시작/종료온도·총 멸균시간을 확인하고 기록한다.',
     '한계기준 이탈 시 재멸균 후 이탈내용과 개선조치를 기록한다.', 'Y', 62, 'system'),
    ('C0061', '중요관리점관리(멸균)', 'CCP_DOC', 'LMTITMST', 'Y', 'Y', 0,
     '○ 시작온도·종료온도·총 멸균시간',
     '배치마다(작업 시작·종료)',
     '멸균기 설비 값과 타이머로 시작/종료온도·총 멸균시간을 확인하고 기록한다.',
     '한계기준 이탈 시 재멸균 후 이탈내용과 개선조치를 기록한다.', 'Y', 63, 'system')
ON CONFLICT (diary_no) DO UPDATE SET
    diary_nm = EXCLUDED.diary_nm,
    limit_item_kind = EXCLUDED.limit_item_kind,
    critical_limit_cn = EXCLUDED.critical_limit_cn,
    monitoring_cycle_cn = EXCLUDED.monitoring_cycle_cn,
    monitoring_method_cn = EXCLUDED.monitoring_method_cn,
    improvement_method_cn = EXCLUDED.improvement_method_cn,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 2) tmpl_ccp-sanitize-log → 멸균 매핑 (기존 소독 C0060 preferred 해제)
UPDATE tbl_smart_diary_map
   SET preferred_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE tmpl_cd = 'tmpl_ccp-sanitize-log'
   AND diary_no IN ('W0060', 'C0060');

INSERT INTO tbl_smart_diary_map (diary_no, tmpl_cd, match_level, impl_status, preferred_yn, ins_id)
VALUES
    ('W0061', 'tmpl_ccp-sanitize-log', 'FULL', 'GENERIC_CCP', 'N', 'system'),
    ('C0061', 'tmpl_ccp-sanitize-log', 'FULL', 'GENERIC_CCP', 'Y', 'system')
ON CONFLICT (diary_no, tmpl_cd) DO UPDATE SET
    match_level = EXCLUDED.match_level,
    impl_status = EXCLUDED.impl_status,
    preferred_yn = EXCLUDED.preferred_yn,
    upd_id = 'system',
    upd_dt = now();

-- 3) 템플릿 표시명 — 멸균
UPDATE tbl_template
   SET tmpl_nm = '멸균 모니터링 일지',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'tmpl_ccp-sanitize-log';

UPDATE tbl_screen
   SET scrn_nm = '멸균 CCP 모니터링 일지',
       upd_id = 'system',
       upd_dt = now()
 WHERE scrn_cd = 'ccp-sanitize-monitor';

-- 4) 작성 leaf 회사양식 ON — 전 활성 업체
INSERT INTO tbl_company_template (co_cd, tmpl_cd, cycle_cd, retention_month, use_yn, appr_line_cd, ins_id, ins_dt)
SELECT c.co_cd, t.tmpl_cd, coalesce(t.default_cycle_cd, 'D'), coalesce(t.default_retention_month, 24),
       'Y', 'DEFAULT', 'system', now()
  FROM tbl_company c
  CROSS JOIN tbl_template t
 WHERE c.use_yn = 'Y'
   AND t.tmpl_cd IN ('tmpl_ccp-heat-log', 'tmpl_ccp-sanitize-log', 'tmpl_ccp-filter-log')
   AND t.use_yn = 'Y'
ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 5) 화면 메뉴명 정합 (있을 때)
UPDATE tbl_menu
   SET menu_nm = CASE menu_cd
        WHEN 'ccp-heat-monitor' THEN '가열 CCP 모니터링 일지'
        WHEN 'ccp-sanitize-monitor' THEN '멸균 CCP 모니터링 일지'
        WHEN 'ccp-filter-monitor' THEN '여과 CCP 모니터링 일지'
        ELSE menu_nm
       END,
       upd_id = 'system',
       upd_dt = now()
 WHERE menu_cd IN ('ccp-heat-monitor', 'ccp-sanitize-monitor', 'ccp-filter-monitor');

-- 6) LIMIT_ITEM_KIND — 멸균 코드
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, sys_yn, ins_id)
VALUES ('0000', 'LIMIT_ITEM_KIND', 'LMTITMST', '멸균', 6, 'STERILIZE', 'Y', 'system')
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
    code_nm = EXCLUDED.code_nm,
    ref1 = EXCLUDED.ref1,
    sys_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 7) 공통 CCP 행 — 서명 경로 R/C
CREATE OR REPLACE FUNCTION sp_tbl_ccp_generic_monitor_r_000(
    p_co_cd varchar,
    p_doc_idx bigint
)
RETURNS TABLE (
    doc_idx bigint,
    doc_no varchar,
    status varchar,
    base_dt varchar,
    tmpl_cd varchar,
    ccp_cd varchar,
    diary_no varchar,
    limit_item_kind varchar,
    mng_user_id varchar,
    mng_nm varchar,
    rows_json jsonb
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT d.idx AS doc_idx,
           d.doc_no,
           d.status,
           m.base_dt,
           m.tmpl_cd,
           m.ccp_cd,
           m.diary_no,
           m.limit_item_kind,
           m.mng_user_id,
           m.mng_nm,
           COALESCE((
               SELECT jsonb_agg(
                          jsonb_build_object(
                              'rowSeq', r.row_seq,
                              'checkTime', COALESCE(r.check_time, ''),
                              'equipNm', COALESCE(r.equip_nm, ''),
                              'productNm', COALESCE(r.product_nm, ''),
                              'judgeCd', r.judge_cd,
                              'judgeModYn', r.judge_mod_yn,
                              'checkerId', COALESCE(r.checker_id, ''),
                              'checkerNm', COALESCE(r.checker_nm, ''),
                              'signPath', COALESCE(r.sign_path, ''),
                              'cells', COALESCE((
                                  SELECT jsonb_agg(
                                             jsonb_build_object(
                                                 'itemCd', c.item_cd,
                                                 'numVal', c.num_val,
                                                 'txtVal', COALESCE(c.txt_val, ''),
                                                 'judgeCd', c.judge_cd
                                             )
                                             ORDER BY c.item_cd
                                         )
                                    FROM tbl_ccp_generic_monitor_cell c
                                   WHERE c.row_idx = r.idx
                                     AND c.co_cd = r.co_cd
                              ), '[]'::jsonb)
                          )
                          ORDER BY r.row_seq
                      )
                 FROM tbl_ccp_generic_monitor_row r
                WHERE r.monitor_idx = m.idx
                  AND r.co_cd = m.co_cd
           ), '[]'::jsonb) AS rows_json
      FROM tbl_document d
      JOIN tbl_ccp_generic_monitor m
        ON m.doc_idx = d.idx
       AND m.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd
       AND d.idx = p_doc_idx
       AND d.del_yn = 'N';
END;
$$;

CREATE OR REPLACE FUNCTION sp_tbl_ccp_generic_monitor_c_000(
    p_co_cd varchar,
    p_doc_idx bigint,
    p_base_dt varchar,
    p_tmpl_cd varchar,
    p_ccp_cd varchar,
    p_diary_no varchar,
    p_limit_item_kind varchar,
    p_mng_user_id varchar,
    p_mng_nm varchar,
    p_rows jsonb,
    p_id varchar
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_doc_idx bigint;
    v_monitor_idx bigint;
    v_doc_no varchar;
    v_title varchar(300);
    v_row jsonb;
    v_cell jsonb;
    v_row_idx bigint;
BEGIN
    IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) = 0 THEN
        RAISE EXCEPTION '점검 행이 없습니다.' USING ERRCODE = '45000';
    END IF;
    SELECT coalesce(nullif(t.tmpl_nm, ''), '공통 CCP 모니터링') INTO v_title
      FROM tbl_template t WHERE t.tmpl_cd = p_tmpl_cd AND t.doc_kind = 'DB' AND t.use_yn = 'Y';
    IF v_title IS NULL THEN
        RAISE EXCEPTION '사용할 공통 CCP 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000';
    END IF;

    IF coalesce(p_doc_idx, 0) <= 0 THEN
        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd, p_tmpl_cd, p_base_dt);
        INSERT INTO tbl_document (
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status, writer_id, form_src, ins_id
        ) VALUES (
            p_co_cd, p_tmpl_cd, 'DB', v_doc_no, p_base_dt, v_title, 'WRK', p_id, 'BASE', p_id
        ) RETURNING idx INTO v_doc_idx;
        INSERT INTO tbl_ccp_generic_monitor (
            co_cd, doc_idx, base_dt, tmpl_cd, ccp_cd, diary_no, limit_item_kind, mng_user_id, mng_nm, ins_id
        ) VALUES (
            p_co_cd, v_doc_idx, p_base_dt, p_tmpl_cd, nullif(p_ccp_cd, ''), nullif(p_diary_no, ''),
            nullif(p_limit_item_kind, ''), nullif(p_mng_user_id, ''), nullif(p_mng_nm, ''), p_id
        ) RETURNING idx INTO v_monitor_idx;
    ELSE
        SELECT m.idx INTO v_monitor_idx
          FROM tbl_ccp_generic_monitor m
          JOIN tbl_document d ON d.idx = m.doc_idx
         WHERE m.co_cd = p_co_cd AND m.doc_idx = p_doc_idx AND d.del_yn = 'N' AND d.status IN ('WRK', 'RJT');
        IF v_monitor_idx IS NULL THEN
            RAISE EXCEPTION '수정할 임시 또는 반려 문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_doc_idx := p_doc_idx;
        UPDATE tbl_document SET base_dt = p_base_dt, title = v_title, upd_id = p_id, upd_dt = now()
         WHERE idx = v_doc_idx AND co_cd = p_co_cd;
        UPDATE tbl_ccp_generic_monitor
           SET base_dt = p_base_dt, tmpl_cd = p_tmpl_cd, ccp_cd = nullif(p_ccp_cd, ''),
               diary_no = nullif(p_diary_no, ''), limit_item_kind = nullif(p_limit_item_kind, ''),
               mng_user_id = nullif(p_mng_user_id, ''), mng_nm = nullif(p_mng_nm, ''), upd_id = p_id, upd_dt = now()
         WHERE idx = v_monitor_idx AND co_cd = p_co_cd;
        DELETE FROM tbl_ccp_generic_monitor_cell c
         USING tbl_ccp_generic_monitor_row r
         WHERE c.row_idx = r.idx AND r.monitor_idx = v_monitor_idx AND r.co_cd = p_co_cd;
        DELETE FROM tbl_ccp_generic_monitor_row WHERE monitor_idx = v_monitor_idx AND co_cd = p_co_cd;
    END IF;

    FOR v_row IN SELECT value FROM jsonb_array_elements(p_rows)
    LOOP
        INSERT INTO tbl_ccp_generic_monitor_row (
            co_cd, monitor_idx, row_seq, check_time, equip_nm, product_nm,
            judge_cd, judge_mod_yn, checker_id, checker_nm, sign_path, ins_id
        ) VALUES (
            p_co_cd, v_monitor_idx, coalesce(nullif(v_row->>'rowSeq', '')::int, 0), nullif(v_row->>'checkTime', ''),
            nullif(v_row->>'equipNm', ''), nullif(v_row->>'productNm', ''),
            nullif(v_row->>'judgeCd', ''), coalesce(nullif(v_row->>'judgeModYn', ''), 'N'),
            nullif(v_row->>'checkerId', ''), nullif(v_row->>'checkerNm', ''),
            nullif(v_row->>'signPath', ''), p_id
        ) RETURNING idx INTO v_row_idx;
        FOR v_cell IN SELECT value FROM jsonb_array_elements(coalesce(v_row->'cells', '[]'::jsonb))
        LOOP
            INSERT INTO tbl_ccp_generic_monitor_cell (
                co_cd, row_idx, item_cd, num_val, txt_val, judge_cd, ins_id
            ) VALUES (
                p_co_cd, v_row_idx, v_cell->>'itemCd', nullif(v_cell->>'numVal', '')::numeric,
                nullif(v_cell->>'txtVal', ''), nullif(v_cell->>'judgeCd', ''), p_id
            );
        END LOOP;
    END LOOP;
    RETURN v_doc_idx;
END;
$$;
