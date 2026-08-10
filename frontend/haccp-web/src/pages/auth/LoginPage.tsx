/**
 * LoginPage — 아이디·비밀번호 로그인 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 성공 시 선호값 저장 → 토큰 보관 위치 결정 → 캐시 초기화 → 세션 적재 → 원래 보던 화면으로 이동한다
 *   2) mes-web과 달리 회사 선택이 없다 — 아이디가 전 업체 통틀어 유일해서 서버가 소속 회사를 판정한다
 *   3) 이미 유효한 토큰이 있으면 입력 없이 홈으로 보낸다. 실패 문구는 서버가 준 업무 문구를 그대로 쓴다
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
// 역할 — 아이디 저장·자동 로그인 선호값
import { loadLoginPrefs, saveLoginPrefs } from "@/shell/loginPrefs";
// 역할 — 중복 제출 방지
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 로그인 입력 공통 스타일
import { loginInputClass } from "@/components/ui/Input";
// 역할 — 제품 로고
import { HaccpLogo } from "@/components/ui/HaccpLogo";

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
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 폼을 그리고 인증 성공 시 세션을 적재한다
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
  const [err, setErr] = useState<string | null>(null);
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
    <div className="flex min-h-screen min-h-[100dvh] items-center justify-center bg-slate-100 px-6 py-10">
      <section className="w-full max-w-[380px] rounded-mes-xl border border-slate-200 bg-white px-8 py-10 shadow-lg sm:px-10">
        <header className="mb-8 flex flex-col items-center gap-1.5">
          <HaccpLogo size="lg" />
          <p className="text-xs text-slate-500">HACCP 기록·결재·보관 시스템</p>
        </header>

        <form className="space-y-4" onSubmit={onSubmit}>
          <div>
            <label className="mb-1.5 block text-sm font-medium text-slate-700" htmlFor="login-user-id">
              아이디
            </label>
            <input
              id="login-user-id"
              className={loginInputClass}
              value={userId}
              onChange={(e) => setUserId(e.target.value)}
              placeholder="아이디"
              // 브라우저 비밀번호 관리자가 아이디 칸으로 인식하게 한다
              autoComplete="username"
              // 로그인 화면에 들어오면 바로 입력할 수 있게 커서를 둔다
              autoFocus
              required
            />
          </div>

          <div>
            <label className="mb-1.5 block text-sm font-medium text-slate-700" htmlFor="login-password">
              비밀번호
            </label>
            <input
              id="login-password"
              className={loginInputClass}
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="비밀번호"
              autoComplete="current-password"
              required
            />
          </div>

          <div className="flex flex-wrap items-center gap-x-5 gap-y-2 pt-1">
            <label className="flex cursor-pointer items-center gap-2">
              <input
                type="checkbox"
                className="h-4 w-4 cursor-pointer accent-[#1a3676]"
                checked={saveId}
                // 아이디만 기억한다 — 비밀번호는 어떤 설정에서도 저장하지 않는다
                onChange={(e) => setSaveId(e.target.checked)}
              />
              <span className="text-sm text-slate-600">아이디 저장</span>
            </label>
            <label className="flex cursor-pointer items-center gap-2">
              <input
                type="checkbox"
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
            type="submit"
            // 요청 중에는 비활성 — 같은 로그인 시도가 두 번 기록되지 않게 한다
            disabled={busy}
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
      </section>
    </div>
  );
}
