/**
 * MenuManagementPage — 메뉴 좌 트리 + 우 그리드.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 좌측 hMenuCd 트리(최상단 「전체」=전건), 우측 메뉴 편집 그리드
 *   2) 노드 클릭 시 직속 하위만 표시하고, 정렬은 sort_no(대중소 인코딩) 순이다
 *   3) 상단 메뉴코드·메뉴명·사용여부로 FE 필터한다(사용 기본 Y)
 *
 * PIPELINE[HF99] 메뉴 관리
 */
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ChevronRight } from "lucide-react";
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useGridAccess } from "@/hooks/useGridAccess";
import { useEditableRows } from "@/hooks/useEditableRows";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
import { PageCard } from "@/components/layout/PageCard";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import {
  TreePanelSearch,
  treeNodeIdleClass,
  treeNodeSelectedClass,
  treePanelHeadClass,
} from "@/components/layout/TreePanelSearch";
import {
  SearchArea,
  SearchButton,
  SearchField,
  SearchSelect,
} from "@/components/layout/SearchArea";
import { pageRootClass } from "@/components/layout/pageClasses";
import { searchInputClass } from "@/components/ui/Input";
import { cn } from "@/lib/cn";
import { filterTreeByQuery } from "@/lib/treeFilter";
import { DEFAULT_USE_YN, ynMap, ynOptions } from "@/lib/yn";
import { mesConfirm, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { usePageCommands } from "@/shell/pageCommands";
import { guardSaveWithKey } from "@/shell/gridRules";
import { resolveRowsForDelete } from "@/shell/resolveDelete";
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
import {
  deleteSystemRows,
  listSystemRows,
  saveSystemRows,
  validateDeleteSystemRows,
  type SystemRow,
} from "@/api/systemApi";
import { SYSTEM_GRID_RULES } from "./SystemManagementPage.rules";

const SCREEN = "menu-management" as const;
/** 트리 「전체」 가상 키 — 전건 표시 */
const TREE_ALL = "__ALL__";

type MenuRow = SystemRow & {
  _key?: string;
  menuCd?: string;
  menuNm?: string;
  hMenuCd?: string;
  scrnCd?: string;
  sortNo?: number | null;
  useYn?: string;
  grpANm?: string;
  grpBNm?: string;
  grpCNm?: string;
  idx?: number | null;
};

type TreeNode = {
  menuCd: string;
  name: string;
  children: TreeNode[];
};

function matchMenu(row: MenuRow, menuCd: string, menuNm: string, useYn: string): boolean {
  const qCd = menuCd.trim().toLowerCase();
  const qNm = menuNm.trim().toLowerCase();
  if (qCd && !String(row.menuCd ?? "").toLowerCase().includes(qCd)) return false;
  if (qNm && !String(row.menuNm ?? "").toLowerCase().includes(qNm)) return false;
  if (useYn && String(row.useYn ?? "").toUpperCase() !== useYn.toUpperCase()) return false;
  return true;
}

/** sort_no(대중소 인코딩) → menuCd — 기존 메뉴관리 정렬 유지 */
function sortByMenuOrder(a: MenuRow, b: MenuRow): number {
  const sa = Number(a.sortNo ?? 0);
  const sb = Number(b.sortNo ?? 0);
  if (sa !== sb) return sa - sb;
  return String(a.menuCd ?? "").localeCompare(String(b.menuCd ?? ""));
}

/**
 * 메뉴 트리에서 대·중·소 표시명을 채운다.
 * depth0=대, depth1=중, depth2+=소.
 */
function enrichMenuLevels(rows: MenuRow[]): MenuRow[] {
  const byCd = new Map<string, MenuRow>();
  for (const row of rows) {
    const cd = String(row.menuCd ?? "").trim();
    if (cd) byCd.set(cd, row);
  }
  const pathOf = (row: MenuRow): MenuRow[] => {
    const chain: MenuRow[] = [];
    let cur: MenuRow | undefined = row;
    const guard = new Set<string>();
    while (cur) {
      const cd = String(cur.menuCd ?? "").trim();
      if (!cd || guard.has(cd)) break;
      guard.add(cd);
      chain.unshift(cur);
      const parent = String(cur.hMenuCd ?? "").trim();
      cur = parent ? byCd.get(parent) : undefined;
    }
    return chain;
  };
  return rows.map((row) => {
    const path = pathOf(row);
    const names = path.map((item) => String(item.menuNm ?? "").trim());
    return {
      ...row,
      grpANm: names[0] || "",
      grpBNm: names[1] || "",
      grpCNm: names.length >= 3 ? names[names.length - 1] : "",
    };
  });
}

function buildMenuTree(rows: MenuRow[]): TreeNode[] {
  const ordered = [...rows]
    .filter((r) => String(r.menuCd ?? "").trim())
    .sort(sortByMenuOrder);
  const nodes = new Map<string, TreeNode>();
  for (const r of ordered) {
    const cd = String(r.menuCd);
    nodes.set(cd, {
      menuCd: cd,
      name: String(r.menuNm ?? cd),
      children: [],
    });
  }
  const roots: TreeNode[] = [];
  for (const r of ordered) {
    const cd = String(r.menuCd);
    const node = nodes.get(cd)!;
    const parentCd = String(r.hMenuCd ?? "").trim();
    const parent = parentCd ? nodes.get(parentCd) : undefined;
    if (parent && parentCd !== cd) parent.children.push(node);
    else roots.push(node);
  }
  return roots;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 메뉴 목록·트리를 조회·저장한다
 *   2) menu-management 화면에서 마운트한다
 *   3) 행추가는 불가 — 시드·migrate로만 생성
 */
