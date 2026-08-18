-- ============================================================
-- 93 — 시스템 양식 코드를 hwp_sys_NNN 으로 바꾸고 new 27건을 시드한다
--
-- 파일번호: 93
-- 이전번호: 92
-- 개발자: 박승우
-- 일자: 2026-08-18
-- 코멘트:
--   1) 사용양식 관리 시스템제공 코드는 hwp_sys_001~027. 사용자추가는 화면이 hwp_usr_NNN 을 채번한다
--   2) docs/templates/new 27건을 00부터 정렬한 순번이다. HTML 전용 화면 tmpl_* 코드는 그대로 둔다
--   3) 목록 SP는 시스템제공 hwp_sys_% + 사용자추가(usr)만 보여 옛 kebab 시스템 행을 숨긴다
--
-- Jenkins는 migrate를 안 돌리므로 적용은 DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

INSERT INTO tbl_template (
    co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd,
    default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, form_path, ins_id, ins_dt
)
SELECT '0000', v.tmpl_cd, v.tmpl_nm, v.mng_no, v.doc_kind, v.category_cd,
       'E', 24, 'Y', v.sort_no, 'Y', v.form_path, 'system', now()
  FROM (VALUES
    ('hwp_sys_001', '외부인출입기록부', '00', 'hwp', 'DOC', 1, 'HaccpTemplates/hwp_sys_001/외부인출입기록부.hwp'),
    ('hwp_sys_002', '업무인수인계서', '01', 'hwp', 'DOC', 2, 'HaccpTemplates/hwp_sys_002/업무인수인계서.hwp'),
    ('hwp_sys_003', '연간검증계획서', '04', 'hwp', 'DOC', 3, 'HaccpTemplates/hwp_sys_003/연간검증계획서.hwp'),
    ('hwp_sys_004', '검증점검표', '05', 'hwp', 'DOC', 4, 'HaccpTemplates/hwp_sys_004/검증점검표.hwp'),
    ('hwp_sys_005', '검증결과보고서', '06', 'hwp', 'DOC', 5, 'HaccpTemplates/hwp_sys_005/검증결과보고서.hwp'),
    ('hwp_sys_006', '검증개선조치결과보고서', '07', 'hwp', 'DOC', 6, 'HaccpTemplates/hwp_sys_006/검증개선조치결과보고서.hwp'),
    ('hwp_sys_007', '연간교육·훈련계획서', '08', 'hwp', 'DOC', 7, 'HaccpTemplates/hwp_sys_007/연간교육·훈련계획서.hwp'),
    ('hwp_sys_008', '교육일지', '09', 'hwp', 'DOC', 8, 'HaccpTemplates/hwp_sys_008/교육일지.hwp'),
    ('hwp_sys_009', '개인위생관리점검표', '11', 'hwp', 'DOC', 9, 'HaccpTemplates/hwp_sys_009/개인위생관리점검표.hwp'),
    ('hwp_sys_010', '작업장위생관리점검표', '12', 'hwp', 'DOC', 10, 'HaccpTemplates/hwp_sys_010/작업장위생관리점검표.hwp'),
    ('hwp_sys_011', '방충방서점검표', '13', 'hwp', 'DOC', 11, 'HaccpTemplates/hwp_sys_011/방충방서점검표.hwp'),
    ('hwp_sys_012', '시설설비처리도구점검표', '14', 'hwp', 'DOC', 12, 'HaccpTemplates/hwp_sys_012/시설설비처리도구점검표.hwp'),
    ('hwp_sys_013', '검교정대상', '15', 'hwp', 'DOC', 13, 'HaccpTemplates/hwp_sys_013/검교정대상.hwp'),
    ('hwp_sys_014', '자체검교정일지', '16', 'hwp', 'DOC', 14, 'HaccpTemplates/hwp_sys_014/자체검교정일지.hwp'),
    ('hwp_sys_015', '폐기물처리점검표', '18', 'hwp', 'DOC', 15, 'HaccpTemplates/hwp_sys_015/폐기물처리점검표.hwp'),
    ('hwp_sys_016', '입출고및재고점검표', '19', 'hwp', 'DOC', 16, 'HaccpTemplates/hwp_sys_016/입출고및재고점검표.hwp'),
    ('hwp_sys_017', '입고검사일지', '20', 'hwp', 'DOC', 17, 'HaccpTemplates/hwp_sys_017/입고검사일지.hwp'),
    ('hwp_sys_018', '제품검사성적서', '21', 'hwp', 'DOC', 18, 'HaccpTemplates/hwp_sys_018/제품검사성적서.hwp'),
    ('hwp_sys_019', '표면오염도검사성적서', '22', 'hwp', 'DOC', 19, 'HaccpTemplates/hwp_sys_019/표면오염도검사성적서.hwp'),
    ('hwp_sys_020', '부적합제품관리점검표', '23', 'hwp', 'DOC', 20, 'HaccpTemplates/hwp_sys_020/부적합제품관리점검표.hwp'),
    ('hwp_sys_021', '용수관리_점검표', '24', 'hwp', 'DOC', 21, 'HaccpTemplates/hwp_sys_021/용수관리_점검표.hwp'),
    ('hwp_sys_022', '소비자불만관리일지', '25', 'hwp', 'DOC', 22, 'HaccpTemplates/hwp_sys_022/소비자불만관리일지.hwp'),
    ('hwp_sys_023', '차량운행일지', '27', 'hwp', 'DOC', 23, 'HaccpTemplates/hwp_sys_023/차량운행일지.hwp'),
    ('hwp_sys_024', '압축공기필터관리대장', '28', 'hwp', 'DOC', 24, 'HaccpTemplates/hwp_sys_024/압축공기필터관리대장.hwp'),
    ('hwp_sys_025', '회수관리일지', '28', 'hwp', 'DOC', 25, 'HaccpTemplates/hwp_sys_025/회수관리일지.hwp'),
    ('hwp_sys_026', '육안검사기준', '29', 'hwp', 'DOC', 26, 'HaccpTemplates/hwp_sys_026/육안검사기준.hwp'),
    ('hwp_sys_027', '육안검사일지', '30', 'hwp', 'DOC', 27, 'HaccpTemplates/hwp_sys_027/육안검사일지.hwp')
  ) AS v(tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, sort_no, form_path)
