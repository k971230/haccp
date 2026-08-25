/**
 * CorrectiveActionManagementRule — 이탈·개선조치 그리드 규칙·컬럼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 컬럼·상태옵션은 이 파일이 갖는다
 *   2) 그리드 하나로 끝나는 화면이라 우측 폼 라벨(FIELD_LABELS)은 더 쓰지 않는다
 *   3) persistId 는 기존 값(doc-corrective-actions)을 승계한다 — 값 변경 금지
 *
 * 문서 정보(양식·문서번호·기준일·작성자)는 읽기 전용이다. 사용자가 채우는 칸은
 * 조치내용·조치자·조치일·기한·상태뿐이라 그 칸만 editable 로 연다.
 *
 * PIPELINE[HF89] 개선조치 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 개선조치 목록 행
import type { WorkflowRow } from "@/api/taskWorkflowApi";

/** 화면코드 — URL·권한·pref. 폴더를 옮겨도 바꾸지 않는다 */
export const SCRN_CD = "corrective-action-management" as const;

/** 목록 열 설정 키 — 값 변경 금지 */
export const PERSIST_ID = "doc-corrective-actions" as const;

/** 목록 행 — 이탈 1건 + 원문서 정보 */
export type Row = WorkflowRow & {
  _key?: string;
  caNo?: string;
  occurDt?: string;
  occurPlace?: string;
  deviationDesc?: string;
  actionDesc?: string;
  actionUserNm?: string;
  actionDt?: string;
  dueDt?: string;
  srcDocNo?: string;
  srcTmplCd?: string;
  tmplNm?: string;
  baseDt?: string;
  writerNm?: string;
};

/** 상태 콤보 — 진행·완료·취소 */
export const STATUS_OPTIONS = [
  { value: "OPEN", label: "진행" },
  { value: "DONE", label: "완료" },
  { value: "CANCEL", label: "취소" },
] as const;

/** 상태 배지 — 진행 노랑·완료 초록·취소 회색 */
export const STATUS_BADGE = { OPEN: "amber", DONE: "green", CANCEL: "gray" } as const;

/** 상태 코드 → 라벨 */
export const STATUS_NM: Record<string, string> =
  Object.fromEntries(STATUS_OPTIONS.map((opt) => [opt.value, opt.label]));

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 그리드 하나에 원문서 정보와 조치 입력 칸을 함께 둔다
 *   2) Page 가 useMemo 로 호출한다
 *   3) 문서에서 온 칸은 잠그고 조치 칸만 연다 — 원문서를 여기서 고치지 않는다
 */
export function buildColumns(): GridColumn<Row>[] {
  return [
    { field: "baseDt", header: "일자", width: 100, type: "date", editable: false },
    { field: "tmplNm", header: "양식", width: 200, editable: false },
    { field: "srcDocNo", header: "문서번호", width: 150, editable: false },
    { field: "writerNm", header: "작성자", width: 90, editable: false },
    { field: "caNo", header: "이탈번호", width: 130, editable: false },
    { field: "deviationDesc", header: "이탈내용", width: 220, editable: true },
    { field: "occurPlace", header: "발생장소", width: 120, editable: true },
    { field: "actionDesc", header: "조치내용", width: 240, editable: true },
    { field: "actionUserNm", header: "조치자", width: 90, editable: true },
    { field: "actionDt", header: "조치일", width: 110, type: "date", editable: true },
    { field: "dueDt", header: "기한", width: 110, type: "date", editable: true },
    {
      field: "status",
      header: "상태",
      width: 90,
      type: "code",
      editable: true,
      codeOptions: [...STATUS_OPTIONS],
      codeMap: STATUS_NM,
      badge: STATUS_BADGE,
    },
  ];
}
