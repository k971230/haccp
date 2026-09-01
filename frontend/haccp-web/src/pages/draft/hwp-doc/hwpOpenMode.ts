/**
 * hwpOpenMode — HWP 편집기가 양식 원본을 열지, 작성본을 열지, 기다릴지.
 *
 * 개발자: 박승우
 * 일자: 2026-09-01
 * 코멘트:
 *   1) 저장된 문서인데 본문 첨부가 아직 없으면 양식 원본을 열지 않는다
 *   2) HwpEditorPane 이 행을 바꿀 때 호출한다
 *   3) wait 인데 원본을 열면 빈 양식이 작성본을 덮는다
 *
 * PIPELINE[HF186] HWP 열기 판정
 */

/** 편집기에 실을 대상 — 작성본 / 양식 원본 / 첨부 대기 */
export type HwpOpenMode = "source" | "template" | "wait";

/**
 * 개발자: 박승우
 * 일자: 2026-09-01
 * 코멘트:
 *   1) 본문 첨부가 있으면 작성본, 저장 전이면 양식 원본, 저장 문서인데 첨부가 없으면 대기
 *   2) HwpEditorPane 로드 효과가 호출한다
 *   3) wait 는 원본 loadFile 금지
 */
export function hwpOpenMode(
  // 저장된 문서 idx. 없으면 신규
  docIdx: number | null | undefined,
  // 첨부 목록에 HWP_SRC 가 있는지
  hasSource: boolean,
): HwpOpenMode {
  if (hasSource) return "source";
  if (docIdx != null && docIdx > 0) return "wait";
  return "template";
}
