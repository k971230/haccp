-- ============================================================
-- 역할 — 시설·재고·공정 DB형 양식 6종의 목록·상세·저장·삭제 저장프로시저
--
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) 시설·검교정·폐기물·재고·입고검사·공정관리의 DDL 7 테이블을 문서와 함께 저장한다
--   2) 화면은 templateCode로 양식을 구분하지만 DB 분기는 고정 CASE만 써 동적 테이블명을 만들지 않는다
--   3) 저장·삭제 트랜잭션은 Spring이 소유하며, 결재 진행·완료 문서는 SP에서도 다시 차단한다
-- ============================================================

SET search_path TO sasshaccp;

-- 목록 — templateCode별 문서 목록. 문서번호·작성자 부분검색.
DROP FUNCTION IF EXISTS sp_tbl_biz_ops_r_000(varchar, varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_tbl_biz_ops_r_000(
    p_co_cd varchar,
    p_tmpl_cd varchar,
    p_from_dt varchar,
    p_to_dt varchar,
    p_doc_no varchar DEFAULT '',
    p_writer varchar DEFAULT ''
)
RETURNS TABLE (
    doc_idx bigint, doc_no varchar, base_dt varchar, title varchar, status varchar,
    writer_id varchar, write_dt timestamp, row_cnt int, ng_cnt int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, d.doc_no, d.base_dt, d.title, d.status, d.writer_id, d.write_dt,
           CASE p_tmpl_cd
             WHEN 'FACILITY' THEN (SELECT count(*)::int FROM tbl_facility_check_item r JOIN tbl_facility_check h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd)
             WHEN 'CALIB_TARGET' THEN (SELECT count(*)::int FROM tbl_calib_target_row r JOIN tbl_calib_target h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd)
             WHEN 'WASTE' THEN (SELECT count(*)::int FROM tbl_waste_check_row r JOIN tbl_waste_check h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd)
             WHEN 'INV_CHECK' THEN (SELECT count(*)::int FROM tbl_inv_txn r WHERE r.src_tmpl_cd = 'INV_CHECK' AND r.src_doc_idx = d.idx AND r.co_cd = d.co_cd)
             WHEN 'RECV_INSP' THEN (SELECT count(*)::int FROM tbl_recv_inspect_item r JOIN tbl_recv_inspect h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd)
             WHEN 'PROCESS' THEN (SELECT count(*)::int FROM tbl_process_check_item r JOIN tbl_process_check h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd)
             ELSE 0
           END,
           CASE p_tmpl_cd
             WHEN 'FACILITY' THEN (SELECT count(*)::int FROM tbl_facility_check_item r JOIN tbl_facility_check h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd AND r.judge_cd = 'X')
             WHEN 'RECV_INSP' THEN (SELECT count(*)::int FROM tbl_recv_inspect_item r JOIN tbl_recv_inspect h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd AND r.judge_cd = 'F')
             ELSE 0
           END
      FROM tbl_document d
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N'
       AND (coalesce(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (coalesce(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
       AND (coalesce(p_doc_no, '') = '' OR d.doc_no ILIKE '%' || p_doc_no || '%')
       AND (
           coalesce(p_writer, '') = ''
           OR d.writer_id ILIKE '%' || p_writer || '%'
           OR coalesce(u.user_nm, '') ILIKE '%' || p_writer || '%'
       )
     ORDER BY d.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_tbl_biz_ops_r_000(varchar, varchar, varchar, varchar, varchar, varchar) IS
  '시설·재고·공정 목록 — 기간·문서번호·작성자';

-- 상세 — header와 rows는 camelCase JSON으로 조립한다. 신규 문서는 표준 점검항목 또는 계측기 목록을 기본행으로 반환한다.
CREATE OR REPLACE FUNCTION sp_tbl_biz_ops_r_001(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 화면이 여는 양식 코드
    p_tmpl_cd varchar,
    -- p_doc_idx: 기존 문서 idx. NULL/0이면 신규 기본 양식
    p_doc_idx bigint
)
RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_header jsonb := NULL;
    v_rows jsonb := '[]'::jsonb;
    v_hdr_idx bigint;
BEGIN
    IF coalesce(p_doc_idx, 0) = 0 THEN
        IF p_tmpl_cd IN ('FACILITY', 'PROCESS', 'RECV_INSP') THEN
            -- 신규일 때(= docIdx 없음) 표준+오버라이드+회사 CUST로 전체 행을 채운다
            SELECT coalesce(jsonb_agg(jsonb_build_object(
                'rowSeq', q.sort_no,
                'grpCd', q.grp_cd, 'grpNm', q.grp_nm,
                'itemCd', q.item_cd,
                'itemNm', q.item_nm,
                'methodNm', q.method_nm,
                'cycleNm', q.cycle_nm,
                'placeNm', NULL,
                'judgeCd', NULL,
                'actionRmk', NULL,
                'actionDesc', NULL
            ) ORDER BY q.sort_no, q.item_cd), '[]'::jsonb) INTO v_rows
              FROM (
                SELECT c.item_cd, c.grp_cd, c.grp_nm, c.method_nm, c.cycle_nm,
                       coalesce(nullif(cci.item_nm_ovr, ''), c.item_nm) AS item_nm,
                       coalesce(cci.sort_no, c.sort_no) AS sort_no
                  FROM tbl_check_item c
                  LEFT JOIN tbl_company_check_item cci
                    ON cci.co_cd = p_co_cd AND cci.tmpl_cd = c.tmpl_cd AND cci.item_cd = c.item_cd
                 WHERE c.tmpl_cd = p_tmpl_cd
                   AND c.use_yn = 'Y'
                   AND coalesce(cci.use_yn, 'Y') = 'Y'
                UNION ALL
                SELECT cci.item_cd, NULL, NULL, NULL, NULL,
                       coalesce(nullif(cci.item_nm_ovr, ''), cci.item_cd),
                       coalesce(cci.sort_no, 0)
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
        ELSIF p_tmpl_cd = 'CALIB_TARGET' THEN
            SELECT coalesce(jsonb_agg(jsonb_build_object(
                'rowSeq', q.row_seq, 'deviceCd', q.device_cd, 'deviceNm', q.device_nm,
                'officialCalibDt', NULL, 'selfCalibDt', NULL, 'nextCalibDt', NULL,
                'doneDocIdx', NULL, 'remark', NULL
            ) ORDER BY q.device_cd), '[]'::jsonb) INTO v_rows
              FROM (
                  SELECT row_number() OVER (ORDER BY m.device_cd)::int AS row_seq,
                         m.device_cd, m.device_nm
                    FROM tbl_measuring_device m
                   WHERE m.co_cd = p_co_cd AND m.use_yn = 'Y'
              ) q;
        END IF;
        RETURN jsonb_build_object('header', NULL, 'rows', v_rows);
    END IF;

    IF p_tmpl_cd = 'FACILITY' THEN
        SELECT h.idx, jsonb_build_object('docIdx', d.idx, 'docNo', d.doc_no, 'status', d.status, 'baseDt', h.base_dt, 'checkerId', h.checker_id, 'checkerNm', h.checker_nm)
          INTO v_hdr_idx, v_header FROM tbl_facility_check h JOIN tbl_document d ON d.idx=h.doc_idx AND d.co_cd=h.co_cd WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx;
        SELECT coalesce(jsonb_agg(jsonb_build_object(
                 'rowSeq', r.row_seq,
                 'placeNm', r.place_nm,
                 'grpNm', r.grp_nm,
                 'itemCd', r.item_cd,
                 'itemNm', r.item_nm,
                 'methodNm', r.method_nm,
                 'cycleNm', r.cycle_nm,
                 'mngNm', r.mng_nm,
                 'judgeCd', r.judge_cd,
                 'actionRmk', r.action_rmk,
                 'actionDesc', r.action_desc
               ) ORDER BY r.row_seq),'[]'::jsonb)
          INTO v_rows
          FROM tbl_facility_check_item r
         WHERE r.co_cd=p_co_cd AND r.hdr_idx=v_hdr_idx;
    ELSIF p_tmpl_cd = 'CALIB_TARGET' THEN
        SELECT h.idx, jsonb_build_object('docIdx',d.idx,'docNo',d.doc_no,'status',d.status,'baseYear',h.base_year,'baseDt',h.base_dt,'checkerId',h.checker_id,'checkerNm',h.checker_nm) INTO v_hdr_idx,v_header FROM tbl_calib_target h JOIN tbl_document d ON d.idx=h.doc_idx AND d.co_cd=h.co_cd WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx;
        SELECT coalesce(jsonb_agg(jsonb_build_object('rowSeq',r.row_seq,'deviceCd',r.device_cd,'deviceNm',r.device_nm,'officialCalibDt',r.official_calib_dt,'selfCalibDt',r.self_calib_dt,'nextCalibDt',r.next_calib_dt,'doneDocIdx',r.done_doc_idx,'remark',r.remark) ORDER BY r.row_seq),'[]'::jsonb) INTO v_rows FROM tbl_calib_target_row r WHERE r.co_cd=p_co_cd AND r.hdr_idx=v_hdr_idx;
    ELSIF p_tmpl_cd = 'WASTE' THEN
        SELECT h.idx,jsonb_build_object('docIdx',d.idx,'docNo',d.doc_no,'status',d.status,'baseDt',h.base_dt,'baseDtTo',h.base_dt_to) INTO v_hdr_idx,v_header FROM tbl_waste_check h JOIN tbl_document d ON d.idx=h.doc_idx AND d.co_cd=h.co_cd WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx;
        SELECT coalesce(jsonb_agg(jsonb_build_object('rowSeq',r.row_seq,'procDt',r.proc_dt,'wasteGbn',r.waste_gbn,'itemNm',r.item_nm,'makeDt',r.make_dt,'expireDt',r.expire_dt,'weightKg',r.weight_kg,'badDesc',r.bad_desc,'procDesc',r.proc_desc,'partnerCd',r.partner_cd,'partnerNm',r.partner_nm,'mngUserId',r.mng_user_id,'mngNm',r.mng_nm) ORDER BY r.row_seq),'[]'::jsonb) INTO v_rows FROM tbl_waste_check_row r WHERE r.co_cd=p_co_cd AND r.hdr_idx=v_hdr_idx;
    ELSIF p_tmpl_cd = 'INV_CHECK' THEN
        SELECT h.idx,jsonb_build_object('docIdx',d.idx,'docNo',d.doc_no,'status',d.status,'baseYm',h.base_ym) INTO v_hdr_idx,v_header FROM tbl_inv_check h JOIN tbl_document d ON d.idx=h.doc_idx AND d.co_cd=h.co_cd WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx;
        SELECT coalesce(jsonb_agg(jsonb_build_object('rowSeq',row_number() over (ORDER BY r.txn_dt,r.idx),'txnDt',r.txn_dt,'txnGbn',r.txn_gbn,'itemGbn',r.item_gbn,'materialCd',r.material_cd,'productCd',r.product_cd,'itemNm',r.item_nm,'partnerCd',r.partner_cd,'partnerNm',r.partner_nm,'qty',r.qty,'unitNm',r.unit_nm,'lotNo',r.lot_no,'makeDt',r.make_dt,'expireDt',r.expire_dt,'storageCd',r.storage_cd,'remark',r.remark) ORDER BY r.txn_dt,r.idx),'[]'::jsonb) INTO v_rows FROM tbl_inv_txn r WHERE r.co_cd=p_co_cd AND r.src_tmpl_cd='INV_CHECK' AND r.src_doc_idx=p_doc_idx;
    ELSIF p_tmpl_cd = 'RECV_INSP' THEN
        SELECT h.idx,jsonb_build_object('docIdx',d.idx,'docNo',d.doc_no,'status',d.status,'baseDt',h.base_dt,'recvGbn',h.recv_gbn,'recvTime',h.recv_time,'partnerCd',h.partner_cd,'partnerNm',h.partner_nm,'materialCd',h.material_cd,'itemNm',h.item_nm,'recvQty',h.recv_qty,'unitNm',h.unit_nm,'lotNo',h.lot_no,'makeDt',h.make_dt,'expireDt',h.expire_dt,'coreTemp',h.core_temp,'carTemp',h.car_temp,'vehicleCd',h.vehicle_cd,'carNo',h.car_no,'haccpApplyCd',h.haccp_apply_cd,'judgeCd',h.judge_cd,'checkerId',h.checker_id,'checkerNm',h.checker_nm) INTO v_hdr_idx,v_header FROM tbl_recv_inspect h JOIN tbl_document d ON d.idx=h.doc_idx AND d.co_cd=h.co_cd WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx;
        SELECT coalesce(jsonb_agg(jsonb_build_object('rowSeq',r.row_seq,'grpCd',r.grp_cd,'itemCd',r.item_cd,'itemNm',r.item_nm,'judgeCd',r.judge_cd,'evalDesc',r.eval_desc) ORDER BY r.row_seq),'[]'::jsonb) INTO v_rows FROM tbl_recv_inspect_item r WHERE r.co_cd=p_co_cd AND r.hdr_idx=v_hdr_idx;
    ELSIF p_tmpl_cd = 'PROCESS' THEN
        SELECT h.idx,jsonb_build_object('docIdx',d.idx,'docNo',d.doc_no,'status',d.status,'baseDt',h.base_dt,'baseDtTo',h.base_dt_to,'cycleNm',h.cycle_nm) INTO v_hdr_idx,v_header FROM tbl_process_check h JOIN tbl_document d ON d.idx=h.doc_idx AND d.co_cd=h.co_cd WHERE h.co_cd=p_co_cd AND h.doc_idx=p_doc_idx;
        SELECT coalesce(jsonb_agg(jsonb_build_object('rowSeq',r.row_seq,'procCd',r.proc_cd,'procNm',r.proc_nm,'itemCd',r.item_cd,'itemNm',r.item_nm,'results',(SELECT coalesce(jsonb_agg(jsonb_build_object('checkDt',x.check_dt,'ampmCd',x.ampm_cd,'judgeCd',x.judge_cd) ORDER BY x.check_dt,x.ampm_cd),'[]'::jsonb) FROM tbl_process_check_result x WHERE x.co_cd=p_co_cd AND x.item_idx=r.idx)) ORDER BY r.row_seq),'[]'::jsonb) INTO v_rows FROM tbl_process_check_item r WHERE r.co_cd=p_co_cd AND r.hdr_idx=v_hdr_idx;
    END IF;
    IF v_header IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
    RETURN jsonb_build_object('header',v_header,'rows',v_rows);
END$$;

-- 저장 — 양식별 헤더·행을 전체 교체하고 문서 상태가 잠기면 변경을 거부한다.
CREATE OR REPLACE FUNCTION sp_tbl_biz_ops_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 저장할 양식 코드
    p_tmpl_cd varchar,
    -- p_doc_idx: 기존 문서 idx. NULL/0이면 신규
    p_doc_idx bigint,
    -- p_payload: header 필드와 rows 배열을 담는 camelCase JSON
    p_payload jsonb,
    -- p_id: JWT 작업자 ID
    p_id varchar
)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_doc_idx bigint; v_hdr_idx bigint; v_item_idx bigint; v_status varchar(4); v_doc_no varchar(50); v_title varchar(200);
    v_base_dt varchar(8); v_base_ym varchar(6); v_tmpl_nm varchar(200); v_appr varchar(20); v_retain_m int;
    v_row jsonb; v_result jsonb; v_seq int; v_judge varchar(1); v_recv_judge varchar(1);
BEGIN
    IF p_tmpl_cd NOT IN ('FACILITY','CALIB_TARGET','WASTE','INV_CHECK','RECV_INSP','PROCESS') THEN RAISE EXCEPTION '지원하지 않는 양식입니다.' USING ERRCODE='45000'; END IF;
    IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' OR jsonb_typeof(coalesce(p_payload->'rows','null'::jsonb)) <> 'array' THEN RAISE EXCEPTION '저장 자료가 올바르지 않습니다.' USING ERRCODE='45000'; END IF;
    v_base_dt := coalesce(nullif(p_payload->>'baseDt',''), to_char(current_date,'YYYYMMDD'));
    v_base_ym := coalesce(nullif(p_payload->>'baseYm',''), substr(v_base_dt,1,6));
    IF length(v_base_dt) <> 8 OR length(v_base_ym) <> 6 THEN RAISE EXCEPTION '기준일자는 YYYYMMDD 형식으로 입력하세요.' USING ERRCODE='45000'; END IF;
    SELECT coalesce(ct.tmpl_nm_ovr,t.tmpl_nm),coalesce(ct.appr_line_cd,'DEFAULT'),coalesce(ct.retention_month,t.default_retention_month) INTO v_tmpl_nm,v_appr,v_retain_m FROM tbl_template t LEFT JOIN tbl_company_template ct ON ct.co_cd=p_co_cd AND ct.tmpl_cd=t.tmpl_cd AND ct.use_yn='Y' WHERE t.tmpl_cd=p_tmpl_cd AND t.use_yn='Y';
    IF v_tmpl_nm IS NULL THEN RAISE EXCEPTION '양식이 등록되어 있지 않습니다.' USING ERRCODE='45000'; END IF;
    v_title := v_tmpl_nm || ' (' || substr(v_base_dt,1,4) || '-' || substr(v_base_dt,5,2) || '-' || substr(v_base_dt,7,2) || ')';
    IF coalesce(p_doc_idx,0)=0 THEN
        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd,p_tmpl_cd,v_base_dt);
        INSERT INTO tbl_document(co_cd,tmpl_cd,doc_kind,doc_no,base_dt,title,status,appr_line_cd,writer_id,write_dt,ver_no,retention_until,del_yn,ins_id,ins_dt)
        VALUES(p_co_cd,p_tmpl_cd,'DB',v_doc_no,v_base_dt,v_title,'WRK',v_appr,p_id,now(),1,to_char((to_date(v_base_dt,'YYYYMMDD')+(coalesce(v_retain_m,24)||' months')::interval)::date,'YYYYMMDD'),'N',p_id,now()) RETURNING idx INTO v_doc_idx;
    ELSE
        SELECT idx,status INTO v_doc_idx,v_status FROM tbl_document WHERE idx=p_doc_idx AND co_cd=p_co_cd AND tmpl_cd=p_tmpl_cd AND del_yn='N';
        IF v_doc_idx IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
        IF v_status IN ('REQ','REV','APV') THEN RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 수정할 수 없습니다.' USING ERRCODE='45000'; END IF;
        UPDATE tbl_document SET base_dt=v_base_dt,title=v_title,upd_id=p_id,upd_dt=now() WHERE idx=v_doc_idx AND co_cd=p_co_cd;
    END IF;
    IF p_tmpl_cd='FACILITY' THEN
        INSERT INTO tbl_facility_check(co_cd,doc_idx,base_dt,checker_id,checker_nm,ins_id) VALUES(p_co_cd,v_doc_idx,v_base_dt,nullif(p_payload->>'checkerId',''),nullif(p_payload->>'checkerNm',''),p_id) ON CONFLICT(doc_idx) DO UPDATE SET base_dt=excluded.base_dt,checker_id=excluded.checker_id,checker_nm=excluded.checker_nm,upd_id=p_id,upd_dt=now() RETURNING idx INTO v_hdr_idx;
        DELETE FROM tbl_facility_check_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
        FOR v_row IN SELECT * FROM jsonb_array_elements(p_payload->'rows') LOOP
            v_seq:=coalesce((v_row->>'rowSeq')::int,0);
            IF v_seq<=0 THEN RAISE EXCEPTION '점검 행 순번이 올바르지 않습니다.' USING ERRCODE='45000'; END IF;
            v_judge:=nullif(v_row->>'judgeCd','');
            -- 부적합일 때(= X) 조치사항 또는 이탈시조치 중 하나는 필수
            IF v_judge='X' AND coalesce(nullif(v_row->>'actionDesc',''), nullif(v_row->>'actionRmk',''),'')='' THEN
                RAISE EXCEPTION '%번째 부적합 항목의 조치사항을 입력하세요.',v_seq USING ERRCODE='45000';
            END IF;
            INSERT INTO tbl_facility_check_item(
                co_cd, hdr_idx, row_seq, place_nm, grp_nm, item_cd, item_nm,
                method_nm, cycle_nm, mng_nm, judge_cd, action_rmk, action_desc, ins_id
            ) VALUES (
                p_co_cd, v_hdr_idx, v_seq,
                nullif(v_row->>'placeNm',''),
                nullif(v_row->>'grpNm',''),
                nullif(v_row->>'itemCd',''),
                nullif(v_row->>'itemNm',''),
                nullif(v_row->>'methodNm',''),
                nullif(v_row->>'cycleNm',''),
                nullif(v_row->>'mngNm',''),
                v_judge,
                nullif(v_row->>'actionRmk',''),
                nullif(v_row->>'actionDesc',''),
                p_id
            );
        END LOOP;
    ELSIF p_tmpl_cd='CALIB_TARGET' THEN
        INSERT INTO tbl_calib_target(co_cd,doc_idx,base_year,base_dt,checker_id,checker_nm,ins_id) VALUES(p_co_cd,v_doc_idx,coalesce(nullif(p_payload->>'baseYear',''),substr(v_base_dt,1,4)),v_base_dt,nullif(p_payload->>'checkerId',''),nullif(p_payload->>'checkerNm',''),p_id) ON CONFLICT(doc_idx) DO UPDATE SET base_year=excluded.base_year,base_dt=excluded.base_dt,checker_id=excluded.checker_id,checker_nm=excluded.checker_nm,upd_id=p_id,upd_dt=now() RETURNING idx INTO v_hdr_idx;
        DELETE FROM tbl_calib_target_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
        FOR v_row IN SELECT * FROM jsonb_array_elements(p_payload->'rows') LOOP v_seq:=coalesce((v_row->>'rowSeq')::int,0); IF v_seq<=0 OR coalesce(v_row->>'deviceCd','')='' THEN RAISE EXCEPTION '계측기 코드와 행 순번은 필수입니다.' USING ERRCODE='45000'; END IF; INSERT INTO tbl_calib_target_row(co_cd,hdr_idx,row_seq,device_cd,device_nm,official_calib_dt,self_calib_dt,next_calib_dt,done_doc_idx,remark,ins_id) VALUES(p_co_cd,v_hdr_idx,v_seq,v_row->>'deviceCd',nullif(v_row->>'deviceNm',''),nullif(v_row->>'officialCalibDt',''),nullif(v_row->>'selfCalibDt',''),nullif(v_row->>'nextCalibDt',''),nullif(v_row->>'doneDocIdx','')::bigint,nullif(v_row->>'remark',''),p_id); END LOOP;
    ELSIF p_tmpl_cd='WASTE' THEN
        INSERT INTO tbl_waste_check(co_cd,doc_idx,base_dt,base_dt_to,ins_id) VALUES(p_co_cd,v_doc_idx,v_base_dt,nullif(p_payload->>'baseDtTo',''),p_id) ON CONFLICT(doc_idx) DO UPDATE SET base_dt=excluded.base_dt,base_dt_to=excluded.base_dt_to,upd_id=p_id,upd_dt=now() RETURNING idx INTO v_hdr_idx;
        DELETE FROM tbl_inv_txn WHERE co_cd=p_co_cd AND src_tmpl_cd='WASTE' AND src_doc_idx=v_doc_idx; DELETE FROM tbl_waste_check_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
        FOR v_row IN SELECT * FROM jsonb_array_elements(p_payload->'rows') LOOP v_seq:=coalesce((v_row->>'rowSeq')::int,0); IF v_seq<=0 OR coalesce(v_row->>'procDt','')='' OR coalesce(v_row->>'itemNm','')='' THEN RAISE EXCEPTION '폐기일자·품명·행 순번은 필수입니다.' USING ERRCODE='45000'; END IF; INSERT INTO tbl_waste_check_row(co_cd,hdr_idx,row_seq,proc_dt,waste_gbn,item_nm,make_dt,expire_dt,weight_kg,bad_desc,proc_desc,partner_cd,partner_nm,mng_user_id,mng_nm,ins_id) VALUES(p_co_cd,v_hdr_idx,v_seq,v_row->>'procDt',nullif(v_row->>'wasteGbn',''),v_row->>'itemNm',nullif(v_row->>'makeDt',''),nullif(v_row->>'expireDt',''),nullif(v_row->>'weightKg','')::numeric,nullif(v_row->>'badDesc',''),nullif(v_row->>'procDesc',''),nullif(v_row->>'partnerCd',''),nullif(v_row->>'partnerNm',''),nullif(v_row->>'mngUserId',''),nullif(v_row->>'mngNm',''),p_id); INSERT INTO tbl_inv_txn(co_cd,txn_dt,txn_gbn,item_gbn,item_nm,qty,unit_nm,src_tmpl_cd,src_doc_idx,remark,ins_id) VALUES(p_co_cd,v_row->>'procDt','OUT','WASTE',v_row->>'itemNm',coalesce(nullif(v_row->>'weightKg','')::numeric,0),'kg','WASTE',v_doc_idx,nullif(v_row->>'procDesc',''),p_id); END LOOP;
    ELSIF p_tmpl_cd='INV_CHECK' THEN
        INSERT INTO tbl_inv_check(co_cd,doc_idx,base_ym,ins_id) VALUES(p_co_cd,v_doc_idx,v_base_ym,p_id) ON CONFLICT(doc_idx) DO UPDATE SET base_ym=excluded.base_ym,upd_id=p_id,upd_dt=now() RETURNING idx INTO v_hdr_idx;
        DELETE FROM tbl_inv_txn WHERE co_cd=p_co_cd AND src_tmpl_cd='INV_CHECK' AND src_doc_idx=v_doc_idx;
        FOR v_row IN SELECT * FROM jsonb_array_elements(p_payload->'rows') LOOP v_seq:=coalesce((v_row->>'rowSeq')::int,0); IF v_seq<=0 OR coalesce(v_row->>'txnDt','')='' OR coalesce(v_row->>'txnGbn','') NOT IN ('IN','OUT') OR coalesce(v_row->>'itemNm','')='' THEN RAISE EXCEPTION '수불 일자·구분·품명·행 순번은 필수입니다.' USING ERRCODE='45000'; END IF; INSERT INTO tbl_inv_txn(co_cd,txn_dt,txn_gbn,item_gbn,material_cd,product_cd,item_nm,partner_cd,partner_nm,qty,unit_nm,lot_no,make_dt,expire_dt,storage_cd,src_tmpl_cd,src_doc_idx,remark,ins_id) VALUES(p_co_cd,v_row->>'txnDt',v_row->>'txnGbn',coalesce(nullif(v_row->>'itemGbn',''),'SUB'),nullif(v_row->>'materialCd',''),nullif(v_row->>'productCd',''),v_row->>'itemNm',nullif(v_row->>'partnerCd',''),nullif(v_row->>'partnerNm',''),coalesce(nullif(v_row->>'qty','')::numeric,0),nullif(v_row->>'unitNm',''),nullif(v_row->>'lotNo',''),nullif(v_row->>'makeDt',''),nullif(v_row->>'expireDt',''),nullif(v_row->>'storageCd',''),'INV_CHECK',v_doc_idx,nullif(v_row->>'remark',''),p_id); END LOOP;
    ELSIF p_tmpl_cd='RECV_INSP' THEN
        v_recv_judge:=CASE WHEN EXISTS(SELECT 1 FROM jsonb_array_elements(p_payload->'rows') x WHERE x->>'judgeCd'='F') THEN 'F' ELSE 'P' END;
        INSERT INTO tbl_recv_inspect(co_cd,doc_idx,base_dt,recv_gbn,recv_time,partner_cd,partner_nm,material_cd,item_nm,recv_qty,unit_nm,lot_no,make_dt,expire_dt,core_temp,car_temp,vehicle_cd,car_no,haccp_apply_cd,judge_cd,checker_id,checker_nm,ins_id) VALUES(p_co_cd,v_doc_idx,v_base_dt,coalesce(nullif(p_payload->>'recvGbn',''),'SUB'),nullif(p_payload->>'recvTime',''),nullif(p_payload->>'partnerCd',''),nullif(p_payload->>'partnerNm',''),nullif(p_payload->>'materialCd',''),nullif(p_payload->>'itemNm',''),nullif(p_payload->>'recvQty','')::numeric,nullif(p_payload->>'unitNm',''),nullif(p_payload->>'lotNo',''),nullif(p_payload->>'makeDt',''),nullif(p_payload->>'expireDt',''),nullif(p_payload->>'coreTemp','')::numeric,nullif(p_payload->>'carTemp','')::numeric,nullif(p_payload->>'vehicleCd',''),nullif(p_payload->>'carNo',''),nullif(p_payload->>'haccpApplyCd',''),v_recv_judge,nullif(p_payload->>'checkerId',''),nullif(p_payload->>'checkerNm',''),p_id) ON CONFLICT(doc_idx) DO UPDATE SET base_dt=excluded.base_dt,recv_gbn=excluded.recv_gbn,recv_time=excluded.recv_time,partner_cd=excluded.partner_cd,partner_nm=excluded.partner_nm,material_cd=excluded.material_cd,item_nm=excluded.item_nm,recv_qty=excluded.recv_qty,unit_nm=excluded.unit_nm,lot_no=excluded.lot_no,make_dt=excluded.make_dt,expire_dt=excluded.expire_dt,core_temp=excluded.core_temp,car_temp=excluded.car_temp,vehicle_cd=excluded.vehicle_cd,car_no=excluded.car_no,haccp_apply_cd=excluded.haccp_apply_cd,judge_cd=excluded.judge_cd,checker_id=excluded.checker_id,checker_nm=excluded.checker_nm,upd_id=p_id,upd_dt=now() RETURNING idx INTO v_hdr_idx;
        DELETE FROM tbl_recv_inspect_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx; DELETE FROM tbl_inv_txn WHERE co_cd=p_co_cd AND src_tmpl_cd='RECV_INSP' AND src_doc_idx=v_doc_idx;
        FOR v_row IN SELECT * FROM jsonb_array_elements(p_payload->'rows') LOOP v_seq:=coalesce((v_row->>'rowSeq')::int,0); IF v_seq<=0 OR coalesce(v_row->>'itemCd','')='' THEN RAISE EXCEPTION '입고검사 항목과 행 순번은 필수입니다.' USING ERRCODE='45000'; END IF; INSERT INTO tbl_recv_inspect_item(co_cd,hdr_idx,row_seq,grp_cd,item_cd,item_nm,judge_cd,eval_desc,ins_id) VALUES(p_co_cd,v_hdr_idx,v_seq,coalesce(nullif(v_row->>'grpCd',''),'EVAL'),v_row->>'itemCd',nullif(v_row->>'itemNm',''),nullif(v_row->>'judgeCd',''),nullif(v_row->>'evalDesc',''),p_id); END LOOP;
        IF v_recv_judge='P' AND coalesce(p_payload->>'itemNm','')<>'' THEN INSERT INTO tbl_inv_txn(co_cd,txn_dt,txn_gbn,item_gbn,material_cd,item_nm,partner_cd,partner_nm,qty,unit_nm,lot_no,make_dt,expire_dt,src_tmpl_cd,src_doc_idx,ins_id) VALUES(p_co_cd,v_base_dt,'IN',coalesce(nullif(p_payload->>'recvGbn',''),'SUB'),nullif(p_payload->>'materialCd',''),p_payload->>'itemNm',nullif(p_payload->>'partnerCd',''),nullif(p_payload->>'partnerNm',''),coalesce(nullif(p_payload->>'recvQty','')::numeric,0),nullif(p_payload->>'unitNm',''),nullif(p_payload->>'lotNo',''),nullif(p_payload->>'makeDt',''),nullif(p_payload->>'expireDt',''),'RECV_INSP',v_doc_idx,p_id); END IF;
    ELSE
        INSERT INTO tbl_process_check(co_cd,doc_idx,base_dt,base_dt_to,cycle_nm,ins_id) VALUES(p_co_cd,v_doc_idx,v_base_dt,nullif(p_payload->>'baseDtTo',''),nullif(p_payload->>'cycleNm',''),p_id) ON CONFLICT(doc_idx) DO UPDATE SET base_dt=excluded.base_dt,base_dt_to=excluded.base_dt_to,cycle_nm=excluded.cycle_nm,upd_id=p_id,upd_dt=now() RETURNING idx INTO v_hdr_idx;
        DELETE FROM tbl_process_check_result x USING tbl_process_check_item r WHERE x.item_idx=r.idx AND x.co_cd=r.co_cd AND r.co_cd=p_co_cd AND r.hdr_idx=v_hdr_idx; DELETE FROM tbl_process_check_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
        FOR v_row IN SELECT * FROM jsonb_array_elements(p_payload->'rows') LOOP
            v_seq:=coalesce((v_row->>'rowSeq')::int,0);
            IF v_seq<=0 OR coalesce(v_row->>'itemCd','')='' THEN RAISE EXCEPTION '공정관리 항목과 행 순번은 필수입니다.' USING ERRCODE='45000'; END IF;
            INSERT INTO tbl_process_check_item(co_cd,hdr_idx,row_seq,proc_cd,proc_nm,item_cd,item_nm,ins_id)
            VALUES(p_co_cd,v_hdr_idx,v_seq,nullif(v_row->>'procCd',''),nullif(v_row->>'procNm',''),v_row->>'itemCd',nullif(v_row->>'itemNm',''),p_id)
            RETURNING idx INTO v_item_idx;
            FOR v_result IN SELECT * FROM jsonb_array_elements(coalesce(v_row->'results','[]'::jsonb)) LOOP
                IF coalesce(v_result->>'checkDt','')='' OR coalesce(v_result->>'ampmCd','') NOT IN ('AM','PM') THEN RAISE EXCEPTION '공정 점검일자와 오전·오후 구분은 필수입니다.' USING ERRCODE='45000'; END IF;
                INSERT INTO tbl_process_check_result(co_cd,item_idx,check_dt,ampm_cd,judge_cd,ins_id)
                VALUES(p_co_cd,v_item_idx,v_result->>'checkDt',v_result->>'ampmCd',nullif(v_result->>'judgeCd',''),p_id);
            END LOOP;
        END LOOP;
    END IF;
    RETURN v_doc_idx;
END$$;

-- 삭제 — 공통 문서 잠금을 확인하고 양식별 하위 데이터를 제거한다.
CREATE OR REPLACE PROCEDURE sp_tbl_biz_ops_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 삭제할 양식 코드
    p_tmpl_cd varchar,
    -- p_doc_idx: 삭제할 문서 idx
    p_doc_idx bigint,
    -- p_id: 작업자 ID. 감사 확장 대비 파라미터 유지
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_status varchar(4); v_hdr_idx bigint;
BEGIN
    SELECT status INTO v_status FROM tbl_document WHERE co_cd=p_co_cd AND idx=p_doc_idx AND tmpl_cd=p_tmpl_cd AND del_yn='N';
    IF v_status IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
    IF v_status NOT IN ('WRK','RJT') THEN RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 삭제할 수 없습니다.' USING ERRCODE='45000'; END IF;
    IF p_tmpl_cd='FACILITY' THEN SELECT idx INTO v_hdr_idx FROM tbl_facility_check WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx; DELETE FROM tbl_facility_check_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx; DELETE FROM tbl_facility_check WHERE co_cd=p_co_cd AND idx=v_hdr_idx;
    ELSIF p_tmpl_cd='CALIB_TARGET' THEN SELECT idx INTO v_hdr_idx FROM tbl_calib_target WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx; DELETE FROM tbl_calib_target_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx; DELETE FROM tbl_calib_target WHERE co_cd=p_co_cd AND idx=v_hdr_idx;
    ELSIF p_tmpl_cd='WASTE' THEN SELECT idx INTO v_hdr_idx FROM tbl_waste_check WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx; DELETE FROM tbl_inv_txn WHERE co_cd=p_co_cd AND src_tmpl_cd='WASTE' AND src_doc_idx=p_doc_idx; DELETE FROM tbl_waste_check_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx; DELETE FROM tbl_waste_check WHERE co_cd=p_co_cd AND idx=v_hdr_idx;
    ELSIF p_tmpl_cd='INV_CHECK' THEN DELETE FROM tbl_inv_txn WHERE co_cd=p_co_cd AND src_tmpl_cd='INV_CHECK' AND src_doc_idx=p_doc_idx; DELETE FROM tbl_inv_check WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx;
    ELSIF p_tmpl_cd='RECV_INSP' THEN SELECT idx INTO v_hdr_idx FROM tbl_recv_inspect WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx; DELETE FROM tbl_inv_txn WHERE co_cd=p_co_cd AND src_tmpl_cd='RECV_INSP' AND src_doc_idx=p_doc_idx; DELETE FROM tbl_recv_inspect_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx; DELETE FROM tbl_recv_inspect WHERE co_cd=p_co_cd AND idx=v_hdr_idx;
    ELSIF p_tmpl_cd='PROCESS' THEN SELECT idx INTO v_hdr_idx FROM tbl_process_check WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx; DELETE FROM tbl_process_check_result x USING tbl_process_check_item r WHERE x.item_idx=r.idx AND x.co_cd=r.co_cd AND r.co_cd=p_co_cd AND r.hdr_idx=v_hdr_idx; DELETE FROM tbl_process_check_signer WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx; DELETE FROM tbl_process_check_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx; DELETE FROM tbl_process_check WHERE co_cd=p_co_cd AND idx=v_hdr_idx;
    END IF;
    DELETE FROM tbl_corrective_action WHERE co_cd=p_co_cd AND src_doc_idx=p_doc_idx;
    DELETE FROM tbl_document_approval WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx;
    DELETE FROM tbl_document_file WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx;
    DELETE FROM tbl_document WHERE co_cd=p_co_cd AND idx=p_doc_idx;
END$$;
