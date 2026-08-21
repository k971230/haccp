# api

Axios HTTP 클라이언트·도메인 API 함수.

손대는 메뉴의 화면 전용 API는 `api/{영역}/` 로 나눈다. 공용 파일 I/O(`documentApi`)는 그대로 둔다.

## docs

| 파일 | 대상 |
|------|------|
| `docs/hwpTemplateApi.ts` | 사용양식관리 `/api/v1/hwp/hwp-templates/*`. 삭제는 `/api/v1/bas/company-templates/*` (법적서류와 URL 공유) |
| `docs/docCycleApi.ts` | 문서주기관리 `/api/v1/hwp/doc-cycles`. 저장 1회로 규칙 업서트 + 예정일 재생성까지 끝난다 |

## 기타

| 파일 | 대상 |
|------|------|
| `workflowApi.ts` | 점검항목·작성주기(구)·법적서류 삭제(`company-templates`) 등 |
| `sys/approvalLineApi.ts` | 결재선 `/api/v1/bas/approval-lines/*` (화면은 sys, URL 유지) |
| `documentApi.ts` | HWP 원본 읽기·업로드 등 공용 파일 I/O |

## 관련

- 정본: `docs/7_에이전트_가이드_FE.md` · `.cursor/rules/09-haccp-frontend.mdc`
