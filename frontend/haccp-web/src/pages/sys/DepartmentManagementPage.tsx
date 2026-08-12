/**
 * DepartmentManagementPage — 부서 좌 트리 + 우 그리드 CRUD.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 좌측 hDeptCd 트리(최상단 「전체」=전건), 우측 부서 CRUD 그리드
 *   2) 노드 클릭 시 직속 하위만 표시하고, 목록·트리는 부서코드 순이다
 *   3) 상단 부서코드·부서명·사용여부로 FE 필터한다(사용 기본 Y)
 *
 * PIPELINE[HF99] 부서 관리
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
import { CodeLookupDialog } from "./CodeLookupDialog";

const SCREEN = "department-management" as const;
/** 트리 「전체」 가상 키 — 전건 표시 */
const TREE_ALL = "__ALL__";

type DeptRow = SystemRow & {
  _key?: string;
  deptCd?: string;
  deptNm?: string;
  hDeptCd?: string;
  // 상위부서명 — SP self JOIN (h_dept_nm)
  hDeptNm?: string;
  sortNo?: number | null;
  useYn?: string;
  idx?: number | null;
};

type TreeNode = {
  deptCd: string;
  name: string;
  children: TreeNode[];
};

function matchDept(row: DeptRow, deptCd: string, deptNm: string, useYn: string): boolean {
  const qCd = deptCd.trim().toLowerCase();
  const qNm = deptNm.trim().toLowerCase();
  if (qCd && !String(row.deptCd ?? "").toLowerCase().includes(qCd)) return false;
  if (qNm && !String(row.deptNm ?? "").toLowerCase().includes(qNm)) return false;
  if (useYn && String(row.useYn ?? "").toUpperCase() !== useYn.toUpperCase()) return false;
  return true;
}

function sortByDeptCd(a: DeptRow, b: DeptRow): number {
  return String(a.deptCd ?? "").localeCompare(String(b.deptCd ?? ""), "ko");
}

function buildDeptTree(rows: DeptRow[]): TreeNode[] {
  // 트리·형제 순서 — 부서코드
  const ordered = [...rows]
    .filter((r) => String(r.deptCd ?? "").trim())
    .sort(sortByDeptCd);
  const nodes = new Map<string, TreeNode>();
  for (const r of ordered) {
    const cd = String(r.deptCd);
    nodes.set(cd, {
      deptCd: cd,
      name: String(r.deptNm ?? cd),
      children: [],
    });
  }
  const roots: TreeNode[] = [];
  for (const r of ordered) {
    const cd = String(r.deptCd);
    const node = nodes.get(cd)!;
    const parentCd = String(r.hDeptCd ?? "").trim();
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
 *   1) 부서 목록·트리를 조회·저장한다
 *   2) department-management 화면에서 마운트한다
 *   3) 권한·검증 실패는 업무 토스트
 */
