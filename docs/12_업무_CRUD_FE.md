# HACCP 업무 CRUD · 갭 요약 (FE)

> BE 대칭: [`13_업무_CRUD_BE.md`](13_업무_CRUD_BE.md).  
> BE: [`13_업무_CRUD_BE.md`](13_업무_CRUD_BE.md)  
> 인덱스: [`00_문서인덱스_및_통합리뷰.md`](1_문서인덱스.md)

## 합본 규칙 (STEP 21 / G-16)

| 주제 | 정본 |
|------|------|
| 완성도 판정 · P0/P1 · G-xx 상태 | **[`09_통합완성도_및_부족분.md`](16_통합완성도_및_부족분.md)** |
| 메뉴×FE×BE×API | [`07`](14_메뉴_화면_API_DB_전수.md) |
| URL·Job·파이프라인 | [`08`](15_HACCP_FE_BE_통합_상세스펙.md) |

**본 06은 업무 흐름·IA·deep-link 요약만 둔다.** 완료/부분/동결·부족분 ID 판정표는 09에만 유지한다 (시점 차이 방지).

---

## 제품 핵심

작성(DB/HWP) → 상신 → 결재함 검토·승인 → 문서함 보관·검색.

## 메뉴 IA (사이드바)

로그인 랜딩: `today-tasks` (최상위 leaf). 대메뉴 정본은 [`24`](24_URL_DB_폴더_패키지_정본.md) · `db_sasshaccp/02_seed.sql`.

| 순서 | 메뉴 | menu_cd | 내용 |
|------|------|---------|------|
| 0 | 오늘 할 일 | `today-tasks` | KPI·오늘 할 일·최근 문서 (미리보기 패널 없음) |
| 1 | 문서 | `docs` | 작성(CCP/PRP/물류/운영) + 기준관리(HWP·HTML·주기). 구 「문서 작성」+「문서 기준관리」 |
| 2 | 문서 현황·결재 | `flow` | 결재함·문서함·이력·법적서류·개선조치 |
| 3 | 기초정보 | `bas` | 제품·원자재·거래처·창고 등 마스터 |
| 4 | 시스템 | `sys` | 공통코드·사용자·부서·권한·메뉴·결재선·로그 |

단독 `hwp-document-editor`·스마트일지·감사추출은 `use_yn=N`.  
smart-diary API는 STEP 20에서 폐기, audit-export는 동결(FE 미노출) — 상세는 09 G-14.

## 화면 계약

| 구분 | 화면 | 결재 버튼 |
|------|------|-----------|
| 작성 DB | Cold/CcpForm/Hygiene/BizOps/건강진단 | `writerActionsOnly` — 상신·취소만 |
| 작성 HWP | `visitor-log`·`waste-hwp` 등 (동일 `HwpDocumentEditorPage`) | 상신·취소 — 권한은 leaf `scrn_cd` |
| 결재 | `approval-inbox` | 검토·승인·반려 |
| 문서함 | `document-inbox` | 상신·취소 + 「작성화면」 deep-link |

## Deep-link

- URL: `routeOf(scrnCd)?docIdx={n}` (basename `/haccp/`). `/screen/` 없음
- 홈·문서함「작성화면」→ [`src/lib/documentNav.ts`](../frontend/haccp-web/src/lib/documentNav.ts)
- HWP: [`HwpDocumentEditorPage`](../frontend/haccp-web/src/pages/docs/hwp/HwpDocumentEditorPage.tsx)가 `docIdx`로 원본 로드 (`PageScrnContext` 권한)
- DB형: 각 작성 페이지 `useDocIdxQuery`로 목록 행 선택

## 문서번호·양식

`tbl_template.mng_no` = `HA-*` (`36`). HWP leaf는 `fixedTmplCd` 1:1 (`37`, `screenRegistry`).  
DB→HWP 전환분(`tmpl_prp-hygiene-personal`·`WASTE` 등)은 `doc_kind=HWP` + 작성 `scrn_cd=*-hwp`.

## 판정·갭을 찾을 때

→ **[`09_통합완성도_및_부족분.md`](16_통합완성도_및_부족분.md)**  
스모크 표 → [`13_스모크_매트릭스.md`](19_스모크_매트릭스.md)

## 에이전트 주의

- 목록 SP는 6인자(`doc_no`,`writer`). 본문만 재적용해도 `14`/`19`/`20`이 정본이다.
- 재고 양식코드는 `tmpl_logis-inventory-check` (구 `INV` 금지).
- 결재 SP는 `WRK` — `28`에 TMP 결재 정의를 다시 넣지 말 것. 보강은 `33`.
- 신규 테넌트 메뉴 시드: `db_sasshaccp/01_sp.sql` `sp_tbl_company_init_c_000` (IA 5부모 + today-tasks).
