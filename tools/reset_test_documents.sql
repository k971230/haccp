-- ============================================================
--  reset_test_documents.sql — 테스트 문서 전체 삭제 (로컬 전용)
--
--  개발자: 박승우
--  일자: 2026-08-25
--
--  ############  경고  ############
--  이 스크립트는 작성한 문서를 **전부** 지운다.
--  작성중·전송대기·전송·결재완료·반려를 가리지 않는다. 되돌릴 수 없다.
--  테스트 환경에서만 쓴다. 운영 DB 에서 절대 실행하지 않는다.
--  ################################
--
--  지우는 것 : 문서 헤더·결재이력·첨부메타·버전·업무 본문(점검표·모니터링일지)·개선조치
--  남기는 것 : 사용자·권한·메뉴·양식(template)·기준정보·공통코드
--
--  첨부 물리 파일은 지우지 않는다 — DB 만 비운다.
--  저장 루트({root}/{co_cd}/{yyyy}/{mm}/) 는 필요하면 따로 비운다.
--
--  실행: psql -f tools/reset_test_documents.sql
--  git 미포함 (01-project-core.mdc — tools/ 는 로컬 전용)
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

DO $$
DECLARE
    v_tbl text;
    v_sql text;
    v_cnt bigint;
    v_total bigint := 0;
BEGIN
    /*
     * 문서에 매달린 표를 이름이 아니라 컬럼으로 찾는다.
     * 표를 손으로 나열하면 새 양식이 생길 때마다 빠뜨린다.
     *   doc_idx      — 문서 헤더에 직접 매달린 표 (tbl_hyg_process, tbl_document_file …)
     *   hdr_idx 등   — 그 아래 행·칸 표 (tbl_hyg_process_item, *_row, *_cell …)
     * 기준정보·양식·사용자 표에는 이 컬럼들이 없어 대상에 들어오지 않는다.
     */
    -- FK 이후에는 이름순 DELETE 가 헤더를 자식보다 먼저 친다.
    -- 칸 → 행 → 본문헤더 순으로 세 번 돈다.
    FOR v_tbl IN
        SELECT table_name FROM (
            SELECT DISTINCT c.table_name,
                   CASE c.column_name
                     WHEN 'row_idx' THEN 1
                     WHEN 'hdr_idx' THEN 2
                     WHEN 'monitor_idx' THEN 2
                     WHEN 'chk_idx' THEN 2
                     ELSE 3
                   END AS ord
              FROM information_schema.columns c
             WHERE c.table_schema = 'sasshaccp'
               AND c.table_name LIKE 'tbl\_%'
               AND c.column_name IN (
                   'doc_idx', 'hdr_idx', 'monitor_idx', 'row_idx', 'chk_idx', 'src_doc_idx'
               )
               AND c.table_name NOT LIKE '%\_ver'
               AND c.table_name NOT IN (
                   'tbl_company_template',
                   'tbl_template',
                   'tbl_schedule_task'
               )
        ) x
         GROUP BY table_name
         ORDER BY min(ord), table_name
    LOOP
        v_sql := format('DELETE FROM %I', v_tbl);
        EXECUTE v_sql;
        GET DIAGNOSTICS v_cnt = ROW_COUNT;
        v_total := v_total + v_cnt;
        IF v_cnt > 0 THEN
            RAISE NOTICE '  % — %건 삭제', rpad(v_tbl, 40), v_cnt;
        END IF;
    END LOOP;

    -- 알림·과제는 문서 FK 가 있어 헤더보다 먼저 끊는다
    DELETE FROM tbl_notification;
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    v_total := v_total + v_cnt;
    UPDATE tbl_schedule_task SET doc_idx = NULL WHERE doc_idx IS NOT NULL;

    -- 문서 헤더는 마지막에 — 위에서 자식을 다 비운 뒤다
    DELETE FROM tbl_document;
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    v_total := v_total + v_cnt;
    RAISE NOTICE '  % — %건 삭제', rpad('tbl_document', 40), v_cnt;

    RAISE NOTICE '합계 %건을 지웠다.', v_total;
END$$;

-- 문서번호 채번 — 다음 테스트가 001 부터 시작하게 되돌린다.
-- 규칙 행은 남기고 카운터만 0 으로 (규칙을 지우면 문서를 못 만든다)
UPDATE tbl_doc_no_rule
   SET last_seq = 0, last_reset_key = NULL, upd_dt = now();

COMMIT;

-- 확인용 — 셋 다 0 이어야 한다
-- SELECT count(*) AS 문서 FROM tbl_document;
-- SELECT count(*) AS 결재이력 FROM tbl_document_approval;
-- SELECT count(*) AS 첨부 FROM tbl_document_file;
