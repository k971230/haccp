# ops 파이프라인 (FE + BE + DB)

시설·검교정 HTML 작성. **평탄.** 폐기·재고·입고·공정은 HWP leaf (`pages/docs/hwpeditor`).

| scrnCd | Page | API | Controller | persistId |
|--------|------|-----|------------|-----------|
| `facility-equipment-check` | `BizOpsFormPage` | `api/bizOpsApi.ts` | `/api/v1/fac/facility-equipment-check` | `ops-doc-list-facility-equipment-check` |
| `calibration-target-management` | 동일 Page | 위와 같음 | `/api/v1/fac/calibration-target-management` | `ops-doc-list-calibration-target-management` |

`calibration-target-management` 는 메뉴 SQL `use_yn='N'` 로 숨긴다. Page·API는 유지하고 `SCREEN_REGISTRY`·`SCREEN_PATH`(`/docs/prp/...`)만 연결한다. 문서함 `html_sys_010` deep-link 전용. 메뉴 재노출·`git rm` 금지.

XML `mapper/ops/`. 패키지 `com.haccp.ops`. SP는 `BizOpsMapper.xml`의 `sp_tbl_*`.
