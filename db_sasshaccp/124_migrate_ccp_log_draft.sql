-- ============================================================
-- 124 — CCP 모니터링일지 작성 (draft/ccp-monitoring/ccp-pkg · ccp-htg · ccp-mtl)
--
-- 파일번호: 124
-- 이전번호: 123
-- 개발자: 박승우
-- 일자: 2026-08-24
-- 코멘트:
--   1) 양식관리 ccp-pkg-template · ccp-htg-template · ccp-mtl-template 에서 사용여부 예로 둔
--      자사 양식(tml_ccp_pkg_NNN · tml_ccp_htg_NNN · tml_ccp_mtl_NNN)을 일자별로 작성한다
--   2) 신규 테이블을 만들지 않는다. PKG·HTG 는 tbl_ccp_generic_monitor(+_row·_cell),
--      MTL 은 tbl_ccp_metal_monitor(+_sens_row·_pass_row)를 그대로 쓴다.
--      작업 전/후 구분 phase_cd 는 두 계열 모두 이미 컬럼이 있다(38·05). ALTER 없음
--   3) 기존 화면(ccp-metal-monitor · ccp-heat/sanitize/filter-monitor)의 동작을 바꾸지 않는다.
--      금속 SP 는 p_tmpl_cd 를 맨 뒤 DEFAULT 인자로 열어 기존 호출 arity 가 그대로 통한다
--
-- 지면(Paper)은 mode=template(미리보기) / mode=write(작성)로 갈린다. 기준관리 화면은 손대지 않는다.
-- 121·122·123 을 먼저 적용해야 한다. Jenkins는 migrate를 안 돌린다. DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

-- ------------------------------------------------------------
-- 1. 공통 CCP(PKG·HTG) 저장 — phase_cd 저장 · 채번 규칙 보강 · 결재선/보존기간
--    기존 인자·arity 그대로. heat/sanitize/filter 화면은 phaseCd 를 안 넘겨 NULL 이 된다
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_generic_monitor_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 기존 문서 idx. NULL·0 이면 신규
    p_doc_idx bigint,
    -- p_base_dt: 작성일 YYYYMMDD
    p_base_dt varchar,
    -- p_tmpl_cd: 양식코드 — html_sys_003/004/005 또는 tml_ccp_pkg_NNN · tml_ccp_htg_NNN
    p_tmpl_cd varchar,
    p_ccp_cd varchar,
    p_diary_no varchar,
    p_limit_item_kind varchar,
    p_mng_user_id varchar,
    p_mng_nm varchar,
    -- p_rows: [{rowSeq, phaseCd, checkTime, equipNm, productNm, judgeCd, judgeModYn, checkerId, checkerNm, signYn, cells[]}]
    p_rows jsonb,
    p_id varchar
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_doc_idx bigint;
    v_monitor_idx bigint;
    v_doc_no varchar;
    v_title varchar(300);
    v_appr varchar;
    v_retain int;
    v_row jsonb;
    v_cell jsonb;
    v_row_idx bigint;
