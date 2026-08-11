/**
 * main — React 앱 진입점 (Provider·라우터 마운트).
 *
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) 서버 상태 캐시(React Query)와 주소 기반 라우터를 깔고 라우트 트리를 #root에 붙인다
 *   2) basename 은 Vite base(운영 /haccp/) — Apache Path 분기와 자산 URL·클라이언트 라우트 정합
 *   3) 401·로그아웃 시 캐시 비우기·멀티탭 로그아웃 구독을 여기서 한 번만 등록한다
 *
 * PIPELINE[HF1] React 진입점
 * PIPELINE[HF2, HF74, HF114] 연관 모듈
 */
// 역할 — 개발 모드 이중 렌더 검사
import React from "react";
// 역할 — DOM 마운트
import ReactDOM from "react-dom/client";
// 역할 — 서버 상태 캐시 Provider
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
// 역할 — History API 라우터 (배포 시 SPA 폴백 필요)
import { BrowserRouter } from "react-router-dom";
// 역할 — 앱 라우트 트리
import { AppRoutes } from "@/routes/AppRoutes";
// 역할 — 캐시 비우기 콜백 등록·401 처리
import { handleUnauthorized, registerQueryCacheClear } from "@/shell/authSession";
// 역할 — 타 탭 로그아웃 구독
import { subscribeAuthCrossTab } from "@/shell/authCrossTab";
// 역할 — Path basename 포함 로그인 경로 판정
import { isLoginBrowserPath } from "@/shell/authPaths";
// 역할 — 전역 스타일
import "@/styles/global.css";

// 조회 캐시 기본값 — 창을 다시 눌렀다고 재조회하지 않는다(기록 입력 중 값이 튀는 것을 막는다)
const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false, staleTime: 30_000 } },
});

// 세션이 끊길 때 이전 사용자 조회 결과가 남지 않도록 캐시 비우기 방법을 알려 둔다
registerQueryCacheClear(() => queryClient.clear());

// 다른 탭에서 로그아웃했을 때 이 탭도 함께 내려간다 (G-22 · F174)
subscribeAuthCrossTab(() => {
  // 이미 로그인 화면이면 생략 — Path 배포에서는 browser path 가 /haccp/login 이다
  if (isLoginBrowserPath(location.pathname)) return;
  handleUnauthorized();
});

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter
        // Vite base 와 동일 — 운영 Docker 는 /haccp/ , 로컬 dev 는 /
        basename={import.meta.env.BASE_URL}
        // React Router v7 동작 미리 켜기 — 콘솔 경고 방지
        future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
      >
        {/* 업무 화면·가드·레이아웃 트리 */}
        <AppRoutes />
      </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>
);
