-- 역할 — 오늘 할 일·알림·개선조치·문서관계·감사자료 워크플로 저장프로시저
--
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) 기존 문서 허브를 기준으로 과제·개선조치·알림·관계를 전용 업무 흐름으로 완결한다
--   2) 생성 절은 재실행해도 (회사·양식·기준일) 과제를 중복 만들지 않아 배치·로그인 보정이 안전하다
--   3) 모든 변경은 테넌트 조건과 문서 존재 검증을 수행하고 Spring 트랜잭션 안에서만 실행한다

SET search_path TO sasshaccp;

-- 오늘 해당하는 활성 규칙을 과제로 보정하고, 마감 경과 미완료 건은 지연 처리한다.
CREATE OR REPLACE PROCEDURE sp_tbl_schedule_task_generate_c_000(
    -- p_co_cd: 생성 대상 회사코드. 공백이면 전체 활성 회사
    p_co_cd varchar,
    -- p_base_dt: 생성 기준일 YYYYMMDD
    p_base_dt varchar,
    -- p_id: 배치 또는 로그인 사용자 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_date date := to_date(p_base_dt, 'YYYYMMDD');
BEGIN
    IF COALESCE(p_base_dt, '') !~ '^[0-9]{8}$' THEN
        RAISE EXCEPTION '과제 생성 기준일 형식이 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;

    INSERT INTO tbl_schedule_task(co_cd, tmpl_cd, base_dt, due_dt, due_time, status, dept_cd, user_id, ins_id, ins_dt)
    SELECT r.co_cd, r.tmpl_cd, p_base_dt, p_base_dt, r.due_time, 'TODO', r.dept_cd, r.user_id, p_id, now()
      FROM tbl_schedule_rule r
      JOIN tbl_company c ON c.co_cd = r.co_cd AND c.use_yn = 'Y'
     WHERE r.use_yn = 'Y'
       AND (COALESCE(p_co_cd, '') = '' OR r.co_cd = p_co_cd)
       AND (
           r.cycle_cd = 'D'
           OR (r.cycle_cd = 'W' AND position(extract(isodow FROM v_date)::text IN COALESCE(r.week_days, '')) > 0)
           OR (r.cycle_cd = 'M' AND extract(day FROM v_date) = r.month_day)
           OR (r.cycle_cd = 'Y' AND extract(month FROM v_date) = r.month_no AND extract(day FROM v_date) = r.month_day)
       )
    ON CONFLICT (co_cd, tmpl_cd, base_dt) DO NOTHING;

    UPDATE tbl_schedule_task
       SET status = 'LATE', upd_id = p_id, upd_dt = now()
     WHERE (COALESCE(p_co_cd, '') = '' OR co_cd = p_co_cd)
       AND status IN ('TODO', 'ING')
       AND (due_dt < p_base_dt OR (due_dt = p_base_dt AND COALESCE(due_time, '2359') < to_char(now(), 'HH24MI')));

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

CREATE OR REPLACE FUNCTION sp_tbl_today_task_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_user_id: JWT 사용자 ID
    p_user_id varchar,
    -- p_base_dt: 조회 기준일 YYYYMMDD
    p_base_dt varchar
) RETURNS TABLE(
    task_idx bigint, task_type varchar, title varchar, status varchar, due_dt varchar, due_time varchar,
    link_scrn_cd varchar, doc_idx bigint, ref_idx bigint, content varchar
) LANGUAGE sql STABLE AS $$
    SELECT t.idx, 'TASK', COALESCE(ct.tmpl_nm_ovr, tp.tmpl_nm, t.tmpl_cd), t.status, t.due_dt, t.due_time,
           tp.scrn_cd, t.doc_idx, t.idx, NULL::varchar
      FROM tbl_schedule_task t
      JOIN tbl_template tp ON tp.tmpl_cd = t.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = t.co_cd AND ct.tmpl_cd = t.tmpl_cd
     WHERE t.co_cd = p_co_cd AND t.base_dt = p_base_dt AND t.status IN ('TODO','ING','LATE')
       AND (t.user_id IS NULL OR t.user_id = p_user_id)
    UNION ALL
    SELECT ca.idx, 'CA', '미완료 개선조치: ' || ca.ca_no, ca.status, ca.due_dt, NULL,
           'corrective-action-management', ca.src_doc_idx, ca.idx, ca.deviation_desc
      FROM tbl_corrective_action ca
     WHERE ca.co_cd = p_co_cd AND ca.status <> 'DONE'
       AND (ca.action_user_id IS NULL OR ca.action_user_id = p_user_id)
    ORDER BY 5 NULLS LAST, 6 NULLS LAST, 1;
$$;

