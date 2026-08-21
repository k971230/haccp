/**
 * ApprovalLineManagementRule — 결재선 좌 헤더·우 단계 규칙.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 컬럼·초기 3단계·필터는 이 파일이 갖는다
 *   2) 결재자는 셀 버튼 룩업이다. 직위코드 컬럼은 없다
 *   3) 헤더 persistId는 승계하고, 단계·분할 키만 열 순서·좌측 축소에 맞춰 v2다
 *
 * PIPELINE[HF87] 결재선 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 그리드 잠금 규칙
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 사용여부 기본값
import { DEFAULT_USE_YN } from "@/lib/yn";
// 역할 — 결재선 API 타입
import type { ApprovalLine, ApprovalStep } from "@/api/sys/approvalLineApi";

/** 화면코드 — URL·권한·pref. 폴더를 옮겨도 바꾸지 않는다 */
export const SCRN_CD = "approval-line-management" as const;

/** 좌측 헤더 열 설정 키 */
export const HEADER_PERSIST_ID = "bas-approval-line-header" as const;

/** 우측 단계 열 설정 키 — 순서·역할·부서·결재자·사용 */
export const STEP_PERSIST_ID = "bas-approval-line-steps-v2" as const;

/** 회사 온보딩 기본 결재선 — 삭제 금지 */
export const DEFAULT_APPR_LINE_CD = "DEFAULT" as const;

/** 좌우 분할 비율 키 — 좌측 32% 기본 */
export const SPLIT_KEY = "haccp-split-approval-line-v2" as const;

/** 고정 역할 — 1작성 2검토 3승인 */
export const ROLES: ApprovalStep["roleCd"][] = ["WRITE", "REVIEW", "APPROVE"];

/** 역할 표시명 */
export const ROLE_LABEL: Record<ApprovalStep["roleCd"], string> = {
  WRITE: "작성",
  REVIEW: "검토",
  APPROVE: "승인",
};

export type HeaderRow = ApprovalLine & { _key?: string };
export type StepRow = ApprovalStep & { _key?: string; roleNm?: string };

/** 헤더 — 결재선코드는 신규만 */
export const HEADER_RULES: ScreenGridRules = {
  newOnly: ["apprLineCd"],
};

/** 단계 — 순서·역할·부서는 직접 고치지 않는다. 결재자는 팝업 */
export const STEP_RULES: ScreenGridRules = {
  alwaysReadonly: ["stepNo", "roleCd", "roleNm", "deptCd", "deptNm", "approverId"],
  popupFields: ["approverNm"],
};

/** 코드 콤보 1건 */
type CodeOpt = { value: string; label: string };

/** 단계 셀 버튼 — Page가 전역 모달을 연다 */
export interface StepColumnHandlers {
  onApproverLookup: (row: StepRow) => void;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 저장 직전 항상 작성·검토·승인 3행으로 맞춘다
 *   2) 행추가·조회 직후 우측 그리드가 호출한다
 *   3) 검토 useYn 기본은 N, 작성과 승인은 Y
 */
export function emptySteps(): ApprovalStep[] {
  return ROLES.map((roleCd, index) => ({
    stepNo: index + 1,
    roleCd,
    approverId: null,
    approverNm: "",
    deptCd: null,
    deptNm: "",
    useYn: roleCd === "REVIEW" ? "N" : "Y",
  }));
}

/** 신규 결재선 — 단계는 바로 3행 */
export function emptyLine(): ApprovalLine {
  return { apprLineCd: "", apprLineNm: "", useYn: DEFAULT_USE_YN, steps: emptySteps() };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 서버 단계를 고정 3역할에 맞춰 빈 칸을 채운다
 *   2) 행 선택·조회 성공 뒤에 호출한다
 *   3) 검토가 없으면 사용안함으로 넣는다
 */
