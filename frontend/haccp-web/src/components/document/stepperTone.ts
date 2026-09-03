/**
 * stepperTone — 결재 스테퍼 칸 색 정본.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 결재첨부 3칸 스테퍼와 문서함 결재선 스테퍼가 같은 색을 쓴다
 *   2) 완료 파랑 · 현재 노랑 · 반려 빨강 · 아직 아님 회색
 *   3) 현재 칸을 파랑으로 칠하면 끝난 것처럼 보인다
 *
 * PIPELINE[HF185] 결재 첨부 스테퍼
 * PIPELINE[HF187] 문서함 결재 스테퍼
 */

/** 스테퍼 칸 상태 — 완료·현재·대기·반려 */
export type StepperTone = "done" | "active" | "pending" | "rejected";

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 스테퍼 점·라벨·연결선 클래스를 고른다
 *   2) ApprovalLineSteps·attachStepperToneClass 가 호출한다
 *   3) 색을 바꾸면 두 화면이 같이 바뀐다
 */
export function stepperToneClass(
  // 칸 상태
  tone: StepperTone,
): { dot: string; label: string; line: string } {
  if (tone === "rejected") {
    return { dot: "bg-red-600", label: "text-red-700", line: "bg-red-300" };
  }
  if (tone === "active") {
    return { dot: "bg-amber-500", label: "text-amber-700", line: "bg-amber-300" };
  }
  if (tone === "done") {
    return { dot: "bg-blue-600", label: "text-blue-700", line: "bg-blue-300" };
  }
  return { dot: "bg-slate-200", label: "text-slate-400", line: "bg-slate-200" };
}
