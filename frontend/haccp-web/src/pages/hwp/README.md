# hwp

HWP 양식·문서주기 영역. 손대는 메뉴는 sys와 같이 `pages/hwp/{메뉴}/` (Page + Rule + README)로 분할한다. 골드: [`pages/sys/README.md`](../sys/README.md).

| 화면 | 폴더 | 요약 |
|------|------|------|
| `hwp-template-management` | `hwptemplate/` | 좌 목록 + rhwp 미리보기. 구분은 badge 표시 전용, 신규는 자사 고정 |
| `schedule-cycle-management` | `doccycle/` | 좌 30% 조회 전용 목록 + 우 70% 주기 폼 |

- 구분 라벨·판정은 `formType.ts` (`FORM_TYPE_LABEL` · `isCompanyForm`)
- API는 `api/hwp/hwpTemplateApi.ts` · `api/hwp/docCycleApi.ts`
- 서버 경로: `/api/v1/hwp/hwp-templates/*` · `/api/v1/hwp/doc-cycles/*`
- 사용양식 삭제는 법적서류와 `/api/v1/bas/company-templates/*` 를 공유한다. 그 메뉴 분할 때 이전

`scrnCd`·`persistId` 값은 폴더를 옮겨도 바꾸지 않는다.

## 관련

- 정본: `docs/7_에이전트_가이드_FE.md` · `.cursor/rules/09-haccp-frontend.mdc`
