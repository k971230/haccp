/**
 * MenuManagementPage — 메뉴 좌 트리 + 우 그리드.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 좌측 hMenuCd 트리(최상단 「전체」=전건), 우측 메뉴 편집 그리드
 *   2) 노드 클릭 시 직속 하위만 표시하고, 정렬은 sort_no(대중소 인코딩) 순이다
 *   3) 컬럼·잠금·트리 산출은 MenuManagementRule이 갖고 이 파일은 렌더·상태·API만 담당한다
 *
 * PIPELINE[HF99] 메뉴 관리
 */
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useGridAccess } from "@/hooks/useGridAccess";
import { useEditableRows } from "@/hooks/useEditableRows";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
import { PageCard } from "@/components/layout/PageCard";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import {
  TreeNodeRow,
  TreePanelSearch,
  treeNodeIdleClass,
  treeNodeLabelClass,
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
import { mesConfirmDanger, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { usePageCommands } from "@/shell/pageCommands";
import { runGridSave, stripRowMeta } from "@/shell/gridRules";
import { resolveRowsForDelete } from "@/shell/resolveDelete";
import type { EditableRow } from "@/types/editable";
// 역할 — 메뉴 관리 도메인 API
import {
  deleteMenus,
  listAdminMenus,
  saveMenus,
  validateDeleteMenus,
} from "@/api/sys/menuApi";
import type { SysRow } from "@/api/sys/sysTypes";
// 역할 — 화면 규칙(컬럼·잠금·정렬·트리)
import {
  MENU_RULES,
  PERSIST_ID,
  REQUIRED_LABEL,
  SCRN_CD,
  TREE_ALL,
  buildMenuColumns,
  buildMenuTree,
  enrichMenuLevels,
  matchMenu,
  sortByMenuOrder,
  type MenuRow,
  type MenuTreeNode,
} from "./MenuManagementRule";

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 메뉴 목록·트리를 조회·저장한다
 *   2) menu-management 화면에서 마운트한다
 *   3) 행추가는 불가 — 시드·migrate로만 생성
 */
export default function MenuManagementPage() {
  const canWrite = useAuthStore((s) => s.can(SCRN_CD, "write"));
  const canModify = useAuthStore((s) => s.can(SCRN_CD, "modify"));
  const canDelete = useAuthStore((s) => s.can(SCRN_CD, "delete"));
  const asyncAct = useAsyncAction();
  const g = useEditableRows<MenuRow>("idx");
  // 메뉴 전건 보관 — 트리·대중소 산출·헤더 필터가 모두 이 목록을 본다
  const allMenusRef = useRef<MenuRow[]>([]);
  const grid = useGridAccess(MENU_RULES, {
    scrnCd: SCRN_CD,
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

  const columns = useMemo(
    () => buildMenuColumns(editable, ynOpts, ynLabels),
    [editable, ynLabels, ynOpts],
  );

  const fullTree = useMemo(
    () => buildMenuTree(allMenusRef.current),
    // 저장·조회 후 g.rows 갱신 시 트리 재구성
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [g.rows],
  );

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

  const applyFilter = useCallback(() => {
    let filtered = allMenusRef.current.filter((r) =>
      matchMenu(r, qMenuCd, qMenuNm, qUseYn),
    );
    // 트리 노드 선택 시(= 「전체」 아님) 직속 하위만
    if (treeSel !== TREE_ALL) {
      filtered = filtered.filter((r) => String(r.hMenuCd ?? "").trim() === treeSel);
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
    const rows = await listAdminMenus();
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
    // 순서·문구는 gridSave 가 갖는다 — 이 화면은 필수값과 저장 대상만 준다
    await runGridSave<MenuRow>({
      canWrite,
      canModify,
      dirty: g.getSaveRows(),
      rules: grid.rules,
      ctx: grid.ctx,
      columns,
      focusRow: setActiveKey,
      // 메뉴코드·메뉴명이 업무키다
      requiredOf: (row) =>
        !String(row.menuCd ?? "").trim() || !String(row.menuNm ?? "").trim()
          ? MES.required(REQUIRED_LABEL)
          : null,
      // 대·중·소분류는 트리에서 산출한 표시열이라 서버로 안 보낸다
      save: (rows) =>
        saveMenus(rows.map((row) => stripRowMeta<SysRow>(row as never, ["grpANm", "grpBNm", "grpCNm"]))),
      reload: loadMenus,
    });
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
      await validateDeleteMenus(keys);
      if (!(await mesConfirmDanger(MES.deleteConfirm()))) return;
      await deleteMenus(keys);
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

  const renderNode = (node: MenuTreeNode, depth: number) => {
    const open = openKeys.has(node.menuCd);
    const selected = treeSel === node.menuCd;
    return (
      <div key={node.menuCd}>
        <TreeNodeRow
          // 깊이 — 공통 컴포넌트가 12px 단위로 들여쓴다
          depth={depth}
          hasChild={node.children.length > 0}
          open={open}
          onToggle={() => toggleOpen(node.menuCd)}
        >
          <button
            // 직속 하위만 그리드 필터
            type="button"
            className={cn(
              treeNodeLabelClass,
              selected ? treeNodeSelectedClass : treeNodeIdleClass,
            )}
            onClick={() => setTreeSel(node.menuCd)}
          >
            {node.name}
          </button>
        </TreeNodeRow>
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
          storageKey="haccp-split-menu-mgmt-30"
          // 좌 트리 30 · 우 그리드 70 — 가로 분할은 30 또는 50만
          defaultPrimaryPct={30}
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
                persistId={PERSIST_ID}
                scrnCd={SCRN_CD}
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
