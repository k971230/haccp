/**
 * sanitize — 저장 직전 문자열을 다듬는 경량 정리기.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 앞뒤 공백, 보이지 않는 제어문자, 꺽쇠(<>)를 제거해 DB에 이상한 값이 들어가는 것을 막는다
 *   2) HTML을 렌더링하는 용도가 아니라 코드·명칭 입력을 정리하는 수준이다 — 그래서 DOMPurify를 쓰지 않는다
 *   3) React가 출력 시 이스케이프하므로 이 함수는 저장 경로의 1차 방어일 뿐, 유일한 방어가 아니다
 *
 * PIPELINE[HF171] 공통 모듈
 */

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 문자열에서 제어문자·꺽쇠를 지우고 앞뒤 공백을 없앤다
 *   2) 코드·명칭처럼 한 줄 입력을 저장하기 직전에 호출한다
 *   3) 여러 줄 서술(비고·조치내용)에는 쓰지 않는다 — 줄바꿈은 유지되지만 꺽쇠까지 지워 원문이 바뀐다
 */
export function sanitizeText(
  // 사용자 입력 원문
  value: string
): string {
  let out = "";
  for (const ch of value) {
    const code = ch.codePointAt(0) ?? 0;
    // 탭·개행·복귀를 뺀 제어문자 — 붙여넣기로 섞여 들어오면 DB에서 눈에 보이지 않는 값이 된다
    if (code < 0x20 && ch !== "\t" && ch !== "\n" && ch !== "\r") continue;
    // DEL 문자
    if (code === 0x7f) continue;
    // 태그로 오인될 수 있는 꺽쇠
    if (ch === "<" || ch === ">") continue;
    out += ch;
  }
  return out.trim();
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 객체의 문자열 값만 골라 정리한 새 객체를 만든다
 *   2) 그리드에서 저장할 행 목록을 서버로 보내기 직전에 각 행에 적용한다
 *   3) 숫자·불리언·중첩 객체·배열은 손대지 않고 그대로 복사한다
 */
export function sanitizeStringFields<T extends Record<string, unknown>>(
  // 저장 대상 행 객체 — 원본은 바꾸지 않고 복사본을 반환한다
  row: T
): T {
  const out: Record<string, unknown> = { ...row };
  for (const key of Object.keys(out)) {
    const v = out[key];
    if (typeof v === "string") out[key] = sanitizeText(v);
  }
  return out as T;
}
