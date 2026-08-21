# haccp-web — Agent Instructions

> 정본: `7_에이전트_가이드_FE.md`  
> 작성일: 2026-08-10 · 개발자: 박승우  
> 상속: 루트 `README.md` · `.cursor/rules/00-bootstrap` → `09-haccp-frontend` · `02-frontend-ui` · `05-handoff` · `06-operations`  
> BE: [`8_에이전트_가이드_BE.md`](8_에이전트_가이드_BE.md)

---

## 1. 스택 (고정)

| 항목 | 버전/값 |
|------|---------|
| React | **18.3.1** |
| Vite | **5.4.8** |
| TypeScript | ^5.6 |
| Tailwind | **3.4** (v4 마이그레이션 없음) |
| Zustand | ^5 |
| TanStack Query | ^5.59 — 메뉴·공통코드 등 |
| TanStack Table / Virtual | ^8 / ^3 — `useMesTable` |
| Axios | ^1.7 |
| @rhwp/editor | ^0.8 |
| Node | >=20 (`.nvmrc`) · npm >=10 |
| API | `VITE_API_BASE_URL` → **7070** |

---

## 2. 작업 전 읽을 문서 순서

1. 루트 README E2E · `docs/23` 태그 · `docs/15` 이야기  
2. `01` 운영 · `02` 작성규칙 · `04` 인증  
3. 해당 도메인 README · 파일 찾는 법 `10`(17) · 파일/보안 `11`(18)  
4. 코드 골드: `ColdMonitorPage` · `HaccpShell` · `LoginPage`

---

## 3. 필수 패턴

| 할 일 | 패턴 |
|-------|------|
| 새 화면 | `pages/{영역}/{메뉴}/` Page+Rule+README + `SCREEN_REGISTRY` + `api/{영역}/` + BE + 메뉴/SP |
| 손대는 메뉴 | 아직 평탄하면 **그 작업에서** sys와 같이 분할. 미리 전 메뉴를 나누지 않는다. `scrnCd`·`persistId`·기존 URL은 유지 |
| DB형 문서 | `useDocFormSession` + DocForm* — 복붙 Page 금지 |
| HWP | `hwpLeaf`만 — 양식별 Page 금지 |
| 그리드 CRUD | `useEditableRows` · `useGridAccess` · `GridCrudButtons` · `useAsyncAction` |
| 삭제 | `resolveRowsForDelete` → validate → `mesConfirm` → delete |
| 권한 | `authStore.can(scrnCd, "read"|"write"|"modify"|"delete"|"print")` |
| 상단 버튼 | `usePageCommands` |
| 오류 | `mesError` · `mesToast` · `MES` |
| 숫자 | `envConfig` only |
| 주석 | `05-handoff-comments` 밀도 |

---

## 4. UI

1. `tailwind.config` 토큰  
2. `pageClasses.ts`  
3. `Input` / `MesButton` (`buttonVariants` — download=indigo)  
4. `styles/global.css` `.mes-*`  
5. 페이지는 짧은 class 조합만  

터치/키오스크 셸 **없음** (`HaccpShell` 단일).

---

## 5. 실행

```bash
cd frontend/haccp-web
nvm use   # 또는 Node 20+
npm ci
npm run dev   # 4173
```

상세: 루트 [`README.md`](../README.md). DB는 프론트가 직접 치지 않음.

---

## 6. 신규 화면 체크리스트

FE 경로에 Vite basename `/haccp/` 를 **넣지 않는다.** `SCREEN_PATH` 는 `paths("/docs/html", …)` · `paths("/sys/code", …)` 처럼 pathname만.

1. `pages/{영역}/{메뉴}/` Page + Rule + 도메인 README  
2. `SCREEN_REGISTRY` 등록  
3. `tabRoute.ts` `SCREEN_PATH` — `/haccp` 접두 금지. `/screen/{scrnCd}` 도 없음  
4. `api/{영역}/` + BE Controller/Service/Mapper/SP  
5. 메뉴·화면 SQL (`tbl_menu` · `tbl_screen`) — 숨김 화면은 `use_yn='N'` 이어도 레지스트리·경로는 연결할 수 있다  
6. `docs/23_PIPELINE.md` 태그 (재채번 금지)

골드: `ColdMonitorPage` · `HaccpShell` · `routeOf`/`parseRoute`.

---

## 7. 하지 말 것

- mes-web 포트를 가정하거나 `mes-auth` 키 사용  
- HTTP DELETE  
- body로 `coCd` 전송  
- 이모지 · 매직 타임아웃 · 제거된 ccpMetalApi / ccpVerificationApi 재생성 (ccpFormsApi 사용)  
- 요청 없는 대규모 리팩터·테스트 프레임워크 추가  
- 사용자 요청 없는 git commit/push  

---

*에이전트 실행 가이드. 상세 계약은 01·02·04·11.*
