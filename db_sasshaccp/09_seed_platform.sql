-- ============================================================
--  DDL 9 — 플랫폼 표준 시드 (템플릿 카탈로그 · 화면 · 공통코드)
--
--  개발자: 박승우
--  일자: 2026-08-19
--  코멘트:
--    1) 전역 카탈로그만 넣는다 — 업체 데이터(회사·사용자·메뉴·기준정보)는 업체 등록 SP가 복사 생성
--    2) 신규 설치 정본 — HTML html_sys_001~012, HWP hwp_sys_001~038
--       사용양식 관리에 보이는 시스템 HWP 는 001~027 이다. 028~038 은 메뉴용이며 목록에서 숨긴다
--    3) 재실행 안전 — 전부 ON CONFLICT DO UPDATE(업서트). idx는 IDENTITY라 값을 지정하지 않는다
--
--  회사코드 0000 = 플랫폼 예약 테넌트. 전 업체 공용 표준코드를 이 코드로 보관한다
--  운영 DB(이미 94 적용)에는 이 파일을 다시 돌리지 않는다. 50~94 도 재실행하지 않는다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. tbl_template — html_sys_001~012 + hwp_sys_001~038
--    doc_kind html = 전용 HTML 화면 + DB 저장 (반복·수치·자동판정)
--    doc_kind hwp  = rhwp 문서작성형 (서술·사진·저빈도, 관리정보만 DB화)
-- ------------------------------------------------------------
INSERT INTO tbl_template
    (tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd, default_cycle_cd, default_retention_month, impl_yn, sort_no, ins_id)
