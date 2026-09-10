-- ============================================================
--  00_alter.sql — 이미 깔린 DB 스키마 보정 (멱등)
--
--  개발자: 박승우
--  일자: 2026-09-10
--  코멘트:
--    1) apply-all.sh 가 스키마가 있으면 00_ddl 을 건너뛴다. CREATE 꼬리 ALTER 도 같이 빠진다.
--       이 파일은 00_ddl 여부와 무관하게 항상 돈다. 빈 DB 는 00_ddl 다음, 이미 깐 DB 는 이것만.
--    2) 다시 돌려도 결과가 같다 — IF NOT EXISTS · DROP IF EXISTS · 같은 TYPE 재지정
--    3) 00_ddl 을 IF NOT EXISTS 로 개작하지 않는다. 새 표·칸이 늘면 여기와 00_ddl 본문에 같이 적는다
-- ============================================================

SET search_path TO sasshaccp;

-- JVM(-Duser.timezone=Asia/Seoul) 과 SP now() 가 같은 벽시계를 보게 한다.
-- 세션 TZ 가 UTC 로 남으면 ins_dt 는 KST, 감사 now() 는 9시간 전으로 찍힌다.
-- 시험 DB 이름은 sasshaccp_test 다. 이름을 박으면 다른 DB 를 건드리거나 적용이 실패한다.
DO $$
BEGIN
  EXECUTE format('ALTER DATABASE %I SET timezone TO %L', current_database(), 'Asia/Seoul');
END
$$;

--
-- 자리 넓힘 — 이미 도는 DB 를 위한 보정. 다시 돌려도 결과가 같다
--
-- 금속검출 감도점검 행의 시각 칸이 varchar(4) 였다. 화면이 보내는 값은 `09:10` 로 5자라
-- 저장·전송이 전부 22001(문자열 잘림)로 막혔다 — 금속검출 일지를 한 장도 못 썼다.
-- 나머지 CCP 표(tbl_ccp_pkg_monitor_row.check_time · tbl_ccp_htg_monitor_row.check_time)는 처음부터 varchar(10) 이고
-- 실제로 `09:00` 5자가 들어 있다. 금속만 좁았다. 그 표에 맞춘다.
--
-- 넓히는 방향이라 자료가 깎이지 않는다. 위 CREATE TABLE 은 새 DB 용이고,
-- 이 문장은 이미 만들어진 표를 위한 것이다.
ALTER TABLE sasshaccp.tbl_ccp_metal_sens_row
    ALTER COLUMN check_time TYPE character varying(10);

--
-- 알림 중복 방지 — 이미 도는 DB 에도 붙는다. 다시 돌려도 결과가 같다
--
-- 일일 배치가 알림을 넣던 시절, 가드가 `NOT EXISTS (... ins_dt::date = current_date)` 였는데
-- 그 서브쿼리는 **같은 INSERT 가 방금 넣은 행을 못 본다**. 같은 양식의 지연 과제가 셋이면
-- 한 문장이 세 행을 넣었다 — 운영에 중복 조합이 15개 쌓여 있었다.
--
-- 그 INSERT 자체는 sp_tbl_schedule_task_generate_c_000 에서 걷어냈다. 이 인덱스는 재발 방지다.
-- 지금 유일한 적재처인 sp_tbl_notification_task_c_000 은 여기 안 걸린다 —
-- ux_tbl_schedule_task(co_cd, tmpl_cd, base_dt) 가 유니크라 과제가 양식·날짜당 하나뿐이고,
-- content 에 due_dt·due_time 이 들어가 한 문장 안에서 겹칠 수 없다.
CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_notification_dedup
    ON sasshaccp.tbl_notification (co_cd, user_id, noti_type_cd, content, ((ins_dt)::date));

--
-- 양식코드 유일 범위를 회사로 — 이미 도는 DB 용. 다시 돌려도 결과가 같다
--
-- 예전에는 tmpl_cd 전역 UNIQUE 였다. 0000 이 html_hyg_prc_001~012 를 쓰면
-- 0003 첫 복사가 013 이 됐다. 자사 HTML 은 회사 안에서 001 부터 채번한다.
-- 표준(html_sys_001, hwp_sys_*) 은 계속 co_cd=0000 한 줄이다.
--
-- 자식 FK 가 물면 DROP UNIQUE 가 죽는다. 의존 FK 만 떼고 UK 를 바꾼다.
-- 옛 FK 정의(tmpl_cd 단독 참조)를 다시 붙이면 새 UK (co_cd, tmpl_cd) 에 안 맞아 또 죽는다.
-- 재부착은 파일 하단 IF NOT EXISTS 가 새 키로 한다. 중간에 멈춰도 다시 돌리면 스킵+하단이 채운다.
DO $$
DECLARE
  v_cols text[];
  r record;
BEGIN
  SELECT array_agg(a.attname::text ORDER BY u.ord)
    INTO v_cols
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    JOIN unnest(c.conkey) WITH ORDINALITY AS u(attnum, ord) ON true
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = u.attnum
   WHERE n.nspname = 'sasshaccp'
     AND t.relname = 'tbl_template'
     AND c.conname = 'ux_tbl_template'
     AND c.contype = 'u';
  -- 이미 (co_cd, tmpl_cd) 이면 자식 FK 를 떼지 않는다
  IF v_cols IS NOT NULL AND v_cols = ARRAY['co_cd', 'tmpl_cd']::text[] THEN
    RETURN;
  END IF;
  FOR r IN
    SELECT n.nspname AS sch, cl.relname AS tbl, con.conname
      FROM pg_constraint con
      JOIN pg_class cl ON cl.oid = con.conrelid
      JOIN pg_namespace n ON n.oid = cl.relnamespace
     WHERE con.contype = 'f'
       AND con.confrelid = 'sasshaccp.tbl_template'::regclass
  LOOP
    EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I', r.sch, r.tbl, r.conname);
  END LOOP;
  ALTER TABLE sasshaccp.tbl_template DROP CONSTRAINT IF EXISTS ux_tbl_template;
  ALTER TABLE sasshaccp.tbl_template ADD CONSTRAINT ux_tbl_template UNIQUE (co_cd, tmpl_cd);
END
$$;

