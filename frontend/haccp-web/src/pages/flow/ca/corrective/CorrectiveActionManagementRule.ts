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
import type { WorkflowRow } from "@/api/board/taskWorkflowApi";

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
  // 조치자 표시명 — 지면·목록에 찍힌다
  actionUserNm?: string;
  /*
   * 조치자 ID — 화면에 열은 없지만 저장·조회되고, 오늘 할 일이 이 값으로 담당을 거른다
   * (`sp_tbl_today_task_doc_r_000`). WorkflowRow 의 인덱스 시그니처 때문에
   * 타입에 없어도 컴파일이 통과해 왔다. 여기 적어 두고 쓰는 곳을 드러낸다.
   */
  actionUserId?: string;
  actionDt?: string;
  dueDt?: string;
  srcDocNo?: string;
  srcTmplCd?: string;
  tmplNm?: string;
  baseDt?: string;
  writerNm?: string;
};

/**
 * 상태 배지 — 미조치 노랑·조치중 파랑·완료 초록.
 *
 * 라벨은 여기서 정하지 않는다. `CA_STATUS` 공통코드가 정본이고 화면이 그것을 넘긴다 —
 * 예전에는 여기에 `OPEN=진행`·`CANCEL` 을 박아 뒀는데,
 * 오늘 할 일은 공통코드를 읽어 같은 코드를 「미조치」로 불러 두 화면이 갈렸다.
 * `CANCEL` 은 6자라 `tbl_corrective_action.status varchar(4)` 에 들어가지도 못했다.
 */
export const STATUS_BADGE = { OPEN: "amber", ING: "blue", DONE: "green" } as const;

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 그리드 하나에 원문서 정보와 조치 입력 칸을 함께 둔다
 *   2) Page 가 useMemo 로 호출한다
 *   3) 문서에서 온 칸은 잠그고 조치 칸만 연다 — 원문서를 여기서 고치지 않는다
 */
export function buildColumns(
  // 상태 콤보 항목 — `CA_STATUS` 공통코드. Page 가 useCommonCodes 로 읽어 넘긴다
  statusOptions: { value: string; label: string }[],
  // 상태 코드 → 표시명 — 같은 공통코드에서 나온 맵
  statusNm: Record<string, string>,
): GridColumn<Row>[] {
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
      // 콤보·표시명 모두 공통코드에서 온다 — 화면이 라벨을 만들지 않는다
      codeOptions: statusOptions,
      codeMap: statusNm,
      badge: STATUS_BADGE,
    },
  ];
}