export default function MenuManagementPage() {
  const canWrite = useAuthStore((s) => s.can(SCREEN, "write"));
  const canModify = useAuthStore((s) => s.can(SCREEN, "modify"));
  const canDelete = useAuthStore((s) => s.can(SCREEN, "delete"));
  const asyncAct = useAsyncAction();
  const g = useEditableRows<MenuRow>("idx");
  const allMenusRef = useRef<MenuRow[]>([]);
  const grid = useGridAccess(SYSTEM_GRID_RULES[SCREEN], {
    scrnCd: SCREEN,
    gridRole: "single",
    readOnly: !canModify,
    extra: { canWrite, canModify, canDelete },
  });
  const [qMenuCd, setQMenuCd] = useState("");
  const [qMenuNm, setQMenuNm] = useState("");
  const [qUseYn, setQUseYn] = useState<string>(DEFAULT_USE_YN);
  // 트리 선택 — TREE_ALL 또는 메뉴코드(직속 하위만)
  const [treeSel, setTreeSel] = useState<string>(TREE_ALL);
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  const [openKeys, setOpenKeys] = useState<Set<string>>(new Set([TREE_ALL]));
  // 트리 결과 내 검색 — 그리드 툴바와 동일 취지
  const [treeQuery, setTreeQuery] = useState("");

  const ynOpts = useMemo(() => ynOptions(), []);
  const ynLabels = useMemo(() => ynMap(), []);
  const editable = canWrite || canModify;

  const columns: GridColumn<MenuRow>[] = useMemo(
    () => [
      {
        // 대·중·소 — 트리 산출 표시열. 편집 불가
        field: "grpANm",
        header: "대분류",
        width: 120,
        editable: false,
        required: true,
      },
      { field: "grpBNm", header: "중분류", width: 120, editable: false },
      { field: "grpCNm", header: "소분류", width: 140, editable: false },
      {
        field: "menuCd",
        header: "메뉴코드",
        width: 140,
        editable: false,
        required: true,
      },
      {
        field: "menuNm",
        header: "메뉴명",
        width: 160,
        editable,
        required: true,
      },
      { field: "hMenuCd", header: "상위메뉴", width: 120, editable: false },
      { field: "scrnCd", header: "화면코드", width: 160, editable: false },
      {
        field: "sortNo",
        header: "정렬코드",
        width: 80,
        type: "number",
        editable: false,
      },
      {
        field: "useYn",
        header: "사용여부",
        width: 80,
        type: "code",
        editable,
        codeOptions: ynOpts,
        codeMap: ynLabels,
        required: true,
      },
    ],
    [editable, ynLabels, ynOpts],
  );

  const fullTree = useMemo(
    () => buildMenuTree(allMenusRef.current),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [g.rows],
  );

  const tree = useMemo(() => {
    const filtered = filterTreeByQuery(
      fullTree,
      treeQuery,
      (n) => n.menuCd,
      (n) => n.name,
    );
    return filtered;
  }, [fullTree, treeQuery]);

  /** 트리 검색 확정 — 매칭 경로 펼침 */
  const runTreeSearch = useCallback(() => {
    if (!treeQuery.trim()) return;
    setOpenKeys((prev) => {
      const next = new Set(prev);
      for (const k of tree.openKeys) next.add(k);
      return next;
    });
  }, [tree.openKeys, treeQuery]);

  useEffect(() => {
    // 입력 중에도 매칭 경로는 펼친다
    runTreeSearch();
  }, [runTreeSearch]);

  const applyFilter = useCallback(() => {
    let filtered = allMenusRef.current.filter((r) =>
      matchMenu(r, qMenuCd, qMenuNm, qUseYn),
    );
    // 트리 노드 선택 시(= 「전체」 아님) 직속 하위만
    if (treeSel !== TREE_ALL) {
      filtered = filtered.filter(
        (r) => String(r.hMenuCd ?? "").trim() === treeSel,
      );
    }
    // 그리드 표시 순서 — sort_no 유지 (대·중·소는 전체 로드 시 이미 산출)
    filtered = [...filtered].sort(sortByMenuOrder);
    g.load(filtered.map((r) => ({ ...r })) as MenuRow[]);
    setActiveKey(null);
    setSelKeys([]);
    setSelReset((n) => n + 1);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [qMenuCd, qMenuNm, qUseYn, treeSel]);

  const loadMenus = useCallback(async () => {
    const rows = await listSystemRows(SCREEN, { keyword: "" });
    // 대·중·소 산출용 전체 보관 — 트리·필터 모두 동일 소스
    allMenusRef.current = enrichMenuLevels(rows.map((r) => ({ ...r })) as MenuRow[]);
    applyFilter();
  }, [applyFilter]);

  useEffect(() => {
    void asyncAct.run(async () => {
      try {
        await loadMenus();
      } catch (e) {
        mesError(e);
      }
    }, "search");
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    // 트리 노드 변경 시 검색조건 유지한 채 즉시 재적용
    if (allMenusRef.current.length === 0) return;
    applyFilter();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [treeSel]);

  const toggleOpen = (cd: string) => {
    setOpenKeys((prev) => {
      const next = new Set(prev);
      if (next.has(cd)) next.delete(cd);
      else next.add(cd);
      return next;
    });
  };

  const handleSave = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    const dirty = g.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    const guard = guardSaveWithKey(grid.rules, grid.ctx, dirty, columns);
    if (guard) {
      mesToast(guard.message, "warn");
      if (guard.rowKey) setActiveKey(guard.rowKey);
      return;
    }
    for (const row of dirty) {
      if (!String(row.menuCd ?? "").trim() || !String(row.menuNm ?? "").trim()) {
        mesToast(MES.required("메뉴코드/메뉴명"), "warn");
        setActiveKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      await saveSystemRows(
        SCREEN,
        dirty.map((row) => {
          const next: SystemRow = { ...row };
          delete (next as { _key?: string })._key;
          delete (next as { _rowState?: string })._rowState;
          delete (next as { _original?: unknown })._original;
          delete (next as { grpANm?: string }).grpANm;
          delete (next as { grpBNm?: string }).grpBNm;
          delete (next as { grpCNm?: string }).grpCNm;
          return next;
        }),
      );
      mesToast(MES.saveDone, "success");
      await loadMenus();
    } catch (e) {
      mesError(e);
    }
  };

  const handleDelete = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(g.rows, activeKey, setActiveKey, selKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");
    const keys = targets
      .filter((r) => r._rowState !== "C" && r.idx != null)
      .map((r) => ({ idx: Number(r.idx) }));
    if (keys.length === 0) return mesToast(MES.selectRow, "warn");
    try {
      await validateDeleteSystemRows(SCREEN, keys);
      if (!(await mesConfirm(MES.deleteConfirm()))) return;
      await deleteSystemRows(SCREEN, keys);
      mesToast(MES.deleteDone, "success");
      await loadMenus();
    } catch (e) {
      mesError(e);
    }
  };

  const runSearch = () => {
    void asyncAct.run(async () => {
      try {
        if (allMenusRef.current.length === 0) await loadMenus();
        else applyFilter();
      } catch (e) {
        mesError(e);
      }
    }, "search");
  };

  usePageCommands({
    search: runSearch,
    // 메뉴는 행추가 불가
    add: undefined,
    save: canWrite || canModify ? () => { void asyncAct.run(handleSave, "save"); } : undefined,
    del: canDelete ? () => { void asyncAct.run(handleDelete, "del"); } : undefined,
  });

  const renderNode = (node: TreeNode, depth: number) => {
    const open = openKeys.has(node.menuCd);
    const selected = treeSel === node.menuCd;
    return (
      <div key={node.menuCd} style={{ paddingLeft: depth * 12 }}>
        <div className="flex items-center gap-1 py-0.5 text-[12px]">
          {node.children.length > 0 ? (
            <button
              // 하위 펼침/접기
              type="button"
              className="inline-flex h-5 w-5 items-center justify-center text-slate-500"
              onClick={() => toggleOpen(node.menuCd)}
              aria-expanded={open}
            >
              <ChevronRight
                className={cn("h-3.5 w-3.5 transition-transform", open && "rotate-90")}
                aria-hidden
              />
            </button>
          ) : (
            <span className="inline-block w-5" />
          )}
          <button
            // 직속 하위만 그리드 필터
            type="button"
            className={cn(
              "min-w-0 flex-1 truncate rounded px-1 py-0.5 text-left",
              selected ? treeNodeSelectedClass : treeNodeIdleClass,
            )}
            onClick={() => setTreeSel(node.menuCd)}
          >
            {node.name}
          </button>
        </div>
        {open && node.children.map((c) => renderNode(c, depth + 1))}
      </div>
    );
  };

  return (
    <div className={pageRootClass}>
      <PageCard
        search={
          <SearchArea
            onSearch={runSearch}
            actions={<SearchButton loading={asyncAct.isBusy("search")} />}
          >
            <SearchField label="메뉴코드">
              <input
                // 메뉴코드 부분검색
                className={searchInputClass}
                value={qMenuCd}
                onChange={(e) => setQMenuCd(e.target.value)}
                placeholder="메뉴코드"
              />
            </SearchField>
            <SearchField label="메뉴명">
              <input
                // 메뉴명 부분검색
                className={searchInputClass}
                value={qMenuNm}
                onChange={(e) => setQMenuNm(e.target.value)}
                placeholder="메뉴명"
              />
            </SearchField>
            <SearchSelect
              // 사용여부 — 기본 Y, 빈값=전체
              label="사용여부"
              value={qUseYn}
              onChange={setQUseYn}
            >
              <option value="">전체</option>
              {ynOpts.map((o) => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </SearchSelect>
          </SearchArea>
        }
      >
        <ResizableSplit
          // 좌 트리 · 우 그리드 (부서·권한그룹과 동일 규칙)
          orientation="horizontal"
          storageKey="haccp-split-menu-mgmt"
          // 트리:그리드 = 2:8 고정
          defaultPrimaryPct={20}
          minPct={20}
          maxPct={20}
          panelClassName="rounded-xl border border-slate-200 bg-white shadow-sm p-2"
          primary={
            <>
              <div className={treePanelHeadClass}>
                <b>메뉴 트리</b>
              </div>
              <TreePanelSearch
                // 트리 결과 내 검색 — 메뉴코드·명
                value={treeQuery}
                onChange={setTreeQuery}
                onSearch={runTreeSearch}
              />
              <div className="min-h-0 flex-1 overflow-y-auto rounded border border-slate-100 bg-white px-2 py-1">
                <div className="py-0.5 text-[12px]">
                  <button
                    // 「전체」 — 검색조건만 적용한 전건
                    type="button"
                    className={cn(
                      "w-full rounded px-1 py-0.5 text-left font-bold",
                      treeSel === TREE_ALL ? treeNodeSelectedClass : treeNodeIdleClass,
                    )}
                    onClick={() => setTreeSel(TREE_ALL)}
                  >
                    전체
                  </button>
                </div>
                {asyncAct.isBusy("search") && allMenusRef.current.length === 0 ? (
                  <p className="p-3 text-xs text-slate-500">불러오는 중…</p>
                ) : (
                  tree.nodes.map((n) => renderNode(n, 0))
                )}
              </div>
            </>
          }
          secondary={
            <>
              <div className={treePanelHeadClass}>
                <b>메뉴</b>
                <GridCrudButtons
                  run={asyncAct.run}
                  // 메뉴 행추가 불가
                  onAdd={undefined}
                  onSave={canWrite || canModify ? handleSave : undefined}
                  onDel={canDelete ? handleDelete : undefined}
                  busy={{ save: asyncAct.isBusy("save"), del: asyncAct.isBusy("del") }}
                />
              </div>
              <MesEditableGrid
                // 열 설정 저장 키 — 메뉴 마스터
                persistId="menu-mgmt-master"
                scrnCd={SCREEN}
                // 검색·트리 필터된 메뉴 행
                rows={g.rows as EditableRow<MenuRow>[]}
                columns={columns}
                // 메뉴명·사용여부만 편집
                editable={editable}
                title="메뉴"
                height="100%"
                loading={asyncAct.isBusy("search")}
                activeKey={activeKey}
                onActivate={(row) => setActiveKey(row._key)}
                onCellChange={(key, field, value) => g.updateCell(key, field as keyof MenuRow, value)}
                access={grid.access}
                onLockedAttempt={grid.onLockedAttempt}
                selectable
                onSelectionChange={(rows) => setSelKeys(rows.map((r) => r._key))}
                selectionResetKey={selReset}
                showRowNum
              />
            </>
          }
        />
      </PageCard>
    </div>
  );
}
