/**
 * HwpTemplateManagementRule — 사용양식관리 그리드 규칙·컬럼·버튼 판정.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 컬럼·잠금·버튼 활성 판정은 이 파일에 둔다
 *   2) 구분은 표시 전용이라 잠금 대상이 아니고, tmplCd 만 신규행에서 편집한다
 *   3) persistId는 기존 값(hwp-template-management-list)을 승계한다. 불러오기 팝업은 FILE_HIST_PERSIST_ID
 *
 * PIPELINE[HF123] 사용양식관리 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 그리드 잠금 규칙 타입
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 사용양식 목록 행·파일 이력 행
import type { HwpTemplateFile, HwpTemplateRow } from "@/api/docs/hwpTemplateApi";
// 역할 — 편집행 메타
import type { EditableRow } from "@/types/editable";
// 역할 — 사용자추가 판정 — 공통코드 sys-yn
import { isCompanyForm, SYS_YN_BADGE } from "@/hooks/useCommonCodes";

/** 화면코드 — tbl_screen.scrn_cd·권한·pref 키 */
export const SCRN_CD = "hwp-template-management" as const;

/** 그리드 열 설정 저장 키 — 폴더를 옮겨도 값을 바꾸지 않는다 */
export const PERSIST_ID = "hwp-template-management-list" as const;

/** 좌 목록 · 우 미리보기 분할 비율 저장 키 */
export const SPLIT_KEY = "haccp-split-hwp-template" as const;

/** 불러오기 팝업 그리드 열 설정 저장 키 — -3 은 양식구분 열 변경 후 옛 pref 를 버린다 */
export const FILE_HIST_PERSIST_ID = "hwp-template-file-hist-3" as const;

/** 파일 이력 양식구분 공통코드 대분류 — sys 시스템, usr 사용자 */
export const SRC_TY_MAIN_CD = "SRC_TY" as const;

/** 좌측 그리드 행 — 서버 목록 + 신규 draft */
export type TmplListRow = HwpTemplateRow;

/** tmplCd 는 신규도 잠근다 — hwp_usr_NNN 자동 채번 */
export const LIST_GRID_RULES: ScreenGridRules = {};

/** 사용자추가 양식코드 접두 — 시스템제공 hwp_sys_ 와 짝 */
export const USR_TMPL_PREFIX = "hwp_usr_" as const;

/** 사용유무 콤보 옵션 */
export type UseOpt = { value: string; label: string };

/**
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) 좌측 목록 컬럼을 만든다 — 구분은 badge, 양식코드는 자동 채번이라 잠근다
 *   2) Page가 canEdit·useOpts·sys-yn 맵을 넘겨 useMemo로 호출한다
 *   3) 구분 문구는 공통코드 sys-yn 이다. 불러오기 src-ty 와 섞지 않는다
 */
export function buildListColumns(
  // 셀 편집 가능 — 쓰기·수정 권한
  canEdit: boolean,
  // 사용유무 콤보
  useOpts: UseOpt[],
  // sys-yn 공통코드 맵 — 시스템제공/사용자추가
  sysYnMap: Record<string, string>,
): GridColumn<TmplListRow>[] {
  return [
    {
      // 양식코드 — 신규는 hwp_usr_NNN 자동 채번, 사용자가 고치지 않는다
      field: "tmplCd",
      header: "양식코드",
      width: 190,
      required: true,
      editable: false,
    },
    {
      // 양식명 — 시스템제공도 회사 표시명을 바꿀 수 있다
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
      // 훅이 sys-yn 문구 + 레거시 Y/N 별칭을 붙인다. src-ty 와 섞지 않는다
      codeMap: sysYnMap,
      badge: SYS_YN_BADGE,
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

/**
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) 불러오기 팝업 그리드 컬럼을 만든다 — 파일명·등록일·양식구분·현재적용
 *   2) 양식구분은 src-ty 공통코드(시스템/사용자). 현재적용은 SP CASE 문구다
 *   3) 등록일은 yyyy-mm-dd만 — 시각은 숨긴다
 */
export function buildFileHistColumns(
  // src-ty 공통코드 맵 — sys 시스템, usr 사용자
  srcTyMap: Record<string, string>,
): GridColumn<HwpTemplateFile>[] {
  return [
    {
      // 이력 파일명 — 업로드 당시 이름. 현재적용 배지 자리를 위해 줄인다
      field: "fileNm",
      header: "파일명",
      width: 160,
    },
    {
      // 등록일 — yyyy-mm-dd
      field: "insDt",
      header: "등록일",
      width: 110,
      type: "date",
    },
    {
      // 양식구분 — src-ty 공통코드. 목록 구분(sys-yn 시스템제공/사용자추가)과 섞지 않는다
      field: "srcTy",
      header: "양식구분",
      width: 100,
      type: "code",
      codeMap: srcTyMap,
      badge: { sys: "blue", usr: "green" },
    },
    {
      // 지금 적용 중인 버전 — SP CASE 문구(현재적용). 배지가 잘리지 않게 88보다 넓힌다
      field: "currentYn",
      header: "현재적용",
      width: 120,
      type: "code",
      align: "center",
      badge: { 현재적용: "green" },
    },
  ];
}
