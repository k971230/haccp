-- ============================================================
-- 역할 — 스마트 HACCP 기준일지 공통코드·정제 카탈로그·내부 양식 매핑
--
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) 공공 API의 테스트·미사용·공백 코드는 제외하고 업무에 쓸 기준일지만 플랫폼 시드로 넣는다
--   2) W/C 수기·설비 쌍은 동일 내부 양식에 매핑하되 설비형 C를 대표 행으로 둔다
--   3) 표준 양식은 플랫폼 소유이며 회사별 변경은 자사 양식 복제로만 허용한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 스마트 HACCP 공통코드 — 업체는 조회만 한다
-- ------------------------------------------------------------
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, sys_yn, ins_id) VALUES
    ('0000', 'DIARY_TYPE', '*',        '스마트 HACCP 기준일지 유형', 0, NULL, 'Y', 'system'),
    ('0000', 'DIARY_TYPE', 'CCP_DOC',  '중요관리점 일지',             1, NULL, 'Y', 'system'),
    ('0000', 'DIARY_TYPE', 'PRE_DOC',  '선행요건·일반 문서',          2, NULL, 'Y', 'system'),
    ('0000', 'DIARY_TYPE', 'LAW_DOC',  '법정의무 문서',               3, NULL, 'Y', 'system'),
    ('0000', 'DIARY_TYPE', 'PRE_AUTO', '선행 자동일지',               4, NULL, 'Y', 'system'),
    ('0000', 'LIMIT_ITEM_KIND', '*',          'CCP 한계항목 종류',       0, NULL, 'Y', 'system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMCC',   '냉장·냉동 온도',          1, 'TEMP', 'Y', 'system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMCD',   '금속검출',                2, 'METAL','Y', 'system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMCH',   '가열',                    3, 'HEAT', 'Y', 'system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMCW',   '세척',                    4, 'WASH', 'Y', 'system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMCP',   '소독·헹굼',               5, 'SAN',  'Y', 'system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMST',   '멸균',                    6, 'STERILIZE', 'Y', 'system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMCF',   '여과',                    7, 'FILTER','Y','system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMCB',   '세병',                    8, 'BOTTLE','Y','system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMCBA',  '세병·에어',               9, 'BOTTLE','Y','system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMCI',   '쇳가루 제거',            10, 'IRON', 'Y', 'system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMCM',   '수분활성도',             11, 'AW',   'Y', 'system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMCQF',  '급속동결',               12, 'FREEZE','Y','system'),
    ('0000', 'LIMIT_ITEM_KIND', 'LMTITMCCA',  '탄산',                   13, 'CO2',  'Y', 'system'),
    ('0000', 'DIARY_MATCH', '*',       '기준일지 매핑 수준',          0, NULL, 'Y', 'system'),
    ('0000', 'DIARY_MATCH', 'FULL',    '완전 대응',                  1, NULL, 'Y', 'system'),
    ('0000', 'DIARY_MATCH', 'PARTIAL', '부분 대응',                  2, NULL, 'Y', 'system'),
    ('0000', 'DIARY_MATCH', 'NONE',    '미대응',                     3, NULL, 'Y', 'system'),
    ('0000', 'DIARY_IMPL', '*',          '양식 구현 상태',              0, NULL, 'Y', 'system'),
    ('0000', 'DIARY_IMPL', 'DB_SCREEN',  '전용 DB 화면',                1, NULL, 'Y', 'system'),
    ('0000', 'DIARY_IMPL', 'HWP',        '문서 편집기',                 2, NULL, 'Y', 'system'),
    ('0000', 'DIARY_IMPL', 'CATALOG',    '카탈로그',                   3, NULL, 'Y', 'system'),
    ('0000', 'DIARY_IMPL', 'GENERIC_CCP','공통 CCP 화면',              4, NULL, 'Y', 'system'),
    ('0000', 'FORM_SRC', '*',          '작성 양식 출처',              0, NULL, 'Y', 'system'),
    ('0000', 'FORM_SRC', 'BASE',       '기본 양식',                   1, NULL, 'Y', 'system'),
    ('0000', 'FORM_SRC', 'CUSTOM',     '자사 양식',                   2, NULL, 'Y', 'system'),
    ('0000', 'CATEGORY_CD', 'LAW',     '법정대장',                    9, NULL, 'Y', 'system'),
    ('0000', 'CATEGORY_CD', 'AUTO',    '자동기록',                   10, NULL, 'Y', 'system')
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
    code_nm = EXCLUDED.code_nm, sort_no = EXCLUDED.sort_no, ref1 = EXCLUDED.ref1,
    sys_yn = 'Y', upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 2. 공공 API 정제 기준일지 — 쓰레기 코드(d)·미사용 공백 P0400은 넣지 않는다 (W0131 포함)
