# docs 파이프라인 (FE + BE + DB)

문서 관리 소스. 골드 구조는 [`pages/sys/README.md`](../sys/README.md)와 같다.
로컬 UI `http://localhost:4173` · API `http://localhost:7070`

라우트: `routeOf(scrnCd)` → `tabRoute.SCREEN_PATH` 계층 경로 (예: `/docs/html-form/hyg-process-template`). `/screen/{scrnCd}` 없음.

바꾸지 않음: `scrnCd` · `persistId`. `/sys/`·`/docs/` 화면 HTTP: `/api/v1` + `SCREEN_PATH` + 동작. `/haccp` 는 API에 넣지 않는다. 문서함·결재·HWP leaf 허브는 `/api/v1/docs/documents` · `/api/v1/docs/templates`.

## 일지설정 세트 (왼쪽 목록 + 오른쪽 업무화면)

슈퍼 셸로 합치지 않는다. 우측 업무가 다르다. 화면 등록은 `shell/screenRegistry.tsx`.

| scrnCd | 화면 | 우측 |
|--------|------|------|
| `schedule-cycle-management` | 문서주기 | 주기 폼 |
| `hwp-template-management` | 사용양식 HWP | rhwp 미리보기·업로드 |
| `hyg-process-template` | 공정점검 양식 | HtmlFormTemplatePage + HygPrcPaper |
| `ccp-verify-template` | CCP 검증점검 양식 | 위와 같음. Paper는 HygPrcPaper re-export |
| `ccp-pkg-template` | CCP-1B 포장 | HtmlFormTemplatePage + CcpPkgPaper |
| `ccp-htg-template` | CCP-2B 가열 | HtmlFormTemplatePage + CcpHtgPaper |
| `ccp-mtl-template` | CCP-3P 금속검출 | HtmlFormTemplatePage + CcpMtlPaper |

공통: `PageCard` · `SearchArea` · `ResizableSplit` · `MesEditableGrid` · `splitPanelClass`(pageClasses). 그리드 열 pref는 `/api/v1/pref/grid` 한 벌.

합치지 않음: `buildListColumns` 3종, 우측 로직·API, Paper 5종 표 구조. `hyg-process-template`(양식관리)과 `hyg-process`(작성, `pages/draft/html/`)는 다른 메뉴다.

---

## 0. 구조 규약

손대는 메뉴는 그 작업에서 sys와 같이 분할한다. 미리 전 메뉴를 나누지 않는다.

### 0-1. 폴더 = 메뉴 1개

```
pages/docs/
 ├ hwp/          사용양식 HWP 관리 (hwp-template-management)
 ├ html-form/    HTML양식 원본 5화면 공통 프레임 — HtmlFormTemplatePage.tsx · htmlFormTemplateShared.ts
 │   ├ htmltemplate       HTML양식 원본 (hyg-process-template)
 │   ├ ccpverifytemplate  CCP 검증점검표 양식 (ccp-verify-template)
 │   ├ ccppkgtemplate     CCP-1B 포장 모니터링일지 양식 (ccp-pkg-template)
 │   ├ ccphtgtemplate     CCP-2B 가열 모니터링일지 양식 (ccp-htg-template)
 │   └ ccpmtltemplate     CCP-3P 금속검출 모니터링일지 양식 (ccp-mtl-template)
 ├ sch/          문서주기 (schedule-cycle-management)
 └ README.md
```

**작성 화면은 여기가 아니다.** `pages/draft/` 에 있다 —
`draft/html/`(`hyg-process`·`ccp-verify`) · `draft/ccp-monitoring/`(`ccp-pkg`·`ccp-htg`·`ccp-mtl`) ·
`draft/hwp-doc/`(`hwp-write`). HWP 에디터도 `draft/hwp-doc/HwpEditorPane.tsx` 다.

### 0-2. Page / Rule

| 파일 | 담는 것 | 담지 않는 것 |
|---|---|---|
| `*Rule.ts` | `SCRN_CD` · persistId · 컬럼 팩터리 · 잠금 · 순수 변환 | JSX · `useState` · API |
| `*Page.tsx` | 렌더 · 상태 · API · 핸들러 | 컬럼·잠금 하드코딩 |

### 0-3. API (`src/api/docs/`)

