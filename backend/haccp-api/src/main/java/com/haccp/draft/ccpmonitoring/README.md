# ccpmonitoring — CCP 모니터링일지 작성 (포장·가열·금속검출)

화면 3개 = 컨트롤러 3개. FE `pages/draft/ccp-monitoring/`.
URL 중분류는 `ccp-monitoring`, 자바 패키지는 하이픈을 못 써 `ccpmonitoring` 이다.

| 화면 | URL | 컨트롤러 | 서비스 | 데이터 |
|---|---|---|---|---|
| `ccp-pkg` | `/api/v1/draft/ccp-monitoring/ccp-pkg/*` | `CcpPkgDraftController` | `CcpLogDraftService(PKG)` | `tbl_ccp_generic_monitor` + `_row` + `_cell` |
| `ccp-htg` | `/api/v1/draft/ccp-monitoring/ccp-htg/*` | `CcpHtgDraftController` | `CcpLogDraftService(HTG)` | 위와 같음 |
| `ccp-mtl` | `/api/v1/draft/ccp-monitoring/ccp-mtl/*` | `CcpMtlDraftController` | `CcpMtlDraftService` | `tbl_ccp_metal_monitor` + `_sens_row` + `_pass_row` |

## 신규 테이블 없음

기존 CCP 작성 테이블을 그대로 쓴다. `phase_cd`(작업 전/작업 종료)는 두 계열 모두 이미 컬럼이 있었다
(`38` generic · `05` metal). 124 는 SP 만 손봤다 — generic 은 `phase_cd` 저장·조회 보강,
metal 은 `p_tmpl_cd` 를 맨 뒤 DEFAULT 인자로 열어 기존 `ccp-metal-monitor` 화면 호출이 그대로 통한다.

## 지면 계약

기록 행은 화면·서버가 같은 모양(`CcpLogDraftRow`)을 쓴다.
양식마다 다른 칸은 `cells` (item_cd → 값) 한 곳에 담고 서비스가 계열별로 편다.

| 계열 | cells 키 | 저장 위치 |
|---|---|---|
| PKG | `temp` · `min` · `sec` | `tbl_ccp_generic_monitor_cell` |
| HTG | `temp` · `time` | 위와 같음 |
| MTL | `hdr-fe` · `hdr-sus` · `hdr-prod` · `hdr-fe-prod` · `hdr-sus-prod` | `tbl_ccp_metal_sens_row` 의 O/X 컬럼 |

작업 전/작업 종료는 **행의 `phaseCd`(BEFORE·AFTER)로만** 가른다. DOM 위치로 판단하지 않는다.

## 지면 하단 4칸

한계기준 이탈내용·개선조치·조치자·확인은 저장할 컬럼이 없어 `DocCorrectiveSupport`
(`tbl_corrective_action` 의 `deviation_desc`·`action_desc`·`action_user_nm`·`confirm_user_nm`)로 넘긴다.
신규 컬럼을 만들지 않았다.

전송(REQUEST)·전송취소(CANCEL)는 여기 없다. 문서 허브 `PUT /api/v1/docs/documents/approval` 을 그대로 쓴다.
