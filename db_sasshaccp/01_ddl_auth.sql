-- ============================================================
--  DDL 1 — 인증·플랫폼 (10 테이블)
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) MES 레거시 bas1200(회사정보)·bap1100(사용자)을 HACCP SaaS 기준으로 전면 재설계
--    2) 최대 변경점 — tbl_user.user_id 를 전역 UNIQUE 로 두어 아이디만으로 소속 회사가 결정된다
--       (로그인 화면 회사 선택 콤보 제거, GET /auth/companies 폐기)
--    3) MES/ERP 전용 컬럼(회계기수·화폐단위·KTNET·수수료계산·발주/수주/출하 알림 등)은 전부 제외
--
--  참조 무결성: FK 제약을 걸지 않는다(레거시 metis 규약 계승).
--               삭제 차단은 SP 참조 COUNT + DeleteValidation.throwIfBlocked 로 처리한다.
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. tbl_company — 회사(테넌트) 마스터
--    제거한 컬럼과 사유:
--      soc_no / ceo_tel_no / ceo_zip_no / ceo_addr_h / ceo_addr_d
--        → 대표자 주민등록번호·자택정보. HACCP 문서 SaaS에 보관 근거 없는 개인정보
--      co_seq / co_st_dt / co_fn_dt        → 회계기수·회계연도. 회계 모듈 없음
--      mall_id / spd_no                    → KTNET 전자문서 ID. EDI 연동 없음
--      curr_cd / member_lvl                → 화폐단위·회원등급. 정산 모듈 없음
--      cnt_calc / amt_calc                 → 거래 수수료 계산 여부. 정산 모듈 없음
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_company (
    idx             bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd           varchar(10)  NOT NULL,
    co_nm           varchar(100) NOT NULL,
    co_nm_en        varchar(100) NULL,
    biz_no          varchar(20)  NULL,
    co_no           varchar(20)  NULL,
    co_gbn          varchar(10)  NULL DEFAULT '1',
    ceo_nm          varchar(50)  NULL,
    tel_no          varchar(20)  NULL,
    fax_no          varchar(20)  NULL,
    zip_no          varchar(10)  NULL,
    addr_h          varchar(200) NULL,
    addr_d          varchar(200) NULL,
    open_dt         varchar(8)   NULL,
    haccp_type      varchar(20)  NULL DEFAULT 'MEAT_PACK',
    lic_no          varchar(50)  NULL,
    logo_path       varchar(300) NULL,
    retention_month int          NOT NULL DEFAULT 24,
    plan_cd         varchar(20)  NULL,
    svc_st_dt       varchar(8)   NULL,
    svc_fn_dt       varchar(8)   NULL,
    use_yn          varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id          varchar(20)  NULL,
    ins_dt          timestamp    NULL DEFAULT now(),
    upd_id          varchar(20)  NULL,
    upd_dt          timestamp    NULL,
    CONSTRAINT ux_tbl_company_co_cd UNIQUE (co_cd)
);
COMMENT ON TABLE  tbl_company                 IS '회사(테넌트) 마스터 — SaaS 가입 업체 1행.';
COMMENT ON COLUMN tbl_company.idx             IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_company.co_cd           IS '회사코드 — 테넌트 키. JWT LoginUser.coCd 및 전 SP p_co_cd 와 1:1';
COMMENT ON COLUMN tbl_company.co_nm           IS '회사명 — 전 문서 A4 헤더에 출력';
COMMENT ON COLUMN tbl_company.co_nm_en        IS '회사명(영문)';
COMMENT ON COLUMN tbl_company.biz_no          IS '사업자등록번호';
COMMENT ON COLUMN tbl_company.co_no           IS '법인등록번호';
COMMENT ON COLUMN tbl_company.co_gbn          IS '법인구분 — 1:법인, 2:개인 (tbl_code CO_GBN)';
COMMENT ON COLUMN tbl_company.ceo_nm          IS '대표자명 — 회수 안내문·성적서 등에 출력';
COMMENT ON COLUMN tbl_company.tel_no          IS '대표 전화번호';
COMMENT ON COLUMN tbl_company.fax_no          IS '팩스번호 — 회수 시 거래처 통보에 사용';
COMMENT ON COLUMN tbl_company.zip_no          IS '우편번호';
COMMENT ON COLUMN tbl_company.addr_h          IS '주소';
COMMENT ON COLUMN tbl_company.addr_d          IS '상세주소';
COMMENT ON COLUMN tbl_company.open_dt         IS '개업일 YYYYMMDD';
COMMENT ON COLUMN tbl_company.haccp_type      IS 'HACCP 업종유형 — MEAT_PACK(식육포장처리업) 등. 표준 템플릿 패키지 선택 기준';
COMMENT ON COLUMN tbl_company.lic_no          IS '영업허가(신고)번호';
COMMENT ON COLUMN tbl_company.logo_path       IS '회사 로고 파일 경로 — A4 문서 헤더 출력용';
COMMENT ON COLUMN tbl_company.retention_month IS '기본 문서 보존 개월수 — HACCP 기준 최소 24(2년)';
COMMENT ON COLUMN tbl_company.plan_cd         IS '요금제 코드 (tbl_code PLAN_CD)';
COMMENT ON COLUMN tbl_company.svc_st_dt       IS '서비스 시작일 YYYYMMDD';
COMMENT ON COLUMN tbl_company.svc_fn_dt       IS '서비스 종료일 YYYYMMDD — 경과 시 로그인 차단';
COMMENT ON COLUMN tbl_company.use_yn          IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_company.ins_id          IS '최초입력자 ID';
COMMENT ON COLUMN tbl_company.ins_dt          IS '최초입력일시';
COMMENT ON COLUMN tbl_company.upd_id          IS '최종수정자 ID';
COMMENT ON COLUMN tbl_company.upd_dt          IS '최종수정일시';