VALUES
    -- HTML 전용 화면
    ('html_sys_001', '일반위생관리 및 공정점검표',       '1',   'html','HYG', 'hygiene-process-check',         'D', 24, 'Y', 101, 'system'),
    ('html_sys_002', 'CCP 금속검출 모니터링 일지',       '2-2', 'html','CCP', 'ccp-metal-monitor',             'D', 24, 'Y', 102, 'system'),
    ('html_sys_003', '가열 모니터링 일지',               NULL,  'html','CCP', 'ccp-heat-monitor',              'D', 24, 'Y', 103, 'system'),
    ('html_sys_004', '멸균 모니터링 일지',               NULL,  'html','CCP', 'ccp-sanitize-monitor',          'D', 24, 'Y', 104, 'system'),
    ('html_sys_005', '여과 모니터링 일지',               NULL,  'html','CCP', 'ccp-filter-monitor',            'D', 24, 'Y', 105, 'system'),
    ('html_sys_006', '중요관리점(CCP) 검증점검표',        '3',   'html','CCP', 'ccp-verification-check',        'M', 24, 'Y', 106, 'system'),
    ('html_sys_007', '일일 위생 점검일지',                '10',  'html','HYG', 'daily-hygiene-check',           'D', 24, 'Y', 107, 'system'),
    ('html_sys_008', '방충·방서 점검표',                  '13',  'html','HYG', 'pest-control-check',            'W', 24, 'Y', 108, 'system'),
    ('html_sys_009', '시설·설비·처리도구 점검표',         '14',  'html','FAC', 'facility-equipment-check',      'W', 24, 'Y', 109, 'system'),
    ('html_sys_010', '검·교정 대상',                      '15',  'html','FAC', 'calibration-target-management', 'Y', 36, 'Y', 110, 'system'),
    ('html_sys_011', '보건증관리',                        NULL,  'html','LAW', 'health-cert-record',            'E', 36, 'Y', 111, 'system'),
    ('html_sys_012', 'CCP 냉장·냉동 보관 모니터링 일지', '2-1', 'html','CCP', 'ccp-cold-monitor',              'D', 24, 'Y', 112, 'system'),

    -- HWP 시스템 001~027 (사용양식 목록)
    ('hwp_sys_001', '외부인출입기록부',           '00', 'hwp', 'DOC', 'visitor-log',           'E', 36, 'Y',  1, 'system'),
    ('hwp_sys_002', '업무인수인계서',             '01', 'hwp', 'DOC', 'handover-hwp',          'E', 36, 'Y',  2, 'system'),
    ('hwp_sys_003', '연간검증계획서',             '04', 'hwp', 'VER', 'verify-plan-hwp',       'Y', 36, 'Y',  3, 'system'),
    ('hwp_sys_004', '검증점검표',                 '05', 'hwp', 'VER', 'verify-check-hwp',      'E', 24, 'Y',  4, 'system'),
    ('hwp_sys_005', '검증결과보고서',             '06', 'hwp', 'VER', 'verify-report-hwp',     'E', 24, 'Y',  5, 'system'),
    ('hwp_sys_006', '검증개선조치결과보고서',     '07', 'hwp', 'VER', 'verify-ca-hwp',         'E', 24, 'Y',  6, 'system'),
    ('hwp_sys_007', '연간교육·훈련계획서',        '08', 'hwp', 'EDU', 'edu-plan-hwp',          'Y', 36, 'Y',  7, 'system'),
    ('hwp_sys_008', '교육일지',                   '09', 'hwp', 'EDU', 'edu-log-hwp',           'E', 24, 'Y',  8, 'system'),
    ('hwp_sys_009', '개인위생관리점검표',         '11', 'hwp', 'HYG', 'personal-hyg-hwp',      'D', 24, 'Y',  9, 'system'),
    ('hwp_sys_010', '작업장위생관리점검표',       '12', 'hwp', 'HYG', 'area-hyg-hwp',          'D', 24, 'Y', 10, 'system'),
    ('hwp_sys_011', '방충방서점검표',             '13', 'hwp', 'HYG', NULL,                    'W', 24, 'Y', 11, 'system'),
    ('hwp_sys_012', '시설설비처리도구점검표',     '14', 'hwp', 'FAC', NULL,                    'W', 24, 'Y', 12, 'system'),
    ('hwp_sys_013', '검교정대상',                 '15', 'hwp', 'FAC', NULL,                    'Y', 36, 'Y', 13, 'system'),
    ('hwp_sys_014', '자체검교정일지',             '16', 'hwp', 'FAC', 'calib-self-hwp',        'Y', 24, 'Y', 14, 'system'),
    ('hwp_sys_015', '폐기물처리점검표',           '18', 'hwp', 'FAC', 'waste-hwp',             'M', 24, 'Y', 15, 'system'),
    ('hwp_sys_016', '입출고및재고점검표',         '19', 'hwp', 'INV', 'inventory-hwp',         'M', 24, 'Y', 16, 'system'),
    ('hwp_sys_017', '입고검사일지',               '20', 'hwp', 'INV', 'receiving-insp-hwp',    'E', 24, 'Y', 17, 'system'),
    ('hwp_sys_018', '제품검사성적서',             '21', 'hwp', 'VER', 'prod-test-hwp',         'M', 24, 'Y', 18, 'system'),
    ('hwp_sys_019', '표면오염도검사성적서',       '22', 'hwp', 'VER', 'surface-test-hwp',      'M', 24, 'Y', 19, 'system'),
    ('hwp_sys_020', '부적합제품관리점검표',       '23', 'hwp', 'DOC', 'bad-product-hwp',       'E', 24, 'Y', 20, 'system'),
    ('hwp_sys_021', '용수관리_점검표',            '24', 'hwp', 'HYG', 'water-hwp',             'W', 24, 'Y', 21, 'system'),
    ('hwp_sys_022', '소비자불만관리일지',         '25', 'hwp', 'DOC', 'claim-hwp',             'E', 24, 'Y', 22, 'system'),
    ('hwp_sys_023', '차량운행일지',               '27', 'hwp', 'FAC', 'vehicle-hwp',           'E', 24, 'Y', 23, 'system'),
    ('hwp_sys_024', '압축공기필터관리대장',       '28', 'hwp', 'FAC', NULL,                    'E', 24, 'Y', 24, 'system'),
    ('hwp_sys_025', '회수관리일지',               '28', 'hwp', 'DOC', 'recall-hwp',            'E', 24, 'Y', 25, 'system'),
    ('hwp_sys_026', '육안검사기준',               '29', 'hwp', 'HYG', 'visual-insp-standard',  'E', 24, 'Y', 26, 'system'),
    ('hwp_sys_027', '육안검사일지',               '30', 'hwp', 'HYG', NULL,                    'E', 24, 'Y', 27, 'system'),

    -- HWP 028~038 (메뉴 유지 · 사용양식 목록 숨김)
    ('hwp_sys_028', '공정관리 점검표',             '26', 'hwp', 'PRC', 'process-hwp',            'M', 24, 'Y', 128, 'system'),
    ('hwp_sys_029', '부자재입고검수점검표',         NULL, 'hwp', 'INV', 'submaterial-recv-hwp',   'E', 24, 'Y', 129, 'system'),
    ('hwp_sys_030', '외부검교정기록부',             NULL, 'hwp', 'FAC', 'calib-ext-hwp',          'Y', 24, 'Y', 130, 'system'),
    ('hwp_sys_031', '제품출고관리일지',             NULL, 'hwp', 'INV', 'shipment-log-hwp',       'E', 24, 'Y', 131, 'system'),
    ('hwp_sys_032', '실시상황평가표',               NULL, 'hwp', 'VER', 'eval-hwp',               'Y', 36, 'Y', 132, 'system'),
    ('hwp_sys_033', '원료수불대장관리',             NULL, 'hwp', 'LAW', 'law-material-ledger',    'M', 36, 'Y', 133, 'system'),
    ('hwp_sys_034', '건축물대장관리',               NULL, 'hwp', 'LAW', 'law-building-ledger',    'E', 36, 'Y', 134, 'system'),
    ('hwp_sys_035', '생산대장관리',                 NULL, 'hwp', 'LAW', 'law-production-ledger',  'D', 36, 'Y', 135, 'system'),
    ('hwp_sys_036', '영업등록증관리',               NULL, 'hwp', 'LAW', 'law-business-license',   'E', 36, 'Y', 136, 'system'),
    ('hwp_sys_037', '자가품질검사관리',             NULL, 'hwp', 'LAW', 'law-self-quality-test',  'M', 36, 'Y', 137, 'system'),
    ('hwp_sys_038', '수료증관리',                   NULL, 'hwp', 'LAW', 'law-completion-cert',    'E', 36, 'Y', 138, 'system')
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