BEGIN
    IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) = 0 THEN
        RAISE EXCEPTION '점검 행이 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 양식명·결재선·보존기간 — 자사 양식은 tbl_company_template 오버라이드가 우선
    SELECT coalesce(nullif(ct.tmpl_nm_ovr, ''), nullif(t.tmpl_nm, ''), '공통 CCP 모니터링'),
           COALESCE(ct.appr_line_cd, 'DEFAULT'),
           COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_title, v_appr, v_retain
      FROM tbl_template t
      LEFT JOIN tbl_company_template ct ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd AND ct.use_yn = 'Y'
     WHERE t.tmpl_cd = p_tmpl_cd AND t.doc_kind = 'html' AND t.use_yn = 'Y';
    IF v_title IS NULL THEN
        RAISE EXCEPTION '사용할 공통 CCP 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000';
    END IF;

    IF coalesce(p_doc_idx, 0) <= 0 THEN
        -- 자사 양식 복사 SP 는 채번 규칙을 만들지 않는다. 없을 때만 기본 규칙을 깐다
        INSERT INTO tbl_doc_no_rule (co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
        VALUES (p_co_cd, p_tmpl_cd, left(p_tmpl_cd, 20), 'YYYYMMDD', 3, 'D', p_id, now())
        ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd, p_tmpl_cd, p_base_dt);
        INSERT INTO tbl_document (
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status, appr_line_cd,
            writer_id, write_dt, ver_no, retention_until, form_src, del_yn, ins_id
        ) VALUES (
            p_co_cd, p_tmpl_cd, 'html', v_doc_no, p_base_dt, v_title, 'WRK', v_appr,
            p_id, now(), 1,
            to_char((to_date(p_base_dt, 'YYYYMMDD') + (COALESCE(v_retain, 24) || ' months')::interval)::date, 'YYYYMMDD'),
            'BASE', 'N', p_id
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
            RAISE EXCEPTION '전송한 문서는 수정할 수 없습니다. 전송취소 후 수정하세요.' USING ERRCODE = '45000';
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
            co_cd, monitor_idx, row_seq, phase_cd, check_time, equip_nm, product_nm,
            judge_cd, judge_mod_yn, checker_id, checker_nm, sign_img, ins_id
        ) VALUES (
            p_co_cd, v_monitor_idx, coalesce(nullif(v_row->>'rowSeq', '')::int, 0),
            -- 작업 전/작업 종료 구분 — 안 넘기면 NULL(기존 heat·sanitize·filter 화면)
            nullif(v_row->>'phaseCd', ''),
            nullif(v_row->>'checkTime', ''),
            nullif(v_row->>'equipNm', ''), nullif(v_row->>'productNm', ''),
            nullif(v_row->>'judgeCd', ''), coalesce(nullif(v_row->>'judgeModYn', ''), 'N'),
            nullif(v_row->>'checkerId', ''), nullif(v_row->>'checkerNm', ''),
            -- 서명은 signYn만 받고 검사자 서명 원본을 그 시점 값으로 복사한다
            CASE WHEN COALESCE(v_row->>'signYn', 'N') = 'Y'
                 THEN (SELECT u.sign_img FROM tbl_user u
                        WHERE u.co_cd = p_co_cd
                          AND u.user_id = nullif(v_row->>'checkerId', ''))
                 ELSE NULL END, p_id
        ) RETURNING idx INTO v_row_idx;
        FOR v_cell IN SELECT value FROM jsonb_array_elements(coalesce(v_row->'cells', '[]'::jsonb))
        LOOP
            INSERT INTO tbl_ccp_generic_monitor_cell (
                co_cd, row_idx, item_cd, num_val, txt_val, judge_cd, ins_id
            ) VALUES (
                p_co_cd, v_row_idx, v_cell->>'itemCd',
                nullif(v_cell->>'numVal', '')::numeric,
                nullif(v_cell->>'txtVal', ''),
                nullif(v_cell->>'judgeCd', ''), p_id
            );
        END LOOP;
    END LOOP;
    RETURN v_doc_idx;
END$$;
COMMENT ON FUNCTION sp_tbl_ccp_generic_monitor_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar, varchar, varchar, jsonb, varchar) IS
  '공통 CCP 저장 — 124에서 phase_cd·채번 규칙·결재선/보존기간 보강. 기존 인자 그대로';

-- ------------------------------------------------------------
-- 2. 공통 CCP 상세 — rows_json 에 phaseCd 추가 (시그니처 동일)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_generic_monitor_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 문서 idx
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
                              -- 작업 전/작업 종료 — 재조회 때 같은 영역에 다시 붙는다
                              'phaseCd', COALESCE(r.phase_cd, ''),
                              'checkTime', COALESCE(r.check_time, ''),
                              'equipNm', COALESCE(r.equip_nm, ''),
                              'productNm', COALESCE(r.product_nm, ''),
                              'judgeCd', r.judge_cd,
                              'judgeModYn', r.judge_mod_yn,
                              'checkerId', COALESCE(r.checker_id, ''),
                              'checkerNm', COALESCE(r.checker_nm, ''),
                              'signYn', (CASE WHEN r.sign_img IS NOT NULL THEN 'Y' ELSE 'N' END),
                              'cells', COALESCE((
                                  SELECT jsonb_agg(
                                             jsonb_build_object(
                                                 'itemCd', c.item_cd,
                                                 'numVal', c.num_val,
                                                 'txtVal', COALESCE(c.txt_val, ''),
                                                 'judgeCd', c.judge_cd
                                             ) ORDER BY c.item_cd
                                         )
                                    FROM tbl_ccp_generic_monitor_cell c
                                   WHERE c.row_idx = r.idx AND c.co_cd = r.co_cd
                              ), '[]'::jsonb)
                          ) ORDER BY r.row_seq
                      )
                 FROM tbl_ccp_generic_monitor_row r
                WHERE r.monitor_idx = m.idx AND r.co_cd = m.co_cd
           ), '[]'::jsonb) AS rows_json
      FROM tbl_document d
      JOIN tbl_ccp_generic_monitor m ON m.doc_idx = d.idx AND m.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.del_yn = 'N';
