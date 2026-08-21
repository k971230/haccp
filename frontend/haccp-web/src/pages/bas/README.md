# bas 파이프라인 (FE + BE + DB)

기초정보 마스터. 폴더 `pages/bas/master/`. 경로 정본 `docs/24_URL_DB_폴더_패키지_정본.md`.

마스터 URL은 `/bas/master/{scrnCd}`. `/screen/` 없음.

| scrnCd | Page | API | Controller | persistId |
|--------|------|-----|------------|-----------|
| `product-management` 등 7종 | `master/MasterDataPage` + rules | `api/masterApi.ts` | `MasterController` `/api/v1/bas/{type}` | `bas-{screenCode}` |

설비·방충 이력 화면은 `pages/docs/prp/`. API는 `/api/v1/docs/prp/equipment-history` · `/api/v1/docs/prp/pest-device-history`.

결재선 화면은 [`pages/sys/code/approvalline/`](../sys/code/approvalline/README.md). HTTP `/api/v1/sys/code/approval-line-management`.

XML `mapper/bas/master/`. 패키지 `com.haccp.bas.master`.
