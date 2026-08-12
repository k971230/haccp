-- ============================================================
-- 위생관리 DB형 양식 5종 저장프로시저
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) tmpl_prp-hygiene-daily, tmpl_prp-hygiene-personal, tmpl_prp-hygiene-area, PEST, WATER를 한 API 계약으로 저장한다
--   2) 행·판정은 JSON으로 받고 각 양식의 정규화 테이블에 전체 교체로 보관한다
--   3) 문서 상태가 임시·반려가 아니면 저장·삭제를 차단한다
-- ============================================================
SET search_path TO sasshaccp;

-- 목록 — 기준일·문서번호·작성자 부분검색.
DROP FUNCTION IF EXISTS sp_tbl_hygiene_document_r_000(varchar, varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_tbl_hygiene_document_r_000(
    p_co_cd varchar,
    p_tmpl_cd varchar,
    p_from_dt varchar,
    p_to_dt varchar,
    p_doc_no varchar DEFAULT '',
    p_writer varchar DEFAULT ''
) RETURNS TABLE(doc_idx bigint, hdr_idx bigint, doc_no varchar, base_dt varchar, base_dt_to varchar,
                checker_nm varchar, status varchar, row_cnt int, ng_cnt int)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, x.hdr_idx, d.doc_no, x.base_dt, x.base_dt_to, x.checker_nm, d.status,
           x.row_cnt, x.ng_cnt
      FROM tbl_document d
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
      JOIN LATERAL (
          SELECT h.idx hdr_idx, h.base_dt, NULL::varchar base_dt_to, h.checker_nm,
                 (SELECT count(*)::int FROM tbl_daily_hygiene_item i WHERE i.hdr_idx=h.idx AND i.co_cd=h.co_cd) row_cnt,
                 (SELECT count(*)::int FROM tbl_daily_hygiene_item i WHERE i.hdr_idx=h.idx AND i.co_cd=h.co_cd AND i.judge_cd='X') ng_cnt
            FROM tbl_daily_hygiene h WHERE p_tmpl_cd='tmpl_prp-hygiene-daily' AND h.doc_idx=d.idx AND h.co_cd=d.co_cd
          UNION ALL
          SELECT h.idx, h.base_dt, NULL, h.checker_nm,
                 (SELECT count(*)::int FROM tbl_personal_hygiene_row r WHERE r.hdr_idx=h.idx AND r.co_cd=h.co_cd),
                 (SELECT count(*)::int FROM tbl_personal_hygiene_row r WHERE r.hdr_idx=h.idx AND r.co_cd=h.co_cd
                   AND 'X' IN (r.health_cd,r.cloth_cd,r.belongings_cd,r.worker_state_cd,r.anteroom_cd,r.handwash_cd))
            FROM tbl_personal_hygiene h WHERE p_tmpl_cd='tmpl_prp-hygiene-personal' AND h.doc_idx=d.idx AND h.co_cd=d.co_cd
          UNION ALL
          SELECT h.idx, h.base_dt, h.base_dt_to, h.checker_nm,
                 (SELECT count(*)::int FROM tbl_area_hygiene_item i WHERE i.hdr_idx=h.idx AND i.co_cd=h.co_cd),
                 (SELECT count(*)::int FROM tbl_area_hygiene_result r JOIN tbl_area_hygiene_item i ON i.idx=r.item_idx AND i.co_cd=r.co_cd WHERE i.hdr_idx=h.idx AND r.co_cd=h.co_cd AND r.judge_cd='X')
            FROM tbl_area_hygiene h WHERE p_tmpl_cd='tmpl_prp-hygiene-area' AND h.doc_idx=d.idx AND h.co_cd=d.co_cd
          UNION ALL
          SELECT h.idx, h.base_dt, NULL, h.checker_nm,
                 (SELECT count(*)::int FROM tbl_pest_check_row r WHERE r.hdr_idx=h.idx AND r.co_cd=h.co_cd),
                 (SELECT count(*)::int FROM tbl_pest_check_row r WHERE r.hdr_idx=h.idx AND r.co_cd=h.co_cd AND (r.device_ng_cd='X' OR r.rat_sum>0))
            FROM tbl_pest_check h WHERE p_tmpl_cd='tmpl_prp-pest-check' AND h.doc_idx=d.idx AND h.co_cd=d.co_cd
          UNION ALL
          SELECT h.idx, h.base_dt, h.base_dt_to, NULL,
                 (SELECT count(*)::int FROM tbl_water_check_item i WHERE i.hdr_idx=h.idx AND i.co_cd=h.co_cd),
                 (SELECT count(*)::int FROM tbl_water_check_result r JOIN tbl_water_check_item i ON i.idx=r.item_idx AND i.co_cd=r.co_cd WHERE i.hdr_idx=h.idx AND r.co_cd=h.co_cd AND r.judge_cd='X')
            FROM tbl_water_check h WHERE p_tmpl_cd='tmpl_prp-water-check' AND h.doc_idx=d.idx AND h.co_cd=d.co_cd
      ) x ON true
     WHERE d.co_cd=p_co_cd AND d.tmpl_cd=p_tmpl_cd AND d.del_yn='N'
       AND (coalesce(p_from_dt,'')='' OR x.base_dt>=p_from_dt)
       AND (coalesce(p_to_dt,'')='' OR x.base_dt<=p_to_dt)
       AND (coalesce(p_doc_no,'')='' OR d.doc_no ILIKE '%' || p_doc_no || '%')
       AND (
           coalesce(p_writer,'')=''
           OR d.writer_id ILIKE '%' || p_writer || '%'
           OR coalesce(u.user_nm,'') ILIKE '%' || p_writer || '%'
       )
     ORDER BY x.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_tbl_hygiene_document_r_000(varchar, varchar, varchar, varchar, varchar, varchar) IS
  '위생 문서 목록 — 기간·문서번호·작성자';

-- 상세/신규 기본값 — entries JSON은 화면이 그대로 편집하여 저장한다.
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
    -- 신규일 때(= docIdx 없음) 표준+오버라이드+회사 CUST 항목을 반환한다
    SELECT coalesce(jsonb_agg(jsonb_build_object(
              'rowSeq', q.sort_no,
              'itemCd', q.item_cd,
              'itemNm', q.item_nm,
              'grpCd', q.grp_cd,
              'grpNm', q.grp_nm,
              'inputType', q.input_type,
              'unitNm', q.unit_nm,
              'stdYn', q.std_yn,
              'judgeCd', null
            ) ORDER BY q.sort_no, q.item_cd), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT ci.item_cd,
               coalesce(ci.grp_cd, '') AS grp_cd,
               coalesce(ci.grp_nm, '') AS grp_nm,
               ci.input_type,
               ci.unit_nm,
               coalesce(nullif(cci.item_nm_ovr, ''), ci.item_nm) AS item_nm,
               coalesce(cci.sort_no, ci.sort_no) AS sort_no,
               'Y' AS std_yn
          FROM tbl_check_item ci
          LEFT JOIN tbl_company_check_item cci
            ON cci.co_cd = p_co_cd AND cci.tmpl_cd = ci.tmpl_cd AND cci.item_cd = ci.item_cd
         WHERE ci.tmpl_cd = p_tmpl_cd
           AND ci.use_yn = 'Y'
           AND coalesce(cci.use_yn, 'Y') = 'Y'
        UNION ALL
        SELECT cci.item_cd, '', '', 'OX', NULL,
               coalesce(nullif(cci.item_nm_ovr, ''), cci.item_cd),
               coalesce(cci.sort_no, 0),
               'N'
          FROM tbl_company_check_item cci
         WHERE cci.co_cd = p_co_cd
           AND cci.tmpl_cd = p_tmpl_cd
           AND cci.item_cd LIKE 'CUST%'
           AND coalesce(cci.use_yn, 'Y') = 'Y'
           AND NOT EXISTS (
               SELECT 1 FROM tbl_check_item s
                WHERE s.tmpl_cd = cci.tmpl_cd AND s.item_cd = cci.item_cd
           )
      ) q;
    IF p_tmpl_cd='tmpl_prp-pest-check' THEN
      -- 신규 스켈레톤 — 수량(Cnt) 대신 yn 체크 플래그. 미관리 유형은 '/' (FE·저장 SP와 동일 계약)
      SELECT coalesce(jsonb_agg(jsonb_build_object(
               'rowSeq', d.sort_no,
               'pestCd', d.pest_cd,
               'pestNm', d.pest_nm,
               'placeNm', d.place_nm,
               'deviceNgCd', 'O',
               'flyYn', CASE WHEN d.pest_type IN ('LAMP','FLY') THEN 'N' ELSE '/' END,
               'mothYn', CASE WHEN d.pest_type IN ('LAMP','FLY') THEN 'N' ELSE '/' END,
               'mosqYn', CASE WHEN d.pest_type IN ('LAMP','FLY') THEN 'N' ELSE '/' END,
               'midgeYn', CASE WHEN d.pest_type IN ('LAMP','FLY') THEN 'N' ELSE '/' END,
               'etcFlyYn', CASE WHEN d.pest_type IN ('LAMP','FLY') THEN 'N' ELSE '/' END,
               'roachYn', CASE WHEN d.pest_type IN ('ROACH','WALK') THEN 'N' ELSE '/' END,
               'spiderYn', CASE WHEN d.pest_type IN ('ROACH','WALK') THEN 'N' ELSE '/' END,
               'antYn', CASE WHEN d.pest_type IN ('ROACH','WALK') THEN 'N' ELSE '/' END,
               'etcWalkYn', CASE WHEN d.pest_type IN ('ROACH','WALK') THEN 'N' ELSE '/' END,
               'ratYn', CASE WHEN d.pest_type = 'RAT' THEN 'N' ELSE '/' END,
               'etcRatYn', CASE WHEN d.pest_type = 'RAT' THEN 'N' ELSE '/' END
             ) ORDER BY d.sort_no),'[]'::jsonb)
        INTO v_items
        FROM tbl_pest_device d
       WHERE d.co_cd=p_co_cd AND d.use_yn='Y';
    END IF;
    RETURN jsonb_build_object('header',null,'entries',v_items,'signers','[]'::jsonb,'checkers','[]'::jsonb);
  END IF;
  SELECT CASE p_tmpl_cd
    WHEN 'tmpl_prp-hygiene-daily' THEN (SELECT h.idx FROM tbl_daily_hygiene h WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx)
    WHEN 'tmpl_prp-hygiene-personal' THEN (SELECT h.idx FROM tbl_personal_hygiene h WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx)
    WHEN 'tmpl_prp-hygiene-area' THEN (SELECT h.idx FROM tbl_area_hygiene h WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx)
    WHEN 'tmpl_prp-pest-check' THEN (SELECT h.idx FROM tbl_pest_check h WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx)
    WHEN 'tmpl_prp-water-check' THEN (SELECT h.idx FROM tbl_water_check h WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx)
  END INTO v_hdr;
  IF v_hdr IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
  SELECT jsonb_build_object('docIdx',d.idx,'docNo',d.doc_no,'baseDt',d.base_dt,'status',d.status) INTO v_out FROM tbl_document d WHERE d.co_cd=p_co_cd AND d.idx=p_doc_idx AND d.del_yn='N';
  IF p_tmpl_cd='tmpl_prp-hygiene-daily' THEN
    -- 기존 문서 재조회 — FE NUM/NUM2 분기를 위해 inputType·unitNm을 표준항목과 JOIN한다
    SELECT jsonb_build_object(
             'header', v_out || jsonb_build_object('beforeTime',h.before_time,'duringTime',h.during_time,'checkerNm',h.checker_nm),
             'entries', coalesce(jsonb_agg(jsonb_build_object(
               'rowSeq', i.row_seq,
               'grpCd', i.grp_cd,
               -- 구분 문구 스냅샷 — 비어 있으면 표준 grp_nm으로 표시
               'grpNm', coalesce(nullif(i.grp_nm, ''), ci.grp_nm, i.grp_cd),
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
      LEFT JOIN tbl_check_item ci ON ci.tmpl_cd='tmpl_prp-hygiene-daily' AND ci.item_cd=i.item_cd
     WHERE h.idx=v_hdr AND h.co_cd=p_co_cd
     GROUP BY h.before_time, h.during_time, h.checker_nm;
  ELSIF p_tmpl_cd='tmpl_prp-hygiene-personal' THEN
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
  ELSIF p_tmpl_cd='tmpl_prp-hygiene-area' THEN
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
  ELSIF p_tmpl_cd='tmpl_prp-pest-check' THEN
    -- camelCase 카운트 열 — 신규 기본행·저장 payload와 동일
    SELECT jsonb_build_object(
             'header', v_out || jsonb_build_object('checkerNm',h.checker_nm),
             'entries', coalesce(jsonb_agg(jsonb_build_object(
               'rowSeq', r.row_seq,
               'pestCd', r.pest_cd,
               'pestNm', r.pest_nm,
               'placeNm', r.place_nm,
               'deviceNgCd', r.device_ng_cd,
               'flyYn', coalesce(r.fly_yn,'N'),
               'mothYn', coalesce(r.moth_yn,'N'),
               'mosqYn', coalesce(r.mosq_yn,'N'),
               'midgeYn', coalesce(r.midge_yn,'N'),
               'etcFlyYn', coalesce(r.etc_fly_yn,'N'),
               'roachYn', coalesce(r.roach_yn,'N'),
               'spiderYn', coalesce(r.spider_yn,'N'),
               'antYn', coalesce(r.ant_yn,'N'),
               'etcWalkYn', coalesce(r.etc_walk_yn,'N'),
               'ratYn', coalesce(r.rat_yn,'N'),
               'etcRatYn', coalesce(r.etc_rat_yn,'N'),
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

-- 저장 — 문서와 양식별 상세행을 같은 트랜잭션에서 전체 교체한다.
CREATE OR REPLACE FUNCTION sp_tbl_hygiene_document_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar, -- p_tmpl_cd: 양식코드
    p_tmpl_cd varchar, -- p_doc_idx: 기존 문서 idx, 신규면 NULL/0
    p_doc_idx bigint, -- p_base_dt: 기준일 YYYYMMDD
    p_base_dt varchar, -- p_base_dt_to: 기간 양식 종료일
    p_base_dt_to varchar, -- p_checker_nm: 점검자 스냅샷
    p_checker_nm varchar, -- p_payload: entries/signers/checkers JSON
    p_payload jsonb, -- p_id: JWT 사용자 ID
    p_id varchar
) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_doc bigint; v_hdr bigint; v_status varchar; v_no varchar; v_name varchar; v_appr varchar; v_retain int; e jsonb; r jsonb; s jsonb; v_item bigint;
BEGIN
 IF coalesce(p_co_cd,'')='' OR coalesce(p_tmpl_cd,'')='' OR coalesce(p_base_dt,'')='' OR length(p_base_dt)<>8 THEN RAISE EXCEPTION '양식과 기준일은 필수입니다.' USING ERRCODE='45000'; END IF;
 IF p_payload IS NULL OR jsonb_typeof(coalesce(p_payload->'entries','null'::jsonb))<>'array' THEN RAISE EXCEPTION '점검행 자료가 올바르지 않습니다.' USING ERRCODE='45000'; END IF;
 SELECT coalesce(ct.tmpl_nm_ovr,t.tmpl_nm),coalesce(ct.appr_line_cd,'DEFAULT'),coalesce(ct.retention_month,t.default_retention_month) INTO v_name,v_appr,v_retain FROM tbl_template t LEFT JOIN tbl_company_template ct ON ct.co_cd=p_co_cd AND ct.tmpl_cd=t.tmpl_cd AND ct.use_yn='Y' WHERE t.tmpl_cd=p_tmpl_cd AND t.use_yn='Y';
 IF v_name IS NULL THEN RAISE EXCEPTION '등록되지 않은 위생 양식입니다.' USING ERRCODE='45000'; END IF;
 IF coalesce(p_doc_idx,0)=0 THEN
   v_no:=sp_tbl_doc_no_gen_c_000(p_co_cd,p_tmpl_cd,p_base_dt);
   INSERT INTO tbl_document(co_cd,tmpl_cd,doc_kind,doc_no,base_dt,base_dt_to,title,status,appr_line_cd,writer_id,write_dt,ver_no,retention_until,del_yn,ins_id,ins_dt)
   VALUES(p_co_cd,p_tmpl_cd,'DB',v_no,p_base_dt,nullif(p_base_dt_to,''),v_name||' ('||substr(p_base_dt,1,4)||'-'||substr(p_base_dt,5,2)||'-'||substr(p_base_dt,7,2)||')','WRK',v_appr,p_id,now(),1,to_char((to_date(p_base_dt,'YYYYMMDD')+(coalesce(v_retain,24)||' months')::interval)::date,'YYYYMMDD'),'N',p_id,now()) RETURNING idx INTO v_doc;
 ELSE
   SELECT idx,status INTO v_doc,v_status FROM tbl_document WHERE co_cd=p_co_cd AND idx=p_doc_idx AND tmpl_cd=p_tmpl_cd AND del_yn='N';
   IF v_doc IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
   IF v_status NOT IN ('WRK','RJT') THEN RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 수정할 수 없습니다.' USING ERRCODE='45000'; END IF;
   UPDATE tbl_document SET base_dt=p_base_dt,base_dt_to=nullif(p_base_dt_to,''),title=v_name||' ('||substr(p_base_dt,1,4)||'-'||substr(p_base_dt,5,2)||'-'||substr(p_base_dt,7,2)||')',upd_id=p_id,upd_dt=now() WHERE idx=v_doc AND co_cd=p_co_cd;
 END IF;
 IF p_tmpl_cd='tmpl_prp-hygiene-daily' THEN
   SELECT idx INTO v_hdr FROM tbl_daily_hygiene WHERE co_cd=p_co_cd AND doc_idx=v_doc;
   IF v_hdr IS NULL THEN INSERT INTO tbl_daily_hygiene(co_cd,doc_idx,base_dt,before_time,during_time,checker_id,checker_nm,ins_id) VALUES(p_co_cd,v_doc,p_base_dt,nullif(p_payload->>'beforeTime',''),nullif(p_payload->>'duringTime',''),p_id,nullif(p_checker_nm,''),p_id) RETURNING idx INTO v_hdr; ELSE UPDATE tbl_daily_hygiene SET base_dt=p_base_dt,before_time=nullif(p_payload->>'beforeTime',''),during_time=nullif(p_payload->>'duringTime',''),checker_nm=nullif(p_checker_nm,''),upd_id=p_id,upd_dt=now() WHERE idx=v_hdr AND co_cd=p_co_cd; DELETE FROM tbl_daily_hygiene_item WHERE hdr_idx=v_hdr AND co_cd=p_co_cd; END IF;
   FOR e IN SELECT * FROM jsonb_array_elements(p_payload->'entries') LOOP
     INSERT INTO tbl_daily_hygiene_item(
       co_cd, hdr_idx, row_seq, grp_cd, grp_nm, item_cd, item_nm,
       judge_cd, num_val, num_val2, remark, ins_id
     ) VALUES (
       p_co_cd, v_hdr, (e->>'rowSeq')::int,
       coalesce(e->>'grpCd',''),
       nullif(e->>'grpNm',''),
       coalesce(e->>'itemCd',''),
       nullif(e->>'itemNm',''),
       nullif(e->>'judgeCd',''),
       nullif(e->>'numVal','')::numeric,
       nullif(e->>'numVal2','')::numeric,
       nullif(e->>'remark',''),
       p_id
     );
   END LOOP;
 ELSIF p_tmpl_cd='tmpl_prp-hygiene-personal' THEN
   SELECT idx INTO v_hdr FROM tbl_personal_hygiene WHERE co_cd=p_co_cd AND doc_idx=v_doc; IF v_hdr IS NULL THEN INSERT INTO tbl_personal_hygiene(co_cd,doc_idx,base_dt,checker_id,checker_nm,ins_id) VALUES(p_co_cd,v_doc,p_base_dt,p_id,nullif(p_checker_nm,''),p_id) RETURNING idx INTO v_hdr; ELSE UPDATE tbl_personal_hygiene SET base_dt=p_base_dt,checker_nm=nullif(p_checker_nm,''),upd_id=p_id,upd_dt=now() WHERE idx=v_hdr AND co_cd=p_co_cd; DELETE FROM tbl_personal_hygiene_row WHERE hdr_idx=v_hdr AND co_cd=p_co_cd; END IF;
   FOR e IN SELECT * FROM jsonb_array_elements(p_payload->'entries') LOOP INSERT INTO tbl_personal_hygiene_row(co_cd,hdr_idx,row_seq,worker_user_id,worker_nm,health_cd,cloth_cd,belongings_cd,worker_state_cd,anteroom_cd,handwash_cd,remark,ins_id) VALUES(p_co_cd,v_hdr,(e->>'rowSeq')::int,nullif(e->>'workerUserId',''),coalesce(e->>'workerNm',''),nullif(e->>'healthCd',''),nullif(e->>'clothCd',''),nullif(e->>'belongingsCd',''),nullif(e->>'workerStateCd',''),nullif(e->>'anteroomCd',''),nullif(e->>'handwashCd',''),nullif(e->>'remark',''),p_id); END LOOP;
 ELSIF p_tmpl_cd='tmpl_prp-pest-check' THEN
   SELECT idx INTO v_hdr FROM tbl_pest_check WHERE co_cd=p_co_cd AND doc_idx=v_doc; IF v_hdr IS NULL THEN INSERT INTO tbl_pest_check(co_cd,doc_idx,base_dt,checker_id,checker_nm,ins_id) VALUES(p_co_cd,v_doc,p_base_dt,p_id,nullif(p_checker_nm,''),p_id) RETURNING idx INTO v_hdr; ELSE UPDATE tbl_pest_check SET base_dt=p_base_dt,checker_nm=nullif(p_checker_nm,''),upd_id=p_id,upd_dt=now() WHERE idx=v_hdr AND co_cd=p_co_cd; DELETE FROM tbl_pest_check_row WHERE hdr_idx=v_hdr AND co_cd=p_co_cd; END IF;
   FOR e IN SELECT * FROM jsonb_array_elements(p_payload->'entries') LOOP
     INSERT INTO tbl_pest_check_row(
       co_cd,hdr_idx,row_seq,pest_cd,pest_nm,place_nm,device_ng_cd,
       fly_yn,moth_yn,mosq_yn,midge_yn,etc_fly_yn,
       roach_yn,spider_yn,ant_yn,etc_walk_yn,rat_yn,etc_rat_yn,
       fly_cnt,moth_cnt,mosq_cnt,midge_cnt,etc_fly_cnt,fly_sum,
       roach_cnt,spider_cnt,ant_cnt,etc_walk_cnt,walk_sum,rat_cnt,etc_rat_cnt,rat_sum,
       remark,ins_id
     ) VALUES(
       p_co_cd,v_hdr,(e->>'rowSeq')::int,coalesce(e->>'pestCd',''),nullif(e->>'pestNm',''),nullif(e->>'placeNm',''),nullif(e->>'deviceNgCd',''),
       coalesce(nullif(e->>'flyYn',''),'N'), coalesce(nullif(e->>'mothYn',''),'N'), coalesce(nullif(e->>'mosqYn',''),'N'),
       coalesce(nullif(e->>'midgeYn',''),'N'), coalesce(nullif(e->>'etcFlyYn',''),'N'),
       coalesce(nullif(e->>'roachYn',''),'N'), coalesce(nullif(e->>'spiderYn',''),'N'), coalesce(nullif(e->>'antYn',''),'N'),
       coalesce(nullif(e->>'etcWalkYn',''),'N'), coalesce(nullif(e->>'ratYn',''),'N'), coalesce(nullif(e->>'etcRatYn',''),'N'),
       CASE WHEN coalesce(e->>'flyYn','N')='Y' THEN 1 ELSE 0 END,
       CASE WHEN coalesce(e->>'mothYn','N')='Y' THEN 1 ELSE 0 END,
       CASE WHEN coalesce(e->>'mosqYn','N')='Y' THEN 1 ELSE 0 END,
       CASE WHEN coalesce(e->>'midgeYn','N')='Y' THEN 1 ELSE 0 END,
       CASE WHEN coalesce(e->>'etcFlyYn','N')='Y' THEN 1 ELSE 0 END,
       (CASE WHEN coalesce(e->>'flyYn','N')='Y' THEN 1 ELSE 0 END)+(CASE WHEN coalesce(e->>'mothYn','N')='Y' THEN 1 ELSE 0 END)+(CASE WHEN coalesce(e->>'mosqYn','N')='Y' THEN 1 ELSE 0 END)+(CASE WHEN coalesce(e->>'midgeYn','N')='Y' THEN 1 ELSE 0 END)+(CASE WHEN coalesce(e->>'etcFlyYn','N')='Y' THEN 1 ELSE 0 END),
       CASE WHEN coalesce(e->>'roachYn','N')='Y' THEN 1 ELSE 0 END,
       CASE WHEN coalesce(e->>'spiderYn','N')='Y' THEN 1 ELSE 0 END,
       CASE WHEN coalesce(e->>'antYn','N')='Y' THEN 1 ELSE 0 END,
       CASE WHEN coalesce(e->>'etcWalkYn','N')='Y' THEN 1 ELSE 0 END,
       (CASE WHEN coalesce(e->>'roachYn','N')='Y' THEN 1 ELSE 0 END)+(CASE WHEN coalesce(e->>'spiderYn','N')='Y' THEN 1 ELSE 0 END)+(CASE WHEN coalesce(e->>'antYn','N')='Y' THEN 1 ELSE 0 END)+(CASE WHEN coalesce(e->>'etcWalkYn','N')='Y' THEN 1 ELSE 0 END),
       CASE WHEN coalesce(e->>'ratYn','N')='Y' THEN 1 ELSE 0 END,
       CASE WHEN coalesce(e->>'etcRatYn','N')='Y' THEN 1 ELSE 0 END,
       (CASE WHEN coalesce(e->>'ratYn','N')='Y' THEN 1 ELSE 0 END)+(CASE WHEN coalesce(e->>'etcRatYn','N')='Y' THEN 1 ELSE 0 END),
       nullif(e->>'remark',''),p_id
     );
   END LOOP;
 ELSE
   IF p_tmpl_cd='tmpl_prp-hygiene-area' THEN SELECT idx INTO v_hdr FROM tbl_area_hygiene WHERE co_cd=p_co_cd AND doc_idx=v_doc; IF v_hdr IS NULL THEN INSERT INTO tbl_area_hygiene(co_cd,doc_idx,base_dt,base_dt_to,area_cd,checker_id,checker_nm,ins_id) VALUES(p_co_cd,v_doc,p_base_dt,nullif(p_base_dt_to,''),nullif(p_payload->>'areaCd',''),p_id,nullif(p_checker_nm,''),p_id) RETURNING idx INTO v_hdr; ELSE DELETE FROM tbl_area_hygiene_result r USING tbl_area_hygiene_item i WHERE r.item_idx=i.idx AND r.co_cd=i.co_cd AND i.hdr_idx=v_hdr AND i.co_cd=p_co_cd; DELETE FROM tbl_area_hygiene_item WHERE hdr_idx=v_hdr AND co_cd=p_co_cd; DELETE FROM tbl_area_hygiene_signer WHERE hdr_idx=v_hdr AND co_cd=p_co_cd; UPDATE tbl_area_hygiene SET base_dt=p_base_dt,base_dt_to=nullif(p_base_dt_to,''),area_cd=nullif(p_payload->>'areaCd',''),checker_nm=nullif(p_checker_nm,''),upd_id=p_id,upd_dt=now() WHERE idx=v_hdr AND co_cd=p_co_cd; END IF;
   ELSE SELECT idx INTO v_hdr FROM tbl_water_check WHERE co_cd=p_co_cd AND doc_idx=v_doc; IF v_hdr IS NULL THEN INSERT INTO tbl_water_check(co_cd,doc_idx,base_dt,base_dt_to,cycle_nm,ins_id) VALUES(p_co_cd,v_doc,p_base_dt,nullif(p_base_dt_to,''),nullif(p_payload->>'cycleNm',''),p_id) RETURNING idx INTO v_hdr; ELSE DELETE FROM tbl_water_check_result r USING tbl_water_check_item i WHERE r.item_idx=i.idx AND r.co_cd=i.co_cd AND i.hdr_idx=v_hdr AND i.co_cd=p_co_cd; DELETE FROM tbl_water_check_item WHERE hdr_idx=v_hdr AND co_cd=p_co_cd; DELETE FROM tbl_water_check_checker WHERE hdr_idx=v_hdr AND co_cd=p_co_cd; UPDATE tbl_water_check SET base_dt=p_base_dt,base_dt_to=nullif(p_base_dt_to,''),cycle_nm=nullif(p_payload->>'cycleNm',''),upd_id=p_id,upd_dt=now() WHERE idx=v_hdr AND co_cd=p_co_cd; END IF; END IF;
   FOR e IN SELECT * FROM jsonb_array_elements(p_payload->'entries') LOOP
     IF p_tmpl_cd='tmpl_prp-hygiene-area' THEN INSERT INTO tbl_area_hygiene_item(co_cd,hdr_idx,row_seq,item_cd,item_nm,remark,ins_id) VALUES(p_co_cd,v_hdr,(e->>'rowSeq')::int,coalesce(e->>'itemCd',''),nullif(e->>'itemNm',''),nullif(e->>'remark',''),p_id) RETURNING idx INTO v_item; FOR r IN SELECT * FROM jsonb_array_elements(coalesce(e->'results','[]'::jsonb)) LOOP INSERT INTO tbl_area_hygiene_result(co_cd,item_idx,check_dt,judge_cd,ins_id) VALUES(p_co_cd,v_item,coalesce(r->>'checkDt',''),nullif(r->>'judgeCd',''),p_id); END LOOP;
     ELSE INSERT INTO tbl_water_check_item(co_cd,hdr_idx,row_seq,grp_cd,grp_nm,item_cd,item_nm,ins_id) VALUES(p_co_cd,v_hdr,(e->>'rowSeq')::int,nullif(e->>'grpCd',''),nullif(e->>'grpNm',''),coalesce(e->>'itemCd',''),nullif(e->>'itemNm',''),p_id) RETURNING idx INTO v_item; FOR r IN SELECT * FROM jsonb_array_elements(coalesce(e->'results','[]'::jsonb)) LOOP INSERT INTO tbl_water_check_result(co_cd,item_idx,week_no,judge_cd,ins_id) VALUES(p_co_cd,v_item,(r->>'weekNo')::int,nullif(r->>'judgeCd',''),p_id); END LOOP; END IF;
   END LOOP;
   IF p_tmpl_cd='tmpl_prp-hygiene-area' THEN FOR s IN SELECT * FROM jsonb_array_elements(coalesce(p_payload->'signers','[]'::jsonb)) LOOP INSERT INTO tbl_area_hygiene_signer(co_cd,hdr_idx,check_dt,writer_nm,reviewer_nm,approver_nm,ins_id) VALUES(p_co_cd,v_hdr,coalesce(s->>'checkDt',''),nullif(s->>'writerNm',''),nullif(s->>'reviewerNm',''),nullif(s->>'approverNm',''),p_id); END LOOP; ELSE FOR s IN SELECT * FROM jsonb_array_elements(coalesce(p_payload->'checkers','[]'::jsonb)) LOOP INSERT INTO tbl_water_check_checker(co_cd,hdr_idx,week_no,check_dt,checker_id,checker_nm,ins_id) VALUES(p_co_cd,v_hdr,(s->>'weekNo')::int,nullif(s->>'checkDt',''),nullif(s->>'checkerId',''),nullif(s->>'checkerNm',''),p_id); END LOOP; END IF;
 END IF;
 RETURN v_doc;
END$$;

-- 삭제 — 양식별 하위행과 문서 허브 행을 함께 삭제한다.
CREATE OR REPLACE PROCEDURE sp_tbl_hygiene_document_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar, -- p_tmpl_cd: 양식코드
    p_tmpl_cd varchar, -- p_doc_idx: 문서 idx
    p_doc_idx bigint, -- p_id: 작업자 ID
    p_id varchar
) LANGUAGE plpgsql AS $$
DECLARE v_status varchar; v_hdr bigint;
BEGIN
 SELECT status INTO v_status FROM tbl_document WHERE co_cd=p_co_cd AND idx=p_doc_idx AND tmpl_cd=p_tmpl_cd AND del_yn='N';
 IF v_status IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
 IF v_status NOT IN ('WRK','RJT') THEN RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 삭제할 수 없습니다.' USING ERRCODE='45000'; END IF;
 IF p_tmpl_cd='tmpl_prp-hygiene-daily' THEN SELECT idx INTO v_hdr FROM tbl_daily_hygiene WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx; DELETE FROM tbl_daily_hygiene_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr; DELETE FROM tbl_daily_hygiene WHERE co_cd=p_co_cd AND idx=v_hdr;
 ELSIF p_tmpl_cd='tmpl_prp-hygiene-personal' THEN SELECT idx INTO v_hdr FROM tbl_personal_hygiene WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx; DELETE FROM tbl_personal_hygiene_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr; DELETE FROM tbl_personal_hygiene WHERE co_cd=p_co_cd AND idx=v_hdr;
 ELSIF p_tmpl_cd='tmpl_prp-hygiene-area' THEN SELECT idx INTO v_hdr FROM tbl_area_hygiene WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx; DELETE FROM tbl_area_hygiene_result r USING tbl_area_hygiene_item i WHERE r.item_idx=i.idx AND r.co_cd=i.co_cd AND i.co_cd=p_co_cd AND i.hdr_idx=v_hdr; DELETE FROM tbl_area_hygiene_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr; DELETE FROM tbl_area_hygiene_signer WHERE co_cd=p_co_cd AND hdr_idx=v_hdr; DELETE FROM tbl_area_hygiene WHERE co_cd=p_co_cd AND idx=v_hdr;
 ELSIF p_tmpl_cd='tmpl_prp-pest-check' THEN SELECT idx INTO v_hdr FROM tbl_pest_check WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx; DELETE FROM tbl_pest_check_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr; DELETE FROM tbl_pest_check WHERE co_cd=p_co_cd AND idx=v_hdr;
 ELSE SELECT idx INTO v_hdr FROM tbl_water_check WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx; DELETE FROM tbl_water_check_result r USING tbl_water_check_item i WHERE r.item_idx=i.idx AND r.co_cd=i.co_cd AND i.co_cd=p_co_cd AND i.hdr_idx=v_hdr; DELETE FROM tbl_water_check_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr; DELETE FROM tbl_water_check_checker WHERE co_cd=p_co_cd AND hdr_idx=v_hdr; DELETE FROM tbl_water_check WHERE co_cd=p_co_cd AND idx=v_hdr; END IF;
 DELETE FROM tbl_corrective_action WHERE co_cd=p_co_cd AND src_doc_idx=p_doc_idx;
 DELETE FROM tbl_document_approval WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx;
 DELETE FROM tbl_document_file WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx;
 DELETE FROM tbl_document WHERE co_cd=p_co_cd AND idx=p_doc_idx;
END$$;
