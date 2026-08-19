-- ============================================================
--  DDL 10 — 표준 점검항목 시드 (tbl_check_item)
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) 문구는 docs/해썹일지.pdf 원문을 그대로 옮긴다 — 임의 축약·의역 금지
--    2) 원문 오탈자만 최소 교정했다: "정상작성"→"정상작동", "적설 상태"→"적절 상태"
--    3) 업체가 문구를 바꾸고 싶으면 이 테이블이 아니라 tbl_company_check_item에 오버라이드를 넣는다
--    4) 신규 설치 정본 tmpl_cd 는 html_sys/hwp_sys. 운영(이미 94)에는 재실행하지 않는다
--       항목키 tmpl_prp-waste-check 는 양식코드가 아니라서 그대로 둔다
--
--  input_type — OX:양호/불량, JUDGE:적합/부적합, YN:예/아니오, NUM:수치1, NUM2:수치2, TEXT:서술
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. html_sys_007 — 일일 위생 점검일지 (작업 전 15항목 + 작업 중 8항목)
--    14·15번, 7·8번은 판정이 아니라 온도 기록 항목이라 input_type이 NUM 계열이다
-- ------------------------------------------------------------
INSERT INTO tbl_check_item (tmpl_cd, item_cd, grp_cd, grp_nm, item_nm, input_type, unit_nm, sort_no, ins_id) VALUES
    ('html_sys_007', 'B01', 'BEFORE', '작업 전 위생상태', '종업원의 위생복, 위생모 위생화, 앞치마, 토시 장갑 등 청결 착용 관리 여부', 'OX',   NULL,  1, 'system'),
    ('html_sys_007', 'B02', 'BEFORE', '작업 전 위생상태', '종업원의 두발, 수염, 손톱 등 개인위생 준수 여부', 'OX',   NULL,  2, 'system'),
    ('html_sys_007', 'B03', 'BEFORE', '작업 전 위생상태', '종업원의 시계, 반지, 목걸이, 귀고리, 머리핀 등 장신구 착용 여부', 'OX',   NULL,  3, 'system'),
    ('html_sys_007', 'B04', 'BEFORE', '작업 전 위생상태', '종업원에 대하여 피부병 등 전염성 질병 감염 또는 식육 안전성에 영향을 미칠 수 있는 심한 상처 여부', 'OX', NULL,  4, 'system'),
    ('html_sys_007', 'B05', 'BEFORE', '작업 전 위생상태', '손세척, 건조 및 소독설비 정상 작동 및 청결 상태, 소독조 등의 적정량 소독약 투입 여부', 'OX', NULL,  5, 'system'),
    ('html_sys_007', 'B06', 'BEFORE', '작업 전 위생상태', '식육과 접촉되는 장비(육절기, 골절기, 분쇄기 등), 컨베이어벨트 및 도구(작업대, 도마, 칼, 칼갈이 등)의 청결 상태 여부', 'OX', NULL,  6, 'system'),
    ('html_sys_007', 'B07', 'BEFORE', '작업 전 위생상태', '냉장 및 냉동 창고, 부자재 창고·진열판매대 온도관리 및 청결 상태 여부', 'OX', NULL,  7, 'system'),
    ('html_sys_007', 'B08', 'BEFORE', '작업 전 위생상태', '출입문 개폐관리 및 방충 방서 설비 적정 상태 여부', 'OX', NULL,  8, 'system'),
    ('html_sys_007', 'B09', 'BEFORE', '작업 전 위생상태', '원재료, 부자재(포장재), 제품 적정 보관 상태 여부', 'OX', NULL,  9, 'system'),
    ('html_sys_007', 'B10', 'BEFORE', '작업 전 위생상태', '원재료, 제품의 유통기한 경과 제품 여부', 'OX', NULL, 10, 'system'),
    ('html_sys_007', 'B11', 'BEFORE', '작업 전 위생상태', '환기, 온도, 조명(조도 및 보호망) 적절 상태 및 응축수 제거 여부', 'OX', NULL, 11, 'system'),
    ('html_sys_007', 'B12', 'BEFORE', '작업 전 위생상태', '위생실, 화장실, 탈의실 등의 청결 유지 여부', 'OX', NULL, 12, 'system'),
    ('html_sys_007', 'B13', 'BEFORE', '작업 전 위생상태', '바닥, 배수구, 벽면 및 천장 청결 상태 관리 여부', 'OX', NULL, 13, 'system'),
    ('html_sys_007', 'B14', 'BEFORE', '작업 전 위생상태', '작업실의 실내온도 온도기록', 'NUM',  '℃', 14, 'system'),
    ('html_sys_007', 'B15', 'BEFORE', '작업 전 위생상태', '냉장·냉동실의 보관온도 냉장실/냉동실', 'NUM2', '℃', 15, 'system'),
    ('html_sys_007', 'D01', 'DURING', '작업 중 위생상태', '작업 중 종업원의 흡연, 음식물 섭취, 껌 씹는 행위 여부', 'OX', NULL, 21, 'system'),
    ('html_sys_007', 'D02', 'DURING', '작업 중 위생상태', '종업원의 화장실 출입 시 또는 작업실 이탈 시 앞치마 및 장갑 등 착용여부', 'OX', NULL, 22, 'system'),
    ('html_sys_007', 'D03', 'DURING', '작업 중 위생상태', '작업 중 칼, 도마 등 작업 장비 및 기구 수시 소독 실시 여부', 'OX', NULL, 23, 'system'),
    ('html_sys_007', 'D04', 'DURING', '작업 중 위생상태', '식육을 오염되지 않도록 위생적으로 운반, 처리 또는 포장 여부', 'OX', NULL, 24, 'system'),
    ('html_sys_007', 'D05', 'DURING', '작업 중 위생상태', '바닥 이물질 및 배수 배출 상태 및 폐수 역류 상태 여부', 'OX', NULL, 25, 'system'),
    ('html_sys_007', 'D06', 'DURING', '작업 중 위생상태', '환기, 온도, 조명(조도 및 보호망) 적절 상태 및 응축수 제거 여부', 'OX', NULL, 26, 'system'),
    ('html_sys_007', 'D07', 'DURING', '작업 중 위생상태', '작업실의 실내온도 온도기록', 'NUM',  '℃', 27, 'system'),
    ('html_sys_007', 'D08', 'DURING', '작업 중 위생상태', '냉장·냉동실의 보관온도 냉장실/냉동실', 'NUM2', '℃', 28, 'system')
