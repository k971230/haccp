-- ============================================================
-- 85 — 문서주기관리 (양식당 주기 1건 · 반복 상세 · 비영업일 처리 · 마감 알림)
--
-- 파일번호: 85
-- 이전번호: 84
-- 개발자: 박승우
-- 일자: 2026-08-14
-- 코멘트:
--   1) 양식 1개 = 주기 0..1 로 못박는다 — UNIQUE(co_cd, tmpl_cd). 기존 여러 규칙은 최신 1건만 남기고 정리한다
--   2) 반복 상세(요일·실행일·말일·분기월·반기월)는 tbl_schedule_rule_detail 로 분리한다
--      규칙 해석은 Java CycleScheduleGenerator 한 곳에서만 한다 — SQL 에 같은 규칙을 두 번 쓰지 않는다
--   3) 주기 코드는 기존 대문자 D/W/M/Y 를 유지하고 Q(분기)·H(반기)만 추가한다 (docs/22 UPPER 정본)
--      비영업일 처리(nonwork-rule)만 신규 코드군이라 kebab 소문자 keep/prev/next 를 쓴다
--   4) 재실행 안전 — ADD COLUMN IF NOT EXISTS · ON CONFLICT · CREATE OR REPLACE
--
-- 선행: 51(base_dt·sys_yn) · 84(사용양식 구분) 적용 완료
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. tbl_schedule_rule — 양식당 1건 제약 · 비영업일 처리
--    중복행은 가장 최근 수정본만 남긴다 (오늘 할 일 배치도 이미 최신 1건만 보고 있었다)
-- ------------------------------------------------------------
DELETE FROM tbl_schedule_rule r
 WHERE r.idx NOT IN (
        SELECT DISTINCT ON (co_cd, tmpl_cd) idx
          FROM tbl_schedule_rule
         ORDER BY co_cd, tmpl_cd, COALESCE(upd_dt, ins_dt) DESC NULLS LAST, idx DESC
       );

-- 남은 1건의 순번을 1로 맞춘다 — rule_seq 는 레거시 유니크(co_cd,tmpl_cd,rule_seq) 유지용
UPDATE tbl_schedule_rule SET rule_seq = 1 WHERE rule_seq <> 1;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ux_tbl_schedule_rule_tmpl'
    ) THEN
        ALTER TABLE tbl_schedule_rule
            ADD CONSTRAINT ux_tbl_schedule_rule_tmpl UNIQUE (co_cd, tmpl_cd);
    END IF;
END$$;

ALTER TABLE tbl_schedule_rule ADD COLUMN IF NOT EXISTS nonwork_rule varchar(10) NOT NULL DEFAULT 'keep';
COMMENT ON COLUMN tbl_schedule_rule.nonwork_rule IS
  '비영업일 처리 — keep:그대로, prev:이전 영업일, next:다음 영업일. 토·일에 걸린 예정일을 어디로 옮길지';
COMMENT ON COLUMN tbl_schedule_rule.cycle_cd IS
  '주기 — D:매일, W:매주, M:매월, Q:분기, H:반기, Y:매년, E:수시(이벤트 발생 시)';
COMMENT ON COLUMN tbl_schedule_rule.base_dt IS
  '관리 시작일 yyyyMMdd — 이 날짜 이전 예정일은 만들지 않는다';
COMMENT ON COLUMN tbl_schedule_rule.rule_seq IS
  '규칙 순번 — 양식당 1건 제약(ux_tbl_schedule_rule_tmpl) 이후로는 항상 1. 레거시 유니크 유지용';

-- ------------------------------------------------------------
-- 2. tbl_schedule_rule_detail — 반복 설정 상세
--    주기 종류마다 필요한 값이 달라 컬럼을 늘리지 않고 (유형, 값1, 값2) 로 세로로 쌓는다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_schedule_rule_detail (
    idx       bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd     varchar(10) NOT NULL,
    tmpl_cd   varchar(40) NOT NULL,
    seq       int         NOT NULL,
    detail_ty varchar(20) NOT NULL,
    val1      int         NULL,
    val2      int         NULL,
    CONSTRAINT ux_tbl_schedule_rule_detail UNIQUE (co_cd, tmpl_cd, seq)
);
COMMENT ON TABLE  tbl_schedule_rule_detail           IS '작성주기 반복 상세 — 요일·실행일·말일·분기월·반기월. 저장 시 양식 단위로 전량 교체된다';
COMMENT ON COLUMN tbl_schedule_rule_detail.idx       IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_schedule_rule_detail.co_cd     IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_schedule_rule_detail.tmpl_cd   IS '양식코드 — tbl_schedule_rule.tmpl_cd (양식당 주기 1건이라 rule 키와 같다)';
COMMENT ON COLUMN tbl_schedule_rule_detail.seq       IS '입력 순번 — 화면 표시 순서. 업무 의미는 없다';
COMMENT ON COLUMN tbl_schedule_rule_detail.detail_ty IS
  '상세 유형 — week-day:요일, month-day:실행일, month-end:말일, quarter-month:분기내 실행월, half-month:반기내 실행월, year-month:실행월';
