# pages/draft — 양식 작성

URL `/draft`. 사용 중인 양식을 골라 일자별 작성 문서를 만드는 화면 묶음이다.
HYG·CCP 는 **형제 화면**이며 UI·업무 흐름이 같다.

```
양식 작성 (draft)
 ├─ HTML 양식 (html)          기준 /docs/html-form/hyg-process-template → 작성 /draft/html/hyg-process
 │                            기준 /docs/html-form/ccp-verify-template  → 작성 /draft/html/ccp-verify
 ├─ CCP 모니터링 (ccp-monitoring)
 │   ├─ 기준 /docs/html-form/ccp-pkg-template → 작성 /draft/ccp-monitoring/ccp-pkg
 │   ├─ 기준 /docs/html-form/ccp-htg-template → 작성 /draft/ccp-monitoring/ccp-htg
 │   └─ 기준 /docs/html-form/ccp-mtl-template → 작성 /draft/ccp-monitoring/ccp-mtl
 └─ HWP 양식 (hwp-doc)        작성 /draft/hwp-doc/hwp-write
```

## 구성 — 공통 1개 + 화면별 얇은 래퍼

양식관리 5화면이 `HtmlFormTemplatePage` 를 공유하는 것과 같은 패턴이다.

| 파일 | 역할 |
|---|---|
| `HtmlFormDraftPage.tsx` | 공통 화면 — 검색·목록·체크박스·팝업·저장·전송·모두 전송·삭제 전부 여기 있다 |
| `htmlFormDraftShared.ts` | 공통 규칙 — 결재 여부 3단계·U/D/전송 잠금·좌측 컬럼·필수값 |
| `HtmlFormLookupModal.tsx` | 양식 선택 팝업 (일자·양식코드·양식명) |
| `htmlFormDraftShared.test.ts` | 상태 판정·필수값 단위 테스트 |
| `htmlFormLogRows.test.ts` | 기록 표 행 영역 분리·행 추가/삭제 단위 테스트 |
| `html/` | HTML 양식 2화면 래퍼 — `HygProcessDraftPage`·`CcpVerifyDraftPage` + Rule(상수만) |
| `ccp-monitoring/` | CCP 모니터링 3화면 래퍼 — `CcpPkg`·`CcpHtg`·`CcpMtl` `DraftPage`+`DraftRule` |

## 기록 표 행 (CCP 모니터링일지)

포장·가열·금속검출은 지면에 **기록 표**가 있다. 행은 `logRows`(감도·기록) / `passRows`(금속 통과량)로
`HtmlFormDraftPage` 버퍼에 실려 저장·재조회된다 — DOM 조작이 아니라 실제 데이터다.

- 작업 전/작업 종료는 **행의 `phaseCd`(BEFORE·AFTER)로만** 가른다. DOM 위치로 판단하지 않는다
- 행 추가 버튼은 영역마다 따로다 — PKG·HTG 2개, MTL 3개(작업 전·작업 후·제품 통과)
- 영역 첫 줄은 고정 라벨 행이라 삭제 버튼이 없다. 추가한 행만 우측 `×` 로 지운다
- 양식마다 다른 칸은 `cells`(item_cd → 값) 한 곳에 담는다. 서버가 계열별 컬럼으로 편다

화면별로 다른 것은 **config 5개 + Paper + api** 뿐이다: `scrnCd` · `persistId` · `splitKey` · `paperTitle` · `paperSubtitle`.
래퍼에 레이아웃을 덧붙이면 두 화면 UI 가 갈리므로 금지한다.

## 버튼 규칙 (좌·우 역할이 다르다)

두 패널의 「저장」·「삭제」는 이름이 같아도 **대상이 다르다**. 순서·색·아이콘은 아래 표가 정본이다.

### 좌측 — 작성 목록 (기본정보)

| 순서 | 버튼 | variant / 색 | icon | 대상 | 활성 조건 |
|---|---|---|---|---|---|
| 1 | 행 추가 | `add` / amber | `plus` | 새 draft 행 | 항상 (양식 0건이면 안내) |
| 2 | 저장 | `save` / blue | `save` | **일자 + 양식코드** 등록 — `docIdx` 를 만든다 | 항상 |
| 3 | 삭제 | `danger` / red | `trash` | 체크된 행(없으면 현재 행) | 항상 |
| 4 | 모두 전송 | `excel` / emerald | `approve` | 체크된 행 중 전송 가능 건 | 체크 1건 이상 |

일자 수정은 **좌측 그리드 셀**에서 한다(전송대기 행만). 고친 뒤 좌측 「저장」으로 커밋한다.
양식코드는 셀 입력이 아니라 **양식 선택 팝업** 전용이며 저장 후에는 잠긴다.

### 우측 — 상세 작성 (지면 값)

| 순서 | 버튼 | variant / 색 | icon | 대상 | 활성 조건 |
|---|---|---|---|---|---|
| 1 | 작성 후 저장 | `save` / blue | `save` | **지면 점검값·하단 4열** — 전송하지 않는다 | 저장된 전송대기 문서 |
| 2 | 전송 | `excel` / emerald | `approve` | **이 문서 1건만** 결재 상신(REQUEST) | 저장된 전송대기 문서 |
| 3 | 삭제 | `danger` / red | `trash` | 이 문서 1건 | `docIdx` 있음 (draft 삭제는 좌측) |
| 4 | 전송취소 | `secondary` / 회색 | `reset` | 상신취소(CANCEL) → 전송대기 복귀 | `REQ` 일 때만 |

### 공통 규칙

- **이모지 금지** — 아이콘은 Lucide preset(`MES_ICONS`) 이름만 쓴다 (`01-project-core.mdc`).
- 색 의미: 저장 blue · 전송 계열 emerald · 삭제 red · 취소/보조 회색 · 행 추가 amber.
- 전송 계열(전송·모두 전송)은 같은 색·같은 아이콘으로 묶어 「결재로 올린다」를 한눈에 보이게 한다.
- 좌측 저장은 dirty 전건, 우측 저장은 **열려 있는 문서의 지면 규칙**만 추가로 본다
  (다른 미저장 행이 우측 저장·전송을 막지 않는다).

## 경로 규칙

중분류 `menu_cd` 는 `tbl_menu UNIQUE (co_cd, menu_cd)` 때문에 전 트리에서 유일해야 한다.
2026-08-25 정리에서 docs 쪽 `html` 을 `html-form` 으로 개명하고 이 대분류가 `html` 을 가져갔다
(`db_sasshaccp/02_seed.sql`). BE 패키지는 `com.haccp.draft.html` 이다.

## 공통 업무 규칙

| 표시 | DOC_STATUS | 수정(U) | 삭제(D) | 전송 | 전송취소 |
|---|---|---|---|---|---|
| 전송대기 | `WRK` · `RJT` | 가능 | 가능 | 가능 | 불필요 |
| 전송 | `REQ` · `REV` | 제목만 | 불가 | — | `REQ` 만 가능 |
| 결재완료 | `APV` | 제목만 | 불가 | — | 불가 (결재 쪽에서 취소) |

좌측 목록 「제목」은 `tbl_document.title` 이다. 결재 첨부 화면의 비고(`tbl_document.remark`)와 다르다.
언제든 고친다. 검색 칸도 제목을 본다.

전송·전송취소는 문서 허브 `processDocumentApproval`(REQUEST/CANCEL)을 그대로 쓴다.
「결재 여부」로 표기를 통일한다 — 「결제」를 쓰지 않는다.
