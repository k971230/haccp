/**
 * gridNav — 그리드 키보드 좌표.
 * ArrowUp/Down = 행 이동(클램프). Tab = 셀 이동(행 넘김, 그리드 끝이면 null).
 *
 * PIPELINE[F90] MesEditableGrid / MesDataGrid 키보드 네비
 */
// 역할 — 키보드 이벤트 target 판별용 (React KeyboardEvent와 호환)

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 선택 없을 때 Down은 첫 행, Up은 마지막. 끝에서는 순환하지 않고 클램프
 *   2) MesEditableGrid·MesDataGrid 방향키 행이동에서 호출
 *   3) 빈 목록이면 -1 — 호출측이 이동을 건너뛴다
 */
// 설명 — 행 이동: current<0(선택 없음)이면 Down→0, Up→마지막. 그 외엔 클램프(순환 없음)
export function nextRowIndex(len: number, current: number, delta: 1 | -1): number {
  if (len === 0) return -1;
  if (current < 0) return delta === 1 ? 0 : len - 1;
  return Math.max(0, Math.min(len - 1, current + delta));
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) Tab은 옆 칸, 열 끝이면 다음 행 첫 열. Shift+Tab은 반대
 *   2) MesEditableGrid 비편집 Tab에서 호출
 *   3) 그리드 밖이면 null — 호출측이 preventDefault를 하지 않아 네이티브 탭 아웃
 */
// 설명 — Tab 셀 이동: 열 끝에서 다음 행 첫 열, 반대로 Shift+Tab. 그리드 밖이면 null
export function nextCell(
  ri: number,
  ci: number,
  nRows: number,
  nCols: number,
  dCol: 1 | -1,
): { ri: number; ci: number } | null {
  let nextCi = ci + dCol;
  let nextRi = ri;

  if (nextCi >= nCols) {
    nextRi += 1;
    nextCi = 0;
  } else if (nextCi < 0) {
    nextRi -= 1;
    nextCi = nCols - 1;
  }

  if (nextRi < 0 || nextRi >= nRows) return null;
  return { ri: nextRi, ci: nextCi };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 툴바 검색·필터·셀 에디터처럼 타이핑 중이면 방향키를 그리드가 가로채지 않는다
 *   2) wrap onKeyDown에서 isEditing 가드 다음에 호출
 *   3) tbody 체크/라디오는 셀 포커스이므로 false — 선택 열에서도 행이동
 */
// 설명 — 툴바·필터 등 입력 중이면 true. tbody checkbox/radio는 행이동 허용
export function isTypingTarget(e: { target: EventTarget | null }): boolean {
  const el = e.target as HTMLElement | null;
  if (!el || typeof el.closest !== "function") return false;
  const field = el.closest("input, select, textarea, [contenteditable=\"true\"]") as HTMLElement | null;
  if (!field) return false;
  if (field.tagName === "INPUT") {
    const type = (field as HTMLInputElement).type;
    if ((type === "checkbox" || type === "radio") && field.closest("tbody")) return false;
  }
  return true;
}
