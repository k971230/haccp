-- ============================================================
--  migrate 65 — 부서 관리 화면 전용 SP 신설
--
--  개발자: 박승우
--  일자: 2026-08-12
--  코멘트:
--    1) 부서는 트리 화면이라 조회에서 상위부서명(self LEFT JOIN)을 함께 내려 FE가 다시 매핑하지 않게 한다
--    2) 삭제 차단 우선순위는 직접 사용자 > 하위트리 사용자 > 직속 하위 부서 순이다 — 사용자에게 가장 가까운 사유부터 보여준다
--    3) 생성 전용 — 레거시 sp_tbl_dept_* DROP은 68에서 수행
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_tbl_dept_mgmt_r_000 — 부서 목록 (트리 정렬 · 상위부서명)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_dept_mgmt_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_dept_mgmt_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_dept_cd: 페이지 헤더 부서코드 검색어. 공백이면 전체
    p_dept_cd varchar,
    -- p_dept_nm: 페이지 헤더 부서명 검색어. 공백이면 전체
    p_dept_nm varchar,
    -- p_use_yn: 페이지 헤더 사용여부. 공백이면 Y·N 모두
    p_use_yn  varchar
)
RETURNS TABLE(
    idx       bigint,
    co_cd     varchar,
    dept_cd   varchar,
    dept_nm   varchar,
    h_dept_cd varchar,
    -- 상위부서명 — 그리드 표시 전용. 저장은 코드(h_dept_cd)로만 한다
    h_dept_nm varchar,
    sort_no   int,
    use_yn    varchar
) LANGUAGE sql AS $$
    SELECT d.idx, d.co_cd, d.dept_cd, d.dept_nm, d.h_dept_cd,
           p.dept_nm AS h_dept_nm,
           d.sort_no, d.use_yn
      FROM tbl_dept d
      -- 상위부서 — 최상위면 h_dept_nm은 NULL
      LEFT JOIN tbl_dept p
        ON p.co_cd = d.co_cd
       AND p.dept_cd = d.h_dept_cd
     WHERE d.co_cd = p_co_cd
       AND d.dept_cd LIKE CONCAT('%', COALESCE(p_dept_cd, ''), '%')
       AND d.dept_nm LIKE CONCAT('%', COALESCE(p_dept_nm, ''), '%')
       AND d.use_yn  LIKE CONCAT('%', COALESCE(p_use_yn,  ''), '%')
     -- 최상위 먼저, 그다음 정렬순서·코드 순 — FE 트리 조립 순서와 동일
     ORDER BY CASE WHEN COALESCE(d.h_dept_cd, '') = '' THEN 0 ELSE 1 END, d.sort_no, d.dept_cd;
$$;
COMMENT ON FUNCTION sp_tbl_dept_mgmt_r_000(varchar, varchar, varchar, varchar) IS
  '부서 목록 — 상위부서명 self JOIN, 최상위 우선 트리 정렬, 헤더 코드·명·사용여부 LIKE';

-- ------------------------------------------------------------
-- 2. sp_tbl_dept_mgmt_c_000 — 부서 저장
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_dept_mgmt_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd     varchar,
    -- p_idx: 수정 대상 대리키. 신규면 NULL
    p_idx       bigint,
    -- p_dept_cd: 업체 내 유일 부서코드
    p_dept_cd   varchar,
    -- p_dept_nm: 부서명
    p_dept_nm   varchar,
    -- p_h_dept_cd: 상위 부서코드. 공백이면 최상위
    p_h_dept_cd varchar,
    -- p_sort_no: 같은 상위 안에서의 표시 순서
    p_sort_no   int,
    -- p_use_yn: 사용여부
    p_use_yn    varchar,
    -- p_id: JWT 작업자 ID — 감사 컬럼
    p_id        varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 업무키 중복 검사 건수
    v_cnt int;
BEGIN
    -- 부서명이 비면(= 화면이 값을 빠뜨림) 기존 이름을 공백으로 덮어쓰게 되므로 막는다
    IF COALESCE(trim(p_dept_nm), '') = '' THEN
        RAISE EXCEPTION '부서명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    IF p_idx IS NULL THEN
        SELECT COUNT(*) INTO v_cnt FROM tbl_dept WHERE co_cd = p_co_cd AND dept_cd = p_dept_cd;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 등록된 부서코드입니다: %', p_dept_cd USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_dept(co_cd, dept_cd, dept_nm, h_dept_cd, sort_no, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_dept_cd, p_dept_nm, NULLIF(p_h_dept_cd, ''),
                COALESCE(p_sort_no, 0), COALESCE(NULLIF(p_use_yn, ''), 'Y'), p_id, now());
    ELSE
        -- 자기 자신을 상위로 지정하면 트리가 끊긴다
        -- 상위가 비었을 때(= 최상위 지정)는 검사 대상이 아니다. 빈 값끼리 같다고 막으면 엉뚱한 문구가 나간다
        IF NULLIF(p_h_dept_cd, '') IS NOT NULL AND p_h_dept_cd = p_dept_cd THEN
            RAISE EXCEPTION '자기 자신을 상위 부서로 지정할 수 없습니다.' USING ERRCODE = '45000';
        END IF;

        UPDATE tbl_dept
           SET dept_nm   = p_dept_nm,
               h_dept_cd = NULLIF(p_h_dept_cd, ''),
               sort_no   = COALESCE(p_sort_no, sort_no),
               use_yn    = COALESCE(NULLIF(p_use_yn, ''), use_yn),
               upd_id    = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;
        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 부서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_dept_mgmt_c_000(varchar, bigint, varchar, varchar, varchar, int, varchar, varchar) IS
  '부서 저장 — 신규는 코드 중복 검사, 수정은 자기참조 방지';