ON CONFLICT (tmpl_cd, item_cd) DO UPDATE SET
    grp_cd = EXCLUDED.grp_cd, grp_nm = EXCLUDED.grp_nm, item_nm = EXCLUDED.item_nm,
    input_type = EXCLUDED.input_type, unit_nm = EXCLUDED.unit_nm, sort_no = EXCLUDED.sort_no,
    upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 2. hwp_sys_010 — 작업장 환경위생관리 점검표 (15항목)
--    grp_nm이 양식의 항목 열, item_nm이 점검사항 열이다
-- ------------------------------------------------------------
INSERT INTO tbl_check_item (tmpl_cd, item_cd, grp_cd, grp_nm, item_nm, input_type, sort_no, ins_id) VALUES
    ('hwp_sys_010', 'A01', 'FLOOR',   '바닥',     '바닥 청결상태가 양호한가?', 'OX',  1, 'system'),
    ('hwp_sys_010', 'A02', 'WALL',    '벽면',     '벽면에 먼지의 축적 등이 없이 청결한가?', 'OX',  2, 'system'),
    ('hwp_sys_010', 'A03', 'CEIL',    '천정',     '응결수, 곰팡이 오염 및 청소상태는 양호한가?', 'OX',  3, 'system'),
    ('hwp_sys_010', 'A04', 'DRAIN',   '배수로',   '퇴적물이 없으며 청소 상태가 양호한가?', 'OX',  4, 'system'),
    ('hwp_sys_010', 'A05', 'DOOR',    '출입구',   '출입문 및 손잡이 등은 청소 상태가 깨끗한가?', 'OX',  5, 'system'),
    ('hwp_sys_010', 'A06', 'VENT',    '환기시설', '급배기 시설은 정상작동하고 청소상태는 양호한가?', 'OX',  6, 'system'),
    ('hwp_sys_010', 'A07', 'PIPE',    '배관',     '응결수가 발생되거나 누수되는 곳이 없는가?', 'OX',  7, 'system'),
    ('hwp_sys_010', 'A08', 'LIGHT',   '조명',     '조명시설에 해충 등이 제거되었으며 청결한가?', 'OX',  8, 'system'),
    ('hwp_sys_010', 'A09', 'ANTEROOM','위생전실', '청결 상태는 양호한가?', 'OX',  9, 'system'),
    ('hwp_sys_010', 'A10', 'WINDOW',  '유리창',   '밀폐관리는 양호하며, 유리창에 먼지가 제거 되었는가?', 'OX', 10, 'system'),
    ('hwp_sys_010', 'A11', 'TRASH',   '쓰레기통', '쓰레기통은 깨끗하게 비워 있는가?', 'OX', 11, 'system'),
    ('hwp_sys_010', 'A12', 'TOILET',  '화장실',   '위생용품 비치 및 위생설비의 작동·청결 상태는 양호한가?', 'OX', 12, 'system'),
    ('hwp_sys_010', 'A13', 'CLEANER', '청소도구', '청소 후 도구는 깨끗이 세척되어 지정된 장소에 보관하는가?', 'OX', 13, 'system'),
    ('hwp_sys_010', 'A14', 'CART',    '운반카',   '세척, 소독하고 정해진 위치에 있는가?', 'OX', 14, 'system'),
    ('hwp_sys_010', 'A15', 'tmpl_prp-waste-check',   '폐기물',   '폐기물 처리는 적절히 이루어지고 있는가?', 'OX', 15, 'system')
