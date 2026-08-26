# com.haccp.docs.sch.dto — 문서주기 전송 객체

| 파일 | 역할 |
|---|---|
| `DocCycleRow.java` | 좌측 양식 목록 한 줄 |
| `DocCycleSaveRequest.java` | 우측 주기 폼 저장 본문 — 주기·요일·실행일·시각·담당·결재선 |
| `DocCycleDeleteItem.java` | 삭제 키 `{ tmplCd }` |

주기 상세(요일·월 실행일 등)는 `tbl_schedule_rule_detail` 에 EAV(`detail_ty`/`val1`/`val2`)로 접힌다.
접었다 펴는 변환은 FE `ScheduleCycleManagementRule` 의 `detailsToForm`/`formToDetails` 가 정본이다.
