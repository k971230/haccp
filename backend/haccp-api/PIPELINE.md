# 백엔드 파이프라인 — 시동부터 로그인까지

> 개발자: 박승우 · 일자: 2026-08-26
> 대상: `backend/haccp-api` (Spring Boot 3.3.4 · Java 17 · MyBatis 3.0.3 · PostgreSQL)
> 프론트 쪽은 [`frontend/haccp-web/PIPELINE.md`](../../frontend/haccp-web/PIPELINE.md)

이 문서는 **실제로 흐르는 순서**를 파일명까지 적는다.
새로 온 사람이 「로그인 버튼을 눌렀을 때 무엇이 어떤 순서로 도는가」를 코드 열지 않고 알 수 있게 한다.

---

## 1단계 — 프로세스 시동

| # | 파일 | 하는 일 |
|---|---|---|
| 1-1 | `src/main/java/com/haccp/HaccpApiApplication.java` | `@SpringBootApplication` · `@MapperScan("com.haccp")` · `@EnableScheduling`. 내장 Tomcat 기동 |
| 1-2 | `src/main/resources/application.yml` | 포트 `${SERVER_PORT:7070}` · DB URL · `mapper-locations: classpath:/mapper/**/*.xml` |
| 1-3 | `backend/haccp-api/.env` | `spring.config.import: optional:dotenv:./.env` 로 읽는다. **git 금지**. 없으면 `JWT_SECRET`·`DB_PASSWORD` 누락으로 기동 실패 |
| 1-4 | `src/main/java/com/haccp/common/config/WebConfig.java` | CORS 허용 출처(`app.cors.allowed-origins`, 기본 `http://localhost:4173`) · `ScreenAuthInterceptor` 를 `/api/**` 에 등록 |
| 1-5 | `src/main/java/com/haccp/common/config/JwtFilter.java` | `@Component extends OncePerRequestFilter`. 모든 요청 앞단 |
| 1-6 | `src/main/resources/mapper/**/*.xml` | MyBatis 가 네임스페이스로 `@Mapper` 인터페이스와 짝짓는다 |

> **여기서 자주 터진다.** 매퍼 XML 은 **컴파일에 안 잡힌다.**
> 패키지를 옮기면 XML `namespace`·`resultType` 도 같이 옮기고 **반드시 기동해서** 확인한다.
> `mvn compile` 통과가 기동 성공을 뜻하지 않는다.

### 1-n. 시동 시 같이 뜨는 것

| # | 파일 | 하는 일 |
|---|---|---|
| 1-7 | `docs/sch/DocumentAlarmScheduler.java` | `@Scheduled` — 예정일 알림 |
| 1-8 | `log/ViewStatDailyJob.java` | 화면조회 로그 일별 집계 |
| 1-9 | `docs/templates/TemplateImportService.java` | `app.template.import-root` 가 있으면 기동 시 HWP 양식을 읽어 들인다 |
| 1-10 | `board/DailyTaskGenerationJob.java` | `@Scheduled` — 매일 00:05 예정일 생성 (`app.task-generation.cron` · `regenerateAllCompanies`) |

---

## 2단계 — 요청 한 건이 지나는 길

로그인 여부와 무관하게 `/api/**` 는 전부 이 순서다.

| # | 파일 | 하는 일 | 실패하면 |
|---|---|---|---|
| 2-1 | `common/config/JwtFilter.java` | `Authorization: Bearer` 파싱 → `JwtProvider.parse` → `LoginUserContext` 에 담는다 | 401 `UNAUTHORIZED` |
| 2-2 | `common/auth/JwtProvider.java` | HS512 서명 검증·만료 확인. 회사코드·권한그룹을 꺼낸다 | 401 |
| 2-3 | `common/auth/ScreenAuthInterceptor.java` | URL → 화면코드·권한종류로 바꿔 `tbl_role_screen` 과 대조 | 403 (deny 로그) |
| 2-4 | `common/auth/ScreenAuthResolver.java` | URL 접두 → `scrnCd` 정적 맵. **화면을 옮기면 여기가 먼저 깨진다** | — |
| 2-5 | `{대}/{중}/XxxController.java` | 요청 본문 → DTO. `@Valid` 로 형식만 본다 | 400 |
| 2-6 | `{대}/{중}/XxxService.java` | 업무 판단 · 회사코드·작업자를 **JWT 에서만** 채운다 | 400 `BizException` |
| 2-7 | `{대}/{중}/XxxMapper.java` + `mapper/{대}/{중}/XxxMapper.xml` | SP 호출 한 줄 | — |
| 2-8 | `db_sasshaccp/01_sp.sql` 의 `sp_*` | 업무 SQL. 규칙 위반은 `RAISE ... ERRCODE='45000'` | 400 `DB_SIGNAL` |
| 2-9 | `common/exception/GlobalExceptionHandler.java` | 예외 → HTTP. 45000→400 · 23505/40P01→409 · 22001/23502/23503/22P02→400 `BAD_INPUT` · 그 밖→500 | — |
| 2-10 | `common/response/CommonResponse.java` | `{success, code, message, data}` 로 감싼다 | — |