-- hwp 양식의 원본 상대 경로 — APP_FILE_ROOT/HaccpTemplates/{tmpl_cd}/{파일명}
-- html 양식은 물리 원본이 없으므로 NULL을 유지한다
UPDATE tbl_template
   SET form_path = CASE tmpl_cd
                       WHEN 'hwp_sys_001' THEN 'HaccpTemplates/hwp_sys_001/외부인출입기록부.hwp'
                       WHEN 'hwp_sys_002' THEN 'HaccpTemplates/hwp_sys_002/업무인수인계서.hwp'
                       WHEN 'hwp_sys_003' THEN 'HaccpTemplates/hwp_sys_003/연간검증계획서.hwp'
                       WHEN 'hwp_sys_004' THEN 'HaccpTemplates/hwp_sys_004/검증점검표.hwp'
                       WHEN 'hwp_sys_005' THEN 'HaccpTemplates/hwp_sys_005/검증결과보고서.hwp'
                       WHEN 'hwp_sys_006' THEN 'HaccpTemplates/hwp_sys_006/검증개선조치결과보고서.hwp'
                       WHEN 'hwp_sys_007' THEN 'HaccpTemplates/hwp_sys_007/연간교육·훈련계획서.hwp'
                       WHEN 'hwp_sys_008' THEN 'HaccpTemplates/hwp_sys_008/교육일지.hwp'
                       WHEN 'hwp_sys_009' THEN 'HaccpTemplates/hwp_sys_009/개인위생관리점검표.hwp'
                       WHEN 'hwp_sys_010' THEN 'HaccpTemplates/hwp_sys_010/작업장위생관리점검표.hwp'
                       WHEN 'hwp_sys_011' THEN 'HaccpTemplates/hwp_sys_011/방충방서점검표.hwp'
                       WHEN 'hwp_sys_012' THEN 'HaccpTemplates/hwp_sys_012/시설설비처리도구점검표.hwp'
                       WHEN 'hwp_sys_013' THEN 'HaccpTemplates/hwp_sys_013/검교정대상.hwp'
                       WHEN 'hwp_sys_014' THEN 'HaccpTemplates/hwp_sys_014/자체검교정일지.hwp'
                       WHEN 'hwp_sys_015' THEN 'HaccpTemplates/hwp_sys_015/폐기물처리점검표.hwp'
                       WHEN 'hwp_sys_016' THEN 'HaccpTemplates/hwp_sys_016/입출고및재고점검표.hwp'
                       WHEN 'hwp_sys_017' THEN 'HaccpTemplates/hwp_sys_017/입고검사일지.hwp'
                       WHEN 'hwp_sys_018' THEN 'HaccpTemplates/hwp_sys_018/제품검사성적서.hwp'
                       WHEN 'hwp_sys_019' THEN 'HaccpTemplates/hwp_sys_019/표면오염도검사성적서.hwp'
                       WHEN 'hwp_sys_020' THEN 'HaccpTemplates/hwp_sys_020/부적합제품관리점검표.hwp'
                       WHEN 'hwp_sys_021' THEN 'HaccpTemplates/hwp_sys_021/용수관리_점검표.hwp'
                       WHEN 'hwp_sys_022' THEN 'HaccpTemplates/hwp_sys_022/소비자불만관리일지.hwp'
                       WHEN 'hwp_sys_023' THEN 'HaccpTemplates/hwp_sys_023/차량운행일지.hwp'
                       WHEN 'hwp_sys_024' THEN 'HaccpTemplates/hwp_sys_024/압축공기필터관리대장.hwp'
                       WHEN 'hwp_sys_025' THEN 'HaccpTemplates/hwp_sys_025/회수관리일지.hwp'
                       WHEN 'hwp_sys_026' THEN 'HaccpTemplates/hwp_sys_026/육안검사기준.hwp'
                       WHEN 'hwp_sys_027' THEN 'HaccpTemplates/hwp_sys_027/육안검사일지.hwp'
                       WHEN 'hwp_sys_028' THEN 'HaccpTemplates/hwp_sys_028/공정관리_점검표.hwp'
                       WHEN 'hwp_sys_029' THEN 'HaccpTemplates/hwp_sys_029/부자재입고검수점검표.hwp'
                       WHEN 'hwp_sys_030' THEN 'HaccpTemplates/hwp_sys_030/외부 검교정기록부.hwp'
                       WHEN 'hwp_sys_031' THEN 'HaccpTemplates/hwp_sys_031/제품출고관리일지.hwp'
                       WHEN 'hwp_sys_032' THEN 'HaccpTemplates/hwp_sys_032/실시상황평가표.hwp'
                       WHEN 'hwp_sys_033' THEN 'HaccpTemplates/hwp_sys_033/LAW_MATERIAL.hwp'
                       WHEN 'hwp_sys_034' THEN 'HaccpTemplates/hwp_sys_034/LAW_BUILDING.hwp'
                       WHEN 'hwp_sys_035' THEN 'HaccpTemplates/hwp_sys_035/LAW_PRODUCTION.hwp'
                       WHEN 'hwp_sys_036' THEN 'HaccpTemplates/hwp_sys_036/LAW_LICENSE.hwp'
                       WHEN 'hwp_sys_037' THEN 'HaccpTemplates/hwp_sys_037/LAW_SELF_TEST.hwp'
                       WHEN 'hwp_sys_038' THEN 'HaccpTemplates/hwp_sys_038/LAW_CERT.hwp'
                       ELSE NULL
                   END,
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd LIKE 'html_sys_%' OR tmpl_cd LIKE 'hwp_sys_%';