ON CONFLICT (tmpl_cd, item_cd) DO UPDATE SET
    grp_cd = EXCLUDED.grp_cd, grp_nm = EXCLUDED.grp_nm, item_nm = EXCLUDED.item_nm,
    input_type = EXCLUDED.input_type, sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 3. WATER — 용수관리 점검표 (12항목)
--    양식의 구분 열이 2단(용수저장탱크 → 주변/상부/내부, 공급시설 → 배관/급수펌프)이라
--    grp_nm에 두 단계를 함께 표기한다
-- ------------------------------------------------------------
INSERT INTO tbl_check_item (tmpl_cd, item_cd, grp_cd, grp_nm, item_nm, input_type, sort_no, ins_id) VALUES
    ('hwp_sys_021', 'W01', 'TANK_AROUND', '용수저장탱크 주변', '쓰레기 등 불필요한 물건이 방치되어 있지 않는가?', 'OX',  1, 'system'),
    ('hwp_sys_021', 'W02', 'TANK_AROUND', '용수저장탱크 주변', '청소상태는 깨끗한가?', 'OX',  2, 'system'),
    ('hwp_sys_021', 'W03', 'TANK_TOP',    '용수저장탱크 상부', '잠금장치는 제대로 설치되어 있는가?', 'OX',  3, 'system'),
    ('hwp_sys_021', 'W04', 'TANK_TOP',    '용수저장탱크 상부', '오염원은 없는가?', 'OX',  4, 'system'),
    ('hwp_sys_021', 'W05', 'TANK_IN',     '용수저장탱크 내부', '균열 혹은 누수는 없는가?', 'OX',  5, 'system'),
    ('hwp_sys_021', 'W06', 'TANK_IN',     '용수저장탱크 내부', '침전물은 없는가?', 'OX',  6, 'system'),
    ('hwp_sys_021', 'W07', 'TANK_IN',     '용수저장탱크 내부', '부유물질은 없는가?', 'OX',  7, 'system'),
    ('hwp_sys_021', 'W08', 'PIPE',        '공급시설 배관',     '균열 혹은 누수는 없는가?', 'OX',  8, 'system'),
    ('hwp_sys_021', 'W09', 'PIPE',        '공급시설 배관',     '접합부는 제대로 고정되어 있는가?', 'OX',  9, 'system'),
    ('hwp_sys_021', 'W10', 'PIPE',        '공급시설 배관',     '침전물 등의 발생은 없는가?', 'OX', 10, 'system'),
    ('hwp_sys_021', 'W11', 'PUMP',        '공급시설 급수펌프', '정상적으로 작동하는가?', 'OX', 11, 'system'),
    ('hwp_sys_021', 'W12', 'PUMP',        '공급시설 급수펌프', '접합부는 제대로 고정되어 있는가?', 'OX', 12, 'system')
ON CONFLICT (tmpl_cd, item_cd) DO UPDATE SET
    grp_cd = EXCLUDED.grp_cd, grp_nm = EXCLUDED.grp_nm, item_nm = EXCLUDED.item_nm,
    input_type = EXCLUDED.input_type, sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 4. PROCESS — 공정관리 점검표 (10항목)