-- ------------------------------------------------------------
-- 3. sp_tbl_dept_mgmt_delete_blocker_r_000 — 삭제 참조 검증
--    사유 우선순위: 직접 사용자 > 하위트리 사용자 > 직속 하위 부서
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_dept_mgmt_delete_blocker_r_000(varchar, bigint[]);
CREATE FUNCTION sp_tbl_dept_mgmt_delete_blocker_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_idxs: 삭제 대상 대리키 배열
    p_idxs  bigint[]
)
RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE sql AS $$
    WITH tgt AS (
        SELECT d.dept_cd,
               -- 이 부서를 직접 쓰는 사용자
               EXISTS (SELECT 1 FROM tbl_user u
                        WHERE u.co_cd = p_co_cd AND u.dept_cd = d.dept_cd) AS has_user,
               -- 하위 트리 어딘가에 사용자가 있으면 상위도 지울 수 없다
               EXISTS (
                   WITH RECURSIVE sub AS (
                       SELECT c.dept_cd
                         FROM tbl_dept c
                        WHERE c.co_cd = p_co_cd AND c.h_dept_cd = d.dept_cd
                       UNION ALL
                       SELECT c2.dept_cd
                         FROM tbl_dept c2
                         INNER JOIN sub s ON s.dept_cd = c2.h_dept_cd
                        WHERE c2.co_cd = p_co_cd
                   )
                   SELECT 1 FROM sub s
                    INNER JOIN tbl_user u ON u.co_cd = p_co_cd AND u.dept_cd = s.dept_cd
               ) AS has_sub_user,
               -- 직속 하위 부서
               EXISTS (SELECT 1 FROM tbl_dept c
                        WHERE c.co_cd = p_co_cd AND c.h_dept_cd = d.dept_cd) AS has_child
          FROM tbl_dept d
         WHERE d.co_cd = p_co_cd
           AND d.idx = ANY(p_idxs)
    )
    SELECT t.dept_cd::varchar AS ref_key,
           (CASE WHEN t.has_user     THEN '사용자'
                 WHEN t.has_sub_user THEN '하위 부서 사용자'
                 ELSE                     '하위 부서'
            END)::varchar AS target
      FROM tgt t
     WHERE t.has_user OR t.has_sub_user OR t.has_child
     LIMIT 1;
$$;
COMMENT ON FUNCTION sp_tbl_dept_mgmt_delete_blocker_r_000(varchar, bigint[]) IS
  '부서 삭제 차단 — 사용자·하위트리 사용자·하위 부서. 위반 첫 건만 반환';

-- ------------------------------------------------------------
-- 4. sp_tbl_dept_mgmt_d_000 — 부서 삭제
--    blocker와 같은 세 조건을 삭제 직전에 다시 본다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_dept_mgmt_d_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 안전장치
    p_co_cd varchar,
    -- p_idx: 삭제 대상 tbl_dept.idx
    p_idx   bigint
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 삭제 대상 부서코드. NULL이면 대상 없음
    v_dept_cd varchar(20);
    -- 참조 건수 검사용
    v_cnt     int;
BEGIN
    SELECT dept_cd INTO v_dept_cd FROM tbl_dept WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_dept_cd IS NULL THEN
        RAISE EXCEPTION '삭제할 부서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 사용자관리에서 이 부서를 직접 사용 중
    SELECT COUNT(*) INTO v_cnt FROM tbl_user u
     WHERE u.co_cd = p_co_cd AND u.dept_cd = v_dept_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '사용자가 사용 중인 부서는 삭제할 수 없습니다: %', v_dept_cd USING ERRCODE = '45000';
    END IF;

    -- 하위 부서 트리에 사용자가 있으면 상위도 삭제 불가
    WITH RECURSIVE sub AS (
        SELECT c.dept_cd
          FROM tbl_dept c
         WHERE c.co_cd = p_co_cd AND c.h_dept_cd = v_dept_cd
        UNION ALL
        SELECT c2.dept_cd
          FROM tbl_dept c2
          INNER JOIN sub s ON s.dept_cd = c2.h_dept_cd
         WHERE c2.co_cd = p_co_cd
    )
    SELECT COUNT(*) INTO v_cnt
      FROM sub s
      INNER JOIN tbl_user u ON u.co_cd = p_co_cd AND u.dept_cd = s.dept_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '하위 부서에 사용자가 있어 삭제할 수 없습니다: %', v_dept_cd USING ERRCODE = '45000';
    END IF;

    -- 직속 하위 부서가 남으면 트리가 끊긴다
    SELECT COUNT(*) INTO v_cnt FROM tbl_dept WHERE co_cd = p_co_cd AND h_dept_cd = v_dept_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '하위 부서가 있어 삭제할 수 없습니다: %', v_dept_cd USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_dept WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_dept_mgmt_d_000(varchar, bigint) IS
  '부서 삭제 — 사용자·하위트리 사용자·하위 부서 차단 후 삭제';