--    sort_no = 공공 API rnum (목록 표시 순서 정본)
-- ------------------------------------------------------------
INSERT INTO tbl_smart_diary_type (
    diary_no, diary_nm, diary_type, limit_item_kind, infra_use_yn, question_use_yn, archive_year_cnt,
    critical_limit_cn, monitoring_cycle_cn, monitoring_method_cn, improvement_method_cn, use_yn, sort_no, ins_id
) VALUES
    ('W0010', '중요관리점관리(가열-수기)', 'CCP_DOC', 'LMTITMCH', 'N', 'N', 0,
     '○ 온도 : 95~100℃\n○ 시간 : 15~20분\n○ 가열 후 품온 : 70~85℃',
     '작업 시작 전, 작업 중 2시간마다, 작업 종료 시',
     '가열기 판넬 온도·타이머와 탐침형 온도계로 가열 온도·시간·심부온도를 확인하고 기록한다.',
     '한계기준 이탈 시 작업을 중지하고 재가열 또는 제품검사 후 이탈내용과 개선조치를 기록한다.', 'Y', 10, 'system'),
    ('C0010', '중요관리점관리(가열)', 'CCP_DOC', 'LMTITMCH', 'Y', 'Y', 0,
     '○ 온도 : 95~100℃\n○ 시간 : 15~20분\n○ 가열 후 품온 : 70~85℃',
     '작업 시작 전, 작업 중 2시간마다, 작업 종료 시',
     '가열기 설비 값과 탐침형 온도계 값을 확인하고 기록한다.',
     '한계기준 이탈 시 생산을 중지하고 재가열·제품검사·개선조치를 기록한다.', 'Y', 11, 'system'),
    ('W0020', '중요관리점관리(냉장-수기)', 'CCP_DOC', 'LMTITMCC', 'N', 'N', 0,
     '○ 냉장실 온도 : -2~5℃', '작업 시작 전, 작업 중 2시간마다, 작업 종료 후',
     '냉장고와 자동온도기록지의 온도를 확인한다.',
     '온도 이탈 시 정상 보관고로 구분 이동하고 원인을 분석·수리하며 필요 시 미생물 검사를 실시한다.', 'Y', 20, 'system'),
    ('C0020', '중요관리점관리(냉장)', 'CCP_DOC', 'LMTITMCC', 'Y', 'Y', 0,
     '○ 냉장실 온도 : -2~5℃', '작업 시작 전, 작업 중 2시간마다, 작업 종료 후',
     '온도계 육안확인과 자동온도기록지를 확인한다.',
     '온도 이탈 시 정상 보관고로 구분 이동하고 이탈 원인을 분석한다.', 'Y', 21, 'system'),
    ('W0030', '중요관리점관리(금속검출-수기)', 'CCP_DOC', 'LMTITMCD', 'N', 'N', 0,
     '○ 금속이물(Fe 2.0mmΦ, STS 2.5mmΦ 이상) 불검출',
     '금속검출기 정상작동: 작업 시작 전·작업 중 2시간마다·작업 종료 후\n공정품 확인: 작업 중 상시',
     '기기감도·제품감도와 통과량·검출량을 확인해 기록한다.',
     '금속성 이물 또는 감도 이상 시 작업을 중지하고 공정품을 보류·재검사한다.', 'Y', 30, 'system'),
    ('C0030', '중요관리점관리(금속검출)', 'CCP_DOC', 'LMTITMCD', 'Y', 'Y', 0,
     '○ 금속이물(Fe 2.0mmΦ, STS 2.5mmΦ 이상) 불검출',
     '금속검출기 정상작동: 작업 시작 전·작업 중 2시간마다·작업 종료 후\n공정품 확인: 작업 중 상시',
     '기기감도·제품감도와 통과량·검출량을 확인해 기록한다.',
     '금속성 이물 또는 감도 이상 시 작업을 중지하고 공정품을 보류·재검사한다.', 'Y', 31, 'system'),
    ('W0040', '중요관리점관리(세척-수기)', 'CCP_DOC', 'LMTITMCW', 'N', 'N', 0,
     '○ 원료량·세척수량·세척시간·세척횟수·세척수 교체주기',
     '작업 시작 시, 작업 종료 전, 작업 중 기준 시간마다',
     '저울·수량계·타이머·육안으로 세척 항목을 측정하고 기록한다.',
     '한계기준 이탈 시 작업을 중지하고 재세척 후 이탈 및 개선조치를 기록한다.', 'Y', 40, 'system'),
    ('C0040', '중요관리점관리(세척)', 'CCP_DOC', 'LMTITMCW', 'Y', 'Y', 0,
     '세척방법·세척시간·세척수 교체주기', '작업 시작 시, 작업 중 2시간마다, 작업 종료 시',
     '세척 시간·주기는 타이머로, 세척수 교체주기는 유량계로 측정해 기록한다.',
     '한계기준 이탈 시 작업을 중지하고 재세척과 공정품 검사를 실시한다.', 'Y', 41, 'system'),
    ('W0050', '중요관리점관리(여과-수기)', 'CCP_DOC', 'LMTITMCF', 'N', 'N', 0,
     '○ 여과망 크기·여과압력·파손유무', '여과망: 작업 시작 전·후 품목교체 시\n압력: 작업 중 기준 시간마다·종료 시',
     '여과망 사이즈·압력계·파손 여부를 확인해 기록한다.',
     '필터 파손·압력 이상 시 작업을 중지하고 필터 교체·전수검사한다.', 'Y', 50, 'system'),
    ('C0050', '중요관리점관리(여과)', 'CCP_DOC', 'LMTITMCF', 'Y', 'Y', 0,
     '○ 여과망 크기·여과압력·파손유무', '여과망: 작업 시작 전·후 품목교체 시\n압력: 작업 중 기준 시간마다·종료 시',
     '여과망 사이즈·압력계·파손 여부를 확인해 기록한다.',
     '필터 파손·압력 이상 시 작업을 중지하고 필터 교체·전수검사한다.', 'Y', 51, 'system'),
    ('W0060', '중요관리점관리(소독/헹굼-수기)', 'CCP_DOC', 'LMTITMCP', 'N', 'N', 0,
     '○ 원료량·소독농도·소독/헹굼 수량·시간·용수 교체주기·잔류염소',
     '작업 시작 전, 작업 중 기준 시간마다, 작업 종료 시',
     '저울·염소측정페이퍼·수량계·타이머로 기준 항목을 확인하고 기록한다.',
     '한계기준 이탈 시 작업을 중지하고 재세척·소독 또는 재헹굼 후 기록한다.', 'Y', 60, 'system'),
    ('C0060', '중요관리점관리(소독/헹굼)', 'CCP_DOC', 'LMTITMCP', 'Y', 'Y', 0,
     '○ 원료량·소독농도·소독시간·헹굼시간·잔류염소',
     '작업 시작 전, 작업 중 2시간마다, 작업 종료 시',
     '소독·헹굼 기준을 계측기로 확인하고 기록한다.',
     '한계기준 이탈 시 작업 중지 후 재세척·소독·헹굼한다.', 'Y', 61, 'system'),
    ('W0061', '중요관리점관리(멸균-수기)', 'CCP_DOC', 'LMTITMST', 'N', 'N', 0,
     '○ 시작온도·종료온도·총 멸균시간',
     '배치마다(작업 시작·종료)',
     '멸균기 판넬 온도와 타이머로 시작/종료온도·총 멸균시간을 확인하고 기록한다.',
     '한계기준 이탈 시 재멸균 후 이탈내용과 개선조치를 기록한다.', 'Y', 62, 'system'),
    ('C0061', '중요관리점관리(멸균)', 'CCP_DOC', 'LMTITMST', 'Y', 'Y', 0,
     '○ 시작온도·종료온도·총 멸균시간',
     '배치마다(작업 시작·종료)',
     '멸균기 설비 값과 타이머로 시작/종료온도·총 멸균시간을 확인하고 기록한다.',
     '한계기준 이탈 시 재멸균 후 이탈내용과 개선조치를 기록한다.', 'Y', 63, 'system'),
    ('W0080', '중요관리점일지(세병-수기)', 'CCP_DOC', 'LMTITMCB', 'N', 'N', 0,
     '○ 세척압력·세척시간', '작업 시작 전, 작업 중 기준 시간마다, 작업 종료 시',
     '세병기 압력계와 판넬 시간을 확인하여 기록한다.',
     '세척압력 또는 시간 이탈 시 작업을 중지하고 재세척·제품검사한다.', 'Y', 80, 'system'),
    ('C0070', '중요관리점관리(세병)', 'CCP_DOC', 'LMTITMCB', 'Y', 'Y', 0,
     '세척압력·세척시간', '작업 시작 전, 작업 중 기준 시간마다, 작업 종료 시',
     '세병기 압력계와 판넬 시간을 확인하여 기록한다.',
     '세척압력 또는 시간 이탈 시 작업을 중지하고 재세척·제품검사한다.', 'Y', 81, 'system'),
    ('C0071', '중요관리점관리(세병-에어)', 'CCP_DOC', 'LMTITMCBA', 'Y', 'N', 0,
     '세척방법 에어세척\n세척시간 2초 이상\n에어분사입력 2.0kgf/㎠ 이상',
     '작업 시작 전, 작업 중 2시간마다, 품명·용기 변경 시',
     '에어 세척 압력과 시간을 확인해 기록한다.',
     '세척 압력 미달 시 이미 세척한 공병을 회수해 재세척한다.', 'Y', 82, 'system'),
    ('W0090', '중요관리점일지(쇳가루제거-수기)', 'CCP_DOC', 'LMTITMCI', 'N', 'N', 0,
     '자력 10,000가우스 이상·자석봉 청소상태·금속이물 10mg/kg 이하',
     '작업 시작 전 자력·청소 확인, 작업 중 1시간마다 청소, 작업 중 1회 이상 공정품 검사',
     '가우스미터로 자력을 확인하고 자석봉 청소·공정품 검사를 기록한다.',
     '기준 이탈 시 통과 속도 조절·자석봉 추가 및 이전 통과제품을 재통과한다.', 'Y', 90, 'system'),
    ('C0080', '중요관리점관리(쇳가루제거)', 'CCP_DOC', 'LMTITMCI', 'Y', 'Y', 0,
     '자력 10,000가우스 이상·자석봉 청소상태·금속이물 10mg/kg 이하',
     '작업 시작 전 자력·청소 확인, 작업 중 1시간마다 청소, 작업 중 1회 이상 공정품 검사',
     '가우스미터로 자력을 확인하고 자석봉 청소·공정품 검사를 기록한다.',
     '기준 이탈 시 통과 속도 조절·자석봉 추가 및 이전 통과제품을 재통과한다.', 'Y', 91, 'system'),
    ('W0100', '중요관리점일지(수분활성도-수기)', 'CCP_DOC', 'LMTITMCM', 'N', 'N', 0,
     '수분활성도 : 0.65 이하', '생산 첫 제품과 식사 후 첫 제품, 제품 변경 시',
     '샘플을 전용 용기에 담아 측정기에 넣고 표시값을 확인해 기록한다.',
     '한계기준 이탈 시 생산을 중단하고 재측정·원인분석·부적합품 조치를 한다.', 'Y', 100, 'system'),
    ('C0090', '중요관리점관리(수분활성)', 'CCP_DOC', 'LMTITMCM', 'Y', 'Y', 0,
     '수분활성도 : 0.65 이하', '생산 첫 제품과 식사 후 첫 제품, 제품 변경 시',
     '샘플을 전용 용기에 담아 측정기에 넣고 표시값을 확인해 기록한다.',
     '한계기준 이탈 시 생산을 중단하고 재측정·원인분석·부적합품 조치를 한다.', 'Y', 101, 'system'),
    ('C0021', '중요관리점일지(급속동결)', 'CCP_DOC', 'LMTITMCQF', 'Y', 'N', 0,
     '○ 동결량 3,000개 이하\n○ 동결온도 -25℃\n○ 동결시간 20분 이상\n○ 심부온도 -18℃ 이하',
     '매 작업 시(품목 변경 시)', '동결량은 육안, 동결온도는 온도계, 동결시간은 타이머로 확인한다.',
     '온도 이탈 시 정상 보관고로 구분 이동하고 원인을 분석·수리한다.', 'Y', 110, 'system'),
    ('C0100', '중요관리점일지(탄산)', 'CCP_DOC', 'LMTITMCCA', 'Y', 'N', 0,
     '탄산가스 볼륨(L/L) 2.8 ~ 4.6', '작업 시작 시, 매 1시간',
     '설비 모니터 화면의 탄산가스 볼륨을 확인해 일지에 기록한다.',
     '설비 이상 또는 기준 이탈 시 공정을 중지하고 개선조치를 기록한다.', 'Y', 120, 'system'),
    ('P0030', '조도관리', 'PRE_DOC', NULL, 'N', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 200, 'system'),
    ('P0050', '온/습도관리', 'PRE_DOC', NULL, 'Y', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 210, 'system'),
    ('P0060', '방충방서관리', 'PRE_DOC', NULL, 'Y', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 220, 'system'),
    ('P0070', '폐기물관리', 'PRE_DOC', NULL, 'Y', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 230, 'system'),
    ('P0080', '세척소독효과확인', 'PRE_DOC', NULL, 'N', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 240, 'system'),
    ('P0090', '교차오염관리', 'PRE_DOC', NULL, 'N', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 250, 'system'),
    ('P0180', '협력업체관리', 'PRE_DOC', NULL, 'N', 'Y', 0, NULL, NULL, NULL, NULL, 'Y', 260, 'system'),
    ('P0190', '회수관리', 'PRE_DOC', NULL, 'N', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 270, 'system'),
    ('P0191', '비상관리계획', 'PRE_DOC', NULL, 'N', 'Y', 1, NULL, NULL, NULL, NULL, 'Y', 280, 'system'),
    ('P0330', '냉장냉동온도관리', 'PRE_DOC', NULL, 'Y', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 290, 'system'),
    ('L0010', '보건증관리', 'LAW_DOC', NULL, 'N', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 300, 'system'),
    ('L0020', '원료수불대장관리', 'LAW_DOC', NULL, 'N', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 310, 'system'),
    ('L0030', '건축물대장관리', 'LAW_DOC', NULL, 'N', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 320, 'system'),
    ('L0040', '생산대장관리', 'LAW_DOC', NULL, 'N', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 330, 'system'),
    ('L0050', '영업등록증관리', 'LAW_DOC', NULL, 'N', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 340, 'system'),
    ('L0060', '자가품질검사관리', 'LAW_DOC', NULL, 'N', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 350, 'system'),
    ('L0070', '수료증관리', 'LAW_DOC', NULL, 'N', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 360, 'system'),
    ('A0010', '선행자동일지(냉장/냉동)', 'PRE_AUTO', 'LMTITMCC', 'Y', 'Y', 0,
     '○ 냉장실 온도 : -2~5℃', '작업 시작 전, 작업 중 2시간마다, 작업 종료 후',
     '온도계 육안확인과 자동온도기록지를 확인한다.',
     '온도 이탈 시 정상 보관고로 이동하고 원인을 분석·수리한다.', 'Y', 400, 'system'),
    ('A0020', '선행자동일지(조도)', 'PRE_AUTO', NULL, 'Y', 'Y', 0, '한계기준', NULL, NULL, NULL, 'Y', 410, 'system'),
    ('A0030', '선행자동일지(온/습도)', 'PRE_AUTO', NULL, 'Y', 'N', 0, NULL, NULL, NULL, NULL, 'Y', 420, 'system'),
    ('A0040', '선행자동일지(방충방서)', 'PRE_AUTO', NULL, 'Y', 'Y', 0, NULL, NULL, NULL, NULL, 'Y', 430, 'system')
