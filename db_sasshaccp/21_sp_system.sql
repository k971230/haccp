-- 역할 — HACCP 시스템 관리 화면이 재사용하는 역할·메뉴 관리 저장프로시저
--
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) 기존 인증·코드·로그 SP에 없는 권한그룹과 관리자용 메뉴 목록·저장 경로만 보완한다
--   2) 모든 조회·변경은 p_co_cd로 테넌트 범위를 강제해 다른 회사의 시스템 설정을 열지 않는다
--   3) 트랜잭션은 Spring Service가 관리하며 이 파일의 PROCEDURE는 자율 COMMIT하지 않는다

SET search_path TO sasshaccp;

-- 권한그룹 목록 — 화면 권한 편집기의 마스터 목록
CREATE OR REPLACE FUNCTION sp_tbl_role_r_000(
    -- p_co_cd: JWT 회사코드 — 업체별 권한그룹 범위
    p_co_cd varchar,
    -- p_use_yn: 사용여부 필터. 공백이면 전체
    p_use_yn varchar
) RETURNS TABLE(idx bigint, usrgrp_cd varchar, usrgrp_nm varchar, desc_rmk varchar, use_yn varchar)
LANGUAGE sql AS $$
    SELECT r.idx, r.usrgrp_cd, r.usrgrp_nm, r.desc_rmk, r.use_yn
      FROM tbl_role r
     WHERE r.co_cd = p_co_cd
       AND r.use_yn LIKE concat('%', coalesce(p_use_yn, ''), '%')
     ORDER BY r.usrgrp_cd;
$$;
COMMENT ON FUNCTION sp_tbl_role_r_000(varchar, varchar) IS '권한그룹 목록 조회 — 테넌트 범위와 사용여부 필터를 강제';

-- 권한그룹 저장 — 신규·수정 모두 업무키 usrgrp_cd를 기준으로 처리
CREATE OR REPLACE PROCEDURE sp_tbl_role_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_idx: 수정 대상 대리키. 신규면 NULL
    p_idx bigint,
    -- p_usrgrp_cd: 업체 내 유일 권한그룹코드
    p_usrgrp_cd varchar,
    -- p_usrgrp_nm: 화면 표시 권한그룹명
    p_usrgrp_nm varchar,
    -- p_desc_rmk: 권한그룹 설명
    p_desc_rmk varchar,
    -- p_use_yn: 사용여부
    p_use_yn varchar,
    -- p_id: JWT 작업자 ID
    p_id varchar
) LANGUAGE plpgsql AS $$
BEGIN
    IF p_idx IS NULL THEN
        INSERT INTO tbl_role(co_cd, usrgrp_cd, usrgrp_nm, desc_rmk, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_usrgrp_cd, p_usrgrp_nm, nullif(p_desc_rmk, ''),
                coalesce(nullif(p_use_yn, ''), 'Y'), p_id, now());
    ELSE
        UPDATE tbl_role
           SET usrgrp_nm = p_usrgrp_nm, desc_rmk = nullif(p_desc_rmk, ''),
               use_yn = coalesce(nullif(p_use_yn, ''), use_yn), upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;
        IF NOT FOUND THEN RAISE EXCEPTION '수정할 권한그룹을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_role_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar) IS '권한그룹 저장 — 테넌트 범위에서 신규 또는 수정';

-- 관리자용 메뉴 목록 — 현재 로그인 사용자의 조회권한으로 필터하지 않는다
CREATE OR REPLACE FUNCTION sp_tbl_menu_admin_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar
) RETURNS TABLE(idx bigint, menu_cd varchar, menu_nm varchar, h_menu_cd varchar, scrn_cd varchar, sort_no int, use_yn varchar)
LANGUAGE sql AS $$
    SELECT m.idx, m.menu_cd, m.menu_nm, m.h_menu_cd, m.scrn_cd, m.sort_no, m.use_yn
      FROM tbl_menu m WHERE m.co_cd = p_co_cd
     ORDER BY coalesce(m.h_menu_cd, ''), m.sort_no, m.menu_cd;
$$;
COMMENT ON FUNCTION sp_tbl_menu_admin_r_000(varchar) IS '관리자용 메뉴 전체 목록 — 권한 필터 없이 현재 테넌트 메뉴를 반환';