export function normalizeSteps(steps: ApprovalStep[] | undefined): ApprovalStep[] {
  return ROLES.map((roleCd, index) => {
    const found = steps?.find((step) => step.roleCd === roleCd);
    const useYn = roleCd === "REVIEW"
      ? (String(found?.useYn ?? "N").toUpperCase() === "Y" ? "Y" : "N")
      : "Y";
    return {
      stepNo: index + 1,
      roleCd,
      approverId: found?.approverId ?? null,
      approverNm: found?.approverNm ?? "",
      deptCd: found?.deptCd ?? null,
      deptNm: found?.deptNm ?? "",
      useYn,
    };
  });
}

/** 저장 payload 단계 — 표시열은 빼고 코드만 */
export function stepsToPayload(rows: StepRow[]): ApprovalStep[] {
  return normalizeSteps(rows).map((step) => ({
    stepNo: step.stepNo,
    roleCd: step.roleCd,
    approverId: step.approverId || null,
    deptCd: step.deptCd || null,
    useYn: step.roleCd === "REVIEW" && String(step.useYn).toUpperCase() === "N" ? "N" : "Y",
  }));
}

export function buildHeaderColumns(
  // 등록 또는 수정 권한
  editable: boolean,
  ynOpts: CodeOpt[],
  ynLabels: Record<string, string>,
): GridColumn<HeaderRow>[] {
  return [
    {
      // 결재선 업무키 — 신규 행에서만 입력
      field: "apprLineCd",
      header: "결재선코드",
      width: 120,
      required: true,
      editableOnNew: true,
    },
    {
      // 결재선 표시명
      field: "apprLineNm",
      header: "결재선명",
      width: 160,
      required: true,
      editable,
    },
    {
      // 결재선 사용여부
      field: "useYn",
      header: "사용",
      width: 80,
      type: "code",
      editable,
      codeOptions: ynOpts,
      codeMap: ynLabels,
    },
  ];
}

export function buildStepColumns(
  // 헤더가 선택되고 권한이 있을 때만 편집
  editable: boolean,
  handlers: StepColumnHandlers,
  ynOpts: CodeOpt[],
  ynLabels: Record<string, string>,
): GridColumn<StepRow>[] {
  return [
    {
      // 고정 순번 1~3
      field: "stepNo",
      header: "순서",
      width: 60,
      type: "number",
      editable: false,
    },
    {
      field: "roleNm",
      header: "역할",
      width: 80,
      editable: false,
    },
    {
      // 결재자 소속 부서 — 직접 고르지 않는다
      field: "deptNm",
      header: "부서",
      width: 140,
      editable: false,
    },
    {
      // 결재자명 + 셀 버튼. 고르면 부서까지 채운다
      field: "approverNm",
      header: "결재자",
      width: 140,
      editable: false,
      cellButton: editable ? { title: "결재자", onClick: handlers.onApproverLookup } : undefined,
    },
    {
      // 검토만 사용안함이 의미 있다. 저장 시 작성·승인은 Y로 고정한다
      field: "useYn",
      header: "사용",
      width: 80,
      type: "code",
      editable,
      codeOptions: ynOpts,
      codeMap: ynLabels,
    },
    {
      field: "roleCd",
      header: "역할코드",
      width: 90,
      editable: false,
      defaultHidden: true,
    },
    {
      field: "approverId",
      header: "결재자ID",
      width: 100,
      editable: false,
      defaultHidden: true,
    },
    {
      field: "deptCd",
      header: "부서코드",
      width: 100,
      editable: false,
      defaultHidden: true,
    },
  ];
}

/** 헤더 FE 필터 — 코드·명칭 부분일치 + 사용여부 정확일치 */
export function matchLine(
  row: HeaderRow,
  apprLineCd: string,
  apprLineNm: string,
  useYn: string,
): boolean {
  const qCd = apprLineCd.trim().toLowerCase();
  const qNm = apprLineNm.trim().toLowerCase();
  const qUse = useYn.trim().toUpperCase();
  if (qCd && !String(row.apprLineCd ?? "").toLowerCase().includes(qCd)) return false;
  if (qNm && !String(row.apprLineNm ?? "").toLowerCase().includes(qNm)) return false;
  if (qUse && String(row.useYn ?? "").toUpperCase() !== qUse) return false;
  return true;
}
