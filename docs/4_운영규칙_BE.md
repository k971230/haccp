# haccp-api 운영규칙

> 정본: `4_운영규칙_BE.md`  
> FE 상세 정본: [`3_운영규칙_FE.md`](3_운영규칙_FE.md)  
> Cursor: [`06-operations.mdc`](../.cursor/rules/06-operations.mdc) · [`08-haccp-backend.mdc`](../.cursor/rules/08-haccp-backend.mdc)

FE 01과 **동일 계약**. 여기는 BE 적용 포인트만.

## 삭제

- `POST .../validate-delete` → `POST .../delete` · Body 객체 배열  
- Service **양쪽** `assertDeletable`  
- 골드: `doc/DocumentService` + `DeleteValidation` + `DocumentMapper.selectDocumentDeleteBlocker`  
- `@Transactional` + SP 루프 · SP 자율 COMMIT 금지  

## 타임아웃

- `TX_DEFAULT_TIMEOUT_SECONDS=60`  
- `MYBATIS_STATEMENT_TIMEOUT_SECONDS=60`  
- 파일/rhwp: `APP_RHWP_TIMEOUT_SECONDS` < FE file timeout  

## 테넌트·응답

- `LoginUserContext` only · body `coCd` 금지  
- `CommonResponse` · SP 건수 미반환  
- 사용자 메시지: `SqlUserMessage` · 로그: `GlobalExceptionHandler`  

## 파일

- `DocumentFileStorage` / `TemplateFileStorage` · `APP_FILE_*`  
- 상세: FE [`11`](18_프레임워크_파일_보안_작성규칙.md)

## Auth 예외

- `AuthService.login` — **`@Transactional` 금지**