CREATE OR REPLACE FUNCTION sp_tbl_notification_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_user_id: JWT 사용자 ID
    p_user_id varchar
) RETURNS TABLE(idx bigint, noti_type_cd varchar, title varchar, content varchar, link_scrn_cd varchar, link_doc_idx bigint, read_yn varchar, ins_dt timestamp)
LANGUAGE sql STABLE AS $$
    SELECT idx, noti_type_cd, title, content, link_scrn_cd, link_doc_idx, read_yn, ins_dt
      FROM tbl_notification
     WHERE co_cd = p_co_cd AND user_id = p_user_id
     ORDER BY read_yn, ins_dt DESC;
$$;

CREATE OR REPLACE PROCEDURE sp_tbl_notification_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_idx: 읽음 처리할 알림 idx
    p_idx bigint,
    -- p_user_id: JWT 사용자 ID
    p_user_id varchar
) LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tbl_notification SET read_yn = 'Y', read_dt = now()
     WHERE idx = p_idx AND co_cd = p_co_cd AND user_id = p_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION '알림을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
END$$;

CREATE OR REPLACE FUNCTION sp_tbl_corrective_action_r_000(
    p_co_cd varchar, p_status varchar, p_from_dt varchar, p_to_dt varchar
) RETURNS TABLE(idx bigint, ca_no varchar, occur_dt varchar, occur_place varchar, deviation_desc text, action_desc text, action_user_id varchar, due_dt varchar, status varchar, src_doc_idx bigint, src_doc_no varchar)
LANGUAGE sql STABLE AS $$
    SELECT ca.idx, ca.ca_no, ca.occur_dt, ca.occur_place, ca.deviation_desc, ca.action_desc,
           ca.action_user_id, ca.due_dt, ca.status, ca.src_doc_idx, d.doc_no
      FROM tbl_corrective_action ca
      LEFT JOIN tbl_document d ON d.co_cd = ca.co_cd AND d.idx = ca.src_doc_idx
     WHERE ca.co_cd = p_co_cd
       AND (COALESCE(p_status, '') = '' OR ca.status = p_status)
       AND (COALESCE(p_from_dt, '') = '' OR ca.occur_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR ca.occur_dt <= p_to_dt)
     ORDER BY ca.occur_dt DESC, ca.idx DESC;
$$;

CREATE OR REPLACE PROCEDURE sp_tbl_corrective_action_c_000(
    p_co_cd varchar, p_idx bigint, p_payload jsonb, p_id varchar
) LANGUAGE plpgsql AS $$
DECLARE v_idx bigint := COALESCE(p_idx, 0); v_no varchar(50);
BEGIN
    IF COALESCE(trim(p_payload->>'deviationDesc'), '') = '' OR COALESCE(p_payload->>'occurDt', '') !~ '^[0-9]{8}$' THEN
        RAISE EXCEPTION '발생일자와 이탈내용을 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF v_idx = 0 THEN
        v_no := 'CA-' || to_char(current_date, 'YYYYMMDD') || '-' || lpad((SELECT (count(*) + 1)::text FROM tbl_corrective_action WHERE co_cd = p_co_cd AND occur_dt = p_payload->>'occurDt'), 3, '0');
        INSERT INTO tbl_corrective_action(co_cd, ca_no, src_tmpl_cd, src_doc_idx, occur_dt, occur_place, deviation_desc, action_desc, action_user_id, action_dt, due_dt, status, ins_id)
        VALUES(p_co_cd, v_no, NULLIF(p_payload->>'srcTmplCd',''), NULLIF(p_payload->>'srcDocIdx','')::bigint, p_payload->>'occurDt', NULLIF(p_payload->>'occurPlace',''), p_payload->>'deviationDesc', NULLIF(p_payload->>'actionDesc',''), NULLIF(p_payload->>'actionUserId',''), NULLIF(p_payload->>'actionDt',''), NULLIF(p_payload->>'dueDt',''), COALESCE(NULLIF(p_payload->>'status',''),'OPEN'), p_id);
    ELSE
        UPDATE tbl_corrective_action SET occur_place = NULLIF(p_payload->>'occurPlace',''), deviation_desc = p_payload->>'deviationDesc', action_desc = NULLIF(p_payload->>'actionDesc',''), action_user_id = NULLIF(p_payload->>'actionUserId',''), action_dt = NULLIF(p_payload->>'actionDt',''), due_dt = NULLIF(p_payload->>'dueDt',''), status = COALESCE(NULLIF(p_payload->>'status',''), status), upd_id = p_id, upd_dt = now()
         WHERE idx = v_idx AND co_cd = p_co_cd;
        IF NOT FOUND THEN RAISE EXCEPTION '개선조치를 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_corrective_action_d_000(p_co_cd varchar, p_idx bigint, p_id varchar)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM tbl_corrective_action WHERE idx = p_idx AND co_cd = p_co_cd AND status <> 'DONE';
    IF NOT FOUND THEN RAISE EXCEPTION '완료된 개선조치는 삭제할 수 없습니다.' USING ERRCODE = '45000'; END IF;