COMMENT ON COLUMN tbl_schedule_rule_detail.val1      IS '값1 — 요일 1(월)~7(일) / 실행일 1~31 / 분기·반기 내 월 순번 / 실행월 1~12. month-end 는 NULL';
COMMENT ON COLUMN tbl_schedule_rule_detail.val2      IS '값2 — 월 지정과 함께 쓰는 실행일 1~31. 요일·실행일 단독일 때는 NULL';

CREATE INDEX IF NOT EXISTS ix_tbl_schedule_rule_detail_01
    ON tbl_schedule_rule_detail (co_cd, tmpl_cd, seq);

-- ------------------------------------------------------------
-- 3. tbl_schedule_task — 마감 알림 시각
--    알림 시각을 예정일 생성 시점에 계산해 둔다 — 배치가 매번 규칙을 다시 해석하지 않는다
-- ------------------------------------------------------------
ALTER TABLE tbl_schedule_task ADD COLUMN IF NOT EXISTS alarm_dt timestamp NULL;
ALTER TABLE tbl_schedule_task ADD COLUMN IF NOT EXISTS alarm_send_yn varchar(1) NOT NULL DEFAULT 'N';
COMMENT ON COLUMN tbl_schedule_task.alarm_dt      IS '알림 시각 — 마감(due_dt+due_time) 에서 app.schedule.alarm-before-minutes 만큼 앞선 시점';
COMMENT ON COLUMN tbl_schedule_task.alarm_send_yn IS '알림 발송여부 Y/N — Y일 때(= 이미 보냄) 다시 보내지 않는다';

CREATE INDEX IF NOT EXISTS ix_tbl_schedule_task_alarm
    ON tbl_schedule_task (alarm_send_yn, alarm_dt);

-- ------------------------------------------------------------
-- 4. 공통코드 — CYCLE_CD 에 분기·반기 추가, 비영업일 처리 신규, 과제 알림 유형 정합
--    기존 CYCLE_CD 를 가진 모든 테넌트에 같이 넣는다 (회사별 코드 복제본이 있다)
-- ------------------------------------------------------------
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, sys_yn, ins_id)
SELECT co_cd, 'CYCLE_CD', v.sub_cd, v.code_nm, v.sort_no, 'Y', 'system'
  FROM (SELECT DISTINCT co_cd FROM tbl_code WHERE main_cd = 'CYCLE_CD') c
 -- 콤보 표시 순서 — 짧은 주기부터. 기존 Y(매년)·E(수시)도 뒤로 밀어 Q·H 와 겹치지 않게 한다
 CROSS JOIN (VALUES ('D', '매일', 1), ('W', '매주', 2), ('M', '매월', 3),
                    ('Q', '분기', 4), ('H', '반기', 5), ('Y', '매년', 6), ('E', '수시', 7)) AS v(sub_cd, code_nm, sort_no)
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
  sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- 공통코드는 회사별 복제본을 읽으므로(표준 '0000' 병합 없음) 코드를 가진 모든 테넌트에 함께 넣는다
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, sys_yn, ins_id)
SELECT c.co_cd, v.main_cd, v.sub_cd, v.code_nm, v.sort_no, 'Y', 'system'
  FROM (SELECT DISTINCT co_cd FROM tbl_code) c
 CROSS JOIN (VALUES
   ('nonwork-rule', '*',    '비영업일 처리',  0),
   ('nonwork-rule', 'keep', '그대로',        1),
   ('nonwork-rule', 'prev', '이전 영업일',   2),
   ('nonwork-rule', 'next', '다음 영업일',   3),
   ('NOTI_TYPE',    'TASK_DUE',  '작성예정 임박', 21),
   ('NOTI_TYPE',    'TASK_LATE', '작성기한 경과', 22)
 ) AS v(main_cd, sub_cd, code_nm, sort_no)
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
  code_nm = EXCLUDED.code_nm, sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 5. 화면·메뉴 표시명 — 사용양식 관리 / 문서주기관리