-- 관리자 메뉴 저장 — 코드 변경은 허용하지 않아 기존 트리 연결을 보호
CREATE OR REPLACE PROCEDURE sp_tbl_menu_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_idx: 수정 대상 대리키. 신규면 NULL
    p_idx bigint,
    -- p_menu_cd: 업체 내 유일 메뉴코드
    p_menu_cd varchar,
    -- p_menu_nm: 메뉴 표시명
    p_menu_nm varchar,
    -- p_h_menu_cd: 상위 메뉴코드. 공백이면 루트
    p_h_menu_cd varchar,
    -- p_scrn_cd: 화면 leaf 코드. 공백이면 분류 노드
    p_scrn_cd varchar,
    -- p_sort_no: 같은 상위 메뉴 내 표시 순서
    p_sort_no int,
    -- p_use_yn: 사용여부
    p_use_yn varchar,
    -- p_id: JWT 작업자 ID
    p_id varchar
) LANGUAGE plpgsql AS $$
BEGIN
    IF p_idx IS NULL THEN
        INSERT INTO tbl_menu(co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_menu_cd, p_menu_nm, nullif(p_h_menu_cd, ''), nullif(p_scrn_cd, ''),
                coalesce(p_sort_no, 0), coalesce(nullif(p_use_yn, ''), 'Y'), p_id, now());
    ELSE
        UPDATE tbl_menu
           SET menu_nm = p_menu_nm, h_menu_cd = nullif(p_h_menu_cd, ''), scrn_cd = nullif(p_scrn_cd, ''),
               sort_no = coalesce(p_sort_no, sort_no), use_yn = coalesce(nullif(p_use_yn, ''), use_yn),
               upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;
        IF NOT FOUND THEN RAISE EXCEPTION '수정할 메뉴를 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_menu_c_000(varchar, bigint, varchar, varchar, varchar, varchar, int, varchar, varchar) IS '관리자 메뉴 저장 — 기존 메뉴코드는 수정하지 않는다';

-- 시스템 관리 저장 — 화면별 JSON을 고정 CASE로 기존 SP에 연결한다
CREATE OR REPLACE PROCEDURE sp_tbl_system_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_type: 허용한 관리 유형(company/user/dept/role/menu/code)
    p_type varchar,
    -- p_payload: 화면이 편집한 camelCase JSON 행
    p_payload jsonb,
    -- p_id: JWT 작업자 ID
    p_id varchar
) LANGUAGE plpgsql AS $$
DECLARE v_idx bigint := nullif(p_payload ->> 'idx', '')::bigint;
BEGIN
    IF p_type = 'company-management' THEN
        CALL sp_tbl_company_u_000(p_co_cd, p_payload ->> 'coNm', p_payload ->> 'coNmEn', p_payload ->> 'bizNo',
            p_payload ->> 'coNo', p_payload ->> 'coGbn', p_payload ->> 'ceoNm', p_payload ->> 'telNo',
            p_payload ->> 'faxNo', p_payload ->> 'zipNo', p_payload ->> 'addrH', p_payload ->> 'addrD',
            p_payload ->> 'openDt', p_payload ->> 'haccpType', p_payload ->> 'licNo', p_payload ->> 'logoPath',
            coalesce(nullif(p_payload ->> 'retentionMonth', '')::int, 24), p_id);
    ELSIF p_type = 'user-management' THEN
        CALL sp_tbl_user_c_000(p_co_cd, v_idx, p_payload ->> 'userId', p_payload ->> 'empCd', p_payload ->> 'userNm',
            p_payload ->> 'userPw', p_payload ->> 'usrgrpCd', p_payload ->> 'deptCd', p_payload ->> 'posCd',
            p_payload ->> 'email', p_payload ->> 'mobile', p_payload ->> 'signPath', p_payload ->> 'lockYn',
            p_payload ->> 'useYn', p_id, CASE WHEN v_idx IS NULL THEN 'C' ELSE 'U' END);
    ELSIF p_type = 'department-management' THEN
        CALL sp_tbl_dept_c_000(p_co_cd, v_idx, p_payload ->> 'deptCd', p_payload ->> 'deptNm', p_payload ->> 'hDeptCd',
            coalesce(nullif(p_payload ->> 'sortNo', '')::int, 0), p_payload ->> 'useYn', p_id,
            CASE WHEN v_idx IS NULL THEN 'C' ELSE 'U' END);
    ELSIF p_type = 'role-management' THEN
        CALL sp_tbl_role_c_000(p_co_cd, v_idx, p_payload ->> 'usrgrpCd', p_payload ->> 'usrgrpNm',
            p_payload ->> 'descRmk', p_payload ->> 'useYn', p_id);
    ELSIF p_type = 'menu-management' THEN
        CALL sp_tbl_menu_c_000(p_co_cd, v_idx, p_payload ->> 'menuCd', p_payload ->> 'menuNm', p_payload ->> 'hMenuCd',
            p_payload ->> 'scrnCd', coalesce(nullif(p_payload ->> 'sortNo', '')::int, 0), p_payload ->> 'useYn', p_id);
    ELSIF p_type = 'common-code-management' THEN
        CALL sp_tbl_code_c_000(p_co_cd, v_idx, p_payload ->> 'mainCd', p_payload ->> 'subCd', p_payload ->> 'codeNm',
            coalesce(nullif(p_payload ->> 'sortNo', '')::int, 0), p_payload ->> 'ref1', p_payload ->> 'ref2',
            p_payload ->> 'useYn', p_id, CASE WHEN v_idx IS NULL THEN 'C' ELSE 'U' END);
    ELSE
        RAISE EXCEPTION '지원하지 않는 시스템 관리 저장 유형입니다.' USING ERRCODE = '45000';
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_system_c_000(varchar, varchar, jsonb, varchar) IS '시스템 관리 저장 — 허용 유형만 기존 회사·사용자·부서·코드 SP로 고정 연결';