-- ------------------------------------------------------------
-- 2. tbl_dept — 부서
--    구 bac1200 계승. h_dept_cd 자기참조로 계층 구성(TreePanel 사용)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_dept (
    idx        bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10)  NOT NULL,
    dept_cd    varchar(20)  NOT NULL,
    dept_nm    varchar(100) NOT NULL,
    h_dept_cd  varchar(20)  NULL,
    sort_no    int          NOT NULL DEFAULT 0,
    use_yn     varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id     varchar(20)  NULL,
    ins_dt     timestamp    NULL DEFAULT now(),
    upd_id     varchar(20)  NULL,
    upd_dt     timestamp    NULL,
    CONSTRAINT ux_tbl_dept_co_dept UNIQUE (co_cd, dept_cd)
);
COMMENT ON TABLE  tbl_dept            IS '부서 — 업체별 조직도. 문서 결재란·작성자 부서 표기에 사용';
COMMENT ON COLUMN tbl_dept.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_dept.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_dept.dept_cd    IS '부서코드 — 업체 내 유일';
COMMENT ON COLUMN tbl_dept.dept_nm    IS '부서명';
COMMENT ON COLUMN tbl_dept.h_dept_cd  IS '상위 부서코드 — NULL이거나 공백일 때(= 최상위 노드) 트리 루트';
COMMENT ON COLUMN tbl_dept.sort_no    IS '정렬순서 — 같은 상위 안에서의 표시 순서';
COMMENT ON COLUMN tbl_dept.use_yn     IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_dept.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_dept.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_dept.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_dept.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 3. tbl_role — 권한그룹
--    사용자는 tbl_user.usrgrp_cd 로 권한그룹 1개에 소속된다(단일 역할 모델)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_role (
    idx        bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10)  NOT NULL,
    usrgrp_cd  varchar(20)  NOT NULL,
    usrgrp_nm  varchar(100) NOT NULL,
    desc_rmk   varchar(300) NULL,
    use_yn     varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id     varchar(20)  NULL,
    ins_dt     timestamp    NULL DEFAULT now(),
    upd_id     varchar(20)  NULL,
    upd_dt     timestamp    NULL,
    CONSTRAINT ux_tbl_role_co_grp UNIQUE (co_cd, usrgrp_cd)
);
COMMENT ON TABLE  tbl_role            IS '권한그룹 — HACCP팀장/모니터링담당자/일반작업자 등';
COMMENT ON COLUMN tbl_role.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_role.co_cd      IS '회사코드 — 테넌트 키. 0000일 때(= 플랫폼 예약 회사) 플랫폼 공통 권한그룹';
COMMENT ON COLUMN tbl_role.usrgrp_cd  IS '권한그룹코드 — 업체 내 유일. PLATFORM은 플랫폼 관리자 예약어';
COMMENT ON COLUMN tbl_role.usrgrp_nm  IS '권한그룹명';
COMMENT ON COLUMN tbl_role.desc_rmk   IS '설명';
COMMENT ON COLUMN tbl_role.use_yn     IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_role.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_role.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_role.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_role.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 4. tbl_role_screen — 권한그룹별 화면 권한
--    조회/등록/수정/삭제/출력 5종 플래그. 미등록 화면은 접근 불가로 간주한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_role_screen (
    idx        bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10) NOT NULL,
    usrgrp_cd  varchar(20) NOT NULL,
    scrn_cd    varchar(30) NOT NULL,
    read_yn    varchar(1)  NOT NULL DEFAULT 'Y',
    write_yn   varchar(1)  NOT NULL DEFAULT 'N',
    modify_yn  varchar(1)  NOT NULL DEFAULT 'N',
    delete_yn  varchar(1)  NOT NULL DEFAULT 'N',
    print_yn   varchar(1)  NOT NULL DEFAULT 'Y',
    ins_id     varchar(20) NULL,
    ins_dt     timestamp   NULL DEFAULT now(),
    upd_id     varchar(20) NULL,
    upd_dt     timestamp   NULL,
    CONSTRAINT ux_tbl_role_screen UNIQUE (co_cd, usrgrp_cd, scrn_cd)
);
COMMENT ON TABLE  tbl_role_screen           IS '권한그룹별 화면 권한 — SideMenu 노출과 그리드 CRUD 잠금(useGridAccess)의 근거';
COMMENT ON COLUMN tbl_role_screen.idx       IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_role_screen.co_cd     IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_role_screen.usrgrp_cd IS '권한그룹코드 — tbl_role.usrgrp_cd';
COMMENT ON COLUMN tbl_role_screen.scrn_cd   IS '화면코드 — tbl_screen.scrn_cd';
COMMENT ON COLUMN tbl_role_screen.read_yn   IS '조회 권한 Y/N — N일 때(= 메뉴 자체 숨김)';
COMMENT ON COLUMN tbl_role_screen.write_yn  IS '등록(신규행 추가) 권한 Y/N';
COMMENT ON COLUMN tbl_role_screen.modify_yn IS '수정(기존행 편집) 권한 Y/N';
COMMENT ON COLUMN tbl_role_screen.delete_yn IS '삭제 권한 Y/N';
COMMENT ON COLUMN tbl_role_screen.print_yn  IS '출력(A4 인쇄·PDF 다운로드) 권한 Y/N';
COMMENT ON COLUMN tbl_role_screen.ins_id    IS '최초입력자 ID';
COMMENT ON COLUMN tbl_role_screen.ins_dt    IS '최초입력일시';
COMMENT ON COLUMN tbl_role_screen.upd_id    IS '최종수정자 ID';
COMMENT ON COLUMN tbl_role_screen.upd_dt    IS '최종수정일시';

