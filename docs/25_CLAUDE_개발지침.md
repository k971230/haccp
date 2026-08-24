# 25 — Claude 개발 지침 (신규 화면·기능 작업 기준서)

개발자: 박승우
일자: 2026-08-24

이 문서는 신규 화면·기능을 개발할 때 **가장 먼저 읽는 실무 기준서**다.
`.cursor/rules/*.mdc` 와 충돌하는 내용이 있으면 **언제나 `.cursor` 규칙이 우선**한다.
이 문서는 `.cursor` 규칙과 `docs/1_`~`24_` 정본을 화면 개발 순서로 재배열한 요약이며, 본문을 복제하지 않고 링크로 넘긴다.

---

## 1. 프로젝트 구조

| 영역 | 경로 | 스택 |
|------|------|------|
| 프론트 | `frontend/haccp-web/` | React 18 · Vite 5(4173) · TypeScript · Tailwind 3.4 · Zustand · React Query |
| 백엔드 | `backend/haccp-api/` | Spring Boot 3.3.4 · Java 17 · MyBatis 3.0.3 · JWT · 포트 7070 |
| DB | `db_sasshaccp/` | PostgreSQL, DB·스키마 `sasshaccp` |
| 문서 | `docs/` | `docs/N_*.md` 정본 + 폴더별 `README.md` |
| 규칙 | `.cursor/rules/` | 에이전트 규칙 (최우선) |

### 프론트 디렉터리

| 경로 | 역할 |
|------|------|
| `src/api/{대}/` | 도메인 API 함수 — `http.ts` 3계층 Axios |
| `src/shell/` | `HaccpShell` · `SideMenu` · `screenRegistry` · `tabRoute` · `pageCommands` · `dialog` · `errors` · `messages` · `gridRules` |
| `src/pages/{대}/{중}/[{메뉴}/]` | 화면 — URL `SCREEN_PATH` 칸과 동일 |
| `src/components/{ui,grid,layout,form,document,common}/` | 공용 UI |
| `src/hooks` · `stores` · `types` · `lib` · `config` · `styles` | 공통 |

### 백엔드 패키지

```
com.haccp.{대}.{중}[.{메뉴}]                 Controller · Service · Mapper
resources/mapper/{대}/{중}[/{메뉴}]/*.xml    namespace = 인터페이스 FQCN
```

셸 전용: `auth` `menu` `code` `pref` `log` `common`.
공유 허브(화면 경로와 별개): `docs.document` · `docs.template` · `workflow`.

---

## 2. URL = DB = 폴더 = 패키지 (절대 규칙)

정본: [`24_URL_DB_폴더_패키지_정본.md`](24_URL_DB_폴더_패키지_정본.md)

```
URL   /haccp + /{대}/{중}/{scrnCd}
API   /api/v1 + /{대}/{중}/{scrnCd} + /{동작}
DB    tbl_menu  대 menu_cd={대} → 중 menu_cd={중} → 소 menu_cd = scrn_cd
FE    src/pages/{대}/{중}/
BE    com.haccp.{대}.{중} · resources/mapper/{대}/{중}/
```

- 한글 메뉴명을 URL에 넣지 않는다.
- `scrnCd` · `persistId` 는 폴더를 옮겨도 **바꾸지 않는다**.
- `tbl_menu` 는 `UNIQUE (co_cd, menu_cd)` 다. **중분류 슬러그는 전 트리에서 유일**해야 하므로 이미 쓰는 중분류명(`html` · `ccp` · `code` 등)을 다른 대분류 아래에 다시 만들 수 없다.
- 라우터 basename 은 `/haccp/`. 라우터 pathname·API 경로에 `/haccp` 를 다시 넣지 않는다.

---

## 3. 화면 개발 규칙

### 3.1 파일 구성 (sys 골드)

