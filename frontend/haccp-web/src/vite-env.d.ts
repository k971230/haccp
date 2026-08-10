/// <reference types="vite/client" />

/**
 * .env로 조정하는 값의 타입 선언 (OPS_GLOBAL_CONFIG).
 * envConfig.ts가 읽는 키와 1:1로 맞춘다 — 여기에 없는 키를 참조하면 컴파일 단계에서 걸린다.
 */
interface ImportMetaEnv {
  /** API 서버 주소 — 비우면 같은 출처로 요청한다 */
  readonly VITE_API_BASE_URL?: string;
  readonly VITE_API_TIMEOUT_DEFAULT?: string;
  readonly VITE_API_TIMEOUT_BATCH?: string;
  readonly VITE_API_TIMEOUT_FILE?: string;
  /** rhwp-studio HTTP(S) URL — 비우면 동일출처 /rhwp/ */
  readonly VITE_RHWP_STUDIO_URL?: string;
  readonly VITE_GRID_DEFAULT_PAGE_SIZE?: string;
  readonly VITE_GRID_VIRTUAL_THRESHOLD?: string;
  readonly VITE_SEARCH_DEBOUNCE_MS?: string;
  readonly VITE_API_RETRY_COUNT?: string;
  readonly VITE_DASHBOARD_POLLING_MS?: string;
  readonly VITE_VIEW_LOG_FLUSH_MS?: string;
  readonly VITE_TOAST_DURATION_MS?: string;
  readonly VITE_TOAST_ERROR_DURATION_MS?: string;
}
interface ImportMeta {
  readonly env: ImportMetaEnv;
}
