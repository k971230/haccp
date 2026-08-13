-- ============================================================
-- 83 — doc_kind 소문자 정본 정합 · 파일 볼륨 3루트 재편 (tmpl_cd 기준)
--
-- 파일번호: 83
-- 이전번호: 82
-- 개발자: 박승우
-- 일자: 2026-08-13
-- 코멘트:
--   1) 51에서 데이터만 html/hwp 로 바꿨고 SP·앱은 대문자(DB/HWP)로 비교하던 불일치를 끝낸다
--      (양식 파일 관리 화면 빈 목록 · 범용 CCP 저장 실패 · HWP 문서 저장 실패의 공통 원인)
--   2) form_path 를 표준 HaccpTemplates/{tmpl_cd}/{파일명} · 자사 CustomTemplates/{co_cd}/{tmpl_cd}/{파일명} 로 옮긴다
--      회사명은 경로에 넣지 않는다 — 상호가 바뀌면 경로가 깨진다
--   3) 재실행 안전 — 전부 CREATE OR REPLACE · 조건부 UPDATE. 09·37·46 의 이전 규칙을 이 파일이 최종 덮어쓴다
--
-- 선행: 51(doc_kind 치환) · 78(서명 bytea SP) 적용 완료
-- 물리 파일: 기존 볼륨에 파일이 있으면 아래 1줄로 한 번만 옮긴다 (컨테이너 안에서)
--   cd /var/haccp/files && mkdir -p HaccpTemplates && mv _template/* HaccpTemplates/ 2>/dev/null || true
--   이후 HaccpTemplates 안에서 파일을 {tmpl_cd}/ 하위로 옮긴다 (양식 파일 관리 화면 재업로드로도 된다)
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. doc_kind 정본 = 소문자 html/hwp — 잔존 대문자 값 치환
--    html = 전용 화면 + DB 저장 / hwp = rhwp 문서작성형
-- ------------------------------------------------------------
UPDATE tbl_template SET doc_kind = 'html' WHERE doc_kind IN ('DB', 'db');
UPDATE tbl_template SET doc_kind = 'hwp'  WHERE doc_kind IN ('HWP', 'HWPX', 'hwpx');
UPDATE tbl_document SET doc_kind = 'html' WHERE doc_kind IN ('DB', 'db');
UPDATE tbl_document SET doc_kind = 'hwp'  WHERE doc_kind IN ('HWP', 'HWPX', 'hwpx');

-- 내보내기 이력은 doc_kind 를 정확히 일치 비교한다 — 소문자로 맞추지 않으면 불러오기 팝업이 빈다
UPDATE tbl_template_export_hist SET doc_kind = 'html' WHERE doc_kind IN ('DB', 'db');
UPDATE tbl_template_export_hist SET doc_kind = 'hwp'  WHERE doc_kind IN ('HWP', 'HWPX', 'hwpx');

-- 스마트다이어리 회사양식(있을 때만) — 표준값을 복사해 두는 테이블이라 같이 맞춘다
DO $$
BEGIN
    IF to_regclass('sasshaccp.tbl_company_form') IS NOT NULL THEN
        EXECUTE $sql$UPDATE tbl_company_form SET doc_kind = 'html' WHERE doc_kind IN ('DB', 'db')$sql$;
        EXECUTE $sql$UPDATE tbl_company_form SET doc_kind = 'hwp'  WHERE doc_kind IN ('HWP', 'HWPX', 'hwpx')$sql$;
    END IF;
END$$;

-- ------------------------------------------------------------
-- 2. doc_kind 정규화 트리거
--    ponytail: 14·19·20·39 의 일지 저장 SP 본문에는 아직 'DB' 리터럴이 남아 있다.
--    함수 5개(각 100줄 이상)를 복사해 재정의하는 대신 쓰기 시점에 한 번 정규화한다.
--    ceiling: SP 리터럴을 소문자로 정리하면 이 트리거는 안전망만 남는다(제거해도 동작 동일).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_doc_kind_norm_biu_000()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    -- doc_kind 가 NULL일 때(= 호출부 누락) 값을 만들지 않고 NOT NULL 제약이 그대로 알리게 둔다
    IF NEW.doc_kind IS NULL THEN
        RETURN NEW;
    END IF;
    NEW.doc_kind := CASE lower(NEW.doc_kind)
                        WHEN 'db'   THEN 'html'
                        WHEN 'hwpx' THEN 'hwp'
                        ELSE lower(NEW.doc_kind)
                    END;
    RETURN NEW;
END$$;
COMMENT ON FUNCTION sp_tbl_doc_kind_norm_biu_000() IS 'doc_kind 를 정본 소문자(html/hwp)로 정규화 — 레거시 대문자 리터럴 SP 안전망';

DROP TRIGGER IF EXISTS trg_tbl_template_doc_kind_norm ON tbl_template;
CREATE TRIGGER trg_tbl_template_doc_kind_norm
    BEFORE INSERT OR UPDATE OF doc_kind ON tbl_template
    FOR EACH ROW EXECUTE FUNCTION sp_tbl_doc_kind_norm_biu_000();

DROP TRIGGER IF EXISTS trg_tbl_document_doc_kind_norm ON tbl_document;
CREATE TRIGGER trg_tbl_document_doc_kind_norm
    BEFORE INSERT OR UPDATE OF doc_kind ON tbl_document
    FOR EACH ROW EXECUTE FUNCTION sp_tbl_doc_kind_norm_biu_000();

-- ------------------------------------------------------------
-- 3. 비교값이 대문자로 남은 SP 3건 재정의
--    3-1. sp_tbl_document_d_000 (15 정본) — HWP 문서 삭제 가드
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_document_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 삭제할 문서 idx
    p_doc_idx bigint,
    -- p_id: 작업자 로그인 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_status varchar(3);
    -- doc_kind 는 varchar(10) — html(4자)이 잘리지 않게 폭을 맞춘다
    v_kind varchar(10);
BEGIN
    SELECT status, doc_kind INTO v_status, v_kind
      FROM tbl_document
     WHERE idx = p_doc_idx
       AND co_cd = p_co_cd
       AND del_yn = 'N'
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- DB형(html)일 때(= 업무 헤더·상세가 연결됨) 전용 양식 삭제 SP로만 처리한다
    IF v_kind <> 'hwp' THEN
        RAISE EXCEPTION 'DB형 문서는 해당 양식 화면에서 삭제하세요.' USING ERRCODE = '45000';
    END IF;
    -- 임시·반려가 아닐 때(= 결재 흐름 또는 보존 대상) 삭제 차단
    IF v_status NOT IN ('WRK', 'RJT') THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_document_relation
     WHERE co_cd = p_co_cd
       AND (src_doc_idx = p_doc_idx OR tgt_doc_idx = p_doc_idx);
    DELETE FROM tbl_document_approval
     WHERE co_cd = p_co_cd
       AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document_version
     WHERE co_cd = p_co_cd
       AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document_file
     WHERE co_cd = p_co_cd
       AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document
     WHERE co_cd = p_co_cd
       AND idx = p_doc_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_document_d_000(varchar, bigint, varchar) IS '문서형 작성중·반려 문서 삭제 — 첨부·결재·버전·관계 일괄 제거';

-- ------------------------------------------------------------
--    3-2. sp_tbl_hwp_document_c_000 (15 정본) — HWP 문서 헤더 저장
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_hwp_document_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 기존 문서 idx. NULL/0이면 신규
    p_doc_idx bigint,
    -- p_tmpl_cd: HWP 표준 템플릿 코드
    p_tmpl_cd varchar,
    -- p_base_dt: 기준일 YYYYMMDD
    p_base_dt varchar,
    -- p_base_dt_to: 기간 문서 종료일 YYYYMMDD. 없으면 공백
    p_base_dt_to varchar,
    -- p_title: 사용자 제목. 공백이면 템플릿명+기준일 자동 생성
    p_title varchar,
    -- p_id: JWT 작성자 ID
    p_id varchar
)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_idx bigint;
    v_tmpl_nm varchar(200);
    -- doc_kind 는 varchar(10) — hwp/html 정본
    v_doc_kind varchar(10);
    v_use_yn varchar(1);
    v_appr_line_cd varchar(20);
    v_retention_month int;
    v_doc_no varchar(50);
BEGIN
    IF COALESCE(p_base_dt, '') !~ '^[0-9]{8}$' THEN
        RAISE EXCEPTION '기준일자는 YYYYMMDD 형식이어야 합니다.' USING ERRCODE = '45000';
    END IF;

    SELECT t.tmpl_nm,
           t.doc_kind,
           ct.use_yn,
           ct.appr_line_cd,
           COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_tmpl_nm, v_doc_kind, v_use_yn, v_appr_line_cd, v_retention_month
      FROM tbl_template t
      JOIN tbl_company_template ct
        ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd
     WHERE t.tmpl_cd = p_tmpl_cd
       AND t.impl_yn = 'Y'
       AND t.use_yn = 'Y';

    -- 양식이 없거나 hwp 형이 아니거나 회사 미사용일 때(= 이 화면 대상 아님) 업무 오류
    IF NOT FOUND OR v_doc_kind <> 'hwp' OR v_use_yn <> 'Y' THEN
        RAISE EXCEPTION '사용 가능한 문서형 양식이 아닙니다.' USING ERRCODE = '45000';
    END IF;

    IF COALESCE(p_doc_idx, 0) <= 0 THEN
        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd, p_tmpl_cd, p_base_dt);
        INSERT INTO tbl_document(
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, base_dt_to, title,
            status, appr_line_cd, writer_id, ver_no, retention_until, del_yn,
            ins_id, ins_dt
        )
        VALUES (
            p_co_cd, p_tmpl_cd, 'hwp', v_doc_no, p_base_dt, NULLIF(p_base_dt_to, ''),
            COALESCE(NULLIF(trim(p_title), ''), v_tmpl_nm || ' (' || to_char(to_date(p_base_dt, 'YYYYMMDD'), 'YYYY-MM-DD') || ')'),
            'WRK', v_appr_line_cd, p_id, 1,
            to_char(to_date(p_base_dt, 'YYYYMMDD') + make_interval(months => v_retention_month), 'YYYYMMDD'),
            'N', p_id, now()
        )
        RETURNING idx INTO v_idx;
    ELSE
        SELECT idx INTO v_idx
          FROM tbl_document
         WHERE idx = p_doc_idx
           AND co_cd = p_co_cd
           AND doc_kind = 'hwp'
           AND writer_id = p_id
           AND status IN ('WRK', 'RJT')
           AND del_yn = 'N'
         FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION '작성자 본인의 작성중 또는 반려 문서만 수정할 수 있습니다.' USING ERRCODE = '45000';
        END IF;

        UPDATE tbl_document
           SET base_dt = p_base_dt,
               base_dt_to = NULLIF(p_base_dt_to, ''),
               title = COALESCE(NULLIF(trim(p_title), ''), v_tmpl_nm || ' (' || to_char(to_date(p_base_dt, 'YYYYMMDD'), 'YYYY-MM-DD') || ')'),
               upd_id = p_id,
               upd_dt = now()
         WHERE idx = v_idx
           AND co_cd = p_co_cd;
    END IF;

    RETURN v_idx;
END$$;
COMMENT ON FUNCTION sp_tbl_hwp_document_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar) IS 'HWP 문서형 공통 헤더 신규·수정 — 문서번호·보존기간 자동 설정';

-- ------------------------------------------------------------
--    3-3. sp_tbl_ccp_generic_monitor_c_000 (78 정본) — 범용 CCP 저장.
--         양식 조회를 doc_kind='html' 로 바꾼다 (서명 bytea 스냅샷은 78과 동일)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_generic_monitor_c_000(
    p_co_cd varchar,
    p_doc_idx bigint,
    p_base_dt varchar,
    p_tmpl_cd varchar,
    p_ccp_cd varchar,
    p_diary_no varchar,
    p_limit_item_kind varchar,
    p_mng_user_id varchar,
    p_mng_nm varchar,
    p_rows jsonb,
    p_id varchar
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_doc_idx bigint;
    v_monitor_idx bigint;
    v_doc_no varchar;
    v_title varchar(300);
    v_row jsonb;
    v_cell jsonb;
    v_row_idx bigint;
BEGIN
    IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) = 0 THEN
        RAISE EXCEPTION '점검 행이 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 양식 유형 정본은 소문자 html — 51 이후 'DB' 비교는 항상 0건이었다
    SELECT coalesce(nullif(t.tmpl_nm, ''), '공통 CCP 모니터링') INTO v_title
      FROM tbl_template t WHERE t.tmpl_cd = p_tmpl_cd AND t.doc_kind = 'html' AND t.use_yn = 'Y';
    IF v_title IS NULL THEN
        RAISE EXCEPTION '사용할 공통 CCP 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000';
    END IF;

    IF coalesce(p_doc_idx, 0) <= 0 THEN
        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd, p_tmpl_cd, p_base_dt);
        INSERT INTO tbl_document (
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status, writer_id, form_src, ins_id
        ) VALUES (
            p_co_cd, p_tmpl_cd, 'html', v_doc_no, p_base_dt, v_title, 'WRK', p_id, 'BASE', p_id
        ) RETURNING idx INTO v_doc_idx;
        INSERT INTO tbl_ccp_generic_monitor (
            co_cd, doc_idx, base_dt, tmpl_cd, ccp_cd, diary_no, limit_item_kind, mng_user_id, mng_nm, ins_id
        ) VALUES (
            p_co_cd, v_doc_idx, p_base_dt, p_tmpl_cd, nullif(p_ccp_cd, ''), nullif(p_diary_no, ''),
            nullif(p_limit_item_kind, ''), nullif(p_mng_user_id, ''), nullif(p_mng_nm, ''), p_id
        ) RETURNING idx INTO v_monitor_idx;
    ELSE
        SELECT m.idx INTO v_monitor_idx
          FROM tbl_ccp_generic_monitor m
          JOIN tbl_document d ON d.idx = m.doc_idx
         WHERE m.co_cd = p_co_cd AND m.doc_idx = p_doc_idx AND d.del_yn = 'N' AND d.status IN ('WRK', 'RJT');
        IF v_monitor_idx IS NULL THEN
            RAISE EXCEPTION '수정할 임시 또는 반려 문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_doc_idx := p_doc_idx;
        UPDATE tbl_document SET base_dt = p_base_dt, title = v_title, upd_id = p_id, upd_dt = now()
         WHERE idx = v_doc_idx AND co_cd = p_co_cd;
        UPDATE tbl_ccp_generic_monitor
           SET base_dt = p_base_dt, tmpl_cd = p_tmpl_cd, ccp_cd = nullif(p_ccp_cd, ''),
               diary_no = nullif(p_diary_no, ''), limit_item_kind = nullif(p_limit_item_kind, ''),
               mng_user_id = nullif(p_mng_user_id, ''), mng_nm = nullif(p_mng_nm, ''), upd_id = p_id, upd_dt = now()
         WHERE idx = v_monitor_idx AND co_cd = p_co_cd;
        DELETE FROM tbl_ccp_generic_monitor_cell c
         USING tbl_ccp_generic_monitor_row r
         WHERE c.row_idx = r.idx AND r.monitor_idx = v_monitor_idx AND r.co_cd = p_co_cd;
        DELETE FROM tbl_ccp_generic_monitor_row WHERE monitor_idx = v_monitor_idx AND co_cd = p_co_cd;
    END IF;

    FOR v_row IN SELECT value FROM jsonb_array_elements(p_rows)
    LOOP
        INSERT INTO tbl_ccp_generic_monitor_row (
            co_cd, monitor_idx, row_seq, check_time, equip_nm, product_nm,
            judge_cd, judge_mod_yn, checker_id, checker_nm, sign_img, ins_id
        ) VALUES (
            p_co_cd, v_monitor_idx, coalesce(nullif(v_row->>'rowSeq', '')::int, 0), nullif(v_row->>'checkTime', ''),
            nullif(v_row->>'equipNm', ''), nullif(v_row->>'productNm', ''),
            nullif(v_row->>'judgeCd', ''), coalesce(nullif(v_row->>'judgeModYn', ''), 'N'),
            nullif(v_row->>'checkerId', ''), nullif(v_row->>'checkerNm', ''),
            -- 서명은 signYn만 받고 검사자 서명 원본을 그 시점 값으로 복사한다
            CASE WHEN COALESCE(v_row->>'signYn', 'N') = 'Y'
                 THEN (SELECT u.sign_img FROM tbl_user u
                        WHERE u.co_cd = p_co_cd
                          AND u.user_id = nullif(v_row->>'checkerId', ''))
                 ELSE NULL END, p_id
        ) RETURNING idx INTO v_row_idx;
        FOR v_cell IN SELECT value FROM jsonb_array_elements(coalesce(v_row->'cells', '[]'::jsonb))
        LOOP
            INSERT INTO tbl_ccp_generic_monitor_cell (
                co_cd, row_idx, item_cd, num_val, txt_val, judge_cd, ins_id
            ) VALUES (
                p_co_cd, v_row_idx, v_cell->>'itemCd', nullif(v_cell->>'numVal', '')::numeric,
                nullif(v_cell->>'txtVal', ''), nullif(v_cell->>'judgeCd', ''), p_id
            );
        END LOOP;
    END LOOP;
    RETURN v_doc_idx;
END;
$$;

-- ------------------------------------------------------------
-- 4. form_path 3루트 재편 — 파일명은 그대로 두고 앞 경로만 바꾼다
--    표준: HaccpTemplates/{tmpl_cd}/{파일명}
--    자사: CustomTemplates/{co_cd}/{tmpl_cd}/{파일명}
--    작성 문서·첨부: HaccpLogBooks/{co_cd}/{일자}/{tmpl_cd}/... (신규 저장 시 앱이 조립)
-- ------------------------------------------------------------
UPDATE tbl_template
   SET form_path = 'HaccpTemplates/' || tmpl_cd || '/' || regexp_replace(form_path, '^.*/', ''),
       upd_id = 'system',
       upd_dt = now()
 WHERE doc_kind = 'hwp'
   AND COALESCE(form_path, '') <> ''
   -- 이미 새 규칙이면 건너뛴다 (재실행 안전) — LIKE 의 _ 와일드카드를 피해 완전 일치로 본다
   AND form_path <> 'HaccpTemplates/' || tmpl_cd || '/' || regexp_replace(form_path, '^.*/', '');

