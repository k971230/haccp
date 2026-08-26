/**
 * HaccpShell — 사이드 메뉴 + 탭바 + 화면 영역 + 하단 바를 조립한 앱 셸.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 후 모든 화면은 이 셸 안에서 열린다. 주소가 바뀌면 해당 화면 탭을 열고 활성화한다
 *   2) 탭을 여러 개 열어 둔 채 전환할 수 있다 — 비활성·홈 전환 시에도 마운트 유지(hidden)로
 *      입력값·그리드 상태가 남고 재진입 깜박임을 막는다
 *   3) UV/PV 수집과 그리드·트리 헤더 초록(bindMesSec)은 셸에서 일괄한다
 *
 * PIPELINE[HF49] 앱 셸
 * PIPELINE[HF51, HF66, HF64, HF30] 연관 모듈
 */
// 역할 — 사이드바 상태·주소 변화 반응·메뉴 트리 메모
import { useEffect, useMemo, useState } from "react";
// 역할 — 주소 읽기·화면 이동
import { useLocation, useNavigate } from "react-router-dom";
// 역할 — 메뉴 서버 조회·캐시
import { useQuery } from "@tanstack/react-query";
// 역할 — 사이드바 접기·로그아웃 아이콘
import { LogOut, Menu } from "lucide-react";
// 역할 — 제품 로고
import { HaccpLogo } from "@/components/ui/HaccpLogo";
// 역할 — 로그인 사용자 조회
import { useAuthStore } from "@/stores/authStore";
// 역할 — 열린 탭 목록·활성 탭
import { useTabStore } from "@/stores/tabStore";
// 역할 — 로그아웃 시 세션 일괄 정리
import { clearAuthSession } from "@/shell/authSession";
// 역할 — Vite base(/haccp/) 반영 로그인 절대 경로
import { loginBrowserPath } from "@/shell/authPaths";
// 역할 — 서버 로그아웃 기록
import { logout as logoutApi } from "@/api/authApi";
// 역할 — 권한 반영 메뉴 조회
import { getMenu } from "@/api/menuApi";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 공통 버튼
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 화면코드 → 화면 컴포넌트
import { SCREEN_REGISTRY, cleanTitle, isImplemented } from "./screenRegistry";
// 역할 — 화면코드 ↔ URL 변환
import { parseRoute, routeOf } from "./tabRoute";
// 역할 — 좌측 메뉴·트리 조립
import { SideMenu, buildTree } from "./SideMenu";
// 역할 — 상단 탭 줄·우클릭 닫기
import { ShellTabBar } from "./ShellTabBar";
// 역할 — 홈 화면
import { HomeView } from "./HomeView";
// 역할 — 하단 상태 바
import { ShellFooter } from "./ShellFooter";
// 역할 — 활성 화면코드 — MesEditableGrid pref 키
import { PageScrnContext } from "./pageCommands";
// 역할 — 모달·토스트 호스트
import { DialogHost } from "./dialog";
// 역할 — 코드 룩업·서명 등 전역 공통 모달 호스트
import { GlobalModal } from "@/components/common/modal/GlobalModal";
// 역할 — 화면 조회 로그 수집
import { useViewLog } from "./useViewLog";
// 역할 — 그리드·트리 클릭 시 헤더 초록 활성 (전 화면 일괄)
import { bindMesSec } from "./mesSec";

// 사이드바 펼침 여부 보관 키 — 탭 단위로 유지되어 다른 탭 설정에 영향을 주지 않는다
const SIDE_KEY = "haccp-side-open";

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 후 메인 레이아웃을 그리고 메뉴·탭·활성 화면을 관리한다
 *   2) 보호 라우트가 인증을 확인한 뒤 이 컴포넌트를 마운트한다
 *   3) 메뉴 조회에 실패하면 좌측이 비지만 홈 화면과 로그아웃은 계속 동작한다
 */
