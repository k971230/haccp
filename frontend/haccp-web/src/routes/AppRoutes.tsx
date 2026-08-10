/**
 * AppRoutes — 로그인 화면과 앱 셸을 주소로 가른다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) /login만 공개다. 그 밖의 모든 주소는 토큰 검사를 통과해야 셸이 마운트된다
 *   2) 만료·손상된 토큰이 저장소에 남아 있으면 먼저 지운다 — 셸이 반쯤 열린 상태로 오류가 쏟아지는 것을 막는다
 *   3) 셸 안의 화면 전환은 라우터 중첩이 아니라 화면 레지스트리가 담당한다(탭 keep-alive 때문)
 *
 * PIPELINE[HF2] 라우팅 분기
 */
// 역할 — 만료 토큰 정리
import { useEffect } from "react";
// 역할 — 라우트 정의·리다이렉트·현재 주소
import { Navigate, Route, Routes, useLocation } from "react-router-dom";
// 역할 — 로그인 화면
import { LoginPage } from "@/pages/auth/LoginPage";
// 역할 — 앱 셸
import { HaccpShell } from "@/shell/HaccpShell";
// 역할 — 저장된 토큰 조회
import { useAuthStore } from "@/stores/authStore";
// 역할 — 토큰 검사·복귀 경로 저장·세션 정리
import { clearAuthSession, isTokenValid, saveReturnUrl } from "@/shell/authSession";

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 유효한 토큰이 있을 때만 자식(셸)을 렌더하고, 없으면 로그인 화면으로 보낸다
 *   2) 보호가 필요한 모든 라우트를 이 컴포넌트로 감싼다
 *   3) 리다이렉트 전에 원래 주소를 저장해 로그인 후 그 화면으로 되돌린다
 */
function Protected({ children }: { children: React.ReactNode }) {
  const location = useLocation();
  const token = useAuthStore((s) => s.token);
  // 서명이 아니라 만료만 본다 — 최종 검증은 서버가 한다
  const valid = isTokenValid(token);

  // 토큰이 있지만 무효할 때(= 만료·손상) 저장소를 먼저 비운다
  useEffect(() => {
    if (token && !valid) clearAuthSession();
  }, [token, valid]);

  if (!valid) {
    const from = location.pathname + location.search;
    // 새로고침으로 state가 사라지는 경우까지 대비해 sessionStorage에도 남긴다
    saveReturnUrl(from);
    return <Navigate to="/login" replace state={{ from }} />;
  }
  return <>{children}</>;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 앱 전체 라우트를 정의한다
 *   2) main.tsx가 라우터 안에 한 번 마운트한다
 *   3) 알 수 없는 주소는 셸로 보내고, 셸이 홈 화면을 보여준다
 */
export function AppRoutes() {
  return (
    <Routes>
      {/* 공개 — 로그인 */}
      <Route path="/login" element={<LoginPage />} />
      {/* 그 외 전부 — 인증 통과 시 셸. 화면 전환은 셸 내부에서 처리한다 */}
      <Route path="/*" element={<Protected><HaccpShell /></Protected>} />
    </Routes>
  );
}