-- ------------------------------------------------------------
UPDATE tbl_screen SET scrn_nm = '사용양식 관리', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'hwp-template-management';
UPDATE tbl_menu   SET menu_nm = '사용양식 관리', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'hwp-template-management';
UPDATE tbl_screen SET scrn_nm = '문서주기관리', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'schedule-cycle-management';
UPDATE tbl_menu   SET menu_nm = '문서주기관리', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'schedule-cycle-management';

-- ------------------------------------------------------------
-- 6. sp_schedule_cycle_management_form_r_000 — 좌측 양식 목록 (조회 전용)
--    사용 중(use_yn=Y) 양식만. 주기 등록 여부·주기 코드까지 한 쿼리로 내려 badge 를 바로 그린다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_schedule_cycle_management_form_r_000(varchar, varchar, varchar);
CREATE FUNCTION sp_schedule_cycle_management_form_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_tmpl_cd: 헤더 양식코드 검색어. 공백이면 전체
    p_tmpl_cd varchar,
    -- p_tmpl_nm: 헤더 양식명 검색어. 공백이면 전체
    p_tmpl_nm varchar
)
RETURNS TABLE(
    tmpl_cd  varchar,
    tmpl_nm  varchar,
    -- 구분 — sys:시스템양식, usr:자사양식
    sys_yn   varchar,
    doc_kind varchar,
    -- 등록된 주기 코드 — 미등록이면 NULL
    cycle_cd varchar,
    -- 주기 등록 여부 Y/N — 삭제 버튼 활성 판정
    rule_yn  varchar
) LANGUAGE sql STABLE AS $$
    SELECT ct.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           lower(CASE WHEN COALESCE(ct.sys_yn, 'sys') IN ('N', 'n', 'usr') THEN 'usr' ELSE 'sys' END),
           t.doc_kind,
           r.cycle_cd,
           CASE WHEN r.idx IS NULL THEN 'N' ELSE 'Y' END
      FROM tbl_company_template ct
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
      -- 양식당 주기 1건이므로 LEFT JOIN 이 행을 늘리지 않는다
      LEFT JOIN tbl_schedule_rule r ON r.co_cd = ct.co_cd AND r.tmpl_cd = ct.tmpl_cd
     WHERE ct.co_cd = p_co_cd
       -- 미사용 양식은 문서를 만들 일이 없으므로 주기 대상이 아니다
       AND upper(COALESCE(ct.use_yn, 'N')) = 'Y'
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_schedule_cycle_management_form_r_000(varchar, varchar, varchar) IS
  '문서주기관리 좌측 양식 목록 — 사용 중 양식 + 구분 + 주기 등록여부(조회 전용)';

-- ------------------------------------------------------------
-- 7. sp_schedule_cycle_management_r_000 — 선택 양식의 주기 1건 + 반복 상세
--    상세는 jsonb 배열로 한 번에 내린다 — 화면이 두 번 호출하지 않게 한다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_schedule_cycle_management_r_000(varchar, varchar);
CREATE FUNCTION sp_schedule_cycle_management_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 좌측에서 선택한 양식코드
    p_tmpl_cd varchar
)
RETURNS TABLE(
    tmpl_cd      varchar,
    tmpl_nm      varchar,
    -- 관리 시작일 yyyyMMdd
    base_dt      varchar,
    cycle_cd     varchar,
    nonwork_rule varchar,
    -- 마감시각 HHMM
    due_time     varchar,
    dept_cd      varchar,
    -- 부서명 — 표시 전용. 저장은 dept_cd 로만 한다
    dept_nm      varchar,
    user_id      varchar,
    -- 담당자명 — 표시 전용. 저장은 user_id 로만 한다
    user_nm      varchar,
    use_yn       varchar,
    -- 반복 상세 [{detailTy, val1, val2}] — 없으면 빈 배열
    details      jsonb
) LANGUAGE sql STABLE AS $$
    SELECT r.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           r.base_dt, r.cycle_cd, r.nonwork_rule, r.due_time,
           r.dept_cd, d.dept_nm,
           r.user_id, u.user_nm,
           r.use_yn,
           COALESCE((
             SELECT jsonb_agg(jsonb_build_object('detailTy', x.detail_ty, 'val1', x.val1, 'val2', x.val2)
                              ORDER BY x.seq)
               FROM tbl_schedule_rule_detail x
              WHERE x.co_cd = r.co_cd AND x.tmpl_cd = r.tmpl_cd
           ), '[]'::jsonb)
      FROM tbl_schedule_rule r
      JOIN tbl_template t ON t.tmpl_cd = r.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = r.co_cd AND ct.tmpl_cd = r.tmpl_cd
      LEFT JOIN tbl_dept d ON d.co_cd = r.co_cd AND d.dept_cd = r.dept_cd
      LEFT JOIN tbl_user u ON u.co_cd = r.co_cd AND u.user_id = r.user_id
     WHERE r.co_cd = p_co_cd AND r.tmpl_cd = p_tmpl_cd;
