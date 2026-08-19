-- ============================================================
--  SP 4 — 중요관리점(CCP) 냉장보관 모니터링
--
--  개발자: 박승우
--  일자: 2026-08-19
--  코멘트:
--    1) ccp-cold-monitor 전용 — 목록·상세·저장·삭제와 보관고·한계기준 조회를 한 파일에 모은다
--    2) 저장 시 tbl_document와 헤더·점검행·온도행을 한 트랜잭션으로 맞춘다(Spring @Transactional)
--    3) 온도 판정은 tbl_storage 개별범위 → tbl_ccp_limit 순으로 읽고, 수동변경(judge_mod_yn=Y)만 예외로 둔다
--    4) 양식코드는 html_sys_001/002/006. 운영 DB(이미 94/95)에는 이 파일을 다시 돌리지 않는다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_tbl_storage_r_000 — 보관고 목록 (일지 열 머리글)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_storage_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd    varchar,
    -- p_ccp_cd: CCP 코드 필터. 공백이면 전체
    p_ccp_cd   varchar,
    -- p_use_yn: 사용여부 필터. 공백이면 전체
    p_use_yn   varchar
)
RETURNS TABLE (
    idx          bigint,
    co_cd        varchar,
    storage_cd   varchar,
    storage_nm   varchar,
    storage_type varchar,
    ccp_cd       varchar,
    temp_min     numeric,
    temp_max     numeric,
    sort_no      int,
    use_yn       varchar
)
LANGUAGE sql STABLE AS $$
    SELECT s.idx, s.co_cd, s.storage_cd, s.storage_nm, s.storage_type,
           s.ccp_cd, s.temp_min, s.temp_max, s.sort_no, s.use_yn
      FROM tbl_storage s
     WHERE s.co_cd = p_co_cd
       AND (COALESCE(p_ccp_cd, '') = '' OR s.ccp_cd = p_ccp_cd)
       AND (COALESCE(p_use_yn, '') = '' OR s.use_yn = p_use_yn)
     ORDER BY s.sort_no, s.storage_cd;
$$;
COMMENT ON FUNCTION sp_tbl_storage_r_000(varchar, varchar, varchar) IS '보관고 목록 — CCP 냉장보관 일지 열 머리글의 근거';

-- ------------------------------------------------------------
-- 2. sp_tbl_ccp_limit_r_000 — CCP 한계기준 조회
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_limit_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd  varchar,
    -- p_ccp_cd: CCP 코드. 공백이면 사용 중인 전체
    p_ccp_cd varchar
)
RETURNS TABLE (
    idx        bigint,
    co_cd      varchar,
    ccp_cd     varchar,
    ccp_nm     varchar,
    proc_nm    varchar,
    limit_type varchar,
    min_val    numeric,
    max_val    numeric,
    unit_nm    varchar,
    fe_size    numeric,
    sts_size   numeric,
    cycle_min  int,
    form_title varchar,
    cycle_rmk  varchar,
    limit_rmk  varchar,
    method_rmk varchar,
    use_yn     varchar
)
LANGUAGE sql STABLE AS $$
    SELECT l.idx, l.co_cd, l.ccp_cd, l.ccp_nm, l.proc_nm, l.limit_type,
           l.min_val, l.max_val, l.unit_nm, l.fe_size, l.sts_size, l.cycle_min,
           l.form_title, l.cycle_rmk, l.limit_rmk, l.method_rmk, l.use_yn
      FROM tbl_ccp_limit l
     WHERE l.co_cd = p_co_cd
       AND l.use_yn = 'Y'
       AND (COALESCE(p_ccp_cd, '') = '' OR l.ccp_cd = p_ccp_cd)
     ORDER BY l.ccp_cd;
$$;
COMMENT ON FUNCTION sp_tbl_ccp_limit_r_000(varchar, varchar) IS 'CCP 한계기준 조회 — 자동판정·화면 한계기준란의 원천';

