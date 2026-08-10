-- 32_migrate_hwp_src_replace.sql
-- HWP_SRC 문서당 1건 유지 — 종류별 일괄 삭제 SP
-- 적용: psql -f db_sasshaccp/32_migrate_hwp_src_replace.sql

CREATE OR REPLACE PROCEDURE sp_tbl_document_file_d_001(
    p_co_cd varchar,
    p_doc_idx bigint,
    p_file_kind varchar,
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_status varchar(3);
BEGIN
    SELECT d.status INTO v_status
      FROM tbl_document d
     WHERE d.idx = p_doc_idx
       AND d.co_cd = p_co_cd
       AND d.del_yn = 'N';

    IF NOT FOUND THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF v_status IN ('REQ', 'REV', 'APV') THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서의 파일은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_document_file
     WHERE co_cd = p_co_cd
       AND doc_idx = p_doc_idx
       AND upper(file_kind) = upper(trim(p_file_kind));
END$$;

COMMENT ON PROCEDURE sp_tbl_document_file_d_001(varchar, bigint, varchar, varchar) IS '문서·파일종류별 메타 일괄 삭제 — HWP_SRC 덮어쓰기 전 호출';
