-- ============================================================
--  130_migrate_hwp_draft_deviation.sql — HWP 작성 목록에 이탈여부
--
--  파일번호: 130
--  이전번호: 129
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) HWP 작성 화면은 우측이 rhwp 편집기라 지면 하단 이탈 시그널을 둘 자리가 없다
--       좌측 목록에 이탈여부 칸을 두고 거기서 켠다 — HTML 5화면의 지면 시그널과 같은 뜻이다
--    2) 목록 SP 가 deviation_yn 을 돌려준다 — 개선조치 행이 하나라도 있으면 Y
--       ng_cnt(미완료 수)와 다른 축이다. 완료된 이탈도 「이탈이 있었다」는 사실은 남는다
--    3) 반환 컬럼이 늘어 DROP 후 재생성한다
--
--  켠 뒤의 실제 조치 작성은 이탈·개선조치 화면(/flow/ca)에서 한다.
--
--  실행: psql -f 130_migrate_hwp_draft_deviation.sql (수동·DBeaver)
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

DROP FUNCTION IF EXISTS sp_draft_hwp_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar);

CREATE FUNCTION sp_draft_hwp_r_000(
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
    ng_cnt int,
    deviation_yn varchar
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
             WHERE ca.co_cd = d.co_cd AND ca.src_doc_idx = d.idx AND ca.status <> 'DONE'),
           -- 이탈여부 — 완료 여부와 무관하게 개선조치가 붙어 있으면 Y
           (CASE WHEN EXISTS (
                    SELECT 1 FROM tbl_corrective_action ca2
                     WHERE ca2.co_cd = d.co_cd AND ca2.src_doc_idx = d.idx
                ) THEN 'Y' ELSE 'N' END)::varchar
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
       AND (COALESCE(NULLIF(btrim(p_writer_id), ''), '') = ''
            OR COALESCE(d.writer_id, '') ILIKE '%' || btrim(p_writer_id) || '%')
       AND (COALESCE(NULLIF(btrim(p_writer_nm), ''), '') = ''
            OR COALESCE(u.user_nm, '') ILIKE '%' || btrim(p_writer_nm) || '%')
     ORDER BY d.base_dt DESC, d.idx DESC;
$$;
COMMENT ON FUNCTION sp_draft_hwp_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar) IS
  'HWP 작성 목록 — 130에서 이탈여부(deviation_yn) 추가';

COMMIT;

-- 확인용
-- SELECT doc_no, base_dt, status, ng_cnt, deviation_yn FROM sp_draft_hwp_r_000('<co_cd>','','','','','','');
