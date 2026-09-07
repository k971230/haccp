/**
 * LoginPage — 아이디·비밀번호 로그인 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) 로그인 성공 시 선호값 저장 → 토큰 보관 위치 결정 → 캐시 초기화 → 세션 적재 → 원래 보던 화면으로 이동한다
 *   2) mes-web과 달리 회사 선택이 없다 — 아이디가 전 업체 통틀어 유일해서 서버가 소속 회사를 판정한다
 *   3) UI는 MES 스플릿(좌측 login_bg + 우측 흰 폼)이며, 이미 유효한 토큰이 있으면 홈으로 보낸다
 *
 * PIPELINE[HF115] 로그인 화면
 * PIPELINE[HF4, HF29, HF160, HF161, HF162] 연관 모듈
 */
// 역할 — 폼 상태·토큰 확인 effect
import { useEffect, useState } from "react";
// 역할 — 로그인 후 이동·복귀 경로 state 읽기
import { useLocation, useNavigate } from "react-router-dom";
// 역할 — 이전 사용자 캐시 제거
import { useQueryClient } from "@tanstack/react-query";
// 역할 — 로그인 API
import { login } from "@/api/authApi";
// 역할 — 세션 적재·토큰 보관 위치 전환
import { applyAuthPersistStorage, useAuthStore } from "@/stores/authStore";
// 역할 — 예외를 사용자 문구로 변환 (토스트 없이)
import { toUserMessage } from "@/shell/errors";
// 역할 — 토큰 유효성·로그인 후 이동 경로
import { isTokenValid, resolvePostLoginPath } from "@/shell/authSession";
import { AUTH_FAIL_CODE_KEY } from "@/shell/authKeys";
// 역할 — 아이디 저장·자동 로그인 선호값
import { loadLoginPrefs, saveLoginPrefs } from "@/shell/loginPrefs";
// 역할 — 중복 제출 방지
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 로그인 입력 공통 스타일
import { loginInputClass } from "@/components/ui/Input";
/*
 * 역할 — 좌측 브랜드 배경.
 * 2026-08-26 에 PNG(1565KB) 를 JPEG(84KB) 로 바꿨다 — 1376x768 사진이라 PNG 로 둘 이유가 없고,
 * 전 화소가 불투명이라 알파를 잃지 않는다. 첫 화면이 1.5MB 덜 내려간다.
 */
import loginBg from "@/static/img/login_bg.jpg";
// 역할 — 우측 패널 상단 HACCP 공식 인증 마크
import haccpLogo from "@/static/img/haccp_logo.png";

/** 저장된 선호값으로 폼 초기값을 만든다 — 아이디 저장이 OFF면 빈 값으로 시작한다 */
function initialLoginForm() {
  const prefs = loadLoginPrefs();
  const hasSavedId = prefs.saveId && !!prefs.userId;
  return {
    userId: hasSavedId ? (prefs.userId ?? "") : "",
    saveId: prefs.saveId,
    autoLogin: prefs.autoLogin,
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) MES와 같은 스플릿 레이아웃으로 로그인 폼을 그리고 인증 성공 시 세션을 적재한다
 *   2) 인증이 없는 상태로 앱에 들어오면 라우터가 이 화면으로 보낸다
 *   3) 실패하면 폼 아래에 사유를 표시하고 비밀번호 입력을 유지한다 — 재입력 부담을 줄인다
 */