```
pages/{대}/{중}/{메뉴}/
  {Name}Page.tsx    렌더·상태·API 호출·핸들러만
  {Name}Rule.ts     SCRN_CD · PERSIST_ID · SPLIT_KEY · 컬럼 팩터리 · 잠금 규칙 · 순수 변환 (JSX/API 없음)
  README.md         화면 한 장 설명 + scrnCd · API · 테이블
```

중 아래 화면이 하나면 `{메뉴}` 단을 생략한다. **이번에 손대는 메뉴만** URL 칸으로 옮기고, 미리 전 메뉴를 나누지 않는다.

### 3.2 화면 등록 3종 세트

1. `shell/tabRoute.ts` `SCREEN_PATH` 에 `paths("/{대}/{중}", ["{scrnCd}"])` 한 줄
2. `shell/screenRegistry.tsx` 에 `"{scrnCd}": {Name}Page` — 키는 `scrn_cd` 와 문자 그대로 동일
3. DB `tbl_screen` · `tbl_role_screen` · `tbl_menu` 시드 (아래 8장)

라우트는 레지스트리 기반이라 `AppRoutes.tsx` 는 건드리지 않는다. `/screen/{scrnCd}` 형태는 쓰지 않는다.

### 3.3 레이아웃 선택

| 형태 | 프레임 | 참고 화면 |
|------|--------|-----------|
| 검색 + 단일/좌우 그리드 | `pageRootClass` + `PageCard` + `SearchArea` + `ResizableSplit` | `pages/docs/html/HtmlFormTemplatePage.tsx` |
| 문서 작성(좌 목록 + 우 지면) | `DocFormLayout` + `DocFormSearchToolbar` + `DocFormBody` / `DocFormDocumentList` / `DocFormMainPanel` | `pages/docs/html/hygprocess/HygProcessPage.tsx` |
| CRUD 표준 | 동일 | `pages/docs/ccp/ColdMonitorPage.tsx` (골드) |
| 로그 3화면 | `LogPageShell` | `pages/sys/logs/*` |

---

## 4. 컴포넌트 사용 규칙

**새로 만들기 전에 반드시 기존 것을 찾는다.** 아래는 실제로 쓰는 공용 컴포넌트다.

| 용도 | 컴포넌트 |
|------|----------|
| 페이지 외곽 | `PageCard` · `pageRootClass` · `splitPanelClass` · `gridHeadClass` (`components/layout/pageClasses.ts`) |
| 검색 | `SearchArea` · `SearchField` · `SearchSelect` · `SearchButton` |
| 좌우 분할 | `ResizableSplit` (`storageKey` = `SPLIT_KEY`) |
| 그리드 | `MesEditableGrid`(편집) · `MesDataGrid`(조회) · `GridCrudButtons` |
| 버튼·입력 | `MesButton` · `Input` · `searchInputClass` · `gridInputClass` |
| 문서 작성 | `DocFormLayout` 계열 · `DocFormSearchToolbar` · `DocPaper` · `DocCell` · `DocDeviationFooter` |
| 결재 툴바 | `DocumentApprovalToolbar` (상신·상신취소·검토·승인·반려 내장) |
| HTML 지면 | `components/form/htmlFormPaperShared.tsx` + 화면별 `*Paper.tsx` |
| 배지 | `SysYnBadge` · `GridColumn.badge` |
| 셀 안 버튼 | `GridColumn.cellButton` (팝업·이동 트리거) |

금지: 페이지 TSX 에 긴 Tailwind 복붙, arbitrary 값 남발, Tailwind v4 문법(`@theme` · `@utility` · `bg-linear-to-r`).

---

## 5. 공통 함수·훅 사용 규칙