export function HaccpShell() {
  const nav = useNavigate();
  const loc = useLocation();
  const user = useAuthStore((s) => s.user);
  const tabs = useTabStore((s) => s.tabs);
  const activeCd = useTabStore((s) => s.activeCd);
  const openTab = useTabStore((s) => s.openTab);
  // 그리드·트리 헤더 초록 — 화면마다 bind 를 달지 않고 셸에서 한 번만 듣는다
  useEffect(() => bindMesSec(), []);
  // 사이드바 펼침 여부 — 저장값이 "0"일 때만 접힌 상태로 시작한다
  const [sideOpen, setSideOpen] = useState(() => sessionStorage.getItem(SIDE_KEY) !== "0");

  // 메뉴는 회사·권한그룹이 바뀌면 완전히 달라지므로 캐시 키에 함께 넣는다
  const menuQ = useQuery({
    queryKey: ["menu", user?.coCd, user?.usrgrpCd],
    queryFn: getMenu,
    staleTime: 60_000,
  });
  const tree = useMemo(() => buildTree(menuQ.data ?? []), [menuQ.data]);

  // 화면 조회 로그 — 활성 탭이 바뀌는 시점을 그대로 넘긴다
  useViewLog(activeCd);

  // 주소가 화면 경로면 그 화면 탭을 열고 활성화한다 (뒤로가기·새로고침·직접 입력 모두 같은 경로)
  useEffect(() => {
    const scrn = parseRoute(loc.pathname);
    // 구현된 화면일 때만 탭을 연다 — 준비 중 화면 주소로 들어와도 빈 탭이 생기지 않는다
    if (scrn && isImplemented(scrn)) {
      // 메뉴가 아직 도착하지 않았을 때(= 탭 제목을 알 수 없음) 기다린다
      if (!menuQ.data) return;
      const row = menuQ.data.find((r) => r.scrnCd === scrn);
      openTab(scrn, row ? cleanTitle(row.menuNm) : scrn);
      return;
    }
    // 마지막 탭 닫기 URL은 "/". HomeView 가 today-tasks 로 replace. /screen 등 미등록은 오늘 할 일
    if (loc.pathname !== "/") {
      nav(routeOf("today-tasks"), { replace: true });
    }
  }, [loc.pathname, menuQ.data, nav, openTab]);

  const isHome = loc.pathname === "/";

  /** 로그아웃 — 서버에 종료를 기록한 뒤 세션을 비우고 로그인 화면으로 보낸다 */
  const onLogout = async () => {
    await logoutApi();
    clearAuthSession();
    // 401·멀티탭과 동일 — basename 누락 시 /login 으로 떨어지는 것을 막는다 (/haccp/login)
    location.replace(loginBrowserPath());
  };

  /** 사이드바 접기·펼치기 — 선택은 저장해 다음 진입에도 유지한다 */
  const toggleSide = () => {
    setSideOpen((v) => {
      const next = !v;
      sessionStorage.setItem(SIDE_KEY, next ? "1" : "0");
      return next;
    });
  };

  // 사이드바 폭이 바뀌면 그리드·차트가 스스로 크기를 다시 재도록 resize를 알린다
  useEffect(() => {
    requestAnimationFrame(() => window.dispatchEvent(new Event("resize")));
  }, [sideOpen]);

  /** 메뉴·탭 클릭 — 해당 화면 경로로 이동한다 */
  const go = (scrnCd: string) => {
    nav(routeOf(scrnCd));
  };

  /** 탭을 닫은 뒤 — 스토어가 정한 activeCd 로 URL 을 한 번만 맞춘다. set() 안에서 navigate 하지 않는다 */
  const onTabClosed = () => {
    const next = useTabStore.getState().activeCd;
    nav(next ? routeOf(next) : "/", { replace: true });
  };

  return (
    <div
      className={cn(
        "grid h-screen transition-[grid-template-columns] duration-150",
        sideOpen ? "grid-cols-[200px_1fr]" : "grid-cols-[48px_1fr]",
      )}
    >
      {/* 좌측 사이드바 — 브랜드·메뉴·로그아웃 */}
      <aside className="mes-sidebar z-10">
        <div className={cn("mes-sidebar-brand", !sideOpen && "mes-sidebar-brand-collapsed")}>
          {sideOpen ? (
            <>
              <button type="button" className="mes-sidebar-toggle" title="메뉴 접기" onClick={toggleSide}>
                <Menu className="h-4 w-4" aria-hidden />
              </button>
              {/* 로고 클릭으로도 접을 수 있게 — 좁은 화면에서 목표가 커진다 */}
              <button
                type="button"
                className="mes-sidebar-brand-title mes-sidebar-brand-hit"
                title="메뉴 접기"
                onClick={toggleSide}
              >
                <HaccpLogo size="sm" className="min-w-0 max-w-[130px]" />
              </button>
            </>
          ) : (
            <>
              <button
                type="button"
                className="mes-sidebar-logo-btn flex w-full items-center justify-center border-0 bg-transparent p-0"
                title="메뉴 펼치기"
                onClick={toggleSide}
              >
                <HaccpLogo size="xs" compact />
              </button>
              <div className="mes-sidebar-brand-divider" />
              <button type="button" className="mes-sidebar-toggle" title="메뉴 펼치기" onClick={toggleSide}>
                <Menu className="h-4 w-4" aria-hidden />
              </button>
            </>
          )}
        </div>

        <SideMenu
          // 대분류-화면 2단 트리 — 서버 메뉴 목록을 조립한 결과
          tree={tree}
          // 현재 활성 화면코드 — 강조·자동 펼침 기준
          activeCd={activeCd}
          // 메뉴 조회 중 여부 — 안내 문구 표시
          loading={menuQ.isLoading}
          // 접힘 여부 — 사이드바가 접혔으면 아이콘 레일로 그린다
          collapsed={!sideOpen}
          // 레일 아이콘 클릭 — 메뉴를 고를 수 있게 사이드바를 펼친다
          onExpand={() => {
            setSideOpen(true);
            sessionStorage.setItem(SIDE_KEY, "1");
          }}
          // 화면 항목 클릭 — 해당 화면으로 이동
          onNavigate={go}
        />

        <div className="mes-sidebar-foot">
          {sideOpen ? (
            <MesButton
              variant="ghost"
              size="sm"
              onClick={() => void onLogout()}
              className="h-5 min-h-0 px-2 py-0 text-[10px] leading-none text-black hover:bg-black/5"
            >
              로그아웃
            </MesButton>
          ) : (
            <MesButton
              variant="ghost"
              size="sm"
              onClick={() => void onLogout()}
              icon={LogOut}
              // 접힌 상태에서는 라벨이 없으므로 도움말로 기능을 알린다
              title="로그아웃"
              className="h-5 w-5 min-h-0 p-0 text-black hover:bg-black/5 [&_svg]:h-3.5 [&_svg]:w-3.5"
            />
          )}
        </div>
      </aside>

      {/* 우측 본문 — 탭바·화면·하단 바 */}
      <main className="flex min-h-0 min-w-0 flex-col overflow-hidden">
        {/* 열린 탭이 있을 때만 탭바를 둔다 — 홈만 볼 때 공간을 차지하지 않게 */}
        {tabs.length > 0 && (
          <ShellTabBar
            // 탭 칩 좌클릭 — 해당 화면으로 이동
            onSelect={go}
            // ×·우클릭 닫기 후 주소 맞춤
            onClosed={onTabClosed}
          />
        )}

        {/* 화면 영역 — 라우터 Outlet이 아니라 레지스트리로 탭마다 직접 마운트한다(입력값 유지) */}
        <section className={cn("relative min-h-0 flex-1 overflow-hidden", isHome ? "bg-slate-50" : "bg-canvas")}>
          {isHome && (
            <div className="absolute inset-0 z-[1]">
              <HomeView />
            </div>
          )}
          {/* 홈에서도 탭 Comp를 유지한다 — !isHome일 때만 그리면 홈 왕복 시 언마운트·그리드 재조회 깜박임 */}
          {tabs.map((t) => {
            const Comp = SCREEN_REGISTRY[t.scrnCd];
            // 레지스트리에 없는 화면은 그리지 않는다(준비 중 화면)
            if (!Comp) return null;
            const active = !isHome && t.scrnCd === activeCd;
            return (
              <div
                key={t.scrnCd}
                // 비활성·홈일 때는 hidden — 언마운트하면 입력·그리드 상태가 사라진다
                className={cn(
                  "flex h-full min-h-0 flex-col p-5",
                  active ? "mes-tab-active" : "hidden",
                )}
                // 패널 활성 범위 — 이 탭 안에서만 헤더 초록을 옮긴다
                data-mes-page={t.scrnCd}
                data-title={t.title}
              >
                {/* 그리드 pref 저장 키 — MesEditableGrid가 PageScrnContext로 scrnCd를 읽는다 */}
                <PageScrnContext.Provider value={t.scrnCd}>
                  <Comp />
                </PageScrnContext.Provider>
              </div>
            );
          })}
        </section>

        <ShellFooter user={user} />
      </main>

      {/* 확인·토스트 — 셸에 한 번만 마운트한다 */}
      <DialogHost />

      {/* 코드 룩업·서명 등 공통 모달 — modalStore가 열림 상태를 갖는다 */}
      <GlobalModal />
    </div>
  );
}
