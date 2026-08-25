-- ============================================================
--  diag_draft_paper.sql — 작성 지면에 값이 안 뜰 때 어느 층이 비었는지 찾는다 (로컬 전용)
--
--  개발자: 박승우
--  일자: 2026-08-25
--
--  증상: 저장했는데 지면(작성 화면 우측 · 결재 미리보기)에 값이 안 보인다.
--  화면·API·SP 중 어디서 끊겼는지 이 스크립트 한 번으로 가른다. 읽기 전용이다.
--
--  실행: psql -f tools/diag_draft_paper.sql
--  git 미포함 (01-project-core.mdc — tools/ 는 로컬 전용)
-- ============================================================

SET search_path TO sasshaccp;

\echo '== 1. 최근 문서 10건 — 상태·양식 =='
SELECT d.idx AS doc_idx, d.doc_no, d.tmpl_cd, d.status, d.base_dt, d.writer_id
  FROM tbl_document d
 WHERE d.del_yn = 'N'
 ORDER BY d.idx DESC
 LIMIT 10;

\echo ''
\echo '== 2. CCP 모니터링(포장·가열) — 문서별 본문 행이 실제로 있는가 =='
-- monitor_rows 가 0 이면 저장이 안 된 것, cells 가 0 이면 칸 값이 안 붙은 것이다
SELECT d.idx AS doc_idx,
       d.doc_no,
       d.tmpl_cd,
       d.status,
       m.idx           AS monitor_idx,
       (SELECT count(*) FROM tbl_ccp_generic_monitor_row r
         WHERE r.monitor_idx = m.idx AND r.co_cd = m.co_cd)      AS monitor_rows,
       (SELECT count(*) FROM tbl_ccp_generic_monitor_cell c
          JOIN tbl_ccp_generic_monitor_row r2 ON r2.idx = c.row_idx
         WHERE r2.monitor_idx = m.idx AND c.co_cd = m.co_cd)     AS cells
  FROM tbl_document d
  LEFT JOIN tbl_ccp_generic_monitor m
         ON m.doc_idx = d.idx AND m.co_cd = d.co_cd
 WHERE d.del_yn = 'N'
   AND (d.tmpl_cd LIKE 'tml_ccp_pkg_%' OR d.tmpl_cd LIKE 'tml_ccp_htg_%')
 ORDER BY d.idx DESC
 LIMIT 10;

\echo ''
\echo '== 3. 가열(htg) 양식 항목 — 지면 한계기준·주기 행이 있는가 =='
-- 서비스는 항상 ver_no=1 로 조회한다 (tbl_ccp_generic_monitor 에 ver_no 컬럼이 없다).
-- 아래 ver_no 가 1 이 아닌 양식이 있으면 그 양식은 지면 항목이 통째로 비어 보인다.
-- item_cnt 가 0 이면 양식관리에서 항목을 저장하지 않은 것이다.
SELECT v.tmpl_cd,
       v.ver_no,
       v.ver_nm,
       v.use_yn,
       (SELECT count(*) FROM tbl_tml_ccp_htg_ver_item i
         WHERE i.co_cd = v.co_cd AND i.tmpl_cd = v.tmpl_cd AND i.ver_no = v.ver_no) AS item_cnt
  FROM tbl_tml_ccp_htg_ver v
 ORDER BY v.tmpl_cd, v.ver_no;

\echo ''
\echo '== 4. 포장(pkg) 양식 항목 =='
SELECT v.tmpl_cd,
       v.ver_no,
       v.ver_nm,
       v.use_yn,
       (SELECT count(*) FROM tbl_tml_ccp_pkg_ver_item i
         WHERE i.co_cd = v.co_cd AND i.tmpl_cd = v.tmpl_cd AND i.ver_no = v.ver_no) AS item_cnt
  FROM tbl_tml_ccp_pkg_ver v
 ORDER BY v.tmpl_cd, v.ver_no;

\echo ''
\echo '== 5. 상세 SP 원본 응답 — 화면이 실제로 받는 값 =='
-- :doc_idx 를 위 1번 목록의 doc_idx 로 바꿔 실행한다
\set doc_idx 0
SELECT *
  FROM sp_tbl_ccp_generic_monitor_r_000(
         (SELECT co_cd FROM tbl_document WHERE idx = :doc_idx),
         :doc_idx
       )
 WHERE :doc_idx > 0;

\echo ''
\echo '== 6. 결재 단계 — 검토(REVIEW)가 끼어 있는지 =='
SELECT d.doc_no, d.status, a.step_no, a.role_cd, a.result_cd, a.approver_id
  FROM tbl_document d
  JOIN tbl_document_approval a ON a.doc_idx = d.idx AND a.co_cd = d.co_cd
 WHERE d.del_yn = 'N'
 ORDER BY d.idx DESC, a.step_no
 LIMIT 30;

\echo ''
\echo '== 7. 결재선 정의 — 켜진 단계만 결재선에 들어가야 한다 =='
SELECT co_cd, appr_line_cd, step_no, role_cd, use_yn, approver_id
  FROM tbl_approval_line_step
 ORDER BY co_cd, appr_line_cd, step_no;