| 용도 | 함수/훅 |
|------|---------|
| 비동기 중복 클릭 차단·busy | `useAsyncAction()` — `run(fn, "search"\|"add"\|"save"\|"del")` |
| 문서 좌측 목록 + 다건 버퍼 + 일괄 저장 | `useDocFormSession<Buf, ListMeta>()` |
| 그리드 잠금·권한 | `useGridAccess(rules, ctx)` → `access` · `onLockedAttempt` |
| 공통코드 | `useCommonCodes(mainCd)` — `codes` · `codeMap` · `label()` |
| 셸 상단 툴바 연결 | `usePageCommands({ search, add, save, del, print, transfer })` |
| 미저장 이탈 경고 | `useRegisterPageDirty` |
| 딥링크 `?docIdx=` | `useDocIdxQuery()` |
| 확인·토스트 | `mesConfirm` · `mesConfirmDanger` · `mesToast` |
| 오류 문구 | `mesError(e)` (`stripDbTechnicalMessage`) |
| 문구 카탈로그 | `MES.*` (`shell/messages.ts`) |
| 날짜 | `todayYmd` · `toInputDate` · `fromInputDate` (`lib/docDateTime.ts`) |
| Y/N | `toYn` · `ynOptions` · `DEFAULT_USE_YN` (`lib/yn.ts`) |
| snake→camel | `camelizeRow` · `camelizeRows` (`lib/camelKeys.ts`) |
| 문서 → 작성 화면 경로 | `routeForDocument` (`lib/documentNav.ts`) |
| 화면 경로·API 베이스 | `routeOf(scrnCd, query)` · `apiOf(scrnCd, action)` (`shell/tabRoute.ts`) |

---

## 6. API 호출 규칙

### 6.1 경로

| 유형 | 패턴 |
|------|------|
| 목록 | `GET /api/v1/{대}/{중}/{scrnCd}/list` |
| 상세 | `GET .../detail?docIdx=` |
| 저장 | `PUT .../save` |
| 삭제 | `POST .../validate-delete` → `POST .../delete` (**객체 배열** Body) |
| 워크플로 | `POST/PUT /{리소스}/{action}` |
| 파일 | `GET .../download` · `POST .../upload` |

- **HTTP DELETE 금지.** 삭제는 POST 2단계.
- FE 는 경로를 하드코딩하지 않고 `apiOf(SCRN_CD, "list")` 로 조립한다.
- 공유 허브 예외(복제 금지): `/api/v1/docs/documents`, `/api/v1/docs/templates/{tmplCd}/form`, `/api/v1/bas/company-templates`, `/api/v1/bas/{type}`, 셸 `/auth` `/menu` `/code` `/pref` `/log`, 서명 `/api/v1/sys/users`.

### 6.2 Axios 3계층 (타임아웃 하드코딩 금지)

| 인스턴스 | env | 기본 | 용도 |
|----------|-----|------|------|
| `http` | `VITE_API_TIMEOUT_DEFAULT` | 10s | 일반 CRUD · validate-delete |
| `httpBatch` | `VITE_API_TIMEOUT_BATCH` | 60s | 대량·집계 |
| `httpFile` | `VITE_API_TIMEOUT_FILE` | 120s | HWPX·PDF |

### 6.3 응답 처리

- 서버는 항상 `CommonResponse<T>` → FE 는 `data.data ?? []` 로 받는다.
- SP Map 행은 snake 가 섞여 오므로 API 파일에서 `as*Row()` / `camelizeRow` 로 **camelCase 정규화 후** 화면에 넘긴다.
- PG CALL 영향 행 수를 건수처럼 반환하지 않는다 — `CommonResponse<Void>` 권장.
- 401 은 인터셉터가 세션 정리 후 `/login`. 화면에서 재처리하지 않는다.

### 6.4 백엔드 레이어

```
Controller(@RestController) → Service(@Service, CUD 는 @Transactional(timeout=60)) → Mapper(@Mapper + XML) → PG SP
```

- DI 는 `@RequiredArgsConstructor` + `private final`.
- `co_cd` · `user_id` 는 **요청 본문으로 받지 않는다** — `LoginUserContext` 만.
- 업무 검증은 Service 에서 `BizException`.
- 삭제는 `validateDelete` · `delete` **양쪽**에서 `assertDeletable` Double Check (`DeleteValidation` · `DeleteBlocker`).