$$;
COMMENT ON FUNCTION sp_schedule_cycle_management_r_000(varchar, varchar) IS
  '문서주기 단건 — 주기·비영업일·마감시각·담당(부서명·담당자명 조인) + 반복 상세 jsonb';

-- ------------------------------------------------------------
-- 8. sp_schedule_cycle_management_c_000 — 주기 저장 (양식당 1건 업서트 + 상세 전량 교체)
--    레거시 week_days·month_day·month_no 도 함께 채운다 — 구 배치·조회 SP 가 아직 읽는다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_schedule_cycle_management_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_payload: 화면 폼 1건 {tmplCd, baseDt, cycleCd, nonworkRule, dueTime, deptCd, userId, useYn, details[]}
    p_payload jsonb,
    -- p_id: JWT 작업자 ID — 감사 컬럼
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_tmpl_cd  varchar(40) := trim(COALESCE(p_payload ->> 'tmplCd', ''));
    v_cycle    varchar(1)  := upper(trim(COALESCE(p_payload ->> 'cycleCd', '')));
    v_nonwork  varchar(10) := lower(trim(COALESCE(NULLIF(p_payload ->> 'nonworkRule', ''), 'keep')));
    v_base     varchar(8)  := regexp_replace(COALESCE(p_payload ->> 'baseDt', ''), '[^0-9]', '', 'g');
    v_due      varchar(4)  := regexp_replace(COALESCE(p_payload ->> 'dueTime', ''), '[^0-9]', '', 'g');
    v_use      varchar(1);
    -- 레거시 호환 컬럼 — 상세에서 파생한다
    v_week     varchar(20);
    v_mday     int;
    v_mno      int;
