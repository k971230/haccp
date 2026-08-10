-- ============================================================
--  DDL 9 — 플랫폼 표준 시드 (템플릿 카탈로그 · 화면 · 공통코드)
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) 전역 카탈로그만 넣는다 — 업체 데이터(회사·사용자·메뉴·기준정보)는 업체 등록 SP가 복사 생성
--    2) 템플릿 42종 = 원본 양식 30종(impl_yn=Y, DB형 15 + rhwp 문서형 15)
--                    + 표준기준서 부속 카탈로그 12종(impl_yn=N, 이번 범위 화면 미개발)
--       원본 PDF는 31페이지지만 마지막 1장이 공백이라 실제 양식은 30종이다.
--       CCP 점검표는 냉장보관·금속검출 2장, 자체 검·교정 일지는 대상 3종으로 각각 분리했다
--    3) 재실행 안전 — 전부 ON CONFLICT DO UPDATE(업서트). idx는 IDENTITY라 값을 지정하지 않는다
--
--  회사코드 0000 = 플랫폼 예약 테넌트. 전 업체 공용 표준코드를 이 코드로 보관한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. tbl_template — 표준 템플릿 카탈로그 42종
--    doc_kind DB  = 전용 HTML 화면 + DB 저장 (반복·수치·자동판정)
--    doc_kind HWP = rhwp 문서작성형 (서술·사진·저빈도, 관리정보만 DB화)
-- ------------------------------------------------------------
INSERT INTO tbl_template
    (tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd, default_cycle_cd, default_retention_month, impl_yn, sort_no, ins_id)