export default function DepartmentManagementPage() {
  const canWrite = useAuthStore((s) => s.can(SCREEN, "write"));
  const canModify = useAuthStore((s) => s.can(SCREEN, "modify"));
  const canDelete = useAuthStore((s) => s.can(SCREEN, "delete"));
  const asyncAct = useAsyncAction();
  const g = useEditableRows<DeptRow>("idx");
  const allDeptsRef = useRef<DeptRow[]>([]);
  const grid = useGridAccess(SYSTEM_GRID_RULES[SCREEN], {
    scrnCd: SCREEN,
    gridRole: "single",
    readOnly: !canModify,
    extra: { canWrite, canModify, canDelete },
  });
  const [qDeptCd, setQDeptCd] = useState("");
  const [qDeptNm, setQDeptNm] = useState("");
  const [qUseYn, setQUseYn] = useState<string>(DEFAULT_USE_YN);
  // 트리 선택 — TREE_ALL 또는 부서코드(직속 하위만)
  const [treeSel, setTreeSel] = useState<string>(TREE_ALL);
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  const [openKeys, setOpenKeys] = useState<Set<string>>(new Set([TREE_ALL]));
  // 트리 결과 내 검색 — 부서코드·명
  const [treeQuery, setTreeQuery] = useState("");
  // 상위부서 코드 팝업
  const [hDeptLookup, setHDeptLookup] = useState<{
    rowKey: string;
    value: string;
    selfCd: string;
  } | null>(null);

  const ynOpts = useMemo(() => ynOptions(), []);
  const ynLabels = useMemo(() => ynMap(), []);

  const deptOptions = useMemo(() => {
    return allDeptsRef.current
      .filter((r) => String(r.useYn ?? "Y").toUpperCase() === "Y")
      .map((r) => ({
        value: String(r.deptCd ?? ""),
        label: String(r.deptNm ?? r.deptCd ?? ""),
      }))
      .filter((o) => o.value);
  }, [g.rows]);

  const openHDeptLookup = useCallback((row: DeptRow) => {
    if (!row._key) return;
    if (!canWrite && !canModify) return;
    setActiveKey(row._key);
    setHDeptLookup({
      rowKey: row._key,
      value: String(row.hDeptCd ?? ""),
      selfCd: String(row.deptCd ?? "").trim(),
    });
  }, [canModify, canWrite]);

  const columns: GridColumn<DeptRow>[] = useMemo(
    () => [
      {
        field: "deptCd",
        header: "부서코드",
        width: 100,
        required: true,
        editableOnNew: true,
      },
      {
        field: "deptNm",
        header: "부서명",
        width: 140,
        editable: canWrite || canModify,
        required: true,
      },
      {
        // 상위부서코드 — 기본 숨김, 「열」메뉴로 표시·pref 저장 가능
        field: "hDeptCd",
        header: "상위부서코드",
        width: 100,
        defaultHidden: true,
        editable: false,
      },
      {
        // 상위부서명 — self JOIN 표시 + 룩업 박스
        field: "hDeptNm",
        header: "상위부서",
        width: 140,
        editable: false,
        cellButton: (canWrite || canModify)
          ? {
            title: "상위부서",
            onClick: (row) => openHDeptLookup(row),
          }
          : undefined,
      },
      {
        field: "sortNo",
        header: "정렬",
        width: 70,
        type: "number",
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
    [canModify, canWrite, openHDeptLookup, ynLabels, ynOpts],
  );

  // 상위부서 후보 — 자기 자신 제외
  const hDeptOptions = useMemo(() => {
    const self = hDeptLookup?.selfCd ?? "";
    return deptOptions.filter((o) => o.value !== self);
  }, [deptOptions, hDeptLookup?.selfCd]);

  const fullTree = useMemo(
    () => buildDeptTree(allDeptsRef.current),
    // 저장·조회 후 g.rows 갱신 시 트리 재구성
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [g.rows],
  );

  const tree = useMemo(
    () => filterTreeByQuery(fullTree, treeQuery, (n) => n.deptCd, (n) => n.name),
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
    runTreeSearch();
  }, [runTreeSearch]);

  const applyFilter = useCallback(() => {
    let filtered = allDeptsRef.current.filter((r) =>
      matchDept(r, qDeptCd, qDeptNm, qUseYn),
    );
    // 트리 노드 선택 시(= 「전체」 아님) 직속 하위만
    if (treeSel !== TREE_ALL) {
      filtered = filtered.filter(
        (r) => String(r.hDeptCd ?? "").trim() === treeSel,
      );
    }
    // 그리드 표시 순서 — 부서코드
    filtered = [...filtered].sort(sortByDeptCd);
    g.load(filtered.map((r) => ({ ...r })) as DeptRow[]);
    setActiveKey(null);
    setSelKeys([]);
    setSelReset((n) => n + 1);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [qDeptCd, qDeptNm, qUseYn, treeSel]);

  const loadDepts = useCallback(async () => {
    const rows = await listSystemRows(SCREEN, { keyword: "" });
    allDeptsRef.current = rows.map((r) => ({ ...r })) as DeptRow[];
    applyFilter();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [applyFilter]);

  useEffect(() => {
    void asyncAct.run(async () => {
      try {
        await loadDepts();
      } catch (e) {
        mesError(e);
      }
    }, "search");
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    // 트리 노드 변경 시(= 직속 하위 필터) 검색조건 유지한 채 즉시 재적용
    if (allDeptsRef.current.length === 0) return;
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

  const handleAdd = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    // 행추가 시 이전 체크 해제
    setSelKeys([]);
    setSelReset((n) => n + 1);
    const hDept =
      treeSel !== TREE_ALL ? treeSel : "";
    setActiveKey(
      g.addRow({
        deptCd: "",
        deptNm: "",
        hDeptCd: hDept,
        sortNo: 0,
        useYn: DEFAULT_USE_YN,
      }),
    );
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
      if (!String(row.deptCd ?? "").trim() || !String(row.deptNm ?? "").trim()) {
        mesToast(MES.required("부서코드/부서명"), "warn");
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
          return next;
        }),
      );
      mesToast(MES.saveDone, "success");
      await loadDepts();
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
      if (keys.length > 0) await loadDepts();
    } catch (e) {
      mesError(e);
    }
  };

  const runSearch = () => {
    void asyncAct.run(async () => {
      try {
        if (allDeptsRef.current.length === 0) await loadDepts();
        else applyFilter();
      } catch (e) {
        mesError(e);
      }
    }, "search");
  };

  usePageCommands({
    search: runSearch,
    add: canWrite ? handleAdd : undefined,
    save: canWrite || canModify ? () => { void asyncAct.run(handleSave, "save"); } : undefined,
    del: canDelete ? () => { void asyncAct.run(handleDelete, "del"); } : undefined,
  });

  const renderNode = (node: TreeNode, depth: number) => {
    const open = openKeys.has(node.deptCd);
    const selected = treeSel === node.deptCd;
    return (
      <div key={node.deptCd} style={{ paddingLeft: depth * 12 }}>
        <div className="flex items-center gap-1 py-0.5 text-[12px]">
          {node.children.length > 0 ? (
            <button
              // 하위 펼침/접기
              type="button"
              className="inline-flex h-5 w-5 items-center justify-center text-slate-500"
              onClick={() => toggleOpen(node.deptCd)}
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
            onClick={() => setTreeSel(node.deptCd)}
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
            <SearchField label="부서코드">
              <input
                // 부서코드 부분검색
                className={searchInputClass}
                value={qDeptCd}
                onChange={(e) => setQDeptCd(e.target.value)}
                placeholder="부서코드"
              />
            </SearchField>
            <SearchField label="부서명">
              <input
                // 부서명 부분검색
                className={searchInputClass}
                value={qDeptNm}
                onChange={(e) => setQDeptNm(e.target.value)}
                placeholder="부서명"
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
          // 좌 트리 · 우 그리드 (메뉴·권한그룹과 동일 규칙)
          orientation="horizontal"
          storageKey="haccp-split-dept-mgmt"
          // 트리:그리드 = 2:8 고정
          defaultPrimaryPct={20}
          minPct={20}
          maxPct={20}
          panelClassName="rounded-xl border border-slate-200 bg-white shadow-sm p-2"
          primary={
            <>
              <div className={treePanelHeadClass}>
                <b>부서 트리</b>
              </div>
              <TreePanelSearch
                // 트리 결과 내 검색 — 부서코드·명
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
                {asyncAct.isBusy("search") && allDeptsRef.current.length === 0 ? (
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
                <b>부서</b>
                <GridCrudButtons
                  run={asyncAct.run}
                  onAdd={canWrite ? handleAdd : undefined}
                  onSave={canWrite || canModify ? handleSave : undefined}
                  onDel={canDelete ? handleDelete : undefined}
                  busy={{ save: asyncAct.isBusy("save"), del: asyncAct.isBusy("del") }}
                />
              </div>
              <MesEditableGrid
                // 열 설정 저장 키 — 부서 마스터
                // v2 — hDeptCd defaultHidden·hDeptNm 표시열 전환 후 구 pref 무효화
                persistId="dept-mgmt-master-v2"
                scrnCd={SCREEN}
                // 검색·트리 필터된 부서 행
                rows={g.rows as EditableRow<DeptRow>[]}
                columns={columns}
                // 등록·수정 권한일 때 편집
                editable={canWrite || canModify}
                title="부서"
                height="100%"
                loading={asyncAct.isBusy("search")}
                activeKey={activeKey}
                onActivate={(row) => setActiveKey(row._key)}
                onCellChange={(key, field, value) => g.updateCell(key, field as keyof DeptRow, value)}
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

      {hDeptLookup ? (
        <CodeLookupDialog
          // 상위부서 코드 선택
          open
          title="상위부서 선택"
          // pref 저장용 화면코드
          scrnCd={SCREEN}
          options={hDeptOptions}
          value={hDeptLookup.value}
          allowEmpty
          onClose={() => setHDeptLookup(null)}
          onSelect={(code, label) => {
            // 코드·명 동시 갱신 — (없음)이면 둘 다 빈 문자열
            g.updateCell(hDeptLookup.rowKey, "hDeptCd", code);
            g.updateCell(hDeptLookup.rowKey, "hDeptNm", label);
            setHDeptLookup(null);
          }}
        />
      ) : null}
    </div>
  );
}
