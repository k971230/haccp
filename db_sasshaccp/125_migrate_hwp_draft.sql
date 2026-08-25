-- ============================================================
--  125_migrate_hwp_draft.sql — HWP 양식 작성 화면
--
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) /draft/hwp-doc/hwp-write 한 화면이 쓰는 조회 SP 2개와 화면·권한·메뉴를 만든다
--    2) 테이블·컬럼 변경이 없다 — 문서는 기존 tbl_document(doc_kind='hwp')를 그대로 쓴다
--    3) 기존 SP 는 손대지 않는다. 오늘 할일(sp_tbl_today_task_r_000)도 그대로 둔다
--
--  중분류 slug 는 hwp-doc — tbl_menu UNIQUE(co_cd, menu_cd) 에서 hwp 는 docs 아래가 이미 쓴다
--  실행: psql -f 125_migrate_hwp_draft.sql (수동·DBeaver. Jenkins 는 마이그레이션을 돌리지 않는다)
-- ============================================================

-- ------------------------------------------------------------
-- 1. 좌측 작성 목록 — 검색 6조건 중 서버 조건 5개
--    결재 여부는 화면이 status 로 거른다 (다른 draft 화면과 같은 계약)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_draft_hwp_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_draft_hwp_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 양식코드 부분검색. 공백이면 전체
    p_tmpl_cd varchar,
    -- p_tmpl_nm: 양식명 부분검색. 공백이면 전체
    p_tmpl_nm varchar,
    -- p_from_dt: 일자 시작 YYYYMMDD. 공백이면 전체
    p_from_dt varchar,
    -- p_to_dt: 일자 종료 YYYYMMDD. 공백이면 전체
    p_to_dt varchar,
    -- p_writer_id: 작성자 ID 부분검색. 공백이면 전체
    p_writer_id varchar,
    -- p_writer_nm: 작성자명 부분검색. 공백이면 전체
    p_writer_nm varchar
)
RETURNS TABLE (
    doc_idx bigint,
    hdr_idx bigint,
    tmpl_cd varchar,
    tmpl_nm varchar,
    doc_no varchar,
    base_dt varchar,
    checker_nm varchar,
    writer_id varchar,
    writer_nm varchar,
    status varchar,
    row_cnt int,
    ng_cnt int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx,
           -- HWP 는 하위 헤더 테이블이 없다 — 문서 idx 를 그대로 쓴다
           d.idx,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd)::varchar,
           d.doc_no,
           d.base_dt,
           COALESCE(u.user_nm, d.writer_id)::varchar,
           d.writer_id,
           COALESCE(u.user_nm, d.writer_id)::varchar,
           d.status,
           -- 본문 파일 수 — 목록에서 HWP 본문이 붙었는지 눈으로 본다
           (SELECT count(*)::int FROM tbl_document_file f
             WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx AND f.file_kind = 'HWP_SRC'),
           -- 미완료 개선조치 수 — 다른 draft 화면의 ng_cnt 자리와 같은 뜻
           (SELECT count(*)::int FROM tbl_corrective_action ca
             WHERE ca.co_cd = d.co_cd AND ca.src_doc_idx = d.idx AND ca.status <> 'DONE')
      FROM tbl_document d
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.del_yn = 'N'
       -- HWP 문서형만. HTML 전용 화면 문서는 이 화면 대상이 아니다
       AND d.doc_kind = 'hwp'
       AND (COALESCE(NULLIF(btrim(p_tmpl_cd), ''), '') = '' OR d.tmpl_cd ILIKE '%' || btrim(p_tmpl_cd) || '%')
       AND (COALESCE(NULLIF(btrim(p_tmpl_nm), ''), '') = ''
            OR COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, '') ILIKE '%' || btrim(p_tmpl_nm) || '%')
       AND (COALESCE(NULLIF(btrim(p_from_dt), ''), '') = '' OR d.base_dt >= btrim(p_from_dt))
       AND (COALESCE(NULLIF(btrim(p_to_dt), ''), '') = '' OR d.base_dt <= btrim(p_to_dt))
       AND (COALESCE(NULLIF(btrim(p_writer_id), ''), '') = '' OR COALESCE(d.writer_id, '') ILIKE '%' || btrim(p_writer_id) || '%')
       AND (COALESCE(NULLIF(btrim(p_writer_nm), ''), '') = '' OR COALESCE(u.user_nm, '') ILIKE '%' || btrim(p_writer_nm) || '%')
     ORDER BY d.base_dt DESC, d.idx DESC;
$$;
COMMENT ON FUNCTION sp_draft_hwp_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar) IS
  'HWP 작성 목록 — doc_kind=hwp 문서만. 검색 6조건 중 서버 조건 5개';