VALUES
    -- [DB형 15종] 반복 기록·수치 입력·자동판정이 필요한 양식 (mng_no = 원본 PDF 기록관리 번호)
    ('CCP_COLD',      'CCP 냉장·냉동 보관 모니터링 일지',     '2-1',  'DB',  'CCP', 'ccp-cold-monitor',       'D', 24, 'Y',  2, 'system'),
    ('CCP_METAL',     'CCP 금속검출 모니터링 일지',           '2-2',  'DB',  'CCP', 'ccp-metal-monitor',      'D', 24, 'Y',  3, 'system'),
    ('CCP_VERIFY',    '중요관리점(CCP) 검증점검표',          '3',    'DB',  'CCP', 'ccp-verification-check', 'M', 24, 'Y',  4, 'system'),
    ('VERIFY_PLAN',   '연간 검증계획서',                     '4',    'DB',  'VER', 'annual-verification-plan','Y', 36, 'Y',  5, 'system'),
    ('DAILY_HYG',     '일일 위생 점검일지',                  '10',   'DB',  'HYG', 'daily-hygiene-check',    'D', 24, 'Y', 11, 'system'),
    ('PERSONAL_HYG',  '개인 위생관리 점검표',                '11',   'DB',  'HYG', 'personal-hygiene-check', 'D', 24, 'Y', 12, 'system'),
    ('AREA_HYG',      '작업장 환경위생관리 점검표',          '12',   'DB',  'HYG', 'area-hygiene-check',     'D', 24, 'Y', 13, 'system'),
    ('PEST',          '방충·방서 점검표',                    '13',   'DB',  'HYG', 'pest-control-check',     'W', 24, 'Y', 14, 'system'),
    ('FACILITY',      '시설·설비·처리도구 점검표',           '14',   'DB',  'FAC', 'facility-equipment-check','W', 24, 'Y', 15, 'system'),
    ('CALIB_TARGET',  '검·교정 대상',                        '15',   'DB',  'FAC', 'calibration-target-management','Y', 36, 'Y', 16, 'system'),
    ('WASTE',         '폐기물 처리 점검표',                  '18',   'DB',  'FAC', 'waste-disposal-check',   'M', 24, 'Y', 21, 'system'),
    ('INV_CHECK',     '입·출고 및 재고 점검표',              '19',   'DB',  'INV', 'inventory-check',        'M', 24, 'Y', 22, 'system'),
    ('RECV_INSP',     '입고검사 일지',                       '20',   'DB',  'INV', 'receiving-inspection',   'E', 24, 'Y', 23, 'system'),
    ('WATER',         '용수관리 점검표',                     '24',   'DB',  'HYG', 'water-management-check', 'W', 24, 'Y', 27, 'system'),
    ('PROCESS',       '공정관리 점검표',                     '26',   'DB',  'PRC', 'process-control-check',  'M', 24, 'Y', 29, 'system'),

    -- [rhwp 문서형 15종] 서술·사진 중심, 관리정보만 DB화하고 본문은 한글 원본 보관
    ('HANDOVER',      '업무 인수인계서',                     '1',    'HWP', 'DOC', NULL,         'E', 36, 'Y',  1, 'system'),
    ('VERIFY_CHECK',  '검증 점검표',                         '5',    'HWP', 'VER', NULL,         'E', 24, 'Y',  6, 'system'),
    ('VERIFY_REPORT', '검증결과 보고서',                     '6',    'HWP', 'VER', NULL,         'E', 24, 'Y',  7, 'system'),
    ('VERIFY_CA',     '검증 개선조치 결과보고서',            '7',    'HWP', 'VER', NULL,         'E', 24, 'Y',  8, 'system'),
    ('EDU_PLAN',      '연간 교육·훈련 계획서',               '8',    'HWP', 'EDU', 'edu-annual-plan',   'Y', 36, 'Y',  9, 'system'),
    ('EDU_LOG',       '교육일지',                            '9',    'HWP', 'EDU', 'edu-training-log',  'E', 24, 'Y', 10, 'system'),
    ('LAW_HEALTH',    '보건증관리',                          NULL,   'HWP', 'LAW', 'law-health-cert',       'E', 36, 'Y', 61, 'system'),
    ('LAW_MATERIAL',  '원료수불대장관리',                    NULL,   'HWP', 'LAW', 'law-material-ledger',   'M', 36, 'Y', 62, 'system'),
    ('LAW_BUILDING',  '건축물대장관리',                      NULL,   'HWP', 'LAW', 'law-building-ledger',   'E', 36, 'Y', 63, 'system'),
    ('LAW_PRODUCTION','생산대장관리',                        NULL,   'HWP', 'LAW', 'law-production-ledger', 'D', 36, 'Y', 64, 'system'),
    ('LAW_LICENSE',   '영업등록증관리',                      NULL,   'HWP', 'LAW', 'law-business-license',  'E', 36, 'Y', 65, 'system'),
    ('LAW_SELF_TEST', '자가품질검사관리',                    NULL,   'HWP', 'LAW', 'law-self-quality-test', 'M', 36, 'Y', 66, 'system'),
    ('LAW_CERT',      '수료증관리',                          NULL,   'HWP', 'LAW', 'law-completion-cert',   'E', 36, 'Y', 67, 'system'),
    ('CALIB_LOG_TEMP','자체 검·교정 일지(온도계)',           '16-1', 'HWP', 'FAC', NULL,         'Y', 24, 'Y', 17, 'system'),
    ('CALIB_LOG_WGT', '자체 검·교정 일지(저울·표준분동)',    '16-2', 'HWP', 'FAC', NULL,         'Y', 24, 'Y', 18, 'system'),
    ('CALIB_LOG_SCL', '자체 검·교정 일지(저울·표준저울)',    '16-3', 'HWP', 'FAC', NULL,         'Y', 24, 'Y', 19, 'system'),
    ('EQUIP_CARD',    '시설·설비 이력카드',                  '17',   'HWP', 'FAC', NULL,         'E', 36, 'Y', 20, 'system'),
    ('PROD_TEST',     '제품검사 성적서',                     '21',   'HWP', 'VER', 'test-product-report', 'M', 24, 'Y', 24, 'system'),
    ('SURFACE_TEST',  '표면오염도 검사 성적서',              '22',   'HWP', 'VER', 'test-surface-report', 'M', 24, 'Y', 25, 'system'),
    ('BAD_PRODUCT',   '부적합제품 관리 점검표',              '23',   'HWP', 'DOC', NULL,         'E', 24, 'Y', 26, 'system'),
    ('CLAIM',         '클레임 관리 일지',                    '25',   'HWP', 'DOC', NULL,         'E', 24, 'Y', 28, 'system'),
    ('VEHICLE_LOG',   '차량운행일지',                        '27',   'HWP', 'FAC', NULL,         'E', 24, 'Y', 30, 'system'),

    -- [카탈로그 등록 12종] 표준기준서에는 있으나 이번 범위에서 화면을 만들지 않는다(impl_yn=N)
    ('HAZARD_ANAL',   '위해요소 분석표',                     NULL,   'HWP', 'DOC', NULL,         'Y', 36, 'N', 41, 'system'),
    ('CCP_DECIDE',    'CCP 결정도',                          NULL,   'HWP', 'DOC', NULL,         'Y', 36, 'N', 42, 'system'),
    ('CCP_PLAN',      'CCP 관리계획표',                      NULL,   'HWP', 'DOC', NULL,         'Y', 36, 'N', 43, 'system'),
    ('FLOW_CHART',    '공정흐름도',                          NULL,   'HWP', 'DOC', NULL,         'Y', 36, 'N', 44, 'system'),
    ('LAYOUT',        '작업장 평면도',                       NULL,   'HWP', 'DOC', NULL,         'Y', 36, 'N', 45, 'system'),
    ('PRODUCT_SPEC',  '제품설명서',                          NULL,   'HWP', 'DOC', NULL,         'Y', 36, 'N', 46, 'system'),
    ('RAW_SPEC',      '원·부재료 설명서',                    NULL,   'HWP', 'DOC', NULL,         'Y', 36, 'N', 47, 'system'),
    ('PRE_REQ',       '선행요건 관리기준서',                 NULL,   'HWP', 'DOC', NULL,         'Y', 36, 'N', 48, 'system'),
    ('SUPPLIER_EVAL', '공급업체 평가표',                     NULL,   'HWP', 'VER', NULL,         'Y', 36, 'N', 49, 'system'),
    ('TRACE_DRILL',   '추적성 모의훈련 기록',                NULL,   'HWP', 'VER', NULL,         'Y', 36, 'N', 50, 'system'),
    ('INTERNAL_AUDIT','내부심사 계획 및 결과',               NULL,   'HWP', 'VER', NULL,         'Y', 36, 'N', 51, 'system'),
    ('ALLERGEN',      '알레르기 유발물질 관리',              NULL,   'HWP', 'HYG', NULL,         'Y', 36, 'N', 52, 'system')