---

## 7. DB 처리 규칙

정본: [`.cursor/rules/07-haccp-db.mdc`](../.cursor/rules/07-haccp-db.mdc)

- PK 는 전 테이블 `idx bigint GENERATED ALWAYS AS IDENTITY`. 업무키는 `ux_{테이블}_{키} UNIQUE (co_cd, ...)`.
- 테넌트 `co_cd varchar(10)` 는 모든 업무 테이블 필수이며 UNIQUE 선두.
- 감사 컬럼 `ins_id` `ins_dt` `upd_id` `upd_dt`.
- SP 명명: 여러 화면이 공유하는 테이블 CRUD 는 `sp_tbl_{테이블}_{r|c|d|u}_{000}`, 화면 전용은 `sp_{화면명}_{r|c|d|u}_{000}`.
- 조회는 `FUNCTION ... RETURNS TABLE`, 쓰기는 `PROCEDURE`. 첫 인자는 **항상 `p_co_cd`**.
- 테넌트 격리는 SP 책임: `WHERE idx = p_idx AND co_cd = p_co_cd`.
- 업무 오류는 `RAISE EXCEPTION '...' USING ERRCODE = '45000'` → `SqlUserMessage` 가 사용자 문구로 변환.
- SP 내부 자율 COMMIT 금지. 트랜잭션 경계는 Spring.
- 재실행 가능: `CREATE OR REPLACE` · `IF NOT EXISTS` · `ON CONFLICT DO UPDATE`.
- 신규 마이그레이션은 **`db_sasshaccp/` 의 다음 번호**로 추가하고 기존 번호를 재사용하지 않는다. Jenkins 는 migrate 를 돌리지 않으므로 운영자가 수동 적용한다.

---

## 8. 메뉴 등록 규칙

신규 화면 1개당 SQL 4블록 (`db_sasshaccp/100_migrate_html_form_hyg_process.sql` 3장이 표준 예시).

```sql
-- 1) 화면 마스터
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, ins_id) VALUES
    ('{scrn-cd}', '{화면명}', '{MODULE}', NULL, {sort}, 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET ...;

-- 2) 권한 — 전 권한그룹 CROSS JOIN. 삭제는 ADMIN 만 Y 가 관례
INSERT INTO tbl_role_screen (co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
SELECT r.co_cd, r.usrgrp_cd, s.scrn_cd, 'Y', 'Y', 'Y',
       CASE WHEN r.usrgrp_cd = 'ADMIN' THEN 'Y' ELSE 'N' END, 'Y', 'system', now()
  FROM tbl_role r CROSS JOIN (VALUES ('{scrn-cd}')) AS s(scrn_cd)
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

-- 3) 분류 메뉴(대·중) — menu_cd = URL 슬러그, scrn_cd = NULL
-- 4) leaf 메뉴 — menu_cd = scrn_cd, h_menu_cd = 중분류 슬러그
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, ...
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c ...
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET ...;
```

- 대상 회사는 항상 `(SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu)` 로 전 테넌트.
- 정렬은 `sp_tbl_menu_sort_encode_u_000(NULL)` 이 대(1~9)\*1000 + 중\*100 + 소 로 재계산한다. **새 대·중 슬러그를 추가하면 이 SP 의 VALUES 목록에도 넣는다.**
- 새 대분류는 FE `lib/icons.tsx` `getModuleIcon` 에도 아이콘 한 줄을 넣는다(없으면 `Folder`).
- 권한은 `tbl_role_screen.scrn_cd` 기준이라 `menu_cd` 개명과 무관하다.

---

## 9. 네이밍 규칙

