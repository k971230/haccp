/**
 * CorrectiveActionManagementRule — 개선조치 그리드 규칙·컬럼·폼 필드.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 컬럼·상태옵션·폼 라벨은 이 파일이 갖는다
 *   2) persistId는 기존 값(doc-corrective-actions)을 승계한다
 *   3) 날짜 변환은 공용 docDateTime을 쓴다
 *
 * PIPELINE[HF89] 개선조치 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 개선조치 목록 행
import type { WorkflowRow } from "@/api/taskWorkflowApi";

/** 화면코드 — URL·권한·pref. 폴더를 옮겨도 바꾸지 않는다 */
export const SCRN_CD = "corrective-action-management" as const;

/** 목록 열 설정 키 */
export const PERSIST_ID = "doc-corrective-actions" as const;

/** 목록 행 — 원문서번호·발생일 표시 필드 */
export type Row = WorkflowRow & {
  _key?: string;
  srcDocNo?: string;
  caNo?: string;
  occurDt?: string;
  deviationDesc?: string;
};

/** 우측 폼 필드 — 날짜는 YYYYMMDD 저장 */
export const FIELD_LABELS: { key: string; label: string; type?: "text" | "date" }[] = [
  { key: "occurDt", label: "발생일", type: "date" },
  { key: "occurPlace", label: "발생장소" },
  { key: "deviationDesc", label: "이탈내용" },
  { key: "actionDesc", label: "조치내용" },
  { key: "actionUserId", label: "조치자 ID" },
  { key: "actionDt", label: "조치일", type: "date" },
  { key: "dueDt", label: "기한", type: "date" },
];

/** 상태 콤보 — 진행·완료·취소 */
export const STATUS_OPTIONS = [
  { value: "OPEN", label: "진행" },
  { value: "DONE", label: "완료" },
  { value: "CANCEL", label: "취소" },
] as const;

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 목록은 선택용이라 편집 컬럼이 없다
 *   2) Page가 useMemo로 호출한다
 *   3) 상태 라벨은 STATUS_OPTIONS 정본
 */
export function buildColumns(): GridColumn<Row>[] {
  return [
    { field: "caNo", header: "번호", width: 110 },
    { field: "occurDt", header: "발생일", width: 100 },
    { field: "srcDocNo", header: "원문서", width: 120 },
    { field: "deviationDesc", header: "이탈내용", width: 220 },
    {
      field: "status",
      header: "상태",
      width: 80,
      type: "code",
      codeOptions: [...STATUS_OPTIONS],
      codeMap: Object.fromEntries(STATUS_OPTIONS.map((opt) => [opt.value, opt.label])),
    },
  ];
}
