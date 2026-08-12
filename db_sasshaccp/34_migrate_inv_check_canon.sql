-- ============================================================
-- 34 — 재고 점검 양식코드 INV → tmpl_logis-inventory-check 통일
--
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) 시드·BizOps SP·Controller는 tmpl_logis-inventory-check를 쓰는데 구 시드 tmpl_cd=INV 가 남아 저장이 실패했다
--   2) 기존 테넌트의 템플릿·화면·사용양식·채번·문서를 tmpl_logis-inventory-check로 옮긴다
--   3) 이미 tmpl_logis-inventory-check만 있으면 환경에서는 no-op에 가깝게 동작한다
-- ============================================================

SET search_path TO sasshaccp;

-- 표준양식 — INV만 있고 tmpl_logis-inventory-check가 없을 때 행을 복제해 코드를 바꾼다
INSERT INTO tbl_template (
    tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
    default_cycle_cd, default_retention_month, impl_yn, sort_no, ins_id, ins_dt
)
SELECT 'tmpl_logis-inventory-check', tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
       default_cycle_cd, default_retention_month, impl_yn, sort_no, 'system', now()
  FROM tbl_template
 WHERE tmpl_cd = 'INV'
   AND NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = 'tmpl_logis-inventory-check')
ON CONFLICT (tmpl_cd) DO NOTHING;

-- tmpl_logis-inventory-check가 이미 있으면 경우에도 화면·명칭을 inventory-check와 맞춘다
UPDATE tbl_template
   SET tmpl_nm = COALESCE(tmpl_nm, '입·출고 및 재고 점검표'),
       scrn_cd = 'inventory-check',
       category_cd = 'INV',
       doc_kind = 'DB',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'tmpl_logis-inventory-check';

UPDATE tbl_screen
   SET tmpl_cd = 'tmpl_logis-inventory-check',
       upd_id = 'system',
       upd_dt = now()
 WHERE scrn_cd = 'inventory-check'
   AND COALESCE(tmpl_cd, '') IN ('INV', 'tmpl_logis-inventory-check', '');

-- 회사 사용양식·채번·점검항목 오버라이드
UPDATE tbl_company_template
   SET tmpl_cd = 'tmpl_logis-inventory-check',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'INV'
   AND NOT EXISTS (
       SELECT 1 FROM tbl_company_template x
        WHERE x.co_cd = tbl_company_template.co_cd
          AND x.tmpl_cd = 'tmpl_logis-inventory-check'
   );

DELETE FROM tbl_company_template WHERE tmpl_cd = 'INV';

UPDATE tbl_doc_no_rule
   SET tmpl_cd = 'tmpl_logis-inventory-check',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'INV'
   AND NOT EXISTS (
       SELECT 1 FROM tbl_doc_no_rule x
        WHERE x.co_cd = tbl_doc_no_rule.co_cd
          AND x.tmpl_cd = 'tmpl_logis-inventory-check'
   );

DELETE FROM tbl_doc_no_rule WHERE tmpl_cd = 'INV';

UPDATE tbl_company_check_item
   SET tmpl_cd = 'tmpl_logis-inventory-check',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'INV'
   AND NOT EXISTS (
       SELECT 1 FROM tbl_company_check_item x
        WHERE x.co_cd = tbl_company_check_item.co_cd
          AND x.tmpl_cd = 'tmpl_logis-inventory-check'
          AND x.item_cd = tbl_company_check_item.item_cd
   );

DELETE FROM tbl_company_check_item WHERE tmpl_cd = 'INV';

-- 업무 문서·수불 원천 양식코드
UPDATE tbl_document
   SET tmpl_cd = 'tmpl_logis-inventory-check',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'INV';

UPDATE tbl_inv_txn
   SET src_tmpl_cd = 'tmpl_logis-inventory-check'
 WHERE src_tmpl_cd = 'INV';

-- 구 INV 표준양식 행 제거 (자식 참조를 위로 옮긴 뒤)
DELETE FROM tbl_template WHERE tmpl_cd = 'INV';
