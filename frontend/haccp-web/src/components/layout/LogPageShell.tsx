/**
 * LogPageShell — 로그인 이력·감사 로그·화면 이용 통계 공통 레이아웃.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 기간 검색·좌측 트리(30%)·조회 전용 그리드라는 뼈대만 갖고, 컬럼·조회 API는 Rule이 주입한다
 *   2) 인스턴스별 상태를 갖는 컴포넌트다 — 각 Page가 key={rule.scrnCd}로 렌더해 탭 간 상태가 섞이지 않게 한다
 *   3) 모듈 레벨 캐시를 두지 않는다. 셸을 여러 개 동시에 마운트해도 서로 독립이다
 *
 * PIPELINE[HF99] 로그 화면 공통 셸
 */
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import dayjs from "dayjs";
import { MesDataGrid } from "@/components/grid/MesDataGrid";
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
import { SearchArea, SearchButton, SearchDateRange } from "@/components/layout/SearchArea";
import { pageRootClass } from "@/components/layout/pageClasses";
import { cn } from "@/lib/cn";
import { filterTreeByQuery } from "@/lib/treeFilter";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useCommonCodes } from "@/hooks/useCommonCodes";
import { mesError } from "@/shell/errors";
import { usePageCommands } from "@/shell/pageCommands";
import type { GridColumn } from "@/types/grid";
// 역할 — 좌측 사용자 트리 원본
import { listUsers } from "@/api/sys/userApi";
// 역할 — 좌측 메뉴 트리 원본
import { listAdminMenus } from "@/api/sys/menuApi";
import type { AdminMenuRow, SysRow } from "@/api/sys/sysTypes";

/** 트리 「전체」 가상 키 — 기간 조건만 적용한 전건 */
export const TREE_ALL = "__ALL__";

/** 로그 그리드 1행 — 화면마다 컬럼이 다르므로 느슨한 Record */
export type LogRow = SysRow & { _key?: string };

/** 사용자 트리 1행 — 계층 없이 평면 */
export type FlatNode = { key: string; label: string };

/** 메뉴 트리 노드 — scrnCd가 있으면 화면(리프) */
export type HierNode = { key: string; label: string; scrnCd?: string | null; children: HierNode[] };

/** 조회 파라미터 — Rule.fetchRows가 받는다 */
export interface LogFetchArgs {
  /** 조회 시작일 YYYYMMDD */
  fromDt: string;
  /** 조회 종료일 YYYYMMDD */
  toDt: string;
  /** 트리 선택 키 — 「전체」면 TREE_ALL */
  selKey: string;
  /** 선택된 메뉴 노드 — 사용자 트리 화면이거나 「전체」면 null */
  selNode: HierNode | null;
}

/** 로그 화면 1개의 설정 — *Rule.ts가 이 모양으로 노출한다 */
export interface LogRule {
  /** 화면코드 — 권한·그리드 pref·탭 key */
  scrnCd: string;
  /** 그리드 열 설정 저장 키 */
  persistId: string;
  /** 그리드·패널 제목 */
  title: string;
  /** 좌측 패널 제목 */
  treeHead: string;
  /** 좌측 트리 종류 — 사용자 평면 목록 또는 메뉴 계층 */
  treeKind: "user" | "menu";
  /** 기간 기본값(일) — 오늘부터 며칠 전까지 */
  rangeDays: number;
  /** 코드 컬럼에 쓸 공통코드 대분류 — 없으면 빈 문자열 */
  codeGroup: string;
  /** 그리드 컬럼 — 코드 컬럼이 있으면 codeMap·codeOptions를 쓴다 */
  buildColumns: (
    codeMap: Record<string, string>,
    codeOptions: Array<{ value: string; label: string }>,
  ) => GridColumn<LogRow>[];
  /** 조회 — 화면별 API 호출과 표시 가공(일시 포맷·하위 필터)을 모두 담당한다 */
  fetchRows: (args: LogFetchArgs) => Promise<LogRow[]>;
}

/** 오늘 YYYYMMDD */
function todayYmd(): string {
  return dayjs().format("YYYYMMDD");
}

/** n일 전 YYYYMMDD */
function daysAgoYmd(days: number): string {
  return dayjs().subtract(days, "day").format("YYYYMMDD");
}