--
-- 변경 감사 로그 — 화면코드 직저. 이미 도는 DB 용. 다시 돌려도 결과가 같다
--
-- 예전에는 테이블명만 남기고 AUDIT_TARGET 공통코드로 화면을 역추적했다.
-- tbl_document 한 장이 문서함·결재대기·첨부·작성에 공유되어 승인이 문서함에 붙었다.
-- 행에 scrn_cd 가 없어도 이력이다. 헤더 없는 적재(curl·배치)를 apply-all 이 지우지 않는다.
ALTER TABLE sasshaccp.tbl_audit_log
    ADD COLUMN IF NOT EXISTS scrn_cd character varying(30) DEFAULT ''::character varying NOT NULL;
CREATE INDEX IF NOT EXISTS ix_tbl_audit_log_scrn
    ON sasshaccp.tbl_audit_log USING btree (co_cd, scrn_cd, ins_dt DESC);
-- 빈 scrn_cd 행은 지우지 않는다. 컬럼 추가만 멱등이다.

--
-- 결재 취소 사유 — 이미 도는 DB 용. 다시 돌려도 결과가 같다
--
ALTER TABLE sasshaccp.tbl_document
    ADD COLUMN IF NOT EXISTS cancel_reason character varying(500);

--
-- 문서 관계 표 — 화면이 안 써서 고아. 이미 도는 DB 용
--
DROP TABLE IF EXISTS sasshaccp.tbl_document_relation;

--
-- 영업일 전환 — 주말·공휴일을 회사 단위로 영업일로 취급. 이미 도는 DB 용
--
-- 00_ddl 본문의 CREATE 는 IF NOT EXISTS 가 없다. 이미 깐 DB 는 00_ddl 을 건너뛰므로 여기서 만든다.
CREATE TABLE IF NOT EXISTS sasshaccp.tbl_workday_override (
    idx bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd character varying(10) NOT NULL,
    ymd character varying(8) NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    CONSTRAINT ux_tbl_workday_override_ymd UNIQUE (co_cd, ymd)
);

--
-- FK 를 걸기 위한 스키마 보정 — 이미 도는 DB. 다시 돌려도 결과가 같다
--
-- 1) 빠진 co_cd · 화면↔양식 순환 끊기 · 파일 대표를 자식 플래그로
-- 2) 감사 로그 빈 화면코드는 NULL
-- 3) 문서 헤더 버전 0 은 NULL
--

ALTER TABLE sasshaccp.tbl_check_item
    ADD COLUMN IF NOT EXISTS co_cd character varying(10);
UPDATE sasshaccp.tbl_check_item SET co_cd = '0000' WHERE co_cd IS NULL;
ALTER TABLE sasshaccp.tbl_check_item
    ALTER COLUMN co_cd SET NOT NULL;
-- 자식 FK 가 생기면 여기도 같은 구멍이다. 의존 FK 만 떼고 UK 를 바꾼다. 재부착은 하단.
DO $$
DECLARE
  v_cols text[];
  r record;
BEGIN
  SELECT array_agg(a.attname::text ORDER BY u.ord)
    INTO v_cols
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    JOIN unnest(c.conkey) WITH ORDINALITY AS u(attnum, ord) ON true
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = u.attnum
   WHERE n.nspname = 'sasshaccp'
     AND t.relname = 'tbl_check_item'
     AND c.conname = 'ux_tbl_check_item'
     AND c.contype = 'u';
  -- 이미 (co_cd, tmpl_cd, item_cd) 이면 자식 FK 를 떼지 않는다
  IF v_cols IS NOT NULL AND v_cols = ARRAY['co_cd', 'tmpl_cd', 'item_cd']::text[] THEN
    RETURN;
  END IF;
  FOR r IN
    SELECT n.nspname AS sch, cl.relname AS tbl, con.conname
      FROM pg_constraint con
      JOIN pg_class cl ON cl.oid = con.conrelid
      JOIN pg_namespace n ON n.oid = cl.relnamespace
     WHERE con.contype = 'f'
       AND con.confrelid = 'sasshaccp.tbl_check_item'::regclass
  LOOP
    EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I', r.sch, r.tbl, r.conname);
  END LOOP;
  ALTER TABLE sasshaccp.tbl_check_item DROP CONSTRAINT IF EXISTS ux_tbl_check_item;
  ALTER TABLE sasshaccp.tbl_check_item ADD CONSTRAINT ux_tbl_check_item UNIQUE (co_cd, tmpl_cd, item_cd);
END
$$;

ALTER TABLE sasshaccp.tbl_screen
    ADD COLUMN IF NOT EXISTS co_cd character varying(10);
UPDATE sasshaccp.tbl_screen SET co_cd = '0000' WHERE co_cd IS NULL;
ALTER TABLE sasshaccp.tbl_screen
    ALTER COLUMN co_cd SET DEFAULT '0000',
    ALTER COLUMN co_cd SET NOT NULL;
ALTER TABLE sasshaccp.tbl_screen DROP COLUMN IF EXISTS tmpl_cd;

ALTER TABLE sasshaccp.tbl_company_template_file
    ADD COLUMN IF NOT EXISTS default_yn character varying(1) DEFAULT 'N';
ALTER TABLE sasshaccp.tbl_company_template_file
    ADD COLUMN IF NOT EXISTS current_yn character varying(1) DEFAULT 'N';
-- 부모 *_file_idx 가 아직 있을 때만 플래그로 옮긴다. 빈 DB(00_ddl 신스키마)는 칸이 없다
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'sasshaccp' AND table_name = 'tbl_company_template'
           AND column_name = 'default_file_idx'
    ) THEN
        UPDATE sasshaccp.tbl_company_template_file f
           SET default_yn = 'Y'
          FROM sasshaccp.tbl_company_template ct
         WHERE ct.default_file_idx IS NOT NULL
           AND f.idx = ct.default_file_idx
           AND f.co_cd = ct.co_cd AND f.tmpl_cd = ct.tmpl_cd;
        UPDATE sasshaccp.tbl_company_template_file f
           SET current_yn = 'Y'
          FROM sasshaccp.tbl_company_template ct
         WHERE ct.current_file_idx IS NOT NULL
           AND f.idx = ct.current_file_idx
           AND f.co_cd = ct.co_cd AND f.tmpl_cd = ct.tmpl_cd;
        ALTER TABLE sasshaccp.tbl_company_template DROP COLUMN IF EXISTS default_file_idx;
        ALTER TABLE sasshaccp.tbl_company_template DROP COLUMN IF EXISTS current_file_idx;
    END IF;