ON CONFLICT (diary_no) DO UPDATE SET
    diary_nm = EXCLUDED.diary_nm, diary_type = EXCLUDED.diary_type, limit_item_kind = EXCLUDED.limit_item_kind,
    infra_use_yn = EXCLUDED.infra_use_yn, question_use_yn = EXCLUDED.question_use_yn,
    archive_year_cnt = EXCLUDED.archive_year_cnt, critical_limit_cn = EXCLUDED.critical_limit_cn,
    monitoring_cycle_cn = EXCLUDED.monitoring_cycle_cn, monitoring_method_cn = EXCLUDED.monitoring_method_cn,
    improvement_method_cn = EXCLUDED.improvement_method_cn, use_yn = EXCLUDED.use_yn, sort_no = EXCLUDED.sort_no,
    upd_id = 'system', upd_dt = now();

-- 장문 관리항목이 없는 PRE/Law 보조 문서와 나머지 수기 CCP는 카탈로그명·유형 중심으로 보완한다
INSERT INTO tbl_smart_diary_type (diary_no, diary_nm, diary_type, use_yn, sort_no, ins_id) VALUES
 ('W0190','중요관리점일지(육안선별-수기)','CCP_DOC','Y',1,'system'),
 ('W0180','중요관리점일지(입고검사-수기)','CCP_DOC','Y',2,'system'),
 ('W0170','중요관리점일지(급속동결-수기)','CCP_DOC','Y',3,'system'),
 ('W0160','중요관리점일지(주정첨가-수기)','CCP_DOC','Y',4,'system'),
 ('W0150','중요관리점일지(크림제조-수기)','CCP_DOC','Y',5,'system'),
 ('W0140','중요관리점일지(건조-수기)','CCP_DOC','Y',6,'system'),
 ('W0133','중요관리점일지(가열/살균)','CCP_DOC','Y',7,'system'),
 ('W0131','중요관리점관리(가열소독-수기)','CCP_DOC','Y',8,'system'),
 ('W0130','중요관리점일지(자외선살균-수기)','CCP_DOC','Y',9,'system'),
 ('W0120','중요관리점일지(보냉-수기)','CCP_DOC','Y',10,'system'),
 ('W0110','중요관리점일지(보온-수기)','CCP_DOC','Y',11,'system'),
 ('P0430','파일첨부 일지','PRE_DOC','Y',21,'system'),
 ('P0420','NEW 개선조치 보고서 관리','PRE_DOC','Y',22,'system'),
 ('P0410','NEW 정기검증일지','PRE_DOC','Y',23,'system'),
 ('P0400','연간검증계획서','PRE_DOC','Y',24,'system'),
 ('P0390','업무 인수인계서','PRE_DOC','Y',25,'system'),('P0380','설비이력카드','PRE_DOC','Y',26,'system'),
 ('P0370','원부자재검사성적서','PRE_DOC','Y',27,'system'),('P0360','완제품검사성적서','PRE_DOC','Y',28,'system'),
 ('P0350','용수검사성적서','PRE_DOC','Y',29,'system'),('P0340','표면오염도검사성적서','PRE_DOC','Y',30,'system'),
 ('P0320','공정관리확인사항','PRE_DOC','Y',32,'system'),('P0301','경영자인터뷰','PRE_DOC','Y',33,'system'),
 ('P0300','차량관리대장','PRE_DOC','Y',34,'system'),('P0290','설비관리점검표','PRE_DOC','Y',35,'system'),
 ('P0280','부적합제품관리','PRE_DOC','Y',36,'system'),('P0270','압축공기필터관리','PRE_DOC','Y',37,'system'),
 ('P0260','용수관리점검','PRE_DOC','Y',38,'system'),('P0240','연간교육훈련계획서','PRE_DOC','Y',39,'system'),
 ('P0230','일반위생관리','PRE_DOC','Y',40,'system'),('P0221','위해요소분석근거관리','PRE_DOC','Y',41,'system'),
 ('P0220','검사성적서관리','PRE_DOC','Y',42,'system'),('P0211','검증개선조치','PRE_DOC','Y',43,'system'),
 ('P0210','정기검증일지','PRE_DOC','Y',44,'system'),('P0200','교육훈련일지','PRE_DOC','Y',45,'system'),
 ('P0170','공중낙하세균 검사 성적서','PRE_DOC','Y',49,'system'),('P0161','검사장비 검/교정점검표','PRE_DOC','Y',50,'system'),
 ('P0160','검교정관리','PRE_DOC','Y',51,'system'),('P0151','원재료육안검사','PRE_DOC','Y',52,'system'),
 ('P0150','원재료입고관리','PRE_DOC','Y',53,'system'),('P0140','원부재료입출고관리기록','PRE_DOC','Y',54,'system'),
 ('P0130','저수조관리','PRE_DOC','Y',55,'system'),('P0120','용수관리','PRE_DOC','Y',56,'system'),
 ('P0110','냉장,냉동온도관리','PRE_DOC','Y',57,'system'),('P0100','설비이력관리','PRE_DOC','Y',58,'system'),
 ('P0040','클레임이물관리','PRE_DOC','Y',64,'system'),('P0020','개인위생관리','PRE_DOC','Y',66,'system'),
 ('P0010','위생.시설점검일지관리','PRE_DOC','Y',67,'system'),('P0000','중요관리점점검관리','PRE_DOC','Y',68,'system'),
 ('C0002','유효성평가자료','PRE_DOC','Y',89,'system'),('C0001','위해요소분석의근거자료','PRE_DOC','Y',90,'system')
