-- ============================================================
-- 87 — 사용양식 목록에 시스템양식 예제 전부 조회
--
-- 파일번호: 87
-- 이전번호: 86
-- 개발자: 박승우
-- 일자: 2026-08-14
-- 코멘트:
--   1) 사용양식 관리는 시스템 제공 양식을 예제로 전부 보여 준다.
--      84 목록 SP가 doc_kind=hwp 만 남겨 HTML 전용 화면 양식(원본 HWP 있음)이 빠졌다
--   2) 83이 html form_path 를 NULL 로 지워 예제 파일명이 비었다. 46 한글 경로를 되돌린다
--   3) 기존 회사에 빠진 카탈로그 행을 시스템양식(sys)으로 보강하고, 파일 이력을 시딩한다
--
-- 선행: 84(사용양식 목록 SP) · 86(문서주기 사용여부) 적용 완료
-- Jenkins는 migrate를 안 돌리므로 적용은 DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 예제 HWP 경로 복원 — 83이 html 을 NULL 로 지운 것을 46 정본으로 되돌린다
--    이미 같은 경로면 건너뛴다 (재실행 안전)
-- ------------------------------------------------------------
UPDATE tbl_template t
   SET form_path = v.path,
       upd_id    = 'system',
       upd_dt    = now()
  FROM (VALUES
    ('tmpl_admin-handover-doc',      'HaccpTemplates/tmpl_admin-handover-doc/업무_인수인계서.hwp'),
    ('tmpl_ccp-cold-log',            'HaccpTemplates/tmpl_ccp-cold-log/중요관리점[CCP]_점검표_냉장보관.hwp'),
    ('tmpl_ccp-metal-log',           'HaccpTemplates/tmpl_ccp-metal-log/중요관리점[CCP]_점검표_금속검출.hwp'),
    ('tmpl_ccp-verify-check',        'HaccpTemplates/tmpl_ccp-verify-check/중요관리점_검증점검표.hwp'),
    ('tmpl_prp-verify-plan',         'HaccpTemplates/tmpl_prp-verify-plan/연간_검증계획서.hwp'),
    ('tmpl_prp-verify-check',        'HaccpTemplates/tmpl_prp-verify-check/검증_점검표.hwp'),
    ('tmpl_prp-verify-report',       'HaccpTemplates/tmpl_prp-verify-report/검증결과_보고서.hwp'),
    ('tmpl_prp-verify-action',       'HaccpTemplates/tmpl_prp-verify-action/검증_개선조치_결과보고서.hwp'),
    ('tmpl_admin-edu-plan',          'HaccpTemplates/tmpl_admin-edu-plan/연간_교육_훈련_계획서.hwp'),
    ('tmpl_admin-edu-log',           'HaccpTemplates/tmpl_admin-edu-log/교육일지.hwp'),
    ('tmpl_prp-hygiene-daily',       'HaccpTemplates/tmpl_prp-hygiene-daily/일일_위생_점검일지.hwp'),
    ('tmpl_prp-hygiene-personal',    'HaccpTemplates/tmpl_prp-hygiene-personal/개인_위생관리_점검표.hwp'),
    ('tmpl_prp-hygiene-area',        'HaccpTemplates/tmpl_prp-hygiene-area/작업장_위생관리_점검표.hwp'),
    ('tmpl_prp-pest-check',          'HaccpTemplates/tmpl_prp-pest-check/방충_방서_점검표.hwp'),
    ('tmpl_prp-facility-check',      'HaccpTemplates/tmpl_prp-facility-check/시설_설비_처리도구_점검표.hwp'),
    ('tmpl_prp-calib-target',        'HaccpTemplates/tmpl_prp-calib-target/검_교정_대상.hwp'),
    ('tmpl_prp-calib-temp',          'HaccpTemplates/tmpl_prp-calib-temp/자체_검_교정_일지_1.hwp'),
    ('tmpl_prp-calib-weight',        'HaccpTemplates/tmpl_prp-calib-weight/자체_검_교정_일지_2.hwp'),
    ('tmpl_prp-calib-scale',         'HaccpTemplates/tmpl_prp-calib-scale/자체_검_교정_일지_3.hwp'),
    ('tmpl_prp-equip-card',          'HaccpTemplates/tmpl_prp-equip-card/시설_설비_이력카드.hwp'),
    ('tmpl_prp-waste-check',         'HaccpTemplates/tmpl_prp-waste-check/폐기물_처리_점검표.hwp'),
    ('tmpl_logis-inventory-check',   'HaccpTemplates/tmpl_logis-inventory-check/입출고_및_재고_점검표.hwp'),
    ('tmpl_logis-receive-inspect',   'HaccpTemplates/tmpl_logis-receive-inspect/입고검사_일지.hwp'),
    ('tmpl_prp-test-product',        'HaccpTemplates/tmpl_prp-test-product/제품검사_성적서.hwp'),
    ('tmpl_prp-test-surface',        'HaccpTemplates/tmpl_prp-test-surface/표면오염도_검사_성적서.hwp'),
    ('tmpl_admin-bad-product',       'HaccpTemplates/tmpl_admin-bad-product/부적합제품_관리_점검표.hwp'),
    ('tmpl_prp-water-check',         'HaccpTemplates/tmpl_prp-water-check/용수관리_점검표.hwp'),
    ('tmpl_admin-claim-log',         'HaccpTemplates/tmpl_admin-claim-log/클레임_관리_일지.hwp'),
    ('tmpl_ccp-process-check',       'HaccpTemplates/tmpl_ccp-process-check/공정관리_점검표.hwp'),
    ('tmpl_logis-vehicle-log',       'HaccpTemplates/tmpl_logis-vehicle-log/차량운행일지.hwp'),
    ('tmpl_admin-visitor-log',       'HaccpTemplates/tmpl_admin-visitor-log/외부인출입기록부.hwp'),
    ('tmpl_prp-visual-inspect',      'HaccpTemplates/tmpl_prp-visual-inspect/원료부자재육안검사기준.hwp'),
    ('tmpl_logis-submat-receive',    'HaccpTemplates/tmpl_logis-submat-receive/부자재입고검수점검표.hwp'),
    ('tmpl_prp-calib-ext',           'HaccpTemplates/tmpl_prp-calib-ext/외부 검교정기록부.hwp'),
    ('tmpl_logis-shipment-log',      'HaccpTemplates/tmpl_logis-shipment-log/제품출고관리일지.hwp'),
    ('tmpl_admin-recall-report',     'HaccpTemplates/tmpl_admin-recall-report/회수결과보고서.hwp'),
    ('tmpl_admin-eval-check',        'HaccpTemplates/tmpl_admin-eval-check/실시상황평가표.hwp')
  ) AS v(tmpl_cd, path)
 WHERE t.tmpl_cd = v.tmpl_cd
   AND COALESCE(t.form_path, '') <> v.path;