-- ------------------------------------------------------------
INSERT INTO tbl_check_item (tmpl_cd, item_cd, grp_cd, grp_nm, item_nm, input_type, sort_no, ins_id) VALUES
    ('hwp_sys_028', 'P01', 'THAW',    '해동',     '해동온도 -2~5℃ 이하', 'OX',  1, 'system'),
    ('hwp_sys_028', 'P02', 'THAW',    '해동',     '해동시간 72시간 이내', 'OX',  2, 'system'),
    ('hwp_sys_028', 'P03', 'THAW',    '해동',     '해동 중 표시 여부', 'OX',  3, 'system'),
    ('hwp_sys_028', 'P04', 'UNPACK',  '개포',     '원료육 박스의 위생적 개포 여부', 'OX',  4, 'system'),
    ('hwp_sys_028', 'P05', 'UNSKIN',  '해피',     '원료육 내포장 위생적 개포 여부', 'OX',  5, 'system'),
    ('hwp_sys_028', 'P06', 'TRIM',    '정형',     '고기의 중심부 온도 10℃ 이하', 'OX',  6, 'system'),
    ('hwp_sys_028', 'P07', 'INPACK',  '내포장',   '포장시간 30분 이내', 'OX',  7, 'system'),
    ('hwp_sys_028', 'P08', 'METAL',   '금속검출', '전제품 금속검출 실시 여부', 'OX',  8, 'system'),
    ('hwp_sys_028', 'P09', 'OUTPACK', '외포장',   '포장시간 30분 이내', 'OX',  9, 'system'),
    ('hwp_sys_028', 'P10', 'SHIP',    '출고',     '신속한 상차 및 표시사항 적정 여부', 'OX', 10, 'system')
ON CONFLICT (tmpl_cd, item_cd) DO UPDATE SET
    grp_cd = EXCLUDED.grp_cd, grp_nm = EXCLUDED.grp_nm, item_nm = EXCLUDED.item_nm,
    input_type = EXCLUDED.input_type, sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 5. html_sys_009 — 시설·설비·처리도구 점검표 (12항목 + 기타)
--    방법·주기·담당자가 양식에 열로 있으므로 method_nm·cycle_nm까지 표준값을 넣는다
-- ------------------------------------------------------------
INSERT INTO tbl_check_item (tmpl_cd, item_cd, grp_cd, grp_nm, item_nm, input_type, method_nm, cycle_nm, sort_no, ins_id) VALUES
    ('html_sys_009', 'F01', 'LOCKER',  '탈의실',        '바닥, 벽, 천장, 조명, 문 등은 이물 등이 제거되어 있어야 한다.', 'OX', '육안', '주1회',  1, 'system'),
    ('html_sys_009', 'F02', 'LOCKER',  '탈의실',        '환기시설은 정상작동하며 이물 등이 제거되어 있어야 한다.', 'OX', '육안', '주1회',  2, 'system'),
    ('html_sys_009', 'F03', 'LOCKER',  '탈의실',        '위생복과 외출복은 구분하여 보관하고 탈의실내 불필요한 물건은 방치되어 있지 않아야 한다.', 'OX', '육안', '주1회',  3, 'system'),
    ('html_sys_009', 'F04', 'CLEAN',   '세척·소독시설', '냉, 온수가 공급 되어야 한다.', 'OX', '육안', '주1회',  4, 'system'),
    ('html_sys_009', 'F05', 'CLEAN',   '세척·소독시설', '위생장화 세척기와 주변은 이물 등이 제거되어 있어야 한다.', 'OX', '육안', '주1회',  5, 'system'),
    ('html_sys_009', 'F06', 'CLEAN',   '세척·소독시설', '손톱 세척솔, 세척용 비누, 손 건조기 등이 비치되어 있으며 손 세척 시설은 이물 등이 제거되어 있어야 한다.', 'OX', '육안', '주1회',  6, 'system'),
    ('html_sys_009', 'F07', 'MAKE',    '제조시설',      '시설 내, 외부는 이물 등이 제거되어 있어야 한다.', 'OX', '육안', '주1회',  7, 'system'),
    ('html_sys_009', 'F08', 'MAKE',    '제조시설',      '주 1회 이상 청소 및 소독을 실시하여야 한다.', 'OX', '육안', '주1회',  8, 'system'),
    ('html_sys_009', 'F09', 'MAKE',    '제조시설',      '제조시설(육절기, 골절기, 연육기, 분쇄기 등)은 정상작동하며 부식·마모되지 않아야 한다.', 'OX', '육안', '주1회',  9, 'system'),
    ('html_sys_009', 'F10', 'STORAGE', '보관시설',      '문 및 유니트쿨러는 정상작동하며 내부가 위생적으로 관리되어야 한다.', 'OX', '육안', '주1회', 10, 'system'),
    ('html_sys_009', 'F11', 'STORAGE', '보관시설',      '원료육 및 완제품은 구분 보관 및 바닥·벽으로부터 이격관리가 이루어져야 하며, 선입선출 관리하여야 한다.', 'OX', '육안', '주1회', 11, 'system'),
    ('html_sys_009', 'F12', 'STORAGE', '보관시설',      '천정은 응결수가 없어야 한다.', 'OX', '육안', '주1회', 12, 'system'),
    ('html_sys_009', 'F99', 'ETC',     '기타',          '기타 점검사항', 'OX', '육안', '주1회', 99, 'system')