-- ------------------------------------------------------------
-- 3. sp_tbl_ccp_cold_monitor_r_000 — 냉장보관 일지 목록 (문서번호·작성자 검색)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_ccp_cold_monitor_r_000(varchar, varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_tbl_ccp_cold_monitor_r_000(
    p_co_cd   varchar,
    p_from_dt varchar,
    p_to_dt   varchar,
    p_ccp_cd  varchar,
    -- p_doc_no: 문서번호 부분검색. 공백이면 전체
    p_doc_no  varchar DEFAULT '',
    -- p_writer: 작성자 ID·이름 부분검색. 공백이면 전체
    p_writer  varchar DEFAULT ''
)
RETURNS TABLE (
    doc_idx     bigint,
    hdr_idx     bigint,
    co_cd       varchar,
    doc_no      varchar,
    base_dt     varchar,
    ccp_cd      varchar,
    title       varchar,
    status      varchar,
    mng_user_id varchar,
    mng_nm      varchar,
    writer_id   varchar,
    write_dt    timestamp,
    row_cnt     int,
    ng_cnt      int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, h.idx, d.co_cd, d.doc_no, h.base_dt, h.ccp_cd, d.title, d.status,
           h.mng_user_id, h.mng_nm, d.writer_id, d.write_dt,
           (SELECT COUNT(*)::int FROM tbl_ccp_cold_monitor_row r
             WHERE r.hdr_idx = h.idx AND r.co_cd = h.co_cd),
           (SELECT COUNT(*)::int FROM tbl_ccp_cold_monitor_row r
             WHERE r.hdr_idx = h.idx AND r.co_cd = h.co_cd AND r.judge_cd = 'F')
      FROM tbl_ccp_cold_monitor h
      JOIN tbl_document d ON d.idx = h.doc_idx AND d.co_cd = h.co_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE h.co_cd = p_co_cd
       AND d.del_yn = 'N'
       AND d.tmpl_cd = 'html_sys_001'
       AND (COALESCE(p_from_dt, '') = '' OR h.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR h.base_dt <= p_to_dt)
       AND (COALESCE(p_ccp_cd, '') = '' OR h.ccp_cd = p_ccp_cd)
       AND (COALESCE(p_doc_no, '') = '' OR d.doc_no ILIKE '%' || p_doc_no || '%')
       AND (
           COALESCE(p_writer, '') = ''
           OR d.writer_id ILIKE '%' || p_writer || '%'
           OR COALESCE(u.user_nm, '') ILIKE '%' || p_writer || '%'
       )
     ORDER BY h.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_tbl_ccp_cold_monitor_r_000(varchar, varchar, varchar, varchar, varchar, varchar) IS
  'CCP 냉장보관 일지 목록 — 기간·CCP·문서번호·작성자';

-- ------------------------------------------------------------
-- 4. sp_tbl_ccp_cold_monitor_r_001 — 헤더 단건
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_cold_monitor_r_001(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_doc_idx: 문서 idx
    p_doc_idx bigint
)
RETURNS TABLE (
    doc_idx     bigint,
    hdr_idx     bigint,
    co_cd       varchar,
    doc_no      varchar,
    base_dt     varchar,
    ccp_cd      varchar,
    title       varchar,
    status      varchar,
    mng_user_id varchar,
    mng_nm      varchar,
    writer_id   varchar,
    write_dt    timestamp,
    ver_no      int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx AS doc_idx,
           h.idx AS hdr_idx,
           d.co_cd,
           d.doc_no,
           h.base_dt,
           h.ccp_cd,
           d.title,
           d.status,
           h.mng_user_id,
           h.mng_nm,
           d.writer_id,
           d.write_dt,
           d.ver_no
      FROM tbl_ccp_cold_monitor h
      JOIN tbl_document d ON d.idx = h.doc_idx AND d.co_cd = h.co_cd
     WHERE h.co_cd = p_co_cd
       AND h.doc_idx = p_doc_idx
       AND d.del_yn = 'N';
$$;
COMMENT ON FUNCTION sp_tbl_ccp_cold_monitor_r_001(varchar, bigint) IS 'CCP 냉장보관 일지 헤더 단건 — 문서·헤더 조인';

-- ------------------------------------------------------------
-- 5. sp_tbl_ccp_cold_monitor_row_r_000 — 점검행 목록
-- 39 에서 writer_id/nm·sign_path 가 추가되어 OUT 시그니처가 달라진다.
-- 재실행 시 CREATE OR REPLACE 가 거부되므로 선행 DROP 한다.
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_ccp_cold_monitor_row_r_000(varchar, bigint);
CREATE OR REPLACE FUNCTION sp_tbl_ccp_cold_monitor_row_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_hdr_idx: 헤더 idx
    p_hdr_idx bigint
)
RETURNS TABLE (
    idx          bigint,
    co_cd        varchar,
    hdr_idx      bigint,
    row_seq      int,
    check_time   varchar,
    judge_cd     varchar,
    judge_mod_yn varchar,
    checker_id   varchar,
    checker_nm   varchar
)
LANGUAGE sql STABLE AS $$
    SELECT r.idx, r.co_cd, r.hdr_idx, r.row_seq, r.check_time,
           r.judge_cd, r.judge_mod_yn, r.checker_id, r.checker_nm
      FROM tbl_ccp_cold_monitor_row r
     WHERE r.co_cd = p_co_cd
       AND r.hdr_idx = p_hdr_idx
     ORDER BY r.row_seq;
$$;
COMMENT ON FUNCTION sp_tbl_ccp_cold_monitor_row_r_000(varchar, bigint) IS 'CCP 냉장보관 점검행 목록';

-- ------------------------------------------------------------
-- 6. sp_tbl_ccp_cold_monitor_temp_r_000 — 보관고 온도 (헤더 단위)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_cold_monitor_temp_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_hdr_idx: 헤더 idx — 하위 점검행의 온도를 모두 반환
    p_hdr_idx bigint
)
RETURNS TABLE (
    idx        bigint,
    co_cd      varchar,
    row_idx    bigint,
    row_seq    int,
    storage_cd varchar,
    temp_val   numeric,
    judge_cd   varchar
)
LANGUAGE sql STABLE AS $$
    SELECT t.idx, t.co_cd, t.row_idx, r.row_seq, t.storage_cd, t.temp_val, t.judge_cd
      FROM tbl_ccp_cold_monitor_temp t
      JOIN tbl_ccp_cold_monitor_row r ON r.idx = t.row_idx AND r.co_cd = t.co_cd
     WHERE t.co_cd = p_co_cd
       AND r.hdr_idx = p_hdr_idx
     ORDER BY r.row_seq, t.storage_cd;
$$;
COMMENT ON FUNCTION sp_tbl_ccp_cold_monitor_temp_r_000(varchar, bigint) IS 'CCP 냉장보관 온도행 — 헤더 하위 전체를 한 번에';

-- ------------------------------------------------------------
-- 7. sp_tbl_ccp_cold_monitor_c_000 — 저장 (문서+헤더+행+온도)
--    p_rows_json 예:
--    [{"rowSeq":1,"checkTime":"0800","judgeModYn":"N","checkerId":"a","checkerNm":"홍길동",
--      "temps":[{"storageCd":"ST01","tempVal":3.0}]}]
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_cold_monitor_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd       varchar,
    -- p_doc_idx: 기존 문서 idx. NULL/0이면(= 신규) 문서를 새로 만든다
    p_doc_idx     bigint,
    -- p_base_dt: 작성일 YYYYMMDD
    p_base_dt     varchar,
    -- p_ccp_cd: 적용 CCP 코드 — 헤더 표기·기본 한계기준. 보관고별 판정은 storage.ccp_cd를 우선
    p_ccp_cd      varchar,
    -- p_mng_user_id: 담당자 로그인 ID
    p_mng_user_id varchar,
    -- p_mng_nm: 담당자명 스냅샷
    p_mng_nm      varchar,
    -- p_rows_json: 점검행·온도 JSON 배열
    p_rows_json   jsonb,
    -- p_id: 작업자 로그인 ID
    p_id          varchar
)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_doc_idx   bigint;
    v_hdr_idx   bigint;
    v_doc_no    varchar(50);
    v_title     varchar(200);
    v_status    varchar(4);
    v_tmpl_nm   varchar(200);
    v_appr      varchar(20);
    v_retain_m  int;
    v_row       jsonb;
    v_temp      jsonb;
    v_row_idx   bigint;
    v_row_seq   int;
    v_check_tm  varchar(4);
    v_mod_yn    varchar(1);
    v_chk_id    varchar(20);
    v_chk_nm    varchar(50);
    v_man_judge varchar(1);
    v_row_judge varchar(1);
    v_st_cd     varchar(30);
    v_temp_val  numeric(5,1);
    v_cell_j    varchar(1);
    v_min       numeric(5,1);
    v_max       numeric(5,1);
    v_st_ccp    varchar(20);
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(p_base_dt, '') = '' OR length(p_base_dt) <> 8 THEN
        RAISE EXCEPTION '작성일은 YYYYMMDD 8자리로 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(p_ccp_cd, '') = '' THEN
        RAISE EXCEPTION 'CCP 코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF p_rows_json IS NULL OR jsonb_typeof(p_rows_json) <> 'array' THEN
        RAISE EXCEPTION '점검 행 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;

    SELECT COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           COALESCE(ct.appr_line_cd, 'DEFAULT'),
           COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_tmpl_nm, v_appr, v_retain_m
      FROM tbl_template t
      LEFT JOIN tbl_company_template ct
        ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd AND ct.use_yn = 'Y'
     WHERE t.tmpl_cd = 'html_sys_001' AND t.use_yn = 'Y';

    IF v_tmpl_nm IS NULL THEN
        RAISE EXCEPTION 'CCP 냉장보관 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000';
    END IF;

    v_title := v_tmpl_nm || ' (' ||
               substr(p_base_dt, 1, 4) || '-' || substr(p_base_dt, 5, 2) || '-' || substr(p_base_dt, 7, 2) || ')';

    -- 신규일 때(= doc_idx 없음) 문서·헤더를 만들고, 기존이면 잠금 상태를 검사한 뒤 갱신한다
    IF p_doc_idx IS NULL OR p_doc_idx = 0 THEN
        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd, 'html_sys_001', p_base_dt);

        INSERT INTO tbl_document(
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status,
            appr_line_cd, writer_id, write_dt, ver_no,
            retention_until, del_yn, ins_id, ins_dt
        )
        VALUES (
            p_co_cd, 'html_sys_001', 'DB', v_doc_no, p_base_dt, v_title, 'WRK',
            v_appr, p_id, now(), 1,
            to_char(
                (to_date(p_base_dt, 'YYYYMMDD') + (COALESCE(v_retain_m, 24) || ' months')::interval)::date,
                'YYYYMMDD'
            ),
            'N', p_id, now()
        )
        RETURNING idx INTO v_doc_idx;

        INSERT INTO tbl_ccp_cold_monitor(
            co_cd, doc_idx, base_dt, ccp_cd, mng_user_id, mng_nm, ins_id, ins_dt
        )
        VALUES (
            p_co_cd, v_doc_idx, p_base_dt, p_ccp_cd,
            NULLIF(p_mng_user_id, ''), NULLIF(p_mng_nm, ''),
            p_id, now()
        )
        RETURNING idx INTO v_hdr_idx;
    ELSE
        SELECT d.idx, d.status, h.idx
          INTO v_doc_idx, v_status, v_hdr_idx
          FROM tbl_document d
          JOIN tbl_ccp_cold_monitor h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
         WHERE d.co_cd = p_co_cd
           AND d.idx = p_doc_idx
           AND d.tmpl_cd = 'html_sys_001'
           AND d.del_yn = 'N';

        IF v_doc_idx IS NULL THEN
            RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        -- 결재 진행·완료일 때(= 기록 잠금) 수정 차단
        IF v_status IN ('REQ', 'REV', 'APV') THEN
            RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 수정할 수 없습니다.' USING ERRCODE = '45000';
        END IF;

        UPDATE tbl_document
           SET base_dt = p_base_dt,
               title   = v_title,
               upd_id  = p_id,
               upd_dt  = now()
         WHERE idx = v_doc_idx AND co_cd = p_co_cd;

        UPDATE tbl_ccp_cold_monitor
           SET base_dt     = p_base_dt,
               ccp_cd      = p_ccp_cd,
               mng_user_id = NULLIF(p_mng_user_id, ''),
               mng_nm      = NULLIF(p_mng_nm, ''),
               upd_id      = p_id,
               upd_dt      = now()
         WHERE idx = v_hdr_idx AND co_cd = p_co_cd;

        -- 기존 점검행·온도를 지우고 JSON으로 다시 넣는다(전체 교체)
        DELETE FROM tbl_ccp_cold_monitor_temp t
         USING tbl_ccp_cold_monitor_row r
         WHERE t.row_idx = r.idx AND t.co_cd = r.co_cd
           AND r.hdr_idx = v_hdr_idx AND r.co_cd = p_co_cd;

        DELETE FROM tbl_ccp_cold_monitor_row
         WHERE hdr_idx = v_hdr_idx AND co_cd = p_co_cd;
    END IF;

    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows_json)
    LOOP
        v_row_seq   := COALESCE((v_row->>'rowSeq')::int, 0);
        v_check_tm  := COALESCE(v_row->>'checkTime', '');
        v_mod_yn    := COALESCE(NULLIF(v_row->>'judgeModYn', ''), 'N');
        v_chk_id    := NULLIF(v_row->>'checkerId', '');
        v_chk_nm    := NULLIF(v_row->>'checkerNm', '');
        v_man_judge := NULLIF(v_row->>'judgeCd', '');

        IF v_row_seq <= 0 THEN
            RAISE EXCEPTION '점검 행 순번이 올바르지 않습니다.' USING ERRCODE = '45000';
        END IF;
        IF v_check_tm = '' THEN
            RAISE EXCEPTION '%번째 행의 점검시간이 없습니다.', v_row_seq USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_ccp_cold_monitor_row(
            co_cd, hdr_idx, row_seq, check_time, judge_cd, judge_mod_yn,
            checker_id, checker_nm, ins_id, ins_dt
        )
        VALUES (
            p_co_cd, v_hdr_idx, v_row_seq, v_check_tm, NULL, v_mod_yn,
            v_chk_id, v_chk_nm, p_id, now()
        )
        RETURNING idx INTO v_row_idx;

        v_row_judge := NULL;

        FOR v_temp IN SELECT * FROM jsonb_array_elements(COALESCE(v_row->'temps', '[]'::jsonb))
        LOOP
            v_st_cd    := COALESCE(v_temp->>'storageCd', '');
            v_temp_val := NULLIF(v_temp->>'tempVal', '')::numeric;

            IF v_st_cd = '' THEN
                RAISE EXCEPTION '%번째 행의 보관고 코드가 없습니다.', v_row_seq USING ERRCODE = '45000';
            END IF;

            -- 보관고 개별범위가 있으면 그걸 쓰고, 없으면 연결 CCP 한계기준을 쓴다
            SELECT s.temp_min, s.temp_max, s.ccp_cd
              INTO v_min, v_max, v_st_ccp
              FROM tbl_storage s
             WHERE s.co_cd = p_co_cd AND s.storage_cd = v_st_cd AND s.use_yn = 'Y';

            IF NOT FOUND THEN
                RAISE EXCEPTION '사용 중인 보관고가 아닙니다: %', v_st_cd USING ERRCODE = '45000';
            END IF;

            IF v_min IS NULL OR v_max IS NULL THEN
                SELECT l.min_val, l.max_val
                  INTO v_min, v_max
                  FROM tbl_ccp_limit l
                 WHERE l.co_cd = p_co_cd
                   AND l.ccp_cd = COALESCE(v_st_ccp, p_ccp_cd)
                   AND l.use_yn = 'Y';
            END IF;

            -- 온도가 비었을 때(= 미입력) 셀 판정 없음. 범위 밖이면 부적합
            IF v_temp_val IS NULL THEN
                v_cell_j := NULL;
            ELSIF v_min IS NOT NULL AND v_temp_val < v_min THEN
                v_cell_j := 'F';
            ELSIF v_max IS NOT NULL AND v_temp_val > v_max THEN
                v_cell_j := 'F';
            ELSE
                v_cell_j := 'P';
            END IF;

            INSERT INTO tbl_ccp_cold_monitor_temp(
                co_cd, row_idx, storage_cd, temp_val, judge_cd, ins_id, ins_dt
            )
            VALUES (p_co_cd, v_row_idx, v_st_cd, v_temp_val, v_cell_j, p_id, now());

            -- 행 판정: 하나라도 부적합이면 F, 그 외 적합 셀이 있으면 P
            IF v_cell_j = 'F' THEN
                v_row_judge := 'F';
            ELSIF v_cell_j = 'P' AND COALESCE(v_row_judge, '') <> 'F' THEN
                v_row_judge := 'P';
            END IF;
        END LOOP;

        -- 수동변경일 때(= 사용자가 판정을 바꿈) JSON의 judgeCd를 우선한다
        IF v_mod_yn = 'Y' AND v_man_judge IS NOT NULL THEN
            v_row_judge := v_man_judge;
        END IF;

        UPDATE tbl_ccp_cold_monitor_row
           SET judge_cd = v_row_judge
         WHERE idx = v_row_idx AND co_cd = p_co_cd;
    END LOOP;

    RETURN v_doc_idx;
