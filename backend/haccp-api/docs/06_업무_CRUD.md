# HACCP 업무 CRUD · 갭 정본 (BE)

> FE: [`frontend/haccp-web/docs/06_업무_CRUD.md`](../../../frontend/haccp-web/docs/06_업무_CRUD.md)  
> FE·BE 통합 상세: [`08_HACCP_FE_BE_통합_상세스펙.md`](../../../frontend/haccp-web/docs/08_HACCP_FE_BE_통합_상세스펙.md)  
> 완성도·부족분: [`09_통합완성도_및_부족분.md`](../../../frontend/haccp-web/docs/09_통합완성도_및_부족분.md)  
> 파일·컴포넌트·함수 지도: [`10`](../../../frontend/haccp-web/docs/10_파일구조_컴포넌트_함수지도.md)  
> 프레임워크·파일·보안: [`11`](../../../frontend/haccp-web/docs/11_프레임워크_파일_보안_작성규칙.md)  
> BE 01~04: [`01`](01_운영규칙.md) · [`02`](02_인수인계_및_아키텍처.md) · [`03`](03_에이전트_가이드.md) · [`04`](04_인증_보안_JWT.md)  
> 인덱스 [`00`](../../../frontend/haccp-web/docs/00_문서인덱스_및_통합리뷰.md)

## 메뉴 IA

사이드바: `today-tasks` + `MWRK`/`MAPR`/`MFRM`/`MCOD`/`MSYS` (`36`).  
HWP leaf 양식·`doc_kind`·`scrn_cd` 1:1 (`37`).

## API 축

| 경로 | 용도 |
|------|------|
| `/api/v1/ccp/cold-monitor/*` | 냉장 일지 |
| `/api/v1/ccp/{form}/*` | 금속·검증·가열/멸균/여과 generic |
| `/api/v1/hyg/{screen}/*` | 위생 DB형 (일일·방충 등) |
| `/api/v1/fac|inv|prc/*` | BizOps — 시설 등. 재고·폐기·공정 작성은 HWP leaf로 이전 |
| `/api/v1/doc/documents/*` | 문서함·상세·결재·파일·HWP 저장 |
| `/api/v1/doc/documents/approval-inbox` | 내 차례 결재함 |
| `/api/v1/sys/users/me/sign` | 서명 이미지 |

## SP 정본 (apply-all 이후)

| SP | 정본 파일 | 계약 |
|----|-----------|------|
| `sp_tbl_document_approval_c_000` | `15_sp_doc.sql` + **`33` 재적용** | REQUEST=`WRK`/`RJT`, CANCEL→`WRK`, 서명 후 CANCEL 차단 |
| `sp_tbl_ccp_cold_monitor_r_000` 등 목록 | `14`/`19`/`20` (6인자) | `30`과 동일 |
| `sp_tbl_document_appr_inbox_r_000` | `31` | 결재함 |
| 재고 양식 | `20` + `09`/`34`/`37` | `INV_CHECK` · 작성 화면 `inventory-hwp` |

`28_migrate_wave1_remain.sql`은 **결재 SP를 덮어쓰지 않는다.**

## 환경 의존

| env | 용도 |
|-----|------|
| `APP_FILE_ROOT` | 첨부·서명·HWP 볼륨 |
| `APP_RHWP_CLI_PATH` | HWP→PDF |
| DB `search_path` | `sasshaccp` (`00_schema.sql`) |

## 명세 구현 (38~42)

- 건강진단 그리드 `/api/v1/hyg/health-cert/*`
- 설비이력 M-D `/api/v1/bas/equipment-hist/*`
- 방충 yn 체크 · CCP 개선조치방법 · 협력업체 `coopListYn`
- MFRM 문서별 admin 메뉴 (`40`) · DEMO 시드 (`41`)
- 갭보완 (`42`) — 일일위생 `grp_nm` · 시설 주1회 · 설비 사진 업로드 · 냉장 행 서명 경로

## 동결 유지

스마트일지 CUD · 감사추출 UI · generic CCP 신규 leaf · 시스템관리 신규 기능.