-- ------------------------------------------------------------
-- 2. tbl_screen — 화면 마스터
--    화면 식별자 규칙: 역할 기반 kebab-case. FE screenRegistry 키와 문자 그대로 일치해야 한다
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, ins_id) VALUES
    -- TSK — 업무 시작점
    ('today-tasks', '오늘 할 일',                 'TSK', NULL,           10, 'system'),
    -- CCP — 중요관리점
    ('ccp-cold-monitor', '냉장·냉동 보관',             'CCP', 'html_sys_012',    110, 'system'),
    ('ccp-metal-monitor', 'CCP 금속검출 모니터링',      'CCP', 'html_sys_002',    120, 'system'),
    ('ccp-verification-check', 'CCP 검증점검표',         'CCP', 'html_sys_006',    130, 'system'),
    ('annual-verification-plan', '연간 검증계획서',      'CCP', 'hwp_sys_003',     140, 'system'),
    ('ccp-generic-monitor', '공통 CCP 모니터링',         'CCP', NULL,          150, 'system'),
    ('ccp-heat-monitor', '가열·삶기 CCP',               'CCP', 'html_sys_003',    151, 'system'),
    ('ccp-wash-monitor', '세척 CCP',                    'CCP', 'CCP_WASH',    152, 'system'),
    ('ccp-sanitize-monitor', '소독·헹굼 CCP',           'CCP', 'html_sys_004',    153, 'system'),
    ('ccp-filter-monitor', '여과 CCP',                  'CCP', 'html_sys_005',    154, 'system'),
    ('ccp-iqf-monitor', '급속냉동 CCP',                  'CCP', 'CCP_IQF',     155, 'system'),
    -- HYG — 위생관리
    ('daily-hygiene-check', '일일 위생 점검일지',        'HYG', 'html_sys_007',   210, 'system'),
    ('hygiene-process-check', '일반위생관리 및 공정점검표', 'HYG', 'html_sys_001', 211, 'system'),
    ('hyg-process-template', '일반위생·공정점검 양식관리', 'SET', 'html_sys_001', 1311, 'system'),
    ('ccp-verify-template', '중요관리점(CCP) 검증점검표', 'SET', 'html_sys_006', 1312, 'system'),
    ('ccp-pkg-template', '중요관리점(CCP-1B) 모니터링일지', 'SET', NULL, 1313, 'system'),
    ('ccp-htg-template', '중요관리점(CCP-2B) 모니터링일지', 'SET', NULL, 1314, 'system'),
    ('ccp-mtl-template', '중요관리점(CCP-3P) 모니터링일지', 'SET', NULL, 1315, 'system'),
    ('personal-hygiene-check', '개인 위생관리 점검표',  'HYG', 'hwp_sys_009',    220, 'system'),
    ('area-hygiene-check', '작업장 환경위생 점검표',    'HYG', 'hwp_sys_010',    230, 'system'),
    ('pest-control-check', '방충·방서 점검표',          'HYG', 'html_sys_008',   240, 'system'),
    ('water-management-check', '용수관리 점검표',       'HYG', 'hwp_sys_021',    250, 'system'),
    -- PRC — 공정관리
    ('process-control-check', '공정관리 점검표',        'PRC', 'hwp_sys_028',     310, 'system'),
    ('process-hwp', '공정관리점검표',                   'PRC', 'hwp_sys_028',     311, 'system'),
    -- FAC — 시설·설비
    ('facility-equipment-check', '시설·설비·처리도구 점검표', 'FAC', 'html_sys_009',    410, 'system'),
    ('calibration-target-management', '검·교정 대상 점검표',   'FAC', 'html_sys_010',    420, 'system'),
    ('waste-disposal-check', '폐기물 처리 점검표',            'FAC', 'hwp_sys_015',       430, 'system'),
    -- INV — 입출고
    ('inventory-check', '입·출고 및 재고 점검표',        'INV', 'hwp_sys_016',   510, 'system'),
    ('receiving-inspection', '입고검사 일지',             'INV', 'hwp_sys_017',   520, 'system'),
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
    ('schedule-cycle-management', '작성 문서 관리',         'SET', NULL,         1350, 'system'),
    ('smart-diary-type-management', '스마트일지유형 관리',  'SET', NULL,         1360, 'system'),
    -- LAW — 개별 leaf는 migrate 35에서 use_yn=N (업무는 법적서류 그리드 첨부만)
    ('law-health-cert', '보건증관리',                       'LAW', 'html_sys_011',  1010, 'system'),
    ('law-material-ledger', '원료수불대장관리',              'LAW', 'hwp_sys_033',    1020, 'system'),
    ('law-building-ledger', '건축물대장관리',                'LAW', 'hwp_sys_034',    1030, 'system'),
    ('law-production-ledger', '생산대장관리',               'LAW', 'hwp_sys_035',    1040, 'system'),
    ('law-business-license', '영업등록증관리',              'LAW', 'hwp_sys_036',    1050, 'system'),
    ('law-self-quality-test', '자가품질검사관리',           'LAW', 'hwp_sys_037',    1060, 'system'),
    ('law-completion-cert', '수료증관리',                    'LAW', 'hwp_sys_038',    1070, 'system'),
    -- EDU — 개별 leaf는 migrate 35에서 use_yn=N (작성은 문서작성에 흡수)
    ('edu-annual-plan', '연간 교육·훈련 계획서',            'EDU', 'hwp_sys_007',    1110, 'system'),
    ('edu-training-log', '교육일지',                        'EDU', 'hwp_sys_008',    1120, 'system'),
    -- TST — 성적서 (migrate 35에서 use_yn=N)
    ('test-product-report', '제품검사 성적서',              'TST', 'hwp_sys_018',   1210, 'system'),
    ('test-surface-report', '표면오염도 검사 성적서',       'TST', 'hwp_sys_019',   1220, 'system'),
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
    -- 작성주기 — tbl_schedule_rule.cycle_cd. E는 예정일을 만들지 않는 비정기
    ('0000', 'CYCLE_CD',     '*',        '작성주기',               0, NULL, 'Y', 'system'),
    ('0000', 'CYCLE_CD',     'D',        '매일',                   1, NULL, 'Y', 'system'),
    ('0000', 'CYCLE_CD',     'W',        '매주',                   2, NULL, 'Y', 'system'),
    ('0000', 'CYCLE_CD',     'M',        '매월',                   3, NULL, 'Y', 'system'),
    ('0000', 'CYCLE_CD',     'Q',        '분기',                   4, NULL, 'Y', 'system'),
    ('0000', 'CYCLE_CD',     'H',        '반기',                   5, NULL, 'Y', 'system'),
    ('0000', 'CYCLE_CD',     'Y',        '매년',                   6, NULL, 'Y', 'system'),
    ('0000', 'CYCLE_CD',     'E',        '비정기',                 7, NULL, 'Y', 'system'),
    ('0000', 'sys-yn',       '*',        '시스템유무',             0, NULL, 'Y', 'system'),
    ('0000', 'sys-yn',       'sys',      '시스템',                 1, NULL, 'Y', 'system'),
    ('0000', 'sys-yn',       'usr',      '사용자',                 2, NULL, 'Y', 'system'),
    ('0000', 'tmpl-ty',      '*',        '양식타입',               0, NULL, 'Y', 'system'),
    ('0000', 'tmpl-ty',      'html',     'HTML',                   1, NULL, 'Y', 'system'),
    ('0000', 'tmpl-ty',      'hwp',      'HWP',                    2, NULL, 'Y', 'system'),
    ('0000', 'use-yn',       '*',        '사용여부',               0, NULL, 'Y', 'system'),
    ('0000', 'use-yn',       'y',        '사용',                   1, NULL, 'Y', 'system'),
    ('0000', 'use-yn',       'n',        '미사용',                 2, NULL, 'Y', 'system'),
    -- 로그인 결과 — tbl_login_log.result_cd
    ('0000', 'login-result', '*',        '로그인 결과',            0, NULL, 'Y', 'system'),
    ('0000', 'login-result', 'S',        '성공',                   1, NULL, 'Y', 'system'),
    ('0000', 'login-result', 'F',        '실패',                   2, NULL, 'Y', 'system'),
    ('0000', 'login-result', 'L',        '잠금',                   3, NULL, 'Y', 'system'),
    -- 감사 행위 — tbl_audit_log.action_cd
    ('0000', 'audit-result', '*',        '감사 행위',              0, NULL, 'Y', 'system'),
    ('0000', 'audit-result', 'I',        '등록',                   1, NULL, 'Y', 'system'),
    ('0000', 'audit-result', 'U',        '수정',                   2, NULL, 'Y', 'system'),
    ('0000', 'audit-result', 'D',        '삭제',                   3, NULL, 'Y', 'system'),
    ('0000', 'audit-result', 'APV',      '승인',                   4, NULL, 'Y', 'system'),
    ('0000', 'audit-result', 'RJT',      '반려',                   5, NULL, 'Y', 'system'),
    ('0000', 'audit-result', 'JUDGE_MOD','판정 수동변경',          6, NULL, 'Y', 'system'),
    ('0000', 'audit-result', 'CO_SWITCH','업체 전환',              7, NULL, 'Y', 'system'),
    -- 감사 대상 메뉴 — sub_cd=tbl_nm, ref1=scrn_cd
    ('0000', 'audit-target', '*',        '감사 대상 메뉴',         0, NULL, 'Y', 'system'),
    ('0000', 'audit-target', 'tbl_document',      '문서함',        1, 'document-inbox', 'Y', 'system'),
    ('0000', 'audit-target', 'tbl_document_file', '문서 파일',     2, 'document-inbox', 'Y', 'system'),
    ('0000', 'audit-target', 'tbl_code',          '공통코드 관리', 3, 'common-code-management', 'Y', 'system'),
    ('0000', 'audit-target', 'tbl_menu',          '메뉴 관리',     4, 'menu-management',        'Y', 'system'),
    ('0000', 'audit-target', 'tbl_role',          '권한그룹 관리', 5, 'role-management',        'Y', 'system'),
    ('0000', 'audit-target', 'tbl_role_screen',   '화면 권한',     6, 'role-management',        'Y', 'system'),
    ('0000', 'audit-target', 'tbl_dept',          '부서 관리',     7, 'department-management',  'Y', 'system'),
    ('0000', 'audit-target', 'tbl_user',          '사용자 관리',   8, 'user-management',        'Y', 'system'),
    -- 법인구분 — tbl_company.co_gbn
    ('0000', 'CO_GBN',       '*',        '법인구분',              0, NULL, 'Y', 'system'),
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
    -- 거래처 구분 — tbl_partner.partner_gbn (tmpl_prp-waste-check 는 양식코드가 아님)
    ('0000', 'PARTNER_GBN',  '*',        '거래처 구분',            0, NULL, 'Y', 'system'),
    ('0000', 'PARTNER_GBN',  'SUPPLY',   '공급처',                 1, NULL, 'Y', 'system'),
    ('0000', 'PARTNER_GBN',  'SALES',    '판매처',                 2, NULL, 'Y', 'system'),
    ('0000', 'PARTNER_GBN',  'tmpl_prp-waste-check',    '폐기물 수거업체',        3, NULL, 'Y', 'system'),
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
    -- 폐기 구분 — tbl_waste_check_row.waste_gbn (tmpl_prp-waste-check 는 양식코드가 아님)
    ('0000', 'WASTE_GBN',    '*',        '폐기 구분',              0, NULL, 'Y', 'system'),
    ('0000', 'WASTE_GBN',    'BAD',      '부적합품',               1, NULL, 'Y', 'system'),
    ('0000', 'WASTE_GBN',    'tmpl_prp-waste-check',    '일반 폐기물',            2, NULL, 'Y', 'system'),
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