COMMENT ON COLUMN tbl_template.form_path IS
  '표준 원본 HWP 상대경로 — HaccpTemplates/{tmpl_cd}/{파일명}. html 전용 화면 양식도 예제 원본이 있으면 경로를 둔다';

-- ------------------------------------------------------------
-- 2. 기존 회사 — 구현된 플랫폼 카탈로그(impl_yn=Y)를 시스템양식으로 보강
--    이미 있는 행(자사양식 포함)은 덮지 않는다
-- ------------------------------------------------------------
INSERT INTO tbl_company_template (co_cd, tmpl_cd, use_yn, sys_yn, cycle_cd, retention_month, ins_id, ins_dt)
SELECT c.co_cd,
       t.tmpl_cd,
       'Y',
       'sys',
       t.default_cycle_cd,
       t.default_retention_month,
       'system',
       now()
  FROM tbl_company c
 CROSS JOIN tbl_template t
 WHERE t.use_yn = 'Y'
   AND t.impl_yn = 'Y'
   AND t.co_cd = '0000'
ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

-- ------------------------------------------------------------
-- 3. 예제 원본을 파일 이력 seq 1(sys)로 시딩 — 84와 같은 고정 순번
-- ------------------------------------------------------------
INSERT INTO tbl_company_template_file(co_cd, tmpl_cd, file_seq, file_nm, form_path, src_ty, ins_id)
SELECT ct.co_cd,
       ct.tmpl_cd,
       1,
       regexp_replace(t.form_path, '^.*/', ''),
       t.form_path,
       'sys',
       'system'
  FROM tbl_company_template ct
  JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
 WHERE COALESCE(t.form_path, '') <> ''
