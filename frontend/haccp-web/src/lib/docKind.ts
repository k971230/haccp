/**
 * docKind — 양식·문서 유형 코드(hwp | html) 정규화·판별 유틸.
 *
 * 개발자: 박승우
 * 일자: 2026-08-13
 * 코멘트:
 *   1) DB 정본은 대문자 HWP·HTML 이다 (04_migrate_code_upper.sql 에서 올렸다)
 *   2) 화면 비교·라벨·송신은 이 유틸만 쓴다 — 대문자 리터럴을 화면마다 두지 않는다
 *   3) 레거시 소문자·DB·hwpx 가 섞여 와도 같은 값으로 본다
 */

// 한글 문서작성형 — rhwp 편집기 + HWP/HWPX 원본 파일
export const DOC_KIND_HWP = "HWP";
// DB 입력형 — 전용 HTML 화면 + DB 저장 (물리 원본 없음)
export const DOC_KIND_HTML = "HTML";

/**
 * 개발자: 박승우
 * 일자: 2026-08-13
 * 코멘트:
 *   1) 서버·그리드에서 온 유형값을 정본 대문자로 바꾼다
 *   2) 비교·필터·콤보 값 정규화에 쓴다
 *   3) 빈 값일 때(= 미지정) 빈 문자열을 그대로 돌려준다
 */
export function toDocKind(
  // 원본 유형값 — hwp·html·HWP·DB·hwpx 모두 허용
  value?: string | null,
): string {
  const kind = String(value ?? "").trim().toUpperCase();
  if (kind === "HWP" || kind === "HWPX") return DOC_KIND_HWP;
  if (kind === "HTML" || kind === "DB") return DOC_KIND_HTML;
  return kind;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-13
 * 코멘트:
 *   1) 한글 문서작성형인지 판별한다
 *   2) HWP 전용 화면·버튼 가드에 쓴다
 *   3) html·빈 값일 때(= 대상 아님) false
 */
export function isHwpKind(
  // 판별할 유형값
  value?: string | null,
): boolean {
  return toDocKind(value) === DOC_KIND_HWP;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-13
 * 코멘트:
 *   1) 목록 타입 컬럼·상세 헤더에 쓸 한글 라벨을 만든다
 *   2) 그리드 표시 전용 — 저장·비교에는 쓰지 않는다
 *   3) 알 수 없는 값일 때(= 신규 유형) 원본 문자열을 그대로 보여준다
 */
export function docKindLabel(
  // 라벨로 바꿀 유형값
  value?: string | null,
): string {
  const kind = toDocKind(value);
  if (kind === DOC_KIND_HWP) return "한글형";
  if (kind === DOC_KIND_HTML) return "DB형";
  return kind;
}
