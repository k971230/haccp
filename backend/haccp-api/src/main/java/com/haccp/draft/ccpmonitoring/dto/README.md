# dto

CCP 포장·가열·금속검출 작성 3화면 공통 DTO.

| DTO | 역할 |
|---|---|
| `CcpLogDraftFormRow` | 양식 선택 팝업 목록 (사용여부 예) |
| `CcpLogDraftListRow` | 좌측 작성 목록 |
| `CcpLogDraftRow` | 기록 표 1행 — `phaseCd` 로 작업 전/종료, `cells` 로 양식별 칸 |
| `CcpLogDraftPassRow` | 금속 통과량 표 1행 (MTL 전용) |
| `CcpLogDraftSaveRequest` | 저장 본문 |
| `CcpLogDraftDeleteItem` | 삭제 키 |

`cells` 는 `item_cd → 값` 맵이다. 서버가 계열별로 실제 컬럼으로 편다 —
PKG·HTG 는 `tbl_ccp_generic_monitor_cell`, MTL 은 `tbl_ccp_metal_sens_row` 의 O/X 컬럼.