ON CONFLICT (tmpl_cd) DO UPDATE SET
    tmpl_nm     = EXCLUDED.tmpl_nm,
    mng_no      = EXCLUDED.mng_no,
    doc_kind    = EXCLUDED.doc_kind,
    category_cd = EXCLUDED.category_cd,
    impl_yn     = 'Y',
    use_yn      = 'Y',
    sort_no     = EXCLUDED.sort_no,
    form_path   = EXCLUDED.form_path,
    upd_id      = 'system',
    upd_dt      = now();

INSERT INTO tbl_company_template (co_cd, tmpl_cd, tmpl_nm_ovr, use_yn, sys_yn, cycle_cd, retention_month, form_path, ins_id, ins_dt)
SELECT c.co_cd, t.tmpl_cd, t.tmpl_nm, 'Y', 'sys', t.default_cycle_cd, t.default_retention_month, t.form_path, 'system', now()
  FROM tbl_company c
  JOIN tbl_template t ON t.tmpl_cd LIKE 'hwp_sys_%'
ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
    tmpl_nm_ovr = EXCLUDED.tmpl_nm_ovr,
    form_path   = EXCLUDED.form_path,
    sys_yn      = 'sys',
    use_yn      = 'Y',
    upd_id      = 'system',
    upd_dt      = now();

INSERT INTO tbl_company_template_file(co_cd, tmpl_cd, file_seq, file_nm, form_path, src_ty, ins_id)
SELECT ct.co_cd, ct.tmpl_cd, 1, regexp_replace(t.form_path, '^.*/', ''), t.form_path, 'sys', 'system'
  FROM tbl_company_template ct
  JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
 WHERE ct.tmpl_cd LIKE 'hwp_sys_%'
   AND COALESCE(t.form_path, '') <> ''
ON CONFLICT (co_cd, tmpl_cd, file_seq) DO UPDATE SET
    file_nm   = EXCLUDED.file_nm,
    form_path = EXCLUDED.form_path,
    src_ty    = 'sys',
    del_yn    = 'N';

UPDATE tbl_company_template ct
   SET default_file_idx = f.idx,
       current_file_idx = f.idx,
       form_path        = f.form_path,
       upd_id           = 'system',
       upd_dt           = now()
  FROM tbl_company_template_file f
 WHERE f.co_cd = ct.co_cd
   AND f.tmpl_cd = ct.tmpl_cd
   AND f.file_seq = 1
   AND f.src_ty = 'sys'
   AND ct.tmpl_cd LIKE 'hwp_sys_%';

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
    -- 구분 — sys:시스템제공, usr:사용자추가. 화면은 표시 전용이며 저장·수정 대상이 아니다
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
       -- 사용양식 관리는 새 시스템코드(hwp_sys_%)와 사용자추가만. HTML 화면용 옛 tmpl_* 는 숨긴다
       AND (
            ct.tmpl_cd LIKE 'hwp_sys_%'
         OR lower(CASE WHEN COALESCE(ct.sys_yn, 'sys') IN ('N', 'n', 'usr') THEN 'usr' ELSE 'sys' END) = 'usr'
       )
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_hwp_template_management_r_000(varchar, varchar, varchar) IS
  '사용양식 목록 — hwp_sys_NNN 시스템제공 + 사용자추가. 옛 kebab 시스템 행은 숨김. 미사용 포함';

SELECT tmpl_cd, tmpl_nm, sort_no, form_path
  FROM tbl_template
 WHERE tmpl_cd LIKE 'hwp_sys_%'
 ORDER BY sort_no, tmpl_cd;