| 대상 | 규칙 |
|------|------|
| 컴포넌트·페이지 파일 | PascalCase = export 명 |
| 훅 | `use` 접두 |
| Props 타입 | `[ComponentName]Props` — `Props` 단독 금지 |
| export | **default export 금지, named export 만** (구 화면 일부는 default 를 쓰지만 신규는 named) |
| Row / API JSON / DTO | camelCase |
| DB · SQL · SP | lower_snake |
| 편집 메타 | `_rowState` · `_key` · `_original` |
| 상수·화면코드 상수 | `UPPER_SNAKE` (값은 kebab) |
| 코드성 값(`scrn_cd` · `menu_cd` · `tmpl_cd` · 공통코드) | **kebab-case 소문자** — 신규 대문자/SNAKE 금지 |
| 예외 | `cycle_cd` 는 대문자 1자 `D|W|M|Q|H|Y|E` 유지. `DOC_STATUS` · `APPR_ACTION` 등 기존 대문자 공통코드는 그대로 |

---

## 10. 상태 관리 규칙

- 전역: Zustand — `authStore`(토큰·사용자·`can(scrnCd, perm)`) · `modalStore` · `pageCommands` 스토어.
- 서버 캐시: React Query (셸 메뉴·공통코드 등). 업무 화면 목록은 `useAsyncAction` + 명시적 재조회를 쓴다.
- 화면 로컬: `useState` + `useRef`(검색조건 스냅샷) 조합. 문서 작성 화면은 `useDocFormSession` 이 목록·버퍼·activeKey 를 한 세션으로 관리한다.
- 그리드 열 너비·정렬은 `persistId` 로 서버(`/pref`)에 저장된다. `PERSIST_ID` 값을 바꾸면 사용자 설정이 초기화되므로 변경 금지.

### 문서 상태 (`DOC_STATUS`)

| 코드 | 공통코드 문구 | 의미 |
|------|---------------|------|
| `WRK` | 작성중 | 저장만 된 상태. 수정·삭제 가능 |
| `REQ` | 검토요청 | 상신됨. 작성자만 상신취소 가능 |
| `REV` | 검토완료 | 검토 서명 완료. 상신취소 불가 |
| `APV` | 승인완료 | 결재 완료. 수정·삭제 불가 |
| `RJT` | 반려 | 다시 수정·재상신 가능 |
| `TMP` | (폐기) | 구 데이터. `WRK` 와 동일 취급 |

상태 전이는 **오직** `PUT /api/v1/docs/documents/approval` (`processDocumentApproval`) → `sp_tbl_document_approval_c_000` 하나만 쓴다. 화면마다 별도 전이 API 를 만들지 않는다.
FE 는 `DocumentApprovalToolbar` 를 그대로 얹고, 작성 화면은 `writerActionsOnly` 로 상신·상신취소만 노출한다.

---

## 11. 메시지·로딩·예외·권한 처리

- **메시지:** 문구는 `MES.*` 카탈로그. 성공 `mesToast(MES.saveDone, "success")`, 경고 `"warn"`, 확인 `mesConfirm` / 위험 `mesConfirmDanger`.
- **로딩:** `useAsyncAction().run(fn, key)` 의 `isBusy(key)` 를 버튼 `disabled` · `loading` 에 연결. 별도 스피너 컴포넌트를 만들지 않는다.
- **예외:** 화면은 `try { ... } catch (e) { mesError(e) }`. 사용자에겐 업무 문구만, 기술 상세는 서버 로그(`GlobalExceptionHandler`).
- **권한:** `useAuthStore((s) => s.can(SCRN_CD, "read"|"write"|"modify"|"delete"|"print"))`. 그리드 잠금은 `useGridAccess` 로 넘기고 잠금 시도는 토스트로만 안내한다. 레지스트리에 없는 화면을 메뉴에서 숨기지 않는다(비활성 표시).

---

## 12. CSS / 스타일 규칙

정본: [`.cursor/rules/02-frontend-ui.mdc`](../.cursor/rules/02-frontend-ui.mdc)