END$$;
COMMENT ON FUNCTION sp_tbl_ccp_generic_monitor_r_000(varchar, bigint) IS
  '공통 CCP 상세 — 124에서 rows_json 에 phaseCd 추가';

-- ------------------------------------------------------------
-- 3. 금속검출 — p_tmpl_cd 를 맨 뒤 DEFAULT 인자로 연다
--    기존 ccp-metal-monitor 화면은 인자를 안 넘겨 DEFAULT(tmpl_ccp-metal-log)로 동작한다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_ccp_metal_monitor_r_001(varchar, bigint);
CREATE FUNCTION sp_tbl_ccp_metal_monitor_r_001(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 문서 idx
    p_doc_idx bigint,
    -- p_tmpl_cd: 양식코드. 생략하면 기존 금속검출 일지
    p_tmpl_cd varchar DEFAULT 'tmpl_ccp-metal-log'
)
RETURNS TABLE (
    doc_idx bigint, hdr_idx bigint, doc_no varchar, base_dt varchar, ccp_cd varchar,
    fe_size numeric, sts_size numeric, mng_user_id varchar, mng_nm varchar, status varchar
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, h.idx, d.doc_no, h.base_dt, h.ccp_cd, h.fe_size, h.sts_size,
           h.mng_user_id, h.mng_nm, d.status
      FROM tbl_document d JOIN tbl_ccp_metal_monitor h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N';
$$;
COMMENT ON FUNCTION sp_tbl_ccp_metal_monitor_r_001(varchar, bigint, varchar) IS
  'CCP 금속검출 헤더 — 124에서 p_tmpl_cd 개방(기본값은 기존 양식)';

DROP FUNCTION IF EXISTS sp_tbl_ccp_metal_monitor_c_000(varchar, bigint, varchar, varchar, numeric, numeric, varchar, varchar, jsonb, jsonb, varchar);
CREATE FUNCTION sp_tbl_ccp_metal_monitor_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar, p_doc_idx bigint, p_base_dt varchar, p_ccp_cd varchar,
    p_fe_size numeric, p_sts_size numeric, p_mng_user_id varchar, p_mng_nm varchar,
    -- p_sens_rows_json: [{rowSeq, phaseCd, productNm, checkTime, feOnlyCd, stsOnlyCd, prodOnlyCd, feProdCd, stsProdCd, judgeCd, judgeModYn, checkerNm}]
    p_sens_rows_json jsonb,
    -- p_pass_rows_json: [{rowSeq, productNm, passQty, detectQty, unitNm, remark}]
    p_pass_rows_json jsonb,
    p_id varchar,
    -- p_tmpl_cd: 양식코드. 생략하면 기존 금속검출 일지
    p_tmpl_cd varchar DEFAULT 'tmpl_ccp-metal-log'
)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_doc_idx bigint; v_hdr_idx bigint; v_status varchar(4); v_name varchar; v_appr varchar; v_retain int; r jsonb; v_judge varchar(1);
BEGIN
    IF COALESCE(p_base_dt, '') = '' OR length(p_base_dt) <> 8 THEN RAISE EXCEPTION '작성일은 YYYYMMDD 8자리로 입력하세요.' USING ERRCODE = '45000'; END IF;
    IF p_sens_rows_json IS NULL OR jsonb_typeof(p_sens_rows_json) <> 'array' THEN RAISE EXCEPTION '감도 점검 행 자료가 올바르지 않습니다.' USING ERRCODE = '45000'; END IF;
    SELECT COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm), COALESCE(ct.appr_line_cd, 'DEFAULT'), COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_name, v_appr, v_retain FROM tbl_template t LEFT JOIN tbl_company_template ct ON ct.co_cd=p_co_cd AND ct.tmpl_cd=t.tmpl_cd AND ct.use_yn='Y'
     WHERE t.tmpl_cd=p_tmpl_cd AND t.use_yn='Y';
    IF v_name IS NULL THEN RAISE EXCEPTION 'CCP 금속검출 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000'; END IF;
    IF p_doc_idx IS NULL OR p_doc_idx = 0 THEN
        -- 자사 양식 복사 SP 는 채번 규칙을 만들지 않는다. 없을 때만 기본 규칙을 깐다
        INSERT INTO tbl_doc_no_rule (co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
        VALUES (p_co_cd, p_tmpl_cd, left(p_tmpl_cd, 20), 'YYYYMMDD', 3, 'D', p_id, now())
        ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

        INSERT INTO tbl_document(co_cd,tmpl_cd,doc_kind,doc_no,base_dt,title,status,appr_line_cd,writer_id,write_dt,ver_no,retention_until,del_yn,ins_id)
        VALUES(p_co_cd,p_tmpl_cd,'html',sp_tbl_doc_no_gen_c_000(p_co_cd,p_tmpl_cd,p_base_dt),p_base_dt,v_name || ' (' || p_base_dt || ')','WRK',v_appr,p_id,now(),1,to_char((to_date(p_base_dt,'YYYYMMDD')+(COALESCE(v_retain,24)||' months')::interval)::date,'YYYYMMDD'),'N',p_id) RETURNING idx INTO v_doc_idx;
        INSERT INTO tbl_ccp_metal_monitor(co_cd,doc_idx,base_dt,ccp_cd,fe_size,sts_size,mng_user_id,mng_nm,ins_id) VALUES(p_co_cd,v_doc_idx,p_base_dt,p_ccp_cd,p_fe_size,p_sts_size,NULLIF(p_mng_user_id,''),NULLIF(p_mng_nm,''),p_id) RETURNING idx INTO v_hdr_idx;
    ELSE
        SELECT d.idx,d.status,h.idx INTO v_doc_idx,v_status,v_hdr_idx FROM tbl_document d JOIN tbl_ccp_metal_monitor h ON h.doc_idx=d.idx AND h.co_cd=d.co_cd WHERE d.co_cd=p_co_cd AND d.idx=p_doc_idx AND d.tmpl_cd=p_tmpl_cd AND d.del_yn='N';
        IF v_doc_idx IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
        IF v_status IN ('REQ','REV','APV') THEN RAISE EXCEPTION '전송한 문서는 수정할 수 없습니다. 전송취소 후 수정하세요.' USING ERRCODE='45000'; END IF;
        UPDATE tbl_document SET base_dt=p_base_dt,title=v_name || ' (' || p_base_dt || ')',upd_id=p_id,upd_dt=now() WHERE idx=v_doc_idx AND co_cd=p_co_cd;
        UPDATE tbl_ccp_metal_monitor SET base_dt=p_base_dt,ccp_cd=p_ccp_cd,fe_size=p_fe_size,sts_size=p_sts_size,mng_user_id=NULLIF(p_mng_user_id,''),mng_nm=NULLIF(p_mng_nm,''),upd_id=p_id,upd_dt=now() WHERE idx=v_hdr_idx AND co_cd=p_co_cd;
        DELETE FROM tbl_ccp_metal_sens_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
        DELETE FROM tbl_ccp_metal_pass_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
    END IF;
    FOR r IN SELECT * FROM jsonb_array_elements(p_sens_rows_json) LOOP
        IF COALESCE((r->>'rowSeq')::int,0) <= 0 THEN RAISE EXCEPTION '감도 점검 행 순번이 올바르지 않습니다.' USING ERRCODE='45000'; END IF;
        -- 자동 판정 — 5칸이 기준과 같으면 적합. 사용자가 고쳤으면(judgeModYn=Y) 그 값을 쓴다
        v_judge := CASE WHEN r->>'feOnlyCd'='O' AND r->>'stsOnlyCd'='O' AND r->>'prodOnlyCd'='X' AND r->>'feProdCd'='O' AND r->>'stsProdCd'='O' THEN 'P' ELSE 'F' END;
        INSERT INTO tbl_ccp_metal_sens_row(co_cd,hdr_idx,row_seq,phase_cd,product_cd,product_nm,place_nm,check_time,fe_only_cd,sts_only_cd,prod_only_cd,fe_prod_cd,sts_prod_cd,judge_cd,judge_mod_yn,checker_id,checker_nm,ins_id)
        VALUES(p_co_cd,v_hdr_idx,(r->>'rowSeq')::int,COALESCE(NULLIF(r->>'phaseCd',''),'DURING'),NULLIF(r->>'productCd',''),NULLIF(r->>'productNm',''),NULLIF(r->>'placeNm',''),NULLIF(r->>'checkTime',''),NULLIF(r->>'feOnlyCd',''),NULLIF(r->>'stsOnlyCd',''),NULLIF(r->>'prodOnlyCd',''),NULLIF(r->>'feProdCd',''),NULLIF(r->>'stsProdCd',''),CASE WHEN r->>'judgeModYn'='Y' AND NULLIF(r->>'judgeCd','') IS NOT NULL THEN r->>'judgeCd' ELSE v_judge END,COALESCE(NULLIF(r->>'judgeModYn',''),'N'),NULLIF(r->>'checkerId',''),NULLIF(r->>'checkerNm',''),p_id);
    END LOOP;
    FOR r IN SELECT * FROM jsonb_array_elements(COALESCE(p_pass_rows_json,'[]'::jsonb)) LOOP
        INSERT INTO tbl_ccp_metal_pass_row(co_cd,hdr_idx,row_seq,product_cd,product_nm,pass_qty,detect_qty,unit_nm,remark,ins_id)
        VALUES(p_co_cd,v_hdr_idx,COALESCE((r->>'rowSeq')::int,0),NULLIF(r->>'productCd',''),NULLIF(r->>'productNm',''),NULLIF(r->>'passQty','')::numeric,NULLIF(r->>'detectQty','')::numeric,NULLIF(r->>'unitNm',''),NULLIF(r->>'remark',''),p_id);
    END LOOP;
    RETURN v_doc_idx;
END$$;
COMMENT ON FUNCTION sp_tbl_ccp_metal_monitor_c_000(varchar, bigint, varchar, varchar, numeric, numeric, varchar, varchar, jsonb, jsonb, varchar, varchar) IS
  'CCP 금속검출 저장 — 124에서 p_tmpl_cd 개방·채번 규칙 보강. 기본값은 기존 양식';

DROP PROCEDURE IF EXISTS sp_tbl_ccp_metal_monitor_d_000(varchar, bigint, varchar);
CREATE PROCEDURE sp_tbl_ccp_metal_monitor_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 삭제할 문서 idx
    p_doc_idx bigint,
    -- p_id: JWT 작업자 ID
    p_id varchar,
    -- p_tmpl_cd: 양식코드. 생략하면 기존 금속검출 일지
    p_tmpl_cd varchar DEFAULT 'tmpl_ccp-metal-log'
)
LANGUAGE plpgsql AS $$
DECLARE v_hdr_idx bigint; v_status varchar(4);
BEGIN
    SELECT h.idx, d.status INTO v_hdr_idx, v_status
      FROM tbl_document d
      JOIN tbl_ccp_metal_monitor h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N';
    IF v_hdr_idx IS NULL THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 전송대기(WRK·RJT)가 아닐 때(= 전송·결재완료) 삭제 차단. 전송취소를 먼저 해야 한다
    IF v_status NOT IN ('WRK', 'RJT') THEN
        RAISE EXCEPTION '전송한 문서는 삭제할 수 없습니다. 전송취소 후 삭제하세요.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_corrective_action WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx;
    DELETE FROM tbl_ccp_metal_sens_row WHERE co_cd = p_co_cd AND hdr_idx = v_hdr_idx;
    DELETE FROM tbl_ccp_metal_pass_row WHERE co_cd = p_co_cd AND hdr_idx = v_hdr_idx;
    DELETE FROM tbl_ccp_metal_monitor WHERE co_cd = p_co_cd AND idx = v_hdr_idx;
    DELETE FROM tbl_document_approval WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document_file WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document WHERE co_cd = p_co_cd AND idx = p_doc_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_ccp_metal_monitor_d_000(varchar, bigint, varchar, varchar) IS
  'CCP 금속검출 삭제 — 124에서 p_tmpl_cd 개방. 전송대기(WRK·RJT)만';

