/**
 * docDateTime — DocForm 셀·메타용 날짜·시각 저장/표시 변환.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) DB는 YYYYMMDD·HHMM, input type=date/time은 YYYY-MM-DD·HH:MM 이다
 *   2) DocCellTime·DocForm 작성 화면이 같은 계약을 쓰도록 한곳에 모은다
 *   3) React 의존 없는 순수 함수다
 *
 * PIPELINE[HF122] DocForm 날짜시각
 */

/**
 * 개발자: 박승우
 * 일자: 2026-08-28
 * 코멘트:
 *   1) YYYYMMDD → input type=date 값(YYYY-MM-DD)으로 바꾼다
 *   2) DocFormMeta·목록 기준일·그리드 date 셀이 쓴다
 *   3) 8자리가 아니거나 **달력에 없는 날**이면 빈 문자열을 반환한다
 *
 * 자리 수만 보면 안 된다. `20240082` 는 8자리라 통과했고 `2024-00-82` 가 만들어졌다.
 * 브라우저가 `<input type=date>` 에서 그 값을 거부하고 콘솔에 경고를 쌓는다 —
 * 실제로 화면에서 그 경고가 계속 났다. 날짜로 되읽어 같은 값인지까지 본다.
 */
export function toInputDate(ymd: string | null | undefined): string {
  const raw = (ymd ?? "").replace(/\D/g, "");
  if (raw.length !== 8) return "";
  const y = Number(raw.slice(0, 4));
  const m = Number(raw.slice(4, 6));
  const d = Number(raw.slice(6, 8));
  // 월·일이 범위 밖일 때(= 00월·82일 같은 값) 날짜가 아니다
  if (m < 1 || m > 12 || d < 1 || d > 31) return "";
  // 2월 30일처럼 자리 수는 맞고 달력엔 없는 날 — Date 가 다음 달로 넘겨 버린다
  const probe = new Date(Date.UTC(y, m - 1, d));
  if (probe.getUTCFullYear() !== y || probe.getUTCMonth() !== m - 1 || probe.getUTCDate() !== d) return "";
  return `${raw.slice(0, 4)}-${raw.slice(4, 6)}-${raw.slice(6, 8)}`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) input type=date 값 → YYYYMMDD로 바꾼다
 *   2) 저장·목록 baseKey에 쓴다
 *   3) 구분자를 제거하고 숫자만 남긴다
 */
export function fromInputDate(value: string | null | undefined): string {
  return (value ?? "").replace(/\D/g, "").slice(0, 8);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) HHMM(또는 HH:MM) → input type=time 값(HH:MM)으로 바꾼다
 *   2) DocCellTime 표시에 쓴다
 *   3) 4자리 미만이면 빈 문자열을 반환한다
 */
export function toInputTime(hhmmOrHm: string | null | undefined): string {
  const raw = (hhmmOrHm ?? "").trim();
  if (!raw) return "";
  if (/^\d{2}:\d{2}/.test(raw)) return raw.slice(0, 5);
  const digits = raw.replace(/\D/g, "");
  if (digits.length < 4) return "";
  return `${digits.slice(0, 2)}:${digits.slice(2, 4)}`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) input type=time 값 → HHMM(4자리)으로 바꾼다
 *   2) Cold·Metal·Hygiene varchar(4) 저장에 쓴다
 *   3) 숫자만 모아 최대 4자리로 자른다
 */
export function fromInputTimeHhmm(value: string | null | undefined): string {
  return (value ?? "").replace(/\D/g, "").slice(0, 4);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) input type=time 값 → HH:MM 문자열로 정규화한다
 *   2) Generic CCP varchar(10) 저장에 쓴다
 *   3) 비어 있으면 빈 문자열을 반환한다
 */
export function fromInputTimeHm(value: string | null | undefined): string {
  const hm = toInputTime(value);
  return hm;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 오늘 날짜를 YYYYMMDD로 만든다
 *   2) 신규 문서 baseKey 기본값에 쓴다
 *   3) 로컬 타임존 기준이다
 */
export function todayYmd(): string {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}${m}${day}`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 서버 타임스탬프를 사용자가 읽는 「YYYY-MM-DD HH:MM」 으로 바꾼다
 *   2) 결재 요청일·처리일처럼 화면에 그대로 노출되는 칸에 쓴다
 *   3) 값이 없거나 해석되지 않으면 대시 한 글자 — ISO 원문을 사용자에게 보여 주지 않는다
 */
export function toDisplayDateTime(value: string | null | undefined): string {
  const raw = (value ?? "").trim();
  if (!raw) return "-";
  const at = new Date(raw);
  if (Number.isNaN(at.getTime())) return "-";
  const y = at.getFullYear();
  const m = String(at.getMonth() + 1).padStart(2, "0");
  const d = String(at.getDate()).padStart(2, "0");
  const hh = String(at.getHours()).padStart(2, "0");
  const mm = String(at.getMinutes()).padStart(2, "0");
  return `${y}-${m}-${d} ${hh}:${mm}`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) YYYYMMDD 를 사용자가 읽는 「YYYY-MM-DD」 로 바꾼다
 *   2) 기준일처럼 화면에 그대로 노출되는 칸에 쓴다
 *   3) 8자리가 아니면 대시 한 글자 — toInputDate 는 input 전용이라 빈 문자열을 준다
 */
export function toDisplayDate(ymd: string | null | undefined): string {
  return toInputDate(ymd) || "-";
}
