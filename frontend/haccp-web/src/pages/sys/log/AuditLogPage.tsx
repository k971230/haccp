/**
 * AuditLogPage — 변경 감사 로그 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 렌더는 LogPageShell이 하고 이 파일은 규칙을 주입하는 얇은 진입점이다
 *   2) key에 화면코드를 넣어 탭 전환·재마운트 시 다른 로그 화면과 상태가 섞이지 않게 한다
 *   3) 조회 전용이라 CRUD 명령을 등록하지 않는다
 *
 * PIPELINE[HF99] 변경 감사 로그
 */
// 역할 — 로그 3화면 공통 셸
import { LogPageShell } from "./LogPageShell";
// 역할 — 감사 로그 컬럼·조회 설정
import { AUDIT_LOG_RULE } from "./AuditLogRule";

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 감사 로그 셸을 마운트한다
 *   2) audit-log 화면에서 마운트한다
 *   3) 상태는 셸 인스턴스가 갖는다
 */
export default function AuditLogPage() {
  return <LogPageShell key={AUDIT_LOG_RULE.scrnCd} rule={AUDIT_LOG_RULE} />;
}
