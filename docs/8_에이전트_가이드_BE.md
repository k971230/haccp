# haccp-api — Agent Instructions

> BE 입구: [`00_문서인덱스.md`](2_문서인덱스_BE.md)  
> FE: [`7_에이전트_가이드_FE.md`](7_에이전트_가이드_FE.md)  
> Cursor: [`08-haccp-backend.mdc`](../.cursor/rules/08-haccp-backend.mdc) · [`07-haccp-db.mdc`](../.cursor/rules/07-haccp-db.mdc)

## 스택

Spring Boot **3.3.4** · Java **17** · MyBatis **3.0.3** · PG `sasshaccp` · 포트 **7070**.

## 패턴

- 신규 API: Controller + (Service) + Mapper + `resources/mapper/{영역}/{메뉴}/*.xml` + SP  
- 손대는 메뉴: 허브(평탄 패키지)에 남아 있으면 **그 작업에서** `com.haccp.{영역}.{메뉴}` + `mapper/{영역}/{메뉴}/` 로 분할. 미리 전 메뉴를 나누지 않는다. 기존 URL은 유지. 골드 `com.haccp.sys`  
- 삭제: validate-delete → delete · Double Check  
- 파일: Storage 경유 · multipart 한도 = `APP_FILE_MAX_*`  
- 테넌트: `LoginUserContext`  
- 주석: FE와 동일 밀도 · PIPELINE `HB` · 색인 `docs/23_PIPELINE.md`  
- login에 `@Transactional` 금지  

## 실행

```bash
cd backend/haccp-api
# .env 준비 (.env.example 복사)
./mvnw spring-boot:run
```

검증: `./mvnw -q -DskipTests compile`  
DB 적용: `db_sasshaccp/apply-all.sh` (운영 절차 준수).

## 신규 화면

기존 URL은 유지. 패키지는 `com.haccp.{영역}.{메뉴}` + `mapper/{영역}/{메뉴}/`. FE `SCREEN_PATH` 는 pathname만 (`/docs/...`, `/sys/code/...`). `/haccp` 접두는 Vite basename.

1. Controller + Service + Mapper XML + SP (`sp_tbl_*`)  
2. `tbl_screen` · 권한. 메뉴 숨김이어도 API URL은 유지할 수 있다  
3. 삭제: validate-delete → delete  
4. `docs/23_PIPELINE.md` `HB` 태그 (재채번 금지)

골드: `com.haccp.docs.document.DocumentService` · `AuthService`.

## 하지 말 것

- mes-api/`metis`/`sp_sk_*` 혼용  
- HTTP DELETE · body coCd  
- SP 내부 COMMIT  
- `.env` 커밋 · 이모지  
