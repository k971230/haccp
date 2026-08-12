/**
 * SideMenu — 좌측 메뉴 트리 (대·중·소 3단).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 서버 평면 목록을 대(폴더)·중(폴더)·소(화면) 3단으로 조립한다
 *   2) scrn_cd가 있고 SCREEN_REGISTRY에 있을 때만 클릭으로 연다
 *   3) 중분류도 scrn_cd가 있으면(예외) leaf처럼 연다
 *
 * PIPELINE[HF66] 셸 인프라
 */
// 역할 — 펼침 상태 보관·활성 메뉴 자동 펼침
import { useEffect, useState } from "react";
// 역할 — 대·중 펼침 화살표
import { ChevronRight } from "lucide-react";
// 역할 — 서버 메뉴 행 타입
import type { MenuRow } from "@/api/menuApi";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 대분류 아이콘 매핑
import { getModuleIcon } from "@/lib/icons";
// 역할 — 제목 정리·구현 여부 판정
import { cleanTitle, isImplemented } from "./screenRegistry";

// 펼쳐 둔 대·중 목록 sessionStorage 키
const MENU_OPEN_KEY = "haccp-menu-open-v3";

/** 화면 항목 (소분류 또는 중분류에 화면이 붙은 경우) */
interface MenuLeaf {
  menuCd: string;
  scrnCd: string;
  title: string;
  ok: boolean;
}

/** 중분류 — 폴더 또는 화면 단독 */
interface MenuMid {
  menuCd: string;
  name: string;
  /** 중분류에 직접 붙은 화면(있으면 헤더 클릭으로 이동) */
  scrnCd?: string | null;
  ok?: boolean;
  leaves: MenuLeaf[];
}

/** 대분류 */
export interface MenuGroup {
  menuCd: string;
  name: string;
  /** 최상위 단독 leaf(오늘 할 일) */
  scrnCd?: string | null;
  ok?: boolean;
  mids: MenuMid[];
  /** 호환: 모든 하위 leaf 평탄 — 레일·활성 판정 */
  leaves: MenuLeaf[];
}

function loadOpenKeys(): Set<string> {
  try {
    const raw = sessionStorage.getItem(MENU_OPEN_KEY);
    if (!raw) return new Set();
    return new Set(JSON.parse(raw) as string[]);
  } catch {
    return new Set();
  }
}

function saveOpenKeys(keys: Set<string>) {
  try {
    sessionStorage.setItem(MENU_OPEN_KEY, JSON.stringify([...keys]));
  } catch {
    /* ignore */
  }
}

/** 활성 화면이 속한 대·중 메뉴코드를 찾는다 */
function findOpenKeysForScreen(tree: MenuGroup[], scrnCd: string | null): string[] {
  if (!scrnCd) return [];
  for (const g of tree) {
    if (g.scrnCd === scrnCd) return [g.menuCd];
    for (const m of g.mids) {
      if (m.scrnCd === scrnCd) return [g.menuCd, m.menuCd];
      if (m.leaves.some((l) => l.scrnCd === scrnCd)) return [g.menuCd, m.menuCd];
    }
  }
  return [];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 평면 메뉴를 대·중·소 3단 트리로 조립한다
 *   2) 셸이 메뉴 조회 후 buildTree 결과를 메모한다
 *   3) 상위 없는 leaf는 기타 대분류로 모은다
 */
