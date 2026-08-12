-- ============================================================
-- 44 — HWP 정렬 템플릿 문서번호 채번 규칙 보강
--
-- 개발자: 박승우
-- 일자: 2026-08-10
-- 코멘트:
--   1) 37_migrate_hwp_tmpl_align 이 company_template 만 넣고 tbl_doc_no_rule 을 빠뜨렸다
--   2) 기존 테넌트에서 tmpl_admin-visitor-log 등 신규 저장 시 "문서번호 채번 규칙이 없습니다" 가 난다
--   3) 26_migrate_smart_diary_menu 와 동일 패턴으로 회사×템플릿 규칙을 채운다
-- ============================================================

SET search_path TO sasshaccp;

-- 기존 업체 채번 규칙 — 37 신규 HWP 템플릿
INSERT INTO tbl_doc_no_rule (co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
SELECT c.co_cd, t.tmpl_cd, t.tmpl_cd, 'YYYYMMDD', 3, 'D', 'system', now()
  FROM tbl_company c
 CROSS JOIN tbl_template t
 WHERE t.tmpl_cd IN (
    'tmpl_admin-visitor-log', 'tmpl_prp-visual-inspect', 'tmpl_logis-submat-receive', 'tmpl_prp-calib-ext', 'tmpl_logis-shipment-log', 'tmpl_admin-recall-report', 'tmpl_admin-eval-check'
 )
ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;
