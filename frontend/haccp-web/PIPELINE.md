# 프론트 파이프라인 — 시동부터 로그인까지

> 개발자: 박승우 · 일자: 2026-08-26
> 대상: `frontend/haccp-web` (React 18 · Vite 5 · TypeScript · Tailwind 3.4 · Zustand · React Query)
> 백엔드 쪽은 [`backend/haccp-api/PIPELINE.md`](../../backend/haccp-api/PIPELINE.md)

이 문서는 **실제로 흐르는 순서**를 파일명까지 적는다.
새로 온 사람이 「주소창에 치면 무엇이 어떤 순서로 도는가」를 코드 열지 않고 알 수 있게 한다.

---

## 1단계 — 브라우저 시동

| # | 파일 | 하는 일 |
|---|---|---|
| 1-1 | `index.html` | `<div id="root">` + `<script type="module" src="/src/main.tsx">` |
| 1-2 | `vite.config.ts` | `base` = `/haccp/` (운영). 자산 URL·라우터 basename 이 여기서 갈린다 |
| 1-3 | `.env` | `VITE_API_BASE_URL` (기본 `http://localhost:7070`). **git 금지** |
| 1-4 | `src/main.tsx` | React Query · BrowserRouter · 전역 CSS 를 깔고 `#root` 에 붙인다 |
| 1-5 | `src/styles/global.css` | Tailwind + `mes-*` 그리드·셀 클래스. 화면 공통 뼈대 |

### 1-n. main.tsx 가 딱 한 번 등록하는 것

| # | 파일 | 왜 여기서 |
|---|---|---|
| 1-6 | `shell/authSession.ts` `registerQueryCacheClear` | 세션이 끊길 때 **이전 사용자 조회 결과**가 남지 않게 캐시 비우는 방법을 알려 둔다 |
| 1-7 | `shell/authCrossTab.ts` `subscribeAuthCrossTab` | 다른 탭에서 로그아웃하면 이 탭도 내려간다 |
| 1-8 | React Query 기본값 | `refetchOnWindowFocus: false` — **기록 입력 중 창을 다시 눌렀다고 값이 튀면 안 된다** |

---

## 2단계 — 주소로 갈라진다

| # | 파일 | 하는 일 |
|---|---|---|
| 2-1 | `src/routes/AppRoutes.tsx` | `/login` → `LoginPage` · `/*` → `Protected(HaccpShell)` |
| 2-2 | `AppRoutes.Protected` | `useAuthStore.token` 이 없으면 `<Navigate to="/login" state={{from}}>` |
| 2-3 | `src/stores/authStore.ts` | Zustand + `persist`. **자동 로그인 여부에 따라 localStorage / sessionStorage 를 갈아 끼운다** |
| 2-4 | `shell/authPaths.ts` | basename(`/haccp/`)을 붙였다 뗐다 하는 자리. 라우터 pathname 에는 `/haccp` 를 다시 넣지 않는다 |

> 화면마다 `<Route>` 가 **없다.** 라우트는 `/login` 과 `/*` 둘뿐이고,
> 화면 식별자는 `scrnCd` 다. 어떤 화면인지는 3-6 의 `parseRoute` 가 정한다.

---

## 3단계 — 로그인

| # | 파일 | 하는 일 |
|---|---|---|
| 3-1 | `pages/auth/LoginPage.tsx` | 좌측 브랜드 배경 + 우측 폼. 이미 유효한 토큰이 있으면 홈으로 보낸다 |
| 3-2 | `shell/loginPrefs.ts` | 아이디 기억·자동 로그인 체크 상태 |
| 3-3 | `api/authApi.ts` `login()` | `POST /api/v1/auth/login` |
| 3-4 | `api/http.ts` | Axios 3계층(`http`·`httpBatch`·`httpFile`). 요청 인터셉터가 `Authorization: Bearer` 를 붙인다 |
| 3-5 | `stores/authStore.setAuth` | **저장소를 먼저 확정하고**(자동 로그인 → localStorage) 토큰·사용자·화면권한을 담는다 |
| 3-6 | `AppRoutes` 재렌더 → `shell/HaccpShell.tsx` | 셸 진입 |

> 순서가 중요하다. `setAuth` 전에 저장소를 정하지 않으면 자동 로그인이 안 걸린다.

### 3-n. 실패·만료 경로

| # | 파일 | 하는 일 |
|---|---|---|
| 3-7 | `api/http.ts` 응답 인터셉터 | 401 → `UnauthorizedError` → `handleUnauthorized()` |
| 3-8 | `shell/authSession.ts` | 토큰 지우고 캐시 비우고 `/login` 으로 |
| 3-9 | `shell/errors.ts` `mesError` | 그 밖의 오류는 **서버가 준 업무 문구를 그대로** 띄운다 |

---

## 4단계 — 셸이 화면을 연다

