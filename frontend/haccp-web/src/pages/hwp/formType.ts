/**
 * formType — 사용양식 구분(시스템양식 / 자사양식) 표시·판정 정본.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) DB sys_yn 은 sys/usr 이 정본이고 레거시 Y/N 값이 남아 있어 판정을 한 곳으로 모은다
 *   2) 사용양식관리·문서주기관리가 구분 badge·삭제 가능 판정에 함께 쓴다
 *   3) 라벨은 화면 문구 정본 — 화면마다 다른 문구를 쓰지 않는다
 *
 * PIPELINE[HF123] 사용양식 구분
 */

/** 구분 코드 → 화면 문구. 레거시 Y/N 도 같은 라벨로 보이게 둔다 */
export const FORM_TYPE_LABEL: Record<string, string> = {
  sys: "시스템양식",
  usr: "자사양식",
  Y: "시스템양식",
  N: "자사양식",
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 자사양식(usr·레거시 N)인지 판정한다
 *   2) 삭제 가능 판정·구분 badge 색 결정에서 호출한다
 *   3) 값이 비었을 때(= 서버가 구분을 안 준 옛 응답) 시스템양식으로 보아 삭제를 막는다
 */
export function isCompanyForm(
  // 서버 sysYn — sys/usr 또는 레거시 Y/N
  sysYn?: string | null,
): boolean {
  const value = String(sysYn ?? "").toLowerCase();
  return value === "usr" || value === "n";
}
