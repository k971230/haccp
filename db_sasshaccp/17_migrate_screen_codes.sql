-- 역할 — 기존 운영 데이터의 C# 양식형 화면코드를 역할 기반 화면 식별자로 일괄 전환
--
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) frm{모듈}{번호} 형식은 화면 구현 기술을 드러내는 레거시 명명이라 kebab-case 역할명으로 교체한다
--   2) 메뉴·권한·그리드 설정·템플릿·조회 통계가 같은 화면코드를 공유하므로 모든 참조 테이블을 같은 트랜잭션에서 바꾼다
--   3) 이미 역할 기반 코드로 전환된 데이터는 매핑 대상이 아니므로 재실행해도 변경 없이 성공한다

BEGIN;

-- tbl_menu.menu_cd: 기존 화면번호 길이(20자) 대신 역할명 최대 30자를 담을 수 있게 확장
ALTER TABLE tbl_menu ALTER COLUMN menu_cd TYPE varchar(40);

-- 기존 화면코드와 새 역할 기반 화면코드의 고정 대응표 — 새 코드가 DB·FE 레지스트리·권한 키의 단일 정본이다
CREATE TEMP TABLE tmp_screen_code_map (
    old_scrn_cd varchar(30) PRIMARY KEY,
    new_scrn_cd varchar(30) NOT NULL UNIQUE
) ON COMMIT DROP;

INSERT INTO tmp_screen_code_map (old_scrn_cd, new_scrn_cd) VALUES
    ('frmTSK0100', 'today-tasks'),
    ('frmCCP0100', 'ccp-cold-monitor'),
    ('frmCCP0200', 'ccp-metal-monitor'),
    ('frmCCP0300', 'ccp-verification-check'),
    ('frmCCP0400', 'annual-verification-plan'),
    ('frmHYG0100', 'daily-hygiene-check'),
    ('frmHYG0200', 'personal-hygiene-check'),
    ('frmHYG0300', 'area-hygiene-check'),
    ('frmHYG0400', 'pest-control-check'),
    ('frmHYG0500', 'water-management-check'),
    ('frmPRC0100', 'process-control-check'),
    ('frmFAC0100', 'facility-equipment-check'),
    ('frmFAC0200', 'calibration-target-management'),
    ('frmFAC0300', 'waste-disposal-check'),
    ('frmINV0100', 'inventory-check'),
    ('frmINV0200', 'receiving-inspection'),
    ('frmDOC0100', 'hwp-document-editor'),
    ('frmDOC0200', 'document-inbox'),
    ('frmDOC0300', 'approval-inbox'),
    ('frmDOC0400', 'corrective-action-management'),
    ('frmDOC0500', 'audit-export'),
    ('frmBAS0100', 'product-management'),
    ('frmBAS0200', 'material-management'),
    ('frmBAS0300', 'partner-management'),
    ('frmBAS0400', 'storage-management'),
    ('frmBAS0500', 'equipment-management'),
    ('frmBAS0600', 'measuring-device-management'),
    ('frmBAS0700', 'pest-device-management'),
    ('frmBAS0800', 'vehicle-management'),
    ('frmBAS0900', 'work-area-management'),
    ('frmBAS1000', 'ccp-limit-management'),
    ('frmBAS1100', 'approval-line-management'),
    ('frmBAS1200', 'template-check-item-management'),
    ('frmBAS1300', 'schedule-cycle-management'),
    ('frmSYS0100', 'company-management'),
    ('frmSYS0200', 'user-management'),
    ('frmSYS0300', 'department-management'),
    ('frmSYS0400', 'role-management'),
    ('frmSYS0500', 'menu-management'),
    ('frmSYS0600', 'common-code-management'),
    ('frmSYS0700', 'login-history'),
    ('frmSYS0800', 'screen-usage-statistics'),
    ('frmSYS0900', 'audit-log');