END$$;

-- CCP 금속검출 삭제 — 임시·반려 문서와 두 표 영역을 함께 제거한다
CREATE OR REPLACE PROCEDURE sp_tbl_ccp_metal_monitor_d_000(p_co_cd varchar, p_doc_idx bigint, p_id varchar)
LANGUAGE plpgsql AS $$
DECLARE v_hdr_idx bigint; v_status varchar(4);
BEGIN
    SELECT h.idx,d.status INTO v_hdr_idx,v_status FROM tbl_document d JOIN tbl_ccp_metal_monitor h ON h.doc_idx=d.idx AND h.co_cd=d.co_cd WHERE d.co_cd=p_co_cd AND d.idx=p_doc_idx AND d.tmpl_cd='html_sys_002' AND d.del_yn='N';
    IF v_hdr_idx IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
    IF v_status NOT IN ('WRK','RJT') THEN RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 삭제할 수 없습니다.' USING ERRCODE='45000'; END IF;
    DELETE FROM tbl_corrective_action WHERE co_cd=p_co_cd AND src_doc_idx=p_doc_idx;
    DELETE FROM tbl_ccp_metal_sens_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
    DELETE FROM tbl_ccp_metal_pass_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
    DELETE FROM tbl_ccp_metal_monitor WHERE co_cd=p_co_cd AND idx=v_hdr_idx;
    DELETE FROM tbl_document_approval WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx;
    DELETE FROM tbl_document_file WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx;
    DELETE FROM tbl_document WHERE co_cd=p_co_cd AND idx=p_doc_idx;
