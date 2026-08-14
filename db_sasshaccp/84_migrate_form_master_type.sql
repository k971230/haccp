-- ============================================================
-- 84 — 사용양식 구분(시스템/자사양식) · 양식파일 이력 · 초기화
--
-- 파일번호: 84
-- 이전번호: 83
-- 개발자: 박승우
-- 일자: 2026-08-14
-- 코멘트:
--   1) 양식의 출처를 tbl_company_template.sys_yn(sys=시스템, usr=자사양식) 하나로만 판정한다
--      파일을 바꿔도 출처는 바뀌지 않는다 — 사용자가 만든 양식은 서버가 항상 usr 로 강제한다
--   2) 기본 제공 파일과 회사가 현재 쓰는 파일을 분리한다
--      tbl_company_template_file 이력 + default_file_idx(기본) / current_file_idx(현재)
--      초기화는 current 를 default 로 되돌리는 것이며 과거 파일 이력은 남긴다
--   3) 자사 신규 양식은 전역 카탈로그(tbl_template)에도 co_cd 로 소유 회사를 남긴다
--      ux_tbl_template UNIQUE(tmpl_cd) 는 그대로 둔다 — 기존 JOIN 이 중복행 없이 유지된다
--   4) 재실행 안전 — ADD COLUMN IF NOT EXISTS · ON CONFLICT DO NOTHING · CREATE OR REPLACE
--
-- 선행: 83(form_path 3루트 재편) 적용 완료
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 전역 카탈로그 소유 회사 — 0000 = 플랫폼 공용, 그 외 = 자사 등록분
--    신규 서비스 개시 전까지는 전량 0000 이며, 자사 등록 양식만 회사코드가 박힌다
-- ------------------------------------------------------------
ALTER TABLE tbl_template ADD COLUMN IF NOT EXISTS co_cd varchar(10) NOT NULL DEFAULT '0000';
COMMENT ON COLUMN tbl_template.co_cd IS
  '카탈로그 소유 회사 — 0000이면(= 플랫폼 공용) 전 업체 배포 대상, 그 외는 해당 업체가 직접 등록한 자사 양식';

-- ------------------------------------------------------------
-- 2. tbl_company_template_file — 양식 파일 이력
--    업로드마다 1행이 쌓이고, 삭제는 물리 삭제 대신 del_yn 논리 삭제다 (감사 추적 보존)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_company_template_file (
    idx       bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd     varchar(10)  NOT NULL,
    tmpl_cd   varchar(40)  NOT NULL,
    file_seq  int          NOT NULL,
    file_nm   varchar(300) NOT NULL,
    form_path varchar(300) NOT NULL,
    file_size bigint       NULL,
    src_ty    varchar(10)  NOT NULL DEFAULT 'usr',
    del_yn    varchar(1)   NOT NULL DEFAULT 'N',
    ins_id    varchar(20)  NULL,
    ins_dt    timestamp    NULL DEFAULT now(),
    CONSTRAINT ux_tbl_company_template_file UNIQUE (co_cd, tmpl_cd, file_seq)
);
COMMENT ON TABLE  tbl_company_template_file           IS '양식 파일 이력 — 업로드·기본제공 파일 1행씩. 불러오기(과거 버전 적용)·초기화의 원천';
COMMENT ON COLUMN tbl_company_template_file.idx       IS 'PK 자동 채번 대리키 — default_file_idx/current_file_idx가 이 값을 가리킨다';
COMMENT ON COLUMN tbl_company_template_file.co_cd     IS '회사코드 — 테넌트 키. 다른 회사 파일이 섞이지 않는다';
COMMENT ON COLUMN tbl_company_template_file.tmpl_cd   IS '양식코드 — tbl_company_template.tmpl_cd';
COMMENT ON COLUMN tbl_company_template_file.file_seq  IS '버전 순번 — 업로드 순서. 물리 파일명 접미(_v{seq})와 같다';
COMMENT ON COLUMN tbl_company_template_file.file_nm   IS '표시 파일명 — 업로드 원본명(번호 접두 제거)';
COMMENT ON COLUMN tbl_company_template_file.form_path IS 'APP_FILE_ROOT 기준 상대 경로 — 표준은 HaccpTemplates/{tmpl_cd}/, 자사는 CustomTemplates/{co_cd}/{tmpl_cd}/';
COMMENT ON COLUMN tbl_company_template_file.file_size IS '바이트 크기 — 표시·검증용. 기본제공 시딩분은 NULL';
COMMENT ON COLUMN tbl_company_template_file.src_ty    IS '출처 — sys:프로그램 기본 제공본, usr:회사 업로드본';
COMMENT ON COLUMN tbl_company_template_file.del_yn    IS '삭제여부 Y/N — Y일 때(= 양식 삭제됨) 불러오기 목록에서 제외하고 파일은 남긴다';
COMMENT ON COLUMN tbl_company_template_file.ins_id    IS '업로드자 ID';
COMMENT ON COLUMN tbl_company_template_file.ins_dt    IS '업로드 일시 — 불러오기 목록 표시 기준';

