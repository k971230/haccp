/**
 * DepartmentManagementRule — 부서 관리 화면의 그리드 규칙·컬럼·트리 산출.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 컬럼·잠금·정렬·트리 규칙은 전부 이 파일에 둔다
 *   2) 상위부서는 직접 입력이 아니라 코드 룩업 모달로 고른다 — 컬럼에 cellButton을 단다
 *   3) persistId는 기존 값(dept-mgmt-master-v2)을 승계한다
 *
 * PIPELINE[HF98] 부서 관리 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 그리드 잠금 규칙 타입
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 사용여부 기본값
import { DEFAULT_USE_YN } from "@/lib/yn";
// 역할 — 부서 행 타입
import type { SysRow } from "@/api/sys/sysTypes";

/** 화면코드 — tbl_screen.scrn_cd·URL 세그먼트와 동일 (권한·pref 키) */
export const SCRN_CD = "department-management" as const;

/** 그리드 열 설정 저장 키 — v2는 상위부서 표시열 전환 시 부여한 값이며 그대로 승계 */
export const PERSIST_ID = "dept-mgmt-master-v2" as const;

/** 트리 「전체」 가상 키 — 전건 표시 */
export const TREE_ALL = "__ALL__";

/** 편집 행 메타가 붙은 부서 행 */
export type DeptRow = SysRow & {
  _key?: string;
  deptCd?: string;
  deptNm?: string;
  hDeptCd?: string;
  /** 상위부서명 — SP self JOIN (h_dept_nm) */
  hDeptNm?: string;
  sortNo?: number | null;
  useYn?: string;
  idx?: number | null;
};

/** 좌측 트리 노드 — 부서코드 기준 부모·자식 */
export type DeptTreeNode = {
  deptCd: string;
  name: string;
  children: DeptTreeNode[];
};

/** 부서 그리드 — 부서코드는 신규 행에서만 입력 */
export const DEPT_RULES: ScreenGridRules = { newOnly: ["deptCd"] };

/** 저장 필수 항목 — 비면 토스트 후 해당 행으로 포커스 */
export const REQUIRED_LABEL = "부서코드/부서명";

/** 코드 콤보 1건 — 사용여부 등 */
type CodeOpt = { value: string; label: string };

/** 부서 그리드 컬럼 — 상위부서 셀은 룩업 모달을 여는 버튼을 갖는다 */
export function buildDeptColumns(
  // 등록 또는 수정 권한 — false면 조회 전용이며 룩업 버튼도 감춘다
  editable: boolean,
  // 상위부서 셀 버튼 클릭 — Page가 룩업 모달을 연다
  onHDeptLookup: (row: DeptRow) => void,
  // 사용여부 콤보 옵션
  ynOpts: CodeOpt[],
  // 사용여부 코드 → 표시명
  ynLabels: Record<string, string>,
): GridColumn<DeptRow>[] {
  return [
    {
      // 부서코드 — 업무키. 저장 뒤에는 잠긴다(DEPT_RULES.newOnly)
      field: "deptCd",
      header: "부서코드",
      width: 100, maxLength: 20,
      required: true,
      editableOnNew: true,
    },
    { field: "deptNm", header: "부서명", width: 140, maxLength: 100, editable, required: true },
    {
      // 상위부서코드 — 기본 숨김, 「열」메뉴로 표시·pref 저장 가능
      field: "hDeptCd",
      header: "상위부서코드",
      width: 100,
      defaultHidden: true,
      editable: false,
    },
    {
      // 상위부서명 — self JOIN 표시 + 룩업 버튼
      field: "hDeptNm",
      header: "상위부서",
      width: 140,
      editable: false,
      cellButton: editable ? { title: "상위부서", onClick: onHDeptLookup } : undefined,
    },
    { field: "sortNo", header: "정렬", width: 70, type: "number", editable },
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

/** 부서 신규 행 초기값 — 트리에서 고른 노드를 상위부서로 물려받는다 */
export function newDeptRow(
  // 트리 선택 부서코드 — 「전체」면 빈 문자열
  hDeptCd: string,
): DeptRow {
  return { deptCd: "", deptNm: "", hDeptCd, sortNo: 0, useYn: DEFAULT_USE_YN };
}

/** 헤더 FE 필터 — 코드·명 부분일치 + 사용여부 정확일치 */
export function matchDept(
  // 검사 대상 부서 행
  row: DeptRow,
  // 부서코드 검색어
  deptCd: string,
  // 부서명 검색어
  deptNm: string,
  // 사용여부 — 빈 문자열이면 전체
  useYn: string,
): boolean {
  const qCd = deptCd.trim().toLowerCase();
  const qNm = deptNm.trim().toLowerCase();
  if (qCd && !String(row.deptCd ?? "").toLowerCase().includes(qCd)) return false;
  if (qNm && !String(row.deptNm ?? "").toLowerCase().includes(qNm)) return false;
  if (useYn && String(row.useYn ?? "").toUpperCase() !== useYn.toUpperCase()) return false;
  return true;
}

/** 표시·트리 순서 — 부서코드 */
export function sortByDeptCd(a: DeptRow, b: DeptRow): number {
  return String(a.deptCd ?? "").localeCompare(String(b.deptCd ?? ""), "ko");
}

/** 평면 부서 목록 → 좌측 트리 — 부모가 없으면 루트로 올린다 */
export function buildDeptTree(rows: DeptRow[]): DeptTreeNode[] {
  const ordered = [...rows]
    .filter((r) => String(r.deptCd ?? "").trim())
    .sort(sortByDeptCd);
  const nodes = new Map<string, DeptTreeNode>();
  for (const r of ordered) {
    const cd = String(r.deptCd);
    nodes.set(cd, { deptCd: cd, name: String(r.deptNm ?? cd), children: [] });
  }
  const roots: DeptTreeNode[] = [];
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
