/**
 * taskWorkflowApi — 오늘 할 일·알림·개선조치 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
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

export type WorkflowRow = Record<string, unknown> & { idx?: number; taskIdx?: number; title?: string; status?: string; linkScrnCd?: string; docIdx?: number };
async function getRows(url: string, params?: Record<string, string>) {
  const { data } = await http.get<CommonResponse<Record<string, unknown>[]>>(url, { params });
  // ca_no·doc_idx 등 → camelCase — 그리드 field 공백 방지
  return camelizeRows<WorkflowRow>(data.data);
}
export const listTodayTasks = () => getRows("/api/v1/tsk/today-tasks/list");
export const listNotifications = () => getRows("/api/v1/tsk/notifications/list");
export const readNotification = (idx: number) => http.put(`/api/v1/tsk/notifications/${idx}/read`);
export const listCorrectiveActions = (params: Record<string, string>) => getRows("/api/v1/doc/corrective-actions/list", params);
export const saveCorrectiveAction = (row: WorkflowRow) => http.put("/api/v1/doc/corrective-actions/save", row);
export const validateDeleteCorrectiveActions = (keys: { idx: number }[]) => http.post("/api/v1/doc/corrective-actions/validate-delete", keys);
export const deleteCorrectiveActions = (keys: { idx: number }[]) => http.post("/api/v1/doc/corrective-actions/delete", keys);
export const listDocumentRelations = (docIdx: number) => getRows(`/api/v1/doc/documents/${docIdx}/relations`);
export const saveDocumentRelation = (docIdx: number, relType: string, tgtDocIdx: number) => http.put(`/api/v1/doc/documents/${docIdx}/relations/save`, { relType, tgtDocIdx });
