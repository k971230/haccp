# HACCP 인수인계 · 아키텍처 · 소스 작성 규칙

> 정본: `5_인수인계_및_아키텍처_FE.md`  
> 작성일: 2026-08-10 · 개발자: 박승우  
> Cursor: [`40-handoff-comments.mdc`](../.cursor/rules/40-handoff-comments.mdc) · [`62-haccp-frontend.mdc`](../.cursor/rules/62-haccp-frontend.mdc) · [`61-haccp-backend.mdc`](../.cursor/rules/61-haccp-backend.mdc)  
> BE 대칭: [`6_인수인계_및_아키텍처_BE.md`](6_인수인계_및_아키텍처_BE.md)  
> 파일 지도: [`10`](17_파일구조_컴포넌트_함수지도.md) · 작성 체크: [`11`](18_프레임워크_파일_보안_작성규칙.md)

---

## 1. 시스템 한 줄

식육포장처리업 HACCP **기록·결재·보관** SaaS.  
MES와 **별개** DB(`sasshaccp`)·앱. 센서/스마트 HACCP이 아니라 종이·한글 서식의 웹화 전 단계.

```
브라우저 haccp-web(4173)
  → JWT → haccp-api(7070)
    → MyBatis → PG SP (sasshaccp)
    → 로컬/볼륨 파일 (APP_FILE_ROOT)
```

---

## 2. 아키텍처 계층

| 층 | FE | BE |
|----|----|----|
| 진입 | `main` · `AppRoutes` | `HaccpApiApplication` · `JwtFilter` |
| 셸 | `HaccpShell` · `screenRegistry` · tabs | menu / code / pref / log |
| 화면 | `pages/{모듈}/*Page` | `{pkg}Controller` |
| 상태 | Zustand · React Query(코드·메뉴) | `LoginUserContext` |
| 계약 | `api/*` → `http` | Service · Mapper · XML |
| 데이터 | — | SP · `tbl_*` · 파일 볼륨 |

의존: `pages → api/hooks/components/shell` · `api`는 UI 금지 · `shell`은 pages import 금지(레지스트리만 예외).

---

## 3. 소스 작성 규칙 (놓치지 말 것)

### 3-1. 언어·문자

- 응답·주석·UI 문구: **한국어**
- **이모지 금지** (소스·UI·커밋·docs)
- UTF-8. 한글 깨지면 즉시 재저장
- UI 아이콘: Lucide / `.mes-*` CSS만

### 3-2. 인수인계 주석 (FE = BE 동일 밀도)

- import 위: `// 역할 — …` (`역할 — 역할 —` 중복 금지)
- 메서드 JSDoc: `개발자: 박승우` / `일자: YYYY-MM-DD` / `코멘트:` 3줄 (무엇·언제·성공실패)
- 분기: `조건일 때(= 의미)`
- JSX: `//`만 (`/**` 삽입 금지). 주석에 `*/` 문자열 금지
- **의미 있는 prop마다 여러 줄** — 한 줄 라벨만이면 미완료
- PIPELINE: FE `HF*` · BE `HB*` (MES `F`/`B`와 섞지 않음). 새 번호는 루트 `ReadMe.md` HACCP PIPELINE 표

**골드 FE:** `shell/HaccpShell.tsx` · `pages/auth/LoginPage.tsx` · DocForm 계열  
**골드 BE:** `auth/AuthService` + `AuthController` + `AuthMapper.xml` · `doc/Document*`

### 3-3. 네이밍 Two-Tier

| 진영 | 규칙 | 예 |
|------|------|-----|
| 앱 (TS/Java/JSON/그리드) | camelCase | `docIdx`, `coCd` |
| DB / Mapper SQL / SP | lower_snake | `doc_idx`, `sp_tbl_document_r_000` |
| 화면코드·상수·env 키 | kebab / UPPER | `ccp-cold-monitor`, `JWT_SECRET` |

### 3-4. FE 디렉터리·이름

| 규칙 | 내용 |
|------|------|
| 화면 키 | `tbl_screen.scrn_cd`와 **문자 동일** kebab → `SCREEN_REGISTRY` |
| CSS/헬퍼 | `.mes-*` · `MesButton` · `mesToast` · `mesError` · `MES` **이름 유지** |
| 제품 고유 | `HaccpShell` · `HaccpLogo` |
| storage | `haccp-*` only (`authKeys.ts`) |
| 페이지 | `{Name}Page.tsx` + 필요 시 `.rules.ts` |
| API | `api/{domain}Api.ts`만 HTTP |

### 3-5. BE 디렉터리·레이어

```
Controller → Service(@Transactional CUD) → Mapper+XML → SP
```

- 셸(menu·code·pref·log): Controller→Mapper 직결 허용
- DI: `@RequiredArgsConstructor` + `private final`
- 검증: Service에서 `BizException`
- `AuthService.login`에 `@Transactional` **금지** (실패 이력 보존)

### 3-6. 금지·동결

- ERP 연동·바코드·요청 없는 PDF 기능 확장 금지 (`01-project-core`)
- 스마트일지 CUD UI · 감사추출 UI · 범용 점검항목관리 메뉴 — 동결(09)
- `ccpMetalApi` / `ccpVerificationApi` — **제거됨** (2026-08-10, STEP 01, `ccpFormsApi`로 통일). 재생성 금지

---

## 4. 화면 조립 패턴 (요약)

| 유형 | 핵심 |
|------|------|
| DB형 작성 | `useDocFormSession` + `DocFormLayout` + `DocumentApprovalToolbar(writerOnly)` |
| HWP leaf | `hwpLeaf(tmplCd)` → `HwpDocumentEditorPage` |
| 그리드 CRUD | `useEditableRows` + `MesEditableGrid` + `GridCrudButtons` |
| M-D | `useSection` + 이중 그리드 |
| 법적서류 | 패널 CRUD만 · 셸 new/save/del 미등록 |

상세 트리·export: [`10`](17_파일구조_컴포넌트_함수지도.md)

---

## 5. 검증 명령

```bash
# FE
cd frontend/haccp-web
npx tsc --noEmit

# BE
cd backend/haccp-api
./mvnw -q -DskipTests compile
```

---

## 6. 커밋·시크릿

- git commit/push는 사용자 요청 시에만
- `.env` · `.env.docker` · `backend/haccp-api/.env` 커밋 금지
- 로컬 전용(에이전트가 git 추가 금지): 루트 `docs/`·`sql/`·`db_migration/`·`tools/` 등 (`01-project-core`)
- **예외 커밋 대상:** 루트 `docs/[숫자]_*.md` · `docs/README.md` · FE/BE docs 스텁 · `db_sasshaccp/`

---

*아키텍처·작성 규칙 정본. 운영 숫자는 01, 보안은 04·11.*
