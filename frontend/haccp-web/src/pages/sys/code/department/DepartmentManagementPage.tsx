/**
 * DepartmentManagementPage — 부서 좌 트리 + 우 그리드 CRUD.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 좌측 hDeptCd 트리(최상단 「전체」=전건), 우측 부서 CRUD 그리드
 *   2) 노드 클릭 시 직속 하위만 표시하고, 목록·트리는 부서코드 순이다
 *   3) 상위부서 선택은 전역 공통 모달(openModal("CodeLookup"))을 쓴다 — 화면이 팝업 JSX를 갖지 않는다
 *
 * PIPELINE[HF99] 부서 관리
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
// 역할 — 전역 공통 모달 열기(상위부서 룩업)
import { useModalStore } from "@/stores/modalStore";
// 역할 — 부서 도메인 API
import {
  deleteDepartments,
  listDepartments,
  saveDepartments,
  validateDeleteDepartments,
} from "@/api/sys/departmentApi";
import type { SysRow } from "@/api/sys/sysTypes";
// 역할 — 화면 규칙(컬럼·잠금·초기값·트리)
import {
  DEPT_RULES,
  PERSIST_ID,
  REQUIRED_LABEL,
  SCRN_CD,
  TREE_ALL,
  buildDeptColumns,
  buildDeptTree,
  matchDept,
  newDeptRow,
  sortByDeptCd,
  type DeptRow,
  type DeptTreeNode,
} from "./DepartmentManagementRule";

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 부서 목록·트리를 조회·저장한다
 *   2) department-management 화면에서 마운트한다
 *   3) 권한·검증 실패는 업무 토스트
 */
export default function DepartmentManagementPage() {
  const canWrite = useAuthStore((s) => s.can(SCRN_CD, "write"));
  const canModify = useAuthStore((s) => s.can(SCRN_CD, "modify"));
  const canDelete = useAuthStore((s) => s.can(SCRN_CD, "delete"));
  const openModal = useModalStore((s) => s.openModal);
  const asyncAct = useAsyncAction();
  const g = useEditableRows<DeptRow>("idx");
  // 부서 전건 보관 — 트리·헤더 필터·상위부서 후보가 모두 이 목록을 본다
  const allDeptsRef = useRef<DeptRow[]>([]);
  const grid = useGridAccess(DEPT_RULES, {
    scrnCd: SCRN_CD,
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
    // 저장·조회 후 g.rows가 바뀌면 후보 목록도 다시 만든다
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [g.rows]);

  const openHDeptLookup = useCallback((row: DeptRow) => {
    if (!row._key) return;
    if (!canWrite && !canModify) return;
    const rowKey = row._key;
    setActiveKey(rowKey);
    // 자기 자신을 상위로 지정하지 못하게 후보에서 뺀다
    const selfCd = String(row.deptCd ?? "").trim();
    openModal("CodeLookup", {
      title: "상위부서 선택",
      scrnCd: SCRN_CD,
      options: deptOptions.filter((o) => o.value !== selfCd),
      value: String(row.hDeptCd ?? ""),
      // 최상위 부서로 만들 수 있게 (없음) 행을 넣는다
      allowEmpty: true,
      onSelect: (code, label) => {
        // 코드·명 동시 갱신 — (없음)이면 둘 다 빈 문자열
        g.updateCell(rowKey, "hDeptCd", code);
        g.updateCell(rowKey, "hDeptNm", label);
      },
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canModify, canWrite, deptOptions, openModal]);

  const columns = useMemo(
    () => buildDeptColumns(canWrite || canModify, openHDeptLookup, ynOpts, ynLabels),
    [canModify, canWrite, openHDeptLookup, ynLabels, ynOpts],
  );

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
    let filtered = allDeptsRef.current.filter((r) => matchDept(r, qDeptCd, qDeptNm, qUseYn));
    // 트리 노드 선택 시(= 「전체」 아님) 직속 하위만
    if (treeSel !== TREE_ALL) {
      filtered = filtered.filter((r) => String(r.hDeptCd ?? "").trim() === treeSel);
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
    const rows = await listDepartments();
    allDeptsRef.current = rows.map((r) => ({ ...r })) as DeptRow[];
    applyFilter();
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
    setActiveKey(g.addRow(newDeptRow(treeSel !== TREE_ALL ? treeSel : "")));
  };

  const handleSave = async () => {
    // 순서·문구는 gridSave 가 갖는다 — 이 화면은 필수값과 저장 대상만 준다
    await runGridSave<DeptRow>({
      canWrite,
      canModify,
      dirty: g.getSaveRows(),
      rules: grid.rules,
      ctx: grid.ctx,
      columns,
      focusRow: setActiveKey,
      // 부서코드·부서명이 업무키다
      requiredOf: (row) =>
        !String(row.deptCd ?? "").trim() || !String(row.deptNm ?? "").trim()
          ? MES.required(REQUIRED_LABEL)
          : null,
      save: (rows) => saveDepartments(rows.map((row) => stripRowMeta<SysRow>(row as never))),
      reload: loadDepts,
    });
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
      if (keys.length > 0) await validateDeleteDepartments(keys);
      if (!(await mesConfirmDanger(MES.deleteConfirm()))) return;
      if (keys.length > 0) await deleteDepartments(keys);
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

  const renderNode = (node: DeptTreeNode, depth: number) => {
    const open = openKeys.has(node.deptCd);
    const selected = treeSel === node.deptCd;
    return (
      <div key={node.deptCd}>
        <TreeNodeRow
          // 깊이 — 공통 컴포넌트가 12px 단위로 들여쓴다
          depth={depth}
          hasChild={node.children.length > 0}
          open={open}
          onToggle={() => toggleOpen(node.deptCd)}
        >
          <button
            // 직속 하위만 그리드 필터
            type="button"
            className={cn(
              treeNodeLabelClass,
              selected ? treeNodeSelectedClass : treeNodeIdleClass,
            )}
            onClick={() => setTreeSel(node.deptCd)}
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
          storageKey="haccp-split-dept-mgmt-30"
          // 좌 트리 30 · 우 그리드 70 — 가로 분할은 30 또는 50만
          defaultPrimaryPct={30}
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
                persistId={PERSIST_ID}
                scrnCd={SCRN_CD}
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
    </div>
  );
}