END $$;
UPDATE sasshaccp.tbl_company_template_file
   SET default_yn = 'N' WHERE default_yn IS NULL;
UPDATE sasshaccp.tbl_company_template_file
   SET current_yn = 'N' WHERE current_yn IS NULL;
ALTER TABLE sasshaccp.tbl_company_template_file
    ALTER COLUMN default_yn SET DEFAULT 'N',
    ALTER COLUMN default_yn SET NOT NULL,
    ALTER COLUMN current_yn SET DEFAULT 'N',
    ALTER COLUMN current_yn SET NOT NULL;

ALTER TABLE sasshaccp.tbl_audit_log ALTER COLUMN scrn_cd DROP DEFAULT;
ALTER TABLE sasshaccp.tbl_audit_log ALTER COLUMN scrn_cd DROP NOT NULL;
UPDATE sasshaccp.tbl_audit_log SET scrn_cd = NULL WHERE scrn_cd IS NOT DISTINCT FROM '';

ALTER TABLE sasshaccp.tbl_ccp_verify_check ALTER COLUMN ver_no DROP DEFAULT;
ALTER TABLE sasshaccp.tbl_ccp_verify_check ALTER COLUMN ver_no DROP NOT NULL;
UPDATE sasshaccp.tbl_ccp_verify_check SET ver_no = NULL WHERE ver_no = 0;

ALTER TABLE sasshaccp.tbl_hyg_process ALTER COLUMN ver_no DROP DEFAULT;
ALTER TABLE sasshaccp.tbl_hyg_process ALTER COLUMN ver_no DROP NOT NULL;
UPDATE sasshaccp.tbl_hyg_process SET ver_no = NULL WHERE ver_no = 0;

--
-- 고아 행 — FK 를 걸기 전에 깨진 참조를 지운다. 개발 DB 전제
--
-- 표준 지면(*_000)은 카탈로그에 없는 가상 양식이다. 부모를 먼저 두지 않으면
-- 아래 DELETE 가 표준 점검항목을 지우고 05_form_seed 가 FK 에 막힌다.
INSERT INTO sasshaccp.tbl_template (
    co_cd, tmpl_cd, tmpl_nm, doc_kind, category_cd, default_cycle_cd,
    default_retention_month, ver_no, impl_yn, sort_no, use_yn, ins_id, ins_dt
)
SELECT v.co_cd, v.tmpl_cd, v.tmpl_nm, 'HTML', 'CCP', v.cycle, 24, 1, 'N', v.sort_no, 'Y', 'system', now()
  FROM (VALUES
    ('0000', 'html_ccp_chk_000', 'CCP 검증점검 표준(가상)', 'M', 9001),
    ('0000', 'html_ccp_htg_000', 'CCP 가열 표준(가상)', 'D', 9002),
    ('0000', 'html_ccp_mtl_000', 'CCP 금속검출 표준(가상)', 'D', 9003),
    ('0000', 'html_ccp_pkg_000', 'CCP 포장 표준(가상)', 'D', 9004)
  ) AS v(co_cd, tmpl_cd, tmpl_nm, cycle, sort_no)
 WHERE NOT EXISTS (
   SELECT 1 FROM sasshaccp.tbl_template t
    WHERE t.co_cd = v.co_cd AND t.tmpl_cd = v.tmpl_cd
 );

DELETE FROM sasshaccp.tbl_check_item t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_template p WHERE p.co_cd = t.co_cd AND p.tmpl_cd = t.tmpl_cd);
DELETE FROM sasshaccp.tbl_company_template t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_template p WHERE p.co_cd = t.co_cd AND p.tmpl_cd = t.tmpl_cd);
DELETE FROM sasshaccp.tbl_company_template_file t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_company_template p WHERE p.co_cd = t.co_cd AND p.tmpl_cd = t.tmpl_cd);
DELETE FROM sasshaccp.tbl_doc_no_rule t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_template p WHERE p.co_cd = t.co_cd AND p.tmpl_cd = t.tmpl_cd);
DELETE FROM sasshaccp.tbl_menu t
 WHERE t.scrn_cd IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_screen s WHERE s.scrn_cd = t.scrn_cd);
DELETE FROM sasshaccp.tbl_role_screen t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_screen s WHERE s.scrn_cd = t.scrn_cd);
UPDATE sasshaccp.tbl_template SET scrn_cd = NULL
 WHERE scrn_cd IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_screen s WHERE s.scrn_cd = tbl_template.scrn_cd);
DELETE FROM sasshaccp.tbl_document_approval t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_document d WHERE d.idx = t.doc_idx);
DELETE FROM sasshaccp.tbl_document_file t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_document d WHERE d.idx = t.doc_idx);
DELETE FROM sasshaccp.tbl_document_version t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_document d WHERE d.idx = t.doc_idx);
DELETE FROM sasshaccp.tbl_hyg_process_item t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_hyg_process h WHERE h.idx = t.hdr_idx);
DELETE FROM sasshaccp.tbl_hyg_process t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_document d WHERE d.idx = t.doc_idx);
DELETE FROM sasshaccp.tbl_ccp_verify_item t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_ccp_verify_check h WHERE h.idx = t.hdr_idx);
DELETE FROM sasshaccp.tbl_ccp_verify_check t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_document d WHERE d.idx = t.doc_idx);
DELETE FROM sasshaccp.tbl_ccp_pkg_monitor_cell t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_ccp_pkg_monitor_row r WHERE r.idx = t.row_idx);
DELETE FROM sasshaccp.tbl_ccp_pkg_monitor_row t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_ccp_pkg_monitor m WHERE m.idx = t.monitor_idx);
DELETE FROM sasshaccp.tbl_ccp_pkg_monitor t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_document d WHERE d.idx = t.doc_idx);
DELETE FROM sasshaccp.tbl_ccp_htg_monitor_cell t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_ccp_htg_monitor_row r WHERE r.idx = t.row_idx);
DELETE FROM sasshaccp.tbl_ccp_htg_monitor_row t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_ccp_htg_monitor m WHERE m.idx = t.monitor_idx);
DELETE FROM sasshaccp.tbl_ccp_htg_monitor t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_document d WHERE d.idx = t.doc_idx);
DELETE FROM sasshaccp.tbl_ccp_metal_sens_row t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_ccp_metal_monitor h WHERE h.idx = t.hdr_idx);
DELETE FROM sasshaccp.tbl_ccp_metal_pass_row t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_ccp_metal_monitor h WHERE h.idx = t.hdr_idx);
DELETE FROM sasshaccp.tbl_ccp_metal_monitor t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_document d WHERE d.idx = t.doc_idx);
UPDATE sasshaccp.tbl_schedule_task SET doc_idx = NULL
 WHERE doc_idx IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_document d WHERE d.idx = tbl_schedule_task.doc_idx);