CREATE INDEX IF NOT EXISTS ix_tbl_company_template_file_01
    ON tbl_company_template_file (co_cd, tmpl_cd, del_yn, file_seq DESC);

-- ------------------------------------------------------------
-- 3. 기본 파일 / 현재 파일 포인터
--    form_path 는 계속 "현재 적용 파일"의 실효 경로로 유지한다 (기존 소비 SP 무영향)
-- ------------------------------------------------------------
ALTER TABLE tbl_company_template ADD COLUMN IF NOT EXISTS default_file_idx bigint NULL;
ALTER TABLE tbl_company_template ADD COLUMN IF NOT EXISTS current_file_idx bigint NULL;
COMMENT ON COLUMN tbl_company_template.default_file_idx IS
  '기본 제공 파일 idx — 시스템 양식은 표준 원본, 자사양식은 최초 등록본. 초기화 대상. NULL이면 초기화 불가';
COMMENT ON COLUMN tbl_company_template.current_file_idx IS
  '현재 적용 파일 idx — 업로드·불러오기로만 바뀐다. form_path 와 항상 같은 파일을 가리킨다';

-- ------------------------------------------------------------
-- 4. 기존 파일을 이력 1행씩으로 시딩
--    seq 1 = 표준 원본(sys), seq 2 = 자사 업로드본(usr) — 고정 순번이라 재실행해도 늘지 않는다
-- ------------------------------------------------------------
INSERT INTO tbl_company_template_file(co_cd, tmpl_cd, file_seq, file_nm, form_path, src_ty, ins_id)
SELECT ct.co_cd, ct.tmpl_cd, 1, regexp_replace(t.form_path, '^.*/', ''), t.form_path, 'sys', 'system'
  FROM tbl_company_template ct
  JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
 WHERE COALESCE(t.form_path, '') <> ''
ON CONFLICT (co_cd, tmpl_cd, file_seq) DO NOTHING;

INSERT INTO tbl_company_template_file(co_cd, tmpl_cd, file_seq, file_nm, form_path, src_ty, ins_id)
SELECT ct.co_cd, ct.tmpl_cd, 2, regexp_replace(ct.form_path, '^.*/', ''), ct.form_path, 'usr', 'system'
  FROM tbl_company_template ct
  LEFT JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
 WHERE COALESCE(ct.form_path, '') <> ''
   AND ct.form_path <> COALESCE(t.form_path, '')
ON CONFLICT (co_cd, tmpl_cd, file_seq) DO NOTHING;

-- 기본 파일 — 표준 원본이 있으면 그것, 없으면(= 자사양식) 가장 오래된 업로드본
UPDATE tbl_company_template ct
   SET default_file_idx = f.idx
  FROM tbl_company_template_file f
 WHERE f.co_cd = ct.co_cd AND f.tmpl_cd = ct.tmpl_cd AND f.src_ty = 'sys'
   AND ct.default_file_idx IS NULL;