export function buildTree(rows: MenuRow[]): MenuGroup[] {
  // 대·중·소 인코딩 sort_no 순으로 맞춘 뒤 트리를 조립한다
  const ordered = [...rows].sort((a, b) => {
    const sa = Number(a.sortNo ?? 0);
    const sb = Number(b.sortNo ?? 0);
    if (sa !== sb) return sa - sb;
    return a.menuCd.localeCompare(b.menuCd);
  });

  const byCd = new Map<string, MenuRow>();
  for (const r of ordered) byCd.set(r.menuCd, r);

  const groups: MenuGroup[] = [];
  const groupBy = new Map<string, MenuGroup>();
  const midBy = new Map<string, MenuMid>();

  // 1) 최상위 — 대분류 폴더 또는 단독 leaf
  for (const r of ordered) {
    if (r.hMenuCd) continue;
    if (r.scrnCd) {
      const leaf: MenuLeaf = {
        menuCd: r.menuCd,
        scrnCd: r.scrnCd,
        title: cleanTitle(r.menuNm),
        ok: isImplemented(r.scrnCd),
      };
      const g: MenuGroup = {
        menuCd: r.menuCd,
        name: cleanTitle(r.menuNm),
        scrnCd: r.scrnCd,
        ok: leaf.ok,
        mids: [],
        leaves: [leaf],
      };
      groups.push(g);
      groupBy.set(r.menuCd, g);
      continue;
    }
    const g: MenuGroup = {
      menuCd: r.menuCd,
      name: cleanTitle(r.menuNm),
      mids: [],
      leaves: [],
    };
    groups.push(g);
    groupBy.set(r.menuCd, g);
  }

  // 2) 중분류 — 부모가 대분류
  for (const r of ordered) {
    if (!r.hMenuCd || !groupBy.has(r.hMenuCd)) continue;
    // 소분류(화면에 중 부모가 또 있는 경우)는 3단계에서
    const parentIsDae = !byCd.get(r.hMenuCd)?.hMenuCd;
    if (!parentIsDae) continue;
    // 중: 화면 없음(폴더) 또는 화면 있음(중+leaf)
    if (r.scrnCd) {
      // 대 바로 아래 leaf — 가상 중 없이 소로 취급하기 위해 중 래퍼 1개
      const mid: MenuMid = {
        menuCd: r.menuCd,
        name: cleanTitle(r.menuNm),
        scrnCd: r.scrnCd,
        ok: isImplemented(r.scrnCd),
        leaves: [{
          menuCd: r.menuCd,
          scrnCd: r.scrnCd,
          title: cleanTitle(r.menuNm),
          ok: isImplemented(r.scrnCd),
        }],
      };
      midBy.set(r.menuCd, mid);
      groupBy.get(r.hMenuCd)!.mids.push(mid);
      groupBy.get(r.hMenuCd)!.leaves.push(...mid.leaves);
      continue;
    }
    const mid: MenuMid = { menuCd: r.menuCd, name: cleanTitle(r.menuNm), leaves: [] };
    midBy.set(r.menuCd, mid);
    groupBy.get(r.hMenuCd)!.mids.push(mid);
  }

  // 3) 소분류 — 부모가 중분류
  for (const r of ordered) {
    if (!r.hMenuCd || !r.scrnCd) continue;
    const mid = midBy.get(r.hMenuCd);
    if (!mid) {
      // 대 바로 아래 leaf는 위에서 처리됨. 상위 누락 시 기타
      if (groupBy.has(r.hMenuCd)) continue;
      let etc = groupBy.get("menu-etc");
      if (!etc) {
        etc = { menuCd: "menu-etc", name: "기타", mids: [], leaves: [] };
        groupBy.set("menu-etc", etc);
        groups.push(etc);
      }
      const leaf: MenuLeaf = {
        menuCd: r.menuCd,
        scrnCd: r.scrnCd,
        title: cleanTitle(r.menuNm),
        ok: isImplemented(r.scrnCd),
      };
      let midEtc = midBy.get("menu-etc-misc");
      if (!midEtc) {
        midEtc = { menuCd: "menu-etc-misc", name: "기타", leaves: [] };
        midBy.set("menu-etc-misc", midEtc);
        etc.mids.push(midEtc);
      }
      midEtc.leaves.push(leaf);
      etc.leaves.push(leaf);
      continue;
    }
    // 중분류가 이미 자기 scrn으로 leaf를 가진 경우(= 중=화면) 스킵
    if (mid.scrnCd === r.scrnCd && mid.menuCd === r.menuCd) continue;
    const leaf: MenuLeaf = {
      menuCd: r.menuCd,
      scrnCd: r.scrnCd,
      title: cleanTitle(r.menuNm),
      ok: isImplemented(r.scrnCd),
    };
    mid.leaves.push(leaf);
    const daeCd = byCd.get(r.hMenuCd)?.hMenuCd;
    if (daeCd && groupBy.has(daeCd)) {
      groupBy.get(daeCd)!.leaves.push(leaf);
    }
  }

  // 빈 중분류 제거 후, 화면이 하나도 없는 대분류 제외
  for (const g of groups) {
    g.mids = g.mids.filter((m) => m.leaves.length > 0 || (m.scrnCd && m.ok));
  }
  return groups.filter((g) => g.leaves.length > 0 || (g.scrnCd && g.ok));
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
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 대 아코디언 → 중 서브헤더 → 소 화면 목록을 그린다
 *   2) 셸이 사이드바에 마운트한다
 *   3) 이동은 onNavigate로 셸에 위임한다
 */
