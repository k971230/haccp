/**
 * RoleManagementPage — 권한그룹 좌 메뉴권한 트리 + 우 마스터 그리드.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 좌측은 대·중·소 메뉴 트리와 readYn 체크, 우측은 권한그룹 CRUD
 *   2) 상단 그룹코드·그룹명·사용여부로 FE 필터한다(사용 기본 Y)
 *   3) 트리는 use_yn=Y 메뉴만 표시하고, 우 그리드 선택 행의 권한을 편집한다
 *
 * PIPELINE[HF99] 권한그룹 관리
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
  treePanelHeadClass,
} from "@/components/layout/TreePanelSearch";
import {
  SearchArea,
  SearchButton,
  SearchField,
  SearchSelect,
} from "@/components/layout/SearchArea";
import { pageRootClass } from "@/components/layout/pageClasses";
import { MesButton } from "@/components/ui/MesButton";
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
  listAdminMenus,
  listRoleScreens,
  listSystemRows,
  saveRoleScreens,
  saveSystemRows,
  validateDeleteSystemRows,
  type AdminMenuRow,
  type SystemRow,
} from "@/api/systemApi";
import { SYSTEM_GRID_RULES } from "./SystemManagementPage.rules";

const SCREEN = "role-management" as const;

type RoleRow = SystemRow & {
  _key?: string;
  usrgrpCd?: string;
  usrgrpNm?: string;
  descRmk?: string;
  useYn?: string;
  idx?: number | null;
};

type TreeNode = {
  menuCd: string;
  name: string;
  scrnCd?: string | null;
  children: TreeNode[];
};

function buildMenuTree(menus: AdminMenuRow[]): TreeNode[] {
  const ordered = [...menus]
    .filter((m) => String(m.useYn ?? "").toUpperCase() === "Y")
    .sort((a, b) => Number(a.sortNo ?? 0) - Number(b.sortNo ?? 0));
  const byCd = new Map(ordered.map((m) => [m.menuCd, m]));
  const nodes = new Map<string, TreeNode>();
  for (const m of ordered) {
    nodes.set(m.menuCd, {
      menuCd: m.menuCd,
      name: m.menuNm,
      scrnCd: m.scrnCd,
      children: [],
    });
  }
  const roots: TreeNode[] = [];
  for (const m of ordered) {
    const node = nodes.get(m.menuCd)!;
    const parent = m.hMenuCd ? nodes.get(m.hMenuCd) : undefined;
    if (parent) parent.children.push(node);
    else if (!m.hMenuCd || !byCd.has(m.hMenuCd)) roots.push(node);
  }
  return roots;
}

function collectLeafScrn(node: TreeNode): string[] {
  if (node.scrnCd) return [node.scrnCd];
  return node.children.flatMap(collectLeafScrn);
}

function matchRole(row: RoleRow, grpCd: string, grpNm: string, useYn: string): boolean {
  const qCd = grpCd.trim().toLowerCase();
  const qNm = grpNm.trim().toLowerCase();
  if (qCd && !String(row.usrgrpCd ?? "").toLowerCase().includes(qCd)) return false;
  if (qNm && !String(row.usrgrpNm ?? "").toLowerCase().includes(qNm)) return false;
  if (useYn && String(row.useYn ?? "").toUpperCase() !== useYn.toUpperCase()) return false;
  return true;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 권한그룹·메뉴 조회권한 트리를 조회·저장한다
 *   2) role-management 화면에서 마운트한다
 *   3) 권한 실패는 업무 토스트
 */
