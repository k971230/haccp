/**
 * LogManagementPage — 로그인 이력·화면 이용 통계·변경 감사 로그.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 세 화면 모두 좌측 트리+기간 조회로 읽기 전용이다
 *   2) 로그인=사용자 트리, 감사·통계=메뉴관리와 동일 계층 트리를 쓴다
 *   3) CRUD 없이 listSystemRows만 호출한다
 *
 * PIPELINE[HF99] 로그 관리
 */
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { ChevronRight } from "lucide-react";
import dayjs from "dayjs";
import { MesDataGrid } from "@/components/grid/MesDataGrid";
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
  SearchDateRange,
} from "@/components/layout/SearchArea";
import { pageRootClass } from "@/components/layout/pageClasses";
import { cn } from "@/lib/cn";
import { filterTreeByQuery } from "@/lib/treeFilter";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useCommonCodes } from "@/hooks/useCommonCodes";
import { mesError } from "@/shell/errors";
import { usePageCommands } from "@/shell/pageCommands";
import type { GridColumn } from "@/types/grid";
import { fmtDateTimeMinute } from "@/utils/date";
import {
  listAdminMenus,
  listSystemRows,
  type AdminMenuRow,
  type SystemRow,
  type SystemScreenCode,
} from "@/api/systemApi";

const TREE_ALL = "__ALL__";
const HISTORY_DEFAULT_RANGE_DAYS = 30;

function todayYmd(): string {
  return dayjs().format("YYYYMMDD");
}

function daysAgoYmd(days: number): string {
  return dayjs().subtract(days, "day").format("YYYYMMDD");
}

function ymdToInput(ymd: string): string {
  return ymd.length === 8 ? `${ymd.slice(0, 4)}-${ymd.slice(4, 6)}-${ymd.slice(6)}` : "";
}

function inputToYmd(v: string): string {
  return v.replace(/-/g, "");
}

export type LogScreenCode =
  | "login-history"
  | "screen-usage-statistics"
  | "audit-log";

const SCREEN_TITLE: Record<LogScreenCode, string> = {
  "login-history": "로그인 이력",
  "screen-usage-statistics": "화면 이용 통계",
  "audit-log": "변경 감사 로그",
};

type LogRow = SystemRow & { _key?: string };

type FlatNode = { key: string; label: string };
type HierNode = { key: string; label: string; scrnCd?: string | null; children: HierNode[] };

function buildMenuTree(menus: AdminMenuRow[]): HierNode[] {
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

function collectScrnCds(node: HierNode): string[] {
  const out: string[] = [];
  const walk = (n: HierNode) => {
    if (n.scrnCd) out.push(n.scrnCd);
    n.children.forEach(walk);
  };
  walk(node);
  return out;
}

/** 감사 필터용 — 하위 메뉴코드·화면코드·메뉴명 키 집합 */
function collectAuditKeys(node: HierNode): Set<string> {
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

function findHierNode(nodes: HierNode[], key: string): HierNode | null {
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
 *   1) 로그 3화면 조회 UI를 렌더한다
 *   2) screenRegistry에서 screenCode로 마운트한다
 *   3) 조회 실패 시 업무 토스트
 */
