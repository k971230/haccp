/**
 * SideMenu — 좌측 메뉴 트리 (대분류 아코디언 + 화면 목록).
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 서버가 준 평면 메뉴 목록을 상위-하위 2단 트리로 조립해 그린다
 *   2) mes-web은 대·중·화면 3단이지만 HACCP 메뉴는 모듈 대분류 아래 화면이 바로 붙는 2단이다
 *   3) 아직 만들지 않은 화면은 비활성으로 보여준다 — 목록에서 감추면 담당자가 기능 유무를 오해한다
 *
 * PIPELINE[HF66] 셸 인프라
 * PIPELINE[HF49, HF51] 연관 모듈
 */
// 역할 — 펼침 상태 보관·활성 메뉴 자동 펼침
import { useEffect, useState } from "react";
// 역할 — 대분류 펼침 표시 화살표
import { ChevronRight } from "lucide-react";
// 역할 — 서버 메뉴 행 타입
import type { MenuRow } from "@/api/menuApi";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 대분류 아이콘 매핑
import { getModuleIcon } from "@/lib/icons";
// 역할 — 제목 정리·구현 여부 판정
import { cleanTitle, isImplemented } from "./screenRegistry";

// 펼쳐 둔 대분류 목록을 담는 sessionStorage 키 — 탭을 닫으면 초기화된다
const MENU_OPEN_KEY = "haccp-menu-open";

/** 화면 항목 (트리 말단) */
interface MenuLeaf {
  scrnCd: string;
  title: string;
  /** 웹 구현 여부 — false면 클릭이 막힌다 */
  ok: boolean;
}

/** 대분류 항목 — 모듈 하나에 대응한다 */
export interface MenuGroup {
  /** 대분류 메뉴코드 — 아이콘 매핑 키('M' + 모듈코드) */
  menuCd: string;
  /** 대분류 이름 — 예: 중요관리점 */
  name: string;
  leaves: MenuLeaf[];
}

/** 펼쳐 둔 대분류 집합을 복원한다 — 새로고침 후에도 열려 있던 분류가 유지된다 */
function loadOpenGroups(): Set<string> {
  try {
    const raw = sessionStorage.getItem(MENU_OPEN_KEY);
    if (!raw) return new Set();
    return new Set(JSON.parse(raw) as string[]);
  } catch {
    // 저장값이 깨졌으면 모두 접힌 상태로 시작한다
    return new Set();
  }
}

/** 펼쳐 둔 대분류 집합을 저장한다 */
function saveOpenGroups(groups: Set<string>) {
  try {
    sessionStorage.setItem(MENU_OPEN_KEY, JSON.stringify([...groups]));
  } catch {
    // storage 접근 실패 — 펼침 상태 유지만 포기한다
  }
}

/** 활성 화면이 속한 대분류 메뉴코드를 찾는다 — 자동 펼침용 */
function findGroupOfScreen(tree: MenuGroup[], scrnCd: string | null): string | null {
  if (!scrnCd) return null;
  for (const g of tree) {
    if (g.leaves.some((l) => l.scrnCd === scrnCd)) return g.menuCd;
  }
  return null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 서버의 평면 메뉴 목록을 대분류-화면 2단 트리로 조립한다
 *   2) 셸이 메뉴 조회 결과를 받은 뒤 한 번 호출하고 결과를 메모한다
 *   3) 상위 메뉴가 없는 화면은 "기타" 분류로 모은다 — 트리에서 누락되지 않게 한다
 */