> **본문의 `coCd`·`userId` 는 믿지 않는다.** 서비스가 `LoginUserContext` 값으로 덮어쓴다.
> E2E 가 위조 본문을 보내 이걸 확인한다(`security-constraints.spec.ts`).

---

## 3단계 — 로그인 (인증이 없는 유일한 길)

`POST /api/v1/auth/login` 은 `JwtFilter` 가 통과시키는 예외 경로다.

| # | 파일 | 하는 일 |
|---|---|---|
| 3-1 | `auth/AuthController.java` `@PostMapping("/login")` | `LoginRequest`(userId·password) 검증. **회사코드는 안 받는다** — 아이디가 전역 유일 |
| 3-2 | `auth/AuthService.login` | 아래 3-3~3-9 를 순서대로 |
| 3-3 | `auth/AuthMapper.selectUserForLogin` → `sp_tbl_user_login_r_000` | 아이디로 사용자 1건. 없으면 이력만 남기고 거절(회사코드를 모르니 `null` 로 남긴다) |
| 3-4 | `AuthService.assertAccountUsable` | 잠금·정지·구독 판정. **비밀번호가 맞아도 여기서 막힌다** |
| 3-5 | `BCrypt.checkpw` | 해시 비교. 저장 해시가 비면 비교 없이 실패 |
| 3-6 | 실패 시 `AuthMapper.updateLoginResult(…,'F',…)` → `sp_tbl_user_login_u_000` | 실패 카운터 +1. 임계 도달이면 결과코드 `L` + 잠금 문구 |
| 3-7 | 성공 시 `updateLoginResult(…,'S',…)` | 카운터 초기화 · 최종 로그인 일시 |
| 3-8 | `common/auth/JwtProvider.createToken` | `sub`·`coCd`·`coNm`·`userNm`·`usrgrpCd`·`deptCd`·`sid` 를 담아 서명 |
| 3-9 | `AuthMapper.insertLoginLog` → `sp_tbl_login_log_c_000` | 성공·실패·잠금 **모두** 남긴다. 실패를 안 남기면 침입 시도를 못 본다 |
| 3-10 | `AuthMapper.selectScreenAuths` → `sp_role_management_screen_r_000` | 화면 권한 목록. **ADMIN 은 빈 목록** — 프론트가 `isAdmin && 빈 목록`을 전권으로 읽는다 |

응답: `LoginResponse { token, user, screens }`

### 3-n. 로그인 뒤 프론트가 바로 부르는 것

| # | API | 파일 | 쓰는 곳 |
|---|---|---|---|
| 3-11 | `GET /api/v1/menu/list` | `menu/MenuController` → `sp_menu_nav_r_000` | 좌측 메뉴 트리 (업체별 `tbl_menu`) |
| 3-12 | `GET /api/v1/code` | `code/CodeController` → `sp_common_code_management_r_001` | 공통코드 콤보 |
| 3-13 | `GET /api/v1/pref/grid` | `pref/PrefController` → `sp_tbl_grid_pref_r_000` | 사용자별 그리드 열 설정 |
| 3-14 | `POST /api/v1/log/view/collect` | `log/ViewLogController` → `sp_tbl_view_log_c_000` | 화면 체류 로그 (화면 이동 시 모아 보낸다) |

---

## 4단계 — 화면 하나가 걸치는 층

화면을 추가·이동하면 **아래가 전부** 같이 움직인다. 하나라도 빠지면 화면이 안 열린다.

```
FE  shell/tabRoute.ts SCREEN_PATH        pages/{대}/{중}/
    shell/screenRegistry.tsx             README.md
BE  com.haccp.{대}.{중}                   mapper/{대}/{중}/
    common/auth/ScreenAuthResolver       README.md
DB  tbl_screen · tbl_role_screen · tbl_menu
```

