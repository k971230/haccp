# haccp-api — Agent Instructions

> BE 입구: [`00_문서인덱스.md`](2_문서인덱스_BE.md)  
> FE: [`7_에이전트_가이드_FE.md`](7_에이전트_가이드_FE.md)  
> Cursor: [`61-haccp-backend.mdc`](../.cursor/rules/61-haccp-backend.mdc) · [`60-haccp-db.mdc`](../.cursor/rules/60-haccp-db.mdc)

## 스택

Spring Boot **3.3.4** · Java **17** · MyBatis **3.0.3** · PG `sasshaccp` · 포트 **7070**.

## 패턴

- 신규 API: Controller + (Service) + Mapper + `resources/mapper/{pkg}/*.xml` + SP  
- 삭제: validate-delete → delete · Double Check  
- 파일: Storage 경유 · multipart 한도 = `APP_FILE_MAX_*`  
- 테넌트: `LoginUserContext`  
- 주석: FE와 동일 밀도 · PIPELINE `HB`  
- login에 `@Transactional` 금지  

## 실행

```bash
cd backend/haccp-api
# .env 준비 (.env.example 복사)
./mvnw spring-boot:run
```

검증: `./mvnw -q -DskipTests compile`  
DB 적용: `db_sasshaccp/apply-all.sh` (운영 절차 준수).

## 하지 말 것

- mes-api/`metis`/`sp_sk_*` 혼용  
- HTTP DELETE · body coCd  
- SP 내부 COMMIT  
- `.env` 커밋 · 이모지  
