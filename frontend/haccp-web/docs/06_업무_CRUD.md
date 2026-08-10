# HACCP 업무 CRUD · 갭 정본 (FE)

> MES [`frontend/mes-web/docs/06_업무_CRUD.md`](../../mes-web/docs/06_업무_CRUD.md) 대칭.  
> BE: [`backend/haccp-api/docs/06_업무_CRUD.md`](../../../backend/haccp-api/docs/06_업무_CRUD.md)  
> 문서 세트: [`00_문서인덱스_및_통합리뷰.md`](00_문서인덱스_및_통합리뷰.md) · 완성도·부족분 정본 [`09_통합완성도_및_부족분.md`](09_통합완성도_및_부족분.md)

## 제품 핵심

작성(DB/HWP) → 상신 → 결재함 검토·승인 → 문서함 보관·검색.

## 메뉴 IA (사이드바)

로그인 랜딩: `today-tasks` (최상위 leaf). 대메뉴 5개 (`36_migrate_menu_sidebar_ia.sql`).

| 순서 | 메뉴 | menu_cd | 내용 |
|------|------|---------|------|
| 0 | 오늘 할 일 | `today-tasks` | KPI·오늘 할 일·최근 문서 (미리보기 패널 없음) |
| 1 | 문서 작성 | `MWRK` | DB형 점검표 + HWP 문서만 leaf |
| 2 | 문서 현황·결재 | `MAPR` | 결재함·문서함·이력·법적서류·개선조치 |
| 3 | 문서 기준관리 | `MFRM` | HWP양식·점검항목·CCP한계·작성주기·결재선·설비/방충 |
| 4 | 기초정보 관리 | `MCOD` | 공통코드·제품·원자재·거래처·창고 등 |
| 5 | 시스템 관리 | `MSYS` | 회사·사용자·부서·권한·메뉴·로그 |

구 대메뉴(`MCCP`/`MHYG`/…/`MSET`) 및 단독 `hwp-document-editor`·스마트일지·감사추출은 `use_yn=N`.

## 화면 계약

| 구분 | 화면 | 결재 버튼 |
|------|------|-----------|
| 작성 DB | Cold/CcpForm/Hygiene/BizOps/건강진단 | `writerActionsOnly` — 상신·취소만 |
| 작성 HWP | `visitor-log`·`waste-hwp` 등 (동일 `HwpDocumentEditorPage`) | 상신·취소 — 권한은 leaf `scrn_cd` |
| 결재 | `approval-inbox` | 검토·승인·반려 |
| 문서함 | `document-inbox` | 상신·취소 + 「작성화면」 deep-link |

## Deep-link

- URL: `/screen/{scrnCd}?docIdx={n}`
- 홈·문서함「작성화면」→ [`src/lib/documentNav.ts`](../src/lib/documentNav.ts)
- HWP: [`HwpDocumentEditorPage`](../src/pages/doc/HwpDocumentEditorPage.tsx)가 `docIdx`로 원본 로드 (`PageScrnContext` 권한)
- DB형: 각 작성 페이지 `useDocIdxQuery`로 목록 행 선택

## 문서번호·양식

`tbl_template.mng_no` = `HA-*` (`36`). HWP leaf는 `fixedTmplCd` 1:1 (`37`, `screenRegistry`).  
DB→HWP 전환분(`PERSONAL_HYG`·`WASTE` 등)은 `doc_kind=HWP` + 작성 `scrn_cd=*-hwp`.

## 완료·부분·동결

상세 판정·부족분 ID(G-xx)·리뷰 백로그는 **[`09`](09_통합완성도_및_부족분.md)가 정본**이다. 아래는 요약.

| 영역 | 판정 |
|------|------|
| 로그인·셸·권한·IA 메뉴 | 완료 |
| CCP 냉장 | 완료(기준) |
| 금속·검증·위생·BizOps | 부분 — 양식별 검증 밀도는 냉장 미만 (09 G-10) |
| HWP 편집·저장·상신 | 부분 — rhwp/CLI·서명 의존 (09 G-04·G-11) |
| 오늘 할 일 | 부분 — Job/로그인 보정 의존 (09 G-12) |
| 건강진단·설비/방충 이력·MFRM admin·법적서류 M-D | 완료 |
| 결재이력 메뉴 | 부족 가능 — DEMO leaf 갭 (09 G-01) |
| UV/PV 통계 | 부분 — 일집계 Job·env (09 G-02) |
| 스마트일지·감사추출 | **동결** |

## 에이전트 주의

- 목록 SP는 6인자(`doc_no`,`writer`). 본문만 재적용해도 `14`/`19`/`20`이 정본이다.
- 재고 양식코드는 `INV_CHECK` (구 `INV` 금지).
- 결재 SP는 `WRK` — `28`에 TMP 결재 정의를 다시 넣지 말 것. 보강은 `33`.
- 신규 테넌트 메뉴 시드: `13_sp_platform.sql` `sp_tbl_company_init_c_000` (IA 5부모 + today-tasks).
