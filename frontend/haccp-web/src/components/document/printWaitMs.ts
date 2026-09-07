/**
 * printWaitMs — 인쇄 대화상자 상한.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) HTML 일괄 인쇄와 HWP iframe 인쇄가 같은 숫자를 쓴다
 *   2) afterprint 가 안 오면 이 뒤에 끝낸다. 대화상자를 닫을 때까지 기다린다
 *   3) API_TIMEOUT_FILE_MS 와 합치지 않는다 — 그건 axios 네트워크 상한이다
 *
 * PIPELINE[HF187] 인쇄 대기
 */

/** 인쇄 대화상자 상한 ms — afterprint 가 안 오면 이 뒤에 끝낸다 */
export const PRINT_DIALOG_WAIT_MS = 180_000;