UPDATE sasshaccp.tbl_notification SET link_doc_idx = NULL
 WHERE link_doc_idx IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_document d WHERE d.idx = tbl_notification.link_doc_idx);
-- 옛 화면코드 → 지금 tbl_screen.scrn_cd. 안 맞으면 링크만 비운다
UPDATE sasshaccp.tbl_notification SET link_scrn_cd = CASE link_scrn_cd
    WHEN 'hygiene-process-check' THEN 'hyg-process'
    WHEN 'ccp-verification-check' THEN 'ccp-verify'
    WHEN 'ccp-htg-monitor' THEN 'ccp-htg'
    WHEN 'ccp-mtl-monitor' THEN 'ccp-mtl'
    WHEN 'ccp-pkg-monitor' THEN 'ccp-pkg'
    ELSE link_scrn_cd
END
 WHERE link_scrn_cd IN (
    'hygiene-process-check', 'ccp-verification-check',
    'ccp-htg-monitor', 'ccp-mtl-monitor', 'ccp-pkg-monitor'
 );
UPDATE sasshaccp.tbl_notification SET link_scrn_cd = NULL
 WHERE link_scrn_cd IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_screen s WHERE s.scrn_cd = tbl_notification.link_scrn_cd);
UPDATE sasshaccp.tbl_audit_log SET scrn_cd = NULL
 WHERE scrn_cd IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_screen s WHERE s.scrn_cd = tbl_audit_log.scrn_cd);
UPDATE sasshaccp.tbl_login_log SET co_cd = NULL
 WHERE co_cd IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_company c WHERE c.co_cd = tbl_login_log.co_cd);
UPDATE sasshaccp.tbl_company_template SET appr_line_cd = NULL
 WHERE appr_line_cd IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sasshaccp.tbl_approval_line a
        WHERE a.co_cd = tbl_company_template.co_cd AND a.appr_line_cd = tbl_company_template.appr_line_cd);
UPDATE sasshaccp.tbl_document SET appr_line_cd = NULL
 WHERE appr_line_cd IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sasshaccp.tbl_approval_line a
        WHERE a.co_cd = tbl_document.co_cd AND a.appr_line_cd = tbl_document.appr_line_cd);
UPDATE sasshaccp.tbl_menu SET h_menu_cd = NULL
 WHERE h_menu_cd IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sasshaccp.tbl_menu p
        WHERE p.co_cd = tbl_menu.co_cd AND p.menu_cd = tbl_menu.h_menu_cd);
UPDATE sasshaccp.tbl_user SET dept_cd = NULL
 WHERE dept_cd IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sasshaccp.tbl_dept d
        WHERE d.co_cd = tbl_user.co_cd AND d.dept_cd = tbl_user.dept_cd);
DELETE FROM sasshaccp.tbl_schedule_rule_detail t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_schedule_rule r WHERE r.co_cd = t.co_cd AND r.tmpl_cd = t.tmpl_cd);
DELETE FROM sasshaccp.tbl_schedule_rule t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_company_template p WHERE p.co_cd = t.co_cd AND p.tmpl_cd = t.tmpl_cd);
DELETE FROM sasshaccp.tbl_schedule_task t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_company_template p WHERE p.co_cd = t.co_cd AND p.tmpl_cd = t.tmpl_cd);
DELETE FROM sasshaccp.tbl_view_log t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_screen s WHERE s.scrn_cd = t.scrn_cd);
DELETE FROM sasshaccp.tbl_view_stat_daily t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_screen s WHERE s.scrn_cd = t.scrn_cd);
DELETE FROM sasshaccp.tbl_grid_pref t
 WHERE NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_screen s WHERE s.scrn_cd = t.scrn_cd)
    OR NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_user u WHERE u.user_id = t.user_id);
-- 회사 없는 행 — login_log 의 NULL co_cd 는 남긴다
DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'tbl_approval_line','tbl_approval_line_step','tbl_audit_log',
        'tbl_check_item','tbl_code','tbl_company_template','tbl_company_template_file',
        'tbl_dept','tbl_doc_no_rule','tbl_document','tbl_menu','tbl_notification',
        'tbl_role','tbl_role_screen','tbl_schedule_rule','tbl_schedule_rule_detail',
        'tbl_schedule_task','tbl_screen','tbl_template','tbl_user','tbl_user_noti_pref',
        'tbl_view_log','tbl_view_stat_daily','tbl_workday_override'
    ] LOOP
        EXECUTE format(
            'DELETE FROM sasshaccp.%I x WHERE x.co_cd IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sasshaccp.tbl_company c WHERE c.co_cd = x.co_cd)',
            t);
    END LOOP;
END $$;

