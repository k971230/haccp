/**
 * MenuManagementRule — 메뉴 관리 화면의 그리드 규칙·컬럼·트리 산출.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 컬럼·잠금·정렬·트리 규칙은 전부 이 파일에 둔다
 *   2) 메뉴는 행추가 불가다 — 코드·상위·화면·정렬은 시드·migrate로만 만든다
 *   3) persistId는 기존 값(menu-mgmt-master)을 승계한다
 *
 * PIPELINE[HF98] 메뉴 관리 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 그리드 잠금 규칙 타입
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 메뉴 행 타입
import type { SysRow } from "@/api/sys/sysTypes";

/** 화면코드 — tbl_screen.scrn_cd·URL 세그먼트와 동일 (권한·pref 키) */
export const SCRN_CD = "menu-management" as const;

/** 그리드 열 설정 저장 키 — 기존 값 승계 */
export const PERSIST_ID = "menu-mgmt-master" as const;

/** 트리 「전체」 가상 키 — 전건 표시 */
export const TREE_ALL = "__ALL__";

/** 편집 행 메타가 붙은 메뉴 행 */
export type MenuRow = SysRow & {
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

/** 좌측 트리 노드 — 메뉴코드 기준 부모·자식 */
export type MenuTreeNode = {
  menuCd: string;
  name: string;
  children: MenuTreeNode[];
};

/** 메뉴 그리드 — 메뉴명·사용여부만 수정 가능 (그 외 전부 잠금) */
export const MENU_RULES: ScreenGridRules = {
  alwaysReadonly: ["grpANm", "grpBNm", "grpCNm", "menuCd", "hMenuCd", "scrnCd", "sortNo"],
};

/** 저장 필수 항목 — 비면 토스트 후 해당 행으로 포커스 */
export const REQUIRED_LABEL = "메뉴코드/메뉴명";

/** 저장 payload에서 제외할 표시 전용 열 — 트리에서 산출한 대·중·소 */
export const DISPLAY_ONLY_FIELDS = ["grpANm", "grpBNm", "grpCNm"] as const;

/** 코드 콤보 1건 — 사용여부 등 */
type CodeOpt = { value: string; label: string };

/** 메뉴 그리드 컬럼 — 대·중·소는 트리 산출 표시열이라 항상 잠긴다 */
export function buildMenuColumns(
  // 등록 또는 수정 권한 — 메뉴명·사용여부 편집 가능 여부
  editable: boolean,
  // 사용여부 콤보 옵션
  ynOpts: CodeOpt[],
  // 사용여부 코드 → 표시명
  ynLabels: Record<string, string>,
): GridColumn<MenuRow>[] {
  return [
    { field: "grpANm", header: "대분류", width: 120, editable: false, required: true },
    { field: "grpBNm", header: "중분류", width: 120, editable: false },
    { field: "grpCNm", header: "소분류", width: 140, editable: false },
    { field: "menuCd", header: "메뉴코드", width: 140, editable: false, required: true },
    { field: "menuNm", header: "메뉴명", width: 160, editable, required: true },
    { field: "hMenuCd", header: "상위메뉴", width: 120, editable: false },
    { field: "scrnCd", header: "화면코드", width: 160, editable: false },
    { field: "sortNo", header: "정렬코드", width: 80, type: "number", editable: false },
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
  ];
}

/** 헤더 FE 필터 — 코드·명 부분일치 + 사용여부 정확일치 */
export function matchMenu(
  // 검사 대상 메뉴 행
  row: MenuRow,
  // 메뉴코드 검색어
  menuCd: string,
  // 메뉴명 검색어
  menuNm: string,
  // 사용여부 — 빈 문자열이면 전체
  useYn: string,
): boolean {
  const qCd = menuCd.trim().toLowerCase();
  const qNm = menuNm.trim().toLowerCase();
  if (qCd && !String(row.menuCd ?? "").toLowerCase().includes(qCd)) return false;
  if (qNm && !String(row.menuNm ?? "").toLowerCase().includes(qNm)) return false;
  if (useYn && String(row.useYn ?? "").toUpperCase() !== useYn.toUpperCase()) return false;
  return true;
}

/** 표시 순서 — sort_no(대중소 인코딩) 우선, 같으면 메뉴코드 */
export function sortByMenuOrder(a: MenuRow, b: MenuRow): number {
  const sa = Number(a.sortNo ?? 0);
  const sb = Number(b.sortNo ?? 0);
  if (sa !== sb) return sa - sb;
  return String(a.menuCd ?? "").localeCompare(String(b.menuCd ?? ""));
}

/**
 * 메뉴 트리에서 대·중·소 표시명을 채운다.
 * depth0=대, depth1=중, depth2+=소.
 */
export function enrichMenuLevels(rows: MenuRow[]): MenuRow[] {
  const byCd = new Map<string, MenuRow>();
  for (const row of rows) {
    const cd = String(row.menuCd ?? "").trim();
    if (cd) byCd.set(cd, row);
  }
  const pathOf = (row: MenuRow): MenuRow[] => {
    const chain: MenuRow[] = [];
    let cur: MenuRow | undefined = row;
    // 순환 참조 방어 — 같은 코드를 두 번 만나면 중단
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

/** 평면 메뉴 목록 → 좌측 트리 — 부모가 없으면 루트로 올린다 */
export function buildMenuTree(rows: MenuRow[]): MenuTreeNode[] {
  const ordered = [...rows]
    .filter((r) => String(r.menuCd ?? "").trim())
    .sort(sortByMenuOrder);
  const nodes = new Map<string, MenuTreeNode>();
  for (const r of ordered) {
    const cd = String(r.menuCd);
    nodes.set(cd, { menuCd: cd, name: String(r.menuNm ?? cd), children: [] });
  }
  const roots: MenuTreeNode[] = [];
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
