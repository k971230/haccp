/**
 * errors — 예외를 사용자 업무 문구로 바꿔 토스트로 알린다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 화면마다 흩어지던 catch 처리(문구 만들기 + 토스트 띄우기)를 한 함수로 모은다
 *   2) 서버가 내려준 업무 문구는 그대로 보여주고, PostgreSQL JDBC가 붙이는 ERROR:·Where: 기술 정보는 잘라낸다
 *   3) nginx HTML(413 Request Entity Too Large 등)은 업무 문구로 바꾼다. 마크업을 토스트에 넣지 않는다
 *
 * PIPELINE[HF54] 셸 인프라
 * PIPELINE[HF49] 연관 — 셸
 */
// 역할 — 오류 토스트 표시
import { mesToast } from "./dialog";
// 역할 — 기본 오류 문구 카탈로그
import { MES } from "./messages";
// 역할 — 401 여부 판정 (중복 토스트 억제)
import { isUnauthorizedError } from "./authSession";

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 예외를 사용자 문구로 바꿔 토스트로 띄우고 그 문구를 반환한다
 *   2) 화면 catch에서는 mesError(e)만 호출한다 — mesToast(mesError(e), "error")는 토스트가 두 번 뜬다
 *   3) 401이면 토스트를 띄우지 않는다. 이미 로그인 화면으로 이동했기 때문에 안내가 겹친다
 */
export function mesError(
  // 잡은 예외 — Axios Error, 문자열, 그 외 무엇이든 받는다
  e: unknown,
  // 문구를 만들 수 없을 때 쓸 기본 안내 — 기본값은 공통 서버 오류 문구
  fallback: string = MES.serverError
): string {
  if (isUnauthorizedError(e)) return (e as Error).message;
  const msg = toUserMessage(e, fallback);
  // 여기서 이미 error 토스트를 띄운다 — 호출부에서 mesToast로 감싸지 말 것
  mesToast(msg, "error");
  return msg;
}

/** PostgreSQL JDBC 메시지에서 업무 문구만 남긴다 — 백엔드 SqlUserMessage와 같은 규칙 */
function stripDbTechnicalMessage(raw: string): string {
  let msg = raw.trim();
  // ERROR: 접두어 제거
  if (/^ERROR:/i.test(msg)) msg = msg.slice(6).trim();
  // Where: 이후는 PL/pgSQL 호출 위치라 사용자에게 의미가 없다
  const cut = msg.search(/\n\s*Where:| Where: PL\/pgSQL| Where:/);
  if (cut >= 0) msg = msg.slice(0, cut).trim();
  // 남은 문구가 없으면 기술 원문을 다시 노출하지 않고 기본 문구를 쓴다
  return msg || "처리할 수 없습니다.";
}

/** nginx·Apache 가 내려주는 HTML 오류 페이지인지 */
function looksLikeHtml(raw: string): boolean {
  const t = raw.trimStart();
  return /^<!DOCTYPE html/i.test(t) || /^<html[\s>]/i.test(t) || /<\/html>/i.test(t);
}

/** 413 Request Entity Too Large — 상태코드 없이 HTML 원문만 남은 경우 */
function isPayloadTooLarge(raw: string): boolean {
  return /request entity too large/i.test(raw);
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) HTTP 본문·Error.message 에서 사용자에게 보여줄 문구만 남긴다
 *   2) http 인터셉터와 toUserMessage 가 같이 쓴다 — nginx HTML 을 두 곳에서 다르게 바꾸지 않는다
 *   3) 413 이면 용량 안내, 그 밖 HTML 은 서버 오류. JSON 업무 문구는 DB 기술 정보만 자른다
 */
export function sanitizeUserErrorText(
  // 서버·프록시가 준 원문 — JSON message 또는 HTML
  raw: string,
  // HTTP 상태. 413 이면 본문을 보지 않고 용량 안내
  status?: number,
): string {
  const text = raw.trim();
  if (!text) return MES.serverError;
  if (status === 413 || isPayloadTooLarge(text)) return MES.fileTooLarge;
  if (/^network error$/i.test(text)
      || /err_connection_reset/i.test(text)
      || /err_connection_aborted/i.test(text)
      || /err_connection_refused/i.test(text)) {
    return MES.networkError;
  }
  if (looksLikeHtml(text)) return MES.serverError;
  return stripDbTechnicalMessage(text);
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 예외에서 사용자에게 보여줄 문구만 뽑아낸다 (토스트는 띄우지 않는다)
 *   2) 문구를 화면 안내 영역에만 넣고 싶을 때, 또는 mesError 내부에서 호출한다
 *   3) 413·HTML 은 sanitizeUserErrorText 가 업무 문구로 바꾼 뒤, 서버 업무 문구 → Error.message → fallback
 */
export function toUserMessage(
  // 잡은 예외 — 타입을 가리지 않는다
  e: unknown,
  // 아무 문구도 찾지 못했을 때 쓸 기본 안내
  fallback: string = MES.serverError
): string {
  // 문자열을 그대로 throw한 경우
  if (typeof e === "string" && e.trim()) return sanitizeUserErrorText(e);
  if (e && typeof e === "object") {
    const anyE = e as {
      response?: { status?: number; data?: unknown };
      message?: unknown;
    };
    const status = anyE.response?.status;
    if (status === 413) return MES.fileTooLarge;
    const data = anyE.response?.data;
    // nginx HTML 이 response.data 문자열로 남은 경우
    if (typeof data === "string" && data.trim()) return sanitizeUserErrorText(data, status);
    const apiMsg =
      data && typeof data === "object" && !(data instanceof Blob)
        ? (data as { message?: unknown }).message
        : undefined;
    if (typeof apiMsg === "string" && apiMsg.trim()) return sanitizeUserErrorText(apiMsg, status);
    // http 인터셉터가 이미 message로 옮겨 담은 경우
    if (typeof anyE.message === "string" && anyE.message.trim()) {
      return sanitizeUserErrorText(anyE.message, status);
    }
  }
  return fallback;
}