--
-- _yn 칸에 Y/N 만 들어가게 막는다 — 이미 도는 DB 와 빈 DB 양쪽. 다시 돌려도 결과가 같다
--
-- 왜 있나: varchar(1) 짜리 _yn 칸이 43본인데 CHECK 가 걸린 건 tbl_html_*_ver 6표의 12본뿐이었다.
-- 나머지 31본은 'X' 든 소문자 'y' 든 그냥 들어간다. 그러면 use_yn = 'y' 인 행이
-- WHERE use_yn = 'Y' 에 안 걸려 화면에서 조용히 사라진다 — 저장은 됐는데 안 보이는 꼴이다.
-- 막는 자리는 응용이 아니라 표다. 패턴은 이미 tbl_html_*_ver 가 쓰고 있어서 그것에 맞춘다.
--
-- 넣기 전에 확인한 것: 01_sp.sql 의 _yn 쓰기는 'Y'/'N' 뿐이고(97/88건), 시드 7본도 같다.
-- 'sys'/'usr' 를 갖는 tbl_company_template.sys_yn 은 varchar(10) 이라 여기 대상이 아니다.
--
-- 자료가 더러우면 이 문장이 그 표 이름을 대며 멈춘다. 그때는 먼저 아래로 범인을 찾는다.
--   SELECT 'tbl_user' t, lock_yn v, count(*) FROM tbl_user WHERE lock_yn NOT IN ('Y','N') GROUP BY 2;
--
DO $$
DECLARE
    -- 표.칸 짝. 새 _yn varchar(1) 칸을 만들면 여기에 한 줄 더한다
    pairs text[][] := ARRAY[
        ['tbl_approval_line','use_yn'], ['tbl_approval_line_step','use_yn'],
        ['tbl_ccp_htg_monitor_row','judge_mod_yn'], ['tbl_ccp_pkg_monitor_row','judge_mod_yn'],
        ['tbl_ccp_metal_sens_row','judge_mod_yn'], ['tbl_check_item','use_yn'],
        ['tbl_code','sys_yn'], ['tbl_code','use_yn'],
        ['tbl_company','use_yn'], ['tbl_company_template','use_yn'],
        ['tbl_company_template','base_use_yn'], ['tbl_company_template_file','del_yn'],
        ['tbl_company_template_file','default_yn'], ['tbl_company_template_file','current_yn'],
        ['tbl_dept','use_yn'], ['tbl_document','del_yn'], ['tbl_menu','use_yn'],
        ['tbl_notification','read_yn'], ['tbl_role','use_yn'],
        ['tbl_role_screen','read_yn'], ['tbl_role_screen','write_yn'],
        ['tbl_role_screen','modify_yn'], ['tbl_role_screen','delete_yn'],
        ['tbl_role_screen','print_yn'], ['tbl_schedule_rule','use_yn'],
        ['tbl_schedule_task','alarm_send_yn'], ['tbl_screen','use_yn'],
        ['tbl_template','impl_yn'], ['tbl_template','use_yn'],
        ['tbl_user','gridsave_yn'], ['tbl_user','lock_yn'], ['tbl_user','use_yn'],
        ['tbl_user_noti_pref','recv_yn']
    ];
    tbl text; col text; cname text;
BEGIN
    FOR i IN 1 .. array_length(pairs, 1) LOOP
        tbl := pairs[i][1];
        col := pairs[i][2];
        cname := 'ck_' || tbl || '_' || col;
        -- 이미 있으면 건너뛴다 — 다시 돌려도 같은 결과여야 한다
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint c
              JOIN pg_class t ON t.oid = c.conrelid
              JOIN pg_namespace n ON n.oid = t.relnamespace
             WHERE n.nspname = 'sasshaccp' AND t.relname = tbl AND c.conname = cname
        ) THEN
            EXECUTE format(
                'ALTER TABLE sasshaccp.%I ADD CONSTRAINT %I CHECK (%I IN (''Y'', ''N''))',
                tbl, cname, col);
        END IF;
    END LOOP;
END $$;

