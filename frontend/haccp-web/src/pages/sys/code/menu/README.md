# 메뉴 관리 (`menu-management`)

정본 파이프라인 요약은 상위 [`pages/sys/README.md`](../../README.md) 2장.

## 파일

| 파일 | 책임 |
|---|---|
| `MenuManagementPage.tsx` | 렌더·상태·API 호출·트리 렌더. 좌 트리 + 우 편집 그리드 |
| `MenuManagementRule.ts` | `SCRN_CD` · `PERSIST_ID` · `TREE_ALL` · 컬럼 팩터리 · `MENU_RULES` · `matchMenu` · `sortByMenuOrder` · `enrichMenuLevels` · `buildMenuTree` |

## 화면 규칙

- **행추가 불가.** 메뉴코드·상위메뉴·화면코드·정렬은 시드·migrate로만 만든다 (`MENU_RULES.alwaysReadonly`)
- 수정 가능한 항목은 메뉴명·사용여부 둘뿐이다
- 대·중·소(`grpANm`/`grpBNm`/`grpCNm`)는 트리에서 산출한 표시열이며 저장 payload에서 제거한다
- 좌측 노드를 고르면 **직속 하위만** 그리드에 남는다. 「전체」는 검색조건만 적용한 전건
- 표시 순서는 `sort_no`(대중소 인코딩) → 메뉴코드

## API · SP · 테이블

| 동작 | API (`api/sys/menuApi.ts`) | SP | 테이블 |
|---|---|---|---|
| 조회 | `listAdminMenus` | `sp_menu_management_r_000` | `tbl_menu` `tbl_screen` |
| 저장 | `saveMenus` | `sp_menu_management_c_000` | `tbl_menu` |
| 삭제 검증 | `validateDeleteMenus` | `sp_menu_management_delete_blocker_r_000` | `tbl_menu` `tbl_role_screen` |
| 삭제 | `deleteMenus` | `sp_menu_management_d_000` | `tbl_menu` `tbl_role_screen` |

`listAdminMenus`는 권한 관리·감사 이력·화면 이용 통계의 좌측 트리 원본으로도 쓰인다.

## 사이드바와의 차이

사이드바 메뉴는 이 화면과 **다른 SP**(`sp_menu_nav_r_000`)를 쓴다. 권한 필터가 걸린 트리이며 호출 경로는 `api/menuApi.ts` → `mapper/menu/MenuMapper.xml`이다. 둘을 한 SP로 합치지 않는다.

## pref 키

`scrnCd = menu-management` · `persistId = menu-mgmt-master` — 값 변경 금지.
