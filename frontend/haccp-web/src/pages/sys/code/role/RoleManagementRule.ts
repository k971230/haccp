/**
 * RoleManagementRule — 권한그룹 관리 화면의 그리드 규칙·컬럼·권한 트리 산출.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 컬럼·잠금·트리 규칙은 전부 이 파일에 둔다
 *   2) 좌측 권한 트리는 use_yn=Y 메뉴만 쓰며 리프(scrnCd)에만 체크가 붙는다
 *   3) persistId는 기존 값(role-mgmt-master)을 승계한다
 *
 * PIPELINE[HF98] 권한그룹 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 그리드 잠금 규칙 타입
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 사용여부 기본값
import { DEFAULT_USE_YN } from "@/lib/yn";
// 역할 — 권한그룹 행·메뉴 행 타입
import type { AdminMenuRow, SysRow } from "@/api/sys/sysTypes";

/** 화면코드 — tbl_screen.scrn_cd·URL 세그먼트와 동일 (권한·pref 키) */
export const SCRN_CD = "role-management" as const;

/** 그리드 열 설정 저장 키 — 기존 값 승계 */
export const PERSIST_ID = "role-mgmt-master" as const;

/** 편집 행 메타가 붙은 권한그룹 행 */
export type RoleRow = SysRow & {
  _key?: string;
  usrgrpCd?: string;
  usrgrpNm?: string;
  descRmk?: string;
  useYn?: string;
  idx?: number | null;
};

/** 좌측 권한 트리 노드 — scrnCd가 있으면 리프(체크 대상) */
export type RoleTreeNode = {
  menuCd: string;
  name: string;
  scrnCd?: string | null;
  children: RoleTreeNode[];
};

/** 권한그룹 그리드 — 그룹코드는 신규 행에서만 입력 */
export const ROLE_RULES: ScreenGridRules = { newOnly: ["usrgrpCd"] };

/** 저장 필수 항목 — 비면 토스트 후 해당 행으로 포커스 */
export const REQUIRED_LABEL = "그룹코드/그룹명";

/** 코드 콤보 1건 — 사용여부 등 */
type CodeOpt = { value: string; label: string };

/** 권한그룹 그리드 컬럼 — 등록·수정 권한이 있을 때만 편집 가능 */
export function buildRoleColumns(
  // 등록 또는 수정 권한 — false면 조회 전용
  editable: boolean,
  // 사용여부 콤보 옵션
  ynOpts: CodeOpt[],
  // 사용여부 코드 → 표시명
  ynLabels: Record<string, string>,
): GridColumn<RoleRow>[] {
  return [
    {
      // 그룹코드 — 업무키. 저장 뒤에는 잠긴다(ROLE_RULES.newOnly)
      field: "usrgrpCd",
      header: "그룹코드",
      width: 110,
      required: true,
      editableOnNew: true,
    },
    { field: "usrgrpNm", header: "그룹명", width: 140, editable, required: true },
    { field: "descRmk", header: "설명", width: 180, editable },
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

/** 권한그룹 신규 행 초기값 — 코드·명은 사용자가 채운다 */
export function newRoleRow(): RoleRow {
  return { usrgrpCd: "", usrgrpNm: "", useYn: DEFAULT_USE_YN };
}

/** 헤더 FE 필터 — 코드·명 부분일치 + 사용여부 정확일치 */
export function matchRole(
  // 검사 대상 권한그룹 행
  row: RoleRow,
  // 그룹코드 검색어
  grpCd: string,
  // 그룹명 검색어
  grpNm: string,
  // 사용여부 — 빈 문자열이면 전체
  useYn: string,
): boolean {
  const qCd = grpCd.trim().toLowerCase();
  const qNm = grpNm.trim().toLowerCase();
  if (qCd && !String(row.usrgrpCd ?? "").toLowerCase().includes(qCd)) return false;
  if (qNm && !String(row.usrgrpNm ?? "").toLowerCase().includes(qNm)) return false;
  if (useYn && String(row.useYn ?? "").toUpperCase() !== useYn.toUpperCase()) return false;
  return true;
}

/** 관리용 메뉴 목록 → 권한 트리 — 사용중지 메뉴는 권한 대상이 아니라 제외한다 */
export function buildRoleTree(menus: AdminMenuRow[]): RoleTreeNode[] {
  const ordered = [...menus]
    .filter((m) => String(m.useYn ?? "").toUpperCase() === "Y")
    .sort((a, b) => Number(a.sortNo ?? 0) - Number(b.sortNo ?? 0));
  const byCd = new Map(ordered.map((m) => [m.menuCd, m]));
  const nodes = new Map<string, RoleTreeNode>();
  for (const m of ordered) {
    nodes.set(m.menuCd, { menuCd: m.menuCd, name: m.menuNm, scrnCd: m.scrnCd, children: [] });
  }
  const roots: RoleTreeNode[] = [];
  for (const m of ordered) {
    const node = nodes.get(m.menuCd)!;
    const parent = m.hMenuCd ? nodes.get(m.hMenuCd) : undefined;
    if (parent) parent.children.push(node);
    // 상위가 사용중지라 트리에 없을 때(= 고아 노드) 루트로 올려 숨지 않게 한다
    else if (!m.hMenuCd || !byCd.has(m.hMenuCd)) roots.push(node);
  }
  return roots;
}

/** 노드 하위의 화면코드 전부 — 폴더 체크 시 일괄 적용 대상 */
export function collectLeafScrn(node: RoleTreeNode): string[] {
  if (node.scrnCd) return [node.scrnCd];
  return node.children.flatMap(collectLeafScrn);
}