ON CONFLICT (tmpl_cd, item_cd) DO UPDATE SET
    grp_cd = EXCLUDED.grp_cd, grp_nm = EXCLUDED.grp_nm, item_nm = EXCLUDED.item_nm,
    input_type = EXCLUDED.input_type, method_nm = EXCLUDED.method_nm, cycle_nm = EXCLUDED.cycle_nm,
    sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 6. html_sys_006 — 중요관리점(CCP) 검증점검표 (3공정 × 4항목 = 12항목)
--    첫 항목은 모니터링 일지 건수를 자동 집계해 기록란을 채운다(ref_tmpl_cd 매핑은 화면에서 처리)
-- ------------------------------------------------------------
INSERT INTO tbl_check_item (tmpl_cd, item_cd, grp_cd, grp_nm, item_nm, input_type, sort_no, ins_id) VALUES
    ('html_sys_006', 'V11', 'RAW_COLD',  '원료육 냉장보관', '종사자가 주기적으로 냉장보관고 온도를 확인하고, 그 내용을 기록하고 있습니까?', 'YN',  1, 'system'),
    ('html_sys_006', 'V12', 'RAW_COLD',  '원료육 냉장보관', '종사자가 원료육 냉장보관 공정 모니터링 방법을 정확히 알고 있습니까?', 'YN',  2, 'system'),
    ('html_sys_006', 'V13', 'RAW_COLD',  '원료육 냉장보관', '종사자가 한계기준 이탈 시 실시해야 하는 개선조치 방법을 알고 있으며, 이탈 및 개선조치 내용이 기록되고 있습니까?', 'YN',  3, 'system'),
    ('html_sys_006', 'V14', 'RAW_COLD',  '원료육 냉장보관', '온도측정장치는 주기적으로 검·교정이 이루어지고 있습니까?', 'YN',  4, 'system'),
    ('html_sys_006', 'V21', 'METAL',     '금속검출',        '종사자가 주기적으로 시편을 통해 금속검출기의 감도 이상 유무를 확인하고 있습니까?', 'YN',  5, 'system'),
    ('html_sys_006', 'V22', 'METAL',     '금속검출',        '종사자가 금속검출 공정 모니터링 방법을 정확히 알고 있습니까?', 'YN',  6, 'system'),
    ('html_sys_006', 'V23', 'METAL',     '금속검출',        '종사자가 한계기준 이탈 시 실시해야 하는 개선조치 방법을 알고 있으며, 이탈 및 개선조치 내용이 기록되고 있습니까?', 'YN',  7, 'system'),
    ('html_sys_006', 'V24', 'METAL',     '금속검출',        '금속검출기는 연 1회 검·교정(또는 정기점검)이 이루어지고 있습니까?', 'YN',  8, 'system'),
    ('html_sys_006', 'V31', 'PROD_COLD', '완제품 냉장보관', '종사자가 주기적으로 냉장보관고 온도를 확인하고, 그 내용을 기록하고 있습니까?', 'YN',  9, 'system'),
    ('html_sys_006', 'V32', 'PROD_COLD', '완제품 냉장보관', '종사자가 완제품 냉장보관 공정 모니터링 방법을 정확히 알고 있습니까?', 'YN', 10, 'system'),
    ('html_sys_006', 'V33', 'PROD_COLD', '완제품 냉장보관', '종사자가 한계기준 이탈 시 실시해야 하는 개선조치 방법을 알고 있으며, 이탈 및 개선조치 내용이 기록되고 있습니까?', 'YN', 11, 'system'),
    ('html_sys_006', 'V34', 'PROD_COLD', '완제품 냉장보관', '온도측정장치는 주기적으로 검·교정이 이루어지고 있습니까?', 'YN', 12, 'system')