export function SideMenu({
  tree,
  activeCd,
  loading,
  collapsed,
  onExpand,
  onNavigate,
}: SideMenuProps) {
  const [openKeys, setOpenKeys] = useState<Set<string>>(loadOpenKeys);

  const toggleKey = (key: string) => {
    setOpenKeys((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      saveOpenKeys(next);
      return next;
    });
  };

  const collapseAll = () => {
    const next = new Set<string>();
    setOpenKeys(next);
    saveOpenKeys(next);
  };

  useEffect(() => {
    if (!activeCd) return;
    const keys = findOpenKeysForScreen(tree, activeCd);
    if (keys.length === 0) return;
    setOpenKeys((prev) => {
      let changed = false;
      const next = new Set(prev);
      for (const k of keys) {
        if (!next.has(k)) {
          next.add(k);
          changed = true;
        }
      }
      if (!changed) return prev;
      saveOpenKeys(next);
      return next;
    });
  }, [activeCd, tree]);

  if (loading) {
    return (
      <nav
        // 접힘·펼침에 따라 레일/스크롤 영역 클래스를 바꾼다
        className={cn(collapsed ? "mes-sidebar-rail" : "mes-sidebar-scroll mes-sidebar-loading px-2.5 py-2 text-[13px] font-semibold")}
      >
        {!collapsed && "메뉴 불러오는 중"}
      </nav>
    );
  }

  if (collapsed) {
    return (
      <nav className="mes-sidebar-rail">
        {tree.map((g) => {
          const hasActive = g.leaves.some((l) => l.scrnCd === activeCd) || g.scrnCd === activeCd;
          const GroupIcon = getModuleIcon(g.menuCd);
          return (
            <button
              // 대분류 메뉴코드 — React 목록 키
              key={g.menuCd}
              // 버튼 역할 — 폼 submit 방지
              type="button"
              // 활성 대분류일 때(= 하위 화면 열림) 레일 강조
              className={cn("mes-sidebar-rail-btn", hasActive && "mes-sidebar-rail-btn-active")}
              // 툴팁 — 접힌 상태에서 대분류명 안내
              title={g.name}
              // 클릭 시 사이드바를 다시 펼친다
              onClick={() => onExpand?.()}
            >
              <GroupIcon
                // 레일 아이콘 크기 — 18px 고정
                className="h-[18px] w-[18px] shrink-0"
                // 장식 아이콘 — 스크린리더 제외
                aria-hidden
              />
            </button>
          );
        })}
      </nav>
    );
  }

  return (
    <nav className="flex min-h-0 flex-1 flex-col overflow-hidden">
      <div className="mes-sidebar-toolbar">
        <button
          // 버튼 역할 — 폼 submit 방지
          type="button"
          // 모두 접기 — 대·중 openKeys 초기화
          className="mes-sidebar-collapse-all"
          // 클릭 시 sessionStorage의 펼침 키도 비운다
          onClick={collapseAll}
        >
          모두 접기
        </button>
      </div>
      <div className="mes-sidebar-scroll">
        {tree.map((g) => {
          const isSoloTop = !!g.scrnCd && g.mids.length === 0;
          const isOpen = openKeys.has(g.menuCd);
          const hasActive = g.leaves.some((l) => l.scrnCd === activeCd) || g.scrnCd === activeCd;
          return (
            <div
              // 대분류 메뉴코드 — React 목록 키
              key={g.menuCd}
              // 대분류 그룹 래퍼 — 아코디언 단위
              className="mes-sidebar-group"
            >
              <button
                // 버튼 역할 — 폼 submit 방지
                type="button"
                // 펼침·활성 상태에 따라 대분류 헤더 스타일
                className={cn(
                  "mes-sidebar-grpa",
                  isOpen && !hasActive && "mes-sidebar-grpa-open",
                  hasActive && "mes-sidebar-grpa-active",
                )}
                // 단독 leaf면 화면 이동, 아니면 대분류 접기/펼치기
                onClick={() => {
                  if (isSoloTop && g.ok && g.scrnCd) {
                    onNavigate(g.scrnCd);
                    return;
                  }
                  toggleKey(g.menuCd);
                }}
                // 접근성 — 아코디언 펼침 여부
                aria-expanded={isOpen}
              >
                <span className="min-w-0 flex-1 truncate">{g.name}</span>
                {!isSoloTop ? (
                  <ChevronRight
                    // 펼침일 때(= isOpen) 90도 회전
                    className={cn("mes-sidebar-grpa-chevron", isOpen && "rotate-90")}
                    // 장식 아이콘 — 스크린리더 제외
                    aria-hidden
                  />
                ) : null}
              </button>
              {isOpen && !isSoloTop && (
                <div className="mes-sidebar-submenu">
                  {g.mids.map((m) => {
                    const midOpen = openKeys.has(m.menuCd);
                    const midActive = m.scrnCd === activeCd || m.leaves.some((l) => l.scrnCd === activeCd);
                    const midIsSolo = !!m.scrnCd && m.leaves.length <= 1;
                    return (
                      <div
                        // 중분류 메뉴코드 — React 목록 키
                        key={m.menuCd}
                        // 중분류 블록 — grpb + 소 leaf 묶음
                        className="mes-sidebar-mid"
                      >
                        <button
                          // 버튼 역할 — 폼 submit 방지
                          type="button"
                          // 중분류(GRPB) — 섹션 헤더. 소(leaf)와 다른 배경·accent
                          className={cn(
                            "mes-sidebar-grpb",
                            midOpen && !midActive && "mes-sidebar-grpb-open",
                            midActive && "mes-sidebar-grpb-active",
                          )}
                          // 화면이 붙은 중이면 이동, 폴더면 소목록 접기/펼치기
                          onClick={() => {
                            if (midIsSolo && m.ok && m.scrnCd) {
                              onNavigate(m.scrnCd);
                              return;
                            }
                            if (m.leaves.length === 0 && m.scrnCd && m.ok) {
                              onNavigate(m.scrnCd);
                              return;
                            }
                            toggleKey(m.menuCd);
                          }}
                          // 접근성 — 중분류 아코디언 펼침
                          aria-expanded={!midIsSolo && midOpen}
                          // 툴팁 — 중분류명
                          title={m.name}
                        >
                          <span className="min-w-0 flex-1 truncate">{m.name}</span>
                          {!midIsSolo && m.leaves.length > 0 ? (
                            <ChevronRight
                              // 중분류 펼침 화살표 — 열리면 90도
                              className={cn("mes-sidebar-grpb-chevron", midOpen && "rotate-90")}
                              // 장식 아이콘 — 스크린리더 제외
                              aria-hidden
                            />
                          ) : null}
                        </button>
                        {midOpen && !midIsSolo && m.leaves.length > 0 && (
                          <ul
                            // 소분류 목록 — 중 아래 들여쓰기·점선 트리
                            className="mes-sidebar-leaves"
                          >
                            {m.leaves.map((leaf) => {
                              const active = activeCd === leaf.scrnCd;
                              return (
                                <li
                                  // 소메뉴 코드 — React 목록 키
                                  key={leaf.menuCd}
                                >
                                  <button
                                    // 버튼 역할 — 폼 submit 방지
                                    type="button"
                                    // 활성·미구현·일반 상태에 따라 leaf 스타일
                                    className={cn(
                                      "mes-sidebar-leaf",
                                      active && "mes-sidebar-leaf-active",
                                      !active && !leaf.ok && "mes-sidebar-leaf-disabled",
                                      !active && leaf.ok && "mes-sidebar-leaf-inactive",
                                    )}
                                    // 레지스트리 미등록일 때(= 준비 중) 클릭 불가
                                    disabled={!leaf.ok}
                                    // 구현된 화면만 셸 navigate
                                    onClick={() => leaf.ok && onNavigate(leaf.scrnCd)}
                                    // 툴팁 — 미구현이면 준비 중 안내
                                    title={leaf.ok ? leaf.title : `${leaf.title} (준비 중)`}
                                  >
                                    <span className="truncate">{leaf.title}</span>
                                  </button>
                                </li>
                              );
                            })}
                          </ul>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </nav>
  );
}
