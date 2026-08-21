/**
 * UserManagementRule — 사용자 관리 화면의 그리드 규칙·컬럼·초기값.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 컬럼·잠금·검증 규칙은 전부 이 파일에 둔다
 *   2) 권한그룹·부서·서명 셀은 직접 입력이 아니라 전역 모달 버튼으로 고른다
 *   3) persistId는 기존 값(sys-user-management-v2)을 승계한다
 *
 * PIPELINE[HF98] 사용자 관리 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 그리드 잠금 규칙 타입
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 사용여부 기본값·콤보
import { DEFAULT_USE_YN } from "@/lib/yn";
// 역할 — 사용자 행 타입
import type { SysRow } from "@/api/sys/sysTypes";

/** 화면코드 — tbl_screen.scrn_cd·URL 세그먼트와 동일 (권한·pref 키) */
export const SCRN_CD = "user-management" as const;

/** 그리드 열 설정 저장 키 — v2는 코드열 숨김 전환 시 부여한 값이며 그대로 승계 */
export const PERSIST_ID = "sys-user-management-v2" as const;

/** 편집 행 메타·서명 표시열이 붙은 사용자 행 */
export type UserRow = SysRow & {
  idx?: number | null;
  _key?: string;
  _rowState?: string;
  /** 서명 등록 여부 표시열 — SP가 내려준 signYn을 화면에서 옮겨 담는다(저장 대상 아님) */
  _hasSign?: string;
};

/** 사용자 그리드 — 아이디는 신규 행에서만 입력 */
export const USER_RULES: ScreenGridRules = { newOnly: ["userId"] };

/** 저장 payload에서 제외할 항목 — 화면에서 다루지 않는 계정 속성 */
export const NON_EDITABLE_FIELDS = ["userPw", "empCd", "posCd", "lockYn"] as const;

/** 저장 필수 항목 — 순서대로 검사해 첫 미입력 행으로 포커스를 옮긴다 */
export const REQUIRED_FIELDS: Array<{ field: string; label: string }> = [
  { field: "userId", label: "사용자 ID" },
  { field: "userNm", label: "사용자명" },
  { field: "usrgrpCd", label: "권한그룹" },
  { field: "deptCd", label: "부서" },
];

/** 코드 콤보 1건 — 사용여부 등 */
type CodeOpt = { value: string; label: string };

/** 사용자 그리드 컬럼 셀 버튼 핸들러 — Page가 전역 모달을 연다 */
export interface UserColumnHandlers {
  /** 서명 셀 버튼 — 서명 관리 모달 */
  onSign: (row: UserRow) => void;
  /** 권한그룹 셀 버튼 — 코드 룩업 모달 */
  onRoleLookup: (row: UserRow) => void;
  /** 부서 셀 버튼 — 코드 룩업 모달 */
  onDeptLookup: (row: UserRow) => void;
}

/** 사용자 그리드 컬럼 — 코드열은 숨기고 명 표시열에 룩업 버튼을 단다 */
export function buildUserColumns(
  // 등록 또는 수정 권한 — false면 조회 전용이며 룩업 버튼도 감춘다
  editable: boolean,
  // 셀 버튼 클릭 핸들러 묶음
  handlers: UserColumnHandlers,
  // 사용여부 콤보 옵션
  ynOpts: CodeOpt[],
  // 사용여부 코드 → 표시명
  ynLabels: Record<string, string>,
): GridColumn<UserRow>[] {
  return [
    {
      // 사용자 ID — 업무키. 저장 뒤에는 잠긴다(USER_RULES.newOnly)
      field: "userId",
      header: "사용자 ID",
      width: 110,
      required: true,
      editableOnNew: true,
    },
    { field: "userNm", header: "사용자명", width: 110, editable, required: true },
    {
      // 권한그룹코드 — 기본 숨김, 「열」메뉴로 표시·pref 저장
      field: "usrgrpCd",
      header: "권한그룹코드",
      width: 100,
      defaultHidden: true,
      editable: false,
    },
    {
      // 권한그룹명 — 표시 + 룩업 버튼 (필수)
      field: "usrgrpNm",
      header: "권한그룹",
      width: 140,
      editable: false,
      required: true,
      cellButton: editable ? { title: "권한그룹", onClick: handlers.onRoleLookup } : undefined,
    },
    {
      // 부서코드 — 기본 숨김, 「열」메뉴로 표시·pref 저장
      field: "deptCd",
      header: "부서코드",
      width: 100,
      defaultHidden: true,
      editable: false,
    },
    {
      // 부서명 — 표시 + 룩업 버튼 (필수)
      field: "deptNm",
      header: "부서",
      width: 140,
      editable: false,
      required: true,
      cellButton: editable ? { title: "부서", onClick: handlers.onDeptLookup } : undefined,
    },
    { field: "email", header: "이메일", width: 160, editable, inputMode: "email" },
    { field: "mobile", header: "휴대폰", width: 120, editable, inputMode: "tel" },
    {
      // 서명 등록 여부 + 셀 버튼으로 서명 모달
      field: "_hasSign",
      header: "서명",
      width: 90,
      editable: false,
      type: "code",
      codeOptions: [
        { value: "Y", label: "등록" },
        { value: "N", label: "미등록" },
      ],
      codeMap: { Y: "등록", N: "미등록" },
      cellButton: { title: "서명", onClick: handlers.onSign },
    },
    {
      field: "useYn",
      header: "사용여부",
      width: 80,
      type: "code",
      editable,
      codeOptions: ynOpts,
      codeMap: ynLabels,
    },
  ];
}

/** 사용자 신규 행 초기값 — 권한그룹 기본은 일반 사용자(USER) */
export function newUserRow(): UserRow {
  return { userId: "", userNm: "", usrgrpCd: "USER", useYn: DEFAULT_USE_YN, _hasSign: "N" };
}

/** 헤더 FE 필터 — 아이디·성명 부분일치 + 사용여부 정확일치 */
export function matchUser(
  // 검사 대상 사용자 행
  row: UserRow,
  // 사용자 ID 검색어
  userId: string,
  // 사용자명 검색어
  userNm: string,
  // 사용여부 — 빈 문자열이면 전체
  useYn: string,
): boolean {
  const qId = userId.trim().toLowerCase();
  const qNm = userNm.trim().toLowerCase();
  const qUse = useYn.trim().toUpperCase();
  if (qId && !String(row.userId ?? "").toLowerCase().includes(qId)) return false;
  if (qNm && !String(row.userNm ?? "").toLowerCase().includes(qNm)) return false;
  if (qUse && String(row.useYn ?? "").toUpperCase() !== qUse) return false;
  return true;
}