-- ------------------------------------------------------------
-- 4. 작성 목록 — 121·123 과 같은 계약(결재 여부는 화면이 DOC_STATUS 로 묶어 거른다)
--    PKG·HTG 공용(접두로 가름) · MTL 전용
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_ccp_log_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_ccp_log_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd     varchar,
    -- p_tmpl_pfx: 양식군 접두 — tml_ccp_pkg_ 또는 tml_ccp_htg_
    p_tmpl_pfx  varchar,
    -- p_tmpl_cd: 양식코드 부분검색. 빈값이면 접두 전체
    p_tmpl_cd   varchar,
    -- p_tmpl_nm: 양식명 부분검색
    p_tmpl_nm   varchar,
    -- p_from_dt: 일자 시작 YYYYMMDD
    p_from_dt   varchar,
    -- p_to_dt: 일자 종료 YYYYMMDD
    p_to_dt     varchar,
    -- p_writer_id: 작성자 ID 부분검색
    p_writer_id varchar,
    -- p_writer_nm: 작성자명 부분검색
    p_writer_nm varchar
)
RETURNS TABLE(
    doc_idx bigint, hdr_idx bigint, tmpl_cd varchar, tmpl_nm varchar, doc_no varchar,
    base_dt varchar, checker_nm varchar, writer_id varchar, writer_nm varchar,
    status varchar, row_cnt int, ng_cnt int
) LANGUAGE sql STABLE AS $$
    SELECT d.idx, m.idx,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm)::varchar,
           d.doc_no, m.base_dt, m.mng_nm,
           d.writer_id,
           COALESCE(u.user_nm, d.writer_id, '')::varchar,
           d.status,
           (SELECT count(*)::int FROM tbl_ccp_generic_monitor_row r WHERE r.monitor_idx = m.idx AND r.co_cd = m.co_cd),
           (SELECT count(*)::int FROM tbl_ccp_generic_monitor_row r WHERE r.monitor_idx = m.idx AND r.co_cd = m.co_cd AND r.judge_cd = 'F')
      FROM tbl_document d
      JOIN tbl_ccp_generic_monitor m ON m.doc_idx = d.idx AND m.co_cd = d.co_cd
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd AND d.del_yn = 'N'
       -- 이 화면은 해당 계열 자사 양식만 다룬다. 예시 000 은 제외
       AND d.tmpl_cd LIKE p_tmpl_pfx || '%'
       AND d.tmpl_cd <> p_tmpl_pfx || '000'
       AND (COALESCE(NULLIF(btrim(p_tmpl_cd), ''), '') = '' OR d.tmpl_cd ILIKE '%' || btrim(p_tmpl_cd) || '%')
       AND (COALESCE(NULLIF(btrim(p_tmpl_nm), ''), '') = ''
            OR COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, '') ILIKE '%' || btrim(p_tmpl_nm) || '%')
       AND (COALESCE(NULLIF(btrim(p_from_dt), ''), '') = '' OR m.base_dt >= btrim(p_from_dt))
       AND (COALESCE(NULLIF(btrim(p_to_dt), ''), '') = '' OR m.base_dt <= btrim(p_to_dt))
       AND (COALESCE(NULLIF(btrim(p_writer_id), ''), '') = '' OR COALESCE(d.writer_id, '') ILIKE '%' || btrim(p_writer_id) || '%')
       AND (COALESCE(NULLIF(btrim(p_writer_nm), ''), '') = '' OR COALESCE(u.user_nm, '') ILIKE '%' || btrim(p_writer_nm) || '%')
     ORDER BY m.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_ccp_log_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar) IS
  'CCP 포장·가열 작성 목록 — 양식군 접두로 가른다. 자사 양식만';

