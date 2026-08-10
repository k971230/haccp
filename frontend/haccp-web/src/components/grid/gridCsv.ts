/** 그리드 CSV보내기 (UTF-8 BOM, 엑셀 한글). 
 * PIPELINE[F164]
 */
// 역할 — 그리드 컬럼 정의 타입
import type { GridColumn } from "@/types/grid";

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) CSV 파일 생성·다운로드 — UTF-8 BOM으로 엑셀 한글 호환
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — CSV 파일 생성·다운로드 — UTF-8 BOM으로 엑셀 한글 호환
export function exportCsv<T extends Record<string, unknown>>(
  filename: string,
  cols: GridColumn<T>[],
  rows: T[],
  text: (row: T, c: GridColumn<T>) => string,
) {
// 설명 — 셀 값 이스케이프 — 따옴표 이중화
  const esc = (s: string) => `"${(s ?? "").replace(/"/g, '""')}"`;
  const head = cols.map((c) => esc(c.header)).join(",");
  const body = rows.map((r) => cols.map((c) => esc(text(r, c))).join(",")).join("\n");
// 설명 — BOM + CSV blob → 임시 a 태그 클릭 다운로드
  const blob = new Blob(["\uFEFF" + head + "\n" + body], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `${filename}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}
