# docs 파이프라인 (FE + BE + DB)

문서 관리 소스. 골드 구조는 [`pages/sys/README.md`](../sys/README.md)와 같다.
로컬 UI `http://localhost:4173` · API `http://localhost:7070`

라우트: `routeOf(scrnCd)` → `tabRoute.SCREEN_PATH` 계층 경로 (예: `/docs/html/hyg-process-template`). `/screen/{scrnCd}` 없음.

바꾸지 않음: `scrnCd` · `persistId` · HTTP URL (`/api/v1/hwp/*` · `/api/v1/doc/*` · `/api/v1/docs/html-form` · `/api/v1/docs/hyg-process`).

## 일지설정 세트 (왼쪽 목록 + 오른쪽 업무화면)

슈퍼 셸로 합치지 않는다. 우측 업무가 다르다. 화면 등록은 `shell/screenRegistry.tsx` 「문서 기준관리」.

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

합치지 않음: `buildListColumns` 3종, 우측 로직·API, Paper 5종 표 구조. `hyg-process-template`(양식관리)과 `hygiene-process-check`(작성)는 다른 메뉴.

---

## 0. 구조 규약

손대는 메뉴는 그 작업에서 sys와 같이 분할한다. 미리 전 메뉴를 나누지 않는다.

### 0-1. 폴더 = 메뉴 1개

```
pages/docs/
 ├ hwptemplate/  사용양식 관리 (hwp-template-management)
 ├ html/HtmlFormTemplatePage.tsx · htmlFormTemplateShared.ts  HTML양식 원본 5화면 공통 프레임
 ├ html/htmltemplate HTML양식 원본 (hyg-process-template)
 ├ html/ccpverifytemplate CCP 검증점검표 양식 (ccp-verify-template)
 ├ html/ccppkgtemplate CCP-1B 포장 모니터링일지 양식 (ccp-pkg-template)
 ├ html/ccphtgtemplate CCP-2B 가열 모니터링일지 양식 (ccp-htg-template)
 ├ html/ccpmtltemplate CCP-3P 금속검출 모니터링일지 양식 (ccp-mtl-template)
 ├ html/hygprocess   일반위생관리 및 공정점검표 작성 (hygiene-process-check) — 그룹 A 16개 밖
 ├ doccycle/    문서주기 (schedule-cycle-management)
 ├ documentbox/ 문서함·결재함·결재이력 (mode 공유)
 ├ hwpeditor/   HWP 작성기 (hwpLeaf 공유)
 ├ legalupload/ 법적서류
 ├ corrective/  개선조치
 └ README.md
```

### 0-2. Page / Rule

| 파일 | 담는 것 | 담지 않는 것 |
|---|---|---|
| `*Rule.ts` | `SCRN_CD` · persistId · 컬럼 팩터리 · 잠금 · 순수 변환 | JSX · `useState` · API |
| `*Page.tsx` | 렌더 · 상태 · API · 핸들러 | 컬럼·잠금 하드코딩 |

### 0-3. API (`src/api/docs/`)

| 파일 | 대상 |
|---|---|
| `hwpTemplateApi.ts` | 사용양식 관리 — URL `/api/v1/hwp/...` |
| `htmlFormApi.ts` | HTML양식 원본 5화면 + 공정점검 작성 — URL `/api/v1/docs/html-form` · `/api/v1/docs/hyg-process` |
| `docCycleApi.ts` | 문서주기 — URL `/api/v1/hwp/doc-cycles` |

파일 I/O는 공용 `api/documentApi.ts`. 개선조치는 `taskWorkflowApi`.

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
| 결재함 | `approval-inbox` | `doc-approval-inbox` |
| 결재이력 | `approval-history` | `doc-approval-history` |
| 법적서류 | `legal-document-upload` | `legal-tmpl-list` · `legal-doc-list` |
| 개선조치 | `corrective-action-management` | `doc-corrective-actions` |
| HWP leaf | 각 scrnCd | `hwp-document-list-{scrnCd}` |

### 0-5. 백엔드 (`com.haccp.docs`)

```
java/com/haccp/docs/
 ├ hwptemplate/              사용양식 — URL /api/v1/hwp/...
 ├ html/htmltemplate         HTML양식 원본 Controller·Service — URL /api/v1/docs/html-form
 ├ html/ccpverifytemplate    CCP 검증점검 Mapper (Controller는 htmltemplate 공유)
 ├ html/ccppkgtemplate       CCP-1B 포장 Mapper
 ├ html/ccphtgtemplate       CCP-2B 가열 Mapper
 ├ html/ccpmtltemplate       CCP-3P 금속검출 Mapper
 ├ html/hygprocess           공정점검 작성 — URL /api/v1/docs/hyg-process
 ├ doccycle/                 문서주기 — URL /api/v1/hwp/doc-cycles
 ├ document/                 Document* 문서함·결재·첨부 — URL /api/v1/doc/documents
 ├ template/                 Template* 파일 저장 — URL /api/v1/doc/templates
 └ corrective/               DocCorrective*
```

XML `resources/mapper/docs/{같은 폴더명}/`. 폴더를 옮겨도 HTTP 경로는 바꾸지 않는다.

### 0-6. CUD

HTTP DELETE 금지. `validate-delete` → `delete` Double Check. 회사코드는 JWT만.

---

## 1. 사용양식 · 2. 문서주기

화면 README `hwptemplate/` · `doccycle/`. HTTP는 `/api/v1/hwp/...` 그대로.

## HTML양식 원본 5화면

화면 README `html/` · `htmltemplate/` · `ccpverifytemplate/` · `ccppkgtemplate/` · `ccphtgtemplate/` · `ccpmtltemplate/`. 공통 프레임 `HtmlFormTemplatePage`. HTTP는 `/api/v1/docs/html-form` 그대로. 작성 `hygprocess` 는 `/api/v1/docs/hyg-process`.

## 3. 문서함 · 4. HWP 작성기 · 5. 법적서류 · 6. 개선조치

화면 README `documentbox/` · `hwpeditor/` · `legalupload/` · `corrective/`. HTTP는 `/api/v1/doc/...` 그대로.

## 7. 신규 메뉴

`pages/sys/README.md` §8과 같다. 폴더는 `pages/docs/{메뉴}/`, 패키지는 `com.haccp.docs.{메뉴}`, XML은 `mapper/docs/{메뉴}/`.
