# prp 파이프라인 (FE + BE + DB)

PRP 위생·설비·이력. 폴더는 URL 중칸 `pages/docs/prp/`.

로컬 UI `http://localhost:4173` · API `http://localhost:7070`  
라우트: `routeOf(scrnCd)` → `/docs/prp/{scrnCd}`. basename `/haccp/`. `/screen/` 없음.

| scrnCd | Page | API | Controller | persistId |
|--------|------|-----|------------|-----------|
| `facility-equipment-check` | `BizOpsFormPage` | `api/bizOpsApi.ts` | `/api/v1/docs/prp/facility-equipment-check` | `ops-doc-list-facility-equipment-check` |
| `calibration-target-management` | 동일 Page | 위와 같음 | `/api/v1/docs/prp/calibration-target-management` | `ops-doc-list-calibration-target-management` |
| `daily-hygiene-check` · `pest-control-check` | `HygieneCheckPage` | `api/hygieneApi.ts` | `/api/v1/docs/prp/{scrnCd}` | 화면 Rule |
| `health-cert-record` | `HealthCertPage` | `api/healthCertApi.ts` | `/api/v1/docs/prp/health-cert-record` | 화면 Rule |
| `equipment-history` | `EquipmentHistoryPage` | `api/equipmentHistApi.ts` | `/api/v1/docs/prp/equipment-history` | `bas-equipment-history-master` · `-detail` |
| `pest-device-history` | `PestDeviceHistoryPage` | `api/pestDeviceHistApi.ts` | `/api/v1/docs/prp/pest-device-history` | `bas-pest-device-history-master` · `-detail` |

`calibration-target-management` 는 메뉴 SQL `use_yn='N'` 로 숨긴다. Page·API는 유지하고 `SCREEN_REGISTRY`·`SCREEN_PATH`(`/docs/prp/...`)만 연결한다. 문서함 `html_sys_010` deep-link 전용. 메뉴 재노출·`git rm` 금지.

폐기·재고·입고 등은 HWP leaf (`pages/docs/{중}/{scrnCd}/` → `HwpDocumentEditorPage`).

XML `mapper/docs/prp/`. 패키지 `com.haccp.docs.prp`. SP는 각 Mapper의 `sp_tbl_*`.