ON CONFLICT (diary_no) DO UPDATE SET diary_nm = EXCLUDED.diary_nm, diary_type = EXCLUDED.diary_type, use_yn = EXCLUDED.use_yn, sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 2b. sort_no = 공공 API rnum (목록 순서 정본, d·공백 P0400 제외)
-- ------------------------------------------------------------
UPDATE tbl_smart_diary_type AS d SET
    sort_no = v.rnum,
    upd_id = 'system',
    upd_dt = now()
  FROM (VALUES
    ('W0190',1),('W0180',2),('W0170',3),('W0160',4),('W0150',5),('W0140',6),('W0133',7),('W0131',8),
    ('W0130',9),('W0120',10),('W0110',11),('W0100',12),('W0090',13),('W0080',14),('W0060',15),('W0050',16),
    ('W0040',17),('W0030',18),('W0020',19),('W0010',20),('P0430',21),('P0420',22),('P0410',23),('P0400',24),
    ('P0390',25),('P0380',26),('P0370',27),('P0360',28),('P0350',29),('P0340',30),('P0330',31),('P0320',32),
    ('P0301',33),('P0300',34),('P0290',35),('P0280',36),('P0270',37),('P0260',38),('P0240',39),('P0230',40),
    ('P0221',41),('P0220',42),('P0211',43),('P0210',44),('P0200',45),('P0191',46),('P0190',47),('P0180',48),
    ('P0170',49),('P0161',50),('P0160',51),('P0151',52),('P0150',53),('P0140',54),('P0130',55),('P0120',56),
    ('P0110',57),('P0100',58),('P0090',59),('P0080',60),('P0070',61),('P0060',62),('P0050',63),('P0040',64),
    ('P0030',65),('P0020',66),('P0010',67),('P0000',68),('L0070',69),('L0060',70),('L0050',71),('L0040',72),
    ('L0030',73),('L0020',74),('L0010',75),('C0100',77),('C0090',78),('C0080',79),('C0071',80),('C0070',81),
    ('C0060',82),('C0050',83),('C0040',84),('C0030',85),('C0021',86),('C0020',87),('C0010',88),('C0002',89),
    ('C0001',90),('A0040',91),('A0030',92),('A0020',93),('A0010',94)
  ) AS v(diary_no, rnum)
 WHERE d.diary_no = v.diary_no;