export default function RoleManagementPage() {
  const canWrite = useAuthStore((s) => s.can(SCREEN, "write"));
  const canModify = useAuthStore((s) => s.can(SCREEN, "modify"));
  const canDelete = useAuthStore((s) => s.can(SCREEN, "delete"));
  const asyncAct = useAsyncAction();
  const g = useEditableRows<RoleRow>("idx");
  const allRolesRef = useRef<RoleRow[]>([]);
  const grid = useGridAccess(SYSTEM_GRID_RULES[SCREEN], {
    scrnCd: SCREEN,
    gridRole: "single",
    readOnly: !canModify,
    extra: { canWrite, canModify, canDelete },
  });
  const [qGrpCd, setQGrpCd] = useState("");
  const [qGrpNm, setQGrpNm] = useState("");
  const [qUseYn, setQUseYn] = useState<string>(DEFAULT_USE_YN);
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  const [menus, setMenus] = useState<AdminMenuRow[]>([]);
  const [readMap, setReadMap] = useState<Record<string, string>>({});
  const [dirtyScrn, setDirtyScrn] = useState<Set<string>>(new Set());
  const [openKeys, setOpenKeys] = useState<Set<string>>(new Set());
  // 트리 결과 내 검색 — 메뉴코드·명
  const [treeQuery, setTreeQuery] = useState("");

  const ynOpts = useMemo(() => ynOptions(), []);
  const ynLabels = useMemo(() => ynMap(), []);

  const columns: GridColumn<RoleRow>[] = useMemo(
    () => [
      {
        field: "usrgrpCd",
        header: "그룹코드",
        width: 110,
        required: true,
        editableOnNew: true,
      },
      {
        field: "usrgrpNm",
        header: "그룹명",
        width: 140,
        editable: canWrite || canModify,
        required: true,
      },
      {
        field: "descRmk",
        header: "설명",
        width: 180,
        editable: canWrite || canModify,
      },
      {
        field: "useYn",
        header: "사용여부",
        width: 80,
        type: "code",
        editable: canWrite || canModify,
        codeOptions: ynOpts,
        codeMap: ynLabels,
        required: true,
      },
    ],
    [canModify, canWrite, ynLabels, ynOpts],
  );

  const activeRole = g.rows.find((r) => r._key === activeKey);
  const usrgrpCd = String(activeRole?.usrgrpCd ?? "").trim();
  const fullTree = useMemo(() => buildMenuTree(menus), [menus]);
  const tree = useMemo(
    () => filterTreeByQuery(fullTree, treeQuery, (n) => n.menuCd, (n) => n.name),
    [fullTree, treeQuery],
  );

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

  const applyRoleFilter = useCallback(() => {
    const filtered = allRolesRef.current.filter((r) =>
      matchRole(r, qGrpCd, qGrpNm, qUseYn),
    );
    g.load(filtered.map((r) => ({ ...r })) as RoleRow[]);
    setActiveKey(null);
    setSelKeys([]);
    setSelReset((n) => n + 1);
    setReadMap({});
    setDirtyScrn(new Set());
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [qGrpCd, qGrpNm, qUseYn]);

  const loadRoles = useCallback(async () => {
    const rows = await listSystemRows(SCREEN, { keyword: "" });
    allRolesRef.current = rows.map((r) => ({ ...r })) as RoleRow[];
    applyRoleFilter();
  }, [applyRoleFilter]);

  const loadTreeAuth = useCallback(async (grp: string) => {
    if (!grp) {
      setReadMap({});
      setDirtyScrn(new Set());
      return;
    }
    const [menuRows, screens] = await Promise.all([listAdminMenus(), listRoleScreens(grp)]);
    setMenus(menuRows);
    const map: Record<string, string> = {};
    for (const s of screens) {
      if (s.scrnCd) map[s.scrnCd] = String(s.readYn ?? "N").toUpperCase() === "Y" ? "Y" : "N";
    }
    setReadMap(map);
    setDirtyScrn(new Set());
    setOpenKeys(new Set(
      menuRows
        .filter((m) => String(m.useYn ?? "").toUpperCase() === "Y" && !m.hMenuCd)
        .map((m) => m.menuCd),
    ));
  }, []);

  useEffect(() => {
    void asyncAct.run(async () => {
      try {
        await loadRoles();
      } catch (e) {
        mesError(e);
      }
    }, "search");
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!usrgrpCd || activeRole?._rowState === "C") {
      setReadMap({});
      return;
    }
    void asyncAct.run(async () => {
      try {
        await loadTreeAuth(usrgrpCd);
      } catch (e) {
        mesError(e);
      }
    }, "tree");
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [usrgrpCd, activeRole?._rowState]);

  const toggleOpen = (cd: string) => {
    setOpenKeys((prev) => {
      const next = new Set(prev);
      if (next.has(cd)) next.delete(cd);
      else next.add(cd);
      return next;
    });
  };

  const setRead = (scrnCd: string, yn: string) => {
    setReadMap((prev) => ({ ...prev, [scrnCd]: yn }));
    setDirtyScrn((prev) => new Set(prev).add(scrnCd));
  };

  const handleAdd = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    // 행추가 시 이전 체크 해제
    setSelKeys([]);
    setSelReset((n) => n + 1);
    setActiveKey(g.addRow({ usrgrpCd: "", usrgrpNm: "", useYn: DEFAULT_USE_YN }));
  };

  const handleSaveRole = async () => {
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
      if (!String(row.usrgrpCd ?? "").trim() || !String(row.usrgrpNm ?? "").trim()) {
        mesToast(MES.required("그룹코드/그룹명"), "warn");
        setActiveKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      await saveSystemRows(SCREEN, dirty.map((row) => {
        const next: SystemRow = { ...row };
        delete (next as { _key?: string })._key;
        delete (next as { _rowState?: string })._rowState;
        delete (next as { _original?: unknown })._original;
        return next;
      }));
      mesToast(MES.saveDone, "success");
      await loadRoles();
    } catch (e) {
      mesError(e);
    }
  };

  const handleSaveTree = async () => {
    if (!canModify && !canWrite) return mesToast("수정 권한이 없습니다.", "warn");
    if (!usrgrpCd || activeRole?._rowState === "C") {
      return mesToast("권한그룹을 먼저 저장하세요.", "warn");
    }
    if (dirtyScrn.size === 0) return mesToast(MES.noChange, "warn");
    if (!(await mesConfirm("화면 권한을 저장하시겠습니까?"))) return;
    try {
      const rows = [...dirtyScrn].map((scrnCd) => ({
        scrnCd,
        readYn: readMap[scrnCd] === "Y" ? "Y" : "N",
      }));
      await saveRoleScreens(usrgrpCd, rows);
      mesToast(MES.saveDone, "success");
      await loadTreeAuth(usrgrpCd);
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
    const localOnly = targets.filter((r) => r._rowState === "C");
    if (keys.length === 0 && localOnly.length === 0) return mesToast(MES.selectRow, "warn");
    try {
      if (keys.length > 0) await validateDeleteSystemRows(SCREEN, keys);
      if (!(await mesConfirm(MES.deleteConfirm()))) return;
      if (keys.length > 0) await deleteSystemRows(SCREEN, keys);
      // 체크된 신규행만 로컬 제거 — 나머지 미저장 행추가분은 유지
      let lastFocus = activeKey;
      for (const r of localOnly) {
        const { focusKey } = g.removeNewRow(r._key!);
        lastFocus = focusKey;
      }
      setActiveKey(lastFocus);
      setSelKeys([]);
      setSelReset((n) => n + 1);
      mesToast(MES.deleteDone, "success");
      // 서버 행 삭제 시에만 재조회 — 신규만 지우면 load 시 남은 행추가가 전부 사라짐
      if (keys.length > 0) await loadRoles();
    } catch (e) {
      mesError(e);
    }
  };

  const runSearch = () => {
    void asyncAct.run(async () => {
      try {
        if (allRolesRef.current.length === 0) await loadRoles();
        else applyRoleFilter();
      } catch (e) {
        mesError(e);
      }
    }, "search");
  };

  usePageCommands({
    search: runSearch,
    add: canWrite ? handleAdd : undefined,
    save: canWrite || canModify ? () => { void asyncAct.run(handleSaveRole, "save"); } : undefined,
    del: canDelete ? () => { void asyncAct.run(handleDelete, "del"); } : undefined,
  });

  const renderNode = (node: TreeNode, depth: number) => {
    const open = openKeys.has(node.menuCd);
    const leaves = collectLeafScrn(node);
    const isLeaf = !!node.scrnCd;
    const checked = isLeaf
      ? readMap[node.scrnCd!] === "Y"
      : leaves.length > 0 && leaves.every((s) => readMap[s] === "Y");
    const partial = !isLeaf && !checked && leaves.some((s) => readMap[s] === "Y");
    return (
      <div key={node.menuCd} style={{ paddingLeft: depth * 12 }}>
        <div className="flex items-center gap-1 py-0.5 text-[12px]">
          {node.children.length > 0 ? (
            <button
              type="button"
              className="inline-flex h-5 w-5 items-center justify-center text-slate-500"
              onClick={() => toggleOpen(node.menuCd)}
              aria-expanded={open}
            >
              <ChevronRight className={cn("h-3.5 w-3.5 transition-transform", open && "rotate-90")} aria-hidden />
            </button>
          ) : (
            <span className="inline-block w-5" />
          )}
          <label className="flex min-w-0 flex-1 cursor-pointer items-center gap-1.5">
            <input
              type="checkbox"
              checked={checked}
              ref={(el) => {
                if (el) el.indeterminate = partial;
              }}
              disabled={(!canModify && !canWrite) || !usrgrpCd || activeRole?._rowState === "C"}
              onChange={(e) => {
                const yn = e.target.checked ? "Y" : "N";
                if (isLeaf && node.scrnCd) setRead(node.scrnCd, yn);
                else leaves.forEach((s) => setRead(s, yn));
              }}
            />
            <span className={cn("truncate", isLeaf ? "font-medium text-slate-800" : "font-bold text-slate-600")}>
              {node.name}
            </span>
          </label>
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
            <SearchField label="그룹코드">
              <input
                className={searchInputClass}
                value={qGrpCd}
                onChange={(e) => setQGrpCd(e.target.value)}
                placeholder="그룹코드"
              />
            </SearchField>
            <SearchField label="그룹명">
              <input
                className={searchInputClass}
                value={qGrpNm}
                onChange={(e) => setQGrpNm(e.target.value)}
                placeholder="그룹명"
              />
            </SearchField>
            <SearchSelect label="사용여부" value={qUseYn} onChange={setQUseYn}>
              <option value="">전체</option>
              {ynOpts.map((o) => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </SearchSelect>
          </SearchArea>
        }
      >
        <ResizableSplit
          // 좌 트리 · 우 그리드 (메뉴·부서와 동일 규칙)
          orientation="horizontal"
          storageKey="haccp-split-role-mgmt"
          // 트리:그리드 = 2:8 고정
          defaultPrimaryPct={20}
          minPct={20}
          maxPct={20}
          panelClassName="rounded-xl border border-slate-200 bg-white shadow-sm p-2"
          primary={
            <>
              <div className={treePanelHeadClass}>
                <b className="min-w-0 truncate">
                  메뉴 권한{usrgrpCd ? ` — ${usrgrpCd}` : ""}
                </b>
              </div>
              <TreePanelSearch
                // 트리 결과 내 검색 — 메뉴코드·명
                value={treeQuery}
                onChange={setTreeQuery}
                onSearch={runTreeSearch}
                // 검색 버튼 자리 — 권한저장
                action={
                  <MesButton
                    variant="save"
                    size="sm"
                    className="shrink-0"
                    disabled={asyncAct.isBusy("treeSave") || dirtyScrn.size === 0}
                    loading={asyncAct.isBusy("treeSave")}
                    onClick={() => void asyncAct.run(handleSaveTree, "treeSave")}
                  >
                    권한저장
                  </MesButton>
                }
              />
              <div className="min-h-0 flex-1 overflow-y-auto rounded border border-slate-100 bg-white px-2 py-1">
                {!usrgrpCd || activeRole?._rowState === "C" ? (
                  <p className="p-3 text-xs text-slate-500">저장된 권한그룹을 선택하세요.</p>
                ) : asyncAct.isBusy("tree") ? (
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
                <b>권한그룹</b>
                <GridCrudButtons
                  run={asyncAct.run}
                  onAdd={canWrite ? handleAdd : undefined}
                  onSave={canWrite || canModify ? handleSaveRole : undefined}
                  onDel={canDelete ? handleDelete : undefined}
                  busy={{ save: asyncAct.isBusy("save"), del: asyncAct.isBusy("del") }}
                />
              </div>
              <MesEditableGrid
                persistId="role-mgmt-master"
                scrnCd={SCREEN}
                rows={g.rows as EditableRow<RoleRow>[]}
                columns={columns}
                editable={canWrite || canModify}
                title="권한그룹"
                height="100%"
                loading={asyncAct.isBusy("search")}
                activeKey={activeKey}
                onActivate={(row) => setActiveKey(row._key)}
                onCellChange={(key, field, value) => g.updateCell(key, field as keyof RoleRow, value)}
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