UPDATE tbl_company_template ct
   SET default_file_idx = f.idx
  FROM (
        SELECT DISTINCT ON (co_cd, tmpl_cd) co_cd, tmpl_cd, idx
          FROM tbl_company_template_file
         WHERE del_yn = 'N'
         ORDER BY co_cd, tmpl_cd, file_seq
       ) f
 WHERE f.co_cd = ct.co_cd AND f.tmpl_cd = ct.tmpl_cd
   AND ct.default_file_idx IS NULL;

-- 현재 파일 — 가장 최근 버전
UPDATE tbl_company_template ct
   SET current_file_idx = f.idx
  FROM (
        SELECT DISTINCT ON (co_cd, tmpl_cd) co_cd, tmpl_cd, idx
          FROM tbl_company_template_file
         WHERE del_yn = 'N'
         ORDER BY co_cd, tmpl_cd, file_seq DESC
       ) f
 WHERE f.co_cd = ct.co_cd AND f.tmpl_cd = ct.tmpl_cd
   AND ct.current_file_idx IS NULL;

-- ------------------------------------------------------------
-- 5. sys_yn 값 도메인 정합 — 51 이후 정본은 sys/usr 인데 45 SP 는 'Y' 로 비교해
--    시스템 양식이 SP 단계에서 통과되던 문제를 끝낸다. 문구도 사용자 안내문으로 통일
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_company_template_d_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd   varchar,
    -- p_tmpl_cd: 삭제 대상 양식코드
    p_tmpl_cd varchar,
    -- p_id: JWT 작업자 ID — 이력 논리삭제 감사용
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 출처 — sys(시스템 제공) / usr(자사 등록). 레거시 Y/N 도 함께 본다
    v_sys varchar(10);
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_tmpl_cd, '') = '' THEN
        RAISE EXCEPTION '삭제할 양식을 선택하세요.' USING ERRCODE = '45000';
    END IF;

    SELECT sys_yn INTO v_sys
      FROM tbl_company_template
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    IF NOT FOUND THEN
        RAISE EXCEPTION '삭제할 양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 자사양식(usr·N)만 삭제 가능 — 그 외는 전부 시스템 제공분으로 본다(값이 비어도 차단)
    IF lower(COALESCE(v_sys, 'sys')) NOT IN ('usr', 'n') THEN
        RAISE EXCEPTION '시스템에서 제공하는 양식은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 파일 이력은 논리 삭제 — 물리 파일과 감사 추적을 남긴다
    UPDATE tbl_company_template_file
       SET del_yn = 'Y'
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND del_yn = 'N';

    DELETE FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;

    -- 이 회사가 직접 만든 카탈로그 행이면 함께 정리한다 — 공용(0000) 카탈로그는 건드리지 않는다
    DELETE FROM tbl_template
     WHERE tmpl_cd = p_tmpl_cd
       AND co_cd = p_co_cd
       AND NOT EXISTS (SELECT 1 FROM tbl_document d WHERE d.tmpl_cd = p_tmpl_cd);
END$$;
COMMENT ON PROCEDURE sp_tbl_company_template_d_000(varchar, varchar, varchar) IS
  '사용양식 삭제 — 자사양식(usr)만 허용, 시스템 제공분은 차단. 파일 이력은 논리삭제하고 자사 카탈로그 행은 함께 정리';

