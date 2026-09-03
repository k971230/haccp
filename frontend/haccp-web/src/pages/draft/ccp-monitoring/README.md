# CCP 모니터링일지 작성 (`ccp-pkg` · `ccp-htg` · `ccp-mtl`)

양식관리 `ccp-pkg-template` · `ccp-htg-template` · `ccp-mtl-template` 에서 **사용여부 = 예**로 둔
자사 양식(`html_ccp_pkg_001` · `html_ccp_htg_001` · `html_ccp_mtl_001` 이상)만 작성한다.

좌측 업무(검색·체크박스·행 추가·양식 팝업·저장·전송·모두 전송·삭제·전송취소·결재 여부)는
전부 공통 `../HtmlFormDraftPage` + `../htmlFormDraftShared` 다. HYG·CCP검증과 같은 화면이다.
**이 폴더는 화면 고유 상수와 지면 연결만 갖는다.**

| 화면 | 지면 | 기록 표 | 데이터 |
|---|---|---|---|
| `ccp-pkg` | `CcpPkgPaper` | 1개 — 작업 전 / 작업 종료 | `tbl_ccp_generic_monitor` + `_row` + `_cell` |
| `ccp-htg` | `CcpHtgPaper` | 1개 — 작업 전 / 작업 종료 | 위와 같음 |
| `ccp-mtl` | `CcpMtlPaper` | 2개 — 감도(작업 전/후) + 통과량 | `tbl_ccp_metal_monitor` + `_sens_row` + `_pass_row` |

## 지면 mode 분리

같은 Paper 를 기준관리와 작성이 공유하되 **동작은 `mode` 로 완전히 갈린다.**

| | `mode="template"` (기준관리) | `mode="write"` (작성) |
|---|---|---|
| 행 | 빈 예시 4행 고정 | 저장된 기록행을 제어 렌더 |
| 입력 | 불가 | 전송대기 + 저장됨일 때만 가능 |
| 행 추가·삭제 | 없음 | 영역별 버튼 |

`logRows` 를 넘기지 않으면 지면은 **예전 미리보기 경로 그대로**다 — 기준관리 화면은 바뀌지 않는다.

## 행 추가 위치

- PKG·HTG: 기록표 아래 슬롯에 「작업 전 행 추가」 「작업 종료 행 추가」
- MTL: 감도표와 통과량표 사이 슬롯에 「작업 전 행 추가」 「작업 후 행 추가」 「제품 통과 행 추가」
  (「금속검출기 제품 통과」 문구 오른쪽)

각 버튼은 **자기 영역 끝에만** 행을 붙인다. 다른 영역 행 수는 변하지 않는다 —
`htmlFormLogRows.test.ts` 가 이 규칙을 고정한다.

## 지면 하단 4칸

한계기준 이탈내용·개선조치·조치자·확인은 저장할 컬럼이 없어 `tbl_corrective_action` 으로 간다.
신규 컬럼·테이블을 만들지 않았다.

API `/api/v1/draft/ccp-monitoring/{scrnCd}` · BE `com.haccp.draft.ccpmonitoring` · DB `db_sasshaccp/01_sp.sql`
