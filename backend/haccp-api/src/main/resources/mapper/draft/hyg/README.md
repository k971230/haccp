# mapper/draft/hyg

`HygProcessDraftMapper.xml` — `com.haccp.draft.hyg.HygProcessDraftMapper`

작성 SP 는 공정점검 테이블 SP `sp_tbl_hyg_process_r_000/r_001/c_000/d_000` 를 양식코드와 함께 호출한다.
양식 목록은 양식관리와 같은 `sp_tbl_html_hyg_prc_ver_r_000` 을 감싸 사용여부 Y·예시(000) 제외로 좁힌다.
저장 직후 `sp_tbl_hyg_process_sign_u_000` — 점검자·승인자·확인 서명 스냅샷.
