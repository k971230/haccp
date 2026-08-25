-- ============================================================
--  00_ddl.sql — 스키마 정본 (테이블·인덱스·제약·주석)
--
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) 실 DB(sasshaccp) 를 그대로 뜬 것이다. 누적 마이그레이션 133본을 이 한 본으로 접었다
--    2) 함수·프로시저는 01_sp.sql, 기초데이터는 02_seed.sql 이다. 이 순서로 적용한다
--    3) 화면 28개 정리(132·133) 가 반영된 상태다 — 빠진 표는 여기 없다
--
--  적용: psql -f 00_ddl.sql ; psql -f 01_sp.sql ; psql -f 02_seed.sql
-- ============================================================

SET search_path TO sasshaccp;

-- Name: sasshaccp; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA sasshaccp;


--
-- Name: SCHEMA sasshaccp; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA sasshaccp IS '식육포장처리업 HACCP 기록·결재·보관 SaaS 전용 스키마';


--
-- Name: tbl_approval_line; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_approval_line (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    appr_line_cd character varying(20) NOT NULL,
    appr_line_nm character varying(100) NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_approval_line; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_approval_line IS '결재선 헤더 — 업체별 결재 경로 정의. 템플릿별로 다른 결재선 지정 가능';


--
-- Name: COLUMN tbl_approval_line.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_approval_line.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_approval_line.appr_line_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line.appr_line_cd IS '결재선 코드 — 업체 내 유일';


--
-- Name: COLUMN tbl_approval_line.appr_line_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line.appr_line_nm IS '결재선명 — 일반 점검표 결재선 등';


--
-- Name: COLUMN tbl_approval_line.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_approval_line.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_approval_line.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_approval_line.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_approval_line.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line.upd_dt IS '최종수정일시';


--
-- Name: tbl_approval_line_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_approval_line ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_approval_line_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_approval_line_step; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_approval_line_step (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    appr_line_cd character varying(20) NOT NULL,
    step_no integer NOT NULL,
    role_cd character varying(20) NOT NULL,
    approver_id character varying(20),
    dept_cd character varying(20),
    pos_cd character varying(20),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL
);


--
-- Name: TABLE tbl_approval_line_step; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_approval_line_step IS '결재선 단계 — 작성자·검토자·승인자 순번 정의';


--
-- Name: COLUMN tbl_approval_line_step.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_approval_line_step.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_approval_line_step.appr_line_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.appr_line_cd IS '결재선 코드 — tbl_approval_line.appr_line_cd';


--
-- Name: COLUMN tbl_approval_line_step.step_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.step_no IS '단계 순번 — 1부터. 낮은 번호부터 순차 결재';


--
-- Name: COLUMN tbl_approval_line_step.role_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.role_cd IS '역할 — WRITE:작성자, REVIEW:검토자, APPROVE:승인자';


--
-- Name: COLUMN tbl_approval_line_step.approver_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.approver_id IS '결재자 로그인 ID — NULL이면(= 직위 기준 지정) dept_cd·pos_cd로 대상자를 찾는다';


--
-- Name: COLUMN tbl_approval_line_step.dept_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.dept_cd IS '결재 부서코드 — approver_id 미지정 시 사용';


--
-- Name: COLUMN tbl_approval_line_step.pos_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.pos_cd IS '결재 직위코드 — approver_id 미지정 시 사용';


--
-- Name: COLUMN tbl_approval_line_step.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_approval_line_step.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_approval_line_step.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_approval_line_step.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_approval_line_step.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_approval_line_step.use_yn IS '단계 사용여부 Y/N — N이면 상신 스냅샷에서 빠진다';


--
-- Name: tbl_approval_line_step_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_approval_line_step ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_approval_line_step_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_area_hygiene; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_area_hygiene (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    doc_idx bigint NOT NULL,
    base_dt character varying(8) NOT NULL,
    base_dt_to character varying(8),
    area_cd character varying(30),
    checker_id character varying(20),
    checker_nm character varying(50),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_area_hygiene; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_area_hygiene IS '작업장 환경위생관리 점검표 헤더 — 기간 단위 문서. 일자별 판정은 자식 테이블';


--
-- Name: COLUMN tbl_area_hygiene.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_area_hygiene.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_area_hygiene.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_area_hygiene.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_area_hygiene.doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_area_hygiene.doc_idx IS '문서 idx — tbl_document.idx와 1:1';


--
-- Name: COLUMN tbl_area_hygiene.base_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_area_hygiene.base_dt IS '기간 시작일 YYYYMMDD';


--
-- Name: COLUMN tbl_area_hygiene.base_dt_to; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_area_hygiene.base_dt_to IS '기간 종료일 YYYYMMDD';


--
-- Name: COLUMN tbl_area_hygiene.area_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_area_hygiene.area_cd IS '대상 구역코드 — tbl_work_area.area_cd. 구역을 나눠 작성할 때만 지정하고 NULL이면(= 전체 작업장 1장)';


--
-- Name: COLUMN tbl_area_hygiene.checker_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_area_hygiene.checker_id IS '점검자 로그인 ID';


--
-- Name: COLUMN tbl_area_hygiene.checker_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_area_hygiene.checker_nm IS '점검자명 — 작성 시점 스냅샷';


--
-- Name: COLUMN tbl_area_hygiene.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_area_hygiene.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_area_hygiene.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_area_hygiene.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_area_hygiene.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_area_hygiene.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_area_hygiene.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_area_hygiene.upd_dt IS '최종수정일시';


--
-- Name: tbl_area_hygiene_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_area_hygiene ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_area_hygiene_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_audit_log; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_audit_log (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    user_id character varying(20) NOT NULL,
    tbl_nm character varying(50) NOT NULL,
    tgt_idx bigint,
    action_cd character varying(20) NOT NULL,
    before_json jsonb,
    after_json jsonb,
    reason character varying(500),
    ip_addr character varying(45),
    ins_dt timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE tbl_audit_log; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_audit_log IS '변경 감사 로그 — HACCP 기록의 사후 수정 추적. 삭제하지 않는다';


--
-- Name: COLUMN tbl_audit_log.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_audit_log.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_audit_log.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_audit_log.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_audit_log.user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_audit_log.user_id IS '행위자 로그인 ID';


--
-- Name: COLUMN tbl_audit_log.tbl_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_audit_log.tbl_nm IS '대상 테이블명 — tbl_ 접두 포함';


--
-- Name: COLUMN tbl_audit_log.tgt_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_audit_log.tgt_idx IS '대상 행의 idx';


--
-- Name: COLUMN tbl_audit_log.action_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_audit_log.action_cd IS '행위 — I:등록, U:수정, D:삭제, APV:승인, RJT:반려, JUDGE_MOD:판정 수동변경, CO_SWITCH:업체 전환';


--
-- Name: COLUMN tbl_audit_log.before_json; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_audit_log.before_json IS '변경 전 값 JSON — 등록(I)일 때는 NULL';


--
-- Name: COLUMN tbl_audit_log.after_json; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_audit_log.after_json IS '변경 후 값 JSON — 삭제(D)일 때는 NULL';


--
-- Name: COLUMN tbl_audit_log.reason; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_audit_log.reason IS '사유 — 판정 수동변경·결재 반려 시 필수 입력값';


--
-- Name: COLUMN tbl_audit_log.ip_addr; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_audit_log.ip_addr IS '행위자 IP';


--
-- Name: COLUMN tbl_audit_log.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_audit_log.ins_dt IS '기록 일시';


--
-- Name: tbl_audit_log_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_audit_log ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_audit_log_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_calib_target; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_calib_target (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    doc_idx bigint NOT NULL,
    base_year character varying(4) NOT NULL,
    base_dt character varying(8),
    checker_id character varying(20),
    checker_nm character varying(50),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_calib_target; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_calib_target IS '검·교정 대상 점검표 헤더 — 표준기준서 관리번호 11. 연 1회 작성';


--
-- Name: COLUMN tbl_calib_target.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_calib_target.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_calib_target.doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target.doc_idx IS '문서 idx — tbl_document.idx와 1:1';


--
-- Name: COLUMN tbl_calib_target.base_year; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target.base_year IS '대상연도 YYYY';


--
-- Name: COLUMN tbl_calib_target.base_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target.base_dt IS '작성일자 YYYYMMDD';


--
-- Name: COLUMN tbl_calib_target.checker_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target.checker_id IS '작성자 로그인 ID';


--
-- Name: COLUMN tbl_calib_target.checker_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target.checker_nm IS '작성자명 — 작성 시점 스냅샷';


--
-- Name: COLUMN tbl_calib_target.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_calib_target.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_calib_target.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_calib_target.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target.upd_dt IS '최종수정일시';


--
-- Name: tbl_calib_target_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_calib_target ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_calib_target_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_calib_target_row; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_calib_target_row (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    hdr_idx bigint NOT NULL,
    row_seq integer NOT NULL,
    device_cd character varying(30) NOT NULL,
    device_nm character varying(200),
    official_calib_dt character varying(8),
    self_calib_dt character varying(8),
    next_calib_dt character varying(8),
    done_doc_idx bigint,
    remark character varying(500),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_calib_target_row; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_calib_target_row IS '계측기별 검·교정 계획·실적 — 행은 tbl_measuring_device 등록 대수만큼 자동 생성';


--
-- Name: COLUMN tbl_calib_target_row.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_calib_target_row.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_calib_target_row.hdr_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.hdr_idx IS '헤더 idx — tbl_calib_target.idx';


--
-- Name: COLUMN tbl_calib_target_row.row_seq; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.row_seq IS '행 순번';


--
-- Name: COLUMN tbl_calib_target_row.device_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.device_cd IS '계측기 코드 — tbl_measuring_device.device_cd';


--
-- Name: COLUMN tbl_calib_target_row.device_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.device_nm IS '계측기명 스냅샷 — 저울 1, 온도계(표준) 등';


--
-- Name: COLUMN tbl_calib_target_row.official_calib_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.official_calib_dt IS '공인기관 검·교정 일자 YYYYMMDD';


--
-- Name: COLUMN tbl_calib_target_row.self_calib_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.self_calib_dt IS '자체 검·교정 일자 YYYYMMDD';


--
-- Name: COLUMN tbl_calib_target_row.next_calib_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.next_calib_dt IS '차기 검·교정 예정일자 YYYYMMDD — 직전 교정일 + calib_cycle_month. 도래 시 알림';


--
-- Name: COLUMN tbl_calib_target_row.done_doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.done_doc_idx IS '실적 문서 idx — 자체 검·교정 일지 tbl_document.idx. 문서 연결로 근거를 남긴다';


--
-- Name: COLUMN tbl_calib_target_row.remark; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.remark IS '비고';


--
-- Name: COLUMN tbl_calib_target_row.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_calib_target_row.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_calib_target_row.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_calib_target_row.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_calib_target_row.upd_dt IS '최종수정일시';


--
-- Name: tbl_calib_target_row_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_calib_target_row ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_calib_target_row_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_ccp_cold_monitor; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_ccp_cold_monitor (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    doc_idx bigint NOT NULL,
    base_dt character varying(8) NOT NULL,
    ccp_cd character varying(20) NOT NULL,
    mng_user_id character varying(20),
    mng_nm character varying(50),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_ccp_cold_monitor; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_ccp_cold_monitor IS 'CCP 냉장보관 모니터링 일지 헤더 — 표준기준서 관리번호 2-1';


--
-- Name: COLUMN tbl_ccp_cold_monitor.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_ccp_cold_monitor.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_ccp_cold_monitor.doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor.doc_idx IS '문서 idx — tbl_document.idx와 1:1';


--
-- Name: COLUMN tbl_ccp_cold_monitor.base_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor.base_dt IS '작성일 YYYYMMDD';


--
-- Name: COLUMN tbl_ccp_cold_monitor.ccp_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor.ccp_cd IS '적용 CCP 코드 — tbl_ccp_limit.ccp_cd. 자동판정 기준의 출처';


--
-- Name: COLUMN tbl_ccp_cold_monitor.mng_user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor.mng_user_id IS '담당자 로그인 ID';


--
-- Name: COLUMN tbl_ccp_cold_monitor.mng_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor.mng_nm IS '담당자명 — 작성 시점 스냅샷';


--
-- Name: COLUMN tbl_ccp_cold_monitor.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_ccp_cold_monitor.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_ccp_cold_monitor.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_ccp_cold_monitor.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor.upd_dt IS '최종수정일시';


--
-- Name: tbl_ccp_cold_monitor_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_ccp_cold_monitor ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_ccp_cold_monitor_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_ccp_cold_monitor_temp; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_ccp_cold_monitor_temp (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    row_idx bigint NOT NULL,
    storage_cd character varying(30) NOT NULL,
    temp_val numeric(5,1),
    judge_cd character varying(1),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_ccp_cold_monitor_temp; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_ccp_cold_monitor_temp IS 'CCP 냉장보관 보관고별 온도 — A4 표의 보관고1~5 열을 세로 정규화한 결과';


--
-- Name: COLUMN tbl_ccp_cold_monitor_temp.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor_temp.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_ccp_cold_monitor_temp.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor_temp.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_ccp_cold_monitor_temp.row_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor_temp.row_idx IS '점검행 idx — tbl_ccp_cold_monitor_row.idx';


--
-- Name: COLUMN tbl_ccp_cold_monitor_temp.storage_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor_temp.storage_cd IS '보관고 코드 — tbl_storage.storage_cd. 화면 열 머리글의 근거';


--
-- Name: COLUMN tbl_ccp_cold_monitor_temp.temp_val; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor_temp.temp_val IS '측정 온도(섭씨) — 소수 1자리';


--
-- Name: COLUMN tbl_ccp_cold_monitor_temp.judge_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor_temp.judge_cd IS '셀 판정 — P:적합, F:부적합. 저장 SP가 tbl_ccp_limit 범위와 비교해 확정';


--
-- Name: COLUMN tbl_ccp_cold_monitor_temp.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor_temp.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_ccp_cold_monitor_temp.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor_temp.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_ccp_cold_monitor_temp.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor_temp.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_ccp_cold_monitor_temp.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_cold_monitor_temp.upd_dt IS '최종수정일시';


--
-- Name: tbl_ccp_cold_monitor_temp_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_ccp_cold_monitor_temp ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_ccp_cold_monitor_temp_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_ccp_generic_monitor; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_ccp_generic_monitor (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    doc_idx bigint NOT NULL,
    base_dt character varying(8) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ccp_cd character varying(30),
    diary_no character varying(20),
    limit_item_kind character varying(30),
    mng_user_id character varying(20),
    mng_nm character varying(50),
    form_src character varying(10) DEFAULT 'BASE'::character varying NOT NULL,
    co_form_idx bigint,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now() NOT NULL,
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_ccp_generic_monitor; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_ccp_generic_monitor IS '공통 CCP 모니터링 헤더 — 가열·세척·소독 등 비특화 공정 기록';


--
-- Name: COLUMN tbl_ccp_generic_monitor.form_src; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_generic_monitor.form_src IS '작성 양식 출처 — BASE 또는 CUSTOM. 과거 양식 이력 보존';


--
-- Name: tbl_ccp_generic_monitor_cell; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_ccp_generic_monitor_cell (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    row_idx bigint NOT NULL,
    item_cd character varying(30) NOT NULL,
    num_val numeric(14,3),
    txt_val character varying(500),
    judge_cd character varying(1),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now() NOT NULL,
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_ccp_generic_monitor_cell; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_ccp_generic_monitor_cell IS '공통 CCP 측정 셀 — 수치 또는 텍스트 값과 항목별 판정';


--
-- Name: COLUMN tbl_ccp_generic_monitor_cell.item_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_generic_monitor_cell.item_cd IS '한계항목 코드 — limit_item_kind 프리셋의 열 식별자';


--
-- Name: tbl_ccp_generic_monitor_cell_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_ccp_generic_monitor_cell ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_ccp_generic_monitor_cell_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_ccp_generic_monitor_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_ccp_generic_monitor ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_ccp_generic_monitor_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_ccp_generic_monitor_row; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_ccp_generic_monitor_row (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    monitor_idx bigint NOT NULL,
    row_seq integer NOT NULL,
    check_time character varying(10),
    judge_cd character varying(1),
    judge_mod_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    checker_id character varying(20),
    checker_nm character varying(50),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now() NOT NULL,
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    equip_nm character varying(100),
    product_nm character varying(100),
    phase_cd character varying(20),
    sign_img bytea
);


--
-- Name: TABLE tbl_ccp_generic_monitor_row; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_ccp_generic_monitor_row IS '공통 CCP 점검 행 — 시간별 측정·판정·점검자';


--
-- Name: COLUMN tbl_ccp_generic_monitor_row.sign_img; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_generic_monitor_row.sign_img IS '행 서명 이미지 바이너리 — 서명 적용 시점 tbl_user.sign_img 스냅샷';


--
-- Name: tbl_ccp_generic_monitor_row_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_ccp_generic_monitor_row ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_ccp_generic_monitor_row_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_ccp_limit; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_ccp_limit (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    ccp_cd character varying(20) NOT NULL,
    ccp_nm character varying(100) NOT NULL,
    proc_nm character varying(100),
    limit_type character varying(20) NOT NULL,
    min_val numeric(10,2),
    max_val numeric(10,2),
    unit_nm character varying(20),
    fe_size numeric(4,1),
    sts_size numeric(4,1),
    cycle_min integer,
    limit_rmk text,
    method_rmk text,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    form_title text,
    cycle_rmk text,
    improve_rmk text
);


--
-- Name: TABLE tbl_ccp_limit; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_ccp_limit IS 'CCP 한계기준 — 업체별 판정 기준값. 저장 SP 자동판정의 유일한 원천';


--
-- Name: COLUMN tbl_ccp_limit.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_ccp_limit.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_ccp_limit.ccp_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.ccp_cd IS 'CCP 코드 — CCP-1B(원료육 냉장), CCP-2P(금속검출), CCP-3B(완제품 냉장)';


--
-- Name: COLUMN tbl_ccp_limit.ccp_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.ccp_nm IS 'CCP 명칭';


--
-- Name: COLUMN tbl_ccp_limit.proc_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.proc_nm IS '해당 공정명 — 검증점검표 공정 구분에 사용';


--
-- Name: COLUMN tbl_ccp_limit.limit_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.limit_type IS '기준유형 — TEMP_RANGE(범위), TEMP_MAX(이하), TEMP_MIN(이상), METAL(금속검출)';


--
-- Name: COLUMN tbl_ccp_limit.min_val; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.min_val IS '하한값 — TEMP_RANGE일 때(= 범위 판정) 필수. 냉장 -2';


--
-- Name: COLUMN tbl_ccp_limit.max_val; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.max_val IS '상한값 — TEMP_RANGE/TEMP_MAX일 때 필수. 냉장 5, 냉동 -18';


--
-- Name: COLUMN tbl_ccp_limit.unit_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.unit_nm IS '단위 — 섭씨온도 등 화면 표기용';


--
-- Name: COLUMN tbl_ccp_limit.fe_size; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.fe_size IS 'Fe 시편 규격(mm) — METAL일 때만 사용';


--
-- Name: COLUMN tbl_ccp_limit.sts_size; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.sts_size IS 'STS 시편 규격(mm) — METAL일 때만 사용';


--
-- Name: COLUMN tbl_ccp_limit.cycle_min; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.cycle_min IS '모니터링 주기(분) — 작업 중 2시간마다면 120';


--
-- Name: COLUMN tbl_ccp_limit.limit_rmk; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.limit_rmk IS '한계기준 서술 문구 — A4 문서 상단 한계기준란에 그대로 출력';


--
-- Name: COLUMN tbl_ccp_limit.method_rmk; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.method_rmk IS '모니터링 방법 서술 문구 — A4 문서 상단 방법란에 그대로 출력';


--
-- Name: COLUMN tbl_ccp_limit.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_ccp_limit.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_ccp_limit.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_ccp_limit.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_ccp_limit.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_ccp_limit.form_title; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.form_title IS '일지 상단 제목 — CCP 콤보 변경 시 DocPaper 제목에 표시';


--
-- Name: COLUMN tbl_ccp_limit.cycle_rmk; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.cycle_rmk IS '주기 서술 문구 — A4 문서 상단 주기란에 그대로 출력';


--
-- Name: COLUMN tbl_ccp_limit.improve_rmk; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_limit.improve_rmk IS '개선조치방법 서술 — 기준관리·일지 상단';


--
-- Name: tbl_ccp_limit_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_ccp_limit ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_ccp_limit_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_ccp_metal_monitor; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_ccp_metal_monitor (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    doc_idx bigint NOT NULL,
    base_dt character varying(8) NOT NULL,
    ccp_cd character varying(20) NOT NULL,
    fe_size numeric(4,1),
    sts_size numeric(4,1),
    mng_user_id character varying(20),
    mng_nm character varying(50),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_ccp_metal_monitor; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_ccp_metal_monitor IS 'CCP 금속검출 모니터링 일지 헤더 — 표준기준서 관리번호 2-2';


--
-- Name: COLUMN tbl_ccp_metal_monitor.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_ccp_metal_monitor.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_ccp_metal_monitor.doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.doc_idx IS '문서 idx — tbl_document.idx와 1:1';


--
-- Name: COLUMN tbl_ccp_metal_monitor.base_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.base_dt IS '작성일 YYYYMMDD';


--
-- Name: COLUMN tbl_ccp_metal_monitor.ccp_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.ccp_cd IS '적용 CCP 코드 — tbl_ccp_limit.ccp_cd';


--
-- Name: COLUMN tbl_ccp_metal_monitor.fe_size; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.fe_size IS 'Fe 시편 규격(mm) — 작성 시점 한계기준 스냅샷. A4 한계기준란에 출력';


--
-- Name: COLUMN tbl_ccp_metal_monitor.sts_size; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.sts_size IS 'STS 시편 규격(mm) — 작성 시점 한계기준 스냅샷';


--
-- Name: COLUMN tbl_ccp_metal_monitor.mng_user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.mng_user_id IS '담당자 로그인 ID';


--
-- Name: COLUMN tbl_ccp_metal_monitor.mng_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.mng_nm IS '담당자명 — 작성 시점 스냅샷';


--
-- Name: COLUMN tbl_ccp_metal_monitor.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_ccp_metal_monitor.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_ccp_metal_monitor.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_ccp_metal_monitor.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_monitor.upd_dt IS '최종수정일시';


--
-- Name: tbl_ccp_metal_monitor_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_ccp_metal_monitor ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_ccp_metal_monitor_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_ccp_metal_pass_row; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_ccp_metal_pass_row (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    hdr_idx bigint NOT NULL,
    row_seq integer NOT NULL,
    product_cd character varying(30),
    product_nm character varying(200),
    pass_qty numeric(15,3),
    detect_qty numeric(15,3),
    unit_nm character varying(20),
    remark character varying(500),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_ccp_metal_pass_row; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_ccp_metal_pass_row IS '금속검출기 제품 통과 실적 — 통과량·검출량 기록';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.hdr_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.hdr_idx IS '헤더 idx — tbl_ccp_metal_monitor.idx';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.row_seq; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.row_seq IS '행 순번';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.product_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.product_cd IS '제품코드 — tbl_product.product_cd';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.product_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.product_nm IS '품명 — 작성 시점 스냅샷';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.pass_qty; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.pass_qty IS '통과량 — 금속검출기를 통과한 제품 수량';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.detect_qty; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.detect_qty IS '검출량 — 금속이 검출되어 배출된 수량. 0보다 클 때(= 이탈 발생) 개선조치 필수';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.unit_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.unit_nm IS '단위';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.remark; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.remark IS '특이사항';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_ccp_metal_pass_row.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_pass_row.upd_dt IS '최종수정일시';


--
-- Name: tbl_ccp_metal_pass_row_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_ccp_metal_pass_row ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_ccp_metal_pass_row_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_ccp_metal_sens_row; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_ccp_metal_sens_row (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    hdr_idx bigint NOT NULL,
    row_seq integer NOT NULL,
    phase_cd character varying(10) NOT NULL,
    product_cd character varying(30),
    product_nm character varying(200),
    check_time character varying(4),
    fe_only_cd character varying(1),
    sts_only_cd character varying(1),
    prod_only_cd character varying(1),
    fe_prod_cd character varying(1),
    sts_prod_cd character varying(1),
    judge_cd character varying(1),
    judge_mod_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    checker_id character varying(20),
    checker_nm character varying(50),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    place_nm character varying(100)
);


--
-- Name: TABLE tbl_ccp_metal_sens_row; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_ccp_metal_sens_row IS '금속검출기 감도 모니터링 행 — 시편 통과 시험 결과';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.hdr_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.hdr_idx IS '헤더 idx — tbl_ccp_metal_monitor.idx';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.row_seq; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.row_seq IS '행 순번';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.phase_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.phase_cd IS '점검 시점 — BEFORE:작업 전, DURING:작업 중, AFTER:작업 후';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.product_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.product_cd IS '제품코드 — tbl_product.product_cd';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.product_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.product_nm IS '품명 — 작성 시점 스냅샷';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.check_time; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.check_time IS '점검시간 HHMM';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.fe_only_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.fe_only_cd IS 'Fe 시편만 통과 결과 — O:검출, X:불검출';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.sts_only_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.sts_only_cd IS 'STS 시편만 통과 결과 — O:검출, X:불검출';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.prod_only_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.prod_only_cd IS '제품만 통과 결과 — O:검출, X:불검출. 정상이면 X(미검출)여야 한다';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.fe_prod_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.fe_prod_cd IS 'Fe 시편 + 제품 통과 결과 — O:검출, X:불검출';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.sts_prod_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.sts_prod_cd IS 'STS 시편 + 제품 통과 결과 — O:검출, X:불검출';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.judge_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.judge_cd IS '행 판정 — P:적합, F:부적합. 시편 시험 4종이 모두 검출(O)이면 적합';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.judge_mod_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.judge_mod_yn IS '판정 수동변경 여부 Y/N';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.checker_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.checker_id IS '점검자 로그인 ID';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.checker_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.checker_nm IS '점검자명 — 서명란 표기용 스냅샷';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_ccp_metal_sens_row.place_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_metal_sens_row.place_nm IS '위치(비고)';


--
-- Name: tbl_ccp_metal_sens_row_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_ccp_metal_sens_row ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_ccp_metal_sens_row_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_ccp_verify_check; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_ccp_verify_check (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    doc_idx bigint NOT NULL,
    base_dt character varying(8) NOT NULL,
    checker_id character varying(20),
    checker_nm character varying(50),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    monitor_chk_rmk text,
    ver_no integer DEFAULT 0 NOT NULL,
    checker_sign_img bytea,
    approver_id character varying(20),
    approver_nm character varying(50),
    approver_sign_img bytea,
    confirm_id character varying(20),
    confirm_nm character varying(50),
    confirm_sign_img bytea,
    special_note text,
    improve_note text,
    action_nm text
);


--
-- Name: TABLE tbl_ccp_verify_check; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_ccp_verify_check IS 'CCP 검증점검표 헤더 — 표준기준서 관리번호 3. 월 1회 작성';


--
-- Name: COLUMN tbl_ccp_verify_check.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_ccp_verify_check.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_ccp_verify_check.doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.doc_idx IS '문서 idx — tbl_document.idx와 1:1';


--
-- Name: COLUMN tbl_ccp_verify_check.base_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.base_dt IS '점검일자 YYYYMMDD';


--
-- Name: COLUMN tbl_ccp_verify_check.checker_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.checker_id IS '점검자 로그인 ID';


--
-- Name: COLUMN tbl_ccp_verify_check.checker_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.checker_nm IS '점검자명 — 작성 시점 스냅샷';


--
-- Name: COLUMN tbl_ccp_verify_check.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_ccp_verify_check.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_ccp_verify_check.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_ccp_verify_check.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_ccp_verify_check.monitor_chk_rmk; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.monitor_chk_rmk IS '모니터링 일지 확인 — SPAN 입력';


--
-- Name: COLUMN tbl_ccp_verify_check.ver_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.ver_no IS '작성에 쓴 자사 양식 버전 — tbl_tml_ccp_chk_ver.ver_no. 0이면 표준';


--
-- Name: COLUMN tbl_ccp_verify_check.approver_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.approver_nm IS '승인자명 스냅샷 — 지면 결재란';


--
-- Name: COLUMN tbl_ccp_verify_check.confirm_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.confirm_nm IS '확인자명 스냅샷 — 지면 하단 확인칸';


--
-- Name: COLUMN tbl_ccp_verify_check.special_note; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_check.special_note IS '특이사항 — 개행 보존';


--
-- Name: tbl_ccp_verify_check_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_ccp_verify_check ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_ccp_verify_check_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_ccp_verify_item; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_ccp_verify_item (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    hdr_idx bigint NOT NULL,
    row_seq integer NOT NULL,
    proc_cd character varying(20),
    proc_nm character varying(100),
    item_cd character varying(20),
    verify_desc character varying(500) NOT NULL,
    answer_cd character varying(1),
    record_desc character varying(500),
    ref_tmpl_cd character varying(20),
    ref_from_dt character varying(8),
    ref_to_dt character varying(8),
    ref_total_cnt integer,
    ref_ok_cnt integer,
    ref_ng_cnt integer,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    cycle_nm character varying(50),
    input_type character varying(20) DEFAULT 'radio'::character varying NOT NULL,
    unit_nm character varying(20)
);


--
-- Name: TABLE tbl_ccp_verify_item; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_ccp_verify_item IS 'CCP 검증 항목별 결과 — 예/아니오 응답과 근거 기록. 일지 건수는 자동 집계';


--
-- Name: COLUMN tbl_ccp_verify_item.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_ccp_verify_item.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_ccp_verify_item.hdr_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.hdr_idx IS '헤더 idx — tbl_ccp_verify_check.idx';


--
-- Name: COLUMN tbl_ccp_verify_item.row_seq; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.row_seq IS '행 순번';


--
-- Name: COLUMN tbl_ccp_verify_item.proc_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.proc_cd IS '공정 코드 — 원료육 냉장보관, 금속검출, 완제품 냉장보관';


--
-- Name: COLUMN tbl_ccp_verify_item.proc_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.proc_nm IS '공정명 — A4 표 좌측 병합 셀';


--
-- Name: COLUMN tbl_ccp_verify_item.item_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.item_cd IS '항목코드 — tbl_check_item.item_cd';


--
-- Name: COLUMN tbl_ccp_verify_item.verify_desc; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.verify_desc IS '검증 내용 — 표준기준서 질문 문구';


--
-- Name: COLUMN tbl_ccp_verify_item.answer_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.answer_cd IS '응답 — Y:예, N:아니오. N일 때(= 미준수) 개선조치 필수';


--
-- Name: COLUMN tbl_ccp_verify_item.record_desc; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.record_desc IS '기록 내용 — 확인 근거 서술. 자동 집계 항목은 SP가 문구를 생성해 채운다';


--
-- Name: COLUMN tbl_ccp_verify_item.ref_tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.ref_tmpl_cd IS '자동 집계 대상 템플릿 코드 — CCP_COLD, CCP_METAL 등. NULL이면(= 수동 입력 항목)';


--
-- Name: COLUMN tbl_ccp_verify_item.ref_from_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.ref_from_dt IS '집계 시작일 YYYYMMDD';


--
-- Name: COLUMN tbl_ccp_verify_item.ref_to_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.ref_to_dt IS '집계 종료일 YYYYMMDD';


--
-- Name: COLUMN tbl_ccp_verify_item.ref_total_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.ref_total_cnt IS '집계 결과 총 작성 건수';


--
-- Name: COLUMN tbl_ccp_verify_item.ref_ok_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.ref_ok_cnt IS '집계 결과 정상 건수';


--
-- Name: COLUMN tbl_ccp_verify_item.ref_ng_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.ref_ng_cnt IS '집계 결과 이탈 건수';


--
-- Name: COLUMN tbl_ccp_verify_item.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_ccp_verify_item.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_ccp_verify_item.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_ccp_verify_item.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_ccp_verify_item.cycle_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.cycle_nm IS '점검주기 문구 스냅샷 — 양식 항목에서 복사';


--
-- Name: COLUMN tbl_ccp_verify_item.input_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.input_type IS '입력유형 html-input-ty — 지면 렌더·필수값 판정 기준';


--
-- Name: COLUMN tbl_ccp_verify_item.unit_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_ccp_verify_item.unit_nm IS '단위 — 숫자 입력 항목 표시용';


--
-- Name: tbl_ccp_verify_item_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_ccp_verify_item ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_ccp_verify_item_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_check_item; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_check_item (
    idx bigint NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    item_cd character varying(20) NOT NULL,
    grp_cd character varying(20),
    grp_nm character varying(100),
    item_nm text NOT NULL,
    input_type character varying(20) DEFAULT 'OX'::character varying NOT NULL,
    unit_nm character varying(20),
    method_nm character varying(100),
    cycle_nm character varying(50),
    sort_no integer DEFAULT 0 NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_check_item; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_check_item IS '템플릿별 표준 점검항목 — 일일위생 15항목, 용수관리 11항목 등 표준기준서 문구 그대로';


--
-- Name: COLUMN tbl_check_item.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_check_item.tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.tmpl_cd IS '템플릿 코드 — tbl_template.tmpl_cd';


--
-- Name: COLUMN tbl_check_item.item_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.item_cd IS '항목코드 — 템플릿 내 유일';


--
-- Name: COLUMN tbl_check_item.grp_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.grp_cd IS '항목 구분코드 — BEFORE(작업 전), DURING(작업 중), AFTER(작업 후), TANK(저장탱크) 등';


--
-- Name: COLUMN tbl_check_item.grp_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.grp_nm IS '항목 구분명 — A4 표 좌측 병합 셀에 출력';


--
-- Name: COLUMN tbl_check_item.item_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.item_nm IS '점검항목 문구 — 표준기준서 원문';


--
-- Name: COLUMN tbl_check_item.input_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.input_type IS '입력유형 — OX(양호/불량), YN(예/아니오), JUDGE(적합/부적합), NUM(수치), TEXT(서술), TIME(시각)';


--
-- Name: COLUMN tbl_check_item.unit_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.unit_nm IS '단위 — input_type=NUM일 때 표기';


--
-- Name: COLUMN tbl_check_item.method_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.method_nm IS '점검방법 — 육안 등. 시설·설비 점검표처럼 표에 방법 열이 있는 양식에서만 사용';


--
-- Name: COLUMN tbl_check_item.cycle_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.cycle_nm IS '점검주기 — 1회/일 등. 방법 열과 함께 출력';


--
-- Name: COLUMN tbl_check_item.sort_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.sort_no IS '정렬순서';


--
-- Name: COLUMN tbl_check_item.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_check_item.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_check_item.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_check_item.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_check_item.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_check_item.upd_dt IS '최종수정일시';


--
-- Name: tbl_check_item_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_check_item ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_check_item_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_code; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_code (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    main_cd character varying(20) NOT NULL,
    sub_cd character varying(20) NOT NULL,
    code_nm character varying(100) NOT NULL,
    sort_no integer DEFAULT 0 NOT NULL,
    ref1 character varying(100),
    ref2 character varying(100),
    sys_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_code; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_code IS '공통코드 — sub_cd=* 행이 그룹 헤더';


--
-- Name: COLUMN tbl_code.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_code.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.co_cd IS '회사코드 — 테넌트 키. 0000일 때(= 플랫폼 표준코드) 전 업체 공용';


--
-- Name: COLUMN tbl_code.main_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.main_cd IS '대분류 코드';


--
-- Name: COLUMN tbl_code.sub_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.sub_cd IS '세부 코드 — *일 때(= 그룹 헤더행) code_nm이 그룹명';


--
-- Name: COLUMN tbl_code.code_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.code_nm IS '코드명';


--
-- Name: COLUMN tbl_code.sort_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.sort_no IS '정렬순서';


--
-- Name: COLUMN tbl_code.ref1; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.ref1 IS '참조값1 — 단위·기준값 등 코드별 부가정보';


--
-- Name: COLUMN tbl_code.ref2; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.ref2 IS '참조값2';


--
-- Name: COLUMN tbl_code.sys_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.sys_yn IS '시스템코드 여부 Y/N — Y일 때(= 플랫폼 고정코드) 업체 수정·삭제 불가';


--
-- Name: COLUMN tbl_code.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_code.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_code.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_code.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_code.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_code.upd_dt IS '최종수정일시';


--
-- Name: tbl_code_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_code ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_code_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_company; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_company (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    co_nm character varying(100) NOT NULL,
    co_nm_en character varying(100),
    biz_no character varying(20),
    co_no character varying(20),
    co_gbn character varying(10) DEFAULT '1'::character varying,
    ceo_nm character varying(50),
    tel_no character varying(20),
    fax_no character varying(20),
    zip_no character varying(10),
    addr_h character varying(200),
    addr_d character varying(200),
    open_dt character varying(8),
    haccp_type character varying(20) DEFAULT 'MEAT_PACK'::character varying,
    lic_no character varying(50),
    logo_path character varying(300),
    retention_month integer DEFAULT 24 NOT NULL,
    plan_cd character varying(20),
    svc_st_dt character varying(8),
    svc_fn_dt character varying(8),
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_company; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_company IS '회사(테넌트) 마스터 — SaaS 가입 업체 1행.';


--
-- Name: COLUMN tbl_company.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_company.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.co_cd IS '회사코드 — 테넌트 키. JWT LoginUser.coCd 및 전 SP p_co_cd 와 1:1';


--
-- Name: COLUMN tbl_company.co_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.co_nm IS '회사명 — 전 문서 A4 헤더에 출력';


--
-- Name: COLUMN tbl_company.co_nm_en; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.co_nm_en IS '회사명(영문)';


--
-- Name: COLUMN tbl_company.biz_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.biz_no IS '사업자등록번호';


--
-- Name: COLUMN tbl_company.co_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.co_no IS '법인등록번호';


--
-- Name: COLUMN tbl_company.co_gbn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.co_gbn IS '법인구분 — 1:법인, 2:개인 (tbl_code CO_GBN)';


--
-- Name: COLUMN tbl_company.ceo_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.ceo_nm IS '대표자명 — 회수 안내문·성적서 등에 출력';


--
-- Name: COLUMN tbl_company.tel_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.tel_no IS '대표 전화번호';


--
-- Name: COLUMN tbl_company.fax_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.fax_no IS '팩스번호 — 회수 시 거래처 통보에 사용';


--
-- Name: COLUMN tbl_company.zip_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.zip_no IS '우편번호';


--
-- Name: COLUMN tbl_company.addr_h; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.addr_h IS '주소';


--
-- Name: COLUMN tbl_company.addr_d; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.addr_d IS '상세주소';


--
-- Name: COLUMN tbl_company.open_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.open_dt IS '개업일 YYYYMMDD';


--
-- Name: COLUMN tbl_company.haccp_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.haccp_type IS 'HACCP 업종유형 — MEAT_PACK(식육포장처리업) 등. 표준 템플릿 패키지 선택 기준';


--
-- Name: COLUMN tbl_company.lic_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.lic_no IS '영업허가(신고)번호';


--
-- Name: COLUMN tbl_company.logo_path; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.logo_path IS '회사 로고 파일 경로 — A4 문서 헤더 출력용';


--
-- Name: COLUMN tbl_company.retention_month; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.retention_month IS '기본 문서 보존 개월수 — HACCP 기준 최소 24(2년)';


--
-- Name: COLUMN tbl_company.plan_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.plan_cd IS '요금제 코드 (tbl_code PLAN_CD)';


--
-- Name: COLUMN tbl_company.svc_st_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.svc_st_dt IS '서비스 시작일 YYYYMMDD';


--
-- Name: COLUMN tbl_company.svc_fn_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.svc_fn_dt IS '서비스 종료일 YYYYMMDD — 경과 시 로그인 차단';


--
-- Name: COLUMN tbl_company.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_company.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_company.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_company.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_company.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company.upd_dt IS '최종수정일시';


--
-- Name: tbl_company_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_company ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_company_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_company_template; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_company_template (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    tmpl_nm_ovr character varying(200),
    appr_line_cd character varying(20),
    cycle_cd character varying(10),
    retention_month integer,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    base_use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    co_form_idx bigint,
    sys_yn character varying(10) DEFAULT 'Y'::character varying NOT NULL,
    form_path character varying(300),
    default_file_idx bigint,
    current_file_idx bigint
);


--
-- Name: TABLE tbl_company_template; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_company_template IS '업체 사용양식 — 표준 템플릿을 업체가 복사·조정한 결과';


--
-- Name: COLUMN tbl_company_template.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_company_template.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_company_template.tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.tmpl_cd IS '템플릿 코드 — tbl_template.tmpl_cd';


--
-- Name: COLUMN tbl_company_template.tmpl_nm_ovr; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.tmpl_nm_ovr IS '문서명 오버라이드 — NULL이면(= 미지정) tbl_template.tmpl_nm 사용';


--
-- Name: COLUMN tbl_company_template.appr_line_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.appr_line_cd IS '적용 결재선 코드 — tbl_approval_line.appr_line_cd';


--
-- Name: COLUMN tbl_company_template.cycle_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.cycle_cd IS '작성주기 오버라이드 — NULL이면 표준 주기 사용';


--
-- Name: COLUMN tbl_company_template.retention_month; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.retention_month IS '보존 개월수 오버라이드 — NULL이면 표준값 사용';


--
-- Name: COLUMN tbl_company_template.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.use_yn IS '사용여부 Y/N — N일 때(= 우리 업체 미해당 양식) 메뉴·일정에서 제외';


--
-- Name: COLUMN tbl_company_template.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_company_template.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_company_template.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_company_template.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_company_template.base_use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.base_use_yn IS '기본 양식 사용여부 — Y일 때(= 플랫폼 기본), N일 때(= 활성 자사 양식) 사용';


--
-- Name: COLUMN tbl_company_template.co_form_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.co_form_idx IS '활성 자사 양식 idx — base_use_yn=N일 때 tbl_company_form.idx';


--
-- Name: COLUMN tbl_company_template.sys_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.sys_yn IS '시스템유무 — sys=플랫폼, usr=사용자(공통코드 sys-yn)';


--
-- Name: COLUMN tbl_company_template.form_path; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.form_path IS '회사 전용 HWP 원본 상대경로 — CustomTemplates/{co_cd}/{tmpl_cd}/{파일명}. NULL이면 tbl_template.form_path';


--
-- Name: COLUMN tbl_company_template.default_file_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.default_file_idx IS '기본 제공 파일 idx — 시스템 양식은 표준 원본, 자사양식은 최초 등록본. 초기화 대상. NULL이면 초기화 불가';


--
-- Name: COLUMN tbl_company_template.current_file_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template.current_file_idx IS '현재 적용 파일 idx — 업로드·불러오기로만 바뀐다. form_path 와 항상 같은 파일을 가리킨다';


--
-- Name: tbl_company_template_file; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_company_template_file (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    file_seq integer NOT NULL,
    file_nm character varying(300) NOT NULL,
    form_path character varying(300) NOT NULL,
    file_size bigint,
    src_ty character varying(10) DEFAULT 'usr'::character varying NOT NULL,
    del_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now()
);


--
-- Name: TABLE tbl_company_template_file; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_company_template_file IS '양식 파일 이력 — 업로드·기본제공 파일 1행씩. 불러오기(과거 버전 적용)·초기화의 원천';


--
-- Name: COLUMN tbl_company_template_file.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template_file.idx IS 'PK 자동 채번 대리키 — default_file_idx/current_file_idx가 이 값을 가리킨다';


--
-- Name: COLUMN tbl_company_template_file.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template_file.co_cd IS '회사코드 — 테넌트 키. 다른 회사 파일이 섞이지 않는다';


--
-- Name: COLUMN tbl_company_template_file.tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template_file.tmpl_cd IS '양식코드 — tbl_company_template.tmpl_cd';


--
-- Name: COLUMN tbl_company_template_file.file_seq; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template_file.file_seq IS '버전 순번 — 업로드 순서. 물리 파일명 접미(_v{seq})와 같다';


--
-- Name: COLUMN tbl_company_template_file.file_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template_file.file_nm IS '표시 파일명 — 업로드 원본명(번호 접두 제거)';


--
-- Name: COLUMN tbl_company_template_file.form_path; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template_file.form_path IS 'APP_FILE_ROOT 기준 상대 경로 — 표준은 HaccpTemplates/{tmpl_cd}/, 자사는 CustomTemplates/{co_cd}/{tmpl_cd}/';


--
-- Name: COLUMN tbl_company_template_file.file_size; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template_file.file_size IS '바이트 크기 — 표시·검증용. 기본제공 시딩분은 NULL';


--
-- Name: COLUMN tbl_company_template_file.src_ty; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template_file.src_ty IS '출처 — sys:프로그램 기본 제공본, usr:회사 업로드본';


--
-- Name: COLUMN tbl_company_template_file.del_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template_file.del_yn IS '삭제여부 Y/N — Y일 때(= 양식 삭제됨) 불러오기 목록에서 제외하고 파일은 남긴다';


--
-- Name: COLUMN tbl_company_template_file.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template_file.ins_id IS '업로드자 ID';


--
-- Name: COLUMN tbl_company_template_file.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_company_template_file.ins_dt IS '업로드 일시 — 불러오기 목록 표시 기준';


--
-- Name: tbl_company_template_file_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_company_template_file ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_company_template_file_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_company_template_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_company_template ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_company_template_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_corrective_action; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_corrective_action (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    ca_no character varying(50) NOT NULL,
    src_tmpl_cd character varying(40),
    src_doc_idx bigint,
    src_row_idx bigint,
    occur_dt character varying(8) NOT NULL,
    occur_place character varying(200),
    deviation_desc text NOT NULL,
    action_desc text,
    action_user_id character varying(20),
    action_dt character varying(8),
    confirm_user_id character varying(20),
    confirm_dt character varying(8),
    due_dt character varying(8),
    status character varying(4) DEFAULT 'OPEN'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    action_user_nm character varying(50),
    confirm_user_nm character varying(50)
);


--
-- Name: TABLE tbl_corrective_action; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_corrective_action IS '이탈·개선조치 — 전 점검표 공통. 미완료 건은 대시보드에 노출되고 결재 상신을 막는다';


--
-- Name: COLUMN tbl_corrective_action.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_corrective_action.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_corrective_action.ca_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.ca_no IS '개선조치 번호 — 업체 내 유일';


--
-- Name: COLUMN tbl_corrective_action.src_tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.src_tmpl_cd IS '발생 출처 템플릿 코드 — 어느 점검표에서 나왔는지';


--
-- Name: COLUMN tbl_corrective_action.src_doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.src_doc_idx IS '발생 출처 문서 idx — tbl_document.idx';


--
-- Name: COLUMN tbl_corrective_action.src_row_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.src_row_idx IS '발생 출처 상세행 idx — 어느 행의 부적합인지 특정';


--
-- Name: COLUMN tbl_corrective_action.occur_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.occur_dt IS '발생일자 YYYYMMDD';


--
-- Name: COLUMN tbl_corrective_action.occur_place; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.occur_place IS '발생장소 — 작업장·보관고·설비명';


--
-- Name: COLUMN tbl_corrective_action.deviation_desc; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.deviation_desc IS '이탈내용 — 기준을 벗어난 사실 서술';


--
-- Name: COLUMN tbl_corrective_action.action_desc; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.action_desc IS '개선조치 및 결과 — 조치 내용과 결과 서술';


--
-- Name: COLUMN tbl_corrective_action.action_user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.action_user_id IS '조치자 로그인 ID';


--
-- Name: COLUMN tbl_corrective_action.action_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.action_dt IS '조치일자 YYYYMMDD';


--
-- Name: COLUMN tbl_corrective_action.confirm_user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.confirm_user_id IS '확인자 로그인 ID — A4 조치자 확인란';


--
-- Name: COLUMN tbl_corrective_action.confirm_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.confirm_dt IS '확인일자 YYYYMMDD';


--
-- Name: COLUMN tbl_corrective_action.due_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.due_dt IS '조치 기한 YYYYMMDD — 경과 시 알림';


--
-- Name: COLUMN tbl_corrective_action.status; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.status IS '상태 — OPEN:미조치, ING:조치중, DONE:완료';


--
-- Name: COLUMN tbl_corrective_action.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_corrective_action.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_corrective_action.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_corrective_action.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_corrective_action.action_user_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.action_user_nm IS '조치자 표시명 — A4 푸터 서명란 자유입력';


--
-- Name: COLUMN tbl_corrective_action.confirm_user_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_corrective_action.confirm_user_nm IS '확인자 표시명 — A4 푸터 확인란 자유입력';


--
-- Name: tbl_corrective_action_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_corrective_action ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_corrective_action_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_dept; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_dept (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    dept_cd character varying(20) NOT NULL,
    dept_nm character varying(100) NOT NULL,
    h_dept_cd character varying(20),
    sort_no integer DEFAULT 0 NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_dept; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_dept IS '부서 — 업체별 조직도. 문서 결재란·작성자 부서 표기에 사용';


--
-- Name: COLUMN tbl_dept.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_dept.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_dept.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_dept.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_dept.dept_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_dept.dept_cd IS '부서코드 — 업체 내 유일';


--
-- Name: COLUMN tbl_dept.dept_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_dept.dept_nm IS '부서명';


--
-- Name: COLUMN tbl_dept.h_dept_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_dept.h_dept_cd IS '상위 부서코드 — NULL이거나 공백일 때(= 최상위 노드) 트리 루트';


--
-- Name: COLUMN tbl_dept.sort_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_dept.sort_no IS '정렬순서 — 같은 상위 안에서의 표시 순서';


--
-- Name: COLUMN tbl_dept.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_dept.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_dept.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_dept.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_dept.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_dept.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_dept.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_dept.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_dept.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_dept.upd_dt IS '최종수정일시';


--
-- Name: tbl_dept_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_dept ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_dept_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_doc_no_rule; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_doc_no_rule (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    prefix character varying(20),
    date_fmt character varying(10) DEFAULT 'YYYYMMDD'::character varying,
    seq_len integer DEFAULT 3 NOT NULL,
    reset_cycle character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    last_reset_key character varying(10),
    last_seq integer DEFAULT 0 NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_doc_no_rule; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_doc_no_rule IS '문서번호 채번 규칙 — 사용자에게 보이는 업무번호(doc_no) 생성. idx와 별개';


--
-- Name: COLUMN tbl_doc_no_rule.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_doc_no_rule.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_doc_no_rule.tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.tmpl_cd IS '템플릿 코드 — tbl_template.tmpl_cd';


--
-- Name: COLUMN tbl_doc_no_rule.prefix; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.prefix IS '문서번호 접두 — CCP-B 등';


--
-- Name: COLUMN tbl_doc_no_rule.date_fmt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.date_fmt IS '일자 형식 — YYYYMMDD / YYYYMM / YYYY. 공백이면 일자 미포함';


--
-- Name: COLUMN tbl_doc_no_rule.seq_len; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.seq_len IS '일련번호 자릿수 — 3이면 001부터';


--
-- Name: COLUMN tbl_doc_no_rule.reset_cycle; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.reset_cycle IS '일련번호 리셋 주기 — D:일, M:월, Y:년, N:리셋 없음';


--
-- Name: COLUMN tbl_doc_no_rule.last_reset_key; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.last_reset_key IS '마지막 리셋 기준키 — reset_cycle에 맞춘 일자 문자열. 값이 바뀌면 last_seq를 0으로 되돌린다';


--
-- Name: COLUMN tbl_doc_no_rule.last_seq; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.last_seq IS '마지막 채번 일련번호';


--
-- Name: COLUMN tbl_doc_no_rule.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_doc_no_rule.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_doc_no_rule.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_doc_no_rule.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_doc_no_rule.upd_dt IS '최종수정일시';


--
-- Name: tbl_doc_no_rule_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_doc_no_rule ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_doc_no_rule_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_document; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_document (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    doc_kind character varying(10) NOT NULL,
    doc_no character varying(50) NOT NULL,
    base_dt character varying(8) NOT NULL,
    base_dt_to character varying(8),
    title character varying(300),
    status character varying(3) DEFAULT 'TMP'::character varying NOT NULL,
    appr_line_cd character varying(20),
    writer_id character varying(20),
    write_dt timestamp without time zone,
    reviewer_id character varying(20),
    review_dt timestamp without time zone,
    approver_id character varying(20),
    approve_dt timestamp without time zone,
    reject_reason character varying(500),
    ver_no integer DEFAULT 1 NOT NULL,
    retention_until character varying(8),
    del_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    form_src character varying(10) DEFAULT 'BASE'::character varying NOT NULL,
    co_form_idx bigint,
    remark character varying(500)
);


--
-- Name: TABLE tbl_document; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_document IS '문서 공통 관리정보 — 모든 문서 1행. 사용자는 목록에서 DB형·문서형을 구분하지 않는다';


--
-- Name: COLUMN tbl_document.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.idx IS 'PK 자동 채번 대리키 — 업무 테이블이 doc_idx로 참조';


--
-- Name: COLUMN tbl_document.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_document.tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.tmpl_cd IS '템플릿 코드 — tbl_template.tmpl_cd';


--
-- Name: COLUMN tbl_document.doc_kind; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.doc_kind IS '문서 유형 — DB:전용 화면, HWP:rhwp 문서작성형';


--
-- Name: COLUMN tbl_document.doc_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.doc_no IS '문서번호 — tbl_doc_no_rule로 채번한 사용자 표기용 번호';


--
-- Name: COLUMN tbl_document.base_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.base_dt IS '기준일자 YYYYMMDD — 작성일 또는 점검일. 일정·검색의 기준';


--
-- Name: COLUMN tbl_document.base_dt_to; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.base_dt_to IS '기준종료일자 YYYYMMDD — 용수관리처럼 기간 단위 문서일 때만 사용';


--
-- Name: COLUMN tbl_document.title; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.title IS '문서 제목 — 미입력 시 템플릿명 + 기준일자로 자동 생성';


--
-- Name: COLUMN tbl_document.status; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.status IS '문서상태 — WRK:작성중, REQ:검토요청, REV:검토완료, APV:승인완료, RJT:반려';


--
-- Name: COLUMN tbl_document.appr_line_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.appr_line_cd IS '적용 결재선 — 작성 시점의 tbl_company_template.appr_line_cd 스냅샷';


--
-- Name: COLUMN tbl_document.writer_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.writer_id IS '작성자 로그인 ID';


--
-- Name: COLUMN tbl_document.write_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.write_dt IS '작성(상신) 일시';


--
-- Name: COLUMN tbl_document.reviewer_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.reviewer_id IS '검토자 로그인 ID';


--
-- Name: COLUMN tbl_document.review_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.review_dt IS '검토 일시';


--
-- Name: COLUMN tbl_document.approver_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.approver_id IS '승인자 로그인 ID';


--
-- Name: COLUMN tbl_document.approve_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.approve_dt IS '승인 일시';


--
-- Name: COLUMN tbl_document.reject_reason; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.reject_reason IS '반려 사유 — status=RJT일 때 필수';


--
-- Name: COLUMN tbl_document.ver_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.ver_no IS '현재 버전 — 승인 후 수정 시 증가하고 직전 내용은 tbl_document_version에 스냅샷';


--
-- Name: COLUMN tbl_document.retention_until; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.retention_until IS '보존 만료일 YYYYMMDD — base_dt + 보존 개월수. 경과 전 삭제 차단';


--
-- Name: COLUMN tbl_document.del_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.del_yn IS '삭제여부 Y/N — 물리 삭제 대신 논리 삭제. 승인 문서는 Y로도 바꿀 수 없다';


--
-- Name: COLUMN tbl_document.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_document.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_document.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_document.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_document.form_src; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.form_src IS '작성 시점 양식 출처 — BASE 기본양식, CUSTOM 자사양식';


--
-- Name: COLUMN tbl_document.co_form_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.co_form_idx IS '작성 시점 자사 양식 idx — CUSTOM일 때만 값 보관';


--
-- Name: COLUMN tbl_document.remark; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document.remark IS '비고 — 상신자가 결재자에게 남기는 문서 단위 메모. 결재완료(APV) 전까지만 수정 가능';


--
-- Name: tbl_document_approval; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_document_approval (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    doc_idx bigint NOT NULL,
    step_no integer NOT NULL,
    role_cd character varying(20) NOT NULL,
    approver_id character varying(20),
    approver_nm character varying(50),
    result_cd character varying(1) DEFAULT 'W'::character varying NOT NULL,
    opinion character varying(500),
    act_dt timestamp without time zone,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    sign_img bytea
);


--
-- Name: TABLE tbl_document_approval; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_document_approval IS '문서 결재 이력 — A4 결재란 3칸의 실제 데이터 원천';


--
-- Name: COLUMN tbl_document_approval.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_document_approval.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_document_approval.doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.doc_idx IS '문서 idx — tbl_document.idx';


--
-- Name: COLUMN tbl_document_approval.step_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.step_no IS '단계 순번 — 결재선 step_no 스냅샷';


--
-- Name: COLUMN tbl_document_approval.role_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.role_cd IS '역할 — WRITE:작성자, REVIEW:검토자, APPROVE:승인자';


--
-- Name: COLUMN tbl_document_approval.approver_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.approver_id IS '결재자 로그인 ID';


--
-- Name: COLUMN tbl_document_approval.approver_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.approver_nm IS '결재자명 — 결재 시점 스냅샷. 이후 사용자명이 바뀌어도 문서는 당시 이름을 유지';


--
-- Name: COLUMN tbl_document_approval.result_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.result_cd IS '결재 결과 — W:대기, A:승인, R:반려';


--
-- Name: COLUMN tbl_document_approval.opinion; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.opinion IS '결재 의견 — 반려(R)일 때 필수';


--
-- Name: COLUMN tbl_document_approval.act_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.act_dt IS '결재 처리 일시';


--
-- Name: COLUMN tbl_document_approval.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_document_approval.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_document_approval.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_document_approval.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_document_approval.sign_img; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_approval.sign_img IS '서명 이미지 바이너리 — 결재 시점 tbl_user.sign_img 스냅샷';


--
-- Name: tbl_document_approval_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_document_approval ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_document_approval_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_document_file; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_document_file (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    doc_idx bigint NOT NULL,
    file_kind character varying(10) NOT NULL,
    file_nm character varying(300) NOT NULL,
    file_path character varying(500) NOT NULL,
    file_size bigint,
    mime_type character varying(100),
    sort_no integer DEFAULT 0 NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now()
);


--
-- Name: TABLE tbl_document_file; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_document_file IS '문서 첨부·원본·PDF — 경로만 저장. 실제 파일은 업체별 볼륨 경로에 보관';


--
-- Name: COLUMN tbl_document_file.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_file.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_document_file.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_file.co_cd IS '회사코드 — 테넌트 키. 파일 저장 경로의 첫 세그먼트이기도 하다';


--
-- Name: COLUMN tbl_document_file.doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_file.doc_idx IS '문서 idx — tbl_document.idx';


--
-- Name: COLUMN tbl_document_file.file_kind; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_file.file_kind IS '파일 종류 — HWP_SRC:한글 원본, PDF:완료본, ATTACH:일반첨부, PHOTO:사진';


--
-- Name: COLUMN tbl_document_file.file_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_file.file_nm IS '원본 파일명 — 사용자가 올린 그대로. 다운로드 시 이 이름으로 내려준다';


--
-- Name: COLUMN tbl_document_file.file_path; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_file.file_path IS '저장 경로 — {root}/{co_cd}/{yyyy}/{mm}/{idx}_{원본명}';


--
-- Name: COLUMN tbl_document_file.file_size; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_file.file_size IS '파일 크기(byte)';


--
-- Name: COLUMN tbl_document_file.mime_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_file.mime_type IS 'MIME 타입';


--
-- Name: COLUMN tbl_document_file.sort_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_file.sort_no IS '정렬순서 — 사진 첨부 표시 순서';


--
-- Name: COLUMN tbl_document_file.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_file.ins_id IS '업로더 로그인 ID';


--
-- Name: COLUMN tbl_document_file.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_file.ins_dt IS '업로드 일시';


--
-- Name: tbl_document_file_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_document_file ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_document_file_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_document_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_document ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_document_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_document_relation; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_document_relation (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    src_doc_idx bigint NOT NULL,
    rel_type character varying(20) NOT NULL,
    tgt_doc_idx bigint NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now()
);


--
-- Name: TABLE tbl_document_relation; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_document_relation IS '문서 간 연결 — 관련 문서 바로가기와 감사자료 묶음 출력의 근거';


--
-- Name: COLUMN tbl_document_relation.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_relation.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_document_relation.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_relation.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_document_relation.src_doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_relation.src_doc_idx IS '출발 문서 idx — tbl_document.idx';


--
-- Name: COLUMN tbl_document_relation.rel_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_relation.rel_type IS '관계 유형 — PLAN_CHECK(계획-점검), CHECK_RESULT(점검-결과), RESULT_CA(결과-개선조치), EDU_PLAN_LOG(교육계획-교육일지), CALIB_TARGET_LOG(검교정대상-일지)';


--
-- Name: COLUMN tbl_document_relation.tgt_doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_relation.tgt_doc_idx IS '도착 문서 idx — tbl_document.idx';


--
-- Name: COLUMN tbl_document_relation.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_relation.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_document_relation.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_relation.ins_dt IS '최초입력일시';


--
-- Name: tbl_document_relation_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_document_relation ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_document_relation_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_document_version; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_document_version (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    doc_idx bigint NOT NULL,
    ver_no integer NOT NULL,
    snap_json jsonb,
    file_path character varying(500),
    change_reason character varying(500),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now()
);


--
-- Name: TABLE tbl_document_version; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_document_version IS '문서 버전 스냅샷 — 승인 후 수정 시 직전 상태 보존. 감사 대응 필수';


--
-- Name: COLUMN tbl_document_version.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_version.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_document_version.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_version.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_document_version.doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_version.doc_idx IS '문서 idx — tbl_document.idx';


--
-- Name: COLUMN tbl_document_version.ver_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_version.ver_no IS '스냅샷 버전 — 이 행이 보존하는 직전 버전 번호';


--
-- Name: COLUMN tbl_document_version.snap_json; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_version.snap_json IS '본문 스냅샷 JSON — DB형일 때(= 헤더+상세 전체 직렬화)';


--
-- Name: COLUMN tbl_document_version.file_path; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_version.file_path IS '원본 파일 스냅샷 경로 — 문서형일 때(= HWPX/PDF 사본)';


--
-- Name: COLUMN tbl_document_version.change_reason; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_version.change_reason IS '변경 사유 — 승인 문서 수정 시 필수 입력';


--
-- Name: COLUMN tbl_document_version.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_version.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_document_version.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_document_version.ins_dt IS '최초입력일시';


--
-- Name: tbl_document_version_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_document_version ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_document_version_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_grid_pref; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_grid_pref (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    user_id character varying(20) NOT NULL,
    scrn_cd character varying(30) NOT NULL,
    grid_id character varying(30) NOT NULL,
    pref_json text NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_grid_pref; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_grid_pref IS '사용자별 그리드 열 설정 — 숨김·순서·너비만 저장. 정렬·필터는 세션 보관';


--
-- Name: COLUMN tbl_grid_pref.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_grid_pref.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_grid_pref.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_grid_pref.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_grid_pref.user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_grid_pref.user_id IS '로그인 ID — tbl_user.user_id';


--
-- Name: COLUMN tbl_grid_pref.scrn_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_grid_pref.scrn_cd IS '화면코드 — tbl_screen.scrn_cd';


--
-- Name: COLUMN tbl_grid_pref.grid_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_grid_pref.grid_id IS '그리드 식별자 — MesEditableGrid persistId (한 화면에 그리드가 여럿일 때 구분)';


--
-- Name: COLUMN tbl_grid_pref.pref_json; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_grid_pref.pref_json IS '열 설정 JSON — gridPref v2 직렬화 문자열';


--
-- Name: COLUMN tbl_grid_pref.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_grid_pref.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_grid_pref.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_grid_pref.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_grid_pref.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_grid_pref.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_grid_pref.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_grid_pref.upd_dt IS '최종수정일시';


--
-- Name: tbl_grid_pref_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_grid_pref ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_grid_pref_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_html_form_ver; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_html_form_ver (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ver_no integer NOT NULL,
    ver_nm character varying(100) NOT NULL,
    apply_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ver_cd character varying(20) NOT NULL,
    CONSTRAINT ck_tbl_html_form_ver_apply CHECK (((apply_yn)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT ck_tbl_html_form_ver_no CHECK ((ver_no >= 1)),
    CONSTRAINT ck_tbl_html_form_ver_use CHECK (((use_yn)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[])))
);


--
-- Name: COLUMN tbl_html_form_ver.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_html_form_ver.idx IS '대리키 PK — identity';


--
-- Name: COLUMN tbl_html_form_ver.ver_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_html_form_ver.ver_no IS '표시 순번 — 1부터. 0은 표준 가상행. 항목·작성 문서가 참조하므로 재사용 금지';


--
-- Name: COLUMN tbl_html_form_ver.ver_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_html_form_ver.ver_nm IS '버전명 — 유니크 아님';


--
-- Name: COLUMN tbl_html_form_ver.apply_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_html_form_ver.apply_yn IS '작성 신규 적용. 없으면(전부 N) 표준';


--
-- Name: COLUMN tbl_html_form_ver.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_html_form_ver.use_yn IS '사용여부 — N=소프트 삭제';


--
-- Name: COLUMN tbl_html_form_ver.ver_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_html_form_ver.ver_cd IS '버전코드 — 표준 가상행 0.1. 활성(use_yn=Y)만 업체+양식당 유니크. 삭제 후 재사용 가능';


--
-- Name: tbl_html_form_ver_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_html_form_ver ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_html_form_ver_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_html_form_ver_item; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_html_form_ver_item (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ver_no integer NOT NULL,
    item_cd character varying(20) NOT NULL,
    sort_no integer DEFAULT 0 NOT NULL,
    cycle_nm character varying(50),
    grp_nm character varying(100),
    item_nm text NOT NULL,
    input_type character varying(20) DEFAULT 'radio'::character varying NOT NULL,
    unit_nm character varying(20),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: COLUMN tbl_html_form_ver_item.input_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_html_form_ver_item.input_type IS 'html-input-ty — radio / radio-num / radio-text / num / text';


--
-- Name: tbl_html_form_ver_item_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_html_form_ver_item ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_html_form_ver_item_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_html_hyg_prc_ver; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_html_hyg_prc_ver (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ver_no integer NOT NULL,
    ver_cd character varying(20) NOT NULL,
    ver_nm character varying(100) NOT NULL,
    apply_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    CONSTRAINT ck_tbl_html_hyg_prc_ver_apply CHECK (((apply_yn)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT ck_tbl_html_hyg_prc_ver_no CHECK ((ver_no >= 1)),
    CONSTRAINT ck_tbl_html_hyg_prc_ver_use CHECK (((use_yn)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[])))
);


--
-- Name: TABLE tbl_html_hyg_prc_ver; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_html_hyg_prc_ver IS '일반위생·공정점검 자사 양식 버전 — 예시는 html_hyg_prc_000 가상';


--
-- Name: tbl_html_hyg_prc_ver_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_html_hyg_prc_ver ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_html_hyg_prc_ver_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_html_hyg_prc_ver_item; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_html_hyg_prc_ver_item (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ver_no integer NOT NULL,
    item_cd character varying(20) NOT NULL,
    sort_no integer DEFAULT 0 NOT NULL,
    cycle_nm character varying(50),
    grp_nm character varying(100),
    item_nm text NOT NULL,
    input_type character varying(20) DEFAULT 'radio'::character varying NOT NULL,
    unit_nm character varying(20),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_html_hyg_prc_ver_item; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_html_hyg_prc_ver_item IS '일반위생·공정점검 자사 양식 항목';


--
-- Name: tbl_html_hyg_prc_ver_item_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_html_hyg_prc_ver_item ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_html_hyg_prc_ver_item_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_hyg_process; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_hyg_process (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    doc_idx bigint NOT NULL,
    base_dt character varying(8) NOT NULL,
    checker_nm character varying(50),
    ver_no integer DEFAULT 0 NOT NULL,
    special_note text,
    improve_note text,
    action_nm text,
    confirm_nm text,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    checker_id character varying(20),
    checker_sign_img bytea,
    approver_id character varying(20),
    approver_nm character varying(50),
    approver_sign_img bytea,
    confirm_id character varying(20),
    confirm_sign_img bytea
);


--
-- Name: COLUMN tbl_hyg_process.checker_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_hyg_process.checker_id IS '점검자 로그인 ID — 저장 시 이름 매칭';


--
-- Name: COLUMN tbl_hyg_process.checker_sign_img; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_hyg_process.checker_sign_img IS '점검자 서명 스냅샷 — 없으면 이름만';


--
-- Name: COLUMN tbl_hyg_process.approver_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_hyg_process.approver_nm IS '승인자명 — 헤더 스냅샷';


--
-- Name: COLUMN tbl_hyg_process.approver_sign_img; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_hyg_process.approver_sign_img IS '승인자 서명 스냅샷 — 없으면 이름만';


--
-- Name: COLUMN tbl_hyg_process.confirm_sign_img; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_hyg_process.confirm_sign_img IS '확인 서명 스냅샷 — 없으면 confirm_nm만';


--
-- Name: tbl_hyg_process_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_hyg_process ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_hyg_process_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_hyg_process_item; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_hyg_process_item (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    hdr_idx bigint NOT NULL,
    sort_no integer NOT NULL,
    item_cd character varying(20) NOT NULL,
    cycle_nm character varying(50),
    grp_nm character varying(100),
    item_nm text,
    input_type character varying(20) DEFAULT 'radio'::character varying NOT NULL,
    unit_nm character varying(20),
    yn character varying(1),
    val_nm text,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: COLUMN tbl_hyg_process_item.input_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_hyg_process_item.input_type IS 'html-input-ty — radio / radio-num / radio-text / num / text';


--
-- Name: tbl_hyg_process_item_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_hyg_process_item ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_hyg_process_item_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_inv_txn; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_inv_txn (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    txn_dt character varying(8) NOT NULL,
    txn_gbn character varying(3) NOT NULL,
    item_gbn character varying(10) NOT NULL,
    material_cd character varying(30),
    product_cd character varying(30),
    item_nm character varying(200) NOT NULL,
    partner_cd character varying(30),
    partner_nm character varying(200),
    qty numeric(15,3) DEFAULT 0 NOT NULL,
    unit_nm character varying(20),
    lot_no character varying(50),
    make_dt character varying(8),
    expire_dt character varying(8),
    storage_cd character varying(30),
    src_tmpl_cd character varying(40),
    src_doc_idx bigint,
    remark character varying(500),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_inv_txn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_inv_txn IS '입·출고 수불 이력 — HACCP 기록용. 실물 재고관리(MES)가 아니므로 단가·금액을 다루지 않는다';


--
-- Name: COLUMN tbl_inv_txn.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_inv_txn.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_inv_txn.txn_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.txn_dt IS '거래일자 YYYYMMDD';


--
-- Name: COLUMN tbl_inv_txn.txn_gbn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.txn_gbn IS '구분 — IN:입고, OUT:출고';


--
-- Name: COLUMN tbl_inv_txn.item_gbn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.item_gbn IS '품목구분 — MEAT:원료육, SUB:부재료, PACK:포장재, PROD:완제품';


--
-- Name: COLUMN tbl_inv_txn.material_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.material_cd IS '원부재료 코드 — tbl_material.material_cd. 완제품일 때 NULL';


--
-- Name: COLUMN tbl_inv_txn.product_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.product_cd IS '제품코드 — tbl_product.product_cd. 원부재료일 때 NULL';


--
-- Name: COLUMN tbl_inv_txn.item_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.item_nm IS '품명 스냅샷 — 마스터가 바뀌어도 당시 명칭 유지';


--
-- Name: COLUMN tbl_inv_txn.partner_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.partner_cd IS '거래처 코드 — tbl_partner.partner_cd';


--
-- Name: COLUMN tbl_inv_txn.partner_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.partner_nm IS '거래처명 스냅샷';


--
-- Name: COLUMN tbl_inv_txn.qty; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.qty IS '수량 — 부호 없이 양수. 방향은 txn_gbn으로 판단';


--
-- Name: COLUMN tbl_inv_txn.unit_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.unit_nm IS '단위';


--
-- Name: COLUMN tbl_inv_txn.lot_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.lot_no IS '로트번호 — 회수 시 추적 단위';


--
-- Name: COLUMN tbl_inv_txn.make_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.make_dt IS '제조일자 YYYYMMDD';


--
-- Name: COLUMN tbl_inv_txn.expire_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.expire_dt IS '소비기한 YYYYMMDD — 경과 임박 시 알림';


--
-- Name: COLUMN tbl_inv_txn.storage_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.storage_cd IS '보관고 코드 — tbl_storage.storage_cd';


--
-- Name: COLUMN tbl_inv_txn.src_tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.src_tmpl_cd IS '출처 템플릿 코드 — RECV_INSP(입고검사), WASTE(폐기) 등. NULL이면(= 직접 입력)';


--
-- Name: COLUMN tbl_inv_txn.src_doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.src_doc_idx IS '출처 문서 idx — tbl_document.idx. 자동 생성 내역의 원본 추적';


--
-- Name: COLUMN tbl_inv_txn.remark; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.remark IS '비고';


--
-- Name: COLUMN tbl_inv_txn.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_inv_txn.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_inv_txn.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_inv_txn.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_inv_txn.upd_dt IS '최종수정일시';


--
-- Name: tbl_inv_txn_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_inv_txn ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_inv_txn_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_login_log; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_login_log (
    idx bigint NOT NULL,
    co_cd character varying(10),
    user_id character varying(20) NOT NULL,
    sid character varying(36),
    login_dt timestamp without time zone DEFAULT now() NOT NULL,
    logout_dt timestamp without time zone,
    result_cd character varying(1) NOT NULL,
    fail_reason character varying(200),
    ip_addr character varying(45),
    user_agent character varying(500),
    device_gbn character varying(10),
    token_exp_dt timestamp without time zone
);


--
-- Name: TABLE tbl_login_log; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_login_log IS '로그인 이력 — 성공·실패·잠금 전수 기록. 감사 대응 및 계정 도용 추적용';


--
-- Name: COLUMN tbl_login_log.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_login_log.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_login_log.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_login_log.co_cd IS '회사코드 — 실패 시 아이디가 존재하지 않으면 NULL이 될 수 있다';


--
-- Name: COLUMN tbl_login_log.user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_login_log.user_id IS '시도한 로그인 ID — 존재하지 않는 아이디도 그대로 기록';


--
-- Name: COLUMN tbl_login_log.sid; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_login_log.sid IS '세션 UUID — 성공 시에만 발급. JWT sid 클레임 및 tbl_view_log.sid와 조인';


--
-- Name: COLUMN tbl_login_log.login_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_login_log.login_dt IS '로그인 시도 일시';


--
-- Name: COLUMN tbl_login_log.logout_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_login_log.logout_dt IS '로그아웃 일시 — 명시적 로그아웃 또는 토큰 만료 시 갱신. NULL이면(= 미종료 세션)';


--
-- Name: COLUMN tbl_login_log.result_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_login_log.result_cd IS '결과 — S:성공, F:실패(비밀번호 불일치·미존재·미사용), L:잠금(실패 임계 초과)';


--
-- Name: COLUMN tbl_login_log.fail_reason; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_login_log.fail_reason IS '실패 사유 — 서버 로그용 기술 문구. 사용자에게는 노출하지 않는다';


--
-- Name: COLUMN tbl_login_log.ip_addr; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_login_log.ip_addr IS '접속 IP — IPv6 대비 45자';


--
-- Name: COLUMN tbl_login_log.user_agent; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_login_log.user_agent IS '브라우저 User-Agent 원문';


--
-- Name: COLUMN tbl_login_log.device_gbn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_login_log.device_gbn IS '기기구분 — PC / MOBILE / TABLET';


--
-- Name: COLUMN tbl_login_log.token_exp_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_login_log.token_exp_dt IS '발급 토큰 만료 예정일시';


--
-- Name: tbl_login_log_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_login_log ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_login_log_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_material; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_material (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    material_cd character varying(30) NOT NULL,
    material_nm character varying(200) NOT NULL,
    material_gbn character varying(10) NOT NULL,
    spec_nm character varying(100),
    unit_nm character varying(20),
    storage_type character varying(10),
    partner_cd character varying(30),
    shelf_life_day integer,
    haccp_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    insp_std text,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_material; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_material IS '원·부재료 — 입고검사 일지, 입출고 재고 점검표의 품명 선택 원천';


--
-- Name: COLUMN tbl_material.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_material.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_material.material_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.material_cd IS '원부재료 코드 — 업체 내 유일';


--
-- Name: COLUMN tbl_material.material_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.material_nm IS '원부재료명';


--
-- Name: COLUMN tbl_material.material_gbn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.material_gbn IS '구분 — MEAT:원료육, SUB:부재료, PACK:포장재';


--
-- Name: COLUMN tbl_material.spec_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.spec_nm IS '규격';


--
-- Name: COLUMN tbl_material.unit_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.unit_nm IS '단위';


--
-- Name: COLUMN tbl_material.storage_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.storage_type IS '보관유형 — COLD:냉장, FROZEN:냉동, ROOM:상온';


--
-- Name: COLUMN tbl_material.partner_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.partner_cd IS '주 공급처 코드 — tbl_partner.partner_cd. 입고검사 반입처 기본값';


--
-- Name: COLUMN tbl_material.shelf_life_day; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.shelf_life_day IS '소비기한 일수';


--
-- Name: COLUMN tbl_material.haccp_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.haccp_yn IS '공급처 HACCP 적용여부 Y/N — 입고검사 HACCP 적용확인란 기본값';


--
-- Name: COLUMN tbl_material.insp_std; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.insp_std IS '입고검사 기준 — 육안검사 기준 문구. 입고검사 화면 상단에 안내';


--
-- Name: COLUMN tbl_material.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_material.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_material.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_material.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_material.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_material.upd_dt IS '최종수정일시';


--
-- Name: tbl_material_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_material ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_material_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_measuring_device; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_measuring_device (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    device_cd character varying(30) NOT NULL,
    device_nm character varying(200) NOT NULL,
    device_type character varying(20) NOT NULL,
    model_nm character varying(100),
    maker_nm character varying(100),
    spec_nm character varying(100),
    tolerance_val numeric(10,3),
    tolerance_unit character varying(20),
    calib_cycle_month integer DEFAULT 12 NOT NULL,
    place_nm character varying(100),
    sort_no integer DEFAULT 0 NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_measuring_device; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_measuring_device IS '계측기 — 저울·온도계·타이머·조도계·표준기. 검·교정 대상 목록과 차기 예정일 알림의 원천';


--
-- Name: COLUMN tbl_measuring_device.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_measuring_device.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_measuring_device.device_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.device_cd IS '계측기 코드 — 업체 내 유일';


--
-- Name: COLUMN tbl_measuring_device.device_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.device_nm IS '계측기명 — 저울 1, 온도계(표준) 등';


--
-- Name: COLUMN tbl_measuring_device.device_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.device_type IS '유형 — SCALE:저울, THERMO:온도계, TIMER:타이머, LUX:조도계, RECORDER:자동온도기록장치, STANDARD:표준기';


--
-- Name: COLUMN tbl_measuring_device.model_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.model_nm IS '모델명';


--
-- Name: COLUMN tbl_measuring_device.maker_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.maker_nm IS '제조사';


--
-- Name: COLUMN tbl_measuring_device.spec_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.spec_nm IS '규격 — 측정 범위·최소눈금';


--
-- Name: COLUMN tbl_measuring_device.tolerance_val; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.tolerance_val IS '자체 검·교정 허용오차 — 저울 1(%), 온도계 1(도)';


--
-- Name: COLUMN tbl_measuring_device.tolerance_unit; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.tolerance_unit IS '허용오차 단위 — PCT:퍼센트, DEG:섭씨도, SEC:초';


--
-- Name: COLUMN tbl_measuring_device.calib_cycle_month; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.calib_cycle_month IS '검·교정 주기(개월) — 기본 12(연 1회). 차기 예정일 산출에 사용';


--
-- Name: COLUMN tbl_measuring_device.place_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.place_nm IS '설치 위치';


--
-- Name: COLUMN tbl_measuring_device.sort_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.sort_no IS '정렬순서';


--
-- Name: COLUMN tbl_measuring_device.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_measuring_device.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_measuring_device.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_measuring_device.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_measuring_device.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_measuring_device.upd_dt IS '최종수정일시';


--
-- Name: tbl_measuring_device_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_measuring_device ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_measuring_device_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_menu; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_menu (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    menu_cd character varying(40) NOT NULL,
    menu_nm character varying(100) NOT NULL,
    h_menu_cd character varying(40),
    scrn_cd character varying(30),
    sort_no integer DEFAULT 0 NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_menu; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_menu IS '업체별 메뉴 트리 — SideMenu 3단 구성. 미사용 양식은 use_yn=N으로 숨긴다';


--
-- Name: COLUMN tbl_menu.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_menu.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_menu.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_menu.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_menu.menu_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_menu.menu_cd IS '메뉴코드 — 업체 내 유일';


--
-- Name: COLUMN tbl_menu.menu_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_menu.menu_nm IS '메뉴명';


--
-- Name: COLUMN tbl_menu.h_menu_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_menu.h_menu_cd IS '상위 메뉴코드 — NULL이거나 공백일 때(= 대분류) 트리 루트';


--
-- Name: COLUMN tbl_menu.scrn_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_menu.scrn_cd IS '화면코드 — tbl_screen.scrn_cd. 값이 있을 때(= leaf 노드) 클릭 시 탭이 열린다';


--
-- Name: COLUMN tbl_menu.sort_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_menu.sort_no IS '정렬순서';


--
-- Name: COLUMN tbl_menu.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_menu.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_menu.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_menu.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_menu.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_menu.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_menu.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_menu.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_menu.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_menu.upd_dt IS '최종수정일시';


--
-- Name: tbl_menu_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_menu ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_menu_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_notification; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_notification (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    noti_type_cd character varying(30) NOT NULL,
    user_id character varying(20) NOT NULL,
    title character varying(200) NOT NULL,
    content character varying(500),
    link_scrn_cd character varying(30),
    link_doc_idx bigint,
    read_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    read_dt timestamp without time zone,
    ins_dt timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE tbl_notification; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_notification IS '알림함 — 수신 여부는 tbl_user_noti_pref를 따르고, 발송된 알림만 이 테이블에 쌓인다';


--
-- Name: COLUMN tbl_notification.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_notification.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_notification.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_notification.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_notification.noti_type_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_notification.noti_type_cd IS '알림 유형 — tbl_user_noti_pref.noti_type_cd와 동일 체계';


--
-- Name: COLUMN tbl_notification.user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_notification.user_id IS '수신자 로그인 ID';


--
-- Name: COLUMN tbl_notification.title; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_notification.title IS '알림 제목';


--
-- Name: COLUMN tbl_notification.content; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_notification.content IS '알림 본문';


--
-- Name: COLUMN tbl_notification.link_scrn_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_notification.link_scrn_cd IS '바로가기 화면코드 — 클릭 시 열 탭';


--
-- Name: COLUMN tbl_notification.link_doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_notification.link_doc_idx IS '바로가기 문서 idx — tbl_document.idx';


--
-- Name: COLUMN tbl_notification.read_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_notification.read_yn IS '읽음여부 Y/N';


--
-- Name: COLUMN tbl_notification.read_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_notification.read_dt IS '읽은 일시';


--
-- Name: COLUMN tbl_notification.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_notification.ins_dt IS '발송 일시';


--
-- Name: tbl_notification_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_notification ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_notification_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_partner; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_partner (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    partner_cd character varying(30) NOT NULL,
    partner_nm character varying(200) NOT NULL,
    partner_gbn character varying(10) NOT NULL,
    biz_no character varying(20),
    ceo_nm character varying(50),
    tel_no character varying(20),
    fax_no character varying(20),
    mng_nm character varying(50),
    mobile character varying(20),
    email character varying(100),
    zip_no character varying(10),
    addr_h character varying(200),
    addr_d character varying(200),
    haccp_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    coop_list_yn character varying(1) DEFAULT 'N'::character varying NOT NULL
);


--
-- Name: TABLE tbl_partner; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_partner IS '거래처 — 공급처·판매처·수거업체·검사기관 통합. 회수 시 거래처 연락망으로도 쓴다';


--
-- Name: COLUMN tbl_partner.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_partner.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_partner.partner_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.partner_cd IS '거래처 코드 — 업체 내 유일';


--
-- Name: COLUMN tbl_partner.partner_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.partner_nm IS '거래처명';


--
-- Name: COLUMN tbl_partner.partner_gbn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.partner_gbn IS '구분 — SUPPLY:공급처, SALES:판매처, WASTE:폐기물 수거업체, LAB:검사기관';


--
-- Name: COLUMN tbl_partner.biz_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.biz_no IS '사업자등록번호';


--
-- Name: COLUMN tbl_partner.ceo_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.ceo_nm IS '대표자명';


--
-- Name: COLUMN tbl_partner.tel_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.tel_no IS '전화번호';


--
-- Name: COLUMN tbl_partner.fax_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.fax_no IS '팩스번호 — 회수 통보 시 사용';


--
-- Name: COLUMN tbl_partner.mng_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.mng_nm IS '담당자명';


--
-- Name: COLUMN tbl_partner.mobile; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.mobile IS '담당자 휴대폰';


--
-- Name: COLUMN tbl_partner.email; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.email IS '담당자 이메일';


--
-- Name: COLUMN tbl_partner.zip_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.zip_no IS '우편번호';


--
-- Name: COLUMN tbl_partner.addr_h; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.addr_h IS '주소';


--
-- Name: COLUMN tbl_partner.addr_d; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.addr_d IS '상세주소';


--
-- Name: COLUMN tbl_partner.haccp_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.haccp_yn IS 'HACCP 인증업체 여부 Y/N';


--
-- Name: COLUMN tbl_partner.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_partner.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_partner.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_partner.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_partner.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_partner.coop_list_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_partner.coop_list_yn IS '협력업체 리스트 등록여부 Y/N — HA-INV-13';


--
-- Name: tbl_partner_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_partner ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_partner_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_pest_check; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_pest_check (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    doc_idx bigint NOT NULL,
    base_dt character varying(8) NOT NULL,
    checker_id character varying(20),
    checker_nm character varying(50),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_pest_check; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_pest_check IS '방충·방서 점검표 헤더 — 원본 양식 13번. 주 1회 작성';


--
-- Name: COLUMN tbl_pest_check.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_pest_check.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_pest_check.doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check.doc_idx IS '문서 idx — tbl_document.idx와 1:1';


--
-- Name: COLUMN tbl_pest_check.base_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check.base_dt IS '작성일 YYYYMMDD';


--
-- Name: COLUMN tbl_pest_check.checker_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check.checker_id IS '작성자 로그인 ID';


--
-- Name: COLUMN tbl_pest_check.checker_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check.checker_nm IS '작성자명 — 작성 시점 스냅샷';


--
-- Name: COLUMN tbl_pest_check.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_pest_check.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_pest_check.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_pest_check.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check.upd_dt IS '최종수정일시';


--
-- Name: tbl_pest_check_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_pest_check ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_pest_check_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_pest_check_row; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_pest_check_row (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    hdr_idx bigint NOT NULL,
    row_seq integer NOT NULL,
    pest_cd character varying(30) NOT NULL,
    pest_nm character varying(100),
    place_nm character varying(100),
    device_ng_cd character varying(1),
    fly_cnt integer DEFAULT 0,
    moth_cnt integer DEFAULT 0,
    mosq_cnt integer DEFAULT 0,
    midge_cnt integer DEFAULT 0,
    etc_fly_cnt integer DEFAULT 0,
    fly_sum integer DEFAULT 0,
    roach_cnt integer DEFAULT 0,
    spider_cnt integer DEFAULT 0,
    ant_cnt integer DEFAULT 0,
    etc_walk_cnt integer DEFAULT 0,
    walk_sum integer DEFAULT 0,
    rat_cnt integer DEFAULT 0,
    etc_rat_cnt integer DEFAULT 0,
    rat_sum integer DEFAULT 0,
    remark character varying(500),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    fly_yn character varying(1),
    moth_yn character varying(1),
    mosq_yn character varying(1),
    midge_yn character varying(1),
    etc_fly_yn character varying(1),
    roach_yn character varying(1),
    spider_yn character varying(1),
    ant_yn character varying(1),
    etc_walk_yn character varying(1),
    rat_yn character varying(1),
    etc_rat_yn character varying(1)
);


--
-- Name: TABLE tbl_pest_check_row; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_pest_check_row IS '방충방서 설비별 포집 수량 — 행은 tbl_pest_device 등록 대수만큼 자동 생성';


--
-- Name: COLUMN tbl_pest_check_row.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_pest_check_row.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_pest_check_row.hdr_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.hdr_idx IS '헤더 idx — tbl_pest_check.idx';


--
-- Name: COLUMN tbl_pest_check_row.row_seq; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.row_seq IS '행 순번';


--
-- Name: COLUMN tbl_pest_check_row.pest_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.pest_cd IS '설비 코드 — tbl_pest_device.pest_cd';


--
-- Name: COLUMN tbl_pest_check_row.pest_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.pest_nm IS '설비명 스냅샷';


--
-- Name: COLUMN tbl_pest_check_row.place_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.place_nm IS '설치 위치 스냅샷';


--
-- Name: COLUMN tbl_pest_check_row.device_ng_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.device_ng_cd IS '설비 이상유무 — O:정상, X:이상';


--
-- Name: COLUMN tbl_pest_check_row.fly_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.fly_cnt IS '비래해충 파리 포집수';


--
-- Name: COLUMN tbl_pest_check_row.moth_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.moth_cnt IS '비래해충 나방 포집수';


--
-- Name: COLUMN tbl_pest_check_row.mosq_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.mosq_cnt IS '비래해충 모기 포집수';


--
-- Name: COLUMN tbl_pest_check_row.midge_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.midge_cnt IS '비래해충 깔따구 포집수';


--
-- Name: COLUMN tbl_pest_check_row.etc_fly_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.etc_fly_cnt IS '비래해충 기타 포집수';


--
-- Name: COLUMN tbl_pest_check_row.fly_sum; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.fly_sum IS '비래해충 소계 — 파리+나방+모기+깔따구+기타. 저장 SP가 계산';


--
-- Name: COLUMN tbl_pest_check_row.roach_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.roach_cnt IS '보행해충 바퀴 포집수';


--
-- Name: COLUMN tbl_pest_check_row.spider_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.spider_cnt IS '보행해충 거미 포집수';


--
-- Name: COLUMN tbl_pest_check_row.ant_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.ant_cnt IS '보행해충 개미 포집수';


--
-- Name: COLUMN tbl_pest_check_row.etc_walk_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.etc_walk_cnt IS '보행해충 기타 포집수';


--
-- Name: COLUMN tbl_pest_check_row.walk_sum; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.walk_sum IS '보행해충 소계 — 저장 SP가 계산';


--
-- Name: COLUMN tbl_pest_check_row.rat_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.rat_cnt IS '쥐 포획수';


--
-- Name: COLUMN tbl_pest_check_row.etc_rat_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.etc_rat_cnt IS '쥐 기타(흔적 등) 수';


--
-- Name: COLUMN tbl_pest_check_row.rat_sum; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.rat_sum IS '쥐 소계 — 저장 SP가 계산. 0보다 클 때(= 방서 이탈) 개선조치 안내';


--
-- Name: COLUMN tbl_pest_check_row.remark; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.remark IS '비고';


--
-- Name: COLUMN tbl_pest_check_row.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_pest_check_row.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_pest_check_row.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_pest_check_row.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_check_row.upd_dt IS '최종수정일시';


--
-- Name: tbl_pest_check_row_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_pest_check_row ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_pest_check_row_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_pest_device; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_pest_device (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    pest_cd character varying(30) NOT NULL,
    pest_nm character varying(100) NOT NULL,
    pest_type character varying(10) NOT NULL,
    place_nm character varying(100),
    sort_no integer DEFAULT 0 NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_pest_device; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_pest_device IS '포충등·트랩 — 방충방서 점검표 행 자동 생성 원천. 업체별 설치 대수만큼 등록';


--
-- Name: COLUMN tbl_pest_device.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_device.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_pest_device.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_device.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_pest_device.pest_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_device.pest_cd IS '설비 코드 — 업체 내 유일';


--
-- Name: COLUMN tbl_pest_device.pest_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_device.pest_nm IS '설비명 — 포충등 1, 바퀴트랩 3 등. A4 표 좌측 열에 출력';


--
-- Name: COLUMN tbl_pest_device.pest_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_device.pest_type IS '유형 — LAMP:포충등, ROACH:바퀴트랩, RAT:쥐트랩';


--
-- Name: COLUMN tbl_pest_device.place_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_device.place_nm IS '설치 위치';


--
-- Name: COLUMN tbl_pest_device.sort_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_device.sort_no IS '정렬순서 — A4 표의 행 순서';


--
-- Name: COLUMN tbl_pest_device.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_device.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_pest_device.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_device.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_pest_device.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_device.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_pest_device.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_device.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_pest_device.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_pest_device.upd_dt IS '최종수정일시';


--
-- Name: tbl_pest_device_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_pest_device ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_pest_device_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_product; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_product (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    product_cd character varying(30) NOT NULL,
    product_nm character varying(200) NOT NULL,
    spec_nm character varying(100),
    unit_nm character varying(20),
    pkg_type character varying(50),
    storage_type character varying(10),
    shelf_life_day integer,
    report_no character varying(50),
    haccp_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_product; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_product IS '제품 — 금속검출·공정관리·제품검사·회수 문서에서 품명 선택 원천';


--
-- Name: COLUMN tbl_product.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_product.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_product.product_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.product_cd IS '제품코드 — 업체 내 유일';


--
-- Name: COLUMN tbl_product.product_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.product_nm IS '제품명';


--
-- Name: COLUMN tbl_product.spec_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.spec_nm IS '규격';


--
-- Name: COLUMN tbl_product.unit_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.unit_nm IS '단위 — kg, box 등';


--
-- Name: COLUMN tbl_product.pkg_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.pkg_type IS '포장형태 — 진공포장, 랩포장 등';


--
-- Name: COLUMN tbl_product.storage_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.storage_type IS '보관유형 — COLD:냉장, FROZEN:냉동, ROOM:상온';


--
-- Name: COLUMN tbl_product.shelf_life_day; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.shelf_life_day IS '소비기한 일수 — 제조일 기준';


--
-- Name: COLUMN tbl_product.report_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.report_no IS '품목제조보고번호';


--
-- Name: COLUMN tbl_product.haccp_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.haccp_yn IS 'HACCP 적용 품목여부 Y/N';


--
-- Name: COLUMN tbl_product.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_product.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_product.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_product.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_product.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_product.upd_dt IS '최종수정일시';


--
-- Name: tbl_product_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_product ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_product_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_recv_inspect; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_recv_inspect (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    doc_idx bigint NOT NULL,
    base_dt character varying(8) NOT NULL,
    recv_gbn character varying(10) NOT NULL,
    recv_time character varying(4),
    partner_cd character varying(30),
    partner_nm character varying(200),
    material_cd character varying(30),
    item_nm character varying(200),
    recv_qty numeric(15,3),
    unit_nm character varying(20),
    lot_no character varying(50),
    make_dt character varying(8),
    expire_dt character varying(8),
    core_temp numeric(5,1),
    car_temp numeric(5,1),
    vehicle_cd character varying(30),
    car_no character varying(20),
    haccp_apply_cd character varying(1),
    judge_cd character varying(1),
    judge_mod_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    checker_id character varying(20),
    checker_nm character varying(50),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_recv_inspect; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_recv_inspect IS '입고검사 일지 헤더 — 표준기준서 관리번호 14. 승인 시 tbl_inv_txn 입고 내역 자동 생성';


--
-- Name: COLUMN tbl_recv_inspect.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_recv_inspect.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_recv_inspect.doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.doc_idx IS '문서 idx — tbl_document.idx와 1:1';


--
-- Name: COLUMN tbl_recv_inspect.base_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.base_dt IS '입고일자 YYYYMMDD';


--
-- Name: COLUMN tbl_recv_inspect.recv_gbn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.recv_gbn IS '입고구분 — MEAT:원료육, SUB:부재료, PACK:포장재. 검사항목 세트를 결정';


--
-- Name: COLUMN tbl_recv_inspect.recv_time; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.recv_time IS '입고시각 HHMM';


--
-- Name: COLUMN tbl_recv_inspect.partner_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.partner_cd IS '반입처 코드 — tbl_partner.partner_cd';


--
-- Name: COLUMN tbl_recv_inspect.partner_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.partner_nm IS '반입처명 스냅샷';


--
-- Name: COLUMN tbl_recv_inspect.material_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.material_cd IS '원부재료 코드 — tbl_material.material_cd';


--
-- Name: COLUMN tbl_recv_inspect.item_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.item_nm IS '품명 스냅샷';


--
-- Name: COLUMN tbl_recv_inspect.recv_qty; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.recv_qty IS '입고 수량';


--
-- Name: COLUMN tbl_recv_inspect.unit_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.unit_nm IS '단위';


--
-- Name: COLUMN tbl_recv_inspect.lot_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.lot_no IS '로트번호';


--
-- Name: COLUMN tbl_recv_inspect.make_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.make_dt IS '제조(도축)일자 YYYYMMDD';


--
-- Name: COLUMN tbl_recv_inspect.expire_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.expire_dt IS '소비기한 YYYYMMDD';


--
-- Name: COLUMN tbl_recv_inspect.core_temp; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.core_temp IS '품온(심부온도, 섭씨) — 냉장 원료육 기준 초과 시 부적합';


--
-- Name: COLUMN tbl_recv_inspect.car_temp; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.car_temp IS '운반차량 적재함 온도(섭씨)';


--
-- Name: COLUMN tbl_recv_inspect.vehicle_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.vehicle_cd IS '차량 코드 — tbl_vehicle.vehicle_cd. 자사 차량일 때만';


--
-- Name: COLUMN tbl_recv_inspect.car_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.car_no IS '차량번호 — 타사 차량은 직접 입력';


--
-- Name: COLUMN tbl_recv_inspect.haccp_apply_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.haccp_apply_cd IS '공급처 HACCP 적용 확인 — Y:적용, N:미적용';


--
-- Name: COLUMN tbl_recv_inspect.judge_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.judge_cd IS '종합 판정 — P:적합, F:부적합. 품온·검사항목을 종합해 SP가 확정';


--
-- Name: COLUMN tbl_recv_inspect.judge_mod_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.judge_mod_yn IS '판정 수동변경 여부 Y/N';


--
-- Name: COLUMN tbl_recv_inspect.checker_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.checker_id IS '검사자 로그인 ID';


--
-- Name: COLUMN tbl_recv_inspect.checker_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.checker_nm IS '검사자명 — 작성 시점 스냅샷';


--
-- Name: COLUMN tbl_recv_inspect.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_recv_inspect.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_recv_inspect.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_recv_inspect.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_recv_inspect.upd_dt IS '최종수정일시';


--
-- Name: tbl_recv_inspect_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_recv_inspect ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_recv_inspect_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_role; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_role (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    usrgrp_cd character varying(20) NOT NULL,
    usrgrp_nm character varying(100) NOT NULL,
    desc_rmk character varying(300),
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_role; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_role IS '권한그룹 — HACCP팀장/모니터링담당자/일반작업자 등';


--
-- Name: COLUMN tbl_role.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_role.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role.co_cd IS '회사코드 — 테넌트 키. 0000일 때(= 플랫폼 예약 회사) 플랫폼 공통 권한그룹';


--
-- Name: COLUMN tbl_role.usrgrp_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role.usrgrp_cd IS '권한그룹코드 — 업체 내 유일. PLATFORM은 플랫폼 관리자 예약어';


--
-- Name: COLUMN tbl_role.usrgrp_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role.usrgrp_nm IS '권한그룹명';


--
-- Name: COLUMN tbl_role.desc_rmk; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role.desc_rmk IS '설명';


--
-- Name: COLUMN tbl_role.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_role.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_role.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_role.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_role.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role.upd_dt IS '최종수정일시';


--
-- Name: tbl_role_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_role ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_role_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_role_screen; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_role_screen (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    usrgrp_cd character varying(20) NOT NULL,
    scrn_cd character varying(30) NOT NULL,
    read_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    write_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    modify_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    delete_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    print_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_role_screen; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_role_screen IS '권한그룹별 화면 권한 — SideMenu 노출과 그리드 CRUD 잠금(useGridAccess)의 근거';


--
-- Name: COLUMN tbl_role_screen.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_role_screen.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_role_screen.usrgrp_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.usrgrp_cd IS '권한그룹코드 — tbl_role.usrgrp_cd';


--
-- Name: COLUMN tbl_role_screen.scrn_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.scrn_cd IS '화면코드 — tbl_screen.scrn_cd';


--
-- Name: COLUMN tbl_role_screen.read_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.read_yn IS '조회 권한 Y/N — N일 때(= 메뉴 자체 숨김)';


--
-- Name: COLUMN tbl_role_screen.write_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.write_yn IS '등록(신규행 추가) 권한 Y/N';


--
-- Name: COLUMN tbl_role_screen.modify_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.modify_yn IS '수정(기존행 편집) 권한 Y/N';


--
-- Name: COLUMN tbl_role_screen.delete_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.delete_yn IS '삭제 권한 Y/N';


--
-- Name: COLUMN tbl_role_screen.print_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.print_yn IS '출력(A4 인쇄·PDF 다운로드) 권한 Y/N';


--
-- Name: COLUMN tbl_role_screen.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_role_screen.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_role_screen.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_role_screen.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_role_screen.upd_dt IS '최종수정일시';


--
-- Name: tbl_role_screen_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_role_screen ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_role_screen_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_schedule_rule; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_schedule_rule (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    rule_seq integer DEFAULT 1 NOT NULL,
    cycle_cd character varying(1) NOT NULL,
    week_days character varying(20),
    month_day integer,
    month_no integer,
    due_time character varying(4) DEFAULT '1800'::character varying,
    dept_cd character varying(20),
    user_id character varying(20),
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    base_dt character varying(8),
    nonwork_rule character varying(10) DEFAULT 'keep'::character varying NOT NULL
);


--
-- Name: TABLE tbl_schedule_rule; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_schedule_rule IS '작성주기 규칙 — 오늘 할 일 생성 배치의 입력. 템플릿별 여러 규칙 허용';


--
-- Name: COLUMN tbl_schedule_rule.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_schedule_rule.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_schedule_rule.tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.tmpl_cd IS '템플릿 코드 — tbl_template.tmpl_cd';


--
-- Name: COLUMN tbl_schedule_rule.rule_seq; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.rule_seq IS '규칙 순번 — 양식당 1건 제약(ux_tbl_schedule_rule_tmpl) 이후로는 항상 1. 레거시 유니크 유지용';


--
-- Name: COLUMN tbl_schedule_rule.cycle_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.cycle_cd IS '주기 — D:매일, W:매주, M:매월, Q:분기, H:반기, Y:매년, E:수시(이벤트 발생 시)';


--
-- Name: COLUMN tbl_schedule_rule.week_days; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.week_days IS '요일 — cycle_cd=W일 때. 1(월)~7(일) 쉼표 구분';


--
-- Name: COLUMN tbl_schedule_rule.month_day; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.month_day IS '기준일 — cycle_cd=M/Y일 때 해당 월의 일자';


--
-- Name: COLUMN tbl_schedule_rule.month_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.month_no IS '기준월 — cycle_cd=Y일 때 1~12';


--
-- Name: COLUMN tbl_schedule_rule.due_time; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.due_time IS '마감시각 HHMM — 경과 시 지연(LATE) 처리';


--
-- Name: COLUMN tbl_schedule_rule.dept_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.dept_cd IS '담당 부서코드 — 오늘 할 일 배정 대상';


--
-- Name: COLUMN tbl_schedule_rule.user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.user_id IS '담당자 로그인 ID — 지정 시 개인에게 직접 배정';


--
-- Name: COLUMN tbl_schedule_rule.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_schedule_rule.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_schedule_rule.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_schedule_rule.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_schedule_rule.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_schedule_rule.base_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.base_dt IS '관리 시작일 yyyyMMdd — 이 날짜 이전 예정일은 만들지 않는다';


--
-- Name: COLUMN tbl_schedule_rule.nonwork_rule; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule.nonwork_rule IS '비영업일 처리 — keep:그대로, prev:이전 영업일, next:다음 영업일. 토·일에 걸린 예정일을 어디로 옮길지';


--
-- Name: tbl_schedule_rule_detail; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_schedule_rule_detail (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    seq integer NOT NULL,
    detail_ty character varying(20) NOT NULL,
    val1 integer,
    val2 integer
);


--
-- Name: TABLE tbl_schedule_rule_detail; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_schedule_rule_detail IS '작성주기 반복 상세 — 요일·실행일·말일·분기월·반기월. 저장 시 양식 단위로 전량 교체된다';


--
-- Name: COLUMN tbl_schedule_rule_detail.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule_detail.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_schedule_rule_detail.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule_detail.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_schedule_rule_detail.tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule_detail.tmpl_cd IS '양식코드 — tbl_schedule_rule.tmpl_cd (양식당 주기 1건이라 rule 키와 같다)';


--
-- Name: COLUMN tbl_schedule_rule_detail.seq; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule_detail.seq IS '입력 순번 — 화면 표시 순서. 업무 의미는 없다';


--
-- Name: COLUMN tbl_schedule_rule_detail.detail_ty; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule_detail.detail_ty IS '상세 유형 — week-day:요일, month-day:실행일, month-end:말일, quarter-month:분기내 실행월, half-month:반기내 실행월, year-month:실행월';


--
-- Name: COLUMN tbl_schedule_rule_detail.val1; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule_detail.val1 IS '값1 — 요일 1(월)~7(일) / 실행일 1~31 / 분기·반기 내 월 순번 / 실행월 1~12. month-end 는 NULL';


--
-- Name: COLUMN tbl_schedule_rule_detail.val2; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_rule_detail.val2 IS '값2 — 월 지정과 함께 쓰는 실행일 1~31. 요일·실행일 단독일 때는 NULL';


--
-- Name: tbl_schedule_rule_detail_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_schedule_rule_detail ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_schedule_rule_detail_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_schedule_rule_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_schedule_rule ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_schedule_rule_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_schedule_task; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_schedule_task (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    base_dt character varying(8) NOT NULL,
    due_dt character varying(8) NOT NULL,
    due_time character varying(4),
    status character varying(4) DEFAULT 'TODO'::character varying NOT NULL,
    doc_idx bigint,
    dept_cd character varying(20),
    user_id character varying(20),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    alarm_dt timestamp without time zone,
    alarm_send_yn character varying(1) DEFAULT 'N'::character varying NOT NULL
);


--
-- Name: TABLE tbl_schedule_task; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_schedule_task IS '작성 과제 — 일 1회 배치 생성 + 로그인 시 온디맨드 보정. 오늘 할 일·누락 알림의 원천';


--
-- Name: COLUMN tbl_schedule_task.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_schedule_task.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_schedule_task.tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.tmpl_cd IS '템플릿 코드 — tbl_template.tmpl_cd';


--
-- Name: COLUMN tbl_schedule_task.base_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.base_dt IS '기준일자 YYYYMMDD — 작성해야 하는 대상 일자';


--
-- Name: COLUMN tbl_schedule_task.due_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.due_dt IS '마감일자 YYYYMMDD';


--
-- Name: COLUMN tbl_schedule_task.due_time; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.due_time IS '마감시각 HHMM';


--
-- Name: COLUMN tbl_schedule_task.status; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.status IS '상태 — TODO:미작성, ING:작성중, APV:승인완료, LATE:기한경과';


--
-- Name: COLUMN tbl_schedule_task.doc_idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.doc_idx IS '연결 문서 idx — 작성 시작 시 tbl_document.idx로 채워진다';


--
-- Name: COLUMN tbl_schedule_task.dept_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.dept_cd IS '담당 부서코드';


--
-- Name: COLUMN tbl_schedule_task.user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.user_id IS '담당자 로그인 ID';


--
-- Name: COLUMN tbl_schedule_task.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.ins_id IS '최초입력자 ID — 배치 실행 주체';


--
-- Name: COLUMN tbl_schedule_task.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_schedule_task.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_schedule_task.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_schedule_task.alarm_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.alarm_dt IS '알림 시각 — 마감(due_dt+due_time) 에서 app.schedule.alarm-before-minutes 만큼 앞선 시점';


--
-- Name: COLUMN tbl_schedule_task.alarm_send_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_schedule_task.alarm_send_yn IS '알림 발송여부 Y/N — Y일 때(= 이미 보냄) 다시 보내지 않는다';


--
-- Name: tbl_schedule_task_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_schedule_task ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_schedule_task_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_screen; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_screen (
    idx bigint NOT NULL,
    scrn_cd character varying(30) NOT NULL,
    scrn_nm character varying(100) NOT NULL,
    module_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40),
    sort_no integer DEFAULT 0 NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_screen; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_screen IS '화면 마스터 — 플랫폼 전역. 메뉴·권한·UV/PV 통계의 공통 차원';


--
-- Name: COLUMN tbl_screen.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_screen.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_screen.scrn_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_screen.scrn_cd IS '화면 식별자 — 역할 기반 kebab-case. FE screenRegistry 키와 1:1';


--
-- Name: COLUMN tbl_screen.scrn_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_screen.scrn_nm IS '화면명 — 탭 제목·통계 표시명';


--
-- Name: COLUMN tbl_screen.module_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_screen.module_cd IS '모듈코드 — SYS/BAS/CCP/HYG/FAC/INV/VER/DOC/TSK. URL 첫 세그먼트';


--
-- Name: COLUMN tbl_screen.tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_screen.tmpl_cd IS '연결 템플릿코드 — tbl_template.tmpl_cd. 점검표 화면일 때만 값이 있다';


--
-- Name: COLUMN tbl_screen.sort_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_screen.sort_no IS '정렬순서';


--
-- Name: COLUMN tbl_screen.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_screen.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_screen.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_screen.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_screen.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_screen.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_screen.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_screen.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_screen.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_screen.upd_dt IS '최종수정일시';


--
-- Name: tbl_screen_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_screen ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_screen_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_storage; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_storage (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    storage_cd character varying(30) NOT NULL,
    storage_nm character varying(100) NOT NULL,
    storage_type character varying(10) NOT NULL,
    ccp_cd character varying(20),
    temp_min numeric(5,1),
    temp_max numeric(5,1),
    sensor_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    place_nm character varying(100),
    sort_no integer DEFAULT 0 NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_storage; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_storage IS '보관고 — 냉장·냉동창고. CCP 냉장보관 일지의 보관고 열을 이 행 수만큼 동적 생성';


--
-- Name: COLUMN tbl_storage.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_storage.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_storage.storage_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.storage_cd IS '보관고 코드 — 업체 내 유일';


--
-- Name: COLUMN tbl_storage.storage_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.storage_nm IS '보관고명 — 냉장창고 1, 완제품 냉장고 등. A4 표 열 머리글에 출력';


--
-- Name: COLUMN tbl_storage.storage_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.storage_type IS '유형 — COLD:냉장, FROZEN:냉동, ROOM:상온';


--
-- Name: COLUMN tbl_storage.ccp_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.ccp_cd IS '연결 CCP 코드 — tbl_ccp_limit.ccp_cd. 자동판정 기준을 여기서 찾는다';


--
-- Name: COLUMN tbl_storage.temp_min; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.temp_min IS '개별 하한온도 — NULL이면(= 미지정) tbl_ccp_limit 값을 따른다';


--
-- Name: COLUMN tbl_storage.temp_max; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.temp_max IS '개별 상한온도 — NULL이면 tbl_ccp_limit 값을 따른다';


--
-- Name: COLUMN tbl_storage.sensor_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.sensor_yn IS '자동온도기록장치 설치여부 Y/N — Y일 때(= 야간 자동기록) 근무외 시간 기록 면제';


--
-- Name: COLUMN tbl_storage.place_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.place_nm IS '설치 위치';


--
-- Name: COLUMN tbl_storage.sort_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.sort_no IS '정렬순서 — A4 표의 열 순서';


--
-- Name: COLUMN tbl_storage.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_storage.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_storage.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_storage.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_storage.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_storage.upd_dt IS '최종수정일시';


--
-- Name: tbl_storage_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_storage ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_storage_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_template; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_template (
    idx bigint NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    tmpl_nm character varying(200) NOT NULL,
    mng_no character varying(20),
    doc_kind character varying(10) NOT NULL,
    category_cd character varying(20),
    scrn_cd character varying(30),
    form_path character varying(300),
    default_cycle_cd character varying(10),
    default_retention_month integer DEFAULT 24 NOT NULL,
    ver_no integer DEFAULT 1 NOT NULL,
    impl_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    sort_no integer DEFAULT 0 NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    co_cd character varying(10) DEFAULT '0000'::character varying NOT NULL
);


--
-- Name: TABLE tbl_template; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_template IS '표준 템플릿 카탈로그 — 플랫폼이 배포하는 31종 + 추가 12종 메타. 업체는 복사해서 쓴다';


--
-- Name: COLUMN tbl_template.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_template.tmpl_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.tmpl_cd IS '템플릿 코드 — CCP_COLD, CCP_METAL, DAILY_HYG 등';


--
-- Name: COLUMN tbl_template.tmpl_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.tmpl_nm IS '표준 문서명 — CCP 냉장보관 모니터링 일지 등(회사별 CCP 코드는 포함하지 않음)';


--
-- Name: COLUMN tbl_template.mng_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.mng_no IS '표준기준서 관리번호 — HA-HYG-01, HA-CCP-06-01 등';


--
-- Name: COLUMN tbl_template.doc_kind; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.doc_kind IS '문서 유형 — DB:전용 HTML 화면 + DB 저장, HWP:rhwp 문서작성형';


--
-- Name: COLUMN tbl_template.category_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.category_cd IS '분류 — CCP, HYG, FAC, INV, VER, EDU, DOC';


--
-- Name: COLUMN tbl_template.scrn_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.scrn_cd IS '연결 화면코드 — doc_kind=DB일 때(= 전용 화면 보유) tbl_screen.scrn_cd';


--
-- Name: COLUMN tbl_template.form_path; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.form_path IS '표준 원본 HWP 상대경로 — HaccpTemplates/{tmpl_cd}/{파일명}. html 양식은 물리 원본이 없어 NULL';


--
-- Name: COLUMN tbl_template.default_cycle_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.default_cycle_cd IS '기본 작성주기 — D:일, W:주, M:월, Y:년, E:수시(이벤트)';


--
-- Name: COLUMN tbl_template.default_retention_month; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.default_retention_month IS '기본 보존 개월수 — HACCP 기준 최소 24';


--
-- Name: COLUMN tbl_template.ver_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.ver_no IS '템플릿 버전 — 표의 전체 구조 변경 시 증가';


--
-- Name: COLUMN tbl_template.impl_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.impl_yn IS '구현여부 Y/N — N일 때(= 카탈로그 등록만, 화면 미개발) 업체 배포 대상에서 제외';


--
-- Name: COLUMN tbl_template.sort_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.sort_no IS '정렬순서 — 표준기준서 관리번호 순';


--
-- Name: COLUMN tbl_template.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_template.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_template.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_template.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_template.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_template.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_template.co_cd IS '카탈로그 소유 회사 — 0000이면(= 플랫폼 공용) 전 업체 배포 대상, 그 외는 해당 업체가 직접 등록한 자사 양식';


--
-- Name: tbl_template_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_template ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_template_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_tml_ccp_chk_ver; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_tml_ccp_chk_ver (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ver_no integer NOT NULL,
    ver_cd character varying(20) NOT NULL,
    ver_nm character varying(100) NOT NULL,
    apply_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    CONSTRAINT ck_tbl_tml_ccp_chk_ver_apply CHECK (((apply_yn)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT ck_tbl_tml_ccp_chk_ver_no CHECK ((ver_no >= 1)),
    CONSTRAINT ck_tbl_tml_ccp_chk_ver_use CHECK (((use_yn)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[])))
);


--
-- Name: TABLE tbl_tml_ccp_chk_ver; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_tml_ccp_chk_ver IS 'CCP 검증점검 자사 양식 버전 — 예시는 tml_ccp_chk_000 가상';


--
-- Name: tbl_tml_ccp_chk_ver_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_tml_ccp_chk_ver ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_tml_ccp_chk_ver_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_tml_ccp_chk_ver_item; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_tml_ccp_chk_ver_item (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ver_no integer NOT NULL,
    item_cd character varying(20) NOT NULL,
    sort_no integer DEFAULT 0 NOT NULL,
    cycle_nm character varying(50),
    grp_nm character varying(100),
    item_nm text NOT NULL,
    input_type character varying(20) DEFAULT 'radio'::character varying NOT NULL,
    unit_nm character varying(20),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_tml_ccp_chk_ver_item; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_tml_ccp_chk_ver_item IS 'CCP 검증점검 자사 양식 항목';


--
-- Name: tbl_tml_ccp_chk_ver_item_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_tml_ccp_chk_ver_item ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_tml_ccp_chk_ver_item_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_tml_ccp_htg_ver; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_tml_ccp_htg_ver (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ver_no integer NOT NULL,
    ver_cd character varying(20) NOT NULL,
    ver_nm character varying(100) NOT NULL,
    apply_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    CONSTRAINT ck_tbl_tml_ccp_htg_ver_apply CHECK (((apply_yn)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT ck_tbl_tml_ccp_htg_ver_no CHECK ((ver_no >= 1)),
    CONSTRAINT ck_tbl_tml_ccp_htg_ver_use CHECK (((use_yn)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[])))
);


--
-- Name: TABLE tbl_tml_ccp_htg_ver; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_tml_ccp_htg_ver IS 'CCP-2B 가열 모니터링일지 자사 양식 버전 — 예시는 tml_ccp_htg_000 가상';


--
-- Name: tbl_tml_ccp_htg_ver_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_tml_ccp_htg_ver ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_tml_ccp_htg_ver_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_tml_ccp_htg_ver_item; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_tml_ccp_htg_ver_item (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ver_no integer NOT NULL,
    item_cd character varying(20) NOT NULL,
    sort_no integer DEFAULT 0 NOT NULL,
    cycle_nm character varying(50),
    grp_nm character varying(100),
    item_nm text NOT NULL,
    input_type character varying(20) DEFAULT 'text'::character varying NOT NULL,
    unit_nm character varying(20),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_tml_ccp_htg_ver_item; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_tml_ccp_htg_ver_item IS 'CCP-2B 가열 모니터링일지 자사 양식 항목 — 한계기준·주기·방법·개선조치';


--
-- Name: tbl_tml_ccp_htg_ver_item_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_tml_ccp_htg_ver_item ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_tml_ccp_htg_ver_item_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_tml_ccp_mtl_ver; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_tml_ccp_mtl_ver (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ver_no integer NOT NULL,
    ver_cd character varying(20) NOT NULL,
    ver_nm character varying(100) NOT NULL,
    apply_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    CONSTRAINT ck_tbl_tml_ccp_mtl_ver_apply CHECK (((apply_yn)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT ck_tbl_tml_ccp_mtl_ver_no CHECK ((ver_no >= 1)),
    CONSTRAINT ck_tbl_tml_ccp_mtl_ver_use CHECK (((use_yn)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[])))
);


--
-- Name: TABLE tbl_tml_ccp_mtl_ver; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_tml_ccp_mtl_ver IS 'CCP-3P 금속검출 모니터링일지 자사 양식 버전 — 예시는 tml_ccp_mtl_000 가상';


--
-- Name: tbl_tml_ccp_mtl_ver_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_tml_ccp_mtl_ver ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_tml_ccp_mtl_ver_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_tml_ccp_mtl_ver_item; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_tml_ccp_mtl_ver_item (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ver_no integer NOT NULL,
    item_cd character varying(20) NOT NULL,
    sort_no integer DEFAULT 0 NOT NULL,
    cycle_nm character varying(50),
    grp_nm character varying(100),
    item_nm text NOT NULL,
    input_type character varying(20) DEFAULT 'text'::character varying NOT NULL,
    unit_nm character varying(20),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_tml_ccp_mtl_ver_item; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_tml_ccp_mtl_ver_item IS 'CCP-3P 금속검출 모니터링일지 자사 양식 항목 — 한계기준·주기·방법·감도열 해당없음·개선조치';


--
-- Name: tbl_tml_ccp_mtl_ver_item_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_tml_ccp_mtl_ver_item ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_tml_ccp_mtl_ver_item_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_tml_ccp_pkg_ver; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_tml_ccp_pkg_ver (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ver_no integer NOT NULL,
    ver_cd character varying(20) NOT NULL,
    ver_nm character varying(100) NOT NULL,
    apply_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    CONSTRAINT ck_tbl_tml_ccp_pkg_ver_apply CHECK (((apply_yn)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT ck_tbl_tml_ccp_pkg_ver_no CHECK ((ver_no >= 1)),
    CONSTRAINT ck_tbl_tml_ccp_pkg_ver_use CHECK (((use_yn)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[])))
);


--
-- Name: TABLE tbl_tml_ccp_pkg_ver; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_tml_ccp_pkg_ver IS 'CCP-1B 포장 모니터링일지 자사 양식 버전 — 예시는 tml_ccp_pkg_000 가상';


--
-- Name: tbl_tml_ccp_pkg_ver_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_tml_ccp_pkg_ver ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_tml_ccp_pkg_ver_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_tml_ccp_pkg_ver_item; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_tml_ccp_pkg_ver_item (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    tmpl_cd character varying(40) NOT NULL,
    ver_no integer NOT NULL,
    item_cd character varying(20) NOT NULL,
    sort_no integer DEFAULT 0 NOT NULL,
    cycle_nm character varying(50),
    grp_nm character varying(100),
    item_nm text NOT NULL,
    input_type character varying(20) DEFAULT 'text'::character varying NOT NULL,
    unit_nm character varying(20),
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_tml_ccp_pkg_ver_item; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_tml_ccp_pkg_ver_item IS 'CCP-1B 포장 모니터링일지 자사 양식 항목 — 한계기준·주기·방법·개선조치';


--
-- Name: tbl_tml_ccp_pkg_ver_item_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_tml_ccp_pkg_ver_item ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_tml_ccp_pkg_ver_item_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_user; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_user (
    idx bigint NOT NULL,
    user_id character varying(20) NOT NULL,
    co_cd character varying(10) NOT NULL,
    emp_cd character varying(20),
    user_nm character varying(50) NOT NULL,
    user_pw character varying(300) NOT NULL,
    usrgrp_cd character varying(20) NOT NULL,
    dept_cd character varying(20),
    email character varying(100),
    mobile character varying(20),
    gridsave_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    last_login_dt timestamp without time zone,
    pw_upd_dt timestamp without time zone,
    login_fail_cnt integer DEFAULT 0 NOT NULL,
    lock_yn character varying(1) DEFAULT 'N'::character varying NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    sign_img bytea,
    sign_mime character varying(50),
    sign_nm character varying(255)
);


--
-- Name: TABLE tbl_user; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_user IS '사용자 — 구 bap1100 재설계. user_id 전역 UNIQUE로 아이디만으로 소속 회사 결정';


--
-- Name: COLUMN tbl_user.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_user.user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.user_id IS '로그인 ID — 전 테넌트 통틀어 유일(ux_tbl_user_user_id). 로그인 시 회사 선택 불필요';


--
-- Name: COLUMN tbl_user.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.co_cd IS '소속 회사코드 — 로그인 성공 시 JWT coCd 클레임으로 주입되어 전 SP 테넌트 범위를 결정';


--
-- Name: COLUMN tbl_user.emp_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.emp_cd IS '사번 — 업체 내 유일(NULL 허용, PG는 NULL 중복 허용)';


--
-- Name: COLUMN tbl_user.user_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.user_nm IS '사용자명 — 문서 작성자·점검자·결재자란에 출력';


--
-- Name: COLUMN tbl_user.user_pw; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.user_pw IS '비밀번호 해시 — PasswordHasher 산출값. 평문 저장 금지';


--
-- Name: COLUMN tbl_user.usrgrp_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.usrgrp_cd IS '권한그룹코드 — tbl_role.usrgrp_cd. PLATFORM일 때(= 플랫폼 관리자) 업체 전환 가능';


--
-- Name: COLUMN tbl_user.dept_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.dept_cd IS '부서코드 — tbl_dept.dept_cd';


--
-- Name: COLUMN tbl_user.email; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.email IS '이메일 — 알림 발송 주소';


--
-- Name: COLUMN tbl_user.mobile; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.mobile IS '휴대전화번호';


--
-- Name: COLUMN tbl_user.gridsave_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.gridsave_yn IS '그리드 열 설정 저장여부 Y/N — tbl_grid_pref 사용 여부';


--
-- Name: COLUMN tbl_user.last_login_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.last_login_dt IS '최종 로그인 일시';


--
-- Name: COLUMN tbl_user.pw_upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.pw_upd_dt IS '비밀번호 최종 변경일시 — 주기적 변경 안내 기준';


--
-- Name: COLUMN tbl_user.login_fail_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.login_fail_cnt IS '연속 로그인 실패 횟수 — 성공 시 0으로 초기화';


--
-- Name: COLUMN tbl_user.lock_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.lock_yn IS '계정 잠금여부 Y/N — Y일 때(= 실패 임계 초과) 로그인 차단';


--
-- Name: COLUMN tbl_user.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.use_yn IS '사용여부 Y/N — N일 때(= 퇴사·비활성) 로그인 차단';


--
-- Name: COLUMN tbl_user.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_user.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_user.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_user.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_user.sign_img; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.sign_img IS '서명 이미지 바이너리 — PNG/JPG 원본. 결재·점검자 서명란에 삽입';


--
-- Name: COLUMN tbl_user.sign_mime; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.sign_mime IS '서명 이미지 MIME — image/png 또는 image/jpeg';


--
-- Name: COLUMN tbl_user.sign_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user.sign_nm IS '서명 이미지 원본 파일명 — 다운로드 시 Content-Disposition에 사용';


--
-- Name: tbl_user_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_user ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_user_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_user_noti_pref; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_user_noti_pref (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    user_id character varying(20) NOT NULL,
    noti_type_cd character varying(30) NOT NULL,
    recv_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_user_noti_pref; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_user_noti_pref IS '사용자별 알림 수신 설정 — bap1100 알림 컬럼 12종의 정규화 대체';


--
-- Name: COLUMN tbl_user_noti_pref.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user_noti_pref.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_user_noti_pref.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user_noti_pref.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_user_noti_pref.user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user_noti_pref.user_id IS '로그인 ID — tbl_user.user_id';


--
-- Name: COLUMN tbl_user_noti_pref.noti_type_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user_noti_pref.noti_type_cd IS '알림 유형 — DOC_DUE(작성기한), DOC_LATE(미작성), APPROVAL(결재요청), CA_DUE(개선조치기한), CALIB_DUE(검교정도래), EDU_DUE(교육예정) 등';


--
-- Name: COLUMN tbl_user_noti_pref.recv_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user_noti_pref.recv_yn IS '수신여부 Y/N';


--
-- Name: COLUMN tbl_user_noti_pref.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user_noti_pref.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_user_noti_pref.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user_noti_pref.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_user_noti_pref.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user_noti_pref.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_user_noti_pref.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_user_noti_pref.upd_dt IS '최종수정일시';


--
-- Name: tbl_user_noti_pref_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_user_noti_pref ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_user_noti_pref_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_vehicle; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_vehicle (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    vehicle_cd character varying(30) NOT NULL,
    car_no character varying(20) NOT NULL,
    car_type character varying(50),
    owner_nm character varying(50),
    driver_nm character varying(50),
    cooler_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    temp_recorder_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_vehicle; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_vehicle IS '차량 — 운반차량. 차량운행일지와 입고검사 차량점검의 선택 원천';


--
-- Name: COLUMN tbl_vehicle.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_vehicle.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_vehicle.vehicle_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.vehicle_cd IS '차량 코드 — 업체 내 유일';


--
-- Name: COLUMN tbl_vehicle.car_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.car_no IS '차량번호 — 차량운행일지 제목에 출력';


--
-- Name: COLUMN tbl_vehicle.car_type; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.car_type IS '차종';


--
-- Name: COLUMN tbl_vehicle.owner_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.owner_nm IS '소유자 — 자차/지입 구분용';


--
-- Name: COLUMN tbl_vehicle.driver_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.driver_nm IS '주 운전자명';


--
-- Name: COLUMN tbl_vehicle.cooler_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.cooler_yn IS '적재함 냉각기 보유여부 Y/N';


--
-- Name: COLUMN tbl_vehicle.temp_recorder_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.temp_recorder_yn IS '자동온도기록장치 보유여부 Y/N';


--
-- Name: COLUMN tbl_vehicle.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_vehicle.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_vehicle.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_vehicle.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_vehicle.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_vehicle.upd_dt IS '최종수정일시';


--
-- Name: tbl_vehicle_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_vehicle ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_vehicle_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_view_log; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_view_log (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    user_id character varying(20) NOT NULL,
    sid character varying(36),
    scrn_cd character varying(30) NOT NULL,
    enter_dt timestamp without time zone NOT NULL,
    leave_dt timestamp without time zone,
    stay_sec integer,
    ref_scrn_cd character varying(30),
    ip_addr character varying(45),
    user_agent character varying(500),
    ins_dt timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE tbl_view_log; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_view_log IS '화면 조회 원시 이벤트 — PV 1건 = 1행. 보존기간 경과분은 정리 배치로 삭제';


--
-- Name: COLUMN tbl_view_log.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_log.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_view_log.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_log.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_view_log.user_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_log.user_id IS '로그인 ID — UV 산출의 distinct 기준';


--
-- Name: COLUMN tbl_view_log.sid; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_log.sid IS '세션 UUID — tbl_login_log.sid와 조인. 세션수(sess_cnt) 산출 기준';


--
-- Name: COLUMN tbl_view_log.scrn_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_log.scrn_cd IS '화면코드 — tbl_screen.scrn_cd';


--
-- Name: COLUMN tbl_view_log.enter_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_log.enter_dt IS '화면 진입 일시 — 탭이 활성으로 전환된 시각';


--
-- Name: COLUMN tbl_view_log.leave_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_log.leave_dt IS '화면 이탈 일시 — 다른 탭으로 전환·탭 닫기·페이지 종료 시각. NULL이면(= 미종료 이벤트)';


--
-- Name: COLUMN tbl_view_log.stay_sec; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_log.stay_sec IS '체류 시간(초) — leave_dt - enter_dt. 미종료 이벤트는 NULL';


--
-- Name: COLUMN tbl_view_log.ref_scrn_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_log.ref_scrn_cd IS '직전 화면코드 — 화면 간 이동 경로 분석용';


--
-- Name: COLUMN tbl_view_log.ip_addr; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_log.ip_addr IS '접속 IP';


--
-- Name: COLUMN tbl_view_log.user_agent; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_log.user_agent IS '브라우저 User-Agent 원문';


--
-- Name: COLUMN tbl_view_log.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_log.ins_dt IS '서버 수집 일시 — 배치 전송이라 enter_dt와 차이가 날 수 있다';


--
-- Name: tbl_view_log_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_view_log ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_view_log_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_view_stat_daily; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_view_stat_daily (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    stat_dt character varying(8) NOT NULL,
    scrn_cd character varying(30) NOT NULL,
    pv_cnt integer DEFAULT 0 NOT NULL,
    uv_cnt integer DEFAULT 0 NOT NULL,
    sess_cnt integer DEFAULT 0 NOT NULL,
    avg_stay_sec numeric(10,1),
    max_stay_sec integer,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone,
    ip_cnt integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE tbl_view_stat_daily; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_view_stat_daily IS '화면별 일자 집계 — UV/PV/세션수/평균체류. 일 1회 배치 upsert, 영구 보존';


--
-- Name: COLUMN tbl_view_stat_daily.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_view_stat_daily.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_view_stat_daily.stat_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.stat_dt IS '집계일자 YYYYMMDD';


--
-- Name: COLUMN tbl_view_stat_daily.scrn_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.scrn_cd IS '화면코드 — tbl_screen.scrn_cd';


--
-- Name: COLUMN tbl_view_stat_daily.pv_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.pv_cnt IS 'PV — 해당 일자·화면의 조회 이벤트 건수';


--
-- Name: COLUMN tbl_view_stat_daily.uv_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.uv_cnt IS 'UV — 해당 일자·화면을 조회한 서로 다른 사용자 수(distinct user_id)';


--
-- Name: COLUMN tbl_view_stat_daily.sess_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.sess_cnt IS '세션수 — 서로 다른 sid 수. 같은 사용자가 여러 번 로그인하면 분리 집계';


--
-- Name: COLUMN tbl_view_stat_daily.avg_stay_sec; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.avg_stay_sec IS '평균 체류시간(초) — stay_sec이 있는 이벤트만 대상';


--
-- Name: COLUMN tbl_view_stat_daily.max_stay_sec; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.max_stay_sec IS '최대 체류시간(초)';


--
-- Name: COLUMN tbl_view_stat_daily.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.ins_id IS '최초입력자 ID — 배치 실행 주체';


--
-- Name: COLUMN tbl_view_stat_daily.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_view_stat_daily.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.upd_id IS '최종수정자 ID — 재집계 실행 주체';


--
-- Name: COLUMN tbl_view_stat_daily.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.upd_dt IS '최종수정일시';


--
-- Name: COLUMN tbl_view_stat_daily.ip_cnt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_view_stat_daily.ip_cnt IS 'IP수 — 해당 일자·화면의 서로 다른 ip_addr 수';


--
-- Name: tbl_view_stat_daily_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_view_stat_daily ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_view_stat_daily_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_work_area; Type: TABLE; Schema: sasshaccp; Owner: -
--

CREATE TABLE sasshaccp.tbl_work_area (
    idx bigint NOT NULL,
    co_cd character varying(10) NOT NULL,
    area_cd character varying(30) NOT NULL,
    area_nm character varying(100) NOT NULL,
    area_gbn character varying(10),
    lux_std integer,
    temp_std_min numeric(5,1),
    temp_std_max numeric(5,1),
    humid_std_min numeric(5,1),
    humid_std_max numeric(5,1),
    sort_no integer DEFAULT 0 NOT NULL,
    use_yn character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    ins_id character varying(20),
    ins_dt timestamp without time zone DEFAULT now(),
    upd_id character varying(20),
    upd_dt timestamp without time zone
);


--
-- Name: TABLE tbl_work_area; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON TABLE sasshaccp.tbl_work_area IS '작업장·구역 — 작업장 환경위생 점검표의 열 자동 생성 및 온습도·조도 기준 원천';


--
-- Name: COLUMN tbl_work_area.idx; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.idx IS 'PK 자동 채번 대리키';


--
-- Name: COLUMN tbl_work_area.co_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.co_cd IS '회사코드 — 테넌트 키';


--
-- Name: COLUMN tbl_work_area.area_cd; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.area_cd IS '구역 코드 — 업체 내 유일';


--
-- Name: COLUMN tbl_work_area.area_nm; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.area_nm IS '구역명 — 작업장1, 내포장실 등. A4 표 열 머리글에 출력';


--
-- Name: COLUMN tbl_work_area.area_gbn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.area_gbn IS '위생구분 — CLEAN:청결구역, SEMI:준청결구역, GENERAL:일반구역';


--
-- Name: COLUMN tbl_work_area.lux_std; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.lux_std IS '조도 기준(LUX) — 검수대 540 등';


--
-- Name: COLUMN tbl_work_area.temp_std_min; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.temp_std_min IS '실내온도 하한 기준';


--
-- Name: COLUMN tbl_work_area.temp_std_max; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.temp_std_max IS '실내온도 상한 기준';


--
-- Name: COLUMN tbl_work_area.humid_std_min; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.humid_std_min IS '습도 하한 기준(%)';


--
-- Name: COLUMN tbl_work_area.humid_std_max; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.humid_std_max IS '습도 상한 기준(%)';


--
-- Name: COLUMN tbl_work_area.sort_no; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.sort_no IS '정렬순서 — A4 표의 열 순서';


--
-- Name: COLUMN tbl_work_area.use_yn; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.use_yn IS '사용여부 Y/N';


--
-- Name: COLUMN tbl_work_area.ins_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.ins_id IS '최초입력자 ID';


--
-- Name: COLUMN tbl_work_area.ins_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.ins_dt IS '최초입력일시';


--
-- Name: COLUMN tbl_work_area.upd_id; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.upd_id IS '최종수정자 ID';


--
-- Name: COLUMN tbl_work_area.upd_dt; Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON COLUMN sasshaccp.tbl_work_area.upd_dt IS '최종수정일시';


--
-- Name: tbl_work_area_idx_seq; Type: SEQUENCE; Schema: sasshaccp; Owner: -
--

ALTER TABLE sasshaccp.tbl_work_area ALTER COLUMN idx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME sasshaccp.tbl_work_area_idx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tbl_approval_line tbl_approval_line_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_approval_line
    ADD CONSTRAINT tbl_approval_line_pkey PRIMARY KEY (idx);


--
-- Name: tbl_approval_line_step tbl_approval_line_step_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_approval_line_step
    ADD CONSTRAINT tbl_approval_line_step_pkey PRIMARY KEY (idx);


--
-- Name: tbl_area_hygiene tbl_area_hygiene_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_area_hygiene
    ADD CONSTRAINT tbl_area_hygiene_pkey PRIMARY KEY (idx);


--
-- Name: tbl_audit_log tbl_audit_log_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_audit_log
    ADD CONSTRAINT tbl_audit_log_pkey PRIMARY KEY (idx);


--
-- Name: tbl_calib_target tbl_calib_target_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_calib_target
    ADD CONSTRAINT tbl_calib_target_pkey PRIMARY KEY (idx);


--
-- Name: tbl_calib_target_row tbl_calib_target_row_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_calib_target_row
    ADD CONSTRAINT tbl_calib_target_row_pkey PRIMARY KEY (idx);


--
-- Name: tbl_ccp_cold_monitor tbl_ccp_cold_monitor_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_cold_monitor
    ADD CONSTRAINT tbl_ccp_cold_monitor_pkey PRIMARY KEY (idx);


--
-- Name: tbl_ccp_cold_monitor_temp tbl_ccp_cold_monitor_temp_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_cold_monitor_temp
    ADD CONSTRAINT tbl_ccp_cold_monitor_temp_pkey PRIMARY KEY (idx);


--
-- Name: tbl_ccp_generic_monitor_cell tbl_ccp_generic_monitor_cell_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_generic_monitor_cell
    ADD CONSTRAINT tbl_ccp_generic_monitor_cell_pkey PRIMARY KEY (idx);


--
-- Name: tbl_ccp_generic_monitor tbl_ccp_generic_monitor_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_generic_monitor
    ADD CONSTRAINT tbl_ccp_generic_monitor_pkey PRIMARY KEY (idx);


--
-- Name: tbl_ccp_generic_monitor_row tbl_ccp_generic_monitor_row_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_generic_monitor_row
    ADD CONSTRAINT tbl_ccp_generic_monitor_row_pkey PRIMARY KEY (idx);


--
-- Name: tbl_ccp_limit tbl_ccp_limit_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_limit
    ADD CONSTRAINT tbl_ccp_limit_pkey PRIMARY KEY (idx);


--
-- Name: tbl_ccp_metal_monitor tbl_ccp_metal_monitor_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_metal_monitor
    ADD CONSTRAINT tbl_ccp_metal_monitor_pkey PRIMARY KEY (idx);


--
-- Name: tbl_ccp_metal_pass_row tbl_ccp_metal_pass_row_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_metal_pass_row
    ADD CONSTRAINT tbl_ccp_metal_pass_row_pkey PRIMARY KEY (idx);


--
-- Name: tbl_ccp_metal_sens_row tbl_ccp_metal_sens_row_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_metal_sens_row
    ADD CONSTRAINT tbl_ccp_metal_sens_row_pkey PRIMARY KEY (idx);


--
-- Name: tbl_ccp_verify_check tbl_ccp_verify_check_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_verify_check
    ADD CONSTRAINT tbl_ccp_verify_check_pkey PRIMARY KEY (idx);


--
-- Name: tbl_ccp_verify_item tbl_ccp_verify_item_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_verify_item
    ADD CONSTRAINT tbl_ccp_verify_item_pkey PRIMARY KEY (idx);


--
-- Name: tbl_check_item tbl_check_item_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_check_item
    ADD CONSTRAINT tbl_check_item_pkey PRIMARY KEY (idx);


--
-- Name: tbl_code tbl_code_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_code
    ADD CONSTRAINT tbl_code_pkey PRIMARY KEY (idx);


--
-- Name: tbl_company tbl_company_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_company
    ADD CONSTRAINT tbl_company_pkey PRIMARY KEY (idx);


--
-- Name: tbl_company_template_file tbl_company_template_file_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_company_template_file
    ADD CONSTRAINT tbl_company_template_file_pkey PRIMARY KEY (idx);


--
-- Name: tbl_company_template tbl_company_template_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_company_template
    ADD CONSTRAINT tbl_company_template_pkey PRIMARY KEY (idx);


--
-- Name: tbl_corrective_action tbl_corrective_action_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_corrective_action
    ADD CONSTRAINT tbl_corrective_action_pkey PRIMARY KEY (idx);


--
-- Name: tbl_dept tbl_dept_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_dept
    ADD CONSTRAINT tbl_dept_pkey PRIMARY KEY (idx);


--
-- Name: tbl_doc_no_rule tbl_doc_no_rule_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_doc_no_rule
    ADD CONSTRAINT tbl_doc_no_rule_pkey PRIMARY KEY (idx);


--
-- Name: tbl_document_approval tbl_document_approval_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_document_approval
    ADD CONSTRAINT tbl_document_approval_pkey PRIMARY KEY (idx);


--
-- Name: tbl_document_file tbl_document_file_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_document_file
    ADD CONSTRAINT tbl_document_file_pkey PRIMARY KEY (idx);


--
-- Name: tbl_document tbl_document_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_document
    ADD CONSTRAINT tbl_document_pkey PRIMARY KEY (idx);


--
-- Name: tbl_document_relation tbl_document_relation_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_document_relation
    ADD CONSTRAINT tbl_document_relation_pkey PRIMARY KEY (idx);


--
-- Name: tbl_document_version tbl_document_version_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_document_version
    ADD CONSTRAINT tbl_document_version_pkey PRIMARY KEY (idx);


--
-- Name: tbl_grid_pref tbl_grid_pref_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_grid_pref
    ADD CONSTRAINT tbl_grid_pref_pkey PRIMARY KEY (idx);


--
-- Name: tbl_html_form_ver_item tbl_html_form_ver_item_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_html_form_ver_item
    ADD CONSTRAINT tbl_html_form_ver_item_pkey PRIMARY KEY (idx);


--
-- Name: tbl_html_form_ver tbl_html_form_ver_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_html_form_ver
    ADD CONSTRAINT tbl_html_form_ver_pkey PRIMARY KEY (idx);


--
-- Name: tbl_html_hyg_prc_ver_item tbl_html_hyg_prc_ver_item_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_html_hyg_prc_ver_item
    ADD CONSTRAINT tbl_html_hyg_prc_ver_item_pkey PRIMARY KEY (idx);


--
-- Name: tbl_html_hyg_prc_ver tbl_html_hyg_prc_ver_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_html_hyg_prc_ver
    ADD CONSTRAINT tbl_html_hyg_prc_ver_pkey PRIMARY KEY (idx);


--
-- Name: tbl_hyg_process_item tbl_hyg_process_item_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_hyg_process_item
    ADD CONSTRAINT tbl_hyg_process_item_pkey PRIMARY KEY (idx);


--
-- Name: tbl_hyg_process tbl_hyg_process_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_hyg_process
    ADD CONSTRAINT tbl_hyg_process_pkey PRIMARY KEY (idx);


--
-- Name: tbl_inv_txn tbl_inv_txn_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_inv_txn
    ADD CONSTRAINT tbl_inv_txn_pkey PRIMARY KEY (idx);


--
-- Name: tbl_login_log tbl_login_log_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_login_log
    ADD CONSTRAINT tbl_login_log_pkey PRIMARY KEY (idx);


--
-- Name: tbl_material tbl_material_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_material
    ADD CONSTRAINT tbl_material_pkey PRIMARY KEY (idx);


--
-- Name: tbl_measuring_device tbl_measuring_device_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_measuring_device
    ADD CONSTRAINT tbl_measuring_device_pkey PRIMARY KEY (idx);


--
-- Name: tbl_menu tbl_menu_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_menu
    ADD CONSTRAINT tbl_menu_pkey PRIMARY KEY (idx);


--
-- Name: tbl_notification tbl_notification_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_notification
    ADD CONSTRAINT tbl_notification_pkey PRIMARY KEY (idx);


--
-- Name: tbl_partner tbl_partner_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_partner
    ADD CONSTRAINT tbl_partner_pkey PRIMARY KEY (idx);


--
-- Name: tbl_pest_check tbl_pest_check_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_pest_check
    ADD CONSTRAINT tbl_pest_check_pkey PRIMARY KEY (idx);


--
-- Name: tbl_pest_check_row tbl_pest_check_row_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_pest_check_row
    ADD CONSTRAINT tbl_pest_check_row_pkey PRIMARY KEY (idx);


--
-- Name: tbl_pest_device tbl_pest_device_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_pest_device
    ADD CONSTRAINT tbl_pest_device_pkey PRIMARY KEY (idx);


--
-- Name: tbl_product tbl_product_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_product
    ADD CONSTRAINT tbl_product_pkey PRIMARY KEY (idx);


--
-- Name: tbl_recv_inspect tbl_recv_inspect_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_recv_inspect
    ADD CONSTRAINT tbl_recv_inspect_pkey PRIMARY KEY (idx);


--
-- Name: tbl_role tbl_role_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_role
    ADD CONSTRAINT tbl_role_pkey PRIMARY KEY (idx);


--
-- Name: tbl_role_screen tbl_role_screen_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_role_screen
    ADD CONSTRAINT tbl_role_screen_pkey PRIMARY KEY (idx);


--
-- Name: tbl_schedule_rule_detail tbl_schedule_rule_detail_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_schedule_rule_detail
    ADD CONSTRAINT tbl_schedule_rule_detail_pkey PRIMARY KEY (idx);


--
-- Name: tbl_schedule_rule tbl_schedule_rule_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_schedule_rule
    ADD CONSTRAINT tbl_schedule_rule_pkey PRIMARY KEY (idx);


--
-- Name: tbl_schedule_task tbl_schedule_task_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_schedule_task
    ADD CONSTRAINT tbl_schedule_task_pkey PRIMARY KEY (idx);


--
-- Name: tbl_screen tbl_screen_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_screen
    ADD CONSTRAINT tbl_screen_pkey PRIMARY KEY (idx);


--
-- Name: tbl_storage tbl_storage_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_storage
    ADD CONSTRAINT tbl_storage_pkey PRIMARY KEY (idx);


--
-- Name: tbl_template tbl_template_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_template
    ADD CONSTRAINT tbl_template_pkey PRIMARY KEY (idx);


--
-- Name: tbl_tml_ccp_chk_ver_item tbl_tml_ccp_chk_ver_item_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_chk_ver_item
    ADD CONSTRAINT tbl_tml_ccp_chk_ver_item_pkey PRIMARY KEY (idx);


--
-- Name: tbl_tml_ccp_chk_ver tbl_tml_ccp_chk_ver_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_chk_ver
    ADD CONSTRAINT tbl_tml_ccp_chk_ver_pkey PRIMARY KEY (idx);


--
-- Name: tbl_tml_ccp_htg_ver_item tbl_tml_ccp_htg_ver_item_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_htg_ver_item
    ADD CONSTRAINT tbl_tml_ccp_htg_ver_item_pkey PRIMARY KEY (idx);


--
-- Name: tbl_tml_ccp_htg_ver tbl_tml_ccp_htg_ver_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_htg_ver
    ADD CONSTRAINT tbl_tml_ccp_htg_ver_pkey PRIMARY KEY (idx);


--
-- Name: tbl_tml_ccp_mtl_ver_item tbl_tml_ccp_mtl_ver_item_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_mtl_ver_item
    ADD CONSTRAINT tbl_tml_ccp_mtl_ver_item_pkey PRIMARY KEY (idx);


--
-- Name: tbl_tml_ccp_mtl_ver tbl_tml_ccp_mtl_ver_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_mtl_ver
    ADD CONSTRAINT tbl_tml_ccp_mtl_ver_pkey PRIMARY KEY (idx);


--
-- Name: tbl_tml_ccp_pkg_ver_item tbl_tml_ccp_pkg_ver_item_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_pkg_ver_item
    ADD CONSTRAINT tbl_tml_ccp_pkg_ver_item_pkey PRIMARY KEY (idx);


--
-- Name: tbl_tml_ccp_pkg_ver tbl_tml_ccp_pkg_ver_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_pkg_ver
    ADD CONSTRAINT tbl_tml_ccp_pkg_ver_pkey PRIMARY KEY (idx);


--
-- Name: tbl_user_noti_pref tbl_user_noti_pref_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_user_noti_pref
    ADD CONSTRAINT tbl_user_noti_pref_pkey PRIMARY KEY (idx);


--
-- Name: tbl_user tbl_user_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_user
    ADD CONSTRAINT tbl_user_pkey PRIMARY KEY (idx);


--
-- Name: tbl_vehicle tbl_vehicle_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_vehicle
    ADD CONSTRAINT tbl_vehicle_pkey PRIMARY KEY (idx);


--
-- Name: tbl_view_log tbl_view_log_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_view_log
    ADD CONSTRAINT tbl_view_log_pkey PRIMARY KEY (idx);


--
-- Name: tbl_view_stat_daily tbl_view_stat_daily_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_view_stat_daily
    ADD CONSTRAINT tbl_view_stat_daily_pkey PRIMARY KEY (idx);


--
-- Name: tbl_work_area tbl_work_area_pkey; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_work_area
    ADD CONSTRAINT tbl_work_area_pkey PRIMARY KEY (idx);


--
-- Name: tbl_approval_line ux_tbl_approval_line; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_approval_line
    ADD CONSTRAINT ux_tbl_approval_line UNIQUE (co_cd, appr_line_cd);


--
-- Name: tbl_approval_line_step ux_tbl_approval_line_step; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_approval_line_step
    ADD CONSTRAINT ux_tbl_approval_line_step UNIQUE (co_cd, appr_line_cd, step_no);


--
-- Name: tbl_area_hygiene ux_tbl_area_hygiene; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_area_hygiene
    ADD CONSTRAINT ux_tbl_area_hygiene UNIQUE (doc_idx);


--
-- Name: tbl_calib_target ux_tbl_calib_target; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_calib_target
    ADD CONSTRAINT ux_tbl_calib_target UNIQUE (doc_idx);


--
-- Name: tbl_calib_target_row ux_tbl_calib_target_row; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_calib_target_row
    ADD CONSTRAINT ux_tbl_calib_target_row UNIQUE (hdr_idx, row_seq);


--
-- Name: tbl_ccp_cold_monitor ux_tbl_ccp_cold_monitor; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_cold_monitor
    ADD CONSTRAINT ux_tbl_ccp_cold_monitor UNIQUE (doc_idx);


--
-- Name: tbl_ccp_cold_monitor_temp ux_tbl_ccp_cold_monitor_temp; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_cold_monitor_temp
    ADD CONSTRAINT ux_tbl_ccp_cold_monitor_temp UNIQUE (row_idx, storage_cd);


--
-- Name: tbl_ccp_generic_monitor_cell ux_tbl_ccp_generic_monitor_cell; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_generic_monitor_cell
    ADD CONSTRAINT ux_tbl_ccp_generic_monitor_cell UNIQUE (row_idx, item_cd);


--
-- Name: tbl_ccp_generic_monitor ux_tbl_ccp_generic_monitor_doc; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_generic_monitor
    ADD CONSTRAINT ux_tbl_ccp_generic_monitor_doc UNIQUE (doc_idx);


--
-- Name: tbl_ccp_generic_monitor_row ux_tbl_ccp_generic_monitor_row; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_generic_monitor_row
    ADD CONSTRAINT ux_tbl_ccp_generic_monitor_row UNIQUE (monitor_idx, row_seq);


--
-- Name: tbl_ccp_limit ux_tbl_ccp_limit; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_limit
    ADD CONSTRAINT ux_tbl_ccp_limit UNIQUE (co_cd, ccp_cd);


--
-- Name: tbl_ccp_metal_monitor ux_tbl_ccp_metal_monitor; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_metal_monitor
    ADD CONSTRAINT ux_tbl_ccp_metal_monitor UNIQUE (doc_idx);


--
-- Name: tbl_ccp_metal_pass_row ux_tbl_ccp_metal_pass_row; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_metal_pass_row
    ADD CONSTRAINT ux_tbl_ccp_metal_pass_row UNIQUE (hdr_idx, row_seq);


--
-- Name: tbl_ccp_metal_sens_row ux_tbl_ccp_metal_sens_row; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_metal_sens_row
    ADD CONSTRAINT ux_tbl_ccp_metal_sens_row UNIQUE (hdr_idx, row_seq);


--
-- Name: tbl_ccp_verify_check ux_tbl_ccp_verify_check; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_verify_check
    ADD CONSTRAINT ux_tbl_ccp_verify_check UNIQUE (doc_idx);


--
-- Name: tbl_ccp_verify_item ux_tbl_ccp_verify_item; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_ccp_verify_item
    ADD CONSTRAINT ux_tbl_ccp_verify_item UNIQUE (hdr_idx, row_seq);


--
-- Name: tbl_check_item ux_tbl_check_item; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_check_item
    ADD CONSTRAINT ux_tbl_check_item UNIQUE (tmpl_cd, item_cd);


--
-- Name: tbl_code ux_tbl_code; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_code
    ADD CONSTRAINT ux_tbl_code UNIQUE (co_cd, main_cd, sub_cd);


--
-- Name: tbl_company ux_tbl_company_co_cd; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_company
    ADD CONSTRAINT ux_tbl_company_co_cd UNIQUE (co_cd);


--
-- Name: tbl_company_template ux_tbl_company_template; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_company_template
    ADD CONSTRAINT ux_tbl_company_template UNIQUE (co_cd, tmpl_cd);


--
-- Name: tbl_company_template_file ux_tbl_company_template_file; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_company_template_file
    ADD CONSTRAINT ux_tbl_company_template_file UNIQUE (co_cd, tmpl_cd, file_seq);


--
-- Name: tbl_corrective_action ux_tbl_corrective_action; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_corrective_action
    ADD CONSTRAINT ux_tbl_corrective_action UNIQUE (co_cd, ca_no);


--
-- Name: tbl_dept ux_tbl_dept_co_dept; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_dept
    ADD CONSTRAINT ux_tbl_dept_co_dept UNIQUE (co_cd, dept_cd);


--
-- Name: tbl_doc_no_rule ux_tbl_doc_no_rule; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_doc_no_rule
    ADD CONSTRAINT ux_tbl_doc_no_rule UNIQUE (co_cd, tmpl_cd);


--
-- Name: tbl_document_approval ux_tbl_document_approval; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_document_approval
    ADD CONSTRAINT ux_tbl_document_approval UNIQUE (doc_idx, step_no);


--
-- Name: tbl_document ux_tbl_document_doc_no; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_document
    ADD CONSTRAINT ux_tbl_document_doc_no UNIQUE (co_cd, doc_no);


--
-- Name: tbl_document_relation ux_tbl_document_relation; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_document_relation
    ADD CONSTRAINT ux_tbl_document_relation UNIQUE (src_doc_idx, rel_type, tgt_doc_idx);


--
-- Name: tbl_document_version ux_tbl_document_version; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_document_version
    ADD CONSTRAINT ux_tbl_document_version UNIQUE (doc_idx, ver_no);


--
-- Name: tbl_grid_pref ux_tbl_grid_pref; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_grid_pref
    ADD CONSTRAINT ux_tbl_grid_pref UNIQUE (user_id, scrn_cd, grid_id);


--
-- Name: tbl_html_form_ver ux_tbl_html_form_ver; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_html_form_ver
    ADD CONSTRAINT ux_tbl_html_form_ver UNIQUE (co_cd, tmpl_cd, ver_no);


--
-- Name: tbl_html_form_ver_item ux_tbl_html_form_ver_item; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_html_form_ver_item
    ADD CONSTRAINT ux_tbl_html_form_ver_item UNIQUE (co_cd, tmpl_cd, ver_no, item_cd);


--
-- Name: tbl_html_hyg_prc_ver ux_tbl_html_hyg_prc_ver; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_html_hyg_prc_ver
    ADD CONSTRAINT ux_tbl_html_hyg_prc_ver UNIQUE (co_cd, tmpl_cd, ver_no);


--
-- Name: tbl_html_hyg_prc_ver_item ux_tbl_html_hyg_prc_ver_item; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_html_hyg_prc_ver_item
    ADD CONSTRAINT ux_tbl_html_hyg_prc_ver_item UNIQUE (co_cd, tmpl_cd, ver_no, item_cd);


--
-- Name: tbl_hyg_process ux_tbl_hyg_process; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_hyg_process
    ADD CONSTRAINT ux_tbl_hyg_process UNIQUE (doc_idx);


--
-- Name: tbl_hyg_process_item ux_tbl_hyg_process_item; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_hyg_process_item
    ADD CONSTRAINT ux_tbl_hyg_process_item UNIQUE (hdr_idx, sort_no);


--
-- Name: tbl_material ux_tbl_material; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_material
    ADD CONSTRAINT ux_tbl_material UNIQUE (co_cd, material_cd);


--
-- Name: tbl_measuring_device ux_tbl_measuring_device; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_measuring_device
    ADD CONSTRAINT ux_tbl_measuring_device UNIQUE (co_cd, device_cd);


--
-- Name: tbl_menu ux_tbl_menu_co_menu; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_menu
    ADD CONSTRAINT ux_tbl_menu_co_menu UNIQUE (co_cd, menu_cd);


--
-- Name: tbl_partner ux_tbl_partner; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_partner
    ADD CONSTRAINT ux_tbl_partner UNIQUE (co_cd, partner_cd);


--
-- Name: tbl_pest_check ux_tbl_pest_check; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_pest_check
    ADD CONSTRAINT ux_tbl_pest_check UNIQUE (doc_idx);


--
-- Name: tbl_pest_check_row ux_tbl_pest_check_row; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_pest_check_row
    ADD CONSTRAINT ux_tbl_pest_check_row UNIQUE (hdr_idx, row_seq);


--
-- Name: tbl_pest_device ux_tbl_pest_device; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_pest_device
    ADD CONSTRAINT ux_tbl_pest_device UNIQUE (co_cd, pest_cd);


--
-- Name: tbl_product ux_tbl_product; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_product
    ADD CONSTRAINT ux_tbl_product UNIQUE (co_cd, product_cd);


--
-- Name: tbl_recv_inspect ux_tbl_recv_inspect; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_recv_inspect
    ADD CONSTRAINT ux_tbl_recv_inspect UNIQUE (doc_idx);


--
-- Name: tbl_role ux_tbl_role_co_grp; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_role
    ADD CONSTRAINT ux_tbl_role_co_grp UNIQUE (co_cd, usrgrp_cd);


--
-- Name: tbl_role_screen ux_tbl_role_screen; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_role_screen
    ADD CONSTRAINT ux_tbl_role_screen UNIQUE (co_cd, usrgrp_cd, scrn_cd);


--
-- Name: tbl_schedule_rule ux_tbl_schedule_rule; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_schedule_rule
    ADD CONSTRAINT ux_tbl_schedule_rule UNIQUE (co_cd, tmpl_cd, rule_seq);


--
-- Name: tbl_schedule_rule_detail ux_tbl_schedule_rule_detail; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_schedule_rule_detail
    ADD CONSTRAINT ux_tbl_schedule_rule_detail UNIQUE (co_cd, tmpl_cd, seq);


--
-- Name: tbl_schedule_rule ux_tbl_schedule_rule_tmpl; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_schedule_rule
    ADD CONSTRAINT ux_tbl_schedule_rule_tmpl UNIQUE (co_cd, tmpl_cd);


--
-- Name: tbl_schedule_task ux_tbl_schedule_task; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_schedule_task
    ADD CONSTRAINT ux_tbl_schedule_task UNIQUE (co_cd, tmpl_cd, base_dt);


--
-- Name: tbl_screen ux_tbl_screen_scrn_cd; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_screen
    ADD CONSTRAINT ux_tbl_screen_scrn_cd UNIQUE (scrn_cd);


--
-- Name: tbl_storage ux_tbl_storage; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_storage
    ADD CONSTRAINT ux_tbl_storage UNIQUE (co_cd, storage_cd);


--
-- Name: tbl_template ux_tbl_template; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_template
    ADD CONSTRAINT ux_tbl_template UNIQUE (tmpl_cd);


--
-- Name: tbl_tml_ccp_chk_ver ux_tbl_tml_ccp_chk_ver; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_chk_ver
    ADD CONSTRAINT ux_tbl_tml_ccp_chk_ver UNIQUE (co_cd, tmpl_cd, ver_no);


--
-- Name: tbl_tml_ccp_chk_ver_item ux_tbl_tml_ccp_chk_ver_item; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_chk_ver_item
    ADD CONSTRAINT ux_tbl_tml_ccp_chk_ver_item UNIQUE (co_cd, tmpl_cd, ver_no, item_cd);


--
-- Name: tbl_tml_ccp_htg_ver ux_tbl_tml_ccp_htg_ver; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_htg_ver
    ADD CONSTRAINT ux_tbl_tml_ccp_htg_ver UNIQUE (co_cd, tmpl_cd, ver_no);


--
-- Name: tbl_tml_ccp_htg_ver_item ux_tbl_tml_ccp_htg_ver_item; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_htg_ver_item
    ADD CONSTRAINT ux_tbl_tml_ccp_htg_ver_item UNIQUE (co_cd, tmpl_cd, ver_no, item_cd);


--
-- Name: tbl_tml_ccp_mtl_ver ux_tbl_tml_ccp_mtl_ver; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_mtl_ver
    ADD CONSTRAINT ux_tbl_tml_ccp_mtl_ver UNIQUE (co_cd, tmpl_cd, ver_no);


--
-- Name: tbl_tml_ccp_mtl_ver_item ux_tbl_tml_ccp_mtl_ver_item; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_mtl_ver_item
    ADD CONSTRAINT ux_tbl_tml_ccp_mtl_ver_item UNIQUE (co_cd, tmpl_cd, ver_no, item_cd);


--
-- Name: tbl_tml_ccp_pkg_ver ux_tbl_tml_ccp_pkg_ver; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_pkg_ver
    ADD CONSTRAINT ux_tbl_tml_ccp_pkg_ver UNIQUE (co_cd, tmpl_cd, ver_no);


--
-- Name: tbl_tml_ccp_pkg_ver_item ux_tbl_tml_ccp_pkg_ver_item; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_tml_ccp_pkg_ver_item
    ADD CONSTRAINT ux_tbl_tml_ccp_pkg_ver_item UNIQUE (co_cd, tmpl_cd, ver_no, item_cd);


--
-- Name: tbl_user ux_tbl_user_co_emp; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_user
    ADD CONSTRAINT ux_tbl_user_co_emp UNIQUE (co_cd, emp_cd);


--
-- Name: tbl_user_noti_pref ux_tbl_user_noti_pref; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_user_noti_pref
    ADD CONSTRAINT ux_tbl_user_noti_pref UNIQUE (user_id, noti_type_cd);


--
-- Name: tbl_user ux_tbl_user_user_id; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_user
    ADD CONSTRAINT ux_tbl_user_user_id UNIQUE (user_id);


--
-- Name: tbl_vehicle ux_tbl_vehicle; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_vehicle
    ADD CONSTRAINT ux_tbl_vehicle UNIQUE (co_cd, vehicle_cd);


--
-- Name: tbl_view_stat_daily ux_tbl_view_stat_daily; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_view_stat_daily
    ADD CONSTRAINT ux_tbl_view_stat_daily UNIQUE (co_cd, stat_dt, scrn_cd);


--
-- Name: tbl_work_area ux_tbl_work_area; Type: CONSTRAINT; Schema: sasshaccp; Owner: -
--

ALTER TABLE ONLY sasshaccp.tbl_work_area
    ADD CONSTRAINT ux_tbl_work_area UNIQUE (co_cd, area_cd);


--
-- Name: ix_tbl_audit_log_tgt; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_audit_log_tgt ON sasshaccp.tbl_audit_log USING btree (co_cd, tbl_nm, tgt_idx, ins_dt DESC);


--
-- Name: ix_tbl_calib_target_row_hdr; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_calib_target_row_hdr ON sasshaccp.tbl_calib_target_row USING btree (hdr_idx);


--
-- Name: ix_tbl_calib_target_row_next; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_calib_target_row_next ON sasshaccp.tbl_calib_target_row USING btree (co_cd, next_calib_dt);


--
-- Name: ix_tbl_ccp_cold_monitor_temp_row; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_ccp_cold_monitor_temp_row ON sasshaccp.tbl_ccp_cold_monitor_temp USING btree (row_idx);


--
-- Name: ix_tbl_ccp_metal_pass_row_hdr; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_ccp_metal_pass_row_hdr ON sasshaccp.tbl_ccp_metal_pass_row USING btree (hdr_idx);


--
-- Name: ix_tbl_ccp_metal_sens_row_hdr; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_ccp_metal_sens_row_hdr ON sasshaccp.tbl_ccp_metal_sens_row USING btree (hdr_idx);


--
-- Name: ix_tbl_ccp_verify_item_hdr; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_ccp_verify_item_hdr ON sasshaccp.tbl_ccp_verify_item USING btree (hdr_idx);


--
-- Name: ix_tbl_code_main; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_code_main ON sasshaccp.tbl_code USING btree (co_cd, main_cd, use_yn, sort_no);


--
-- Name: ix_tbl_company_template_file_01; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_company_template_file_01 ON sasshaccp.tbl_company_template_file USING btree (co_cd, tmpl_cd, del_yn, file_seq DESC);


--
-- Name: ix_tbl_corrective_action_src; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_corrective_action_src ON sasshaccp.tbl_corrective_action USING btree (src_doc_idx);


--
-- Name: ix_tbl_corrective_action_st; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_corrective_action_st ON sasshaccp.tbl_corrective_action USING btree (co_cd, status, due_dt);


--
-- Name: ix_tbl_document_approval_doc; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_document_approval_doc ON sasshaccp.tbl_document_approval USING btree (doc_idx, step_no);


--
-- Name: ix_tbl_document_approval_usr; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_document_approval_usr ON sasshaccp.tbl_document_approval USING btree (co_cd, approver_id, result_cd);


--
-- Name: ix_tbl_document_file_doc; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_document_file_doc ON sasshaccp.tbl_document_file USING btree (doc_idx, file_kind);


--
-- Name: ix_tbl_document_relation_tgt; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_document_relation_tgt ON sasshaccp.tbl_document_relation USING btree (tgt_doc_idx, rel_type);


--
-- Name: ix_tbl_document_retain; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_document_retain ON sasshaccp.tbl_document USING btree (co_cd, retention_until);


--
-- Name: ix_tbl_document_search; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_document_search ON sasshaccp.tbl_document USING btree (co_cd, tmpl_cd, base_dt DESC);


--
-- Name: ix_tbl_document_status; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_document_status ON sasshaccp.tbl_document USING btree (co_cd, status, base_dt DESC);


--
-- Name: ix_tbl_document_writer; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_document_writer ON sasshaccp.tbl_document USING btree (co_cd, writer_id, base_dt DESC);


--
-- Name: ix_tbl_inv_txn_dt; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_inv_txn_dt ON sasshaccp.tbl_inv_txn USING btree (co_cd, txn_dt DESC);


--
-- Name: ix_tbl_inv_txn_exp; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_inv_txn_exp ON sasshaccp.tbl_inv_txn USING btree (co_cd, expire_dt);


--
-- Name: ix_tbl_inv_txn_lot; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_inv_txn_lot ON sasshaccp.tbl_inv_txn USING btree (co_cd, lot_no);


--
-- Name: ix_tbl_login_log_co; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_login_log_co ON sasshaccp.tbl_login_log USING btree (co_cd, login_dt DESC);


--
-- Name: ix_tbl_login_log_user; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_login_log_user ON sasshaccp.tbl_login_log USING btree (user_id, login_dt DESC);


--
-- Name: ix_tbl_material_co; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_material_co ON sasshaccp.tbl_material USING btree (co_cd, use_yn, material_gbn);


--
-- Name: ix_tbl_measuring_device_co; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_measuring_device_co ON sasshaccp.tbl_measuring_device USING btree (co_cd, use_yn, sort_no);


--
-- Name: ix_tbl_menu_co; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_menu_co ON sasshaccp.tbl_menu USING btree (co_cd, use_yn, sort_no);


--
-- Name: ix_tbl_notification_user; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_notification_user ON sasshaccp.tbl_notification USING btree (co_cd, user_id, read_yn, ins_dt DESC);


--
-- Name: ix_tbl_partner_co; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_partner_co ON sasshaccp.tbl_partner USING btree (co_cd, use_yn, partner_gbn);


--
-- Name: ix_tbl_pest_check_row_hdr; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_pest_check_row_hdr ON sasshaccp.tbl_pest_check_row USING btree (hdr_idx);


--
-- Name: ix_tbl_pest_device_co; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_pest_device_co ON sasshaccp.tbl_pest_device USING btree (co_cd, use_yn, sort_no);


--
-- Name: ix_tbl_product_co; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_product_co ON sasshaccp.tbl_product USING btree (co_cd, use_yn);


--
-- Name: ix_tbl_role_screen_grp; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_role_screen_grp ON sasshaccp.tbl_role_screen USING btree (co_cd, usrgrp_cd);


--
-- Name: ix_tbl_schedule_rule_detail_01; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_schedule_rule_detail_01 ON sasshaccp.tbl_schedule_rule_detail USING btree (co_cd, tmpl_cd, seq);


--
-- Name: ix_tbl_schedule_task_alarm; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_schedule_task_alarm ON sasshaccp.tbl_schedule_task USING btree (alarm_send_yn, alarm_dt);


--
-- Name: ix_tbl_schedule_task_due; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_schedule_task_due ON sasshaccp.tbl_schedule_task USING btree (co_cd, due_dt, status);


--
-- Name: ix_tbl_schedule_task_user; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_schedule_task_user ON sasshaccp.tbl_schedule_task USING btree (co_cd, user_id, status);


--
-- Name: ix_tbl_storage_co; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_storage_co ON sasshaccp.tbl_storage USING btree (co_cd, use_yn, sort_no);


--
-- Name: ix_tbl_user_co; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_user_co ON sasshaccp.tbl_user USING btree (co_cd, use_yn);


--
-- Name: ix_tbl_vehicle_co; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_vehicle_co ON sasshaccp.tbl_vehicle USING btree (co_cd, use_yn);


--
-- Name: ix_tbl_view_log_agg; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_view_log_agg ON sasshaccp.tbl_view_log USING btree (co_cd, enter_dt, scrn_cd);


--
-- Name: ix_tbl_view_log_sid; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_view_log_sid ON sasshaccp.tbl_view_log USING btree (sid, enter_dt);


--
-- Name: ix_tbl_view_stat_dt; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_view_stat_dt ON sasshaccp.tbl_view_stat_daily USING btree (co_cd, stat_dt DESC);


--
-- Name: ix_tbl_work_area_co; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE INDEX ix_tbl_work_area_co ON sasshaccp.tbl_work_area USING btree (co_cd, use_yn, sort_no);


--
-- Name: ux_tbl_html_form_ver_apply; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE UNIQUE INDEX ux_tbl_html_form_ver_apply ON sasshaccp.tbl_html_form_ver USING btree (co_cd, tmpl_cd) WHERE ((apply_yn)::text = 'Y'::text);


--
-- Name: ux_tbl_html_form_ver_cd; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE UNIQUE INDEX ux_tbl_html_form_ver_cd ON sasshaccp.tbl_html_form_ver USING btree (co_cd, tmpl_cd, ver_cd) WHERE ((use_yn)::text = 'Y'::text);


--
-- Name: ux_tbl_html_hyg_prc_ver_apply; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE UNIQUE INDEX ux_tbl_html_hyg_prc_ver_apply ON sasshaccp.tbl_html_hyg_prc_ver USING btree (co_cd, tmpl_cd) WHERE ((apply_yn)::text = 'Y'::text);


--
-- Name: ux_tbl_html_hyg_prc_ver_cd; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE UNIQUE INDEX ux_tbl_html_hyg_prc_ver_cd ON sasshaccp.tbl_html_hyg_prc_ver USING btree (co_cd, tmpl_cd, ver_cd) WHERE ((use_yn)::text = 'Y'::text);


--
-- Name: ux_tbl_tml_ccp_chk_ver_apply; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE UNIQUE INDEX ux_tbl_tml_ccp_chk_ver_apply ON sasshaccp.tbl_tml_ccp_chk_ver USING btree (co_cd, tmpl_cd) WHERE ((apply_yn)::text = 'Y'::text);


--
-- Name: ux_tbl_tml_ccp_chk_ver_cd; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE UNIQUE INDEX ux_tbl_tml_ccp_chk_ver_cd ON sasshaccp.tbl_tml_ccp_chk_ver USING btree (co_cd, tmpl_cd, ver_cd) WHERE ((use_yn)::text = 'Y'::text);


--
-- Name: ux_tbl_tml_ccp_htg_ver_apply; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE UNIQUE INDEX ux_tbl_tml_ccp_htg_ver_apply ON sasshaccp.tbl_tml_ccp_htg_ver USING btree (co_cd, tmpl_cd) WHERE ((apply_yn)::text = 'Y'::text);


--
-- Name: ux_tbl_tml_ccp_htg_ver_cd; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE UNIQUE INDEX ux_tbl_tml_ccp_htg_ver_cd ON sasshaccp.tbl_tml_ccp_htg_ver USING btree (co_cd, tmpl_cd, ver_cd) WHERE ((use_yn)::text = 'Y'::text);


--
-- Name: ux_tbl_tml_ccp_mtl_ver_apply; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE UNIQUE INDEX ux_tbl_tml_ccp_mtl_ver_apply ON sasshaccp.tbl_tml_ccp_mtl_ver USING btree (co_cd, tmpl_cd) WHERE ((apply_yn)::text = 'Y'::text);


--
-- Name: ux_tbl_tml_ccp_mtl_ver_cd; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE UNIQUE INDEX ux_tbl_tml_ccp_mtl_ver_cd ON sasshaccp.tbl_tml_ccp_mtl_ver USING btree (co_cd, tmpl_cd, ver_cd) WHERE ((use_yn)::text = 'Y'::text);


--
-- Name: ux_tbl_tml_ccp_pkg_ver_apply; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE UNIQUE INDEX ux_tbl_tml_ccp_pkg_ver_apply ON sasshaccp.tbl_tml_ccp_pkg_ver USING btree (co_cd, tmpl_cd) WHERE ((apply_yn)::text = 'Y'::text);


--
-- Name: ux_tbl_tml_ccp_pkg_ver_cd; Type: INDEX; Schema: sasshaccp; Owner: -
--

CREATE UNIQUE INDEX ux_tbl_tml_ccp_pkg_ver_cd ON sasshaccp.tbl_tml_ccp_pkg_ver USING btree (co_cd, tmpl_cd, ver_cd) WHERE ((use_yn)::text = 'Y'::text);


--
--

\unrestrict NxeLzI9OwCGFiXEMnglo1PU5i3TO4fuKSoXf35NXjRm6dpyb5rTBiAfC2m78HSg