-- ------------------------------------------------------------
-- 6. sp_hwp_template_management_r_000 — 사용양식 목록 (좌측 30% 그리드)
--    구분·양식파일·사용유무 + 버튼 활성 판정에 필요한 기본/현재/이력건수까지 한 번에 내린다
--    사용양식관리는 파일 관리 화면이므로 hwp 양식만, 미사용(use_yn=N)도 포함한다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_hwp_template_management_r_000(varchar, varchar, varchar);
CREATE FUNCTION sp_hwp_template_management_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_tmpl_cd: 헤더 양식코드 검색어. 공백이면 전체
    p_tmpl_cd varchar,
    -- p_tmpl_nm: 헤더 양식명 검색어. 공백이면 전체
    p_tmpl_nm varchar
)
RETURNS TABLE(
    tmpl_cd          varchar,
    tmpl_nm          varchar,
    -- 구분 — sys:시스템, usr:자사양식. 화면은 표시 전용이며 저장·수정 대상이 아니다
    sys_yn           varchar,
    doc_kind         varchar,
    category_cd      varchar,
    mng_no           varchar,
    -- 현재 적용 파일의 상대 경로 — 자사 업로드본이 있으면 그것, 없으면 표준 원본
    form_path        varchar,
    -- 현재 적용 파일명 — 그리드 양식파일 컬럼
    form_file_nm     varchar,
    use_yn           varchar,
    default_file_idx bigint,
    current_file_idx bigint,
    -- 살아있는 파일 이력 건수 — 불러오기 버튼 활성 판정
    file_hist_cnt    int
) LANGUAGE sql STABLE AS $$
    SELECT ct.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           lower(CASE WHEN COALESCE(ct.sys_yn, 'sys') IN ('N', 'n', 'usr') THEN 'usr' ELSE 'sys' END),
           t.doc_kind,
           t.category_cd,
           t.mng_no,
           COALESCE(NULLIF(ct.form_path, ''), t.form_path),
           CASE
             WHEN COALESCE(NULLIF(ct.form_path, ''), t.form_path) IS NULL THEN NULL
             ELSE regexp_replace(COALESCE(NULLIF(ct.form_path, ''), t.form_path), '^.*/', '')
           END,
           ct.use_yn,
           ct.default_file_idx,
           ct.current_file_idx,
           (SELECT COUNT(*)::int
              FROM tbl_company_template_file f
             WHERE f.co_cd = ct.co_cd AND f.tmpl_cd = ct.tmpl_cd AND f.del_yn = 'N')
      FROM tbl_company_template ct
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
     WHERE ct.co_cd = p_co_cd
       -- 파일로 관리하는 양식만 — html 전용 화면 양식은 이 화면 대상이 아니다
       AND t.doc_kind = 'hwp'
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_hwp_template_management_r_000(varchar, varchar, varchar) IS
  '사용양식 목록 — hwp 양식만, 구분(sys/usr)·현재 파일명·사용유무·기본/현재 파일·이력건수. 미사용 양식도 포함';

-- ------------------------------------------------------------
-- 7. sp_hwp_template_management_c_000 — 사용양식 저장
--    신규는 무조건 자사양식(usr)이다. 화면이 sysYn 을 보내도 무시한다
--    수정은 양식명·사용유무만 — 양식코드·구분은 바꿀 수 없다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_hwp_template_management_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 양식코드 — 신규는 사용자 입력, 수정은 조회키
    p_tmpl_cd varchar,
    -- p_tmpl_nm: 양식명
    p_tmpl_nm varchar,
    -- p_use_yn: 사용여부 Y/N. 공백이면 기존값 유지(신규는 Y)
    p_use_yn  varchar,
    -- p_id: JWT 작업자 ID — 감사 컬럼
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 카탈로그 소유 회사 — 0000이면 공용, 값이 없으면 카탈로그 미등록
    v_owner varchar(10);