export function buildTree(
  // 서버가 준 메뉴 목록 — 상위 노드(h_menu_cd = null)와 화면 노드가 섞여 있고, 정렬은 이미 되어 있다
  rows: MenuRow[]
): MenuGroup[] {
  const groups: MenuGroup[] = [];
  const byCd = new Map<string, MenuGroup>();

  // 서버 sort 순서 유지 — 오늘할일(최상위 leaf)과 대메뉴 부모를 먼저 만든다
  for (const r of rows) {
    if (r.hMenuCd) continue;
    // 최상위 화면 leaf(오늘 할 일) — 단독 그룹 1 leaf
    if (r.scrnCd) {
      const g: MenuGroup = {
        menuCd: r.menuCd,
        name: cleanTitle(r.menuNm),
        leaves: [{ scrnCd: r.scrnCd, title: cleanTitle(r.menuNm), ok: isImplemented(r.scrnCd) }],
      };
      groups.push(g);
      byCd.set(r.menuCd, g);
      continue;
    }
    // 대메뉴 부모
    const g: MenuGroup = { menuCd: r.menuCd, name: cleanTitle(r.menuNm), leaves: [] };
    groups.push(g);
    byCd.set(r.menuCd, g);
  }

  // 화면이 붙은 노드를 상위 그룹에 담는다
  for (const r of rows) {
    if (!r.hMenuCd || !r.scrnCd) continue;
    let g = byCd.get(r.hMenuCd);
    // 상위 노드가 응답에 없을 때(= 메뉴 설정 누락) 기타 그룹으로 모은다
    if (!g) {
      g = { menuCd: "METC", name: "기타", leaves: [] };
      byCd.set(r.hMenuCd, g);
      groups.push(g);
    }
    g.leaves.push({ scrnCd: r.scrnCd, title: cleanTitle(r.menuNm), ok: isImplemented(r.scrnCd) });
  }

  // 화면이 하나도 없는 대분류는 클릭할 것이 없으므로 제외한다
  return groups.filter((g) => g.leaves.length > 0);
}

interface SideMenuProps {
  tree: MenuGroup[];
  activeCd: string | null;
  loading: boolean;
  collapsed?: boolean;
  onExpand?: () => void;
  onNavigate: (scrnCd: string) => void;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 좌측 메뉴를 그린다 — 펼친 상태는 아코디언, 접은 상태는 아이콘 레일이다
 *   2) 셸이 사이드바 영역에 한 번 마운트한다
 *   3) 화면 이동은 직접 하지 않고 onNavigate로 셸에 넘긴다 — 미저장 확인은 셸이 판단한다
 */
