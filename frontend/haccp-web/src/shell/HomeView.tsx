/**
 * HomeView — 로그인 직후 랜딩. 오늘 할 일 조회권이 있으면 그 화면으로 보낸다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-31
 * 코멘트:
 *   1) IA상 최초 화면은 today-tasks 이므로 "/" 진입 시 해당 탭으로 이동한다
 *   2) 오늘 할 일 조회권이 없으면 보내지 않는다 — 권한 밖 URL이 홈으로 온 뒤 다시 토스트가 돌지 않게
 *   3) 대시보드 본문은 TodayTasksPage(카드+2열)가 담당한다 — 중앙 문서 미리보기 없음
 *
 * PIPELINE[HF62] 홈 화면
 * PIPELINE[HF88, HF49] 연관 모듈
 */
// 역할 — 마운트 시 1회 이동
import { useEffect } from "react";
// 역할 — 오늘 할 일 경로로 이동
import { useNavigate } from "react-router-dom";
// 역할 — 로그인 사용자·화면 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 화면 경로
import { routeOf } from "@/shell/tabRoute";

/**
 * 개발자: 박승우
 * 일자: 2026-08-31
 * 코멘트:
 *   1) 오늘 할 일 조회권이 있을 때만 "/" 를 today-tasks 로 replace 한다
 *   2) 셸이 홈일 때 마운트한다
 *   3) 히스토리 스택을 늘리지 않는다(replace)
 */
export function HomeView() {
  const navigate = useNavigate();
  const user = useAuthStore((s) => s.user);
  // 오늘 할 일 조회권 — 없으면 홈 안내만 남긴다
  const canToday = useAuthStore((s) => s.can("today-tasks", "read"));

  useEffect(() => {
    if (!canToday) return;
    navigate(routeOf("today-tasks"), { replace: true });
  }, [canToday, navigate]);

  return (
    <div className="flex h-full min-h-0 items-center justify-center bg-slate-50 p-6">
      <div className="rounded border border-slate-200 bg-white px-8 py-6 text-center shadow-sm">
        <p className="text-xs font-semibold text-[#1a3676]">HACCP 일지관리</p>
        <h1 className="mt-2 text-lg font-bold text-slate-800">
          {canToday
            ? `${user?.userNm ?? "사용자"}님, 오늘 할 일로 이동합니다.`
            : `${user?.userNm ?? "사용자"}님, 환영합니다.`}
        </h1>
        <p className="mt-2 text-sm text-slate-500">
          {canToday
            ? `${user?.coNm ?? "-"} · 잠시만 기다려 주세요.`
            : `${user?.coNm ?? "-"} · 왼쪽 메뉴에서 화면을 고르세요.`}
        </p>
      </div>
    </div>
  );
}
