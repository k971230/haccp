# HACCP 업무 CRUD · 갭 요약 (BE)

> FE: [`12_업무_CRUD_FE.md`](12_업무_CRUD_FE.md)  
> BE 인덱스: [`00_문서인덱스.md`](2_문서인덱스_BE.md)  
> **완성도·부족분 판정 정본**: [`09`](16_통합완성도_및_부족분.md) (STEP 21 / G-16)  
> FE·BE URL·Job: [`08`](15_HACCP_FE_BE_통합_상세스펙.md)  
> 프레임워크·파일·보안: [`11`](18_프레임워크_파일_보안_작성규칙.md)

본 파일은 API·SP·env **요약**만 둔다. P0/P1·G-xx 판정은 09에만 갱신한다.

## 메뉴 IA

사이드바: `today-tasks` + `docs`/`flow`/`bas`/`sys` ([`24`](24_URL_DB_폴더_패키지_정본.md) · `120`).  
HWP leaf 양식·`doc_kind`·`scrn_cd` 1:1 (`37`).

## API 축

| 경로 | 용도 |
|------|------|
| `/api/v1/docs/ccp/ccp-cold-monitor/*` | 냉장 일지 |
| `/api/v1/docs/ccp/{scrnCd}/*` | 금속·검증·가열/멸균/여과 generic |
| `/api/v1/docs/prp/{scrnCd}/*` | 위생 DB형·시설 HTML. 재고·폐기·공정 작성은 HWP leaf |
| `/api/v1/docs/documents/*` | 문서함·상세·결재·파일·HWP 저장 |
| `/api/v1/docs/documents/approval-inbox` | 내 차례 결재함 |
| `/api/v1/sys/users/me/sign` | 서명 이미지 |

## SP 정본 (apply-all 이후)

| SP | 정본 파일 | 계약 |
|----|-----------|------|
| `sp_tbl_document_approval_c_000` | `15_sp_doc.sql` + **`33` 재적용** | REQUEST=`WRK`/`RJT`, CANCEL→`WRK`, 서명 후 CANCEL 차단 |
| `sp_tbl_ccp_cold_monitor_r_000` 등 목록 | `14`/`19`/`20` (6인자) | `30`과 동일 |
| `sp_tbl_document_appr_inbox_r_000` | `31` | 결재함 |
| 재고 양식 | `20` + `09`/`34`/`37` | `tmpl_logis-inventory-check` · 작성 화면 `inventory-hwp` |

`28_migrate_wave1_remain.sql`은 **결재 SP를 덮어쓰지 않는다.**

## 환경 의존

| env | 용도 |
|-----|------|
| `APP_FILE_ROOT` | 첨부·서명·HWP 볼륨 |
| `APP_RHWP_CLI_PATH` | HWP→PDF |
| DB `search_path` | `sasshaccp` (`00_schema.sql`) |

## 명세 구현 (38~42)

- 건강진단 그리드 `/api/v1/docs/prp/health-cert-record/*`
- 설비이력 M-D `/api/v1/docs/prp/equipment-history/*`
- 방충 yn 체크 · CCP 개선조치방법 · 협력업체 `coopListYn`
- MFRM 문서별 admin 메뉴 (`40`) · DEMO 시드 (`41`)
- 갭보완 (`42`) — 일일위생 `grp_nm` · 시설 주1회 · 설비 사진 업로드 · 냉장 행 서명 경로

## 동결·폐기 (요약 — 판정은 09)

| 항목 | 상태 | 근거 |
|------|------|------|
| smart-diary API | **폐기** (STEP 20) | BE 엔드포인트 제거 · DB DROP 별도 |
| audit-export | **동결** (STEP 20) | `@Deprecated` · FE 미노출 · audit-log와 별개 |
| generic CCP 신규 leaf · 시스템관리 신규 | 동결 | 09 §12 |