BEGIN
    IF COALESCE(trim(p_tmpl_cd), '') = '' THEN
        RAISE EXCEPTION '양식코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(trim(p_tmpl_nm), '') = '' THEN
        RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    -- 이미 등록된 사용양식일 때(= 수정) 양식명·사용유무만 바꾼다. sys_yn 은 UPDATE 대상이 아니다
    IF EXISTS (SELECT 1 FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd) THEN
        UPDATE tbl_company_template
           SET tmpl_nm_ovr = p_tmpl_nm,
               use_yn      = COALESCE(NULLIF(p_use_yn, ''), use_yn),
               upd_id      = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
        RETURN;
    END IF;

    SELECT co_cd INTO v_owner FROM tbl_template WHERE tmpl_cd = p_tmpl_cd;
    IF NOT FOUND THEN
        -- 카탈로그에 없는 새 코드 — 이 회사 소유 자사 양식으로 카탈로그를 만든다
        INSERT INTO tbl_template(co_cd, tmpl_cd, tmpl_nm, doc_kind, use_yn, impl_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_tmpl_cd, p_tmpl_nm, 'hwp', 'Y', 'Y', p_id, now());
    ELSIF v_owner <> '0000' AND v_owner <> p_co_cd THEN
        -- 다른 회사가 쓰는 코드 — 전역 유일 제약이라 재사용할 수 없다
        RAISE EXCEPTION '이미 사용 중인 양식코드입니다: %', p_tmpl_cd USING ERRCODE = '45000';
    END IF;

    -- 사용자가 화면에서 만드는 양식은 항상 자사양식(usr)
    INSERT INTO tbl_company_template(co_cd, tmpl_cd, tmpl_nm_ovr, use_yn, sys_yn, ins_id, ins_dt)
    VALUES (p_co_cd, p_tmpl_cd, p_tmpl_nm, COALESCE(NULLIF(p_use_yn, ''), 'Y'), 'usr', p_id, now());
END$$;
COMMENT ON PROCEDURE sp_hwp_template_management_c_000(varchar, varchar, varchar, varchar, varchar) IS
  '사용양식 저장 — 신규는 sys_yn=usr 강제 + 자사 카탈로그 생성, 수정은 양식명·사용유무만(구분·코드 불변)';

-- ------------------------------------------------------------
-- 8. sp_hwp_template_management_file_r_000 — 양식 파일 이력 (불러오기 목록)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_hwp_template_management_file_r_000(varchar, varchar);
CREATE FUNCTION sp_hwp_template_management_file_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 선택한 양식코드
    p_tmpl_cd varchar
)
RETURNS TABLE(
    idx        bigint,
    file_seq   int,
    file_nm    varchar,
    file_size  bigint,
    -- 출처 — sys:기본 제공본, usr:회사 업로드본
    src_ty     varchar,
    -- 현재 적용 여부 Y/N — 목록에서 지금 쓰는 파일을 표시한다
    current_yn varchar,
    -- 기본 제공 여부 Y/N — 초기화가 되돌릴 대상
    default_yn varchar,
    ins_id     varchar,
    ins_dt     timestamp
) LANGUAGE sql STABLE AS $$
    SELECT f.idx, f.file_seq, f.file_nm, f.file_size, f.src_ty,
           CASE WHEN f.idx = ct.current_file_idx THEN 'Y' ELSE 'N' END,
           CASE WHEN f.idx = ct.default_file_idx THEN 'Y' ELSE 'N' END,
           f.ins_id, f.ins_dt
      FROM tbl_company_template_file f
      JOIN tbl_company_template ct ON ct.co_cd = f.co_cd AND ct.tmpl_cd = f.tmpl_cd
     WHERE f.co_cd = p_co_cd AND f.tmpl_cd = p_tmpl_cd AND f.del_yn = 'N'
     ORDER BY f.file_seq DESC;
$$;
COMMENT ON FUNCTION sp_hwp_template_management_file_r_000(varchar, varchar) IS
  '양식 파일 이력 — 최근 업로드 우선, 현재 적용·기본 제공 표시 포함';

