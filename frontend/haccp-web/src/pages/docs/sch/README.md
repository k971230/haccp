# 문서주기관리 (`schedule-cycle-management`)

정본 파이프라인 요약은 상위 [`pages/docs/README.md`](../README.md) 2장.

## 파일

| 파일 | 책임 |
|---|---|
| `ScheduleCycleManagementPage.tsx` | 렌더·상태·API. 좌 목록 + 우 주기 폼 |
| `ScheduleCycleManagementRule.ts` | `SCRN_CD` · `PERSIST_ID` · `SPLIT_KEY` · 주기 상수·날짜 변환·`detailsToForm`/`formToDetails` · `buildFormColumns` |

## 화면 규칙

- 좌측은 조회 전용. 양식 등록·삭제는 사용양식 관리 몫
- 검색: 양식코드 · 양식명 · 사용여부(기본 Y, 빈값=전체)
- 목록 열: 양식코드 · 양식명 · 구분 · 사용여부. 구분 문구는 공통코드 관리 `sys-yn`
- 분할 기본 50:50 (범위 약 25~75)
- 양식 1개 = 주기 0..1건. 우측은 그리드가 아닌 단일 폼(업서트)
- 반복설정은 주기 콤보에 따라 영역만 교체 — 매일·비정기 안내 / 매주 요일 / 매월 실행일(파랑)·말일 실행(노랑, 전폭) / 분기·반기·매년 월+일
- 매월 1~31 칩은 `auto-fill` 그리드. 「말일 실행」은 날짜 칸 아래 한 줄
- 담당자 「선택」은 입력과 한 줄(`size="sm"`, 조회 버튼과 같은 높이)
- 결재선 「선택」도 같은 한 줄. 결재선관리(`approval-line-management`) 목록. 작성(WRITE)에 사람이 있으면 담당자·담당부서를 채운다. (없음)은 결재선만 비운다
- 주기 없는 양식 기본값: 당일 · 매일 · 그대로 · 18:00 · 담당 빈값 · 사용양식 결재선 · 사용 Y
- 미저장 변경이 있으면 좌측 행 이동 전에 `mesConfirm`

## API · SP · 테이블

| 동작 | API (`api/docs/docCycleApi.ts`) | SP | 테이블 |
|---|---|---|---|
| 양식 목록 | `listDocCycleForms` | `sp_schedule_cycle_management_form_r_000` | `tbl_company_template` `tbl_template` `tbl_schedule_rule` |
| 단건 | `getDocCycle` | `sp_schedule_cycle_management_r_000` | `tbl_schedule_rule` `tbl_schedule_rule_detail` `tbl_company_template` `tbl_approval_line` |
| 저장 | `saveDocCycle` | `sp_schedule_cycle_management_c_000` | `tbl_schedule_rule` `tbl_schedule_rule_detail` `tbl_company_template` |
| 저장 직후 예정일 재생성 | (Service) | `sp_tbl_schedule_task_regen_c_000` | `tbl_schedule_task` |
| 삭제 검증 | `validateDeleteDocCycles` | SP 없음 — Service가 `sp_schedule_cycle_management_r_000`으로 존재 확인 | `tbl_schedule_rule` |
| 삭제 | `deleteDocCycles` | `sp_schedule_cycle_management_d_000` | `tbl_schedule_rule` |
| 담당자 룩업 | `userApi.listUsers` | `sp_user_management_r_000` | `tbl_user` `tbl_dept` |
| 결재선 룩업 | `approvalLineApi.listApprovalLines` | `sp_tbl_approval_line_r_000` | `tbl_approval_line` `tbl_approval_line_step` |
| 마감 알림 배치 | `DocumentAlarmScheduler` | `sp_tbl_notification_task_c_000` | `tbl_schedule_task` |

목록 `useYn` 검색·비정기(E)·좌측 필터는 `db_sasshaccp/01_sp.sql`(Jenkins migrate 안 함, DBeaver/수동). 선행 86. 결재선은 `db_sasshaccp/01_sp.sql`.

HTTP `/api/v1/docs/sch/schedule-cycle-management`. 결재선 룩업은 `/api/v1/sys/code/approval-line-management`.

## pref 키

`scrnCd = schedule-cycle-management` · `persistId = doc-cycle-forms` · split `haccp-split-doc-cycle-50` — persistId 값 변경 금지.