| 파일 | 대상 |
|---|---|
| `hwpTemplateApi.ts` | 사용양식 관리 — URL `/api/v1/docs/hwp/hwp-template-management` |
| `htmlFormApi.ts` | HTML양식 원본 5화면 + 공정점검 작성 — URL `/api/v1/docs/html-form/{scrnCd}` · `/api/v1/docs/html-form/hyg-process-template` |
| `docCycleApi.ts` | 문서주기 — URL `/api/v1/docs/sch/schedule-cycle-management` |

파일 I/O는 공용 `api/documentApi.ts`. 개선조치는 `api/board/taskWorkflowApi`.

### 0-4. pref 키 (값 변경 금지)

| 화면 | scrnCd | persistId |
|---|---|---|
| 사용양식 | `hwp-template-management` | `hwp-template-management-list` |
| 공정점검 양식 | `hyg-process-template` | `hyg-process-template-list` |
| CCP 검증점검 양식 | `ccp-verify-template` | `ccp-verify-template-list` |
| CCP-1B 포장 양식 | `ccp-pkg-template` | `ccp-pkg-template-list-v2` |
| CCP-2B 가열 양식 | `ccp-htg-template` | `ccp-htg-template-list-v2` |
| CCP-3P 금속검출 양식 | `ccp-mtl-template` | `ccp-mtl-template-list-v2` |
| 문서주기 | `schedule-cycle-management` | `doc-cycle-forms` |
| 문서함 | `document-inbox` | `doc-document-inbox` |
| 결재 대기 | `sign-ready` | `doc-approval-inbox` |
| 결재 완료 | `sign-ok` | `doc-approval-history` |
| 개선조치 | `corrective-action-management` | `doc-corrective-actions` |
| HWP 작성 | `hwp-write` | `hwp-draft-list` |

### 0-5. 백엔드 (`com.haccp.docs`)

```
java/com/haccp/docs/
 ├ hwp/                          사용양식 — URL /api/v1/docs/hwp/hwp-template-management
 ├ sch/                          문서주기 — URL /api/v1/docs/sch/schedule-cycle-management
 ├ htmlform/htmltemplate         HTML양식 원본 Controller·Service — URL /api/v1/docs/html-form/{scrnCd} 5화면
 ├ htmlform/ccpverifytemplate    CCP 검증점검 Mapper (Controller는 htmltemplate 공유)
 ├ htmlform/ccppkgtemplate       CCP-1B 포장 Mapper
 ├ htmlform/ccphtgtemplate       CCP-2B 가열 Mapper
 ├ htmlform/ccpmtltemplate       CCP-3P 금속검출 Mapper
 ├ documents/                    Document* 문서함·결재·첨부 — URL /api/v1/docs/documents (공유 허브)
 └ templates/                    Template* 파일 저장 — URL /api/v1/docs/templates (공유 허브)
```

**패키지·XML 폴더는 `htmlform`, HTTP 경로만 `html-form` 이다.** 하이픈은 URL 에만 있다.

개선조치는 `com.haccp.flow.ca`. XML `resources/mapper/{대}/{중}/`. 폴더를 옮겨도 HTTP 경로는 바꾸지 않는다.

### 0-6. CUD

HTTP DELETE 금지. `validate-delete` → `delete` Double Check. 회사코드는 JWT만.

---

## 1. 사용양식 · 2. 문서주기

화면 README `hwp/` · `sch/`. HTTP는 `/api/v1/docs/hwp/hwp-template-management` · `/api/v1/docs/sch/schedule-cycle-management`.

## HTML양식 원본 5화면

화면 README `html-form/` 과 그 아래 `htmltemplate/` · `ccpverifytemplate/` · `ccppkgtemplate/` · `ccphtgtemplate/` · `ccpmtltemplate/`. 공통 프레임 `HtmlFormTemplatePage`. HTTP는 `/api/v1/docs/html-form/{scrnCd}`.

## 3. 문서함 · 4. HWP 작성 · 5. 개선조치

화면 README `flow/box/documentbox/` · `draft/hwp-doc/` · `flow/ca/corrective/`. HTTP는 `/api/v1/docs/documents` · `/api/v1/docs/templates` · `/api/v1/flow/ca/corrective-action-management`.

## 7. 신규 메뉴

`pages/sys/README.md` §8과 같다. 폴더는 `pages/{대}/{중}/`, 패키지는 `com.haccp.{대}.{중}`, XML은 `mapper/{대}/{중}/`. 경로 정본 `docs/4_명명과_경로.md`.