ON CONFLICT (tmpl_cd, item_cd) DO UPDATE SET
    grp_cd = EXCLUDED.grp_cd, grp_nm = EXCLUDED.grp_nm, item_nm = EXCLUDED.item_nm,
    input_type = EXCLUDED.input_type, sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 7. hwp_sys_017 — 입고검사 일지
--    원료육(MEAT_*)과 부재료(SUB) 검사항목 세트가 다르다.
--    화면은 tbl_recv_inspect.recv_gbn 값에 따라 해당 grp_cd 항목만 보여준다
-- ------------------------------------------------------------
INSERT INTO tbl_check_item (tmpl_cd, item_cd, grp_cd, grp_nm, item_nm, input_type, sort_no, ins_id) VALUES
    -- 원료육 관능검사
    ('hwp_sys_017', 'M01', 'MEAT_EVAL',  '원료육 관능검사', '색깔(육질) — 고유의 색택', 'JUDGE',  1, 'system'),
    ('hwp_sys_017', 'M02', 'MEAT_EVAL',  '원료육 관능검사', '이물질 유무', 'JUDGE',  2, 'system'),
    ('hwp_sys_017', 'M03', 'MEAT_EVAL',  '원료육 관능검사', '냄새 — 이취여부', 'JUDGE',  3, 'system'),
    ('hwp_sys_017', 'M04', 'MEAT_EVAL',  '원료육 관능검사', '유통기한 — 기한표시', 'JUDGE',  4, 'system'),
    ('hwp_sys_017', 'M05', 'MEAT_EVAL',  '원료육 관능검사', '심부온도 — 냉장 -2~5℃, 냉동 -18℃ 이하', 'JUDGE',  5, 'system'),
    -- 원료육 운반차량
    ('hwp_sys_017', 'M06', 'MEAT_CAR',   '운반차량',        '차량온도', 'NUM',  6, 'system'),
    ('hwp_sys_017', 'M07', 'MEAT_CAR',   '운반차량',        '청결상태', 'JUDGE',  7, 'system'),
    -- 원료육 HACCP 적용확인
    ('hwp_sys_017', 'M08', 'MEAT_HACCP', 'HACCP 적용확인',  'HACCP 적용여부', 'YN',  8, 'system'),
    -- 원료육 서류검사
    ('hwp_sys_017', 'M09', 'MEAT_DOC',   '서류검사',        '도축증명서', 'JUDGE',  9, 'system'),
    ('hwp_sys_017', 'M10', 'MEAT_DOC',   '서류검사',        '등급판정서', 'JUDGE', 10, 'system'),
    ('hwp_sys_017', 'M11', 'MEAT_DOC',   '서류검사',        '기타', 'JUDGE', 11, 'system'),
    -- 부재료 평가항목
    ('hwp_sys_017', 'S01', 'SUB_EVAL',   '부재료 평가항목', '운송차량 청결상태', 'JUDGE', 21, 'system'),
    ('hwp_sys_017', 'S02', 'SUB_EVAL',   '부재료 평가항목', '포장상태', 'JUDGE', 22, 'system'),
    ('hwp_sys_017', 'S03', 'SUB_EVAL',   '부재료 평가항목', '이물질 오염', 'JUDGE', 23, 'system'),
    ('hwp_sys_017', 'S04', 'SUB_EVAL',   '부재료 평가항목', '인쇄상태', 'JUDGE', 24, 'system'),
    ('hwp_sys_017', 'S05', 'SUB_EVAL',   '부재료 평가항목', '표시상태', 'JUDGE', 25, 'system'),
    ('hwp_sys_017', 'S06', 'SUB_EVAL',   '부재료 평가항목', '성적서 확인', 'JUDGE', 26, 'system'),
    ('hwp_sys_017', 'S07', 'SUB_EVAL',   '부재료 평가항목', '기타사항', 'JUDGE', 27, 'system')
ON CONFLICT (tmpl_cd, item_cd) DO UPDATE SET
    grp_cd = EXCLUDED.grp_cd, grp_nm = EXCLUDED.grp_nm, item_nm = EXCLUDED.item_nm,
    input_type = EXCLUDED.input_type, sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();
