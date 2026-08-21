/**
 * CommonCodeRule — 공통코드 관리 화면의 그리드 규칙·컬럼·초기값.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 컬럼·잠금·검증 규칙은 전부 이 파일에 둔다
 *   2) persistId는 기존 값을 그대로 승계한다 — 바꾸면 사용자가 저장한 열 너비·숨김이 초기화된다
 *   3) 대분류·시스템 그리드는 조회 전용이고 사용자 그리드만 CRUD 대상이다
 *
 * PIPELINE[HF98] 공통코드 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 그리드 잠금 규칙 타입
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 사용여부 기본값
import { DEFAULT_USE_YN } from "@/lib/yn";
// 역할 — 공통코드 행 타입
import type { CodeManageRow } from "@/api/sys/sysTypes";

/** 화면코드 — tbl_screen.scrn_cd·URL 세그먼트와 동일 (권한·pref 키) */
export const SCRN_CD = "common-code-management" as const;

/** 그리드 열 설정 저장 키 — 3그리드가 각각 다른 키를 갖는다 */
export const PERSIST_ID = {
  /** 좌 대분류 그리드 */
  group: "code-mgmt-group",
  /** 우상 시스템 세부 그리드 */
  sys: "code-mgmt-sys",
  /** 우하 사용자 세부 그리드 */
  usr: "code-mgmt-usr",
} as const;

/** 편집 행 메타가 붙은 공통코드 행 */
export type CodeRow = CodeManageRow & {
  _key?: string;
  _rowState?: string;
  _original?: unknown;
  idx?: number | null;
};

/** 대분류 그리드 — 선택만 하므로 전 컬럼 잠금 */
export const GROUP_RULES: ScreenGridRules = {
  alwaysReadonly: ["mainCd", "subCd", "codeNm", "sortNo", "ref1", "ref2", "sysYn", "useYn"],
};

/** 시스템 세부 그리드 — 플랫폼 표준 코드라 수정 불가 */
export const SYS_RULES: ScreenGridRules = {
  alwaysReadonly: ["mainCd", "subCd", "codeNm", "sortNo", "ref1", "ref2", "sysYn", "useYn"],
};

/** 사용자 세부 그리드 — 업무키는 신규 행에서만 입력 */
export const USR_RULES: ScreenGridRules = { newOnly: ["mainCd", "subCd"] };

/** 코드 콤보 1건 — 사용여부 등 */
type CodeOpt = { value: string; label: string };

/** 대분류 그리드 컬럼 — 코드·명·사용여부만 본다 */
export function buildGroupColumns(
  // 사용여부 콤보 옵션
  ynOpts: CodeOpt[],
  // 사용여부 코드 → 표시명
  ynLabels: Record<string, string>,
): GridColumn<CodeRow>[] {
  return [
    { field: "mainCd", header: "대분류코드", width: 110 },
    { field: "codeNm", header: "대분류명", width: 160 },
    {
      field: "useYn",
      header: "사용여부",
      width: 80,
      type: "code",
      codeOptions: ynOpts,
      codeMap: ynLabels,
    },
  ];
}

/** 시스템 세부 그리드 컬럼 — 사용자 그리드와 같은 열이지만 편집 불가 */
export function buildSysColumns(
  // 사용여부 콤보 옵션
  ynOpts: CodeOpt[],
  // 사용여부 코드 → 표시명
  ynLabels: Record<string, string>,
): GridColumn<CodeRow>[] {
  return [
    { field: "subCd", header: "세부코드", width: 100 },
    { field: "codeNm", header: "세부코드명", width: 160 },
    { field: "sortNo", header: "정렬", width: 70, type: "number" },
    { field: "ref1", header: "참조1", width: 100 },
    { field: "ref2", header: "참조2", width: 100 },
    {
      field: "useYn",
      header: "사용여부",
      width: 80,
      type: "code",
      codeOptions: ynOpts,
      codeMap: ynLabels,
    },
  ];
}

/** 사용자 세부 그리드 컬럼 — 등록·수정 권한이 있을 때만 편집 가능 */
export function buildUsrColumns(
  // 등록 또는 수정 권한 — false면 조회 전용
  editable: boolean,
  // 사용여부 콤보 옵션
  ynOpts: CodeOpt[],
  // 사용여부 코드 → 표시명
  ynLabels: Record<string, string>,
): GridColumn<CodeRow>[] {
  return [
    {
      // 세부코드 — 업무키. 저장 뒤에는 잠긴다(USR_RULES.newOnly)
      field: "subCd",
      header: "세부코드",
      width: 100,
      required: true,
      editableOnNew: true,
    },
    { field: "codeNm", header: "코드명", width: 160, editable, required: true },
    { field: "sortNo", header: "정렬", width: 70, type: "number", editable },
    { field: "ref1", header: "참조1", width: 100, editable },
    { field: "ref2", header: "참조2", width: 100, editable },
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

/** 사용자 세부코드 신규 행 초기값 — 선택된 대분류를 물려받는다 */
export function newUsrRow(
  // 좌측에서 고른 대분류코드
  mainCd: string,
): CodeRow {
  return { mainCd, subCd: "", codeNm: "", sortNo: 0, useYn: DEFAULT_USE_YN, sysYn: "N" };
}

/** 저장 필수 항목 — 비면 토스트 후 해당 행으로 포커스 */
export const USR_REQUIRED_LABEL = "세부코드/코드명";

/** 대분류 FE 필터 — 코드·명 부분일치 + 사용여부 정확일치 */
export function matchGroup(
  // 검사 대상 대분류 행
  row: CodeManageRow,
  // 대분류코드 검색어
  mainCd: string,
  // 대분류명 검색어
  codeNm: string,
  // 사용여부 — 빈 문자열이면 전체
  useYn: string,
): boolean {
  const qMain = mainCd.trim().toLowerCase();
  const qNm = codeNm.trim().toLowerCase();
  if (qMain && !String(row.mainCd ?? "").toLowerCase().includes(qMain)) return false;
  if (qNm && !String(row.codeNm ?? "").toLowerCase().includes(qNm)) return false;
  if (useYn && String(row.useYn ?? "").toUpperCase() !== useYn.toUpperCase()) return false;
  return true;
}