-- ------------------------------------------------------------
-- 5. tbl_user — 사용자
--    구 bap1100 재설계. 제거한 컬럼과 사유:
--      orderout_yn / receipt_yn / receive_yn / orderin_yn / workorder_yn
--      product_yn  / shipping_yn / down_yn   / defect_yn  / buy_yn / sale_yn
--        → MES 발주·수주·입고·작업지시·생산·출하·비가동·불량·매입·매출 알림 플래그.
--          HACCP 알림 유형이 다르고 유형이 늘 때마다 DDL을 바꿔야 하므로
--          tbl_user_noti_pref 자식 테이블로 정규화하여 대체한다
--      infoexec_yn / receiveinfo_yn → 위 자식 테이블로 흡수
--
--    핵심 변경: PK가 (usr_id, co_cd) 복합키 → idx 단일 + user_id 전역 UNIQUE
--              아이디만으로 소속 회사가 결정되므로 로그인 시 회사 선택이 사라진다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_user (
    idx             bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         varchar(20)  NOT NULL,
    co_cd           varchar(10)  NOT NULL,
    emp_cd          varchar(20)  NULL,
    user_nm         varchar(50)  NOT NULL,
    user_pw         varchar(300) NOT NULL,
    usrgrp_cd       varchar(20)  NOT NULL,
    dept_cd         varchar(20)  NULL,
    pos_cd          varchar(20)  NULL,
    email           varchar(100) NULL,
    mobile          varchar(20)  NULL,
    sign_path       varchar(300) NULL,
    gridsave_yn     varchar(1)   NOT NULL DEFAULT 'Y',
    last_login_dt   timestamp    NULL,
    pw_upd_dt       timestamp    NULL,
    login_fail_cnt  int          NOT NULL DEFAULT 0,
    lock_yn         varchar(1)   NOT NULL DEFAULT 'N',
    use_yn          varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id          varchar(20)  NULL,
    ins_dt          timestamp    NULL DEFAULT now(),
    upd_id          varchar(20)  NULL,
    upd_dt          timestamp    NULL,
    CONSTRAINT ux_tbl_user_user_id UNIQUE (user_id),
    CONSTRAINT ux_tbl_user_co_emp  UNIQUE (co_cd, emp_cd)
);
COMMENT ON TABLE  tbl_user                IS '사용자 — 구 bap1100 재설계. user_id 전역 UNIQUE로 아이디만으로 소속 회사 결정';
COMMENT ON COLUMN tbl_user.idx            IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_user.user_id        IS '로그인 ID — 전 테넌트 통틀어 유일(ux_tbl_user_user_id). 로그인 시 회사 선택 불필요';
COMMENT ON COLUMN tbl_user.co_cd          IS '소속 회사코드 — 로그인 성공 시 JWT coCd 클레임으로 주입되어 전 SP 테넌트 범위를 결정';
COMMENT ON COLUMN tbl_user.emp_cd         IS '사번 — 업체 내 유일(NULL 허용, PG는 NULL 중복 허용)';
COMMENT ON COLUMN tbl_user.user_nm        IS '사용자명 — 문서 작성자·점검자·결재자란에 출력';
COMMENT ON COLUMN tbl_user.user_pw        IS '비밀번호 해시 — PasswordHasher 산출값. 평문 저장 금지';
COMMENT ON COLUMN tbl_user.usrgrp_cd      IS '권한그룹코드 — tbl_role.usrgrp_cd. PLATFORM일 때(= 플랫폼 관리자) 업체 전환 가능';
COMMENT ON COLUMN tbl_user.dept_cd        IS '부서코드 — tbl_dept.dept_cd';
COMMENT ON COLUMN tbl_user.pos_cd         IS '직위코드 — 문서 결재란 직위 표기 (tbl_code POS_CD)';
COMMENT ON COLUMN tbl_user.email          IS '이메일 — 알림 발송 주소';
COMMENT ON COLUMN tbl_user.mobile         IS '휴대전화번호';
COMMENT ON COLUMN tbl_user.sign_path      IS '서명 이미지 파일 경로 — 결재·점검자 서명란에 삽입';
COMMENT ON COLUMN tbl_user.gridsave_yn    IS '그리드 열 설정 저장여부 Y/N — tbl_grid_pref 사용 여부';
COMMENT ON COLUMN tbl_user.last_login_dt  IS '최종 로그인 일시';
COMMENT ON COLUMN tbl_user.pw_upd_dt      IS '비밀번호 최종 변경일시 — 주기적 변경 안내 기준';
COMMENT ON COLUMN tbl_user.login_fail_cnt IS '연속 로그인 실패 횟수 — 성공 시 0으로 초기화';
COMMENT ON COLUMN tbl_user.lock_yn        IS '계정 잠금여부 Y/N — Y일 때(= 실패 임계 초과) 로그인 차단';
COMMENT ON COLUMN tbl_user.use_yn         IS '사용여부 Y/N — N일 때(= 퇴사·비활성) 로그인 차단';
COMMENT ON COLUMN tbl_user.ins_id         IS '최초입력자 ID';
COMMENT ON COLUMN tbl_user.ins_dt         IS '최초입력일시';
COMMENT ON COLUMN tbl_user.upd_id         IS '최종수정자 ID';
COMMENT ON COLUMN tbl_user.upd_dt         IS '최종수정일시';