ON CONFLICT (co_cd, tmpl_cd, file_seq) DO NOTHING;

UPDATE tbl_company_template ct
   SET default_file_idx = f.idx
  FROM tbl_company_template_file f
 WHERE f.co_cd = ct.co_cd AND f.tmpl_cd = ct.tmpl_cd AND f.src_ty = 'sys'
   AND ct.default_file_idx IS NULL;

UPDATE tbl_company_template ct
   SET current_file_idx = f.idx,
       form_path        = COALESCE(NULLIF(ct.form_path, ''), f.form_path)
  FROM tbl_company_template_file f
 WHERE f.co_cd = ct.co_cd AND f.tmpl_cd = ct.tmpl_cd AND f.src_ty = 'sys'
   AND ct.current_file_idx IS NULL;

-- ------------------------------------------------------------
-- 4. 목록 SP — hwp 전용 필터를 뺀다. 시스템양식 예제 + 자사양식 전부 조회
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_hwp_template_management_r_000(varchar, varchar, varchar);
CREATE FUNCTION sp_hwp_template_management_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_tmpl_cd: 헤더 양식코드 검색어. 공백이면 전체
    p_tmpl_cd varchar,
    -- p_tmpl_nm: 헤더 양식명 검색어. 공백이면 전체
    p_tmpl_nm varchar
)
RETURNS TABLE(
    tmpl_cd          varchar,
    tmpl_nm          varchar,
    -- 구분 — sys:시스템, usr:자사양식. 화면은 표시 전용이며 저장·수정 대상이 아니다
    sys_yn           varchar,
    doc_kind         varchar,
    category_cd      varchar,
    mng_no           varchar,
    -- 현재 적용 파일의 상대 경로 — 자사 업로드본이 있으면 그것, 없으면 표준 원본
    form_path        varchar,
    -- 현재 적용 파일명 — 그리드 양식파일 컬럼
    form_file_nm     varchar,
    use_yn           varchar,
    default_file_idx bigint,
    current_file_idx bigint,
    -- 살아있는 파일 이력 건수 — 불러오기 버튼 활성 판정
    file_hist_cnt    int
) LANGUAGE sql STABLE AS $$
    SELECT ct.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           lower(CASE WHEN COALESCE(ct.sys_yn, 'sys') IN ('N', 'n', 'usr') THEN 'usr' ELSE 'sys' END),
           t.doc_kind,
           t.category_cd,
           t.mng_no,
           COALESCE(NULLIF(ct.form_path, ''), t.form_path),
           CASE
             WHEN COALESCE(NULLIF(ct.form_path, ''), t.form_path) IS NULL THEN NULL
             ELSE regexp_replace(COALESCE(NULLIF(ct.form_path, ''), t.form_path), '^.*/', '')
           END,
           ct.use_yn,
           ct.default_file_idx,
           ct.current_file_idx,
           (SELECT COUNT(*)::int
              FROM tbl_company_template_file f
             WHERE f.co_cd = ct.co_cd AND f.tmpl_cd = ct.tmpl_cd AND f.del_yn = 'N')
      FROM tbl_company_template ct
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
     WHERE ct.co_cd = p_co_cd
       -- html 전용 화면도 예제 HWP 를 쓰므로 doc_kind 로 숨기지 않는다
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_hwp_template_management_r_000(varchar, varchar, varchar) IS
  '사용양식 목록 — 시스템양식 예제+자사양식 전부, 구분(sys/usr)·현재 파일명·사용유무·기본/현재 파일·이력건수. 미사용 양식도 포함';
