-- ============================================================
--  00_alter.sql — 이미 깔린 DB 스키마 보정 (멱등)
--
--  개발자: 박승우
--  일자: 2026-09-09
--  코멘트:
--    1) apply-all.sh 가 스키마가 있으면 00_ddl 을 건너뛴다. CREATE 꼬리 ALTER 도 같이 빠진다.
--       이 파일은 00_ddl 여부와 무관하게 항상 돈다. 빈 DB 는 00_ddl 다음, 이미 깐 DB 는 이것만.
--    2) 다시 돌려도 결과가 같다 — IF NOT EXISTS · DROP IF EXISTS · 같은 TYPE 재지정
--    3) 00_ddl 을 IF NOT EXISTS 로 개작하지 않는다. 새 표·칸이 늘면 여기와 00_ddl 본문에 같이 적는다
-- ============================================================

SET search_path TO sasshaccp;

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

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.check_time IS '점검 시각 HH:MM — 다른 CCP 표와 같은 자리 폭(10)';


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
ALTER TABLE sasshaccp.tbl_template DROP CONSTRAINT IF EXISTS ux_tbl_template;
ALTER TABLE sasshaccp.tbl_template ADD CONSTRAINT ux_tbl_template UNIQUE (co_cd, tmpl_cd);


--
-- 변경 감사 로그 — 화면코드 직저. 이미 도는 DB 용. 다시 돌려도 결과가 같다
--
-- 예전에는 테이블명만 남기고 AUDIT_TARGET 공통코드로 화면을 역추적했다.
-- tbl_document 한 장이 문서함·결재대기·첨부·작성에 공유되어 승인이 문서함에 붙었다.
-- 행에 scrn_cd 가 없어도 이력이다. 헤더 없는 적재(curl·배치)를 apply-all 이 지우지 않는다.
ALTER TABLE sasshaccp.tbl_audit_log
    ADD COLUMN IF NOT EXISTS scrn_cd character varying(30) DEFAULT ''::character varying NOT NULL;
COMMENT ON COLUMN sasshaccp.tbl_audit_log.scrn_cd IS '행위 화면코드 — tbl_screen.scrn_cd. 적재 시점에 남긴다. 조회는 이 값으로 메뉴 트리를 가른다';
COMMENT ON COLUMN sasshaccp.tbl_audit_log.action_cd IS '행위 — I:등록, U:수정, D:삭제, REQ:상신, REV:검토, APV:승인, RJT:반려, CANCEL:상신취소, UNDO:결재취소';
COMMENT ON COLUMN sasshaccp.tbl_audit_log.reason IS '사유 — 결재 반려·결재취소 시 입력값';
CREATE INDEX IF NOT EXISTS ix_tbl_audit_log_scrn
    ON sasshaccp.tbl_audit_log USING btree (co_cd, scrn_cd, ins_dt DESC);
-- 빈 scrn_cd 행은 지우지 않는다. 컬럼 추가만 멱등이다.


--
-- 결재 취소 사유 — 이미 도는 DB 용. 다시 돌려도 결과가 같다
--
ALTER TABLE sasshaccp.tbl_document
    ADD COLUMN IF NOT EXISTS cancel_reason character varying(500);
COMMENT ON COLUMN sasshaccp.tbl_document.cancel_reason IS '결재 취소 사유 — 줄바꿈으로 쌓는다. 최신이 맨 위. 재전송해도 유지';


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
COMMENT ON TABLE sasshaccp.tbl_workday_override IS '영업일 전환 — 행이 있으면 그 날(주말·공휴일)을 회사 영업일로 취급한다';
COMMENT ON COLUMN sasshaccp.tbl_workday_override.idx IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN sasshaccp.tbl_workday_override.co_cd IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN sasshaccp.tbl_workday_override.ymd IS '대상일 YYYYMMDD — 주말·공휴일을 영업일로 바꾼 날';
COMMENT ON COLUMN sasshaccp.tbl_workday_override.ins_id IS '전환 저장자 ID';
COMMENT ON COLUMN sasshaccp.tbl_workday_override.ins_dt IS '전환 저장 시각';


--
-- 문서 삭제 의미 — 컬럼 del_yn 은 목록 숨김이다. WRK·RJT 화면 삭제는 물리 DELETE.
-- 이미 깐 DB 는 00_ddl COMMENT 를 안 읽으므로 여기서도 맞춘다.
--
COMMENT ON COLUMN sasshaccp.tbl_document.del_yn IS '삭제여부 Y/N — 목록 숨김. WRK·RJT 화면 삭제는 물리 DELETE. 전송·결재완료는 지우지 않는다';
