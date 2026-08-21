# 개선조치 관리 (`corrective-action-management`)

정본 파이프라인 요약은 상위 [`pages/docs/README.md`](../README.md).

## 파일

| 파일 | 책임 |
|---|---|
| `CorrectiveActionManagementPage.tsx` | 렌더·상태·API. 좌 목록 + 우 입력 폼 |
| `CorrectiveActionManagementRule.ts` | `SCRN_CD` · `PERSIST_ID` · `STATUS_OPTIONS` · `FIELD_LABELS` · `buildColumns` |

## 화면 규칙

- 조회는 기간·상태. 문서번호·작성자는 FE 부분필터
- 목록은 선택용. 상세는 우측 폼
- 완료 상태는 서버 SP가 삭제를 차단한다

## API · SP · 테이블

| 동작 | API (`api/taskWorkflowApi.ts`) | SP | 테이블 |
|---|---|---|---|
| 조회 | `listCorrectiveActions` | `sp_tbl_doc_corrective_*` | `tbl_doc_corrective` |
| 저장 | `saveCorrectiveAction` | 위 | 위 |
| 삭제 | `validateDeleteCorrectiveActions` → `deleteCorrectiveActions` | 위 | 위 |

## pref 키

`scrnCd = corrective-action-management` · `persistId = doc-corrective-actions` — 값 변경 금지.
