-- ============================================================
-- 29_migrate_hygiene_form_fix.sql
-- 위생 상세 SP camelCase·DAILY inputType/unitNm 정합
-- 개발자: 박승우 / 일자: 2026-08-06
-- 코멘트:
--   1) sp_tbl_hygiene_document_r_001 재조회 시 DAILY inputType/unitNm, PERSONAL/PEST camelCase
--   2) AREA signers·WATER checkers도 camelCase로 통일한다
--   3) 정본은 19_sp_hygiene.sql 동일 본문
-- ============================================================

SET client_encoding = 'UTF8';
SET search_path TO sasshaccp, public;

CREATE OR REPLACE FUNCTION sp_tbl_hygiene_document_r_001(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 양식코드
    p_tmpl_cd varchar,
    -- p_doc_idx: 기존 문서 idx. NULL/0이면 신규 기본행
    p_doc_idx bigint
) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE v_hdr bigint; v_out jsonb; v_items jsonb;
BEGIN
  IF coalesce(p_doc_idx,0)=0 THEN
    -- 신규일 때(= docIdx 없음) 표준 점검항목에 업체 문구·순서·표시 오버라이드를 덮어 전체 행을 반환한다
    SELECT coalesce(jsonb_agg(jsonb_build_object(
              'rowSeq', coalesce(cci.sort_no, ci.sort_no),
              'itemCd', ci.item_cd,
              'itemNm', coalesce(nullif(cci.item_nm_ovr, ''), ci.item_nm),
              'grpCd', coalesce(ci.grp_cd, ''),
              'grpNm', coalesce(ci.grp_nm, ''),
              'inputType', ci.input_type,
              'unitNm', ci.unit_nm,
              'stdYn', 'Y',
              'judgeCd', null
            ) ORDER BY coalesce(cci.sort_no, ci.sort_no), ci.item_cd), '[]'::jsonb)
      INTO v_items
      FROM tbl_check_item ci
      LEFT JOIN tbl_company_check_item cci
        ON cci.co_cd = p_co_cd AND cci.tmpl_cd = ci.tmpl_cd AND cci.item_cd = ci.item_cd
     WHERE ci.tmpl_cd = p_tmpl_cd
       AND ci.use_yn = 'Y'
       AND coalesce(cci.use_yn, 'Y') = 'Y';
    IF p_tmpl_cd='PEST' THEN
      SELECT coalesce(jsonb_agg(jsonb_build_object('rowSeq',d.sort_no,'pestCd',d.pest_cd,'pestNm',d.pest_nm,'placeNm',d.place_nm,'deviceNgCd','O','flyCnt',0,'mothCnt',0,'mosqCnt',0,'midgeCnt',0,'etcFlyCnt',0,'roachCnt',0,'spiderCnt',0,'antCnt',0,'etcWalkCnt',0,'ratCnt',0,'etcRatCnt',0) ORDER BY d.sort_no),'[]'::jsonb) INTO v_items FROM tbl_pest_device d WHERE d.co_cd=p_co_cd AND d.use_yn='Y';
    END IF;
    RETURN jsonb_build_object('header',null,'entries',v_items,'signers','[]'::jsonb,'checkers','[]'::jsonb);
  END IF;
  SELECT CASE p_tmpl_cd
    WHEN 'DAILY_HYG' THEN (SELECT h.idx FROM tbl_daily_hygiene h WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx)
    WHEN 'PERSONAL_HYG' THEN (SELECT h.idx FROM tbl_personal_hygiene h WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx)
    WHEN 'AREA_HYG' THEN (SELECT h.idx FROM tbl_area_hygiene h WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx)
    WHEN 'PEST' THEN (SELECT h.idx FROM tbl_pest_check h WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx)
    WHEN 'WATER' THEN (SELECT h.idx FROM tbl_water_check h WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx)
  END INTO v_hdr;
  IF v_hdr IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
  SELECT jsonb_build_object('docIdx',d.idx,'docNo',d.doc_no,'baseDt',d.base_dt,'status',d.status) INTO v_out FROM tbl_document d WHERE d.co_cd=p_co_cd AND d.idx=p_doc_idx AND d.del_yn='N';
  IF p_tmpl_cd='DAILY_HYG' THEN
    -- 기존 문서 재조회 — FE NUM/NUM2 분기를 위해 inputType·unitNm을 표준항목과 JOIN한다
    SELECT jsonb_build_object(
             'header', v_out || jsonb_build_object('beforeTime',h.before_time,'duringTime',h.during_time,'checkerNm',h.checker_nm),
             'entries', coalesce(jsonb_agg(jsonb_build_object(
               'rowSeq', i.row_seq,
               'grpCd', i.grp_cd,
               'itemCd', i.item_cd,
               'itemNm', i.item_nm,
               'inputType', coalesce(ci.input_type, 'OX'),
               'unitNm', ci.unit_nm,
               'judgeCd', i.judge_cd,
               'numVal', i.num_val,
               'numVal2', i.num_val2,
               'remark', i.remark,
               'stdYn', CASE WHEN ci.item_cd IS NOT NULL THEN 'Y' ELSE 'N' END
             ) ORDER BY i.row_seq), '[]'::jsonb),
             'signers', '[]'::jsonb,
             'checkers', '[]'::jsonb
           )
      INTO v_out
      FROM tbl_daily_hygiene h
      LEFT JOIN tbl_daily_hygiene_item i ON i.hdr_idx=h.idx AND i.co_cd=h.co_cd
      LEFT JOIN tbl_check_item ci ON ci.tmpl_cd='DAILY_HYG' AND ci.item_cd=i.item_cd
     WHERE h.idx=v_hdr AND h.co_cd=p_co_cd
     GROUP BY h.before_time, h.during_time, h.checker_nm;
  ELSIF p_tmpl_cd='PERSONAL_HYG' THEN
    -- camelCase — 저장 c_000·FE 스칼라 OX 키와 동일
    SELECT jsonb_build_object(
             'header', v_out || jsonb_build_object('checkerNm',h.checker_nm),
             'entries', coalesce(jsonb_agg(jsonb_build_object(
               'rowSeq', r.row_seq,
               'workerUserId', r.worker_user_id,
               'workerNm', r.worker_nm,
               'healthCd', r.health_cd,
               'clothCd', r.cloth_cd,
               'belongingsCd', r.belongings_cd,
               'workerStateCd', r.worker_state_cd,
               'anteroomCd', r.anteroom_cd,
               'handwashCd', r.handwash_cd,
               'remark', r.remark
             ) ORDER BY r.row_seq), '[]'::jsonb),
             'signers', '[]'::jsonb,
             'checkers', '[]'::jsonb
           )
      INTO v_out
      FROM tbl_personal_hygiene h
      LEFT JOIN tbl_personal_hygiene_row r ON r.hdr_idx=h.idx AND r.co_cd=h.co_cd
     WHERE h.idx=v_hdr AND h.co_cd=p_co_cd
     GROUP BY h.checker_nm;
  ELSIF p_tmpl_cd='AREA_HYG' THEN
    SELECT jsonb_build_object(
             'header', v_out || jsonb_build_object('baseDtTo',h.base_dt_to,'areaCd',h.area_cd,'checkerNm',h.checker_nm),
             'entries', coalesce(jsonb_agg(jsonb_build_object(
               'rowSeq', i.row_seq,
               'itemCd', i.item_cd,
               'itemNm', i.item_nm,
               'remark', i.remark,
               'results', (SELECT coalesce(jsonb_agg(jsonb_build_object('checkDt',r.check_dt,'judgeCd',r.judge_cd) ORDER BY r.check_dt),'[]'::jsonb)
                             FROM tbl_area_hygiene_result r WHERE r.item_idx=i.idx AND r.co_cd=i.co_cd)
             ) ORDER BY i.row_seq), '[]'::jsonb),
             'signers', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                          'checkDt', s.check_dt,
                          'writerNm', s.writer_nm,
                          'reviewerNm', s.reviewer_nm,
                          'approverNm', s.approver_nm
                        ) ORDER BY s.check_dt),'[]'::jsonb)
                        FROM tbl_area_hygiene_signer s WHERE s.hdr_idx=h.idx AND s.co_cd=h.co_cd),
             'checkers', '[]'::jsonb
           )
      INTO v_out
      FROM tbl_area_hygiene h
      LEFT JOIN tbl_area_hygiene_item i ON i.hdr_idx=h.idx AND i.co_cd=h.co_cd
     WHERE h.idx=v_hdr AND h.co_cd=p_co_cd
     GROUP BY h.base_dt_to, h.area_cd, h.checker_nm, h.idx;
  ELSIF p_tmpl_cd='PEST' THEN
    -- camelCase 카운트 열 — 신규 기본행·저장 payload와 동일
    SELECT jsonb_build_object(
             'header', v_out || jsonb_build_object('checkerNm',h.checker_nm),
             'entries', coalesce(jsonb_agg(jsonb_build_object(
               'rowSeq', r.row_seq,
               'pestCd', r.pest_cd,
               'pestNm', r.pest_nm,
               'placeNm', r.place_nm,
               'deviceNgCd', r.device_ng_cd,
               'flyCnt', r.fly_cnt,
               'mothCnt', r.moth_cnt,
               'mosqCnt', r.mosq_cnt,
               'midgeCnt', r.midge_cnt,
               'etcFlyCnt', r.etc_fly_cnt,
               'roachCnt', r.roach_cnt,
               'spiderCnt', r.spider_cnt,
               'antCnt', r.ant_cnt,
               'etcWalkCnt', r.etc_walk_cnt,
               'ratCnt', r.rat_cnt,
               'etcRatCnt', r.etc_rat_cnt,
               'remark', r.remark
             ) ORDER BY r.row_seq), '[]'::jsonb),
             'signers', '[]'::jsonb,
             'checkers', '[]'::jsonb
           )
      INTO v_out
      FROM tbl_pest_check h
      LEFT JOIN tbl_pest_check_row r ON r.hdr_idx=h.idx AND r.co_cd=h.co_cd
     WHERE h.idx=v_hdr AND h.co_cd=p_co_cd
     GROUP BY h.checker_nm;
  ELSE
    SELECT jsonb_build_object(
             'header', v_out || jsonb_build_object('baseDtTo',h.base_dt_to,'cycleNm',h.cycle_nm),
             'entries', coalesce(jsonb_agg(jsonb_build_object(
               'rowSeq', i.row_seq,
               'grpCd', i.grp_cd,
               'grpNm', i.grp_nm,
               'itemCd', i.item_cd,
               'itemNm', i.item_nm,
               'results', (SELECT coalesce(jsonb_agg(jsonb_build_object('weekNo',r.week_no,'judgeCd',r.judge_cd) ORDER BY r.week_no),'[]'::jsonb)
                             FROM tbl_water_check_result r WHERE r.item_idx=i.idx AND r.co_cd=i.co_cd)
             ) ORDER BY i.row_seq), '[]'::jsonb),
             'signers', '[]'::jsonb,
             'checkers', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                            'weekNo', c.week_no,
                            'checkDt', c.check_dt,
                            'checkerId', c.checker_id,
                            'checkerNm', c.checker_nm
                          ) ORDER BY c.week_no),'[]'::jsonb)
                          FROM tbl_water_check_checker c WHERE c.hdr_idx=h.idx AND c.co_cd=h.co_cd)
           )
      INTO v_out
      FROM tbl_water_check h
      LEFT JOIN tbl_water_check_item i ON i.hdr_idx=h.idx AND i.co_cd=h.co_cd
     WHERE h.idx=v_hdr AND h.co_cd=p_co_cd
     GROUP BY h.base_dt_to, h.cycle_nm, h.idx;
  END IF;
  RETURN v_out;
END$$;