DROP FUNCTION IF EXISTS sp_ccp_mtl_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_ccp_mtl_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd     varchar,
    -- p_tmpl_cd: 양식코드 부분검색. 빈값이면 자사 금속검출 양식 전체
    p_tmpl_cd   varchar,
    -- p_tmpl_nm: 양식명 부분검색
    p_tmpl_nm   varchar,
    -- p_from_dt: 일자 시작 YYYYMMDD
    p_from_dt   varchar,
    -- p_to_dt: 일자 종료 YYYYMMDD
    p_to_dt     varchar,
    -- p_writer_id: 작성자 ID 부분검색
    p_writer_id varchar,
    -- p_writer_nm: 작성자명 부분검색
    p_writer_nm varchar
)
RETURNS TABLE(
    doc_idx bigint, hdr_idx bigint, tmpl_cd varchar, tmpl_nm varchar, doc_no varchar,
    base_dt varchar, checker_nm varchar, writer_id varchar, writer_nm varchar,
    status varchar, row_cnt int, ng_cnt int
) LANGUAGE sql STABLE AS $$
    SELECT d.idx, h.idx,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm)::varchar,
           d.doc_no, h.base_dt, h.mng_nm,
           d.writer_id,
           COALESCE(u.user_nm, d.writer_id, '')::varchar,
           d.status,
           (SELECT count(*)::int FROM tbl_ccp_metal_sens_row s WHERE s.hdr_idx = h.idx AND s.co_cd = h.co_cd),
           (SELECT count(*)::int FROM tbl_ccp_metal_sens_row s WHERE s.hdr_idx = h.idx AND s.co_cd = h.co_cd AND s.judge_cd = 'F')
      FROM tbl_document d
      JOIN tbl_ccp_metal_monitor h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd AND d.del_yn = 'N'
       -- 자사 금속검출 양식만. 기존 tmpl_ccp-metal-log 문서는 이 화면 대상이 아니다
       AND d.tmpl_cd ~ '^tml_ccp_mtl_[0-9]{3}$'
       AND d.tmpl_cd <> 'tml_ccp_mtl_000'
       AND (COALESCE(NULLIF(btrim(p_tmpl_cd), ''), '') = '' OR d.tmpl_cd ILIKE '%' || btrim(p_tmpl_cd) || '%')
       AND (COALESCE(NULLIF(btrim(p_tmpl_nm), ''), '') = ''
            OR COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, '') ILIKE '%' || btrim(p_tmpl_nm) || '%')
       AND (COALESCE(NULLIF(btrim(p_from_dt), ''), '') = '' OR h.base_dt >= btrim(p_from_dt))
       AND (COALESCE(NULLIF(btrim(p_to_dt), ''), '') = '' OR h.base_dt <= btrim(p_to_dt))
       AND (COALESCE(NULLIF(btrim(p_writer_id), ''), '') = '' OR COALESCE(d.writer_id, '') ILIKE '%' || btrim(p_writer_id) || '%')
       AND (COALESCE(NULLIF(btrim(p_writer_nm), ''), '') = '' OR COALESCE(u.user_nm, '') ILIKE '%' || btrim(p_writer_nm) || '%')
     ORDER BY h.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_ccp_mtl_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar) IS
  'CCP 금속검출 작성 목록 — tml_ccp_mtl_NNN 자사 양식만';

