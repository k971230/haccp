/**
 * envConfig — .env 값을 한곳에서 파싱하는 전역 설정 (OPS_GLOBAL_CONFIG).
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 타임아웃·페이지 크기·폴링 주기처럼 운영 중 조정될 수 있는 숫자는 전부 여기로 모은다
 *   2) 소스 곳곳에 숫자를 박아두면 운영값을 바꿀 때 재배포가 필요해진다 — 그래서 매직 넘버를 금지한다
 *   3) 미설정·잘못된 값이면 권장 기본값으로 되돌린다. .env를 고친 뒤에는 Vite를 재시작해야 반영된다
 *
 * PIPELINE[HF31] 전역 설정
 * PIPELINE[HF3] 연관 — http 타임아웃 3계층
 */

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 환경변수 문자열을 양의 정수로 바꾼다
 *   2) 아래 export 상수를 만들 때만 호출한다
 *   3) 비었거나 숫자가 아니거나 0 이하면 fallback을 반환한다 — 오타 하나로 앱이 멈추지 않게 한다
 */
function parsePositiveInt(
  // .env에서 읽은 원문 — Vite는 값이 없으면 undefined를 준다
  raw: string | undefined,
  // 유효한 값이 없을 때 쓸 권장 기본값
  fallback: number
): number {
  // raw가 없거나 공백뿐일 때(= 미설정)
  if (raw == null || raw.trim() === "") return fallback;
  const n = Number.parseInt(raw.trim(), 10);
  // 유한 양수가 아닐 때(= 오타·음수 등 잘못된 설정)
  if (!Number.isFinite(n) || n <= 0) return fallback;
  return n;
}

/** 일반 CRUD·조회 타임아웃(ms) — 기록 저장, 코드 조회 등 대부분의 호출 */
export const API_TIMEOUT_DEFAULT_MS = parsePositiveInt(
  import.meta.env.VITE_API_TIMEOUT_DEFAULT,
  10_000
);

/** 배치 타임아웃(ms) — 감사자료 묶음 출력, 기간 집계처럼 수십 초가 걸리는 처리 */
export const API_TIMEOUT_BATCH_MS = parsePositiveInt(
  import.meta.env.VITE_API_TIMEOUT_BATCH,
  60_000
);

/** 파일 타임아웃(ms) — HWPX 업로드·다운로드, 서버 PDF 변환 */
export const API_TIMEOUT_FILE_MS = parsePositiveInt(
  import.meta.env.VITE_API_TIMEOUT_FILE,
  120_000
);

/** 그리드·목록 기본 페이지 크기 */
export const GRID_DEFAULT_PAGE_SIZE = parsePositiveInt(
  import.meta.env.VITE_GRID_DEFAULT_PAGE_SIZE,
  50
);

/** 그리드 행 가상화 임계 — 이 행 수 이상이면 가상 스크롤로 전환한다 */
export const GRID_VIRTUAL_THRESHOLD = parsePositiveInt(
  import.meta.env.VITE_GRID_VIRTUAL_THRESHOLD,
  100
);

/** 검색 입력 debounce(ms) — 조회 픽커에서 타이핑 중 과다 호출을 막는다 */
export const SEARCH_DEBOUNCE_MS = parsePositiveInt(
  import.meta.env.VITE_SEARCH_DEBOUNCE_MS,
  300
);

/** GET 재시도 횟수 — 일시적 네트워크 단절 방어 */
export const API_RETRY_COUNT = parsePositiveInt(
  import.meta.env.VITE_API_RETRY_COUNT,
  2
);

/** 오늘 할 일·대시보드 자동 새로고침 주기(ms) */
export const DASHBOARD_POLLING_MS = parsePositiveInt(
  import.meta.env.VITE_DASHBOARD_POLLING_MS,
  10_000
);

/** 화면 조회 로그 전송 주기(ms) — 모아둔 UV/PV 이벤트를 이 간격으로 배치 전송한다 */
export const VIEW_LOG_FLUSH_MS = parsePositiveInt(
  import.meta.env.VITE_VIEW_LOG_FLUSH_MS,
  30_000
);

/** 일반 토스트 표시 시간(ms) — 저장 완료처럼 읽고 넘기면 되는 안내 */
export const TOAST_DURATION_MS = parsePositiveInt(
  import.meta.env.VITE_TOAST_DURATION_MS,
  2_600
);

/** 오류 토스트 표시 시간(ms) — 원인을 읽을 시간이 필요해 더 길게 둔다 */
export const TOAST_ERROR_DURATION_MS = parsePositiveInt(
  import.meta.env.VITE_TOAST_ERROR_DURATION_MS,
  5_000
);
