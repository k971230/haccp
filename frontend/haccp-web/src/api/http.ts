/**
 * http — Axios 3계층 인스턴스 + JWT 주입 + 401 처리.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) OPS_TIMEOUT_TIER — http(일반) / httpBatch(집계·대량 출력) / httpFile(HWPX·PDF) 3계층을 만든다
 *   2) 모든 요청에 Bearer를 붙이고, 401이면 세션을 정리해 로그인 화면으로 보낸다
 *   3) 타임아웃 숫자는 여기에 적지 않는다 — envConfig가 .env에서 읽어 넘긴다(OPS_GLOBAL_CONFIG)
 *
 * PIPELINE[HF3] HTTP 클라이언트
 */
// 역할 — HTTP 클라이언트 라이브러리
import axios, { type AxiosInstance } from "axios";
// 역할 — 요청 시 JWT를 읽어올 인증 스토어
import { useAuthStore } from "@/stores/authStore";
// 역할 — 401 세션 정리·전용 예외 타입
import { handleUnauthorized, UnauthorizedError } from "@/shell/authSession";
// 역할 — 타임아웃 3계층 설정값 (OPS_GLOBAL_CONFIG)
import {
  API_TIMEOUT_BATCH_MS,
  API_TIMEOUT_DEFAULT_MS,
  API_TIMEOUT_FILE_MS,
} from "@/config/envConfig";

/**
 * API 서버 베이스 주소.
 * 운영은 같은 출처에서 /api 를 프록시하므로 빈 문자열, 개발은 haccp-api 기본 포트 8081을 쓴다.
 */
const baseURL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8081";

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) Axios 오류 본문에서 서버 업무 문구(message)를 꺼낸다
 *   2) responseType=blob·arraybuffer 일 때(= 서명·HWP 다운로드) 오류 JSON도 바이너리로 오므로 text 파싱한다
 *   3) 문구를 못 찾으면 공통 안내를 반환한다
 */
async function resolveErrorMessage(
  // Axios 거부 사유 — response.data 가 object·Blob·string 일 수 있다
  err: {
    response?: { data?: unknown };
    message?: string;
  }
): Promise<string> {
  const fallback = "요청 처리 중 오류가 발생했습니다.";
  const data = err.response?.data;

  // JSON 객체 응답 — 일반 CRUD
  if (data && typeof data === "object" && !(data instanceof Blob)) {
    const msg = (data as { message?: unknown }).message;
    if (typeof msg === "string" && msg.trim()) return msg.trim();
  }

  // blob 다운로드 실패 — 서버 ErrorResponse JSON이 Blob으로 온다
  if (data instanceof Blob) {
    try {
      const text = (await data.text()).trim();
      if (text) {
        const parsed = JSON.parse(text) as { message?: unknown };
        if (typeof parsed.message === "string" && parsed.message.trim()) {
          return parsed.message.trim();
        }
      }
    } catch {
      // JSON이 아니면 공통 문구
    }
  }

  // arraybuffer 다운로드 실패 — HWP 원본 GET은 responseType=arraybuffer라 ErrorResponse JSON도 바이트로 온다.
  // 이 분기가 없으면 사용자에게 "Request failed with status code 404" 원문이 그대로 보인다
  if (data instanceof ArrayBuffer && data.byteLength > 0) {
    try {
      const text = new TextDecoder("utf-8").decode(data).trim();
      if (text) {
        const parsed = JSON.parse(text) as { message?: unknown };
        if (typeof parsed.message === "string" && parsed.message.trim()) {
          return parsed.message.trim();
        }
      }
    } catch {
      // JSON이 아니면 공통 문구
    }
  }

  // 문자열 본문
  if (typeof data === "string" && data.trim()) {
    try {
      const parsed = JSON.parse(data) as { message?: unknown };
      if (typeof parsed.message === "string" && parsed.message.trim()) {
        return parsed.message.trim();
      }
    } catch {
      return data.trim();
    }
  }

  if (typeof err.message === "string" && err.message.trim()) return err.message.trim();
  return fallback;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 인스턴스에 JWT 주입 요청 인터셉터와 401·오류 응답 인터셉터를 붙인다
 *   2) 세 계층 인스턴스를 만들 때마다 호출한다 — 설정이 갈라지는 것을 막는다
 *   3) 401은 UnauthorizedError로, 그 외는 서버가 준 업무 문구를 담은 Error로 변환한다
 */
function attachInterceptors(instance: AxiosInstance): void {
  // 요청 인터셉터 — 저장된 토큰이 있으면 Authorization 헤더를 붙인다
  instance.interceptors.request.use((config) => {
    const token = useAuthStore.getState().token;
    // token이 있을 때(= 로그인 상태) Bearer를 붙인다. 로그인 API는 토큰이 없어도 통과한다
    if (token) config.headers.Authorization = `Bearer ${token}`;
    return config;
  });

  // 응답 인터셉터 — 401은 세션 정리, 그 외는 서버 업무 문구를 그대로 올린다
  instance.interceptors.response.use(
    (res) => res,
    async (err) => {
      // 401일 때(= 토큰 없음·만료·위조) 세션을 비우고 로그인 화면으로 보낸다
      if (err.response?.status === 401) {
        const data = err.response?.data;
        let message = "로그인이 필요합니다.";
        if (data && typeof data === "object" && !(data instanceof Blob)) {
          const msg = (data as { message?: unknown }).message;
          if (typeof msg === "string" && msg.trim()) message = msg.trim();
        }
        handleUnauthorized();
        // 전용 예외로 감싸 화면 catch에서 중복 토스트를 억제할 수 있게 한다
        return Promise.reject(new UnauthorizedError(message));
      }
      // 400·409·500 등 — blob JSON 포함해 서버 업무 문구를 우선한다
      const message = await resolveErrorMessage(err);
      return Promise.reject(new Error(message));
    }
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 지정한 타임아웃으로 Axios 인스턴스를 만들고 공통 인터셉터를 붙인다
 *   2) 아래 3계층 export를 만들 때만 호출한다
 *   3) baseURL·인터셉터가 동일하게 적용된 인스턴스를 반환한다
 */
function createHttpClient(
  // 이 인스턴스의 요청 제한 시간(ms) — envConfig가 .env에서 읽은 값
  timeoutMs: number
): AxiosInstance {
  const instance = axios.create({ baseURL, timeout: timeoutMs });
  attachInterceptors(instance);
  return instance;
}

/** 일반 CRUD·조회·validate-delete — VITE_API_TIMEOUT_DEFAULT (기본 10초) */
export const http = createHttpClient(API_TIMEOUT_DEFAULT_MS);

/** 감사자료 묶음 출력·기간 집계 등 장시간 처리 — VITE_API_TIMEOUT_BATCH (기본 60초) */
export const httpBatch = createHttpClient(API_TIMEOUT_BATCH_MS);

/** HWPX 업로드·PDF 변환 등 대용량 파일 — VITE_API_TIMEOUT_FILE (기본 120초) */
export const httpFile = createHttpClient(API_TIMEOUT_FILE_MS);
