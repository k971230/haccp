# shell — 앱 셸 진입

정본 이야기: [`docs/11_메인_셸.md`](../../../../docs/11_메인_셸.md). 태그 HF49 대역 [`docs/23_PIPELINE.md`](../../../../docs/23_PIPELINE.md).

화면마다 `<Route>`가 없다. `AppRoutes`는 `/login`과 `/*`(HaccpShell)만.

| 파일 | 역할 |
|------|------|
| `HaccpShell.tsx` | 사이드·탭·본문·상단 명령. 탭 닫힌 뒤 `routeOf` 또는 `/` |
| `mesSec.ts` | 그리드·트리 클릭 시 헤더(메뉴명) 초록. 화면별 bind 없음 |
| `ShellTabBar.tsx` | 열린 탭. Portal 우클릭 메뉴 |
| `tabRoute.ts` | `scrnCd` ↔ 계층 pathname. basename은 Vite |
| `screenRegistry.tsx` | `scrnCd` → Page |
| `SideMenu.tsx` | `menuApi` 2단 트리 |
| `tabStore` | `stores/tabStore.ts` — 닫기 `afterRemove` |

`gridRules/` — 그리드 잠금·저장 가드. MES `PIPELINE[Fn]` 잔존. 새 파일에 F 접두 금지.
