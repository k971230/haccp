# com.haccp.sys — 시스템 관리 9화면

정본: `docs/8_에이전트_가이드_BE.md` · `docs/4_운영규칙_BE.md` · FE 파이프라인 표는 `frontend/haccp-web/src/pages/sys/README.md`  
경로 정본: `docs/24_URL_DB_폴더_패키지_정본.md`

## 구조 — 메뉴 1개 = 패키지 1개

```
com/haccp/sys/
 ├ SysPayload.java   Map payload · 삭제키 정규화 공용 유틸
 ├ code/
 │   ├ commoncode/ CommonCodeController · CommonCodeService · CommonCodeMapper
 │   ├ menu/       MenuMgmtController · MenuMgmtService · MenuMgmtMapper
 │   ├ role/       RoleMgmtController · RoleMgmtService · RoleMgmtMapper
 │   ├ department/ DepartmentController · DepartmentService · DepartmentMapper
 │   ├ user/       UserController · UserService · UserMapper   (서명 포함)
 │   └ approvalline/ ApprovalLineController · Service · Mapper
 └ logs/
     ├ loginhistory/ LoginHistoryController · Service · Mapper   (조회 전용)
     ├ auditlog/     AuditLogController · Service · Mapper · AuditWriter
     └ screenusage/  ScreenUsageController · Service · Mapper    (조회 전용)
```

XML은 `resources/mapper/sys/{code|logs}/{같은 폴더명}/*.xml` (`mapper/sys/README.md`).
구 `SystemController`·`SystemService`·`SystemMapper`·`SystemMapper.xml` 단일 허브는 제거되었다. 되살리지 않는다.

**다른 영역도 이번에 손대는 메뉴는 같은 규약으로 분할한다.** 미리 전 메뉴를 나누지 않는다. 상세 `08-haccp-backend.mdc`.

패키지 루트는 `com.haccp`다. 구 MES 접두 패키지는 전면 이동되었고 잔존 참조가 없어야 한다 (MES 접두 문자열 grep 결과 0건).

## 계층 책임

| 계층 | 하는 일 | 하지 않는 일 |
|---|---|---|
| Controller | URL 매핑, 요청 파라미터 수신, 날짜 등 표현 계층 정규화 | 트랜잭션, 업무 검증, SQL |
| Service | `@Transactional`, `LoginUserContext` 조회, payload 정규화(`SysPayload`), 삭제 Double Check, 파일 I/O | HTTP 타입 의존, 네이티브 SQL |
| Mapper | SP 호출 시그니처 선언 | 업무 분기 |

## URL 규약

HTTP: `/api/v1` + FE `SCREEN_PATH` + 동작.

```
GET  /api/v1/sys/code|{logs}/{scrnCd}/list
PUT  /api/v1/sys/code|{logs}/{scrnCd}/save
POST /api/v1/sys/code|{logs}/{scrnCd}/validate-delete
POST /api/v1/sys/code|{logs}/{scrnCd}/delete
```

`{scrnCd}`는 `tbl_screen.scrn_cd` (`common-code-management` · `menu-management` · `role-management` · `department-management` · `user-management` · `approval-line-management` · `login-history` · `audit-log` · `screen-usage-statistics`).

예외적으로 공통코드는 `list` 대신 `groups`·`details` 2개, 권한그룹은 `screens`(GET/PUT)가 추가되고, 서명은 다음 경로를 쓴다.

```
GET  /api/v1/sys/users/{userId}/sign          서명 이미지
POST /api/v1/sys/users/{userId}/sign          업로드 (multipart)
POST /api/v1/sys/users/{userId}/sign/delete   삭제 (HTTP DELETE 금지)
GET  /api/v1/sys/users/me/sign                내 서명 이미지 (HWP 클립보드 복사·미리보기)
GET  /api/v1/sys/users/me/sign-info           내 서명 보유여부·파일명 (CCP 행 서명 — 바이너리 미포함)
```

## 삭제 표준 (`06-operations.mdc` OPS_DELETE)

- HTTP DELETE 금지. 삭제는 `POST`만
- Body는 복합키 객체 **배열** `[{ "idx": 1 }]` — UI 단건이어도 1건 배열. 스칼라 배열 금지
- `validateDelete`·`delete` **양쪽**에서 같은 `assertDeletable(coCd, keys)`를 돈다 (Double Check)
- 차단 판정은 화면별 `sp_{화면명}_delete_blocker_r_000` 단일 조회 → `DeleteValidation.throwIfBlocked`
- 실제 삭제도 `@Transactional` + SP 루프. SP 내부 자율 COMMIT 금지

## 공용 유틸 — `SysPayload`

화면 payload는 `Map<String, Object>`로 들어온다. 각 서비스가 캐스팅을 반복하지 않도록 다음을 여기 모았다.

| 메서드 | 용도 |
|---|---|
| `text(row, key)` | 문자열 추출 + trim, 없으면 빈 문자열 |
| `intOrNull` · `idxOrNull` | 숫자 변환, 값 없으면 null |
| `requireRows(rows)` | 저장 대상이 비면 `BizException` |
| `idxList(keys)` | 삭제키 배열에서 `idx` 목록 추출 + 검증 |
| `normalizeDate(s)` | 기간 문자열을 `YYYYMMDD` 8자리로 정규화 (로그 3화면) |

## 보안·테넌시

- `co_cd`·작업자 ID는 **요청 본문에서 읽지 않는다.** 항상 `LoginUserContext.coCd()` / `userId()`
- 조회·저장·삭제 SP 모두 `p_co_cd`를 첫 파라미터로 받아 테넌트 범위를 강제한다
- 비밀번호는 서비스에서 BCrypt 해싱 후 SP로 넘긴다. 평문이 SP·로그에 남지 않게 한다

## 오류 처리

업무 오류는 `BizException`, SP 오류는 `ERRCODE='45000'` → `SqlUserMessage` → 400.
사용자에게는 업무 문구만, 기술 상세는 `GlobalExceptionHandler`가 서버 로그로만 남긴다.

## 신규 메뉴 추가 시

1. `com.haccp.{대}.{중}` 패키지에 Controller·Service·Mapper 3종 + `resources/mapper/{대}/{중}/*.xml`
2. SP는 화면명 기준 `sp_{화면}_{r|c|d|u}_{nnn}` 또는 `sp_tbl_*`. 다른 화면 SP를 재사용하지 않는다
3. 삭제가 있으면 `_delete_blocker_r_000`까지 함께 만든다
4. 폴더 README 작성, 이 문서의 URL·구조 표 갱신
5. 검증: `./mvnw -q -DskipTests compile`