우선순위: ① `tailwind.config.js` 토큰 → ② TS 상수(`pageClasses.ts` · `Input.tsx` · `buttonVariants.ts`) → ③ `styles/global.css` `@layer components` 의 `.mes-*` → ④ 페이지 TSX 의 짧은 `cn()`.

- 촘촘한 업무 시스템 UI. 포인트 컬러는 남색 + 초록(`brand-*` · `sidebar-*`).
- **이모지 금지** — 아이콘은 Lucide React 또는 `.mes-*`.
- 인라인 `style` 은 동적 값(그리드 컬럼 너비·트리 depth·z-index·스켈레톤)만.
- 데스크톱 우선(1280px+). 셸에 불필요한 `sm:` / `md:` 를 강제로 추가하지 않는다.

---

## 13. 인수인계 주석 (FE = BE 동일 밀도, 필수)

정본: [`.cursor/rules/05-handoff-comments.mdc`](../.cursor/rules/05-handoff-comments.mdc)

- 파일 머리: 역할 요약 + `개발자` / `일자` / `코멘트:` 3줄 + `PIPELINE[HFnnn]` / `[HBnnn]` 태그.
- import 바로 위 `// 역할 — …`.
- 공개 메서드·핸들러는 `개발자` / `일자` / `코멘트:` 3줄 JSDoc.
- **의미 있는 JSX prop 마다 여러 줄 주석.** 한 줄 라벨만 달면 미완료.
- BE 파라미터·분기·Mapper XML 절도 **같은 밀도**로 단다.
- 분기는 `조건일 때(= 업무 의미)` 형식.
- SQL 도 동일 — 파일 머리 4줄 + `COMMENT ON TABLE/COLUMN` + `-- p_xxx:` 파라미터 주석.
- PIPELINE 태그는 `docs/23_PIPELINE.md` 색인에 새 번호로 추가한다. FE `HF*` · BE `HB*`. `LOGIN`/`MAIN`/`BIZ` 태그는 쓰지 않고, MES 잔존 `PIPELINE[Fn]` 을 새 파일에 복제하지 않는다.

---

## 14. 기존 화면 재사용 원칙

1. 같은 업무 유형의 화면을 먼저 찾는다 — `docs/14_메뉴_화면_API_DB_전수.md` · 각 폴더 `README.md` · `docs/23_PIPELINE.md`.
2. 골드 참조:
   - FE 셸 `shell/HaccpShell.tsx` · CRUD `pages/docs/ccp/ColdMonitorPage.tsx` · 로그인 `pages/auth/LoginPage.tsx`
   - 문서 작성 `pages/docs/html/hygprocess/HygProcessPage.tsx`
   - 좌우 50:50 기준관리 `pages/docs/html/HtmlFormTemplatePage.tsx`
   - BE `docs/document/DocumentService.java` + `mapper/docs/document/DocumentMapper.xml` · `auth/AuthService.java`
3. 유사 화면 N 개가 같은 프레임을 쓰면 **공통 Page 컴포넌트 + 화면별 Rule/Paper** 로 나눈다 (`HtmlFormTemplatePage` 패턴). 화면마다 복제하지 않는다.
4. 공유 페이지(MasterDataPage · 점검항목 · HWP 작성기)는 복제 금지. 그 메뉴를 손볼 때 폴더만 옮긴다.

---

## 15. 금지사항

- 이모지 (소스 주석 · 규칙 · 커밋 · **사용자 UI 문구** 전부). 허용은 `→` `①②` `×`(U+00D7) · ASCII.
- HTTP `DELETE` 메서드.
- 매직 넘버 — 타임아웃 · 페이지 크기 · 디바운스 · 폴링은 `.env` + `envConfig.ts` / `application.yml`.
- `co_cd` · `user_id` 를 요청 본문으로 받기.
- Tailwind v4 문법, 페이지 TSX 에 긴 Tailwind 복붙.
- default export (신규 코드).
- 신규 대문자/SNAKE 코드값.
- `/screen/{scrnCd}` 라우트, 한글 메뉴명 URL.
- `scrnCd` · `persistId` 값 변경.
- 요청 없는 대규모 리팩터 · 테스트 프레임워크 추가 · ERP/바코드 연동.
- 기존 마이그레이션 번호 재사용, `78` · `85` 재실행.
- git commit/push 는 **사용자가 명시 요청할 때만**.
- 새 공통 함수·컴포넌트를 만들기 전에 기존 것을 찾지 않는 것.