-- 시스템 관리 삭제 가능 여부 — 삭제 전·삭제 직전 모두 같은 함수로 호출한다
CREATE OR REPLACE FUNCTION sp_tbl_system_delete_blocker_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_type: 관리 유형
    p_type varchar,
    -- p_idxs: 삭제 대상 대리키 배열
    p_idxs bigint[]
) RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE plpgsql AS $$
BEGIN
    IF p_type = 'department-management' THEN
        RETURN QUERY SELECT d.dept_cd, '하위 부서 또는 사용자'
          FROM tbl_dept d WHERE d.co_cd = p_co_cd AND d.idx = ANY(p_idxs)
           AND (EXISTS (SELECT 1 FROM tbl_dept c WHERE c.co_cd = p_co_cd AND c.h_dept_cd = d.dept_cd)
             OR EXISTS (SELECT 1 FROM tbl_user u WHERE u.co_cd = p_co_cd AND u.dept_cd = d.dept_cd));
    ELSIF p_type = 'role-management' THEN
        RETURN QUERY SELECT r.usrgrp_cd, '사용자'
          FROM tbl_role r WHERE r.co_cd = p_co_cd AND r.idx = ANY(p_idxs)
           AND EXISTS (SELECT 1 FROM tbl_user u WHERE u.co_cd = p_co_cd AND u.usrgrp_cd = r.usrgrp_cd);
    ELSIF p_type = 'menu-management' THEN
        RETURN QUERY SELECT m.menu_cd, '하위 메뉴'
          FROM tbl_menu m WHERE m.co_cd = p_co_cd AND m.idx = ANY(p_idxs)
           AND EXISTS (SELECT 1 FROM tbl_menu c WHERE c.co_cd = p_co_cd AND c.h_menu_cd = m.menu_cd);
    END IF;
END$$;
COMMENT ON FUNCTION sp_tbl_system_delete_blocker_r_000(varchar, varchar, bigint[]) IS '시스템 관리 삭제 참조 차단 — 부서·권한·메뉴의 종속 행을 배열 단일 조회';

-- 시스템 관리 삭제 — 회사는 가입 테넌트를 보존하기 위해 사용중지로 전환한다
CREATE OR REPLACE PROCEDURE sp_tbl_system_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_type: 관리 유형
    p_type varchar,
    -- p_idx: 삭제 대상 대리키
    p_idx bigint,
    -- p_id: JWT 작업자 ID
    p_id varchar
) LANGUAGE plpgsql AS $$
BEGIN
    IF p_type = 'company-management' THEN
        UPDATE tbl_company SET use_yn = 'N', upd_id = p_id, upd_dt = now() WHERE co_cd = p_co_cd AND idx = p_idx;
    ELSIF p_type = 'user-management' THEN CALL sp_tbl_user_d_000(p_co_cd, p_idx);
    ELSIF p_type = 'department-management' THEN CALL sp_tbl_dept_d_000(p_co_cd, p_idx);
    ELSIF p_type = 'role-management' THEN DELETE FROM tbl_role WHERE co_cd = p_co_cd AND idx = p_idx;
    ELSIF p_type = 'menu-management' THEN DELETE FROM tbl_menu WHERE co_cd = p_co_cd AND idx = p_idx;
    ELSIF p_type = 'common-code-management' THEN CALL sp_tbl_code_d_000(p_co_cd, p_idx);
    ELSE RAISE EXCEPTION '지원하지 않는 시스템 관리 삭제 유형입니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT FOUND THEN RAISE EXCEPTION '삭제할 시스템 관리 행을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_system_d_000(varchar, varchar, bigint, varchar) IS '시스템 관리 삭제 — 회사는 비활성화, 나머지는 테넌트 범위에서 삭제';