BEGIN
    IF v_tmpl_cd = '' THEN
        RAISE EXCEPTION '주기를 설정할 양식을 선택하세요.' USING ERRCODE = '45000';
    END IF;
    -- 대문자 주기 도메인 — 분기(Q)·반기(H) 포함. 수시(E)는 일정 생성 대상이 아니라 화면에서 다루지 않는다
    IF v_cycle NOT IN ('D', 'W', 'M', 'Q', 'H', 'Y') THEN
        RAISE EXCEPTION '주기(매일/매주/매월/분기/반기/매년)를 선택하세요.' USING ERRCODE = '45000';
    END IF;
    IF v_nonwork NOT IN ('keep', 'prev', 'next') THEN
        RAISE EXCEPTION '비영업일 처리 방식이 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    IF length(v_base) <> 8 THEN
        RAISE EXCEPTION '관리 시작일을 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_company_template
         WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd AND upper(COALESCE(use_yn, 'N')) = 'Y'
    ) THEN
        RAISE EXCEPTION '사용 중인 양식만 문서주기를 설정할 수 있습니다.' USING ERRCODE = '45000';
    END IF;

    IF length(v_due) = 3 THEN v_due := lpad(v_due, 4, '0'); END IF;
    IF v_due = '' THEN v_due := '1800'; END IF;
    v_use := CASE lower(COALESCE(NULLIF(p_payload ->> 'useYn', ''), 'y')) WHEN 'n' THEN 'N' ELSE 'Y' END;

    -- 상세 전량 교체 — 부분 수정 대신 통째로 갈아 끼워 남은 행이 규칙을 오염시키지 않게 한다
    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd;
    INSERT INTO tbl_schedule_rule_detail(co_cd, tmpl_cd, seq, detail_ty, val1, val2)
    SELECT p_co_cd, v_tmpl_cd, d.ord,
           lower(trim(d.value ->> 'detailTy')),
           NULLIF(d.value ->> 'val1', '')::int,
           NULLIF(d.value ->> 'val2', '')::int
      FROM jsonb_array_elements(COALESCE(p_payload -> 'details', '[]'::jsonb)) WITH ORDINALITY AS d(value, ord)
     WHERE COALESCE(trim(d.value ->> 'detailTy'), '') <> '';

    SELECT string_agg(val1::text, ',' ORDER BY val1) INTO v_week
      FROM tbl_schedule_rule_detail
     WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd AND detail_ty = 'week-day' AND val1 IS NOT NULL;
    SELECT MIN(COALESCE(val2, val1)) INTO v_mday
      FROM tbl_schedule_rule_detail
     WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd AND detail_ty <> 'week-day';
    SELECT MIN(val1) INTO v_mno
      FROM tbl_schedule_rule_detail
     WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd AND detail_ty = 'year-month';

    INSERT INTO tbl_schedule_rule(
        co_cd, tmpl_cd, rule_seq, cycle_cd, nonwork_rule, week_days, month_day, month_no,
        due_time, dept_cd, user_id, use_yn, base_dt, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_tmpl_cd, 1, v_cycle, v_nonwork, v_week, v_mday, v_mno,
        v_due, NULLIF(p_payload ->> 'deptCd', ''), NULLIF(p_payload ->> 'userId', ''),
        v_use, v_base, p_id, now()
    )
    ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
        cycle_cd     = EXCLUDED.cycle_cd,
        nonwork_rule = EXCLUDED.nonwork_rule,
        week_days    = EXCLUDED.week_days,
        month_day    = EXCLUDED.month_day,
        month_no     = EXCLUDED.month_no,
        due_time     = EXCLUDED.due_time,
        dept_cd      = EXCLUDED.dept_cd,
        user_id      = EXCLUDED.user_id,
        use_yn       = EXCLUDED.use_yn,
        base_dt      = EXCLUDED.base_dt,
        upd_id       = p_id,
        upd_dt       = now();
END$$;
COMMENT ON PROCEDURE sp_schedule_cycle_management_c_000(varchar, jsonb, varchar) IS
  '문서주기 저장 — 양식당 1건 업서트 + 반복 상세 전량 교체. 담당자는 ID로만 저장한다';

-- ------------------------------------------------------------
-- 9. sp_schedule_cycle_management_d_000 — 주기 삭제
--    과거·진행분은 감사 대상이라 남기고, 아직 손대지 않은 미래 예정일만 정리한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_schedule_cycle_management_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 삭제 대상 양식코드
    p_tmpl_cd varchar,
    -- p_id: JWT 작업자 ID
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 오늘 — 이 날짜 이후의 미작성 예정일만 지운다
    v_today varchar(8) := to_char(current_date, 'YYYYMMDD');
BEGIN
    IF COALESCE(p_tmpl_cd, '') = '' THEN
        RAISE EXCEPTION '삭제할 문서주기를 선택하세요.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_schedule_task
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd
       AND base_dt > v_today
       -- 작성 시작 전(doc_idx 없음) TODO 만 — 진행·승인분은 보존
       AND status = 'TODO' AND doc_idx IS NULL;

    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    IF NOT FOUND THEN
        RAISE EXCEPTION '삭제할 문서주기를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END$$;
COMMENT ON PROCEDURE sp_schedule_cycle_management_d_000(varchar, varchar, varchar) IS
  '문서주기 삭제 — 규칙·상세 삭제 + 미래 미작성 예정일 정리(과거·진행분 보존)';

