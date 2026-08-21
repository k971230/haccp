-- ============================================================
-- 115 — HTML 지면 제목·부제·감도캡션 시드
--
-- 파일번호: 115
-- 이전번호: 114
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) 기준관리 수정 때 제목·부제를 저장한다. 항목코드 hdr-title / hdr-subtitle
--   2) 금속검출 감도표 제목은 hdr-sens-cap. 점검 행이 아니라서 지면 표에서는 뺀다
--   3) 자사 복사는 tbl_check_item 을 그대로 복사하므로 시드만 넣으면 된다
--
-- Jenkins는 migrate를 안 돌린다. DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

-- 공정점검 예시 — copy SP 가 html_sys_001 을 읽는다
INSERT INTO tbl_check_item (
    tmpl_cd, item_cd, grp_cd, grp_nm, item_nm, input_type, cycle_nm, sort_no, ins_id
) VALUES
    ('html_sys_001', 'hdr-title', 'hdr', '지면',
     '일반위생관리 및 공정점검표', 'text', NULL, 0, 'system'),
    ('html_sys_001', 'hdr-subtitle', 'hdr', '지면',
     '(매일 작성)', 'text', NULL, 0, 'system'),
    ('tml_ccp_chk_000', 'hdr-title', 'hdr', '지면',
     '중요관리점(CCP) 검증점검표', 'text', NULL, 0, 'system'),
    ('tml_ccp_chk_000', 'hdr-subtitle', 'hdr', '지면',
     '(매월 작성)', 'text', NULL, 0, 'system'),
    ('tml_ccp_pkg_000', 'hdr-title', 'hdr', '지면',
     '중요관리점(CCP-1B) 모니터링일지 [포장공정]', 'text', NULL, 0, 'system'),
    ('tml_ccp_pkg_000', 'hdr-subtitle', 'hdr', '지면',
     '(매일 작성)', 'text', NULL, 0, 'system'),
    ('tml_ccp_htg_000', 'hdr-title', 'hdr', '지면',
     '중요관리점(CCP-2B) 모니터링일지 [가열공정]', 'text', NULL, 0, 'system'),
    ('tml_ccp_htg_000', 'hdr-subtitle', 'hdr', '지면',
     '(매일 작성)', 'text', NULL, 0, 'system'),
    ('tml_ccp_mtl_000', 'hdr-title', 'hdr', '지면',
     '중요관리점(CCP-3P) 모니터링일지 [금속검출공정]', 'text', NULL, 0, 'system'),
    ('tml_ccp_mtl_000', 'hdr-subtitle', 'hdr', '지면',
     '(매일 작성)', 'text', NULL, 0, 'system'),
    ('tml_ccp_mtl_000', 'hdr-sens-cap', 'hdr', '지면',
     '금속검출기 감도 모니터링 (검출 = O, 불검출 = X)', 'text', NULL, 0, 'system')
ON CONFLICT (tmpl_cd, item_cd) DO UPDATE SET
    grp_cd = EXCLUDED.grp_cd,
    grp_nm = EXCLUDED.grp_nm,
    item_nm = EXCLUDED.item_nm,
    input_type = EXCLUDED.input_type,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();
