# com.haccp.docs.sch.dto — 문서주기 전송 객체

| 파일 | 역할 |
|---|---|
| (목록·저장 본문) | 전용 DTO 를 두지 않는다 — `DocCycleMapper` 가 `List<Map<String,Object>>` 로 받고 저장은 `@Param` 으로 넘긴다 |
| `DocCycleDeleteItem.java` | 삭제 키 `{ tmplCd }` |

주기 상세(요일·월 실행일 등)는 `tbl_schedule_rule_detail` 에 EAV(`detail_ty`/`val1`/`val2`)로 접힌다.
접었다 펴는 변환은 FE `ScheduleCycleManagementRule` 의 `detailsToForm`/`formToDetails` 가 정본이다.