END$$;

-- CCP 검증점검표·연간 검증계획서 상세 — 헤더와 JSON 입력용 행 목록을 반환한다
CREATE OR REPLACE FUNCTION sp_tbl_ccp_form_detail_r_000(p_co_cd varchar, p_tmpl_cd varchar, p_doc_idx bigint)
RETURNS TABLE (doc_idx bigint, hdr_idx bigint, doc_no varchar, base_dt varchar, status varchar, checker_id varchar, checker_nm varchar, dept_cd varchar, confirm_id varchar, rows_json jsonb)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    IF p_tmpl_cd='html_sys_006' THEN
        RETURN QUERY SELECT d.idx,h.idx,d.doc_no,h.base_dt,d.status,h.checker_id,h.checker_nm,NULL::varchar,NULL::varchar,
          COALESCE((SELECT jsonb_agg(jsonb_build_object('rowSeq',i.row_seq,'procCd',i.proc_cd,'procNm',i.proc_nm,'itemCd',i.item_cd,'verifyDesc',i.verify_desc,'answerCd',i.answer_cd,'recordDesc',i.record_desc,'refTmplCd',i.ref_tmpl_cd,'refFromDt',i.ref_from_dt,'refToDt',i.ref_to_dt,'refTotalCnt',i.ref_total_cnt,'refOkCnt',i.ref_ok_cnt,'refNgCnt',i.ref_ng_cnt) ORDER BY i.row_seq) FROM tbl_ccp_verify_item i WHERE i.co_cd=p_co_cd AND i.hdr_idx=h.idx),'[]'::jsonb)
        FROM tbl_document d JOIN tbl_ccp_verify_check h ON h.doc_idx=d.idx AND h.co_cd=d.co_cd WHERE d.co_cd=p_co_cd AND d.idx=p_doc_idx AND d.tmpl_cd=p_tmpl_cd AND d.del_yn='N';
    ELSIF p_tmpl_cd='hwp_sys_003' THEN
        RETURN QUERY SELECT d.idx,h.idx,d.doc_no,h.plan_year||'0101',d.status,h.checker_id,NULL::varchar,h.dept_cd,h.confirm_id,
          COALESCE((SELECT jsonb_agg(jsonb_build_object('rowSeq',i.row_seq,'verifyTarget',i.verify_target,'verifyMethod',i.verify_method,'refTmplCd',i.ref_tmpl_cd,'months',(SELECT jsonb_agg(jsonb_build_object('monthNo',m.month_no,'planYn',m.plan_yn,'doneYn',m.done_yn,'doneDocIdx',m.done_doc_idx,'doneDt',m.done_dt) ORDER BY m.month_no) FROM tbl_verify_plan_month m WHERE m.co_cd=p_co_cd AND m.item_idx=i.idx)) ORDER BY i.row_seq) FROM tbl_verify_plan_item i WHERE i.co_cd=p_co_cd AND i.hdr_idx=h.idx),'[]'::jsonb)
        FROM tbl_document d JOIN tbl_verify_plan h ON h.doc_idx=d.idx AND h.co_cd=d.co_cd WHERE d.co_cd=p_co_cd AND d.idx=p_doc_idx AND d.tmpl_cd=p_tmpl_cd AND d.del_yn='N';
    END IF;
END$$;

