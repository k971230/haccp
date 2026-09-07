# ccpmonitoring — CCP 모니터링일지 작성 (포장·가열·금속검출)

화면 3개 = 컨트롤러 3개. FE `pages/draft/ccp-monitoring/`.
URL 중분류는 `ccp-monitoring`, 자바 패키지는 하이픈을 못 써 `ccpmonitoring` 이다.

| 화면 | URL | 컨트롤러 | 서비스 | 데이터 |
|---|---|---|---|---|
| `ccp-pkg` | `/api/v1/draft/ccp-monitoring/ccp-pkg/*` | `CcpPkgDraftController` | `CcpPkgDraftService` | `tbl_ccp_pkg_monitor` + `_row` + `_cell` |
| `ccp-htg` | `/api/v1/draft/ccp-monitoring/ccp-htg/*` | `CcpHtgDraftController` | `CcpHtgDraftService` | `tbl_ccp_htg_monitor` + `_row` + `_cell` |
| `ccp-mtl` | `/api/v1/draft/ccp-monitoring/ccp-mtl/*` | `CcpMtlDraftController` | `CcpMtlDraftService` | `tbl_ccp_metal_monitor` + `_sens_row` + `_pass_row` |

포장·가열은 표와 SP 를 계열별로 둔다. generic 표는 없다.
조립(EAV 접기·이탈 푸터)은 `CcpMonitorDraftSupport` 가 맡는다.

## 지면 계약

기록 행은 화면·서버가 같은 모양(`DraftLogRow`)을 쓴다.
양식마다 다른 칸은 `cells` 한 곳에 담고 서비스가 계열 DTO 로 받는다.

| 계열 | cells 키 | 타입 | 저장 위치 |
|---|---|---|---|
| PKG | `temp` · `min` · `sec` | `PkgLogCells` | `tbl_ccp_pkg_monitor_cell` |
| HTG | `temp` · `time` | `HtgLogCells` | `tbl_ccp_htg_monitor_cell` |
| MTL | `hdr-fe` · `hdr-sus` · `hdr-prod` · `hdr-fe-prod` · `hdr-sus-prod` | Map | `tbl_ccp_metal_sens_row` 의 O/X 컬럼 |

작업 전/작업 종료는 **행의 `phaseCd`(BEFORE·AFTER)로만** 가른다. DOM 위치로 판단하지 않는다.

## 지면 하단 4칸

한계기준 이탈내용·개선조치·조치자·확인은 저장할 컬럼이 없어 `DocCorrectiveSupport`
(`tbl_corrective_action` 의 `deviation_desc`·`action_desc`·`action_user_nm`·`confirm_user_nm`)로 넘긴다.
신규 컬럼을 만들지 않았다.

전송(REQUEST)·전송취소(CANCEL)는 여기 없다. 문서 허브 `PUT /api/v1/docs/documents/approval` 을 그대로 쓴다.