-- HTML 양식은 물리 원본이 없다 — 참조본 경로를 남기면 없는 파일을 내려받으려 한다
UPDATE tbl_template
   SET form_path = NULL,
       upd_id = 'system',
       upd_dt = now()
 WHERE doc_kind = 'html'
   AND form_path IS NOT NULL;

UPDATE tbl_company_template
   SET form_path = 'CustomTemplates/' || co_cd || '/' || tmpl_cd || '/' || regexp_replace(form_path, '^.*/', ''),
       upd_id = 'system',
       upd_dt = now()
 WHERE COALESCE(form_path, '') <> ''
   AND form_path <> 'CustomTemplates/' || co_cd || '/' || tmpl_cd || '/' || regexp_replace(form_path, '^.*/', '');

COMMENT ON COLUMN tbl_template.form_path IS
    '표준 원본 HWP 상대경로 — HaccpTemplates/{tmpl_cd}/{파일명}. html 양식은 물리 원본이 없어 NULL';
COMMENT ON COLUMN tbl_company_template.form_path IS
    '회사 전용 HWP 원본 상대경로 — CustomTemplates/{co_cd}/{tmpl_cd}/{파일명}. NULL이면 tbl_template.form_path';

-- ------------------------------------------------------------
-- 5. 확인 — 아래 3건이 모두 0이면 정합 완료
--   SELECT count(*) FROM tbl_template WHERE doc_kind NOT IN ('html','hwp');
--   SELECT count(*) FROM tbl_template WHERE doc_kind='hwp' AND COALESCE(form_path,'')<>''
--                                       AND form_path NOT LIKE 'HaccpTemplates/%';
--   SELECT count(*) FROM tbl_template WHERE doc_kind='html' AND form_path IS NOT NULL;
-- ------------------------------------------------------------