-- ------------------------------------------------------------
-- 5. 화면 · 권한 · 메뉴 — 대 draft(양식 작성) / 중 ccp-monitoring(CCP 모니터링)
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, ins_id) VALUES
    ('ccp-pkg', 'CCP 포장 모니터링일지 작성', 'CCP', NULL, 4301, 'system'),
    ('ccp-htg', 'CCP 가열 모니터링일지 작성', 'CCP', NULL, 4302, 'system'),
    ('ccp-mtl', 'CCP 금속검출 모니터링일지 작성', 'CCP', NULL, 4303, 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm, module_cd = EXCLUDED.module_cd, tmpl_cd = EXCLUDED.tmpl_cd,
    sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- 삭제는 ADMIN 만 Y — 100·121·123 과 같은 관례
INSERT INTO tbl_role_screen (co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
SELECT r.co_cd, r.usrgrp_cd, s.scrn_cd,
       'Y', 'Y', 'Y',
       CASE WHEN r.usrgrp_cd = 'ADMIN' THEN 'Y' ELSE 'N' END,
       'Y', 'system', now()
  FROM tbl_role r
  CROSS JOIN (VALUES ('ccp-pkg'), ('ccp-htg'), ('ccp-mtl')) AS s(scrn_cd)
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

-- 중분류 ccp-monitoring — docs 아래 ccp 와 menu_cd 가 겹치지 않는다
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'ccp-monitoring', 'CCP 모니터링', 'draft', NULL, 4300, 'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = 'draft', scrn_cd = NULL,
    use_yn = 'Y', sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- 소 leaf — menu_cd = scrn_cd (120 정본 규칙)
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, s.scrn_cd, s.scrn_nm, 'ccp-monitoring', s.scrn_cd, s.sort_no, 'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
 CROSS JOIN (SELECT scrn_cd, scrn_nm, sort_no FROM tbl_screen WHERE scrn_cd IN ('ccp-pkg', 'ccp-htg', 'ccp-mtl')) s
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = 'ccp-monitoring', scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 6. sort 인코딩 SP — 123 정의에 ccp-monitoring 을 더한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_menu_sort_encode_u_000(
    -- p_co_cd: NULL이면 전 업체, 값이면 해당 업체만
    p_co_cd varchar DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tbl_menu m
       SET sort_no = v.sn, upd_id = 'system', upd_dt = now()
      FROM (VALUES
        ('today-tasks', 1001),
        ('docs', 2000), ('flow', 3000), ('draft', 4000), ('bas', 5000), ('sys', 6000),
        ('ccp', 2100), ('prp', 2200), ('logis', 2300), ('admin', 2400),
        ('sch', 2500), ('hwp', 2600), ('html', 2700), ('appr-hidden', 2800),
        ('appr', 3100), ('box', 3200), ('ca', 3300),
        ('hyg', 4100), ('ccp-chk', 4200), ('ccp-monitoring', 4300),
        ('master', 5100),
        ('code', 6100), ('logs', 6200)
      ) AS v(menu_cd, sn)
     WHERE m.menu_cd = v.menu_cd
       AND m.use_yn = 'Y'
       AND (p_co_cd IS NULL OR m.co_cd = p_co_cd);

    -- sys/code leaf: 공통코드 → 메뉴 → 권한그룹 → 부서 → 사용자 → 결재선
    UPDATE tbl_menu m
       SET sort_no = v.ord, upd_id = 'system', upd_dt = now()
      FROM (VALUES
        ('common-code-management', 1),
        ('menu-management', 2),
        ('role-management', 3),
        ('department-management', 4),
        ('user-management', 5),
        ('approval-line-management', 6)
      ) AS v(scrn_cd, ord)
     WHERE m.scrn_cd = v.scrn_cd
       AND m.h_menu_cd = 'code'
       AND m.use_yn = 'Y'
       AND (p_co_cd IS NULL OR m.co_cd = p_co_cd);

    WITH mid AS (
        SELECT * FROM (VALUES
            ('ccp', 2, 1), ('prp', 2, 2),
            ('logis', 2, 3), ('admin', 2, 4),
            ('sch', 2, 5), ('hwp', 2, 6), ('html', 2, 7), ('appr-hidden', 2, 8),
            ('appr', 3, 1), ('box', 3, 2), ('ca', 3, 3),
            ('hyg', 4, 1), ('ccp-chk', 4, 2), ('ccp-monitoring', 4, 3),
            ('master', 5, 1),
            ('code', 6, 1), ('logs', 6, 2)
        ) AS t(mid_cd, dae_no, jung_no)
    ),
    ranked AS (
        SELECT m.co_cd, m.menu_cd,
               (mid.dae_no * 1000 + mid.jung_no * 100
                 + ROW_NUMBER() OVER (
                       PARTITION BY m.co_cd, m.h_menu_cd
                       ORDER BY m.sort_no, m.menu_cd
                   ))::int AS sn
          FROM tbl_menu m
          JOIN mid ON mid.mid_cd = m.h_menu_cd
         WHERE m.use_yn = 'Y'
           AND m.scrn_cd IS NOT NULL
           AND (p_co_cd IS NULL OR m.co_cd = p_co_cd)
    )
    UPDATE tbl_menu m
       SET sort_no = r.sn, upd_id = 'system', upd_dt = now()
      FROM ranked r
     WHERE m.co_cd = r.co_cd AND m.menu_cd = r.menu_cd;
END;
$$;
COMMENT ON PROCEDURE sp_tbl_menu_sort_encode_u_000(varchar) IS
  '메뉴 sort_no 인코딩 — 대(1~9)*1000+중(0~9)*100+소(0~99). draft=4(hyg·ccp-chk·ccp-monitoring)';

CALL sp_tbl_menu_sort_encode_u_000(NULL);

COMMIT;

-- ------------------------------------------------------------
-- 검증
-- ------------------------------------------------------------
-- SELECT menu_cd, h_menu_cd, scrn_cd, menu_nm, sort_no FROM tbl_menu WHERE h_menu_cd = 'ccp-monitoring' ORDER BY sort_no;
-- SELECT * FROM sp_ccp_log_r_000('{회사코드}', 'tml_ccp_pkg_', '', '', '', '', '', '');
-- SELECT * FROM sp_ccp_mtl_r_000('{회사코드}', '', '', '', '', '', '');
-- 기존 화면 회귀: SELECT * FROM sp_tbl_ccp_metal_monitor_r_001('{회사코드}', {docIdx});  -- 3번째 인자 생략 = 기존 동작