END$$;

CREATE OR REPLACE FUNCTION sp_tbl_document_relation_r_000(p_co_cd varchar, p_doc_idx bigint)
RETURNS TABLE(idx bigint, src_doc_idx bigint, rel_type varchar, tgt_doc_idx bigint, tgt_doc_no varchar, tgt_title varchar, tgt_tmpl_cd varchar)
LANGUAGE sql STABLE AS $$
    SELECT r.idx, r.src_doc_idx, r.rel_type, r.tgt_doc_idx, d.doc_no, d.title, d.tmpl_cd
      FROM tbl_document_relation r JOIN tbl_document d ON d.idx = r.tgt_doc_idx AND d.co_cd = r.co_cd
     WHERE r.co_cd = p_co_cd AND r.src_doc_idx = p_doc_idx AND d.del_yn = 'N'
     ORDER BY r.idx;
$$;

CREATE OR REPLACE PROCEDURE sp_tbl_document_relation_c_000(p_co_cd varchar, p_src_doc_idx bigint, p_rel_type varchar, p_tgt_doc_idx bigint, p_id varchar)
LANGUAGE plpgsql AS $$
DECLARE v_src varchar; v_tgt varchar;
BEGIN
    SELECT tmpl_cd INTO v_src FROM tbl_document WHERE idx = p_src_doc_idx AND co_cd = p_co_cd AND del_yn = 'N';
    SELECT tmpl_cd INTO v_tgt FROM tbl_document WHERE idx = p_tgt_doc_idx AND co_cd = p_co_cd AND del_yn = 'N';
    IF v_src IS NULL OR v_tgt IS NULL THEN RAISE EXCEPTION '연결할 문서를 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    IF NOT ((p_rel_type = 'PLAN_REPORT' AND v_src = 'tmpl_prp-verify-plan' AND v_tgt = 'tmpl_prp-verify-report')
         OR (p_rel_type = 'tmpl_admin-edu-plan_LOG' AND v_src = 'tmpl_admin-edu-plan' AND v_tgt = 'tmpl_admin-edu-log')
         OR (p_rel_type = 'tmpl_prp-calib-target_LOG' AND v_src = 'tmpl_prp-calib-target' AND v_tgt IN ('tmpl_prp-calib-temp','tmpl_prp-calib-weight','tmpl_prp-calib-scale'))
         OR (p_rel_type = 'RECV_INVENTORY' AND v_src = 'tmpl_logis-receive-inspect' AND v_tgt IN ('INV', 'tmpl_logis-inventory-check'))) THEN
        RAISE EXCEPTION '허용되지 않은 문서 관계입니다.' USING ERRCODE = '45000';
    END IF;
    INSERT INTO tbl_document_relation(co_cd, src_doc_idx, rel_type, tgt_doc_idx, ins_id) VALUES(p_co_cd, p_src_doc_idx, p_rel_type, p_tgt_doc_idx, p_id) ON CONFLICT DO NOTHING;
END$$;

-- 31 에서 doc_kind·tmpl_cd·category_cd 가 추가되어 OUT 시그니처가 달라진다 — 재실행 안전 DROP
DROP FUNCTION IF EXISTS sp_tbl_audit_export_r_000(varchar, varchar, varchar, varchar);
CREATE OR REPLACE FUNCTION sp_tbl_audit_export_r_000(p_co_cd varchar, p_from_dt varchar, p_to_dt varchar, p_status varchar)
RETURNS TABLE(doc_idx bigint, doc_no varchar, tmpl_nm varchar, base_dt varchar, status varchar, writer_id varchar, approve_dt timestamp, file_cnt int, relation_cnt int, open_ca_cnt int)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, d.doc_no, COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd), d.base_dt, d.status, d.writer_id, d.approve_dt,
           (SELECT count(*)::int FROM tbl_document_file f WHERE f.co_cd=d.co_cd AND f.doc_idx=d.idx),
           (SELECT count(*)::int FROM tbl_document_relation r WHERE r.co_cd=d.co_cd AND (r.src_doc_idx=d.idx OR r.tgt_doc_idx=d.idx)),
           (SELECT count(*)::int FROM tbl_corrective_action ca WHERE ca.co_cd=d.co_cd AND ca.src_doc_idx=d.idx AND ca.status <> 'DONE')
      FROM tbl_document d LEFT JOIN tbl_template t ON t.tmpl_cd=d.tmpl_cd LEFT JOIN tbl_company_template ct ON ct.co_cd=d.co_cd AND ct.tmpl_cd=d.tmpl_cd
     WHERE d.co_cd=p_co_cd AND d.del_yn='N'
       AND (COALESCE(p_from_dt,'')='' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt,'')='' OR d.base_dt <= p_to_dt)
       AND (COALESCE(p_status,'')='' OR d.status=p_status)
     ORDER BY d.base_dt, d.doc_no;
$$;