export function SideMenu({
  // 대분류-화면 2단 트리 — buildTree 결과
  tree,
  // 현재 활성 화면코드 — 강조 표시와 자동 펼침 기준. 홈이면 null
  activeCd,
  // 메뉴 조회 중 여부 — true면 안내 문구만 보여준다
  loading,
  // 사이드바 접힘 여부 — true면 아이콘만 있는 레일로 그린다
  collapsed,
  // 레일에서 아이콘을 눌렀을 때 사이드바를 펼치라는 신호
  onExpand,
  // 화면 항목 클릭 — 실제 이동은 셸이 수행한다
  onNavigate,
}: SideMenuProps) {
  const [openGroups, setOpenGroups] = useState<Set<string>>(loadOpenGroups);

  /** 대분류 펼치기·접기 */
  const toggleGroup = (menuCd: string) => {
    setOpenGroups((prev) => {
      const next = new Set(prev);
      if (next.has(menuCd)) next.delete(menuCd);
      else next.add(menuCd);
      saveOpenGroups(next);
      return next;
    });
  };

  /** 모두 접기 — 메뉴가 길어질 때 원하는 분류를 찾기 쉽게 한다 */
  const collapseAll = () => {
    const next = new Set<string>();
    setOpenGroups(next);
    saveOpenGroups(next);
  };

  // 활성 화면이 속한 대분류는 자동으로 펼친다 — 주소로 바로 들어와도 위치를 알 수 있다
  useEffect(() => {
    if (!activeCd) return;
    const menuCd = findGroupOfScreen(tree, activeCd);
    if (!menuCd) return;
    setOpenGroups((prev) => {
      // 이미 펼쳐져 있으면 상태를 바꾸지 않는다(불필요한 리렌더 방지)
      if (prev.has(menuCd)) return prev;
      const next = new Set(prev);
      next.add(menuCd);
      saveOpenGroups(next);
      return next;
    });
  }, [activeCd, tree]);

  // 메뉴 조회 중 — 레일 모드에서는 문구 없이 빈 영역만 둔다
  if (loading) {
    return (
      <nav className={cn(collapsed ? "mes-sidebar-rail" : "mes-sidebar-scroll mes-sidebar-loading px-2.5 py-2 text-[13px] font-semibold")}>
        {!collapsed && "메뉴 불러오는 중"}
      </nav>
    );
  }

  // 접힘(레일) — 대분류 아이콘만 표시하고, 누르면 사이드바를 펼친다
  if (collapsed) {
    return (
      <nav className="mes-sidebar-rail">
        {tree.map((g) => {
          const hasActive = g.leaves.some((l) => l.scrnCd === activeCd);
          const GroupIcon = getModuleIcon(g.menuCd);
          return (
            <button
              key={g.menuCd}
              type="button"
              className={cn("mes-sidebar-rail-btn", hasActive && "mes-sidebar-rail-btn-active")}
              // 레일에서는 이름이 보이지 않으므로 도움말로 대분류명을 알린다
              title={g.name}
              onClick={() => onExpand?.()}
            >
              <GroupIcon className="h-[18px] w-[18px] shrink-0" aria-hidden />
            </button>
          );
        })}
      </nav>
    );
  }

  // 펼침 — 대분류 아코디언 아래 화면 목록
  return (
    <nav className="flex min-h-0 flex-1 flex-col overflow-hidden">
      <div className="mes-sidebar-toolbar">
        <button type="button" className="mes-sidebar-collapse-all" onClick={collapseAll}>
          모두 접기
        </button>
      </div>
      <div className="mes-sidebar-scroll">
        {tree.map((g) => {
          const isOpen = openGroups.has(g.menuCd);
          const hasActive = g.leaves.some((l) => l.scrnCd === activeCd);
          return (
            <div key={g.menuCd} className="mes-sidebar-group">
              <button
                type="button"
                className={cn(
                  "mes-sidebar-grpa",
                  // 펼쳐졌지만 활성 화면이 없을 때
                  isOpen && !hasActive && "mes-sidebar-grpa-open",
                  // 이 분류 안에 현재 보고 있는 화면이 있을 때
                  hasActive && "mes-sidebar-grpa-active",
                )}
                onClick={() => {
                  // 오늘 할 일처럼 최상위 단독 leaf 그룹이면 헤더 클릭으로 바로 연다
                  const solo = g.leaves.length === 1 && g.menuCd === g.leaves[0].scrnCd;
                  if (solo && g.leaves[0].ok) {
                    onNavigate(g.leaves[0].scrnCd);
                    return;
                  }
                  toggleGroup(g.menuCd);
                }}
                aria-expanded={isOpen}
              >
                <span className="min-w-0 flex-1 truncate">{g.name}</span>
                {!(g.leaves.length === 1 && g.menuCd === g.leaves[0].scrnCd) ? (
                  <ChevronRight className={cn("mes-sidebar-grpa-chevron", isOpen && "rotate-90")} aria-hidden />
                ) : null}
              </button>
              {isOpen && !(g.leaves.length === 1 && g.menuCd === g.leaves[0].scrnCd) && (
                <div className="mes-sidebar-submenu">
                  <ul className="m-0 list-none space-y-0.5">
                    {g.leaves.map((leaf) => {
                      const active = activeCd === leaf.scrnCd;
                      return (
                        <li key={leaf.scrnCd}>
                          <button
                            type="button"
                            className={cn(
                              "mes-sidebar-leaf",
                              active && "mes-sidebar-leaf-active",
                              // 미구현 화면 — 눌러도 열리지 않음을 색으로 알린다
                              !active && !leaf.ok && "mes-sidebar-leaf-disabled",
                              !active && leaf.ok && "mes-sidebar-leaf-inactive",
                            )}
                            disabled={!leaf.ok}
                            onClick={() => leaf.ok && onNavigate(leaf.scrnCd)}
                            // 미구현이면 이유를 도움말로 알려 담당자가 문의하지 않게 한다
                            title={leaf.ok ? leaf.title : `${leaf.title} (준비 중)`}
                          >
                            <span className="truncate">{leaf.title}</span>
                          </button>
                        </li>
                      );
                    })}
                  </ul>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </nav>
  );
}