-- ------------------------------------------------------------
-- 10. sp_tbl_schedule_task_regen_c_000 — 예정일 재생성
--     날짜 계산은 Java CycleScheduleGenerator 가 하고, 이 SP 는 전달받은 날짜 배열만 반영한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_schedule_task_regen_c_000(
    -- p_co_cd: 회사코드
    p_co_cd        varchar,
    -- p_tmpl_cd: 양식코드
    p_tmpl_cd      varchar,
    -- p_dates: 예정일 배열 ["yyyyMMdd", …] — 생성기가 비영업일 이동까지 끝낸 결과
    p_dates        jsonb,
    -- p_due_time: 마감시각 HHMM
    p_due_time     varchar,
    -- p_dept_cd: 담당 부서코드
    p_dept_cd      varchar,
    -- p_user_id: 담당자 ID
    p_user_id      varchar,
    -- p_alarm_min: 마감 몇 분 전에 알릴지 — app.schedule.alarm-before-minutes
    p_alarm_min    int,
    -- p_id: 배치 또는 작업자 ID
    p_id           varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_today varchar(8) := to_char(current_date, 'YYYYMMDD');
    v_due   varchar(4) := COALESCE(NULLIF(regexp_replace(COALESCE(p_due_time, ''), '[^0-9]', '', 'g'), ''), '1800');
    v_min   int        := COALESCE(p_alarm_min, 60);
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_tmpl_cd, '') = '' THEN
        RAISE EXCEPTION '예정일 생성 대상이 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;

    -- 규칙에서 빠진 미래 예정일 정리 — 작성 시작 전(TODO·doc 없음) 만 지운다
    DELETE FROM tbl_schedule_task t
     WHERE t.co_cd = p_co_cd AND t.tmpl_cd = p_tmpl_cd
       AND t.base_dt > v_today
       AND t.status = 'TODO' AND t.doc_idx IS NULL
       AND NOT EXISTS (
           SELECT 1 FROM jsonb_array_elements_text(COALESCE(p_dates, '[]'::jsonb)) AS d(dt)
            WHERE d.dt = t.base_dt
       );

    -- 오늘 이후 예정일 적재 — 과거는 만들지 않는다(지난 일정을 새로 밀어 넣으면 즉시 LATE 가 된다)
    INSERT INTO tbl_schedule_task(
        co_cd, tmpl_cd, base_dt, due_dt, due_time, status, dept_cd, user_id,
        alarm_dt, alarm_send_yn, ins_id, ins_dt
    )
    SELECT p_co_cd, p_tmpl_cd, d.dt, d.dt, v_due, 'TODO',
           NULLIF(p_dept_cd, ''), NULLIF(p_user_id, ''),
           to_timestamp(d.dt || v_due, 'YYYYMMDDHH24MI') - make_interval(mins => v_min), 'N',
           p_id, now()
      FROM jsonb_array_elements_text(COALESCE(p_dates, '[]'::jsonb)) AS d(dt)
     WHERE d.dt ~ '^[0-9]{8}$' AND d.dt >= v_today
    ON CONFLICT (co_cd, tmpl_cd, base_dt) DO NOTHING;

    -- 이미 있던 미래 예정일의 마감·담당·알림시각을 규칙에 맞춘다
    UPDATE tbl_schedule_task t
       SET due_time = v_due,
           dept_cd  = NULLIF(p_dept_cd, ''),
           user_id  = NULLIF(p_user_id, ''),
           alarm_dt = to_timestamp(t.base_dt || v_due, 'YYYYMMDDHH24MI') - make_interval(mins => v_min),
           upd_id = p_id, upd_dt = now()
     WHERE t.co_cd = p_co_cd AND t.tmpl_cd = p_tmpl_cd
       AND t.base_dt > v_today
       AND t.status = 'TODO'
       AND (t.due_time IS DISTINCT FROM v_due
            OR t.dept_cd IS DISTINCT FROM NULLIF(p_dept_cd, '')
            OR t.user_id IS DISTINCT FROM NULLIF(p_user_id, '')
            OR t.alarm_dt IS NULL);
END$$;
COMMENT ON PROCEDURE sp_tbl_schedule_task_regen_c_000(varchar, varchar, jsonb, varchar, varchar, varchar, int, varchar) IS
  '예정일 재생성 — 생성기가 계산한 날짜 배열만 반영. 미래 미작성분만 지우고 알림시각까지 채운다';