-- ------------------------------------------------------------
-- 2. 오늘 할일 중 HWP 문서주기 — 행 추가 팝업이 쓴다
--    기존 sp_tbl_today_task_r_000 은 tmpl_cd 를 안 주고 개선조치(CA)까지 섞어 준다.
--    작성 화면은 양식코드로 rhwp 에 양식을 열어야 해 별도 SP 로 둔다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_draft_hwp_task_r_000(varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_draft_hwp_task_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_user_id: JWT 사용자 ID — 담당자 미지정 할일도 함께 본다
    p_user_id varchar,
    -- p_base_dt: 기준일 YYYYMMDD
    p_base_dt varchar
)
RETURNS TABLE (
    task_idx bigint,
    tmpl_cd varchar,
    tmpl_nm varchar,
    base_dt varchar,
    due_dt varchar,
    due_time varchar,
    status varchar,
    doc_idx bigint
)
LANGUAGE sql STABLE AS $$
    SELECT t.idx,
           t.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, tp.tmpl_nm, t.tmpl_cd)::varchar,
           t.base_dt,
           t.due_dt,
           t.due_time,
           t.status,
           t.doc_idx
      FROM tbl_schedule_task t
      JOIN tbl_template tp ON tp.tmpl_cd = t.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = t.co_cd AND ct.tmpl_cd = t.tmpl_cd
     WHERE t.co_cd = p_co_cd
       AND t.base_dt = p_base_dt
       -- 아직 끝나지 않은 할일만 — 오늘 할일 화면과 같은 상태 집합
       AND t.status IN ('TODO', 'ING', 'LATE')
       -- HWP 문서형 주기만. HTML 전용 화면 주기는 이 팝업 대상이 아니다
       AND tp.doc_kind = 'hwp'
       -- 담당자 미지정이거나(= 누구나 처리) 내 할일일 때만
       AND (t.user_id IS NULL OR t.user_id = p_user_id)
     ORDER BY t.due_time NULLS LAST, t.idx;
$$;
COMMENT ON FUNCTION sp_draft_hwp_task_r_000(varchar, varchar, varchar) IS
  'HWP 작성 행추가 팝업 — 오늘 할일 중 doc_kind=hwp 문서주기만';

-- ------------------------------------------------------------
-- 3. 화면 · 권한 · 메뉴 — 대 draft(양식 작성) / 중 hwp-doc(HWP 문서)
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, ins_id) VALUES
    ('hwp-write', 'HWP 양식 작성', 'DOC', NULL, 4401, 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm, module_cd = EXCLUDED.module_cd, tmpl_cd = EXCLUDED.tmpl_cd,
    sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- 삭제는 ADMIN 만 Y — 100·121·123·124 와 같은 관례
INSERT INTO tbl_role_screen (co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
SELECT r.co_cd, r.usrgrp_cd, s.scrn_cd,
       'Y', 'Y', 'Y',
       CASE WHEN r.usrgrp_cd = 'ADMIN' THEN 'Y' ELSE 'N' END,
       'Y', 'system', now()
  FROM tbl_role r
  CROSS JOIN (VALUES ('hwp-write')) AS s(scrn_cd)
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

-- 중분류 hwp-doc — docs 아래 hwp 와 menu_cd 가 겹치지 않는다
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'hwp-doc', 'HWP 문서', 'draft', NULL, 4400, 'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = 'draft', scrn_cd = NULL,
    use_yn = 'Y', sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- 소 leaf — menu_cd = scrn_cd (120 정본 규칙)
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, s.scrn_cd, s.scrn_nm, 'hwp-doc', s.scrn_cd, s.sort_no, 'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
 CROSS JOIN (SELECT scrn_cd, scrn_nm, sort_no FROM tbl_screen WHERE scrn_cd = 'hwp-write') s
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = 'hwp-doc', scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 4. sort 인코딩 SP — 124 정의에 hwp-doc 을 더한다
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
        ('hyg', 4100), ('ccp-chk', 4200), ('ccp-monitoring', 4300), ('hwp-doc', 4400)
      ) AS v(mc, sn)
     WHERE m.menu_cd = v.mc
       AND (p_co_cd IS NULL OR m.co_cd = p_co_cd);
END$$;
COMMENT ON PROCEDURE sp_tbl_menu_sort_encode_u_000(varchar) IS
  '대·중분류 정렬 인코딩 — 125에서 draft/hwp-doc 추가';

-- ------------------------------------------------------------
-- 5. 정렬 재계산
-- ------------------------------------------------------------
CALL sp_tbl_menu_sort_encode_u_000(NULL);