`scrnCd`·`persistId` 는 폴더·URL 이 바뀌어도 **안 바꾼다** — 사용자가 저장한 열 너비가 날아간다.

### 4-n. 패키지 = URL 규칙

| URL | 패키지 | 매퍼 XML |
|---|---|---|
| `/api/v1/docs/documents/**` | `com.haccp.docs.documents` | `mapper/docs/documents/` |
| `/api/v1/docs/templates/**` | `com.haccp.docs.templates` | (전용 매퍼 없음 — `DocumentMapper` 공용) |
| `/api/v1/docs/html-form/{화면}/**` | `com.haccp.docs.htmlform.{화면}` | `mapper/docs/htmlform/{화면}/` |
| `/api/v1/draft/ccp-monitoring/{화면}` | `com.haccp.draft.ccpmonitoring` | `mapper/draft/ccpmonitoring/` |
| `/api/v1/draft/hwp-doc/hwp-write` | `com.haccp.draft.hwpdoc` | `mapper/draft/hwpdoc/` |
| `/api/v1/sys/code/{화면}` | `com.haccp.sys.code.{화면}` | `mapper/sys/code/{화면}/` |
| `/api/v1/sys/logs/{화면}` | `com.haccp.sys.logs.{화면}` | `mapper/sys/logs/{화면}/` |
| `/api/v1/board/**` | `com.haccp.board` (중분류 없음) | `mapper/board/` |

자바 패키지는 하이픈을 못 써 **중분류의 하이픈만 지운다**(`html-form` → `htmlform`).
**중분류 아래 화면이 하나뿐이면 중분류 단을 생략한다** — `board` 가 그 경우다 (`docs/4_명명과_경로.md`).
그 밖의 차이는 규칙 위반이다 — 2026-08-26 에 `draft.hwp`→`draft.hwpdoc`,
`docs.document`→`docs.documents`, `docs.template`→`docs.templates` 로 맞췄다.

---

## 5단계 — SP 규약

업무 SQL 은 **전부 SP** 에 있다. 매퍼 XML 에 직접 SELECT 를 적지 않는다.

| 이름 | 뜻 |
|---|---|
| `sp_{화면코드}_{동작}_000` | 그 화면 전용 (`sp_department_management_r_000`) |
| `sp_tbl_{표}_{동작}_000` | 여러 화면 공용 (`sp_tbl_document_delete_blocker_r_000`) |
| 동작 | `r` 조회 · `c` 등록 · `u` 수정 · `d` 삭제 |

- 업무 규칙 위반은 `RAISE EXCEPTION '문구' USING ERRCODE = '45000'` → 400 + 그 문구
- 삭제는 `validate-delete` → `delete` **2단계**. HTTP DELETE 를 쓰지 않는다
- 정본은 `db_sasshaccp/01_sp.sql` (156본 · 화면이 늘면 같이 는다). 라이브와 목록이 같아야 한다

점검(2026-08-26): SP 155 · 파일=DB 일치 · 인자 개수 불일치 0 · 컬럼 실재 0건 · 회사 격리 위반 0 ·
매퍼의 직접 SQL 0 · 아무도 안 부르는 SP 0.

---

## 6단계 — 검증

```sh
cd backend/haccp-api
./mvnw -q -o test          # 단위 108건 — DB·기동 없이 도는 것만
```

**단위 테스트로는 매퍼 XML 이 안 잡힌다.** 화면까지 도는지는 프론트 E2E 가 본다.

```sh
cd frontend/haccp-web ; npm run build ; npm run preview &
npx playwright test    # DB 대조 포함
```

---

## 관련

- 규칙: `.cursor/rules/08-haccp-backend.mdc` · `01-project-core.mdc`
- 태그 색인: `docs/5_PIPELINE_색인.md` (`PIPELINE[HB*]` → 파일)
- 화면 전수표: [`docs/3_화면_지도.md`](../../docs/3_화면_지도.md) — 생성기가 만든다
- SP → 표 전수표: [`docs/9_SP_색인.md`](../../docs/9_SP_색인.md) — 생성기가 만든다
- DB 정본: `db_sasshaccp/README.md`
- E2E 결과: `E2E.md` · `E2E_ERRORS.md`

## 변경

- 2026-08-26 — 신설. 시동→요청→로그인 순서를 파일명까지 적었다.
  패키지 3건을 URL 과 맞추고(`draft.hwpdoc`·`docs.documents`·`docs.templates`),
  매퍼에 흩어져 있던 직접 SQL 6곳을 공용 SP 2본으로 내렸다.