-- ------------------------------------------------------------
-- 9. sp_hwp_template_management_file_c_000 — 업로드 파일 이력 등록
--    새 버전을 append 하고 현재 적용 파일로 만든다. 기본 파일이 없으면(= 자사양식 최초 등록) 기본으로도 지정한다
--    시스템 양식의 기본(표준 원본)은 절대 덮어쓰지 않는다 — 초기화가 항상 동작해야 한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_hwp_template_management_file_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd    varchar,
    -- p_tmpl_cd: 대상 양식코드
    p_tmpl_cd  varchar,
    -- p_file_nm: 표시 파일명 — 업로드 원본명
    p_file_nm  varchar,
    -- p_form_path: 저장된 상대 경로 — CustomTemplates/{co_cd}/{tmpl_cd}/{파일명}
    p_form_path varchar,
    -- p_file_size: 바이트 크기. 모르면 NULL
    p_file_size bigint,
    -- p_id: JWT 작업자 ID
    p_id       varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 다음 버전 순번
    v_seq int;
    -- 방금 만든 이력 idx
    v_idx bigint;
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_tmpl_cd, '') = '' OR COALESCE(p_form_path, '') = '' THEN
        RAISE EXCEPTION '양식 파일 정보가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd) THEN
        RAISE EXCEPTION '사용양식을 먼저 등록하세요.' USING ERRCODE = '45000';
    END IF;

    SELECT COALESCE(MAX(file_seq), 0) + 1 INTO v_seq
      FROM tbl_company_template_file WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;

    INSERT INTO tbl_company_template_file(co_cd, tmpl_cd, file_seq, file_nm, form_path, file_size, src_ty, ins_id)
    VALUES (p_co_cd, p_tmpl_cd, v_seq,
            COALESCE(NULLIF(p_file_nm, ''), regexp_replace(p_form_path, '^.*/', '')),
            p_form_path, p_file_size, 'usr', p_id)
    RETURNING idx INTO v_idx;

    UPDATE tbl_company_template
       SET form_path        = p_form_path,
           current_file_idx = v_idx,
           -- 기본 파일이 없을 때(= 자사양식 최초 업로드)만 기본으로 지정한다
           default_file_idx = COALESCE(default_file_idx, v_idx),
           upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;
COMMENT ON PROCEDURE sp_hwp_template_management_file_c_000(varchar, varchar, varchar, varchar, bigint, varchar) IS
  '양식 파일 업로드 — 이력 append + 현재 적용 갱신. 기본 파일은 없을 때만 채운다(시스템 원본 보존)';

-- ------------------------------------------------------------
-- 10. sp_hwp_template_management_current_u_000 — 불러오기 / 초기화
--     p_file_idx 지정 = 그 이력 버전을 현재 적용 / NULL = 기본 제공본으로 복원(초기화)
--     기본이 표준 원본(sys)이면 form_path 를 비워 tbl_template.form_path 를 다시 따르게 한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_hwp_template_management_current_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd    varchar,
    -- p_tmpl_cd: 대상 양식코드
    p_tmpl_cd  varchar,
    -- p_file_idx: 적용할 이력 idx. NULL이면(= 초기화) default_file_idx 를 쓴다
    p_file_idx bigint,
    -- p_id: JWT 작업자 ID
    p_id       varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 적용 대상 이력 idx
    v_idx  bigint;
    -- 적용 대상 경로
    v_path varchar(300);
    -- 적용 대상 출처 — sys면 표준 원본이라 자사 경로를 비운다
    v_src  varchar(10);
BEGIN
    v_idx := p_file_idx;
    IF v_idx IS NULL THEN
        SELECT default_file_idx INTO v_idx
          FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
        IF v_idx IS NULL THEN
            RAISE EXCEPTION '초기화할 기본 양식이 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;

    SELECT form_path, src_ty INTO v_path, v_src
      FROM tbl_company_template_file
     WHERE idx = v_idx AND co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND del_yn = 'N';
    IF NOT FOUND THEN
        RAISE EXCEPTION '적용할 양식 파일을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    UPDATE tbl_company_template
       SET form_path        = CASE WHEN v_src = 'sys' THEN NULL ELSE v_path END,
           current_file_idx = v_idx,
           upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    IF NOT FOUND THEN
        RAISE EXCEPTION '사용양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END$$;
COMMENT ON PROCEDURE sp_hwp_template_management_current_u_000(varchar, varchar, bigint, varchar) IS
  '양식 파일 불러오기·초기화 — 이력 버전 적용 또는 기본 제공본 복원. 과거 이력은 지우지 않는다';
