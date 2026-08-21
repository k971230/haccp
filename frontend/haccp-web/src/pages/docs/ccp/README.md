# ccp 파이프라인 (FE + BE + DB)

중요관리점 작성 화면. 폴더는 URL 중칸 `pages/docs/ccp/`. HWP leaf `process-hwp/` 만 화면 하위 폴더다.

로컬 UI `http://localhost:4173` · API `http://localhost:7070`  
라우트: `routeOf(scrnCd)` → `/docs/ccp/{scrnCd}`. basename `/haccp/`. `/screen/` 없음.

정본 이야기: `docs/15` DocForm 절. 태그: `docs/23` HF81·HF85·HF95 / HB63–HB70·HB88–HB90.

폴더 규약 장문은 [`pages/sys/README.md`](../../sys/README.md) §0.

## 화면 (이 폴더에 Page가 있음)

| scrnCd | Page | API | Controller | 주요 SP | persistId |
|--------|------|-----|------------|---------|-----------|
| `ccp-cold-monitor` | `ColdMonitorPage.tsx` | `api/ccpColdApi.ts` | `CcpColdController` `/api/v1/docs/ccp/ccp-cold-monitor` | `sp_tbl_ccp_cold_monitor_*` · `sp_tbl_storage_r_000` · `sp_tbl_ccp_limit_r_000` | `ccp-cold-doc-list` |
| `ccp-metal-monitor` | `MetalMonitorPage.tsx` → `CcpFormPage` form=`metal-monitor` | `api/ccpFormsApi.ts` | `CcpFormsController` `/api/v1/docs/ccp/ccp-metal-monitor` | `sp_tbl_ccp_metal_monitor_*` · `sp_tbl_ccp_form_*` | `ccp-form-list-metal-monitor` |
| `ccp-verification-check` | `VerificationCheckPage.tsx` → `CcpFormPage` form=`verification-check` | 위와 같음 | `/api/v1/docs/ccp/ccp-verification-check` | `sp_tbl_ccp_form_*` | `ccp-form-list-verification-check` |
| `ccp-heat-monitor` | `CcpGenericMonitorPage` tmpl `html_sys_003` | `api/ccpGenericApi.ts` | `CcpGenericController` `/api/v1/docs/ccp/ccp-heat-monitor` | `sp_tbl_ccp_generic_monitor_*` | `ccp-generic-doc-list-ccp-heat-monitor` |
| `ccp-sanitize-monitor` | 동일 tmpl `html_sys_004` | 위와 같음 | 위와 같음 | 위와 같음 | `ccp-generic-doc-list-ccp-sanitize-monitor` |
| `ccp-filter-monitor` | 동일 tmpl `html_sys_005` | 위와 같음 | 위와 같음 | 위와 같음 | `ccp-generic-doc-list-ccp-filter-monitor` |

XML `resources/mapper/docs/ccp/`. 패키지 `com.haccp.docs.ccp`.

테이블: 냉장 `tbl_ccp_cold_monitor*` · 금속/양식 `tbl_document` + 금속 전용 행 · 한계 `tbl_ccp_limit` · 보관고 `tbl_storage`.

## 공통

DocForm 세션 · `usePageCommands` · 삭제 POST validate-delete → delete. `co_cd` 본문 금지.

양식 **관리** 화면(`ccp-htg-template` 등)은 이 폴더가 아니라 [`pages/docs/html/`](../html/README.md).

BE 포인터: `com.haccp.docs.ccp/README.md`.