-- ------------------------------------------------------------
-- 11. sp_tbl_notification_task_c_000 — 마감 임박 알림 적재
--     발송 대상 조회와 적재를 한 문장으로 묶어 중복 발송 여지를 없앤다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_notification_task_c_000(
    -- p_id: 배치 실행 주체 ID — 감사 로그용
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO tbl_notification(co_cd, noti_type_cd, user_id, title, content, link_scrn_cd, link_doc_idx)
    SELECT t.co_cd, 'TASK_DUE', u.user_id,
           '문서 작성 마감이 다가옵니다.',
           COALESCE(ct.tmpl_nm_ovr, tp.tmpl_nm, t.tmpl_cd) || ' · ' || t.due_dt || ' ' || COALESCE(t.due_time, ''),
           tp.scrn_cd, t.doc_idx
      FROM tbl_schedule_task t
      JOIN tbl_template tp ON tp.tmpl_cd = t.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = t.co_cd AND ct.tmpl_cd = t.tmpl_cd
      JOIN tbl_user u ON u.co_cd = t.co_cd AND u.use_yn = 'Y'
     WHERE t.status IN ('TODO', 'ING')
       AND t.alarm_send_yn = 'N'
       AND t.alarm_dt IS NOT NULL AND t.alarm_dt <= now()
       -- 담당자 지정이 있으면 그 사람에게만, 부서 지정만 있으면 그 부서 전원에게 보낸다
       AND (t.user_id IS NULL OR t.user_id = u.user_id)
       AND (t.dept_cd IS NULL OR t.dept_cd = u.dept_cd);

    UPDATE tbl_schedule_task
       SET alarm_send_yn = 'Y', upd_id = p_id, upd_dt = now()
     WHERE status IN ('TODO', 'ING')
       AND alarm_send_yn = 'N'
       AND alarm_dt IS NOT NULL AND alarm_dt <= now();
END$$;
COMMENT ON PROCEDURE sp_tbl_notification_task_c_000(varchar) IS
  '마감 임박 알림 — alarm_dt 도달분 1회 발송 후 alarm_send_yn=Y. 담당자·부서 배정 기준으로 대상 선정';

-- ------------------------------------------------------------
-- 12. sp_tbl_schedule_task_generate_c_000 — 일일 배치 (지연 처리 + 일일 알림)
--     주기 해석을 SQL 에서 걷어낸다 — 분기·반기·말일·비영업일을 SQL 이 알 필요가 없다
--     예정일 생성은 Java CycleScheduleGenerator + sp_tbl_schedule_task_regen_c_000 이 담당한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_schedule_task_generate_c_000(
    -- p_co_cd: 대상 회사코드. 공백이면 전체 활성 회사
    p_co_cd   varchar,
    -- p_base_dt: 기준일 YYYYMMDD
    p_base_dt varchar,
    -- p_id: 배치 또는 로그인 사용자 ID
    p_id      varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF COALESCE(p_base_dt, '') !~ '^[0-9]{8}$' THEN
        RAISE EXCEPTION '과제 생성 기준일 형식이 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;

    -- 마감 경과 미작성분 지연 처리 — 당일은 마감시각까지 기다린다
    UPDATE tbl_schedule_task
       SET status = 'LATE', upd_id = p_id, upd_dt = now()
     WHERE (COALESCE(p_co_cd, '') = '' OR co_cd = p_co_cd)
       AND status IN ('TODO', 'ING')
       AND (due_dt < p_base_dt
            OR (due_dt = p_base_dt AND COALESCE(due_time, '2359') < to_char(now(), 'HH24MI')));

    -- 오늘 할 일·지연 일일 알림 — 같은 내용은 하루 1건만 남긴다
    INSERT INTO tbl_notification(co_cd, noti_type_cd, user_id, title, content, link_scrn_cd, link_doc_idx)
    SELECT t.co_cd, CASE WHEN t.status = 'LATE' THEN 'TASK_LATE' ELSE 'TASK_DUE' END,
           u.user_id,
           CASE WHEN t.status = 'LATE' THEN '작성 기한이 지난 과제가 있습니다.' ELSE '오늘 작성할 문서 과제가 있습니다.' END,
           COALESCE(ct.tmpl_nm_ovr, tp.tmpl_nm, t.tmpl_cd),
           tp.scrn_cd, t.doc_idx
      FROM tbl_schedule_task t
      JOIN tbl_template tp ON tp.tmpl_cd = t.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = t.co_cd AND ct.tmpl_cd = t.tmpl_cd
      JOIN tbl_user u ON u.co_cd = t.co_cd AND u.use_yn = 'Y'
     WHERE (COALESCE(p_co_cd, '') = '' OR t.co_cd = p_co_cd)
       AND t.status IN ('TODO', 'LATE')
       AND t.base_dt <= p_base_dt
       AND (t.user_id IS NULL OR t.user_id = u.user_id)
       AND (t.dept_cd IS NULL OR t.dept_cd = u.dept_cd)
       AND NOT EXISTS (
           SELECT 1 FROM tbl_notification n
            WHERE n.co_cd = t.co_cd AND n.user_id = u.user_id
              AND n.noti_type_cd = CASE WHEN t.status = 'LATE' THEN 'TASK_LATE' ELSE 'TASK_DUE' END
              AND n.content = COALESCE(ct.tmpl_nm_ovr, tp.tmpl_nm, t.tmpl_cd)
              AND n.ins_dt::date = current_date
       );
END$$;
COMMENT ON PROCEDURE sp_tbl_schedule_task_generate_c_000(varchar, varchar, varchar) IS
  '일일 배치 — 마감 경과 지연 처리 + 오늘/지연 알림. 예정일 생성은 CycleScheduleGenerator 담당';

-- 51 의 미사용 생성 SP — 주기 해석이 두 곳에 남지 않게 제거한다
DROP PROCEDURE IF EXISTS sp_tbl_schedule_task_gen_c_000(varchar, varchar, varchar);

-- ------------------------------------------------------------
-- 13. 레거시 작성주기 SP 보정
--     구 화면(작성주기 그리드) 호출부가 남아 있어 유지하되, 두 가지를 고친다
--       가) 주기 화이트리스트에 Q·H 추가
--       나) user_id 컬럼에 담당자'명'이 들어가던 버그 → userId 만 저장
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_schedule_rule_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_payload: 구 작성주기 그리드 1행 {idx, tmplCd, cycleCd, baseDt, dueTime, deptCd, userId, useYn}
    p_payload jsonb,
    -- p_id: JWT 작업자 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_idx bigint := NULLIF(p_payload ->> 'idx', '')::bigint;
    v_tmpl_cd varchar(40) := trim(COALESCE(p_payload ->> 'tmplCd', ''));
    v_cycle_cd varchar(1) := upper(trim(COALESCE(p_payload ->> 'cycleCd', '')));
    v_base varchar(8) := regexp_replace(COALESCE(p_payload ->> 'baseDt', ''), '[^0-9]', '', 'g');
    v_due varchar(4) := regexp_replace(COALESCE(p_payload ->> 'dueTime', ''), '[^0-9]', '', 'g');
    v_month_day int;
    v_use varchar(1);
