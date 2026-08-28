# haccp-api

HACCP API 서버. Spring Boot 3.3.4 · Java 17 · MyBatis 3.0.3 · PostgreSQL.
로컬 listen **7070**.

**기동부터 로그인까지 무엇이 어떤 순서로 도는가는 [`PIPELINE.md`](PIPELINE.md)** 에 파일명까지 적혀 있다.

---

## 띄우기

```sh
cp .env.example .env      # 값을 채운다. .env 는 git 금지
./mvnw spring-boot:run    # 또는 IntelliJ 에서 HaccpApiApplication Run
```

없으면 기동이 안 되는 값: `JWT_SECRET` · `DB_HOST` · `DB_USERNAME` · `DB_PASSWORD`.

확인:

```sh
curl -X POST http://localhost:7070/api/v1/auth/login \
  -H "Content-Type: application/json" -d '{"userId":"admin","password":"1234"}'
```

---

## 폴더

| 경로 | 무엇 | 규칙 |
|---|---|---|
| `src/main/java/com/haccp/` | 애플리케이션 코드 | 패키지 = URL (`docs/4_명명과_경로.md`) |
| `src/main/resources/mapper/` | MyBatis XML | 폴더·`namespace` 가 자바 패키지와 **같아야 한다** |
| `src/main/resources/application.yml` | 설정 | 값은 전부 `${ENV:기본값}` |
| `src/test/java/com/haccp/` | 단위 테스트 | DB·기동 없이 도는 것만 |
| `.mvn/` | Maven Wrapper | 손대지 않는다 |
| `.run/` | IntelliJ 실행 구성 | 팀 공용 — 커밋한다 |
| `Dockerfile` | 운영 이미지 | 멀티스테이지 |

### 패키지 배치

```
com.haccp
  HaccpApiApplication      진입점 · @MapperScan("com.haccp")
  common/                  전 화면 공용 — 손대면 전부 영향
    auth/                  JWT 발급·화면 권한 판정
    config/                JwtFilter · WebConfig(CORS·인터셉터)
    exception/             GlobalExceptionHandler — 예외를 HTTP 로
    response/              CommonResponse
    validation/            삭제 차단 공통
  auth/ code/ menu/        셸이 쓰는 공용 API (화면 아님)
  log/ pref/ tsk/
  docs/                    문서 기준 — documents · templates · htmlform · hwp · sch
  draft/                   문서 작성 — ccpmonitoring · html · hwpdoc
  flow/ca/                 이탈·개선조치
  sys/                     시스템 — code · logs
```

---

## 지키는 것

| 규칙 | 왜 |
|---|---|
| 업무 SQL 은 **SP** 에 둔다 | 매퍼 XML 에 직접 SELECT 를 적지 않는다 |
| 회사코드·작업자는 **JWT 에서만** | 본문 값을 쓰면 남의 회사 자료를 만진다 |
| 삭제는 `validate-delete` → `delete` **2단계** | HTTP DELETE 를 쓰지 않는다 |
| 컨트롤러는 얇게 | 업무 판단은 서비스, SQL 은 SP |
| 형제 화면과 코드가 같으면 공통 기반으로 | 복제하면 한쪽만 고쳐진다 |

---

## 확인

```sh
./mvnw -q -o test     # 단위 104건
```

**단위 테스트 통과가 기동 성공을 뜻하지 않는다.** MyBatis 매퍼 XML 은 컴파일에 안 잡힌다 —
패키지를 옮겼거나 XML 을 고쳤으면 **반드시 기동해서** 확인한다.

화면까지 도는지는 프론트 E2E 가 본다.

```sh
cd ../../frontend/haccp-web ; npx playwright test    # 152건
```

---

## 관련

- 기동·요청 흐름: [`PIPELINE.md`](PIPELINE.md)
- 화면 추가: [`docs/2_화면_추가하기.md`](../../docs/2_화면_추가하기.md)
- 이름 규칙: [`docs/4_명명과_경로.md`](../../docs/4_명명과_경로.md)
- 단위 테스트: [`src/test/java/com/haccp/README.md`](src/test/java/com/haccp/README.md)
- DB 정본: [`db_sasshaccp/README.md`](../../db_sasshaccp/README.md)
- 규칙: `.cursor/rules/08-haccp-backend.mdc`

## 변경

- 2026-08-26 — PIPELINE.md 신설에 맞춰 다시 썼다. 죽은 문서 링크를 걷어내고
  패키지 배치·지키는 것을 표로 옮겼다