-- CCP 검증점검표·연간 검증계획서 저장 — 화면별 행 JSON을 해당 정규화 테이블로 전개한다
CREATE OR REPLACE FUNCTION sp_tbl_ccp_form_c_000(p_co_cd varchar, p_tmpl_cd varchar, p_doc_idx bigint, p_base_dt varchar, p_checker_id varchar, p_checker_nm varchar, p_dept_cd varchar, p_confirm_id varchar, p_rows_json jsonb, p_id varchar)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_doc_idx bigint; v_hdr_idx bigint; v_item_idx bigint; v_status varchar(4); v_name varchar; v_appr varchar; v_retain int; r jsonb; m jsonb;
BEGIN
    IF p_tmpl_cd NOT IN ('html_sys_006','hwp_sys_003') THEN RAISE EXCEPTION '지원하지 않는 CCP 양식입니다.' USING ERRCODE='45000'; END IF;
    IF COALESCE(p_base_dt,'')='' OR (p_tmpl_cd='html_sys_006' AND length(p_base_dt)<>8) OR (p_tmpl_cd='hwp_sys_003' AND length(p_base_dt)<>4) THEN RAISE EXCEPTION '기준일 형식이 올바르지 않습니다.' USING ERRCODE='45000'; END IF;
    IF p_rows_json IS NULL OR jsonb_typeof(p_rows_json)<>'array' THEN RAISE EXCEPTION '점검 행 자료가 올바르지 않습니다.' USING ERRCODE='45000'; END IF;
    SELECT COALESCE(ct.tmpl_nm_ovr,t.tmpl_nm),COALESCE(ct.appr_line_cd,'DEFAULT'),COALESCE(ct.retention_month,t.default_retention_month) INTO v_name,v_appr,v_retain FROM tbl_template t LEFT JOIN tbl_company_template ct ON ct.co_cd=p_co_cd AND ct.tmpl_cd=t.tmpl_cd AND ct.use_yn='Y' WHERE t.tmpl_cd=p_tmpl_cd AND t.use_yn='Y';
    IF v_name IS NULL THEN RAISE EXCEPTION '양식이 등록되어 있지 않습니다.' USING ERRCODE='45000'; END IF;
    IF p_doc_idx IS NULL OR p_doc_idx=0 THEN
      INSERT INTO tbl_document(co_cd,tmpl_cd,doc_kind,doc_no,base_dt,title,status,appr_line_cd,writer_id,write_dt,ver_no,retention_until,del_yn,ins_id) VALUES(p_co_cd,p_tmpl_cd,'DB',sp_tbl_doc_no_gen_c_000(p_co_cd,p_tmpl_cd,p_base_dt||CASE WHEN p_tmpl_cd='hwp_sys_003' THEN '0101' ELSE '' END),p_base_dt||CASE WHEN p_tmpl_cd='hwp_sys_003' THEN '0101' ELSE '' END,v_name||' ('||p_base_dt||')','WRK',v_appr,p_id,now(),1,to_char((to_date(p_base_dt||CASE WHEN p_tmpl_cd='hwp_sys_003' THEN '0101' ELSE '' END,'YYYYMMDD')+(COALESCE(v_retain,24)||' months')::interval)::date,'YYYYMMDD'),'N',p_id) RETURNING idx INTO v_doc_idx;
      IF p_tmpl_cd='html_sys_006' THEN INSERT INTO tbl_ccp_verify_check(co_cd,doc_idx,base_dt,checker_id,checker_nm,ins_id) VALUES(p_co_cd,v_doc_idx,p_base_dt,NULLIF(p_checker_id,''),NULLIF(p_checker_nm,''),p_id) RETURNING idx INTO v_hdr_idx;
      ELSE INSERT INTO tbl_verify_plan(co_cd,doc_idx,plan_year,dept_cd,checker_id,confirm_id,ins_id) VALUES(p_co_cd,v_doc_idx,p_base_dt,NULLIF(p_dept_cd,''),NULLIF(p_checker_id,''),NULLIF(p_confirm_id,''),p_id) RETURNING idx INTO v_hdr_idx; END IF;
    ELSE
      SELECT d.idx,d.status,CASE WHEN p_tmpl_cd='html_sys_006' THEN v.idx ELSE p.idx END INTO v_doc_idx,v_status,v_hdr_idx FROM tbl_document d LEFT JOIN tbl_ccp_verify_check v ON v.doc_idx=d.idx AND v.co_cd=d.co_cd AND p_tmpl_cd='html_sys_006' LEFT JOIN tbl_verify_plan p ON p.doc_idx=d.idx AND p.co_cd=d.co_cd AND p_tmpl_cd='hwp_sys_003' WHERE d.co_cd=p_co_cd AND d.idx=p_doc_idx AND d.tmpl_cd=p_tmpl_cd AND d.del_yn='N';
      IF v_doc_idx IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
      IF v_status IN ('REQ','REV','APV') THEN RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 수정할 수 없습니다.' USING ERRCODE='45000'; END IF;
      UPDATE tbl_document SET base_dt=p_base_dt||CASE WHEN p_tmpl_cd='hwp_sys_003' THEN '0101' ELSE '' END,title=v_name||' ('||p_base_dt||')',upd_id=p_id,upd_dt=now() WHERE co_cd=p_co_cd AND idx=v_doc_idx;
      IF p_tmpl_cd='html_sys_006' THEN UPDATE tbl_ccp_verify_check SET base_dt=p_base_dt,checker_id=NULLIF(p_checker_id,''),checker_nm=NULLIF(p_checker_nm,''),upd_id=p_id,upd_dt=now() WHERE co_cd=p_co_cd AND idx=v_hdr_idx; DELETE FROM tbl_ccp_verify_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
      ELSE DELETE FROM tbl_verify_plan_month m USING tbl_verify_plan_item i WHERE m.co_cd=p_co_cd AND i.co_cd=p_co_cd AND m.item_idx=i.idx AND i.hdr_idx=v_hdr_idx; UPDATE tbl_verify_plan SET plan_year=p_base_dt,dept_cd=NULLIF(p_dept_cd,''),checker_id=NULLIF(p_checker_id,''),confirm_id=NULLIF(p_confirm_id,''),upd_id=p_id,upd_dt=now() WHERE co_cd=p_co_cd AND idx=v_hdr_idx; DELETE FROM tbl_verify_plan_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx; END IF;
    END IF;
    FOR r IN SELECT * FROM jsonb_array_elements(p_rows_json) LOOP
      IF COALESCE((r->>'rowSeq')::int,0)<=0 THEN RAISE EXCEPTION '행 순번이 올바르지 않습니다.' USING ERRCODE='45000'; END IF;
      IF p_tmpl_cd='html_sys_006' THEN INSERT INTO tbl_ccp_verify_item(co_cd,hdr_idx,row_seq,proc_cd,proc_nm,item_cd,verify_desc,answer_cd,record_desc,ref_tmpl_cd,ref_from_dt,ref_to_dt,ref_total_cnt,ref_ok_cnt,ref_ng_cnt,ins_id) VALUES(p_co_cd,v_hdr_idx,(r->>'rowSeq')::int,NULLIF(r->>'procCd',''),NULLIF(r->>'procNm',''),NULLIF(r->>'itemCd',''),COALESCE(NULLIF(r->>'verifyDesc',''),'검증 내용'),NULLIF(r->>'answerCd',''),NULLIF(r->>'recordDesc',''),NULLIF(r->>'refTmplCd',''),NULLIF(r->>'refFromDt',''),NULLIF(r->>'refToDt',''),NULLIF(r->>'refTotalCnt','')::int,NULLIF(r->>'refOkCnt','')::int,NULLIF(r->>'refNgCnt','')::int,p_id);
      ELSE INSERT INTO tbl_verify_plan_item(co_cd,hdr_idx,row_seq,verify_target,verify_method,ref_tmpl_cd,ins_id) VALUES(p_co_cd,v_hdr_idx,(r->>'rowSeq')::int,COALESCE(NULLIF(r->>'verifyTarget',''),'검증대상'),NULLIF(r->>'verifyMethod',''),NULLIF(r->>'refTmplCd',''),p_id) RETURNING idx INTO v_item_idx; FOR m IN SELECT * FROM jsonb_array_elements(COALESCE(r->'months','[]'::jsonb)) LOOP INSERT INTO tbl_verify_plan_month(co_cd,item_idx,month_no,plan_yn,done_yn,done_doc_idx,done_dt,ins_id) VALUES(p_co_cd,v_item_idx,(m->>'monthNo')::int,COALESCE(NULLIF(m->>'planYn',''),'N'),COALESCE(NULLIF(m->>'doneYn',''),'N'),NULLIF(m->>'doneDocIdx','')::bigint,NULLIF(m->>'doneDt',''),p_id); END LOOP; END IF;
    END LOOP;
    RETURN v_doc_idx;
