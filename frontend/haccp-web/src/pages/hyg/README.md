# hyg 파이프라인 (FE + BE + DB)

위생 작성 화면. **평탄 폴더.** 손댈 때 sys처럼 나눈다.

라우트: `routeOf(scrnCd)` → `/docs/prp/{scrnCd}`. `/screen/` 없음.

| scrnCd | Page | API | Controller | 주요 SP | persistId |
|--------|------|-----|------------|---------|-----------|
| `daily-hygiene-check` | `HygieneCheckPage` kind=`daily` | `api/hygieneApi.ts` | `HygieneController` `/api/v1/hyg` | `sp_tbl_hygiene_document_*` | `hyg-doc-list-daily-hygiene-check` |
| `pest-control-check` | `HygieneCheckPage` kind=`pest` | 위와 같음 | 위와 같음 | 위와 같음 | `hyg-doc-list-pest-control-check` |
| `health-cert-record` | `HealthCertPage.tsx` | `api/healthCertApi.ts` | `HealthCertController` `/api/v1/hyg/health-cert` | `sp_tbl_health_cert_*` | `hyg-health-cert-record` |

XML `mapper/hyg/`. 패키지 `com.haccp.hyg` (평탄).

공정점검 **작성** `hygiene-process-check` 는 [`pages/docs/html/hygprocess/`](../docs/html/hygprocess/README.md).
