# bas 파이프라인 (FE + BE + DB)

기준정보·이력. **평탄 폴더.** 손댈 때 sys처럼 나눈다.

마스터 URL은 `tabRoute`의 기초정보 접두 (`/bas/...` 등). `/screen/` 없음.

| scrnCd | Page | API | Controller | persistId |
|--------|------|-----|------------|-----------|
| `product-management` 등 7종 | `MasterDataPage` + `MasterDataPage.rules.ts` | `api/masterApi.ts` | `MasterController` `/api/v1/bas` | `bas-{screenCode}` |
| `equipment-history` | `EquipmentHistoryPage.tsx` | `api/equipmentHistApi.ts` | `EquipmentHistController` `/api/v1/bas/equipment-hist` | `bas-equipment-history-master` · `-detail` |
| `pest-device-history` | `PestDeviceHistoryPage.tsx` | `api/pestDeviceHistApi.ts` | `PestDeviceHistController` `/api/v1/bas/pest-device-hist` | `bas-pest-device-history-master` · `-detail` |

XML `mapper/bas/`. 패키지 `com.haccp.bas` (평탄). SP `sp_tbl_*` (마스터 타입별).

결재선 HTTP는 `/api/v1/bas/approval-lines` 이지만 화면 폴더는 [`pages/sys/approvalline/`](../sys/approvalline/README.md).