| # | 파일 | 하는 일 |
|---|---|---|
| 4-1 | `shell/HaccpShell.tsx` | 좌측 메뉴 + 탭 + 본문 |
| 4-2 | `shell/tabRoute.ts` `parseRoute` | pathname → `scrnCd`. 정본 표 `SCREEN_PATH`(28화면) |
| 4-3 | `shell/screenRegistry.tsx` `SCREEN_REGISTRY` | `scrnCd` → 컴포넌트. **탭은 keep-alive** — 닫기 전까지 언마운트하지 않는다 |
| 4-4 | `api/menuApi.ts` `GET /api/v1/menu/list` | 좌측 메뉴 트리 (업체별 `tbl_menu`) |
| 4-5 | `hooks/useCommonCodes.ts` `GET /api/v1/code` | 콤보용 공통코드. 화면이 필요할 때 캐시에서 꺼낸다 |
| 4-6 | `api/prefApi.ts` `GET /api/v1/pref/grid/list` | 사용자별 그리드 열 너비·표시여부 (`persistId` 기준) |
| 4-7 | `api/viewLogApi.ts` `POST /api/v1/log/view/collect` | 화면 체류 로그. **이동 시 모아 보낸다** |

> 탭을 닫으면 Zustand `afterRemove` 로 배열을 한 번만 갱신한다.
> 활성 탭이 지워지면 **오른쪽 → 왼쪽 → 홈** 순으로 옮긴다.

---

## 5단계 — 화면 한 장의 구조

28화면이 같은 뼈대를 쓴다. 화면 폴더에는 보통 세 파일이 있다.

| 파일 | 맡는 것 |
|---|---|
| `XxxPage.tsx` | 배치·상태·버튼 배선 |
| `XxxRule.ts` | 열 정의·잠금 규칙·필수값 — **업무 판단이 여기 모인다** |
| `README.md` | 이 화면이 무엇을 맡고 무엇을 안 맡는지 |

### 5-n. 공통으로 내려간 것

| 파일 | 왜 공통인가 |
|---|---|
| `components/grid/MesEditableGrid.tsx` | 편집 그리드. 셀을 누르면 그 자리에 input 을 덮는다 |
| `components/grid/MesDataGrid.tsx` | 조회 전용 그리드 |
| `shell/gridRules/gridSave.ts` `runGridSave` | 저장 절차 — 권한 → 변경분 → 잠금 → 필수값 → 확인창 → 저장 → 재조회. **6화면이 25줄씩 복제하던 것** |
| `shell/gridRules/gridSave.ts` `stripRowMeta` | 저장 payload 에서 `_key`·`_rowState`·`_original` 제거 |
| `shell/gridRules/pageGuard.ts` | 잠긴 칸·업무키 검사 |
| `shell/dialog.tsx` | `mesToast`·`mesConfirm`. **저장·삭제·전송은 전부 확인창을 거친다** |
| `shell/messages.ts` `MES` | 사용자 문구 정본. 화면마다 다른 말을 쓰지 않는다 |
| `hooks/useEditableRows.ts` | 행 추가·변경 추적. 신규행 키에 `__new_` 를 붙인다 |
| `hooks/useDocFormSession.ts` | 좌측 목록 + 우측 지면을 함께 들고 있는 작성 화면용 |
| `pages/draft/htmlFormDraftShared.ts` | 작성 6화면의 상태 배지·전송 가능 판정·필수값 |

---

## 6단계 — 작성 화면의 저장 흐름 (가장 자주 건드리는 길)

| # | 어디 | 하는 일 |
|---|---|---|
| 6-1 | 좌측 `행추가` | `useEditableRows.addRow` — `__new_*` 키로 빈 행 |
| 6-2 | 양식코드 셀 버튼 | 양식 선택 팝업. **손으로 못 친다** |
| 6-3 | 좌측 `저장` | `PUT /draft/{중}/{화면}/save` → `docIdx` 생성. **여기까지 해야 우측 지면이 편집 가능** |
| 6-4 | 우측 지면 입력 | `HtmlFormDraftPage` 버퍼에 담긴다 (아직 서버로 안 간다) |
| 6-5 | `작성 후 저장` | 같은 `/save` 에 `items`·`logRows`·`passRows` 를 실어 보낸다 |
| 6-6 | `전송` | `validateForTransfer` 로 필수값 확인 → 확인창 → `PUT /docs/documents/approval` `actionCd:REQUEST` |
| 6-7 | 상태 | `WRK` 전송대기 → `REQ` 승인요청 → `APV` 승인완료 (반려는 `RJT`) |

> 목록 배지는 **3단계**(전송대기·전송·결재완료)다. 반려(`RJT`)도 전송대기로 묶여 보인다 —
> 작성자가 다시 고칠 수 있는 상태라서다.

---

## 7단계 — 검증

```sh
cd frontend/haccp-web
npx tsc --noEmit          # 타입
npx eslint src e2e        # 규칙
npx vitest run            # 단위 130건
npm run build             # 번들
npx playwright test       # E2E 105건 — 화면·API·SP·DB 를 한 줄로 꿴다
```

E2E 는 화면 문구가 아니라 **DB 를 직접 읽어** 판정한다.
「저장했습니다」를 띄우고 서버가 실패를 삼킨 사고가 실제로 있었다(E2E-001).

---

## 관련

- 규칙: `.cursor/rules/09-frontend-conventions.mdc` · `02-frontend-ui.mdc` · `01-project-core.mdc`
- 태그 색인: `docs/23_PIPELINE.md` (`PIPELINE[HF*]` → 파일)
- 경로 정본: `docs/24_URL_DB_폴더_패키지_정본.md` · `shell/tabRoute.ts`
- E2E: `e2e/README.md` · 결과 `E2E.md` · `E2E_ERRORS.md`

## 변경

- 2026-08-26 — 신설. 시동→라우팅→로그인→셸→화면 순서를 파일명까지 적었다.
  시스템 6화면의 저장 절차를 `runGridSave` 한곳으로 모았다.
