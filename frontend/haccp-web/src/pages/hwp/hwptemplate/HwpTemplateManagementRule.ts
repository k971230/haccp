/**
 * HwpTemplateManagementRule — 사용양식관리 그리드 규칙·컬럼·버튼 판정.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 컬럼·잠금·버튼 활성 판정은 이 파일에 둔다
 *   2) 구분은 표시 전용이라 잠금 대상이 아니고, tmplCd 만 신규행에서 편집한다
 *   3) persistId는 기존 값(hwp-template-management-list)을 승계한다
 *
 * PIPELINE[HF123] 사용양식관리 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 그리드 잠금 규칙 타입
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 사용양식 목록 행
import type { HwpTemplateRow } from "@/api/hwp/hwpTemplateApi";
// 역할 — 편집행 메타
import type { EditableRow } from "@/types/editable";
// 역할 — 구분 라벨·자사양식 판정
import { FORM_TYPE_LABEL, isCompanyForm } from "../formType";

/** 화면코드 — tbl_screen.scrn_cd·권한·pref 키 */
export const SCRN_CD = "hwp-template-management" as const;

/** 그리드 열 설정 저장 키 — 폴더를 옮겨도 값을 바꾸지 않는다 */
export const PERSIST_ID = "hwp-template-management-list" as const;

/** 좌 목록 · 우 미리보기 분할 비율 저장 키 */
export const SPLIT_KEY = "haccp-split-hwp-template" as const;

/** 좌측 그리드 행 — 서버 목록 + 신규 draft */
export type TmplListRow = HwpTemplateRow;

/** tmplCd 는 신규(C) 행만 편집 */
export const LIST_GRID_RULES: ScreenGridRules = { newOnly: ["tmplCd"] };

/** 사용유무 콤보 옵션 */
export type UseOpt = { value: string; label: string };

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 좌측 목록 컬럼을 만든다 — 구분은 badge, 코드는 신규만
 *   2) Page가 canEdit·useOpts 를 넘겨 useMemo로 호출한다
 *   3) 구분 코드맵은 formType 정본을 쓴다
 */
export function buildListColumns(
  // 셀 편집 가능 — 쓰기·수정 권한
  canEdit: boolean,
  // 사용유무 콤보
  useOpts: UseOpt[],
): GridColumn<TmplListRow>[] {
  return [
    {
      // 양식코드 — 신규행에서 직접 입력하고 저장 후 잠긴다
      field: "tmplCd",
      header: "양식코드",
      width: 190,
      required: true,
      editableOnNew: true,
    },
    {
      // 양식명 — 시스템양식도 회사 표시명을 바꿀 수 있다
      field: "tmplNm",
      header: "양식명",
      width: 200,
      required: true,
      editable: canEdit,
    },
    {
      // 구분 — 서버 sysYn 표시 전용. 사용자가 고르는 값이 아니다
      field: "sysYn",
      header: "구분",
      width: 96,
      type: "code",
      editable: false,
      codeMap: FORM_TYPE_LABEL,
      badge: { sys: "blue", usr: "green" },
    },
    {
      // 양식파일 — 현재 적용 파일명. 없으면 업로드 전이다
      field: "formFileNm",
      header: "양식파일",
      width: 220,
      editable: false,
    },
    {
      // 사용유무 — 미사용 양식은 문서작성·문서주기 대상에서 빠진다
      field: "useYn",
      header: "사용유무",
      width: 96,
      type: "code",
      editable: canEdit,
      codeOptions: useOpts,
      codeMap: Object.fromEntries(useOpts.map((opt) => [opt.value, opt.label])),
    },
  ];
}

/** 툴바 버튼 활성 판정 — 구분은 삭제에만 관여하고 파일 기능은 양쪽 모두 허용 */
export type HwpButtonState = {
  canSaveRow: boolean;
  canDeleteRow: boolean;
  canUpload: boolean;
  canExport: boolean;
  canImport: boolean;
  canReset: boolean;
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 선택행·권한으로 툴바 버튼 활성을 한 곳에서 계산한다
 *   2) Page useMemo가 호출한다
 *   3) 시스템양식도 업로드·내보내기·불러오기·초기화는 켠다
 */
export function buildButtonState(
  // 현재 선택행 — 없으면 파일 기능 전부 잠금
  row: EditableRow<TmplListRow> | null,
  canEdit: boolean,
  canDeleteAuth: boolean,
): HwpButtonState {
  const persisted = !!row && row._rowState !== "C";
  return {
    canSaveRow: canEdit,
    canDeleteRow: canDeleteAuth && !!row && (row._rowState === "C" || isCompanyForm(row.sysYn)),
    canUpload: canEdit && persisted,
    canExport: persisted && !!row?.formFileNm,
    canImport: canEdit && persisted && Number(row?.fileHistCnt ?? 0) > 0,
    canReset: canEdit && persisted && !!row?.defaultFileIdx,
  };
}
