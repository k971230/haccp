/**
 * authApi — 로그인·로그아웃·현재 사용자 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) /api/v1/auth/{login,logout,me} 세 엔드포인트를 감싼다
 *   2) mes-web과 다른 점 — 회사 콤보 조회가 없다. 아이디가 전역 유일해서 로그인 화면에 회사 선택이 없다
 *   3) 회사코드를 요청에 담지 않는다 — 서버가 아이디로 소속 회사를 판정하고 JWT에 넣어 돌려준다
 *
 * PIPELINE[HF4] API 레이어
 */
// 역할 — 일반 타임아웃 Axios 인스턴스
import { http } from "./http";
// 역할 — 공통 응답·로그인 응답 타입
import type { CommonResponse, LoginResponse, LoginUser } from "@/types/common";

/** 로그인 요청 파라미터 — 아이디·비밀번호만. 회사코드는 보내지 않는다 */
export interface LoginParams {
  userId: string;
  password: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 아이디·비밀번호로 로그인해 토큰·사용자·화면권한을 받는다
 *   2) 로그인 화면의 확인 버튼에서 호출한다
 *   3) 성공 시 LoginResponse를 반환하고, 실패 시 서버 업무 문구를 담은 Error를 던진다
 */
export async function login(
  // 로그인 입력값 — 아이디와 평문 비밀번호. 비밀번호는 저장하지 않고 이 호출에만 사용한다
  params: LoginParams
): Promise<LoginResponse> {
  const { data } = await http.post<CommonResponse<LoginResponse>>("/api/v1/auth/login", params);
  return data.data;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 서버에 로그아웃을 알려 로그인 이력에 종료 시각을 남긴다
 *   2) 로그아웃 버튼에서 세션을 지우기 전에 호출한다
 *   3) 실패해도 예외를 던지지 않는다 — 이력 기록 실패가 로그아웃을 막아서는 안 된다
 */
export async function logout(): Promise<void> {
  try {
    await http.post<CommonResponse<null>>("/api/v1/auth/logout");
  } catch {
    // 네트워크 단절·토큰 만료 등 — 어차피 클라이언트 세션은 아래에서 지워진다
  }
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 현재 토큰으로 인식되는 로그인 사용자 정보를 조회한다
 *   2) 새로고침 후 보관된 세션이 서버에서도 유효한지 확인할 때 호출한다
 *   3) 유효하면 LoginUser를 반환하고, 만료·위조면 401이 되어 http 인터셉터가 로그인 화면으로 보낸다
 */
export async function getMe(): Promise<LoginUser> {
  const { data } = await http.get<CommonResponse<LoginUser>>("/api/v1/auth/me");
  return data.data;
}
