# 결재선 관리 (`approval-line-management`)

정본 파이프라인 요약은 상위 [`pages/sys/README.md`](../../README.md).

## 파일

| 파일 | 책임 |
|---|---|
| `ApprovalLineManagementPage.tsx` | 렌더·상태·API. 좌 결재선 + 우 고정 3단계 |
| `ApprovalLineManagementRule.ts` | `SCRN_CD` · persistId · 컬럼 · `emptySteps` · `normalizeSteps` |

## 화면 규칙

- 좌 결재선: 행추가·저장·삭제. 분할 기본 32%. `DEFAULT` 기본 결재선은 삭제 불가
- 우 단계: 1작성 · 2검토 · 3승인 고정. **저장만**. 행추가·삭제 없음
- 열 순서: 순서 · 역할 · 부서 · 결재자 · 사용
- 검토 사용여부 기본 **사용안함**. 작성과 승인은 항상 사용
- 결재자는 셀 버튼 룩업. 고르면 소속 부서가 따라 들어온다. 직위코드 없음
- URL은 `/sys/code/approval-line-management` — 메뉴 중분류 `code`. `/screen/{scrnCd}` 없음

## API · SP · 테이블

| 동작 | API (`api/sys/approvalLineApi.ts`) | SP | 테이블 |
|---|---|---|---|
| 조회 | `listApprovalLines` | `sp_tbl_approval_line_r_000` | `tbl_approval_line` `tbl_approval_line_step` |
| 저장 | `saveApprovalLine` | `sp_tbl_approval_line_c_000` | 위 |
| 삭제 | `validateDeleteApprovalLines` → `deleteApprovalLines` | `sp_tbl_approval_line_delete_blocker_r_000` → `sp_tbl_approval_line_d_000` | 위 |

점검항목 콤보도 같은 목록 API를 쓴다.

## pref 키

`scrnCd = approval-line-management` · `persistId = bas-approval-line-header` · `bas-approval-line-steps-v2` · split `haccp-split-approval-line-v2`
