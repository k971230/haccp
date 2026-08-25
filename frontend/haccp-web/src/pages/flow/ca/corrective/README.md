# 개선조치 관리 (`corrective-action-management`)

정본 파이프라인 요약은 상위 [`pages/docs/README.md`](../../../docs/README.md).

## 파일

| 파일 | 책임 |
|---|---|
| `CorrectiveActionManagementPage.tsx` | 렌더·상태·API. **그리드 1개** |
| `CorrectiveActionManagementRule.ts` | `SCRN_CD` · `PERSIST_ID` · `STATUS_OPTIONS` · `STATUS_BADGE` · `buildColumns` |

## 화면 규칙

작성 화면에서 **이탈로 등록한 문서**를 모두 모아 한 표에서 조치를 적는다.
우측 상세 폼을 두지 않는다 — 적을 칸이 다섯이라 표에서 바로 치는 편이 빠르다.

- 검색: **일자 구간 · 양식 · 작성자** — 다른 작성 화면과 같은 순서다
  - 일자는 이탈 발생일이 아니라 **원문서 기준일**이다. 사용자가 찾는 것은 그 일지를 쓴 날이다
  - 양식 콤보는 회사가 쓰는 HWP·HTML 양식만 올린다 (`listDocumentTemplates`)
- 문서에서 온 칸(일자·양식·문서번호·작성자)은 **잠근다**. 원문서는 작성 화면에서 고친다
- 채우는 칸: 이탈내용·발생장소·조치내용·조치자·조치일·기한·상태
- 저장은 고친 행만 건별로 보낸다. 완료 상태는 서버 SP가 삭제를 차단한다

## API · SP · 테이블

| 동작 | API (`api/taskWorkflowApi.ts`) | SP | 테이블 |
|---|---|---|---|
| 조회 | `listCorrectiveActions` | `sp_tbl_corrective_action_r_000` | `tbl_corrective_action` |
| 저장 | `saveCorrectiveAction` | `sp_tbl_corrective_action_c_000` | 위 |
| 삭제 | `validateDeleteCorrectiveActions` → `deleteCorrectiveActions` | `sp_tbl_corrective_action_d_000` | 위 |

조회 SP는 `129_migrate_corrective_search.sql` 에서 검색 조건을 일자·양식·작성자로 바꾸고
문서 정보(양식명·문서번호·기준일·작성자)를 함께 돌려주도록 고쳤다.

## pref 키

`scrnCd = corrective-action-management` · `persistId = doc-corrective-actions` — 값 변경 금지.