export default function LogManagementPage({
  // 로그 화면코드 — login-history | screen-usage-statistics | audit-log
  screenCode,
}: {
  screenCode: LogScreenCode;
}) {
  const title = SCREEN_TITLE[screenCode];
  const asyncAct = useAsyncAction();
  const loginCodes = useCommonCodes("login-result");
  const auditCodes = useCommonCodes("audit-result");
  // 최신 조회만 반영 — 트리·기간 변경으로 load가 겹칠 때 이전 응답 무시
  const loadSeq = useRef(0);
  const [loading, setLoading] = useState(false);

  const [fromDt, setFromDt] = useState(() => daysAgoYmd(HISTORY_DEFAULT_RANGE_DAYS));
  const [toDt, setToDt] = useState(todayYmd);
  const [rows, setRows] = useState<LogRow[]>([]);
  const [treeSel, setTreeSel] = useState(TREE_ALL);
  const [treeQuery, setTreeQuery] = useState("");
  const [openKeys, setOpenKeys] = useState<Set<string>>(new Set([TREE_ALL]));
  // 로그인 트리 — 사용자
  const [users, setUsers] = useState<FlatNode[]>([]);
  // 감사·통계 트리 — 메뉴
  const [menus, setMenus] = useState<AdminMenuRow[]>([]);

  const isLogin = screenCode === "login-history";
  const isAudit = screenCode === "audit-log";
  const isStats = screenCode === "screen-usage-statistics";
  // 감사·통계 — 메뉴관리와 동일 계층 트리
  const useMenuHier = isAudit || isStats;

  const columns: GridColumn<LogRow>[] = useMemo(() => {
    if (isLogin) {
      return [
        { field: "loginDt", header: "로그인 일시", width: 140 },
        { field: "logoutDt", header: "로그아웃 일시", width: 140 },
        { field: "userId", header: "사용자 ID", width: 110 },
        { field: "userNm", header: "사용자명", width: 110 },
        {
          field: "resultCd",
          header: "결과",
          width: 80,
          type: "code",
          codeMap: loginCodes.codeMap,
          codeOptions: loginCodes.codes.map((c) => ({ value: c.subCd, label: c.codeNm })),
        },
        { field: "ipAddr", header: "접속 IP", width: 130 },
      ];
    }
    if (isAudit) {
      return [
        { field: "insDt", header: "기록 일시", width: 140, required: true },
        { field: "menuNm", header: "대상 메뉴", width: 140 },
        {
          field: "actionCd",
          header: "행위",
          width: 110,
          type: "code",
          codeMap: auditCodes.codeMap,
          codeOptions: auditCodes.codes.map((c) => ({ value: c.subCd, label: c.codeNm })),
        },
        { field: "userId", header: "작업자 ID", width: 110 },
        { field: "userNm", header: "작업자명", width: 110 },
        { field: "ipAddr", header: "접속 IP", width: 130 },
      ];
    }
    return [
      { field: "statDt", header: "집계일", width: 100 },
      { field: "menuCd", header: "메뉴코드", width: 140 },
      { field: "menuNm", header: "메뉴명", width: 160 },
      { field: "pvCnt", header: "페이지뷰(PV)", width: 100, type: "number" },
      { field: "uvCnt", header: "유저뷰(UV)", width: 100, type: "number" },
      { field: "sessCnt", header: "세션수", width: 80, type: "number" },
      { field: "ipCnt", header: "IP 수", width: 80, type: "number" },
    ];
  }, [auditCodes.codeMap, auditCodes.codes, isAudit, isLogin, loginCodes.codeMap, loginCodes.codes]);

  const loadTree = useCallback(async () => {
    try {
      if (isLogin) {
        const list = await listSystemRows("user-management" as SystemScreenCode, {
          keyword: "",
          fromDt: "",
          toDt: "",
        });
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
  }, [isLogin]);

  const load = useCallback(async () => {
    // 겹친 요청 중 마지막만 setRows — useAsyncAction 잠금으로 조회가 스킵되지 않게 함
    const seq = ++loadSeq.current;
    setLoading(true);
    try {
      let keyword = "";
      const hier = useMenuHier ? buildMenuTree(menus) : [];
      const selNode = treeSel !== TREE_ALL && useMenuHier ? findHierNode(hier, treeSel) : null;
      if (treeSel !== TREE_ALL) {
        if (isLogin) keyword = treeSel;
        else if (isStats) {
          // 통계 — 리프(scrnCd)만 SP 필터, 폴더는 FE에서 하위 집계
          keyword = String(selNode?.scrnCd ?? "").trim();
        } else if (isAudit) {
          // 감사 — 리프만 SP keyword, 폴더는 기간 전건 후 FE 하위 필터
          keyword =
            selNode && selNode.children.length === 0
              ? String(selNode.scrnCd ?? selNode.key).trim()
              : "";
        }
      }
      const raw = await listSystemRows(screenCode, {
        keyword,
        fromDt,
        toDt,
      });
      if (seq !== loadSeq.current) return;
      let next: LogRow[] = raw.map((r, i) => ({
        ...r,
        _key: String(r.idx ?? `${screenCode}-${i}`),
      }));
      if (isLogin || isAudit) {
        next = next.map((r) => ({
          ...r,
          loginDt: fmtDateTimeMinute(String(r.loginDt ?? "")) || r.loginDt,
          logoutDt: fmtDateTimeMinute(String(r.logoutDt ?? "")) || r.logoutDt,
          insDt: fmtDateTimeMinute(String(r.insDt ?? "")) || r.insDt,
        }));
      }
      // 감사 — 폴더/전체 하위 메뉴키로 FE 필터 (tbl_nm·menu_nm·scrn)
      if (isAudit && selNode && !keyword) {
        const keys = collectAuditKeys(selNode);
        next = next.filter((r) => {
          const tbl = String(r.tblNm ?? "").trim();
          const menuNm = String(r.menuNm ?? "").trim();
          const scrn = String(r.scrnCd ?? "").trim();
          return keys.has(tbl) || keys.has(menuNm) || (scrn && keys.has(scrn));
        });
      }
      if (isStats) {
        next = next.map((r) => ({
          ...r,
          // 집계일 YYYYMMDD → YYYY-MM-DD 표시
          statDt: (() => {
            const s = String(r.statDt ?? "");
            return s.length === 8 ? `${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6)}` : s;
          })(),
          menuCd: r.menuCd ?? r.scrnCd,
        }));
        // 폴더 선택 시(= 리프 아님·scrnCd 없음) FE에서 하위 화면코드로 추가 필터
        if (selNode && !keyword) {
          const cds = new Set(collectScrnCds(selNode));
          next = next.filter((r) => cds.has(String(r.scrnCd ?? r.menuCd ?? "")));
        }
      }
      setRows(next);
    } catch (e) {
      if (seq !== loadSeq.current) return;
      mesError(e);
    } finally {
      if (seq === loadSeq.current) setLoading(false);
    }
  }, [fromDt, isAudit, isLogin, isStats, menus, screenCode, toDt, treeSel, useMenuHier]);

  useEffect(() => {
    void loadTree();
  }, [loadTree]);

  // 기간·트리 변경 시 즉시 조회 — asyncAct 잠금 없이 호출(겹치면 seq로 무시)
  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    setTreeSel(TREE_ALL);
    setTreeQuery("");
  }, [screenCode]);

  const runSearch = useCallback(() => {
    void asyncAct.run(load, "search");
  }, [asyncAct, load]);

  usePageCommands({ search: runSearch });

  const flatFiltered = useMemo(() => {
    if (!isLogin) return [];
    const q = treeQuery.trim().toLowerCase();
    if (!q) return users;
    return users.filter(
      (u) => u.key.toLowerCase().includes(q) || u.label.toLowerCase().includes(q),
    );
  }, [isLogin, treeQuery, users]);

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
        <div
          className="flex items-center gap-0.5"
          style={{ paddingLeft: depth * 12 }}
        >
          {hasChild ? (
            <button
              type="button"
              className="shrink-0 rounded p-0.5 text-slate-500 hover:bg-slate-100"
              onClick={() =>
                setOpenKeys((prev) => {
                  const next = new Set(prev);
                  if (next.has(node.key)) next.delete(node.key);
                  else next.add(node.key);
                  return next;
                })
              }
            >
              <ChevronRight className={cn("h-3.5 w-3.5 transition", open && "rotate-90")} />
            </button>
          ) : (
            <span className="inline-block w-4" />
          )}
          <button
            type="button"
            className={cn(
              "min-w-0 flex-1 truncate rounded px-1 py-0.5 text-left text-[12px]",
              selected ? treeNodeSelectedClass : treeNodeIdleClass,
            )}
            onClick={() => selectHierNode(node)}
          >
            {node.label}
          </button>
        </div>
        {open && node.children.map((c) => renderHier(c, depth + 1))}
      </div>
    );
  };

  const treeHead = isLogin ? "사용자" : "메뉴 트리";

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
          orientation="horizontal"
          storageKey={`haccp-split-log-${screenCode}`}
          defaultPrimaryPct={20}
          minPct={20}
          maxPct={20}
          panelClassName="rounded-xl border border-slate-200 bg-white shadow-sm p-2"
          primary={
            <>
              <div className={treePanelHeadClass}>
                <b>{treeHead}</b>
              </div>
              <TreePanelSearch
                value={treeQuery}
                onChange={setTreeQuery}
                onSearch={useMenuHier ? runTreeSearch : undefined}
              />
              <div className="min-h-0 flex-1 overflow-y-auto rounded border border-slate-100 bg-white px-2 py-1">
                <div className="py-0.5 text-[12px]">
                  <button
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
                      <button
                        key={n.key}
                        type="button"
                        className={cn(
                          "mt-0.5 w-full truncate rounded px-1 py-0.5 text-left",
                          treeSel === n.key ? treeNodeSelectedClass : treeNodeIdleClass,
                        )}
                        onClick={() => setTreeSel(n.key)}
                      >
                        {n.label}
                      </button>
                    ))}
                </div>
              </div>
            </>
          }
          secondary={
            <>
              <div className={treePanelHeadClass}>
                <b>{title}</b>
              </div>
              <MesDataGrid
                // 로그 그리드 — 열 설정 키 (패널 flex 직계 자식이어야 height 100% 채움)
                persistId={`log-${screenCode}`}
                // pref 저장 — persistId와 함께 필수
                scrnCd={screenCode}
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
                title={title}
              />
            </>
          }
        />
      </PageCard>
    </div>
  );
}
