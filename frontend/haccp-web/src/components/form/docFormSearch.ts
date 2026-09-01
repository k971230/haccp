/**
 * docFormSearch — 문서함·결재첨부 검색 조건 기본값.
 *
 * 개발자: 박승우
 * 일자: 2026-09-01
 * 코멘트:
 *   1) 검색 UI 는 만들지 않는다. 화면이 HtmlFormDraftPage 와 같은 SearchArea 를 직접 쓴다
 *   2) 당월 1일~오늘 YYYYMMDD 만 여기서 채운다
 *   3) 문서함·결재첨부 둘이 같은 기본 기간을 쓴다
 *
 * PIPELINE[HF120] 문서 검색 기본값
 */
/** 공통 검색 조건 — API·세션과 동일 camelCase */
export type DocFormSearchValues = {
  // 시작일 YYYYMMDD
  fromDt: string;
  // 종료일 YYYYMMDD
  toDt: string;
  // 문서번호 부분검색
  docNo: string;
  // 작성자 ID·이름 부분검색
  writer: string;
};

/** 기본 검색 기간 — 당월 1일~오늘 */
export function defaultDocFormSearch(): DocFormSearchValues {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  const d = String(now.getDate()).padStart(2, "0");
  return {
    fromDt: `${y}${m}01`,
    toDt: `${y}${m}${d}`,
    docNo: "",
    writer: "",
  };
}