export function LoginPage() {
  const nav = useNavigate();
  const loc = useLocation();
  const setAuth = useAuthStore((s) => s.setAuth);
  const token = useAuthStore((s) => s.token);
  const qc = useQueryClient();
  const { run, isBusy } = useAsyncAction();
  // 보호 라우트가 넘겨준 원래 목적지 — 로그인 후 이 경로로 되돌린다
  const returnFrom = (loc.state as { from?: string } | null)?.from;

  const [formInit] = useState(initialLoginForm);
  const [userId, setUserId] = useState(formInit.userId);
  const [password, setPassword] = useState("");
  const [saveId, setSaveId] = useState(formInit.saveId);
  const [autoLogin, setAutoLogin] = useState(formInit.autoLogin);
  const [err, setErr] = useState<string | null>(() => {
    try {
      const code = sessionStorage.getItem(AUTH_FAIL_CODE_KEY);
      if (code) sessionStorage.removeItem(AUTH_FAIL_CODE_KEY);
      if (code === "SESSION_EXPIRED") return "세션이 종료되었습니다.";
      if (code === "UNAUTHENTICATED") return "로그인이 필요합니다.";
      if (code === "UNAUTHORIZED") return "인증이 올바르지 않습니다. 다시 로그인하세요.";
    } catch {
      // 저장소 거부
    }
    return null;
  });
  const busy = isBusy("login");

  // 이미 유효한 토큰이 있으면(= 자동 로그인·주소 직접 입력) 로그인 화면을 건너뛴다
  useEffect(() => {
    if (isTokenValid(token)) {
      nav(resolvePostLoginPath(returnFrom), { replace: true });
    }
  }, [token, returnFrom, nav]);

  const onSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    // SPA 흐름을 유지하려면 폼 기본 제출(새로고침)을 막아야 한다
    e.preventDefault();
    setErr(null);

    const uid = userId.trim();
    const pwd = password.trim();
    // 서버 왕복 없이 걸러낼 수 있는 입력 누락은 여기서 안내한다
    if (!uid || !pwd) {
      setErr("아이디와 비밀번호를 입력해 주세요.");
      return;
    }

    void run(
      async () => {
        const res = await login({ userId: uid, password: pwd });
        // 선호값 저장 — 아이디 저장이 OFF면 아이디가 남지 않는다
        saveLoginPrefs({ saveId, autoLogin, userId: saveId ? uid : undefined });
        // 토큰 보관 위치를 먼저 확정해야 setAuth가 올바른 저장소에 기록된다
        applyAuthPersistStorage(autoLogin);
        // 같은 브라우저에서 사용자가 바뀔 수 있으므로 이전 조회 결과를 모두 버린다
        qc.clear();
        setAuth(res.token, res.user, res.screens);
        nav(resolvePostLoginPath(returnFrom), { replace: true });
      },
      "login",
      // 로그인 실패는 토스트 대신 폼 아래 문구로 보여준다 — 입력 위치와 가까워 눈에 잘 들어온다
      (ex) => setErr(toUserMessage(ex, "로그인에 실패했습니다.")),
    );
  };

  return (
    <div className="flex min-h-screen min-h-[100dvh] flex-col lg:flex-row">
      {/* 브랜드 이미지 — 넓은 화면 좌측, 좁은 화면 하단 */}
      <section className="relative order-2 min-h-[200px] flex-1 overflow-hidden lg:order-1 lg:min-h-screen">
        <img
          // 로그인 브랜드 배경 — MES login_bg 와 같은 그림 (JPEG 로 재인코딩)
          src={loginBg}
          // 접근성용 대체 텍스트 — HACCP 브랜드 배경
          alt="HACCP"
          // 섹션 전체를 채우는 cover 스타일
          className="absolute inset-0 h-full w-full object-cover"
        />
      </section>

      {/* 로그인 패널 — 넓은 화면 우측 흰색, 좁은 화면 상단 */}
      <section className="order-1 flex w-full shrink-0 items-center justify-center bg-white px-6 py-10 sm:px-10 lg:order-2 lg:w-[min(480px,46%)] lg:min-h-screen lg:px-12">
        <div className="w-full max-w-[340px]">
          <header className="mb-8 flex justify-center">
            <img
              // 우측 상단 HACCP 공식 인증 마크 — METIS 로고 자리 대체
              src={haccpLogo}
              // 접근성용 대체 텍스트
              alt="HACCP"
              // 원형 마크이므로 폭 대신 높이 기준으로 맞춤
              className="mx-auto h-28 w-auto object-contain"
            />
          </header>

          <form className="space-y-4" onSubmit={onSubmit}>
            <div>
              <label className="mb-1.5 block text-sm font-medium text-slate-700" htmlFor="login-user-id">
                아이디
              </label>
              <input
                // 접근성·라벨 연결용 id
                id="login-user-id"
                // 로그인 입력 공통 스타일
                className={loginInputClass}
                // 제어 값 — prefs 복원·입력 state
                value={userId}
                // 입력 시 userId state 갱신
                onChange={(e) => setUserId(e.target.value)}
                // 미입력 안내 placeholder
                placeholder="아이디"
                // 브라우저 비밀번호 관리자가 아이디 칸으로 인식하게 한다
                autoComplete="username"
                // 로그인 화면에 들어오면 바로 입력할 수 있게 커서를 둔다
                autoFocus
                // 필수 입력
                required
              />
            </div>

            <div>
              <label className="mb-1.5 block text-sm font-medium text-slate-700" htmlFor="login-password">
                비밀번호
              </label>
              <input
                // 접근성·라벨 연결용 id
                id="login-password"
                // 로그인 입력 공통 스타일
                className={loginInputClass}
                // 비밀번호 마스킹 입력
                type="password"
                // 제어 값 — 매 로그인마다 빈 문자열로 시작
                value={password}
                // 입력 시 password state 갱신
                onChange={(e) => setPassword(e.target.value)}
                // 미입력 안내
                placeholder="비밀번호"
                // 브라우저 자동완성 current-password
                autoComplete="current-password"
                // 필수 입력
                required
              />
            </div>

            <div className="flex flex-wrap items-center gap-x-5 gap-y-2 pt-1">
              <label className="flex cursor-pointer items-center gap-2">
                <input
                  // 아이디 저장 체크박스 — ON이면 다음 로그인에 userId 복원
                  type="checkbox"
                  // HACCP/MES 남색 accent 체크 UI
                  className="h-4 w-4 cursor-pointer accent-[#1a3676]"
                  checked={saveId}
                  // 아이디만 기억한다 — 비밀번호는 어떤 설정에서도 저장하지 않는다
                  onChange={(e) => setSaveId(e.target.checked)}
                />
                <span className="text-sm text-slate-600">아이디 저장</span>
              </label>
              <label className="flex cursor-pointer items-center gap-2">
                <input
                  // 자동 로그인 체크박스 — local vs session 토큰 격리
                  type="checkbox"
                  // HACCP/MES 남색 accent 체크 UI
                  className="h-4 w-4 cursor-pointer accent-[#1a3676]"
                  checked={autoLogin}
                  // 켜면 토큰을 localStorage에 둬 브라우저를 닫아도 유지된다. 공용 PC에서는 끄는 것이 안전하다
                  onChange={(e) => setAutoLogin(e.target.checked)}
                />
                <span className="text-sm text-slate-600">자동 로그인</span>
              </label>
            </div>

            {err && <p className="text-sm font-medium text-rose-600">{err}</p>}

            <button
              // form submit — onSubmit 로그인 API 흐름
              type="submit"
              // 요청 중에는 비활성 — 같은 로그인 시도가 두 번 기록되지 않게 한다
              disabled={busy}
              // 남색 CTA 버튼 스타일 — hover/focus/disabled
              className={cn(
                "mt-2 flex h-12 w-full items-center justify-center rounded-lg bg-[#1a3676] text-sm font-semibold text-white transition",
                "hover:bg-[#152d63] active:translate-y-px",
                "focus:outline-none focus:ring-2 focus:ring-[#1a3676]/30",
                "disabled:cursor-not-allowed disabled:opacity-60",
              )}
            >
              {busy ? "로그인 중" : "로그인"}
            </button>
          </form>
        </div>
      </section>
    </div>
  );
}
