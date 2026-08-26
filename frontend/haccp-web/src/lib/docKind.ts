/**
 * docKind — 양식·문서 유형 코드(HWP | HTML) 판별 유틸.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) DB 정본은 대문자 HWP·HTML 이다
 *   2) 화면 비교·라벨은 이 유틸만 쓴다 — 대문자 리터럴을 화면마다 두지 않는다
 *   3) 저장값과 다른 표기는 다른 값이다. 소문자·별칭을 같게 보지 않는다
 */

// 한글 문서작성형 — rhwp 편집기 + HWP/HWPX 원본 파일
export const DOC_KIND_HWP = "HWP";
// DB 입력형 — 전용 HTML 화면 + DB 저장 (물리 원본 없음)
export const DOC_KIND_HTML = "HTML";

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 한글 문서작성형인지 판별한다
 *   2) HWP 전용 화면·버튼 가드에 쓴다
 *   3) HTML·빈 값일 때(= 대상 아님) false
 */
export function isHwpKind(
  // 판별할 유형값 — HWP 만 true
  value?: string | null,
): boolean {
  return value === DOC_KIND_HWP;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 목록 타입 컬럼·상세 헤더에 쓸 한글 라벨을 만든다
 *   2) 그리드 표시 전용 — 저장·비교에는 쓰지 않는다
 *   3) 알 수 없는 값일 때(= 신규 유형) 원본 문자열을 그대로 보여준다
 */
export function docKindLabel(
  // 라벨로 바꿀 유형값
  value?: string | null,
): string {
  if (value === DOC_KIND_HWP) return "한글형";
  if (value === DOC_KIND_HTML) return "DB형";
  return value ?? "";
}