-- 09_seed_platform.sql이 먼저 실행된 경우(= 기존 DB를 전체 재적용) 새 코드 행이 선삽입된다.
-- 구 코드 행도 존재할 때만 새 코드 행을 지워 이후 UPDATE의 unique 충돌을 막고 기존 idx·감사 이력을 승계한다.
DELETE FROM tbl_screen seeded
 USING tmp_screen_code_map map
 WHERE seeded.scrn_cd = map.new_scrn_cd
   AND EXISTS (
       SELECT 1
         FROM tbl_screen legacy
        WHERE legacy.scrn_cd = map.old_scrn_cd
   );

-- tbl_template.scrn_cd: DB형 양식이 여는 전용 화면 연결
UPDATE tbl_template target
   SET scrn_cd = map.new_scrn_cd,
       upd_id = 'system',
       upd_dt = now()
  FROM tmp_screen_code_map map
 WHERE target.scrn_cd = map.old_scrn_cd;

-- tbl_role_screen.scrn_cd: 사용자 역할별 5단계 화면 권한
UPDATE tbl_role_screen target
   SET scrn_cd = map.new_scrn_cd,
       upd_id = 'system',
       upd_dt = now()
  FROM tmp_screen_code_map map
 WHERE target.scrn_cd = map.old_scrn_cd;

-- tbl_menu의 menu_cd·scrn_cd: 화면 leaf가 코드 자체를 메뉴 식별자로도 사용한다
UPDATE tbl_menu target
   SET menu_cd = map.new_scrn_cd,
       scrn_cd = map.new_scrn_cd,
       upd_id = 'system',
       upd_dt = now()
  FROM tmp_screen_code_map map
 WHERE target.scrn_cd = map.old_scrn_cd;

-- tbl_grid_pref.scrn_cd: 기존 사용자의 열 너비·정렬 JSON 설정을 새 화면으로 승계
UPDATE tbl_grid_pref target
   SET scrn_cd = map.new_scrn_cd,
       upd_id = 'system',
       upd_dt = now()
  FROM tmp_screen_code_map map
 WHERE target.scrn_cd = map.old_scrn_cd;

-- tbl_view_log의 현재·직전 화면코드: 과거 PV와 화면 전환 분석을 새 명명으로 일관되게 보존
UPDATE tbl_view_log target
   SET scrn_cd = (
           SELECT map.new_scrn_cd
             FROM tmp_screen_code_map map
            WHERE map.old_scrn_cd = target.scrn_cd
       ),
       ref_scrn_cd = COALESCE(
           (
               SELECT map.new_scrn_cd
                 FROM tmp_screen_code_map map
                WHERE map.old_scrn_cd = target.ref_scrn_cd
           ),
           target.ref_scrn_cd
       )
 WHERE EXISTS (
       SELECT 1
         FROM tmp_screen_code_map map
        WHERE map.old_scrn_cd = target.scrn_cd
   );

-- 직전 화면만 구 형식이고 현재 화면은 이미 전환됐을 때(= 부분 적용 이력)도 보정
UPDATE tbl_view_log target
   SET ref_scrn_cd = map.new_scrn_cd
  FROM tmp_screen_code_map map
 WHERE target.ref_scrn_cd = map.old_scrn_cd;

-- tbl_view_stat_daily.scrn_cd: 일자별 집계의 화면 차원값
UPDATE tbl_view_stat_daily target
   SET scrn_cd = map.new_scrn_cd,
       upd_id = 'system',
       upd_dt = now()
  FROM tmp_screen_code_map map
 WHERE target.scrn_cd = map.old_scrn_cd;

-- tbl_notification.link_scrn_cd: 알림 클릭 시 열 화면
UPDATE tbl_notification target
   SET link_scrn_cd = map.new_scrn_cd
  FROM tmp_screen_code_map map
 WHERE target.link_scrn_cd = map.old_scrn_cd;

-- 참조 데이터 전환 뒤 화면 마스터를 마지막에 갱신한다
UPDATE tbl_screen target
   SET scrn_cd = map.new_scrn_cd,
       upd_id = 'system',
       upd_dt = now()
  FROM tmp_screen_code_map map
 WHERE target.scrn_cd = map.old_scrn_cd;

COMMIT;
