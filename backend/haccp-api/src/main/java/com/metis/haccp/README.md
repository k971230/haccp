# haccp

HACCP API 루트 패키지. 도메인별 하위 패키지로 Controller·Service·Mapper를 둔다.

## 하위
- `auth/` — 도메인 `auth` — 인증·로그인·JWT
- `bas/` — 도메인 `bas` — 기준정보(회사·사용자·양식 등)
- `ccp/` — 도메인 `ccp` — 중요관리점(냉장·모니터링 등)
- `code/` — 도메인 `code` — 공통코드
- `common/` — 공통 설정·컨텍스트·예외·응답·검증
- `doc/` — 도메인 `doc` — 문서·결재·파일
- `hyg/` — 도메인 `hyg` — 위생 점검
- `log/` — 도메인 `log` — 화면 조회·UV/PV 로그
- `menu/` — 도메인 `menu` — 메뉴·권한
- `ops/` — 도메인 `ops` — 운영·법적서류 등
- `pref/` — 도메인 `pref` — 사용자 환경설정
- `sys/` — 도메인 `sys` — 시스템 관리
- `tsk/` — 도메인 `tsk` — 오늘 할 일·과제
- `workflow/` — 도메인 `workflow` — 결재 워크플로

## 관련
- 정본: `docs/8_에이전트_가이드_BE.md` · `docs/4_운영규칙_BE.md`