UPDATE tbl_smart_diary_type
   SET diary_nm = 'NEW 개선조치 보고서 관리', upd_id = 'system', upd_dt = now()
 WHERE diary_no = 'P0420';

UPDATE tbl_smart_diary_type
   SET diary_nm = 'NEW 정기검증일지', upd_id = 'system', upd_dt = now()
 WHERE diary_no = 'P0410';

-- ------------------------------------------------------------
-- 3. 공통 CCP 화면으로 수용할 신규 공정 템플릿
-- ------------------------------------------------------------
INSERT INTO tbl_template (
    tmpl_cd, tmpl_nm, doc_kind, category_cd, scrn_cd, default_cycle_cd, default_retention_month, impl_yn, sort_no, ins_id
) VALUES
    ('tmpl_ccp-heat-log',     '가열 모니터링 일지',         'DB', 'CCP', 'ccp-heat-monitor', 'D', 24, 'Y', 31, 'system'),
    ('CCP_WASH',     '세척 모니터링 일지',         'DB', 'CCP', 'ccp-wash-monitor', 'D', 24, 'Y', 32, 'system'),
    ('tmpl_ccp-sanitize-log', '멸균 모니터링 일지',         'DB', 'CCP', 'ccp-sanitize-monitor', 'D', 24, 'Y', 33, 'system'),
    ('tmpl_ccp-filter-log',   '여과 모니터링 일지',         'DB', 'CCP', 'ccp-filter-monitor', 'D', 24, 'Y', 34, 'system'),
    ('CCP_BOTTLE',   '세병 모니터링 일지',         'DB', 'CCP', 'ccp-generic-monitor', 'D', 24, 'Y', 35, 'system'),
    ('CCP_IRON',     '쇳가루 제거 모니터링 일지',  'DB', 'CCP', 'ccp-generic-monitor', 'D', 24, 'Y', 36, 'system'),
    ('CCP_AW',       '수분활성도 모니터링 일지',   'DB', 'CCP', 'ccp-generic-monitor', 'D', 24, 'Y', 37, 'system'),
    ('CCP_IQF',      '급속동결 모니터링 일지',     'DB', 'CCP', 'ccp-iqf-monitor', 'D', 24, 'Y', 38, 'system'),
    ('CCP_CO2',      '탄산 모니터링 일지',         'DB', 'CCP', 'ccp-generic-monitor', 'D', 24, 'Y', 39, 'system'),
    ('ILLUMINATION',  '조도관리',                   'HWP','HYG', NULL, 'M', 24, 'Y', 53, 'system'),
    ('TEMP_HUMIDITY','온·습도관리',                'HWP','HYG', NULL, 'D', 24, 'Y', 54, 'system'),
    ('WASH_EFFICACY','세척소독효과확인',            'HWP','HYG', NULL, 'M', 24, 'Y', 55, 'system'),
    ('CROSS_CONTAM', '교차오염관리',               'HWP','HYG', NULL, 'M', 24, 'Y', 56, 'system'),
    ('tmpl_admin-recall-report',       '회수관리',                   'HWP','DOC', NULL, 'E', 36, 'Y', 57, 'system'),
    ('EMERGENCY',    '비상관리계획',               'HWP','DOC', NULL, 'Y', 36, 'Y', 58, 'system'),
    ('tmpl_admin-law-health',   '보건증관리',                 'HWP','LAW', 'law-health-cert', 'E', 36, 'Y', 61, 'system'),
    ('tmpl_logis-material-ledger', '원료수불대장관리',           'HWP','LAW', 'law-material-ledger', 'M', 36, 'Y', 62, 'system'),
    ('tmpl_admin-building-ledger', '건축물대장관리',             'HWP','LAW', 'law-building-ledger', 'E', 36, 'Y', 63, 'system'),
    ('tmpl_admin-production-ledger','생산대장관리',              'HWP','LAW', 'law-production-ledger', 'D', 36, 'Y', 64, 'system'),
    ('tmpl_admin-license-manage',  '영업등록증관리',             'HWP','LAW', 'law-business-license', 'E', 36, 'Y', 65, 'system'),
    ('tmpl_admin-self-test','자가품질검사관리',           'HWP','LAW', 'law-self-quality-test', 'M', 36, 'Y', 66, 'system'),
    ('tmpl_admin-cert-manage',     '수료증관리',                 'HWP','LAW', 'law-completion-cert', 'E', 36, 'Y', 67, 'system'),
    ('AUTO_COLD',    '자동 냉장·냉동 온도관리',    'DB', 'AUTO','ccp-generic-monitor', 'D', 24, 'Y', 71, 'system'),
    ('AUTO_ILLUM',   '자동 조도관리',              'DB', 'AUTO','ccp-generic-monitor', 'D', 24, 'Y', 72, 'system'),
    ('AUTO_TEMP',    '자동 온·습도관리',           'DB', 'AUTO','ccp-generic-monitor', 'D', 24, 'Y', 73, 'system'),
    ('AUTO_PEST',    '자동 방충방서관리',           'DB', 'AUTO','ccp-generic-monitor', 'D', 24, 'Y', 74, 'system')