BEGIN
    IF v_tmpl_cd = '' OR v_cycle_cd NOT IN ('D', 'W', 'M', 'Q', 'H', 'Y') THEN
        RAISE EXCEPTION '양식과 작성주기(매일/매주/매월/분기/반기/매년)를 확인하세요.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd AND upper(use_yn) = 'Y'
    ) THEN
        RAISE EXCEPTION '사용 중인 업체 양식만 작성주기를 설정할 수 있습니다.' USING ERRCODE = '45000';
    END IF;
    IF length(v_base) = 8 THEN
        v_month_day := substring(v_base, 7, 2)::int;
    ELSE
        v_base := NULL;
        v_month_day := NULLIF(p_payload ->> 'monthDay', '')::int;
    END IF;
    IF length(v_due) = 3 THEN v_due := lpad(v_due, 4, '0'); END IF;
    IF v_due = '' THEN v_due := '1800'; END IF;
    v_use := CASE lower(COALESCE(NULLIF(p_payload ->> 'useYn', ''), 'y')) WHEN 'n' THEN 'N' ELSE 'Y' END;

    -- 양식당 1건 제약이라 idx 유무와 무관하게 업서트한다
    INSERT INTO tbl_schedule_rule(
        co_cd, tmpl_cd, rule_seq, cycle_cd, week_days, month_day, month_no, due_time,
        dept_cd, user_id, use_yn, base_dt, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_tmpl_cd, 1, v_cycle_cd, NULL, v_month_day, NULL, v_due,
        NULLIF(p_payload ->> 'deptCd', ''),
        -- 담당자는 ID 만 저장한다 — 이름을 넣으면 배정·알림 조인이 어긋난다
        NULLIF(p_payload ->> 'userId', ''),
        v_use, v_base, p_id, now()
    )
    ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
        cycle_cd  = EXCLUDED.cycle_cd,
        month_day = EXCLUDED.month_day,
        due_time  = EXCLUDED.due_time,
        dept_cd   = EXCLUDED.dept_cd,
        user_id   = EXCLUDED.user_id,
        use_yn    = EXCLUDED.use_yn,
        base_dt   = EXCLUDED.base_dt,
        upd_id    = p_id, upd_dt = now();
    -- v_idx 는 구 화면 호환 인자라 사용하지 않는다(양식코드가 곧 키다)
    PERFORM v_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_schedule_rule_c_000(varchar, jsonb, varchar) IS
  '구 작성주기 저장 — 양식당 1건 업서트, 담당자는 ID 저장, 주기 Q·H 허용';