/** YYYYMMDD → input[type=date] 값 */
function ymdToInput(ymd: string): string {
  return ymd.length === 8 ? `${ymd.slice(0, 4)}-${ymd.slice(4, 6)}-${ymd.slice(6)}` : "";
}

/** input[type=date] 값 → YYYYMMDD */
function inputToYmd(v: string): string {
  return v.replace(/-/g, "");
}

/** 관리용 메뉴 목록 → 계층 트리 — 사용중지 메뉴는 제외한다 */
export function buildMenuTree(menus: AdminMenuRow[]): HierNode[] {
  const ordered = [...menus]
    .filter((m) => String(m.useYn ?? "Y").toUpperCase() === "Y")
    .filter((m) => String(m.menuCd ?? "").trim())
    .sort((a, b) => Number(a.sortNo ?? 0) - Number(b.sortNo ?? 0));
  const nodes = new Map<string, HierNode>();
  for (const m of ordered) {
    const cd = String(m.menuCd);
    nodes.set(cd, {
      key: cd,
      label: String(m.menuNm ?? cd),
      scrnCd: m.scrnCd ? String(m.scrnCd) : null,
      children: [],
    });
  }
  const roots: HierNode[] = [];
  for (const m of ordered) {
    const cd = String(m.menuCd);
    const node = nodes.get(cd)!;
    const parentCd = String(m.hMenuCd ?? "").trim();
    const parent = parentCd ? nodes.get(parentCd) : undefined;
    if (parent && parentCd !== cd) parent.children.push(node);
    else roots.push(node);
  }
  return roots;
}

/** 노드 하위의 화면코드 전부 — 폴더 선택 시 통계 FE 필터용 */
export function collectScrnCds(node: HierNode): string[] {
  const out: string[] = [];
  const walk = (n: HierNode) => {
    if (n.scrnCd) out.push(n.scrnCd);
    n.children.forEach(walk);
  };
  walk(node);
  return out;
}

/** 감사 필터용 — 하위 메뉴코드·화면코드·메뉴명 키 집합 */
export function collectAuditKeys(node: HierNode): Set<string> {
  const keys = new Set<string>();
  const walk = (n: HierNode) => {
    keys.add(n.key);
    if (n.scrnCd) keys.add(n.scrnCd);
    if (n.label) keys.add(n.label);
    n.children.forEach(walk);
  };
  walk(node);
  return keys;
}

/** 트리에서 키로 노드 찾기 — 선택 노드의 하위 정보를 Rule에 넘기기 위해 쓴다 */
export function findHierNode(nodes: HierNode[], key: string): HierNode | null {
  for (const n of nodes) {
    if (n.key === key) return n;
    const c = findHierNode(n.children, key);
    if (c) return c;
  }
  return null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 기간·트리 조회 UI를 렌더하고 Rule이 준 컬럼·조회 함수로 그리드를 채운다
 *   2) 로그 3화면 Page가 각자 key={rule.scrnCd}로 마운트한다
 *   3) 조회 실패는 업무 토스트, 겹친 요청은 마지막 응답만 반영한다
 */
