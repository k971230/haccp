# pref

도메인 `pref` — 사용자 환경설정. 조회(list)는 Controller → Mapper 직행. 저장(save)만 `PrefService` (`@Transactional`).

## 하위
- `dto/` — `pref` 요청·응답 DTO (JSON camelCase)

## 관련
- 정본: `.cursor/rules/08-haccp-backend.mdc` · `.cursor/rules/06-operations.mdc`
