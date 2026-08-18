# com.haccp.hwp — 사용양식 · 문서주기 2화면

정본: `docs/8_에이전트_가이드_BE.md` · `docs/4_운영규칙_BE.md` · FE 파이프라인 표는 `frontend/haccp-web/src/pages/hwp/README.md`

## 구조 — 메뉴 1개 = 패키지 1개

```
com/haccp/hwp/
 ├ hwptemplate/ HwpTemplateController · HwpTemplateService · HwpTemplateMapper
 └ doccycle/    DocCycleController · DocCycleService · DocCycleMapper
                CycleScheduleGenerator · DocumentAlarmScheduler
```

XML은 `resources/mapper/hwp/{같은 폴더명}/*.xml` (`mapper/hwp/README.md`).

**다른 영역도 이번에 손대는 메뉴는 같은 규약으로 분할한다.** 미리 전 메뉴를 나누지 않는다. 상세 `08-haccp-backend.mdc`.

## 계층 책임

| 계층 | 하는 일 | 하지 않는 일 |
|---|---|---|
| Controller | URL 매핑, 요청 파라미터 수신 | 트랜잭션, 업무 검증, SQL |
| Service | `@Transactional`, `LoginUserContext`, 삭제 Double Check, 예정일 재생성 호출 | HTTP 타입 의존, 네이티브 SQL |
| Mapper | SP 호출 시그니처 선언 | 업무 분기 |

`CycleScheduleGenerator`는 규칙 → 예정일 순수 계산. 검증은 `src/test/.../hwp/doccycle/CycleScheduleGeneratorTest`.

## URL 규약 (화면 분할 후에도 유지)

```
GET  /api/v1/hwp/hwp-templates/list
PUT  /api/v1/hwp/hwp-templates/save
GET  /api/v1/hwp/hwp-templates/files
POST /api/v1/hwp/hwp-templates/apply-file

GET  /api/v1/hwp/doc-cycles/forms
GET  /api/v1/hwp/doc-cycles/get
PUT  /api/v1/hwp/doc-cycles/save
POST /api/v1/hwp/doc-cycles/validate-delete
POST /api/v1/hwp/doc-cycles/delete
```

사용양식 삭제는 법적서류와 URL을 공유하므로 Workflow에 잔류한다.

```
POST /api/v1/bas/company-templates/validate-delete
POST /api/v1/bas/company-templates/delete
```

파일 원본 I/O는 `doc` 영역.

```
GET  /api/v1/doc/templates/{tmplCd}/form
POST /api/v1/doc/templates/{tmplCd}/form
```

## 삭제 표준 (`06-operations.mdc` OPS_DELETE)

- HTTP DELETE 금지. 삭제는 `POST`만
- Body는 복합키 객체 **배열** `[{ "tmplCd": "..." }]` — UI 단건이어도 1건 배열
- `validateDelete`·`delete` **양쪽**에서 같은 `assertDeletable`을 돈다 (Double Check)
- 실제 삭제도 `@Transactional` + SP. SP 내부 자율 COMMIT 금지

## 보안·테넌시

- `co_cd`·작업자 ID는 **요청 본문에서 읽지 않는다.** 항상 `LoginUserContext.coCd()` / `userId()`
- 조회·저장·삭제 SP 모두 `p_co_cd`를 첫 파라미터로 받아 테넌트 범위를 강제한다

## 오류 처리

업무 오류는 `BizException`, SP 오류는 `ERRCODE='45000'` → `SqlUserMessage` → 400.
사용자에게는 업무 문구만, 기술 상세는 `GlobalExceptionHandler`가 서버 로그로만 남긴다.

## 배치

일일 과제: `tsk/DailyTaskGenerationJob` → `DocCycleService.regenerateAllCompanies()` → `TaskService.generateAllCompanies()`.
마감 알림: `DocumentAlarmScheduler` — `app.schedule.alarm-cron`.

## 신규 메뉴 추가 시

1. `com.haccp.hwp.{메뉴}` 패키지에 Controller·Service·Mapper 3종 + `resources/mapper/hwp/{메뉴}/*.xml`
2. SP는 화면명 기준 `sp_{화면명}_{r|c|d|u}_{nnn}` 또는 테이블 단위 `sp_tbl_*`
3. 삭제가 있으면 `_delete_blocker_r_000`까지 함께 만든다
4. 폴더 README 작성, FE `pages/hwp/README.md` URL·구조 표 갱신
