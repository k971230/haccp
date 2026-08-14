# 사용양식 관리 (`hwp-template-management`)

화면 1개 = 폴더 1개. 골드: [`pages/sys/README.md`](../../sys/README.md).

## 파일

| 파일 | 책임 |
|---|---|
| `HwpTemplateManagementPage.tsx` | 렌더·상태·API·rhwp 미리보기. 좌 목록 + 파일 버전(업로드/내보내기/불러오기/초기화) |
| `HwpTemplateManagementRule.ts` | `SCRN_CD` · `PERSIST_ID` · `LIST_GRID_RULES` · `buildListColumns` · `buildButtonState` |
| `../formType.ts` | 구분 라벨·자사양식 판정 정본 — 문서주기관리와 공유 |

## 화면 규칙

- 구분(시스템/자사)은 서버가 정하고 badge 표시 전용. 신규는 항상 자사양식
- `tmplCd` 는 신규행만 편집 (`LIST_GRID_RULES.newOnly`)
- 파일 기능은 구분과 무관. 삭제만 자사양식(+ 신규 draft) 허용
- 업로드는 덮어쓰지 않고 버전 1건을 쌓는다

## API · SP

| 동작 | API (`api/hwp/hwpTemplateApi.ts`) | 서버 |
|---|---|---|
| 목록 | `listHwpTemplates` | `GET /api/v1/hwp/hwp-templates/list` |
| 저장 | `saveHwpTemplate` | `PUT /api/v1/hwp/hwp-templates/save` |
| 파일이력 | `listHwpTemplateFiles` | `GET .../files` |
| 불러오기/초기화 | `applyHwpTemplateFile` | `POST .../apply-file` |
| 삭제 검증 → 삭제 | `validateDeleteCompanyTemplates` → `deleteCompanyTemplates` | `/api/v1/bas/company-templates/*` — 법적서류와 URL 공유. 그 메뉴 분할 때 이전 |

파일 원본 I/O는 `documentApi` (`loadHwpTemplateFile` · `saveHwpTemplateForm`).

## pref 키

`scrnCd = hwp-template-management` · `persistId = hwp-template-management-list` — 값 변경 금지.