---

## 16. 신규 기능 개발 작업 순서

1. `.cursor/rules/00-bootstrap.mdc` 순서대로 규칙·정본 문서를 읽는다.
2. 이 문서(25) 와 대상 도메인 폴더 `README.md` 를 읽는다.
3. **유사 화면을 찾아 그 구현을 그대로 따른다.** 없을 때만 새 구조를 검토하고, 검토 결과를 사용자에게 먼저 보고한다.
4. 경로를 정한다 — `24_URL_DB_폴더_패키지_정본.md` 의 대/중/소 칸. 중분류 슬러그 중복(`UNIQUE (co_cd, menu_cd)`)을 먼저 확인한다.
5. DB: 다음 번호 마이그레이션 파일 1개에 DDL · 시드 · SP · 화면/권한/메뉴 등록을 담는다.
6. BE: `com.haccp.{대}.{중}` 에 Controller · Service · Mapper + `mapper/{대}/{중}/*.xml`.
7. FE: `api/{대}/*.ts` → `pages/{대}/{중}/{메뉴}/{Name}Page.tsx` + `{Name}Rule.ts` + `README.md`.
8. 등록: `tabRoute.SCREEN_PATH` · `screenRegistry` (+ 새 대분류면 `getModuleIcon`).
9. 인수인계 주석을 FE·BE 동일 밀도로 작성하고 `23_PIPELINE.md` 에 태그를 추가한다.
10. 검증: FE `npx tsc --noEmit` · BE `./mvnw -q -DskipTests compile` · 필요 시 `npx vitest run`.
11. 폴더 `README.md` · `docs/14_메뉴_화면_API_DB_전수.md` 전수 표를 갱신한다.

---

## 17. `.cursor` 규칙 요약 (우선순위 최상)

| 파일 | 적용 | 핵심 |
|------|------|------|
| `00-bootstrap.mdc` | 항상 | 작업 전 읽기 순서, 한국어 응답, 요청 범위만, 이모지 금지, Windows 는 `;` 연결 |
| `01-project-core.mdc` | 항상 | 스택·포트·git 범위·시크릿·kebab 코드값·URL=DB=폴더=패키지 |
| `02-frontend-ui.mdc` | FE UI | Tailwind 3.4 고정, 스타일 4계층, 공통 클래스, 금지 목록 |
| `03-branching.mdc` | git | 브랜치 규약 |
| `04-deploy.mdc` | 배포 | 런북 `docs/20_배포_런북.md` |
| `05-handoff-comments.mdc` | 항상 | FE·BE 동일 밀도 인수인계 주석 (완료 기준) |
| `06-operations.mdc` | 항상 | 삭제 표준 · 타임아웃 3계층 · 4중 방어 · 전역 env Zero Tolerance · 멀티탭 로그아웃 |
| `07-haccp-db.mdc` | DB | 스키마·SP·마이그레이션 번호·양식 42종 규약 |
| `08-haccp-backend.mdc` | BE | 패키지·레이어·테넌트·API 경로·응답 |
| `09-haccp-frontend.mdc` | FE | 디렉터리·네이밍·API 레이어·화면 등록 |
| `ponytail.mdc` | 항상 | 가장 단순한 해법. 요청 없는 추상화·의존성·보일러플레이트 금지 |

충돌 시 우선순위: `.cursor/rules/` > `docs/N_*.md` 정본 > 이 문서(25).