-- ------------------------------------------------------------
-- 6. tbl_user_noti_pref — 사용자별 알림 수신 설정
--    bap1100의 알림 *_YN 컬럼 12종을 정규화한 자식 테이블.
--    알림 유형이 추가돼도 DDL 변경 없이 행만 늘어난다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_user_noti_pref (
    idx          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10) NOT NULL,
    user_id      varchar(20) NOT NULL,
    noti_type_cd varchar(30) NOT NULL,
    recv_yn      varchar(1)  NOT NULL DEFAULT 'Y',
    ins_id       varchar(20) NULL,
    ins_dt       timestamp   NULL DEFAULT now(),
    upd_id       varchar(20) NULL,
    upd_dt       timestamp   NULL,
    CONSTRAINT ux_tbl_user_noti_pref UNIQUE (user_id, noti_type_cd)
);
COMMENT ON TABLE  tbl_user_noti_pref              IS '사용자별 알림 수신 설정 — bap1100 알림 컬럼 12종의 정규화 대체';
COMMENT ON COLUMN tbl_user_noti_pref.idx          IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_user_noti_pref.co_cd        IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_user_noti_pref.user_id      IS '로그인 ID — tbl_user.user_id';
COMMENT ON COLUMN tbl_user_noti_pref.noti_type_cd IS '알림 유형 — DOC_DUE(작성기한), DOC_LATE(미작성), APPROVAL(결재요청), CA_DUE(개선조치기한), CALIB_DUE(검교정도래), EDU_DUE(교육예정) 등';
COMMENT ON COLUMN tbl_user_noti_pref.recv_yn      IS '수신여부 Y/N';
COMMENT ON COLUMN tbl_user_noti_pref.ins_id       IS '최초입력자 ID';
COMMENT ON COLUMN tbl_user_noti_pref.ins_dt       IS '최초입력일시';
COMMENT ON COLUMN tbl_user_noti_pref.upd_id       IS '최종수정자 ID';
COMMENT ON COLUMN tbl_user_noti_pref.upd_dt       IS '최종수정일시';

