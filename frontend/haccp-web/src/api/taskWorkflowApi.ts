/**
 * taskWorkflowApi — 오늘 할 일·알림·개선조치 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 오늘할일·개선조치 화면의 고정 API 계약만 제공한다
 *   2) 회사·사용자 값은 JWT에서 결정되므로 브라우저 요청에 전송하지 않는다
 *   3) 개선조치 삭제는 validate-delete와 delete의 객체 배열 계약을 지킨다
 *
 * PIPELINE[HF87] 워크플로 화면 API
 * PIPELINE[HF3, HF88, HF89] 연관 모듈
 */
// 역할 — 일반 API Axios
import { http } from "./http";
// 역할 — 공통 응답 형식
import type { CommonResponse } from "@/types/common";
// 역할 — SP Map snake_case → camelCase
import { camelizeRows } from "@/lib/camelKeys";
// 역할 — 최근 문서 행 타입 — 문서함과 동일
import type { DocumentListRow } from "./documentApi";

export type WorkflowRow = Record<string, unknown> & {
  idx?: number;
  taskIdx?: number;
  title?: string;
  status?: string;
  linkScrnCd?: string;
  docIdx?: number;
  taskType?: string;
  content?: string;
  dueDt?: string;
  dueTime?: string;
  tmplCd?: string;
  baseDt?: string;
  docKind?: string;
};
async function getRows(url: string, params?: Record<string, string>) {
  const { data } = await http.get<CommonResponse<Record<string, unknown>[]>>(url, { params });
  // ca_no·doc_idx 등 → camelCase — 그리드 field 공백 방지
  return camelizeRows<WorkflowRow>(data.data);
}
export const listTodayTasks = () => getRows("/api/v1/tsk/today-tasks/list");

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 오늘 할 일 최근 문서를 OFFSET/LIMIT 으로 조회한다
 *   2) 랜딩 최근 문서 패널이 호출한다
 *   3) total 은 기간 전체 건수. rows 는 현재 페이지만
 */
export async function listTodayRecentDocs(
  // fromDt·toDt: YYYYMMDD. offset·limit: SP 페이지
  params: { fromDt: string; toDt: string; offset: number; limit: number },
): Promise<{ rows: DocumentListRow[]; total: number }> {
  const { data } = await http.get<CommonResponse<{ rows?: Record<string, unknown>[]; total?: number }>>(
    "/api/v1/tsk/today-tasks/recent-docs",
    {
      params: {
        fromDt: params.fromDt,
        toDt: params.toDt,
        offset: String(params.offset),
        limit: String(params.limit),
      },
    },
  );
  const payload = data.data ?? {};
  return {
    rows: camelizeRows<DocumentListRow & Record<string, unknown>>(payload.rows ?? []),
    total: Number(payload.total ?? 0),
  };
}
export const listNotifications = () => getRows("/api/v1/tsk/notifications/list");
export const readNotification = (idx: number) => http.put(`/api/v1/tsk/notifications/${idx}/read`);
/** 이탈·개선조치 목록 — 일자 구간·양식·작성자 */
export const listCorrectiveActions = (params: { fromDt?: string; toDt?: string; tmplCd?: string; writer?: string }) => getRows("/api/v1/flow/ca/corrective-action-management/list", params as Record<string, string>);
export const saveCorrectiveAction = (row: WorkflowRow) => http.put("/api/v1/flow/ca/corrective-action-management/save", row);
export const validateDeleteCorrectiveActions = (keys: { idx: number }[]) => http.post("/api/v1/flow/ca/corrective-action-management/validate-delete", keys);
export const deleteCorrectiveActions = (keys: { idx: number }[]) => http.post("/api/v1/flow/ca/corrective-action-management/delete", keys);
export const listDocumentRelations = (docIdx: number) => getRows(`/api/v1/docs/documents/${docIdx}/relations`);
export const saveDocumentRelation = (docIdx: number, relType: string, tgtDocIdx: number) => http.put(`/api/v1/docs/documents/${docIdx}/relations/save`, { relType, tgtDocIdx });