export function LogPageShell({
  // 화면 설정 — 컬럼·조회 API·트리 종류·pref 키
  rule,
}: {
  rule: LogRule;
}) {
  const asyncAct = useAsyncAction();
  // 코드 컬럼용 공통코드 — codeGroup이 빈 화면은 호출하지 않는다
  const codes = useCommonCodes(rule.codeGroup);
  // 최신 조회만 반영 — 트리·기간 변경으로 load가 겹칠 때 이전 응답 무시
  const loadSeq = useRef(0);
  const [loading, setLoading] = useState(false);

  const [fromDt, setFromDt] = useState(() => daysAgoYmd(rule.rangeDays));
  const [toDt, setToDt] = useState(todayYmd);
  const [rows, setRows] = useState<LogRow[]>([]);
  const [treeSel, setTreeSel] = useState(TREE_ALL);
  const [treeQuery, setTreeQuery] = useState("");
  const [openKeys, setOpenKeys] = useState<Set<string>>(new Set([TREE_ALL]));
  // 로그인 이력 트리 — 사용자 평면 목록
  const [users, setUsers] = useState<FlatNode[]>([]);
  // 감사·통계 트리 — 관리자 메뉴 계층
  const [menus, setMenus] = useState<AdminMenuRow[]>([]);

  const useMenuHier = rule.treeKind === "menu";

  const columns = useMemo(
    () => rule.buildColumns(
      codes.codeMap,
      codes.codes.map((c) => ({ value: c.subCd, label: c.codeNm })),
    ),
    [codes.codeMap, codes.codes, rule],
  );

  const loadTree = useCallback(async () => {
    try {
      if (!useMenuHier) {
        const list = await listUsers();
        const next = list
          .map((r) => ({
            key: String(r.userId ?? "").trim(),
            label: `${String(r.userNm ?? r.userId ?? "").trim()}(${String(r.userId ?? "").trim()})`,
          }))
          .filter((n) => n.key)
          .sort((a, b) => a.label.localeCompare(b.label, "ko"));
        setUsers(next);
        return;
      }
      const admin = await listAdminMenus();
      setMenus(admin.filter((m) => String(m.useYn ?? "Y").toUpperCase() === "Y"));
    } catch (e) {
      mesError(e);
    }
  }, [useMenuHier]);

  const load = useCallback(async () => {
    // 겹친 요청 중 마지막만 setRows — useAsyncAction 잠금으로 조회가 스킵되지 않게 함
    const seq = ++loadSeq.current;
    setLoading(true);
    try {
      const hier = useMenuHier ? buildMenuTree(menus) : [];
      const selNode =
        treeSel !== TREE_ALL && useMenuHier ? findHierNode(hier, treeSel) : null;
      const next = await rule.fetchRows({ fromDt, toDt, selKey: treeSel, selNode });
      if (seq !== loadSeq.current) return;
      setRows(next.map((r, i) => ({ ...r, _key: String(r._key ?? r.idx ?? `${rule.scrnCd}-${i}`) })));
    } catch (e) {
      if (seq !== loadSeq.current) return;
      mesError(e);
    } finally {
      if (seq === loadSeq.current) setLoading(false);
    }
  }, [fromDt, menus, rule, toDt, treeSel, useMenuHier]);

  useEffect(() => {
    void loadTree();
  }, [loadTree]);

  // 기간·트리 변경 시 즉시 조회 — asyncAct 잠금 없이 호출(겹치면 seq로 무시)
  useEffect(() => {
    void load();
  }, [load]);

  const runSearch = useCallback(() => {
    void asyncAct.run(load, "search");
  }, [asyncAct, load]);

  usePageCommands({ search: runSearch });

  const flatFiltered = useMemo(() => {
    if (useMenuHier) return [];
    const q = treeQuery.trim().toLowerCase();
    if (!q) return users;
    return users.filter(
      (u) => u.key.toLowerCase().includes(q) || u.label.toLowerCase().includes(q),
    );
  }, [treeQuery, useMenuHier, users]);

  const hierTree = useMemo(() => {
    if (!useMenuHier) return { nodes: [] as HierNode[], openKeys: new Set<string>() };
    const full = buildMenuTree(menus);
    return filterTreeByQuery(full, treeQuery, (n) => n.key, (n) => n.label);
  }, [menus, treeQuery, useMenuHier]);

  const runTreeSearch = useCallback(() => {
    if (!treeQuery.trim() || !useMenuHier) return;
    setOpenKeys((prev) => {
      const next = new Set(prev);
      for (const k of hierTree.openKeys) next.add(k);
      next.add(TREE_ALL);
      return next;
    });
  }, [hierTree.openKeys, treeQuery, useMenuHier]);

  useEffect(() => {
    runTreeSearch();
  }, [runTreeSearch]);

  /** 노드 선택 — 하위가 있으면 펼쳐서 메뉴관리처럼 자식이 보이게 한다 */
  const selectHierNode = (node: HierNode) => {
    setTreeSel(node.key);
    if (node.children.length > 0) {
      setOpenKeys((prev) => {
        const next = new Set(prev);
        next.add(node.key);
        return next;
      });
    }
  };

  const renderHier = (node: HierNode, depth: number): ReactNode => {
    const hasChild = node.children.length > 0;
    const open = openKeys.has(node.key);
    const selected = treeSel === node.key;
    return (
      <div key={node.key}>
        <TreeNodeRow
          // 깊이 — 공통 컴포넌트가 12px 단위로 들여쓴다
          depth={depth}
          hasChild={hasChild}
          open={open}
          onToggle={() =>
            setOpenKeys((prev) => {
              const next = new Set(prev);
              if (next.has(node.key)) next.delete(node.key);
              else next.add(node.key);
              return next;
            })
          }
        >
          <button
            // 노드 선택 — 하위 포함 필터
            type="button"
            className={cn(
              treeNodeLabelClass,
              selected ? treeNodeSelectedClass : treeNodeIdleClass,
            )}
            onClick={() => selectHierNode(node)}
          >
            {node.label}
          </button>
        </TreeNodeRow>
        {open && node.children.map((c) => renderHier(c, depth + 1))}
      </div>
    );
  };

  return (
    <div className={pageRootClass}>
      <PageCard
        search={
          <SearchArea
            onSearch={runSearch}
            actions={<SearchButton loading={loading || asyncAct.isBusy("search")} />}
          >
            <SearchDateRange
              // 시작일·종료일만
              label="기간"
              from={ymdToInput(fromDt)}
              to={ymdToInput(toDt)}
              onFrom={(v) => setFromDt(inputToYmd(v))}
              onTo={(v) => setToDt(inputToYmd(v))}
            />
          </SearchArea>
        }
      >
        <ResizableSplit
          // 좌 트리 · 우 그리드 (시스템 관리 화면과 동일 규칙)
          orientation="horizontal"
          storageKey={`haccp-split-log-${rule.scrnCd}-30`}
          // 좌 트리 30 · 우 그리드 70 — 가로 분할은 30 또는 50만
          defaultPrimaryPct={30}
          panelClassName="rounded-xl border border-slate-200 bg-white shadow-sm p-2"
          primary={
            <>
              <div className={treePanelHeadClass}>
                <b>{rule.treeHead}</b>
              </div>
              <TreePanelSearch
                // 트리 결과 내 검색 — 사용자/메뉴 공통
                value={treeQuery}
                onChange={setTreeQuery}
                onSearch={useMenuHier ? runTreeSearch : undefined}
              />
              <div className="min-h-0 flex-1 overflow-y-auto rounded border border-slate-100 bg-white px-2 py-1">
                <div className="py-0.5 text-[12px]">
                  <button
                    // 「전체」 — 기간 조건만 적용한 전건
                    type="button"
                    className={cn(
                      "w-full rounded px-1 py-0.5 text-left font-bold",
                      treeSel === TREE_ALL ? treeNodeSelectedClass : treeNodeIdleClass,
                    )}
                    onClick={() => setTreeSel(TREE_ALL)}
                  >
                    전체
                  </button>
                  {useMenuHier
                    ? hierTree.nodes.map((n) => renderHier(n, 0))
                    : flatFiltered.map((n) => (
                      <TreeNodeRow
                        // 평면 목록이라 항상 깊이 0·하위 없음 — 계층 트리와 행 높이를 맞추려고 같은 행을 쓴다
                        key={n.key}
                        depth={0}
                        hasChild={false}
                        open={false}
                        onToggle={() => undefined}
                      >
                        <button
                          // 사용자 1명 — 해당 아이디만 조회
                          type="button"
                          className={cn(
                            treeNodeLabelClass,
                            treeSel === n.key ? treeNodeSelectedClass : treeNodeIdleClass,
                          )}
                          onClick={() => setTreeSel(n.key)}
                        >
                          {n.label}
                        </button>
                      </TreeNodeRow>
                    ))}
                </div>
              </div>
            </>
          }
          secondary={
            <>
              <div className={treePanelHeadClass}>
                <b>{rule.title}</b>
              </div>
              <MesDataGrid
                // 로그 그리드 — 열 설정 키 (패널 flex 직계 자식이어야 height 100% 채움)
                persistId={rule.persistId}
                // pref 저장 — persistId와 함께 필수
                scrnCd={rule.scrnCd}
                // 조회 결과 행
                rows={rows}
                columns={columns}
                rowKey={(r) => String(r._key ?? "")}
                loading={loading || asyncAct.isBusy("search")}
                height="100%"
                showToolbar
                showFooter
                showRowNum
                sortable
                title={rule.title}
              />
            </>
          }
        />
      </PageCard>
    </div>
  );
}