END$$;

-- CCP 검증점검표·연간 검증계획서 삭제 — 참조 행과 문서 허브 하위를 같은 트랜잭션에서 제거한다
CREATE OR REPLACE PROCEDURE sp_tbl_ccp_form_d_000(p_co_cd varchar, p_tmpl_cd varchar, p_doc_idx bigint, p_id varchar)
LANGUAGE plpgsql AS $$
DECLARE v_hdr_idx bigint; v_status varchar(4);
BEGIN
    SELECT d.status, CASE WHEN p_tmpl_cd='html_sys_006' THEN v.idx ELSE p.idx END INTO v_status,v_hdr_idx
      FROM tbl_document d
      LEFT JOIN tbl_ccp_verify_check v ON v.doc_idx=d.idx AND v.co_cd=d.co_cd AND p_tmpl_cd='html_sys_006'
      LEFT JOIN tbl_verify_plan p ON p.doc_idx=d.idx AND p.co_cd=d.co_cd AND p_tmpl_cd='hwp_sys_003'
     WHERE d.co_cd=p_co_cd AND d.idx=p_doc_idx AND d.tmpl_cd=p_tmpl_cd AND d.del_yn='N';
    IF v_hdr_idx IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
    IF v_status NOT IN ('WRK','RJT') THEN RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 삭제할 수 없습니다.' USING ERRCODE='45000'; END IF;
    DELETE FROM tbl_corrective_action WHERE co_cd=p_co_cd AND src_doc_idx=p_doc_idx;
    IF p_tmpl_cd='html_sys_006' THEN
      DELETE FROM tbl_ccp_verify_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
      DELETE FROM tbl_ccp_verify_check WHERE co_cd=p_co_cd AND idx=v_hdr_idx;
    ELSE
      DELETE FROM tbl_verify_plan_month m USING tbl_verify_plan_item i WHERE m.co_cd=p_co_cd AND i.co_cd=p_co_cd AND m.item_idx=i.idx AND i.hdr_idx=v_hdr_idx;
      DELETE FROM tbl_verify_plan_item WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
      DELETE FROM tbl_verify_plan WHERE co_cd=p_co_cd AND idx=v_hdr_idx;
    END IF;
    DELETE FROM tbl_document_approval WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx;
    DELETE FROM tbl_document_file WHERE co_cd=p_co_cd AND doc_idx=p_doc_idx;
    DELETE FROM tbl_document WHERE co_cd=p_co_cd AND idx=p_doc_idx;
END$$;
COMMENT ON FUNCTION sp_tbl_ccp_cold_monitor_c_000(varchar, bigint, varchar, varchar, varchar, varchar, jsonb, varchar) IS 'CCP 냉장보관 일지 저장 — 문서·헤더·점검행·온도·자동판정';

-- ------------------------------------------------------------
-- 8. sp_tbl_ccp_cold_monitor_d_000 — 삭제 (임시·반려만)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_ccp_cold_monitor_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_doc_idx: 삭제할 문서 idx
    p_doc_idx bigint,
    -- p_id: 작업자 로그인 ID
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_status  varchar(4);
    v_hdr_idx bigint;
BEGIN
    IF p_doc_idx IS NULL OR p_doc_idx = 0 THEN
        RAISE EXCEPTION '삭제할 문서를 선택하세요.' USING ERRCODE = '45000';
    END IF;

    SELECT d.status, h.idx
      INTO v_status, v_hdr_idx
      FROM tbl_document d
      JOIN tbl_ccp_cold_monitor h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd
       AND d.idx = p_doc_idx
       AND d.tmpl_cd = 'html_sys_001'
       AND d.del_yn = 'N';

    IF v_hdr_idx IS NULL THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 임시·반려가 아닐 때(= 결재 흐름에 들어간 문서) 삭제 차단
    IF v_status NOT IN ('WRK', 'RJT') THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_corrective_action
     WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx;

    DELETE FROM tbl_ccp_cold_monitor_temp t
     USING tbl_ccp_cold_monitor_row r
     WHERE t.row_idx = r.idx AND t.co_cd = r.co_cd
       AND r.hdr_idx = v_hdr_idx AND r.co_cd = p_co_cd;

    DELETE FROM tbl_ccp_cold_monitor_row
     WHERE hdr_idx = v_hdr_idx AND co_cd = p_co_cd;

    DELETE FROM tbl_ccp_cold_monitor
     WHERE idx = v_hdr_idx AND co_cd = p_co_cd;

    DELETE FROM tbl_document_approval
     WHERE doc_idx = p_doc_idx AND co_cd = p_co_cd;

    DELETE FROM tbl_document_file
     WHERE doc_idx = p_doc_idx AND co_cd = p_co_cd;

    DELETE FROM tbl_document
     WHERE idx = p_doc_idx AND co_cd = p_co_cd;
