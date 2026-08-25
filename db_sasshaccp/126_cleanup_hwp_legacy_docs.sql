-- ============================================================
--  126_cleanup_hwp_legacy_docs.sql — HWP 문서 레거시 데이터 전체 삭제
--
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) doc_kind='hwp' 문서와 딸린 첨부·결재·버전·관계·개선조치를 모두 지운다
--    2) HWP 작성 화면을 신규 데이터로 다시 시작하기 위한 1회성 정리다
--    3) 되돌릴 수 없다 — 실행 전에 아래 1번 확인 쿼리로 건수를 먼저 본다
--
--  [경고] 지우는 범위
--    doc_kind='hwp' 는 새 작성 화면(/draft/hwp-doc/hwp-write)만의 것이 아니다.
--    기존 HWP 편집 화면(/docs/ccp/process-hwp · /docs/logis/vehicle-hwp 등 20여 개)이
--    만든 문서도 같은 값을 쓴다. 이 스크립트는 그 문서들도 함께 지운다.
--    HTML 전용 화면 문서(doc_kind='html')는 건드리지 않는다.
--
--  [수동 후처리] 물리 파일
--    DB 행만 지운다. 실제 HWP·PDF 파일은 파일 볼륨에 남는다.
--    로컬:  backend/haccp-api/data/haccp-files/HaccpLogBooks
--    운영:  /var/haccp/files/HaccpLogBooks
--    위 폴더를 직접 비워야 디스크가 정리된다.
--
--  실행: DBeaver 에서 1번 확인 → 2번 삭제 순서로 실행
-- ============================================================

-- ------------------------------------------------------------
-- 1. 확인 — 무엇이 몇 건 지워지는지 먼저 본다 (삭제 전 필수)
-- ------------------------------------------------------------
SELECT '문서(hwp)'      AS 대상, count(*) AS 건수 FROM tbl_document WHERE doc_kind = 'hwp'
UNION ALL
SELECT '  - 상태 WRK/RJT(작성중·반려)', count(*) FROM tbl_document WHERE doc_kind = 'hwp' AND status IN ('WRK','RJT')
UNION ALL
SELECT '  - 상태 REQ/REV(전송)',        count(*) FROM tbl_document WHERE doc_kind = 'hwp' AND status IN ('REQ','REV')
UNION ALL
SELECT '  - 상태 APV(결재완료)',        count(*) FROM tbl_document WHERE doc_kind = 'hwp' AND status = 'APV'
UNION ALL
SELECT '첨부·본문 파일', count(*) FROM tbl_document_file f
  WHERE EXISTS (SELECT 1 FROM tbl_document d WHERE d.idx = f.doc_idx AND d.doc_kind = 'hwp')
UNION ALL
SELECT '결재 이력', count(*) FROM tbl_document_approval a
  WHERE EXISTS (SELECT 1 FROM tbl_document d WHERE d.idx = a.doc_idx AND d.doc_kind = 'hwp')
UNION ALL
SELECT '문서 버전', count(*) FROM tbl_document_version v
  WHERE EXISTS (SELECT 1 FROM tbl_document d WHERE d.idx = v.doc_idx AND d.doc_kind = 'hwp')
UNION ALL
SELECT '개선조치', count(*) FROM tbl_corrective_action c
  WHERE EXISTS (SELECT 1 FROM tbl_document d WHERE d.idx = c.src_doc_idx AND d.doc_kind = 'hwp')
UNION ALL
SELECT '할일 연결(끊기만 함)', count(*) FROM tbl_schedule_task t
  WHERE EXISTS (SELECT 1 FROM tbl_document d WHERE d.idx = t.doc_idx AND d.doc_kind = 'hwp');

-- 양식코드·상태별 건수 — 어느 옛 화면 계열이 몇 건인지 보고 삭제 범위를 확정한다
-- (1단계 합계만으로는 process-hwp·vehicle-hwp 등이 섞인 줄 모른다)
SELECT d.tmpl_cd, t.tmpl_nm, d.status, count(*) AS 건수
FROM tbl_document d
LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
WHERE d.doc_kind = 'hwp'
GROUP BY d.tmpl_cd, t.tmpl_nm, d.status
ORDER BY 건수 DESC, d.tmpl_cd;

-- ------------------------------------------------------------
-- 2. 삭제 — 위 건수를 확인한 뒤 이 블록을 실행한다
--    한 트랜잭션으로 묶여 중간에 실패하면 아무것도 지워지지 않는다
-- ------------------------------------------------------------
DO $$
DECLARE
    v_docs bigint[];
    v_cnt int;
BEGIN
    SELECT array_agg(idx) INTO v_docs FROM tbl_document WHERE doc_kind = 'hwp';
    IF v_docs IS NULL THEN
        RAISE NOTICE '지울 HWP 문서가 없습니다.';
        RETURN;
    END IF;
    v_cnt := array_length(v_docs, 1);

    -- 할일은 지우지 않는다 — 문서 연결만 끊어 오늘 할일이 사라지지 않게 한다
    UPDATE tbl_schedule_task SET doc_idx = NULL WHERE doc_idx = ANY(v_docs);
    -- 알림의 문서 링크도 끊는다 — 지운 문서를 열려다 오류가 나지 않게 한다
    UPDATE tbl_notification SET link_doc_idx = NULL WHERE link_doc_idx = ANY(v_docs);

    DELETE FROM tbl_corrective_action   WHERE src_doc_idx = ANY(v_docs);
    DELETE FROM tbl_document_relation   WHERE src_doc_idx = ANY(v_docs) OR tgt_doc_idx = ANY(v_docs);
    DELETE FROM tbl_document_approval   WHERE doc_idx = ANY(v_docs);
    DELETE FROM tbl_document_version    WHERE doc_idx = ANY(v_docs);
    DELETE FROM tbl_document_file       WHERE doc_idx = ANY(v_docs);
    DELETE FROM tbl_document            WHERE idx = ANY(v_docs);

    RAISE NOTICE 'HWP 문서 % 건과 딸린 자료를 지웠습니다. 파일 볼륨은 직접 비우세요.', v_cnt;
END$$;

-- ------------------------------------------------------------
-- 3. 확인 — 0 이어야 한다
-- ------------------------------------------------------------
SELECT count(*) AS 남은_hwp_문서 FROM tbl_document WHERE doc_kind = 'hwp';