-- HACCP_FK_BLOCK
--
-- 외래키 — 부모→자식 일방향. ON DELETE 는 RESTRICT(기본)
-- 안 거는 칸: 결재·작성 스냅샷, 로그 user_id/tgt_idx, CCP cell.item_cd, CA.src_doc_idx
--

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_approval_line_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_approval_line
            ADD CONSTRAINT fk_tbl_approval_line_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_approval_line_step_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_approval_line_step
            ADD CONSTRAINT fk_tbl_approval_line_step_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_audit_log_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_audit_log
            ADD CONSTRAINT fk_tbl_audit_log_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_htg_monitor_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_htg_monitor
            ADD CONSTRAINT fk_tbl_ccp_htg_monitor_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_htg_monitor_cell_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_htg_monitor_cell
            ADD CONSTRAINT fk_tbl_ccp_htg_monitor_cell_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_htg_monitor_row_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_htg_monitor_row
            ADD CONSTRAINT fk_tbl_ccp_htg_monitor_row_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_pkg_monitor_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_pkg_monitor
            ADD CONSTRAINT fk_tbl_ccp_pkg_monitor_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_pkg_monitor_cell_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_pkg_monitor_cell
            ADD CONSTRAINT fk_tbl_ccp_pkg_monitor_cell_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_pkg_monitor_row_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_pkg_monitor_row
            ADD CONSTRAINT fk_tbl_ccp_pkg_monitor_row_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_metal_monitor_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_metal_monitor
            ADD CONSTRAINT fk_tbl_ccp_metal_monitor_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_metal_pass_row_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_metal_pass_row
            ADD CONSTRAINT fk_tbl_ccp_metal_pass_row_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_metal_sens_row_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_metal_sens_row
            ADD CONSTRAINT fk_tbl_ccp_metal_sens_row_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_verify_check_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_verify_check
            ADD CONSTRAINT fk_tbl_ccp_verify_check_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_verify_item_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_verify_item
            ADD CONSTRAINT fk_tbl_ccp_verify_item_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_check_item_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_check_item
            ADD CONSTRAINT fk_tbl_check_item_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_code_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_code
            ADD CONSTRAINT fk_tbl_code_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_company_template_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_company_template
            ADD CONSTRAINT fk_tbl_company_template_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_company_template_file_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_company_template_file
            ADD CONSTRAINT fk_tbl_company_template_file_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_corrective_action_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_corrective_action
            ADD CONSTRAINT fk_tbl_corrective_action_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_dept_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_dept
            ADD CONSTRAINT fk_tbl_dept_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_doc_no_rule_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_doc_no_rule
            ADD CONSTRAINT fk_tbl_doc_no_rule_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_document_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_document
            ADD CONSTRAINT fk_tbl_document_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_document_approval_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_document_approval
            ADD CONSTRAINT fk_tbl_document_approval_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_document_file_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_document_file
            ADD CONSTRAINT fk_tbl_document_file_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_document_version_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_document_version
            ADD CONSTRAINT fk_tbl_document_version_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_grid_pref_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_grid_pref
            ADD CONSTRAINT fk_tbl_grid_pref_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_form_ver_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_form_ver
            ADD CONSTRAINT fk_tbl_html_form_ver_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_form_ver_item_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_form_ver_item
            ADD CONSTRAINT fk_tbl_html_form_ver_item_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_hyg_prc_ver_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_hyg_prc_ver
            ADD CONSTRAINT fk_tbl_html_hyg_prc_ver_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_hyg_prc_ver_item_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_hyg_prc_ver_item
            ADD CONSTRAINT fk_tbl_html_hyg_prc_ver_item_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_hyg_process_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_hyg_process
            ADD CONSTRAINT fk_tbl_hyg_process_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_hyg_process_item_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_hyg_process_item
            ADD CONSTRAINT fk_tbl_hyg_process_item_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_login_log_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_login_log
            ADD CONSTRAINT fk_tbl_login_log_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_menu_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_menu
            ADD CONSTRAINT fk_tbl_menu_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_notification_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_notification
            ADD CONSTRAINT fk_tbl_notification_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_role_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_role
            ADD CONSTRAINT fk_tbl_role_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_role_screen_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_role_screen
            ADD CONSTRAINT fk_tbl_role_screen_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_schedule_rule_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_schedule_rule
            ADD CONSTRAINT fk_tbl_schedule_rule_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_schedule_rule_detail_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_schedule_rule_detail
            ADD CONSTRAINT fk_tbl_schedule_rule_detail_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_schedule_task_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_schedule_task
            ADD CONSTRAINT fk_tbl_schedule_task_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_screen_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_screen
            ADD CONSTRAINT fk_tbl_screen_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_template_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_template
            ADD CONSTRAINT fk_tbl_template_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_chk_ver_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_chk_ver
            ADD CONSTRAINT fk_tbl_html_ccp_chk_ver_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_chk_ver_item_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_chk_ver_item
            ADD CONSTRAINT fk_tbl_html_ccp_chk_ver_item_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_htg_ver_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_htg_ver
            ADD CONSTRAINT fk_tbl_html_ccp_htg_ver_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_htg_ver_item_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_htg_ver_item
            ADD CONSTRAINT fk_tbl_html_ccp_htg_ver_item_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_mtl_ver_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_mtl_ver
            ADD CONSTRAINT fk_tbl_html_ccp_mtl_ver_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_mtl_ver_item_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_mtl_ver_item
            ADD CONSTRAINT fk_tbl_html_ccp_mtl_ver_item_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_pkg_ver_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_pkg_ver
            ADD CONSTRAINT fk_tbl_html_ccp_pkg_ver_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_pkg_ver_item_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_pkg_ver_item
            ADD CONSTRAINT fk_tbl_html_ccp_pkg_ver_item_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_user_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_user
            ADD CONSTRAINT fk_tbl_user_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_user_noti_pref_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_user_noti_pref
            ADD CONSTRAINT fk_tbl_user_noti_pref_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_view_log_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_view_log
            ADD CONSTRAINT fk_tbl_view_log_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_view_stat_daily_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_view_stat_daily
            ADD CONSTRAINT fk_tbl_view_stat_daily_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_workday_override_co_cd'
    ) THEN
        ALTER TABLE sasshaccp.tbl_workday_override
            ADD CONSTRAINT fk_tbl_workday_override_co_cd FOREIGN KEY (co_cd)
            REFERENCES sasshaccp.tbl_company(co_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_menu_scrn'
    ) THEN
        ALTER TABLE sasshaccp.tbl_menu
            ADD CONSTRAINT fk_tbl_menu_scrn FOREIGN KEY (scrn_cd)
            REFERENCES sasshaccp.tbl_screen(scrn_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_role_screen_scrn'
    ) THEN
        ALTER TABLE sasshaccp.tbl_role_screen
            ADD CONSTRAINT fk_tbl_role_screen_scrn FOREIGN KEY (scrn_cd)
            REFERENCES sasshaccp.tbl_screen(scrn_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_template_scrn'
    ) THEN
        ALTER TABLE sasshaccp.tbl_template
            ADD CONSTRAINT fk_tbl_template_scrn FOREIGN KEY (scrn_cd)
            REFERENCES sasshaccp.tbl_screen(scrn_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_grid_pref_scrn'
    ) THEN
        ALTER TABLE sasshaccp.tbl_grid_pref
            ADD CONSTRAINT fk_tbl_grid_pref_scrn FOREIGN KEY (scrn_cd)
            REFERENCES sasshaccp.tbl_screen(scrn_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_audit_log_scrn'
    ) THEN
        ALTER TABLE sasshaccp.tbl_audit_log
            ADD CONSTRAINT fk_tbl_audit_log_scrn FOREIGN KEY (scrn_cd)
            REFERENCES sasshaccp.tbl_screen(scrn_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_view_log_scrn'
    ) THEN
        ALTER TABLE sasshaccp.tbl_view_log
            ADD CONSTRAINT fk_tbl_view_log_scrn FOREIGN KEY (scrn_cd)
            REFERENCES sasshaccp.tbl_screen(scrn_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_view_stat_daily_scrn'
    ) THEN
        ALTER TABLE sasshaccp.tbl_view_stat_daily
            ADD CONSTRAINT fk_tbl_view_stat_daily_scrn FOREIGN KEY (scrn_cd)
            REFERENCES sasshaccp.tbl_screen(scrn_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_notification_scrn'
    ) THEN
        ALTER TABLE sasshaccp.tbl_notification
            ADD CONSTRAINT fk_tbl_notification_scrn FOREIGN KEY (link_scrn_cd)
            REFERENCES sasshaccp.tbl_screen(scrn_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_check_item_tmpl'
    ) THEN
        ALTER TABLE sasshaccp.tbl_check_item
            ADD CONSTRAINT fk_tbl_check_item_tmpl FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_company_template_tmpl'
    ) THEN
        ALTER TABLE sasshaccp.tbl_company_template
            ADD CONSTRAINT fk_tbl_company_template_tmpl FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_company_template_file_ct'
    ) THEN
        ALTER TABLE sasshaccp.tbl_company_template_file
            ADD CONSTRAINT fk_tbl_company_template_file_ct FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_company_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_doc_no_rule_tmpl'
    ) THEN
        ALTER TABLE sasshaccp.tbl_doc_no_rule
            ADD CONSTRAINT fk_tbl_doc_no_rule_tmpl FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_document_tmpl'
    ) THEN
        ALTER TABLE sasshaccp.tbl_document
            ADD CONSTRAINT fk_tbl_document_tmpl FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_schedule_rule_ct'
    ) THEN
        ALTER TABLE sasshaccp.tbl_schedule_rule
            ADD CONSTRAINT fk_tbl_schedule_rule_ct FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_company_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_schedule_task_ct'
    ) THEN
        ALTER TABLE sasshaccp.tbl_schedule_task
            ADD CONSTRAINT fk_tbl_schedule_task_ct FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_company_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_form_ver_tmpl'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_form_ver
            ADD CONSTRAINT fk_tbl_html_form_ver_tmpl FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_hyg_prc_ver_tmpl'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_hyg_prc_ver
            ADD CONSTRAINT fk_tbl_html_hyg_prc_ver_tmpl FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_chk_ver_tmpl'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_chk_ver
            ADD CONSTRAINT fk_tbl_html_ccp_chk_ver_tmpl FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_htg_ver_tmpl'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_htg_ver
            ADD CONSTRAINT fk_tbl_html_ccp_htg_ver_tmpl FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_mtl_ver_tmpl'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_mtl_ver
            ADD CONSTRAINT fk_tbl_html_ccp_mtl_ver_tmpl FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_pkg_ver_tmpl'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_pkg_ver
            ADD CONSTRAINT fk_tbl_html_ccp_pkg_ver_tmpl FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_template(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_form_ver_item_ver'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_form_ver_item
            ADD CONSTRAINT fk_tbl_html_form_ver_item_ver FOREIGN KEY (co_cd, tmpl_cd, ver_no)
            REFERENCES sasshaccp.tbl_html_form_ver(co_cd, tmpl_cd, ver_no);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_hyg_prc_ver_item_ver'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_hyg_prc_ver_item
            ADD CONSTRAINT fk_tbl_html_hyg_prc_ver_item_ver FOREIGN KEY (co_cd, tmpl_cd, ver_no)
            REFERENCES sasshaccp.tbl_html_hyg_prc_ver(co_cd, tmpl_cd, ver_no);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_chk_ver_item_ver'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_chk_ver_item
            ADD CONSTRAINT fk_tbl_html_ccp_chk_ver_item_ver FOREIGN KEY (co_cd, tmpl_cd, ver_no)
            REFERENCES sasshaccp.tbl_html_ccp_chk_ver(co_cd, tmpl_cd, ver_no);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_htg_ver_item_ver'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_htg_ver_item
            ADD CONSTRAINT fk_tbl_html_ccp_htg_ver_item_ver FOREIGN KEY (co_cd, tmpl_cd, ver_no)
            REFERENCES sasshaccp.tbl_html_ccp_htg_ver(co_cd, tmpl_cd, ver_no);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_mtl_ver_item_ver'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_mtl_ver_item
            ADD CONSTRAINT fk_tbl_html_ccp_mtl_ver_item_ver FOREIGN KEY (co_cd, tmpl_cd, ver_no)
            REFERENCES sasshaccp.tbl_html_ccp_mtl_ver(co_cd, tmpl_cd, ver_no);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_html_ccp_pkg_ver_item_ver'
    ) THEN
        ALTER TABLE sasshaccp.tbl_html_ccp_pkg_ver_item
            ADD CONSTRAINT fk_tbl_html_ccp_pkg_ver_item_ver FOREIGN KEY (co_cd, tmpl_cd, ver_no)
            REFERENCES sasshaccp.tbl_html_ccp_pkg_ver(co_cd, tmpl_cd, ver_no);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_approval_line_step_line'
    ) THEN
        ALTER TABLE sasshaccp.tbl_approval_line_step
            ADD CONSTRAINT fk_tbl_approval_line_step_line FOREIGN KEY (co_cd, appr_line_cd)
            REFERENCES sasshaccp.tbl_approval_line(co_cd, appr_line_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_company_template_line'
    ) THEN
        ALTER TABLE sasshaccp.tbl_company_template
            ADD CONSTRAINT fk_tbl_company_template_line FOREIGN KEY (co_cd, appr_line_cd)
            REFERENCES sasshaccp.tbl_approval_line(co_cd, appr_line_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_document_line'
    ) THEN
        ALTER TABLE sasshaccp.tbl_document
            ADD CONSTRAINT fk_tbl_document_line FOREIGN KEY (co_cd, appr_line_cd)
            REFERENCES sasshaccp.tbl_approval_line(co_cd, appr_line_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_role_screen_role'
    ) THEN
        ALTER TABLE sasshaccp.tbl_role_screen
            ADD CONSTRAINT fk_tbl_role_screen_role FOREIGN KEY (co_cd, usrgrp_cd)
            REFERENCES sasshaccp.tbl_role(co_cd, usrgrp_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_user_role'
    ) THEN
        ALTER TABLE sasshaccp.tbl_user
            ADD CONSTRAINT fk_tbl_user_role FOREIGN KEY (co_cd, usrgrp_cd)
            REFERENCES sasshaccp.tbl_role(co_cd, usrgrp_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_user_dept'
    ) THEN
        ALTER TABLE sasshaccp.tbl_user
            ADD CONSTRAINT fk_tbl_user_dept FOREIGN KEY (co_cd, dept_cd)
            REFERENCES sasshaccp.tbl_dept(co_cd, dept_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_schedule_task_dept'
    ) THEN
        ALTER TABLE sasshaccp.tbl_schedule_task
            ADD CONSTRAINT fk_tbl_schedule_task_dept FOREIGN KEY (co_cd, dept_cd)
            REFERENCES sasshaccp.tbl_dept(co_cd, dept_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_grid_pref_user'
    ) THEN
        ALTER TABLE sasshaccp.tbl_grid_pref
            ADD CONSTRAINT fk_tbl_grid_pref_user FOREIGN KEY (user_id)
            REFERENCES sasshaccp.tbl_user(user_id);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_user_noti_pref_user'
    ) THEN
        ALTER TABLE sasshaccp.tbl_user_noti_pref
            ADD CONSTRAINT fk_tbl_user_noti_pref_user FOREIGN KEY (user_id)
            REFERENCES sasshaccp.tbl_user(user_id);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_notification_user'
    ) THEN
        ALTER TABLE sasshaccp.tbl_notification
            ADD CONSTRAINT fk_tbl_notification_user FOREIGN KEY (user_id)
            REFERENCES sasshaccp.tbl_user(user_id);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_schedule_rule_detail_rule'
    ) THEN
        ALTER TABLE sasshaccp.tbl_schedule_rule_detail
            ADD CONSTRAINT fk_tbl_schedule_rule_detail_rule FOREIGN KEY (co_cd, tmpl_cd)
            REFERENCES sasshaccp.tbl_schedule_rule(co_cd, tmpl_cd);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_document_approval_doc'
    ) THEN
        ALTER TABLE sasshaccp.tbl_document_approval
            ADD CONSTRAINT fk_tbl_document_approval_doc FOREIGN KEY (doc_idx)
            REFERENCES sasshaccp.tbl_document(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_document_file_doc'
    ) THEN
        ALTER TABLE sasshaccp.tbl_document_file
            ADD CONSTRAINT fk_tbl_document_file_doc FOREIGN KEY (doc_idx)
            REFERENCES sasshaccp.tbl_document(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_document_version_doc'
    ) THEN
        ALTER TABLE sasshaccp.tbl_document_version
            ADD CONSTRAINT fk_tbl_document_version_doc FOREIGN KEY (doc_idx)
            REFERENCES sasshaccp.tbl_document(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_hyg_process_doc'
    ) THEN
        ALTER TABLE sasshaccp.tbl_hyg_process
            ADD CONSTRAINT fk_tbl_hyg_process_doc FOREIGN KEY (doc_idx)
            REFERENCES sasshaccp.tbl_document(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_verify_check_doc'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_verify_check
            ADD CONSTRAINT fk_tbl_ccp_verify_check_doc FOREIGN KEY (doc_idx)
            REFERENCES sasshaccp.tbl_document(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_pkg_monitor_doc'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_pkg_monitor
            ADD CONSTRAINT fk_tbl_ccp_pkg_monitor_doc FOREIGN KEY (doc_idx)
            REFERENCES sasshaccp.tbl_document(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_htg_monitor_doc'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_htg_monitor
            ADD CONSTRAINT fk_tbl_ccp_htg_monitor_doc FOREIGN KEY (doc_idx)
            REFERENCES sasshaccp.tbl_document(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_metal_monitor_doc'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_metal_monitor
            ADD CONSTRAINT fk_tbl_ccp_metal_monitor_doc FOREIGN KEY (doc_idx)
            REFERENCES sasshaccp.tbl_document(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_schedule_task_doc'
    ) THEN
        ALTER TABLE sasshaccp.tbl_schedule_task
            ADD CONSTRAINT fk_tbl_schedule_task_doc FOREIGN KEY (doc_idx)
            REFERENCES sasshaccp.tbl_document(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_notification_doc'
    ) THEN
        ALTER TABLE sasshaccp.tbl_notification
            ADD CONSTRAINT fk_tbl_notification_doc FOREIGN KEY (link_doc_idx)
            REFERENCES sasshaccp.tbl_document(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_hyg_process_item_hdr'
    ) THEN
        ALTER TABLE sasshaccp.tbl_hyg_process_item
            ADD CONSTRAINT fk_tbl_hyg_process_item_hdr FOREIGN KEY (hdr_idx)
            REFERENCES sasshaccp.tbl_hyg_process(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_verify_item_hdr'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_verify_item
            ADD CONSTRAINT fk_tbl_ccp_verify_item_hdr FOREIGN KEY (hdr_idx)
            REFERENCES sasshaccp.tbl_ccp_verify_check(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_metal_sens_row_hdr'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_metal_sens_row
            ADD CONSTRAINT fk_tbl_ccp_metal_sens_row_hdr FOREIGN KEY (hdr_idx)
            REFERENCES sasshaccp.tbl_ccp_metal_monitor(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_metal_pass_row_hdr'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_metal_pass_row
            ADD CONSTRAINT fk_tbl_ccp_metal_pass_row_hdr FOREIGN KEY (hdr_idx)
            REFERENCES sasshaccp.tbl_ccp_metal_monitor(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_pkg_monitor_row_mon'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_pkg_monitor_row
            ADD CONSTRAINT fk_tbl_ccp_pkg_monitor_row_mon FOREIGN KEY (monitor_idx)
            REFERENCES sasshaccp.tbl_ccp_pkg_monitor(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_htg_monitor_row_mon'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_htg_monitor_row
            ADD CONSTRAINT fk_tbl_ccp_htg_monitor_row_mon FOREIGN KEY (monitor_idx)
            REFERENCES sasshaccp.tbl_ccp_htg_monitor(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_pkg_monitor_cell_row'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_pkg_monitor_cell
            ADD CONSTRAINT fk_tbl_ccp_pkg_monitor_cell_row FOREIGN KEY (row_idx)
            REFERENCES sasshaccp.tbl_ccp_pkg_monitor_row(idx);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
          JOIN pg_namespace n ON n.oid = c.connamespace
         WHERE n.nspname = 'sasshaccp' AND c.conname = 'fk_tbl_ccp_htg_monitor_cell_row'
    ) THEN
        ALTER TABLE sasshaccp.tbl_ccp_htg_monitor_cell
            ADD CONSTRAINT fk_tbl_ccp_htg_monitor_cell_row FOREIGN KEY (row_idx)
            REFERENCES sasshaccp.tbl_ccp_htg_monitor_row(idx);
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_company_template_file_default
    ON sasshaccp.tbl_company_template_file (co_cd, tmpl_cd)
    WHERE default_yn = 'Y' AND del_yn = 'N';
CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_company_template_file_current
    ON sasshaccp.tbl_company_template_file (co_cd, tmpl_cd)
    WHERE current_yn = 'Y' AND del_yn = 'N';