-- ------------------------------------------------------------
-- 7. tbl_screen — 화면 마스터 (플랫폼 전역, co_cd 없음)
--    메뉴·권한·UV/PV 통계가 공통으로 참조하는 차원 테이블
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_screen (
    idx        bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scrn_cd    varchar(30)  NOT NULL,
    scrn_nm    varchar(100) NOT NULL,
    module_cd  varchar(10)  NOT NULL,
    tmpl_cd    varchar(40)  NULL,
    sort_no    int          NOT NULL DEFAULT 0,
    use_yn     varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id     varchar(20)  NULL,
    ins_dt     timestamp    NULL DEFAULT now(),
    upd_id     varchar(20)  NULL,
    upd_dt     timestamp    NULL,
    CONSTRAINT ux_tbl_screen_scrn_cd UNIQUE (scrn_cd)
);
COMMENT ON TABLE  tbl_screen           IS '화면 마스터 — 플랫폼 전역. 메뉴·권한·UV/PV 통계의 공통 차원';
COMMENT ON COLUMN tbl_screen.idx       IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_screen.scrn_cd   IS '화면 식별자 — 역할 기반 kebab-case. FE screenRegistry 키와 1:1';
COMMENT ON COLUMN tbl_screen.scrn_nm   IS '화면명 — 탭 제목·통계 표시명';
COMMENT ON COLUMN tbl_screen.module_cd IS '모듈코드 — SYS/BAS/CCP/HYG/FAC/INV/VER/DOC/TSK. URL 첫 세그먼트';
COMMENT ON COLUMN tbl_screen.tmpl_cd   IS '연결 템플릿코드 — tbl_template.tmpl_cd. 점검표 화면일 때만 값이 있다';
COMMENT ON COLUMN tbl_screen.sort_no   IS '정렬순서';
COMMENT ON COLUMN tbl_screen.use_yn    IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_screen.ins_id    IS '최초입력자 ID';
COMMENT ON COLUMN tbl_screen.ins_dt    IS '최초입력일시';
COMMENT ON COLUMN tbl_screen.upd_id    IS '최종수정자 ID';
COMMENT ON COLUMN tbl_screen.upd_dt    IS '최종수정일시';

