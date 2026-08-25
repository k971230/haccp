# hyg — 위생공정 양식 작성

화면 1개 = 패키지 1개(중 아래 화면이 하나라 `{메뉴}` 단 생략). FE `pages/draft/hyg/`.

URL `/api/v1/draft/hyg/hyg-process/*`
XML `mapper/draft/hyg/HygProcessDraftMapper.xml`
scrnCd `hyg-process` · 양식 `html_hyg_prc_001` 이상(사용여부 Y 자사 양식만)

양식관리 `hyg-process-template` 에서 사용여부를 예로 둔 양식만 작성 대상이다.
작성 SP 는 공정점검 테이블 SP `sp_tbl_hyg_process_*` 를 양식코드와 함께 그대로 쓴다(121에서 `p_tmpl_cd` 개방).
저장 후 `sp_tbl_hyg_process_sign_u_000` 이 점검자·승인자·확인 서명을 스냅샷한다.

전송(REQUEST)·전송취소(CANCEL)는 여기 없다. 문서 허브 `PUT /api/v1/docs/documents/approval` 을 그대로 쓴다.
상태 3단계: 전송대기 `WRK`·`RJT` / 전송 `REQ`·`REV` / 결재완료 `APV`.
