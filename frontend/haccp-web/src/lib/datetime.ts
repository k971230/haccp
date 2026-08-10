/**
 * datetime — 서버가 받는 문자열 형식으로 날짜·시각을 만든다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 백엔드 LocalDateTime은 "2026-08-05T13:24:01" 형태만 받는다 — 밀리초·타임존이 붙으면 파싱에 실패한다
 *   2) Date.toISOString은 UTC로 바꿔 버려서 국내 시각과 9시간 차이가 난다. 그래서 직접 조립한다
 *   3) React·UI 의존이 없는 순수 함수다
 *
 * PIPELINE[HF35] 공통 모듈
 */

/** 한 자리 수를 두 자리로 채운다 — 2026-8-5가 아니라 2026-08-05가 되도록 */
function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) Date를 로컬 시각 기준 "YYYY-MM-DDTHH:mm:ss" 문자열로 만든다
 *   2) 화면 조회 로그처럼 시각을 서버로 보낼 때 호출한다
 *   3) 초 단위까지만 남기고 밀리초는 버린다
 */
export function formatLocalDateTime(
  // 변환할 시각 — 생략하면 현재 시각
  d: Date = new Date()
): string {
  return (
    `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}` +
    `T${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`
  );
}