-- ------------------------------------------------------------
-- 8. tbl_menu — 업체별 메뉴 트리
--    h_menu_cd 자기참조 3단(대분류 → 중분류 → 화면 leaf)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_menu (
    idx        bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10)  NOT NULL,
    menu_cd    varchar(40)  NOT NULL,
    menu_nm    varchar(100) NOT NULL,
    -- 상위 메뉴코드 — kebab 대·중 분류(예: menu-doc-write)까지 수용
    h_menu_cd  varchar(40)  NULL,
    scrn_cd    varchar(30)  NULL,
    sort_no    int          NOT NULL DEFAULT 0,
    use_yn     varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id     varchar(20)  NULL,
    ins_dt     timestamp    NULL DEFAULT now(),
    upd_id     varchar(20)  NULL,
    upd_dt     timestamp    NULL,
    CONSTRAINT ux_tbl_menu_co_menu UNIQUE (co_cd, menu_cd)
);
COMMENT ON TABLE  tbl_menu            IS '업체별 메뉴 트리 — SideMenu 3단 구성. 미사용 양식은 use_yn=N으로 숨긴다';
COMMENT ON COLUMN tbl_menu.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_menu.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_menu.menu_cd    IS '메뉴코드 — 업체 내 유일';
COMMENT ON COLUMN tbl_menu.menu_nm    IS '메뉴명';
COMMENT ON COLUMN tbl_menu.h_menu_cd  IS '상위 메뉴코드 — NULL이거나 공백일 때(= 대분류) 트리 루트';
COMMENT ON COLUMN tbl_menu.scrn_cd    IS '화면코드 — tbl_screen.scrn_cd. 값이 있을 때(= leaf 노드) 클릭 시 탭이 열린다';
COMMENT ON COLUMN tbl_menu.sort_no    IS '정렬순서';
COMMENT ON COLUMN tbl_menu.use_yn     IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_menu.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_menu.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_menu.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_menu.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 9. tbl_code — 공통코드
--    sub_cd = '*' 행이 대분류(그룹) 헤더, 그 외가 세부코드
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_code (
    idx      bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd    varchar(10)  NOT NULL,
    main_cd  varchar(20)  NOT NULL,
    sub_cd   varchar(20)  NOT NULL,
    code_nm  varchar(100) NOT NULL,
    sort_no  int          NOT NULL DEFAULT 0,
    ref1     varchar(100) NULL,
    ref2     varchar(100) NULL,
    sys_yn   varchar(1)   NOT NULL DEFAULT 'N',
    use_yn   varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id   varchar(20)  NULL,
    ins_dt   timestamp    NULL DEFAULT now(),
    upd_id   varchar(20)  NULL,
    upd_dt   timestamp    NULL,
    CONSTRAINT ux_tbl_code UNIQUE (co_cd, main_cd, sub_cd)
);
COMMENT ON TABLE  tbl_code          IS '공통코드 — sub_cd=* 행이 그룹 헤더';
COMMENT ON COLUMN tbl_code.idx      IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_code.co_cd    IS '회사코드 — 테넌트 키. 0000일 때(= 플랫폼 표준코드) 전 업체 공용';
COMMENT ON COLUMN tbl_code.main_cd  IS '대분류 코드';
COMMENT ON COLUMN tbl_code.sub_cd   IS '세부 코드 — *일 때(= 그룹 헤더행) code_nm이 그룹명';
COMMENT ON COLUMN tbl_code.code_nm  IS '코드명';
COMMENT ON COLUMN tbl_code.sort_no  IS '정렬순서';
COMMENT ON COLUMN tbl_code.ref1     IS '참조값1 — 단위·기준값 등 코드별 부가정보';
COMMENT ON COLUMN tbl_code.ref2     IS '참조값2';
COMMENT ON COLUMN tbl_code.sys_yn   IS '시스템코드 여부 Y/N — Y일 때(= 플랫폼 고정코드) 업체 수정·삭제 불가';
COMMENT ON COLUMN tbl_code.use_yn   IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_code.ins_id   IS '최초입력자 ID';
COMMENT ON COLUMN tbl_code.ins_dt   IS '최초입력일시';
COMMENT ON COLUMN tbl_code.upd_id   IS '최종수정자 ID';
COMMENT ON COLUMN tbl_code.upd_dt   IS '최종수정일시';