ON CONFLICT (tmpl_cd) DO UPDATE SET
    tmpl_nm     = EXCLUDED.tmpl_nm,
    mng_no      = EXCLUDED.mng_no,
    doc_kind    = EXCLUDED.doc_kind,
    category_cd = EXCLUDED.category_cd,
    scrn_cd     = EXCLUDED.scrn_cd,
    impl_yn     = EXCLUDED.impl_yn,
    sort_no     = EXCLUDED.sort_no,
    upd_id      = 'system',
    upd_dt      = now();

-- 구현 양식 30종의 원본 HWP 상대 경로 — APP_FILE_ROOT/_template/{tmpl_cd}.hwp 에 읽기 전용으로 배치한다
-- 카탈로그 전용 12종은 원본이 없으므로 NULL을 유지한다
UPDATE tbl_template
   SET form_path = CASE
                       WHEN impl_yn = 'Y' THEN '_template/' || tmpl_cd || '.hwp'
                       ELSE NULL
                   END,
       upd_id = 'system',
       upd_dt = now();

-- ------------------------------------------------------------
-- 2. tbl_screen — 화면 마스터
--    화면 식별자 규칙: 역할 기반 kebab-case. FE screenRegistry 키와 문자 그대로 일치해야 한다
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, ins_id) VALUES
    -- TSK — 업무 시작점
    ('today-tasks', '오늘 할 일',                 'TSK', NULL,           10, 'system'),
    -- CCP — 중요관리점
    ('ccp-cold-monitor', '냉장·냉동 보관',             'CCP', 'CCP_COLD',    110, 'system'),
    ('ccp-metal-monitor', 'CCP 금속검출 모니터링',      'CCP', 'CCP_METAL',   120, 'system'),
    ('ccp-verification-check', 'CCP 검증점검표',         'CCP', 'CCP_VERIFY',  130, 'system'),
    ('annual-verification-plan', '연간 검증계획서',      'CCP', 'VERIFY_PLAN', 140, 'system'),
    ('ccp-generic-monitor', '공통 CCP 모니터링',         'CCP', NULL,          150, 'system'),
    ('ccp-heat-monitor', '가열·삶기 CCP',               'CCP', 'CCP_HEAT',    151, 'system'),
    ('ccp-wash-monitor', '세척 CCP',                    'CCP', 'CCP_WASH',    152, 'system'),
    ('ccp-sanitize-monitor', '소독·헹굼 CCP',           'CCP', 'CCP_SANITIZE',153, 'system'),
    ('ccp-filter-monitor', '여과 CCP',                  'CCP', 'CCP_FILTER',  154, 'system'),
    ('ccp-iqf-monitor', '급속냉동 CCP',                  'CCP', 'CCP_IQF',     155, 'system'),
    -- HYG — 위생관리
    ('daily-hygiene-check', '일일 위생 점검일지',        'HYG', 'DAILY_HYG',   210, 'system'),
    ('personal-hygiene-check', '개인 위생관리 점검표',  'HYG', 'PERSONAL_HYG',220, 'system'),
    ('area-hygiene-check', '작업장 환경위생 점검표',    'HYG', 'AREA_HYG',    230, 'system'),
    ('pest-control-check', '방충·방서 점검표',          'HYG', 'PEST',        240, 'system'),
    ('water-management-check', '용수관리 점검표',       'HYG', 'WATER',       250, 'system'),
    -- PRC — 공정관리
    ('process-control-check', '공정관리 점검표',        'PRC', 'PROCESS',     310, 'system'),
    -- FAC — 시설·설비
    ('facility-equipment-check', '시설·설비·처리도구 점검표', 'FAC', 'FACILITY',    410, 'system'),
    ('calibration-target-management', '검·교정 대상 점검표',   'FAC', 'CALIB_TARGET',420, 'system'),
    ('waste-disposal-check', '폐기물 처리 점검표',            'FAC', 'WASTE',       430, 'system'),
    -- INV — 입출고
    ('inventory-check', '입·출고 및 재고 점검표',        'INV', 'INV_CHECK',   510, 'system'),
    ('receiving-inspection', '입고검사 일지',             'INV', 'RECV_INSP',   520, 'system'),
    -- DOC — 문서·결재 (법적서류=그리드 첨부, 교육·개별 서류 leaf는 메뉴 비활성)
    ('hwp-document-editor', '문서 작성(한글 양식)',      'DOC', NULL,          610, 'system'),
    ('legal-document-upload', '법적서류',                'DOC', NULL,          615, 'system'),
    ('document-inbox', '문서함',                         'DOC', NULL,          620, 'system'),
    ('approval-inbox', '결재함',                         'DOC', NULL,          630, 'system'),
    ('corrective-action-management', '이탈·개선조치 관리','DOC', NULL,          640, 'system'),
    ('audit-export', '감사자료 출력',                    'DOC', NULL,          650, 'system'),
    -- BAS — 기준정보
    ('product-management', '제품 관리',                     'BAS', NULL,          710, 'system'),
    ('material-management', '원·부재료 관리',              'BAS', NULL,          720, 'system'),
    ('partner-management', '거래처 관리',                   'BAS', NULL,          730, 'system'),
    ('storage-management', '보관고 관리',                   'BAS', NULL,          740, 'system'),
    ('equipment-management', '시설·설비 관리',             'BAS', NULL,          750, 'system'),
    ('measuring-device-management', '계측기 관리',          'BAS', NULL,          760, 'system'),
    ('pest-device-management', '포충등·트랩 관리',          'BAS', NULL,          770, 'system'),
    ('vehicle-management', '차량 관리',                     'BAS', NULL,          780, 'system'),
    ('work-area-management', '작업장·구역 관리',            'BAS', NULL,          790, 'system'),
    -- SET — 일지설정 (사용양식 + CCP한계·결재선·작성주기·스마트일지유형)
    -- 범용 점검항목관리(template-check-item-management)는 문서별 admin으로 대체 — 시드 미등록
    ('hwp-template-management', '사용양식관리',             'SET', NULL,         1310, 'system'),
    ('ccp-limit-management', 'CCP 한계기준 관리',           'SET', NULL,         1330, 'system'),
    ('approval-line-management', '결재선 관리',             'SET', NULL,         1340, 'system'),
    ('schedule-cycle-management', '작성주기 관리',          'SET', NULL,         1350, 'system'),
    ('smart-diary-type-management', '스마트일지유형 관리',  'SET', NULL,         1360, 'system'),
    -- LAW — 개별 leaf는 migrate 35에서 use_yn=N (업무는 법적서류 그리드 첨부만)
    ('law-health-cert', '보건증관리',                       'LAW', 'LAW_HEALTH',  1010, 'system'),
    ('law-material-ledger', '원료수불대장관리',              'LAW', 'LAW_MATERIAL',1020, 'system'),
    ('law-building-ledger', '건축물대장관리',                'LAW', 'LAW_BUILDING',1030, 'system'),
    ('law-production-ledger', '생산대장관리',               'LAW', 'LAW_PRODUCTION',1040, 'system'),
    ('law-business-license', '영업등록증관리',              'LAW', 'LAW_LICENSE', 1050, 'system'),
    ('law-self-quality-test', '자가품질검사관리',           'LAW', 'LAW_SELF_TEST',1060, 'system'),
    ('law-completion-cert', '수료증관리',                    'LAW', 'LAW_CERT',    1070, 'system'),
    -- EDU — 개별 leaf는 migrate 35에서 use_yn=N (작성은 문서작성에 흡수)
    ('edu-annual-plan', '연간 교육·훈련 계획서',            'EDU', 'EDU_PLAN',    1110, 'system'),
    ('edu-training-log', '교육일지',                        'EDU', 'EDU_LOG',     1120, 'system'),
    -- TST — 성적서 (migrate 35에서 use_yn=N)
    ('test-product-report', '제품검사 성적서',              'TST', 'PROD_TEST',   1210, 'system'),
    ('test-surface-report', '표면오염도 검사 성적서',       'TST', 'SURFACE_TEST',1220, 'system'),
    -- SYS — 시스템
    ('company-management', '회사정보 관리',                 'SYS', NULL,          910, 'system'),
    ('user-management', '사용자 관리',                     'SYS', NULL,          920, 'system'),
    ('department-management', '부서 관리',                 'SYS', NULL,          930, 'system'),
    ('role-management', '권한그룹 관리',                   'SYS', NULL,          940, 'system'),
    ('menu-management', '메뉴 관리',                       'SYS', NULL,          950, 'system'),
    ('common-code-management', '공통코드 관리',            'SYS', NULL,          960, 'system'),
    ('login-history', '로그인 이력',                       'SYS', NULL,          970, 'system'),
    ('screen-usage-statistics', '화면 이용 통계',           'SYS', NULL,          980, 'system'),
    ('audit-log', '변경 감사 로그',                        'SYS', NULL,          990, 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm   = EXCLUDED.scrn_nm,
    module_cd = EXCLUDED.module_cd,
    tmpl_cd   = EXCLUDED.tmpl_cd,
    sort_no   = EXCLUDED.sort_no,
    upd_id    = 'system',
    upd_dt    = now();

-- ------------------------------------------------------------
-- 3. tbl_code — 플랫폼 표준 공통코드 (co_cd = 0000, sys_yn = Y)
--    sub_cd = '*' 행이 그룹 헤더. 업체는 이 코드를 수정·삭제할 수 없다
-- ------------------------------------------------------------
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, sys_yn, ins_id) VALUES
    -- 판정 표기 2종 — 양호/불량(O·X)과 적합/부적합(P·F)을 혼용하지 않는다
    ('0000', 'JUDGE_OX',     '*',        '판정(양호/불량)',        0, NULL, 'Y', 'system'),
    ('0000', 'JUDGE_OX',     'O',        '양호',                   1, NULL, 'Y', 'system'),
    ('0000', 'JUDGE_OX',     'X',        '불량',                   2, NULL, 'Y', 'system'),
    ('0000', 'JUDGE_PF',     '*',        '판정(적합/부적합)',      0, NULL, 'Y', 'system'),
    ('0000', 'JUDGE_PF',     'P',        '적합',                   1, NULL, 'Y', 'system'),
    ('0000', 'JUDGE_PF',     'F',        '부적합',                 2, NULL, 'Y', 'system'),
    -- 문서 상태 — tbl_document.status
    ('0000', 'DOC_STATUS',   '*',        '문서 상태',              0, NULL, 'Y', 'system'),
    ('0000', 'DOC_STATUS',   'WRK',      '작성중',                 1, NULL, 'Y', 'system'),
    ('0000', 'DOC_STATUS',   'TMP',      '임시저장(폐기)',         0, NULL, 'N', 'system'),
    ('0000', 'DOC_STATUS',   'REQ',      '검토요청',               2, NULL, 'Y', 'system'),
    ('0000', 'DOC_STATUS',   'REV',      '검토완료',               3, NULL, 'Y', 'system'),
    ('0000', 'DOC_STATUS',   'APV',      '승인완료',               4, NULL, 'Y', 'system'),
    ('0000', 'DOC_STATUS',   'RJT',      '반려',                   5, NULL, 'Y', 'system'),
    -- 작성주기 — tbl_schedule_rule.cycle_cd
    ('0000', 'CYCLE_CD',     '*',        '작성주기',               0, NULL, 'Y', 'system'),
    ('0000', 'CYCLE_CD',     'D',        '매일',                   1, NULL, 'Y', 'system'),
    ('0000', 'CYCLE_CD',     'W',        '매주',                   2, NULL, 'Y', 'system'),
    ('0000', 'CYCLE_CD',     'M',        '매월',                   3, NULL, 'Y', 'system'),
    ('0000', 'CYCLE_CD',     'Y',        '매년',                   4, NULL, 'Y', 'system'),
    ('0000', 'CYCLE_CD',     'E',        '수시',                   5, NULL, 'Y', 'system'),
    -- 법인구분 — tbl_company.co_gbn
    ('0000', 'CO_GBN',       '*',        '법인구분',               0, NULL, 'Y', 'system'),
    ('0000', 'CO_GBN',       '1',        '법인',                   1, NULL, 'Y', 'system'),
    ('0000', 'CO_GBN',       '2',        '개인',                   2, NULL, 'Y', 'system'),
    -- 보관유형 — tbl_product/tbl_material/tbl_storage
    ('0000', 'STORAGE_TYPE', '*',        '보관유형',               0, NULL, 'Y', 'system'),
    ('0000', 'STORAGE_TYPE', 'COLD',     '냉장',                   1, NULL, 'Y', 'system'),
    ('0000', 'STORAGE_TYPE', 'FROZEN',   '냉동',                   2, NULL, 'Y', 'system'),
    ('0000', 'STORAGE_TYPE', 'ROOM',     '상온',                   3, NULL, 'Y', 'system'),
    -- 원부재료 구분 — tbl_material.material_gbn
    ('0000', 'MATERIAL_GBN', '*',        '원부재료 구분',          0, NULL, 'Y', 'system'),
    ('0000', 'MATERIAL_GBN', 'MEAT',     '원료육',                 1, NULL, 'Y', 'system'),
    ('0000', 'MATERIAL_GBN', 'SUB',      '부재료',                 2, NULL, 'Y', 'system'),
    ('0000', 'MATERIAL_GBN', 'PACK',     '포장재',                 3, NULL, 'Y', 'system'),
    -- 거래처 구분 — tbl_partner.partner_gbn
    ('0000', 'PARTNER_GBN',  '*',        '거래처 구분',            0, NULL, 'Y', 'system'),
    ('0000', 'PARTNER_GBN',  'SUPPLY',   '공급처',                 1, NULL, 'Y', 'system'),
    ('0000', 'PARTNER_GBN',  'SALES',    '판매처',                 2, NULL, 'Y', 'system'),
    ('0000', 'PARTNER_GBN',  'WASTE',    '폐기물 수거업체',        3, NULL, 'Y', 'system'),
    ('0000', 'PARTNER_GBN',  'LAB',      '검사기관',               4, NULL, 'Y', 'system'),
    -- 계측기 유형 — tbl_measuring_device.device_type
    ('0000', 'DEVICE_TYPE',  '*',        '계측기 유형',            0, NULL, 'Y', 'system'),
    ('0000', 'DEVICE_TYPE',  'SCALE',    '저울',                   1, 'PCT', 'Y', 'system'),
    ('0000', 'DEVICE_TYPE',  'THERMO',   '온도계',                 2, 'DEG', 'Y', 'system'),
    ('0000', 'DEVICE_TYPE',  'TIMER',    '타이머',                 3, 'SEC', 'Y', 'system'),
    ('0000', 'DEVICE_TYPE',  'LUX',      '조도계',                 4, NULL,  'Y', 'system'),
    ('0000', 'DEVICE_TYPE',  'RECORDER', '자동온도기록장치',       5, 'DEG', 'Y', 'system'),
    ('0000', 'DEVICE_TYPE',  'STANDARD', '표준기',                 6, NULL,  'Y', 'system'),
    -- 방충방서 설비 유형 — tbl_pest_device.pest_type
    ('0000', 'PEST_TYPE',    '*',        '방충방서 설비 유형',     0, NULL, 'Y', 'system'),
    ('0000', 'PEST_TYPE',    'LAMP',     '포충등',                 1, NULL, 'Y', 'system'),
    ('0000', 'PEST_TYPE',    'ROACH',    '바퀴트랩',               2, NULL, 'Y', 'system'),
    ('0000', 'PEST_TYPE',    'RAT',      '쥐트랩',                 3, NULL, 'Y', 'system'),
    -- 작업장 위생구분 — tbl_work_area.area_gbn
    ('0000', 'AREA_GBN',     '*',        '작업장 위생구분',        0, NULL, 'Y', 'system'),
    ('0000', 'AREA_GBN',     'CLEAN',    '청결구역',               1, NULL, 'Y', 'system'),
    ('0000', 'AREA_GBN',     'SEMI',     '준청결구역',             2, NULL, 'Y', 'system'),
    ('0000', 'AREA_GBN',     'GENERAL',  '일반구역',               3, NULL, 'Y', 'system'),
    -- 개선조치 상태 — tbl_corrective_action.status
    ('0000', 'CA_STATUS',    '*',        '개선조치 상태',          0, NULL, 'Y', 'system'),
    ('0000', 'CA_STATUS',    'OPEN',     '미조치',                 1, NULL, 'Y', 'system'),
    ('0000', 'CA_STATUS',    'ING',      '조치중',                 2, NULL, 'Y', 'system'),
    ('0000', 'CA_STATUS',    'DONE',     '완료',                   3, NULL, 'Y', 'system'),
    -- 폐기 구분 — tbl_waste_check_row.waste_gbn
    ('0000', 'WASTE_GBN',    '*',        '폐기 구분',              0, NULL, 'Y', 'system'),
    ('0000', 'WASTE_GBN',    'BAD',      '부적합품',               1, NULL, 'Y', 'system'),
    ('0000', 'WASTE_GBN',    'WASTE',    '일반 폐기물',            2, NULL, 'Y', 'system'),
    ('0000', 'WASTE_GBN',    'EXPIRE',   '기한경과',               3, NULL, 'Y', 'system'),
    -- 알림 유형 — tbl_user_noti_pref.noti_type_cd / tbl_notification.noti_type_cd
    ('0000', 'NOTI_TYPE',    '*',        '알림 유형',              0, NULL, 'Y', 'system'),
    ('0000', 'NOTI_TYPE',    'DOC_DUE',  '작성기한 임박',          1, NULL, 'Y', 'system'),
    ('0000', 'NOTI_TYPE',    'DOC_LATE', '문서 미작성',            2, NULL, 'Y', 'system'),
    ('0000', 'NOTI_TYPE',    'APPROVAL', '결재 요청',              3, NULL, 'Y', 'system'),
    ('0000', 'NOTI_TYPE',    'REJECT',   '결재 반려',              4, NULL, 'Y', 'system'),
    ('0000', 'NOTI_TYPE',    'CA_DUE',   '개선조치 기한',          5, NULL, 'Y', 'system'),
    ('0000', 'NOTI_TYPE',    'CALIB_DUE','검·교정 도래',           6, NULL, 'Y', 'system'),
    ('0000', 'NOTI_TYPE',    'EXPIRE',   '소비기한 임박',          7, NULL, 'Y', 'system'),
    -- 결재 역할 — tbl_approval_line_step.role_cd
    ('0000', 'APPR_ROLE',    '*',        '결재 역할',              0, NULL, 'Y', 'system'),
    ('0000', 'APPR_ROLE',    'WRITE',    '작성자',                 1, NULL, 'Y', 'system'),
    ('0000', 'APPR_ROLE',    'REVIEW',   '검토자',                 2, NULL, 'Y', 'system'),
    ('0000', 'APPR_ROLE',    'APPROVE',  '승인자',                 3, NULL, 'Y', 'system'),
    -- 결재 행위 — DocumentApprovalToolbar 버튼 라벨
    ('0000', 'APPR_ACTION',  '*',        '결재 행위',              0, NULL, 'Y', 'system'),
    ('0000', 'APPR_ACTION',  'REQUEST',  '상신',                   1, NULL, 'Y', 'system'),
    ('0000', 'APPR_ACTION',  'REVIEW',   '검토완료',               2, NULL, 'Y', 'system'),
    ('0000', 'APPR_ACTION',  'APPROVE',  '승인',                   3, NULL, 'Y', 'system'),
    ('0000', 'APPR_ACTION',  'REJECT',   '반려',                   4, NULL, 'Y', 'system'),
    ('0000', 'APPR_ACTION',  'CANCEL',   '상신취소',               5, NULL, 'Y', 'system'),
    -- 결재 결과 — tbl_document_approval.result_cd
    ('0000', 'APPR_RESULT',  '*',        '결재 결과',              0, NULL, 'Y', 'system'),
    ('0000', 'APPR_RESULT',  'W',        '대기',                   1, NULL, 'Y', 'system'),
    ('0000', 'APPR_RESULT',  'A',        '승인',                   2, NULL, 'Y', 'system'),
    ('0000', 'APPR_RESULT',  'R',        '반려',                   3, NULL, 'Y', 'system'),
    -- CCP 한계기준 유형 — tbl_ccp_limit.limit_type
    ('0000', 'LIMIT_TYPE',   '*',        'CCP 한계기준 유형',      0, NULL, 'Y', 'system'),
    ('0000', 'LIMIT_TYPE',   'TEMP_RANGE','온도 범위',             1, NULL, 'Y', 'system'),
    ('0000', 'LIMIT_TYPE',   'TEMP_MAX', '온도 이하',              2, NULL, 'Y', 'system'),
    ('0000', 'LIMIT_TYPE',   'TEMP_MIN', '온도 이상',              3, NULL, 'Y', 'system'),
    ('0000', 'LIMIT_TYPE',   'METAL',    '금속검출',               4, NULL, 'Y', 'system')
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
    code_nm = EXCLUDED.code_nm,
    sort_no = EXCLUDED.sort_no,
    ref1    = EXCLUDED.ref1,
    sys_yn  = EXCLUDED.sys_yn,
    upd_id  = 'system',
    upd_dt  = now();