ON CONFLICT (tmpl_cd) DO UPDATE SET
    tmpl_nm = EXCLUDED.tmpl_nm, doc_kind = EXCLUDED.doc_kind, category_cd = EXCLUDED.category_cd,
    scrn_cd = EXCLUDED.scrn_cd, default_cycle_cd = EXCLUDED.default_cycle_cd,
    default_retention_month = EXCLUDED.default_retention_month, impl_yn = EXCLUDED.impl_yn,
    sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 4. 대표 대응 매핑 — 공공 외부코드는 내부 tmpl_cd와 분리한다
-- ------------------------------------------------------------
INSERT INTO tbl_smart_diary_map (diary_no, tmpl_cd, match_level, impl_status, preferred_yn, ins_id) VALUES
    ('W0010','tmpl_ccp-heat-log','FULL','GENERIC_CCP','N','system'), ('C0010','tmpl_ccp-heat-log','FULL','GENERIC_CCP','Y','system'),
    ('W0020','tmpl_ccp-cold-log','FULL','DB_SCREEN','N','system'), ('C0020','tmpl_ccp-cold-log','FULL','DB_SCREEN','Y','system'),
    ('W0030','tmpl_ccp-metal-log','FULL','DB_SCREEN','N','system'), ('C0030','tmpl_ccp-metal-log','FULL','DB_SCREEN','Y','system'),
    ('W0040','CCP_WASH','FULL','GENERIC_CCP','N','system'), ('C0040','CCP_WASH','FULL','GENERIC_CCP','Y','system'),
    ('W0050','tmpl_ccp-filter-log','FULL','GENERIC_CCP','N','system'), ('C0050','tmpl_ccp-filter-log','FULL','GENERIC_CCP','Y','system'),
    ('W0060','tmpl_ccp-sanitize-log','FULL','GENERIC_CCP','N','system'), ('C0060','tmpl_ccp-sanitize-log','FULL','GENERIC_CCP','N','system'),
    ('W0061','tmpl_ccp-sanitize-log','FULL','GENERIC_CCP','N','system'), ('C0061','tmpl_ccp-sanitize-log','FULL','GENERIC_CCP','Y','system'),
    ('W0080','CCP_BOTTLE','FULL','GENERIC_CCP','N','system'), ('C0070','CCP_BOTTLE','FULL','GENERIC_CCP','Y','system'),
    ('C0071','CCP_BOTTLE','PARTIAL','GENERIC_CCP','Y','system'),
    ('W0090','CCP_IRON','FULL','GENERIC_CCP','N','system'), ('C0080','CCP_IRON','FULL','GENERIC_CCP','Y','system'),
    ('W0100','CCP_AW','FULL','GENERIC_CCP','N','system'), ('C0090','CCP_AW','FULL','GENERIC_CCP','Y','system'),
    ('C0021','CCP_IQF','FULL','GENERIC_CCP','Y','system'), ('C0100','CCP_CO2','FULL','GENERIC_CCP','Y','system'),
    ('P0030','ILLUMINATION','FULL','HWP','Y','system'), ('P0050','TEMP_HUMIDITY','FULL','HWP','Y','system'),
    ('P0060','tmpl_prp-pest-check','FULL','DB_SCREEN','Y','system'), ('P0070','tmpl_prp-waste-check','FULL','DB_SCREEN','Y','system'),
    ('P0080','WASH_EFFICACY','FULL','HWP','Y','system'), ('P0090','CROSS_CONTAM','FULL','HWP','Y','system'),
    ('P0180','SUPPLIER_EVAL','PARTIAL','CATALOG','Y','system'), ('P0190','tmpl_admin-recall-report','FULL','HWP','Y','system'),
    ('P0191','EMERGENCY','FULL','HWP','Y','system'), ('P0330','tmpl_ccp-cold-log','PARTIAL','DB_SCREEN','Y','system'),
    ('L0010','tmpl_admin-law-health','FULL','HWP','Y','system'), ('L0020','tmpl_logis-material-ledger','PARTIAL','HWP','Y','system'),
    ('L0030','tmpl_admin-building-ledger','FULL','HWP','Y','system'), ('L0040','tmpl_admin-production-ledger','PARTIAL','HWP','Y','system'),
    ('L0050','tmpl_admin-license-manage','FULL','HWP','Y','system'), ('L0060','tmpl_admin-self-test','PARTIAL','HWP','Y','system'),
    ('L0070','tmpl_admin-cert-manage','FULL','HWP','Y','system'), ('A0010','AUTO_COLD','PARTIAL','GENERIC_CCP','Y','system'),
    ('A0020','AUTO_ILLUM','PARTIAL','GENERIC_CCP','Y','system'), ('A0030','AUTO_TEMP','PARTIAL','GENERIC_CCP','Y','system'),
    ('A0040','AUTO_PEST','PARTIAL','GENERIC_CCP','Y','system')
ON CONFLICT (diary_no, tmpl_cd) DO UPDATE SET
    match_level = EXCLUDED.match_level, impl_status = EXCLUDED.impl_status, preferred_yn = EXCLUDED.preferred_yn,
    upd_id = 'system', upd_dt = now();