-- ------------------------------------------------------------
-- 10. tbl_grid_pref — 사용자별 그리드 열 설정
--     FE components/grid/gridPref.ts v2 직렬화 결과(hidden·order·sizing)를 그대로 보관
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_grid_pref (
    idx       bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd     varchar(10) NOT NULL,
    user_id   varchar(20) NOT NULL,
    scrn_cd   varchar(30) NOT NULL,
    grid_id   varchar(30) NOT NULL,
    pref_json text        NOT NULL,
    ins_id    varchar(20) NULL,
    ins_dt    timestamp   NULL DEFAULT now(),
    upd_id    varchar(20) NULL,
    upd_dt    timestamp   NULL,
    CONSTRAINT ux_tbl_grid_pref UNIQUE (user_id, scrn_cd, grid_id)
);
COMMENT ON TABLE  tbl_grid_pref           IS '사용자별 그리드 열 설정 — 숨김·순서·너비만 저장. 정렬·필터는 세션 보관';
COMMENT ON COLUMN tbl_grid_pref.idx       IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_grid_pref.co_cd     IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_grid_pref.user_id   IS '로그인 ID — tbl_user.user_id';
COMMENT ON COLUMN tbl_grid_pref.scrn_cd   IS '화면코드 — tbl_screen.scrn_cd';
COMMENT ON COLUMN tbl_grid_pref.grid_id   IS '그리드 식별자 — MesEditableGrid persistId (한 화면에 그리드가 여럿일 때 구분)';
COMMENT ON COLUMN tbl_grid_pref.pref_json IS '열 설정 JSON — gridPref v2 직렬화 문자열';
COMMENT ON COLUMN tbl_grid_pref.ins_id    IS '최초입력자 ID';
COMMENT ON COLUMN tbl_grid_pref.ins_dt    IS '최초입력일시';
COMMENT ON COLUMN tbl_grid_pref.upd_id    IS '최종수정자 ID';
COMMENT ON COLUMN tbl_grid_pref.upd_dt    IS '최종수정일시';
