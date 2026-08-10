-- ============================================================
-- 41 — DEMO 마스터·작성 샘플 (명세 전량)
--
-- 개발자: 박승우
-- 일자: 2026-08-07
-- 코멘트:
--   1) 방충설비·CCP한계·설비·건강진단·협력업체 플래그를 DEMO에 넣는다
--   2) 주요 DB/HWP 작성 문서는 당일 1건씩 메타+소수 행을 넣는다(HWP는 업로드 슬롯)
--   3) 회사는 첫 번째 활성 테넌트를 대상으로 한다
-- ============================================================

SET search_path TO sasshaccp;

DO $$
DECLARE
    v_co varchar(10);
    v_today varchar(8) := to_char(current_date, 'YYYYMMDD');
    -- 작성 샘플 문서 생성용
    v_doc bigint;
    v_hdr bigint;
    v_doc_no varchar(50);
    v_line varchar(20);
    v_stor varchar(30);
BEGIN
    SELECT co_cd INTO v_co FROM tbl_company WHERE use_yn = 'Y' ORDER BY co_cd LIMIT 1;
    IF v_co IS NULL THEN
        RAISE NOTICE 'DEMO 회사 없음 — 시드 생략';
        RETURN;
    END IF;

    -- 방충 설비
    INSERT INTO tbl_pest_device (co_cd, pest_cd, pest_nm, pest_type, place_nm, sort_no, use_yn, ins_id)
    VALUES
        (v_co, 'PL01', '포충등 1', 'LAMP', '원료입고실', 1, 'Y', 'system'),
        (v_co, 'PL02', '포충등 2', 'LAMP', '작업장A', 2, 'Y', 'system'),
        (v_co, 'TR01', '바퀴트랩 1', 'ROACH', '창고복도', 3, 'Y', 'system'),
        (v_co, 'RT01', '쥐트랩 1', 'RAT', '외부경계', 4, 'Y', 'system')
    ON CONFLICT (co_cd, pest_cd) DO UPDATE SET
        pest_nm = EXCLUDED.pest_nm, place_nm = EXCLUDED.place_nm, use_yn = 'Y', upd_id = 'system', upd_dt = now();

    -- CCP 한계 샘플 (가열·멸균·여과·금속)
    INSERT INTO tbl_ccp_limit (co_cd, ccp_cd, ccp_nm, proc_nm, limit_type, min_val, max_val, unit_nm, fe_size, sts_size, cycle_min, cycle_rmk, limit_rmk, method_rmk, improve_rmk, use_yn, ins_id)
    VALUES
        (v_co, 'CCP-HEAT', '가열공정', '가열', 'TEMP_MIN', 75, NULL, 'C', NULL, NULL, 60,
         '배치마다', '품온 75C 이상', '중심온도 측정', '재가열 후 재측정', 'Y', 'system'),
        (v_co, 'CCP-STER', '멸균공정', '멸균', 'TEMP_RANGE', 121, 125, 'C', NULL, NULL, 60,
         '배치마다', '121~125C', '멸균기 온도기록', '재멸균', 'Y', 'system'),
        (v_co, 'CCP-FILT', '여과공정', '여과', 'TEMP_MAX', NULL, NULL, NULL, NULL, NULL, 120,
         '작업전후', '필터 파손·이물 없음', '육안·압력 확인', '필터교체', 'Y', 'system'),
        (v_co, 'CCP-2P', '금속검출', '금속검출', 'METAL', NULL, NULL, 'mm', 1.5, 2.0, 60,
         '1시간마다', 'Fe 1.5 / STS 2.0 mm', '시험편 통과 확인', '라인정지·재검사', 'Y', 'system')
    ON CONFLICT (co_cd, ccp_cd) DO UPDATE SET
        ccp_nm = EXCLUDED.ccp_nm,
        improve_rmk = EXCLUDED.improve_rmk,
        use_yn = 'Y',
        upd_id = 'system',
        upd_dt = now();

    -- 설비 마스터
    INSERT INTO tbl_equipment (co_cd, equip_cd, equip_nm, equip_kind, purpose_nm, model_nm, install_dt, as_mng_nm, place_nm, use_yn, ins_id)
    VALUES
        (v_co, 'EQ01', '금속검출기', '검출기', '이물검출', 'MD-100', '20200115', '김AS', '포장실', 'Y', 'system'),
        (v_co, 'EQ02', '육절기', '절단기', '원료절단', 'CS-200', '20190601', '박AS', '작업장A', 'Y', 'system')
    ON CONFLICT (co_cd, equip_cd) DO UPDATE SET
        equip_nm = EXCLUDED.equip_nm, equip_kind = EXCLUDED.equip_kind, purpose_nm = EXCLUDED.purpose_nm,
        use_yn = 'Y', upd_id = 'system', upd_dt = now();

    -- 설비 이력 샘플 (설비당 2~3건)
    INSERT INTO tbl_equipment_hist (co_cd, equip_idx, hist_dt, fault_rmk, action_rmk, remark, ins_id)
    SELECT v_co, e.idx, s.hist_dt, s.fault_rmk, s.action_rmk, s.remark, 'system'
      FROM tbl_equipment e
      CROSS JOIN (VALUES
        (v_today, '벨트 소음', '베어링 교체', '당일 샘플'),
        (to_char(current_date - 7, 'YYYYMMDD'), '센서 이상', '센서 교체', '1주전 샘플'),
        (to_char(current_date - 30, 'YYYYMMDD'), '정기점검', '윤활·청소', '월간 샘플')
      ) AS s(hist_dt, fault_rmk, action_rmk, remark)
     WHERE e.co_cd = v_co AND e.equip_cd = 'EQ01'
       AND NOT EXISTS (
            SELECT 1 FROM tbl_equipment_hist h
             WHERE h.co_cd = v_co AND h.equip_idx = e.idx AND h.hist_dt = s.hist_dt
       );

    INSERT INTO tbl_equipment_hist (co_cd, equip_idx, hist_dt, fault_rmk, action_rmk, remark, ins_id)
    SELECT v_co, e.idx, s.hist_dt, s.fault_rmk, s.action_rmk, s.remark, 'system'
      FROM tbl_equipment e
      CROSS JOIN (VALUES
        (v_today, '칼날 마모', '칼날 교체', '당일 샘플'),
        (to_char(current_date - 14, 'YYYYMMDD'), '모터 과열', '냉각팬 청소', '2주전 샘플')
      ) AS s(hist_dt, fault_rmk, action_rmk, remark)
     WHERE e.co_cd = v_co AND e.equip_cd = 'EQ02'
       AND NOT EXISTS (
            SELECT 1 FROM tbl_equipment_hist h
             WHERE h.co_cd = v_co AND h.equip_idx = e.idx AND h.hist_dt = s.hist_dt
       );

    -- 건강진단 샘플
    INSERT INTO tbl_health_cert (co_cd, person_nm, exam_dt, expire_dt, remark, use_yn, ins_id)
    SELECT v_co, v.person_nm, v.exam_dt, v.expire_dt, v.remark, 'Y', 'system'
      FROM (VALUES
        ('홍길동', to_char(current_date - 30, 'YYYYMMDD'), to_char(current_date + 335, 'YYYYMMDD'), '샘플1'),
        ('김영희', to_char(current_date - 60, 'YYYYMMDD'), to_char(current_date + 305, 'YYYYMMDD'), '샘플2'),
        ('이철수', to_char(current_date - 10, 'YYYYMMDD'), to_char(current_date + 355, 'YYYYMMDD'), '샘플3')
      ) AS v(person_nm, exam_dt, expire_dt, remark)
     WHERE NOT EXISTS (
        SELECT 1 FROM tbl_health_cert h
         WHERE h.co_cd = v_co AND h.person_nm = v.person_nm AND h.exam_dt = v.exam_dt
     );

    -- 협력업체 리스트 플래그
    UPDATE tbl_partner
       SET coop_list_yn = 'Y', upd_id = 'system', upd_dt = now()
     WHERE co_cd = v_co
       AND partner_gbn IN ('SUPPLY', 'LAB')
       AND use_yn = 'Y';

    -- LIMIT_ITEM_KIND 멸균 코드
    INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, use_yn, ins_id)
    VALUES ('0000', 'LIMIT_ITEM_KIND', 'LMTITMST', '멸균', 5, 'Y', 'system')
    ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
        code_nm = EXCLUDED.code_nm, use_yn = 'Y', upd_id = 'system', upd_dt = now();

    -- ------------------------------------------------------------
    -- 주요 DB형 작성 샘플 (당일 1건) — 목록·상세 오픈용 메타+소수 행
    -- ------------------------------------------------------------
    -- 공통: 결재선 스냅샷 (없으면 NULL)
    SELECT appr_line_cd INTO v_line
      FROM tbl_company_template
     WHERE co_cd = v_co AND tmpl_cd = 'DAILY_HYG'
     LIMIT 1;

    -- DAILY_HYG
    IF NOT EXISTS (
        SELECT 1 FROM tbl_document
         WHERE co_cd = v_co AND tmpl_cd = 'DAILY_HYG' AND base_dt = v_today AND del_yn = 'N'
    ) THEN
        v_doc_no := sp_tbl_doc_no_gen_c_000(v_co, 'DAILY_HYG', v_today);
        INSERT INTO tbl_document(
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status,
            appr_line_cd, writer_id, write_dt, ver_no, del_yn, ins_id, ins_dt
        ) VALUES (
            v_co, 'DAILY_HYG', 'DB', v_doc_no, v_today,
            '일일 위생 점검일지(샘플)', 'WRK',
            v_line, 'admin', now(), 1, 'N', 'system', now()
        ) RETURNING idx INTO v_doc;

        INSERT INTO tbl_daily_hygiene(co_cd, doc_idx, base_dt, before_time, during_time, checker_id, checker_nm, ins_id)
        VALUES (v_co, v_doc, v_today, '0800', '1400', 'admin', '시스템관리자', 'system')
        RETURNING idx INTO v_hdr;

        INSERT INTO tbl_daily_hygiene_item(co_cd, hdr_idx, row_seq, grp_cd, item_cd, item_nm, judge_cd, remark, ins_id)
        VALUES
            (v_co, v_hdr, 1, 'BEFORE', 'B01', '종업원 위생복 착용', 'O', '샘플', 'system'),
            (v_co, v_hdr, 2, 'BEFORE', 'B02', '개인위생 준수', 'O', NULL, 'system'),
            (v_co, v_hdr, 3, 'DURING', 'D01', '작업 중 흡연·음식물 금지', 'O', NULL, 'system');
    END IF;

    -- PEST
    IF NOT EXISTS (
        SELECT 1 FROM tbl_document
         WHERE co_cd = v_co AND tmpl_cd = 'PEST' AND base_dt = v_today AND del_yn = 'N'
    ) THEN
        SELECT appr_line_cd INTO v_line FROM tbl_company_template
         WHERE co_cd = v_co AND tmpl_cd = 'PEST' LIMIT 1;
        v_doc_no := sp_tbl_doc_no_gen_c_000(v_co, 'PEST', v_today);
        INSERT INTO tbl_document(
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status,
            appr_line_cd, writer_id, write_dt, ver_no, del_yn, ins_id, ins_dt
        ) VALUES (
            v_co, 'PEST', 'DB', v_doc_no, v_today,
            '방충·방서 점검표(샘플)', 'WRK',
            v_line, 'admin', now(), 1, 'N', 'system', now()
        ) RETURNING idx INTO v_doc;

        INSERT INTO tbl_pest_check(co_cd, doc_idx, base_dt, checker_id, checker_nm, ins_id)
        VALUES (v_co, v_doc, v_today, 'admin', '시스템관리자', 'system')
        RETURNING idx INTO v_hdr;

        INSERT INTO tbl_pest_check_row(
            co_cd, hdr_idx, row_seq, pest_cd, pest_nm, place_nm, device_ng_cd,
            fly_yn, moth_yn, mosq_yn, midge_yn, etc_fly_yn,
            roach_yn, spider_yn, ant_yn, etc_walk_yn,
            rat_yn, etc_rat_yn, remark, ins_id
        )
        SELECT v_co, v_hdr, row_number() OVER (ORDER BY d.sort_no, d.pest_cd)::int,
               d.pest_cd, d.pest_nm, d.place_nm, 'O',
               'N', 'N', 'N', 'N', '/',
               CASE WHEN d.pest_type = 'ROACH' THEN 'N' ELSE '/' END,
               '/', '/', '/',
               CASE WHEN d.pest_type = 'RAT' THEN 'N' ELSE '/' END,
               '/',
               '샘플', 'system'
          FROM tbl_pest_device d
         WHERE d.co_cd = v_co AND d.use_yn = 'Y'
         ORDER BY d.sort_no, d.pest_cd
         LIMIT 4;
    END IF;

    -- CCP_COLD
    IF NOT EXISTS (
        SELECT 1 FROM tbl_document
         WHERE co_cd = v_co AND tmpl_cd = 'CCP_COLD' AND base_dt = v_today AND del_yn = 'N'
    ) THEN
        SELECT appr_line_cd INTO v_line FROM tbl_company_template
         WHERE co_cd = v_co AND tmpl_cd = 'CCP_COLD' LIMIT 1;
        SELECT storage_cd INTO v_stor FROM tbl_storage
         WHERE co_cd = v_co AND use_yn = 'Y' ORDER BY sort_no NULLS LAST, storage_cd LIMIT 1;
        v_doc_no := sp_tbl_doc_no_gen_c_000(v_co, 'CCP_COLD', v_today);
        INSERT INTO tbl_document(
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status,
            appr_line_cd, writer_id, write_dt, ver_no, del_yn, ins_id, ins_dt
        ) VALUES (
            v_co, 'CCP_COLD', 'DB', v_doc_no, v_today,
            '냉장·냉동 보관 모니터링(샘플)', 'WRK',
            v_line, 'admin', now(), 1, 'N', 'system', now()
        ) RETURNING idx INTO v_doc;

        INSERT INTO tbl_ccp_cold_monitor(co_cd, doc_idx, base_dt, ccp_cd, mng_user_id, mng_nm, ins_id)
        VALUES (v_co, v_doc, v_today, COALESCE(
            (SELECT ccp_cd FROM tbl_ccp_limit WHERE co_cd = v_co AND ccp_cd LIKE '%COLD%' LIMIT 1),
            (SELECT ccp_cd FROM tbl_ccp_limit WHERE co_cd = v_co ORDER BY ccp_cd LIMIT 1),
            'CCP-1B'
        ), 'admin', '시스템관리자', 'system')
        RETURNING idx INTO v_hdr;

        INSERT INTO tbl_ccp_cold_monitor_row(
            co_cd, hdr_idx, row_seq, check_time, judge_cd, judge_mod_yn,
            checker_id, checker_nm, writer_id, writer_nm, ins_id
        ) VALUES (
            v_co, v_hdr, 1, '0900', 'P', 'Y',
            'admin', '시스템관리자', 'admin', '시스템관리자', 'system'
        );

        IF v_stor IS NOT NULL THEN
            INSERT INTO tbl_ccp_cold_monitor_temp(co_cd, row_idx, storage_cd, temp_val, judge_cd, ins_id)
            SELECT v_co, r.idx, v_stor, 3.5, 'P', 'system'
              FROM tbl_ccp_cold_monitor_row r
             WHERE r.hdr_idx = v_hdr AND r.co_cd = v_co AND r.row_seq = 1;
        END IF;
    END IF;

    -- CCP_METAL
    IF NOT EXISTS (
        SELECT 1 FROM tbl_document
         WHERE co_cd = v_co AND tmpl_cd = 'CCP_METAL' AND base_dt = v_today AND del_yn = 'N'
    ) THEN
        SELECT appr_line_cd INTO v_line FROM tbl_company_template
         WHERE co_cd = v_co AND tmpl_cd = 'CCP_METAL' LIMIT 1;
        v_doc_no := sp_tbl_doc_no_gen_c_000(v_co, 'CCP_METAL', v_today);
        INSERT INTO tbl_document(
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status,
            appr_line_cd, writer_id, write_dt, ver_no, del_yn, ins_id, ins_dt
        ) VALUES (
            v_co, 'CCP_METAL', 'DB', v_doc_no, v_today,
            '금속검출 모니터링(샘플)', 'WRK',
            v_line, 'admin', now(), 1, 'N', 'system', now()
        ) RETURNING idx INTO v_doc;

        INSERT INTO tbl_ccp_metal_monitor(co_cd, doc_idx, base_dt, ccp_cd, fe_size, sts_size, mng_user_id, mng_nm, ins_id)
        VALUES (v_co, v_doc, v_today, 'CCP-2P', 1.5, 2.0, 'admin', '시스템관리자', 'system')
        RETURNING idx INTO v_hdr;

        INSERT INTO tbl_ccp_metal_sens_row(
            co_cd, hdr_idx, row_seq, phase_cd, product_nm, check_time,
            fe_only_cd, sts_only_cd, prod_only_cd, fe_prod_cd, sts_prod_cd,
            judge_cd, place_nm, ins_id
        ) VALUES (
            v_co, v_hdr, 1, 'START', '샘플제품', '1000',
            'O', 'O', 'O', 'O', 'O',
            'P', '포장라인1', 'system'
        );
    END IF;

    -- FACILITY
    IF NOT EXISTS (
        SELECT 1 FROM tbl_document
         WHERE co_cd = v_co AND tmpl_cd = 'FACILITY' AND base_dt = v_today AND del_yn = 'N'
    ) THEN
        SELECT appr_line_cd INTO v_line FROM tbl_company_template
         WHERE co_cd = v_co AND tmpl_cd = 'FACILITY' LIMIT 1;
        v_doc_no := sp_tbl_doc_no_gen_c_000(v_co, 'FACILITY', v_today);
        INSERT INTO tbl_document(
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status,
            appr_line_cd, writer_id, write_dt, ver_no, del_yn, ins_id, ins_dt
        ) VALUES (
            v_co, 'FACILITY', 'DB', v_doc_no, v_today,
            '시설·설비 점검표(샘플)', 'WRK',
            v_line, 'admin', now(), 1, 'N', 'system', now()
        ) RETURNING idx INTO v_doc;

        INSERT INTO tbl_facility_check(co_cd, doc_idx, base_dt, checker_id, checker_nm, ins_id)
        VALUES (v_co, v_doc, v_today, 'admin', '시스템관리자', 'system')
        RETURNING idx INTO v_hdr;

        INSERT INTO tbl_facility_check_item(
            co_cd, hdr_idx, row_seq, grp_nm, item_cd, item_nm, method_nm, cycle_nm,
            mng_nm, judge_cd, place_nm, action_rmk, ins_id
        ) VALUES (
            v_co, v_hdr, 1, '시설', 'F01', '바닥·배수 청결', '육안', '주1회',
            '시스템관리자', 'O', '작업장A', NULL, 'system'
        );
    END IF;

    -- HWP 메타 문서 슬롯 (원본은 화면에서 일자별 업로드)
    IF NOT EXISTS (
        SELECT 1 FROM tbl_document
         WHERE co_cd = v_co AND tmpl_cd = 'HANDOVER' AND base_dt = v_today AND del_yn = 'N'
    ) THEN
        SELECT appr_line_cd INTO v_line FROM tbl_company_template
         WHERE co_cd = v_co AND tmpl_cd = 'HANDOVER' LIMIT 1;
        v_doc_no := sp_tbl_doc_no_gen_c_000(v_co, 'HANDOVER', v_today);
        INSERT INTO tbl_document(
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status,
            appr_line_cd, writer_id, write_dt, ver_no, del_yn, ins_id, ins_dt
        ) VALUES (
            v_co, 'HANDOVER', 'HWP', v_doc_no, v_today,
            '업무 인수인계서(샘플·업로드슬롯)', 'WRK',
            v_line, 'admin', now(), 1, 'N', 'system', now()
        ) RETURNING idx INTO v_doc;

        INSERT INTO tbl_document_file(co_cd, doc_idx, file_kind, file_nm, file_path, file_size, mime_type, sort_no, ins_id)
        VALUES (
            v_co, v_doc, 'HWP_SRC', 'HANDOVER_DEMO.hwpx',
            '_template/DEMO_EMPTY.hwpx', 0, 'application/x-hwpx', 1, 'system'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM tbl_document
         WHERE co_cd = v_co AND tmpl_cd = 'EDU_LOG' AND base_dt = v_today AND del_yn = 'N'
    ) THEN
        SELECT appr_line_cd INTO v_line FROM tbl_company_template
         WHERE co_cd = v_co AND tmpl_cd = 'EDU_LOG' LIMIT 1;
        v_doc_no := sp_tbl_doc_no_gen_c_000(v_co, 'EDU_LOG', v_today);
        INSERT INTO tbl_document(
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status,
            appr_line_cd, writer_id, write_dt, ver_no, del_yn, ins_id, ins_dt
        ) VALUES (
            v_co, 'EDU_LOG', 'HWP', v_doc_no, v_today,
            '교육일지(샘플·업로드슬롯)', 'WRK',
            v_line, 'admin', now(), 1, 'N', 'system', now()
        ) RETURNING idx INTO v_doc;

        INSERT INTO tbl_document_file(co_cd, doc_idx, file_kind, file_nm, file_path, file_size, mime_type, sort_no, ins_id)
        VALUES (
            v_co, v_doc, 'HWP_SRC', 'EDU_LOG_DEMO.hwpx',
            '_template/DEMO_EMPTY.hwpx', 0, 'application/x-hwpx', 1, 'system'
        );
    END IF;

END$$;