END$$;
COMMENT ON PROCEDURE sp_tbl_ccp_cold_monitor_d_000(varchar, bigint, varchar) IS 'CCP 냉장보관 일지 삭제 — 임시·반려만, 하위·문서 일괄 제거';

-- ------------------------------------------------------------
-- 9. CCP 금속검출·검증점검표·연간 검증계획서 공통 목록 (문서번호·작성자 검색)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_ccp_form_list_r_000(varchar, varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_tbl_ccp_form_list_r_000(
    p_co_cd varchar,
    p_tmpl_cd varchar,
    p_from_dt varchar,
    p_to_dt varchar,
    p_doc_no varchar DEFAULT '',
    p_writer varchar DEFAULT ''
)
RETURNS TABLE (
    doc_idx bigint, hdr_idx bigint, doc_no varchar, base_dt varchar, title varchar,
    status varchar, row_cnt int, ng_cnt int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx,
           CASE p_tmpl_cd
             WHEN 'html_sys_002' THEN m.idx
             WHEN 'html_sys_006' THEN v.idx
             ELSE p.idx
           END,
           d.doc_no,
           CASE p_tmpl_cd
             WHEN 'html_sys_002' THEN m.base_dt
             WHEN 'html_sys_006' THEN v.base_dt
             ELSE p.plan_year || '0101'
           END,
           d.title, d.status,
           CASE p_tmpl_cd
             WHEN 'html_sys_002' THEN (SELECT count(*)::int FROM tbl_ccp_metal_sens_row r WHERE r.co_cd = p_co_cd AND r.hdr_idx = m.idx)
             WHEN 'html_sys_006' THEN (SELECT count(*)::int FROM tbl_ccp_verify_item i WHERE i.co_cd = p_co_cd AND i.hdr_idx = v.idx)
             ELSE (SELECT count(*)::int FROM tbl_verify_plan_item i WHERE i.co_cd = p_co_cd AND i.hdr_idx = p.idx)
           END,
           CASE p_tmpl_cd
             WHEN 'html_sys_002' THEN (SELECT count(*)::int FROM tbl_ccp_metal_sens_row r WHERE r.co_cd = p_co_cd AND r.hdr_idx = m.idx AND r.judge_cd = 'F')
             WHEN 'html_sys_006' THEN (SELECT count(*)::int FROM tbl_ccp_verify_item i WHERE i.co_cd = p_co_cd AND i.hdr_idx = v.idx AND i.answer_cd = 'N')
             ELSE 0
           END
      FROM tbl_document d
      LEFT JOIN tbl_ccp_metal_monitor m ON m.doc_idx = d.idx AND m.co_cd = d.co_cd AND p_tmpl_cd = 'html_sys_002'
      LEFT JOIN tbl_ccp_verify_check v ON v.doc_idx = d.idx AND v.co_cd = d.co_cd AND p_tmpl_cd = 'html_sys_006'
      LEFT JOIN tbl_verify_plan p ON p.doc_idx = d.idx AND p.co_cd = d.co_cd AND p_tmpl_cd = 'hwp_sys_003'
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.tmpl_cd = p_tmpl_cd
       AND d.del_yn = 'N'
       AND (COALESCE(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
       AND (COALESCE(p_doc_no, '') = '' OR d.doc_no ILIKE '%' || p_doc_no || '%')
       AND (
           COALESCE(p_writer, '') = ''
           OR d.writer_id ILIKE '%' || p_writer || '%'
           OR COALESCE(u.user_nm, '') ILIKE '%' || p_writer || '%'
       )
     ORDER BY d.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_tbl_ccp_form_list_r_000(varchar, varchar, varchar, varchar, varchar, varchar) IS
  'CCP DB형 양식 공통 목록 — 기간·문서번호·작성자';


CREATE OR REPLACE FUNCTION sp_tbl_ccp_metal_monitor_r_001(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 문서 idx
    p_doc_idx bigint
)
RETURNS TABLE (
    doc_idx bigint, hdr_idx bigint, doc_no varchar, base_dt varchar, ccp_cd varchar,
    fe_size numeric, sts_size numeric, mng_user_id varchar, mng_nm varchar, status varchar
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, h.idx, d.doc_no, h.base_dt, h.ccp_cd, h.fe_size, h.sts_size,
           h.mng_user_id, h.mng_nm, d.status
      FROM tbl_document d JOIN tbl_ccp_metal_monitor h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = 'html_sys_002' AND d.del_yn = 'N';
$$;

-- 39 에서 place_nm 컬럼이 추가되어 OUT 시그니처가 달라진다 — 재실행 안전 DROP
DROP FUNCTION IF EXISTS sp_tbl_ccp_metal_monitor_r_002(varchar, bigint);
CREATE OR REPLACE FUNCTION sp_tbl_ccp_metal_monitor_r_002(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_hdr_idx: 금속검출 헤더 idx
    p_hdr_idx bigint
)
RETURNS TABLE (
    idx bigint, row_seq int, phase_cd varchar, product_cd varchar, product_nm varchar,
    check_time varchar, fe_only_cd varchar, sts_only_cd varchar, prod_only_cd varchar,
    fe_prod_cd varchar, sts_prod_cd varchar, judge_cd varchar, checker_id varchar, checker_nm varchar
)
LANGUAGE sql STABLE AS $$
    SELECT idx, row_seq, phase_cd, product_cd, product_nm, check_time, fe_only_cd, sts_only_cd,
           prod_only_cd, fe_prod_cd, sts_prod_cd, judge_cd, checker_id, checker_nm
      FROM tbl_ccp_metal_sens_row
     WHERE co_cd = p_co_cd AND hdr_idx = p_hdr_idx ORDER BY row_seq;
$$;

CREATE OR REPLACE FUNCTION sp_tbl_ccp_metal_monitor_r_003(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_hdr_idx: 금속검출 헤더 idx
    p_hdr_idx bigint
)
RETURNS TABLE (idx bigint, row_seq int, product_cd varchar, product_nm varchar, pass_qty numeric, detect_qty numeric, unit_nm varchar, remark varchar)
LANGUAGE sql STABLE AS $$
    SELECT idx, row_seq, product_cd, product_nm, pass_qty, detect_qty, unit_nm, remark
      FROM tbl_ccp_metal_pass_row
     WHERE co_cd = p_co_cd AND hdr_idx = p_hdr_idx ORDER BY row_seq;
$$;

CREATE OR REPLACE FUNCTION sp_tbl_ccp_metal_monitor_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar, p_doc_idx bigint, p_base_dt varchar, p_ccp_cd varchar,
    p_fe_size numeric, p_sts_size numeric, p_mng_user_id varchar, p_mng_nm varchar,
    -- p_sens_rows_json: 감도 모니터링 행 배열
    p_sens_rows_json jsonb,
    -- p_pass_rows_json: 제품 통과 실적 행 배열
    p_pass_rows_json jsonb,
    -- p_id: 저장 작업자
    p_id varchar
)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_doc_idx bigint; v_hdr_idx bigint; v_status varchar(4); v_name varchar; v_appr varchar; v_retain int; r jsonb; v_judge varchar(1);
BEGIN
    IF COALESCE(p_base_dt, '') = '' OR length(p_base_dt) <> 8 THEN RAISE EXCEPTION '작성일은 YYYYMMDD 8자리로 입력하세요.' USING ERRCODE = '45000'; END IF;
    IF p_sens_rows_json IS NULL OR jsonb_typeof(p_sens_rows_json) <> 'array' THEN RAISE EXCEPTION '감도 점검 행 자료가 올바르지 않습니다.' USING ERRCODE = '45000'; END IF;
    SELECT COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm), COALESCE(ct.appr_line_cd, 'DEFAULT'), COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_name, v_appr, v_retain FROM tbl_template t LEFT JOIN tbl_company_template ct ON ct.co_cd=p_co_cd AND ct.tmpl_cd=t.tmpl_cd AND ct.use_yn='Y'
     WHERE t.tmpl_cd='html_sys_002' AND t.use_yn='Y';
    IF v_name IS NULL THEN RAISE EXCEPTION 'CCP 금속검출 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000'; END IF;
    IF p_doc_idx IS NULL OR p_doc_idx = 0 THEN
        INSERT INTO tbl_document(co_cd,tmpl_cd,doc_kind,doc_no,base_dt,title,status,appr_line_cd,writer_id,write_dt,ver_no,retention_until,del_yn,ins_id)
        VALUES(p_co_cd,'html_sys_002','DB',sp_tbl_doc_no_gen_c_000(p_co_cd,'html_sys_002',p_base_dt),p_base_dt,v_name || ' (' || p_base_dt || ')','WRK',v_appr,p_id,now(),1,to_char((to_date(p_base_dt,'YYYYMMDD')+(COALESCE(v_retain,24)||' months')::interval)::date,'YYYYMMDD'),'N',p_id) RETURNING idx INTO v_doc_idx;
        INSERT INTO tbl_ccp_metal_monitor(co_cd,doc_idx,base_dt,ccp_cd,fe_size,sts_size,mng_user_id,mng_nm,ins_id) VALUES(p_co_cd,v_doc_idx,p_base_dt,p_ccp_cd,p_fe_size,p_sts_size,NULLIF(p_mng_user_id,''),NULLIF(p_mng_nm,''),p_id) RETURNING idx INTO v_hdr_idx;
    ELSE
        SELECT d.idx,d.status,h.idx INTO v_doc_idx,v_status,v_hdr_idx FROM tbl_document d JOIN tbl_ccp_metal_monitor h ON h.doc_idx=d.idx AND h.co_cd=d.co_cd WHERE d.co_cd=p_co_cd AND d.idx=p_doc_idx AND d.tmpl_cd='html_sys_002' AND d.del_yn='N';
        IF v_doc_idx IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
        IF v_status IN ('REQ','REV','APV') THEN RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 수정할 수 없습니다.' USING ERRCODE='45000'; END IF;
        UPDATE tbl_document SET base_dt=p_base_dt,title=v_name || ' (' || p_base_dt || ')',upd_id=p_id,upd_dt=now() WHERE idx=v_doc_idx AND co_cd=p_co_cd;
        UPDATE tbl_ccp_metal_monitor SET base_dt=p_base_dt,ccp_cd=p_ccp_cd,fe_size=p_fe_size,sts_size=p_sts_size,mng_user_id=NULLIF(p_mng_user_id,''),mng_nm=NULLIF(p_mng_nm,''),upd_id=p_id,upd_dt=now() WHERE idx=v_hdr_idx AND co_cd=p_co_cd;
        DELETE FROM tbl_ccp_metal_sens_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
        DELETE FROM tbl_ccp_metal_pass_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
    END IF;
    FOR r IN SELECT * FROM jsonb_array_elements(p_sens_rows_json) LOOP
        IF COALESCE((r->>'rowSeq')::int,0) <= 0 THEN RAISE EXCEPTION '감도 점검 행 순번이 올바르지 않습니다.' USING ERRCODE='45000'; END IF;
        -- 시편 4종 모두 O, 제품만 X일 때(= 장비가 정상 검출) 적합
        v_judge := CASE WHEN r->>'feOnlyCd'='O' AND r->>'stsOnlyCd'='O' AND r->>'prodOnlyCd'='X' AND r->>'feProdCd'='O' AND r->>'stsProdCd'='O' THEN 'P' ELSE 'F' END;
        INSERT INTO tbl_ccp_metal_sens_row(co_cd,hdr_idx,row_seq,phase_cd,product_cd,product_nm,check_time,fe_only_cd,sts_only_cd,prod_only_cd,fe_prod_cd,sts_prod_cd,judge_cd,judge_mod_yn,checker_id,checker_nm,ins_id)
        VALUES(p_co_cd,v_hdr_idx,(r->>'rowSeq')::int,COALESCE(NULLIF(r->>'phaseCd',''),'DURING'),NULLIF(r->>'productCd',''),NULLIF(r->>'productNm',''),NULLIF(r->>'checkTime',''),NULLIF(r->>'feOnlyCd',''),NULLIF(r->>'stsOnlyCd',''),NULLIF(r->>'prodOnlyCd',''),NULLIF(r->>'feProdCd',''),NULLIF(r->>'stsProdCd',''),CASE WHEN r->>'judgeModYn'='Y' AND NULLIF(r->>'judgeCd','') IS NOT NULL THEN r->>'judgeCd' ELSE v_judge END,COALESCE(NULLIF(r->>'judgeModYn',''),'N'),NULLIF(r->>'checkerId',''),NULLIF(r->>'checkerNm',''),p_id);
    END LOOP;
    FOR r IN SELECT * FROM jsonb_array_elements(COALESCE(p_pass_rows_json,'[]'::jsonb)) LOOP
        INSERT INTO tbl_ccp_metal_pass_row(co_cd,hdr_idx,row_seq,product_cd,product_nm,pass_qty,detect_qty,unit_nm,remark,ins_id)
        VALUES(p_co_cd,v_hdr_idx,COALESCE((r->>'rowSeq')::int,0),NULLIF(r->>'productCd',''),NULLIF(r->>'productNm',''),NULLIF(r->>'passQty','')::numeric,NULLIF(r->>'detectQty','')::numeric,NULLIF(r->>'unitNm',''),NULLIF(r->>'remark',''),p_id);
    END LOOP;
    RETURN v_doc_idx;
END$$;
