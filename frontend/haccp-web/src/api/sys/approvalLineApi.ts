/**
 * approvalLineApi — 결재선 관리 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 경로를 폴더와 맞춰 나누되 URL은 /api/v1/bas/approval-lines 를 유지한다
 *   2) 회사코드는 JWT 테넌트다
 *   3) 삭제는 객체 배열 POST. 왼쪽 그리드 삭제 버튼이 호출한다
 *
 * PIPELINE[HF86] 결재선 관리 API
 */
// 역할 — 일반 CRUD Axios
import { http } from "../http";
// 역할 — 서버 공통 응답
import type { CommonResponse } from "@/types/common";

/** 결재 단계 1건 — 작성·검토·승인 고정 3행 */
export interface ApprovalStep {
  stepNo: number;
  roleCd: "WRITE" | "REVIEW" | "APPROVE";
  approverId?: string | null;
  approverNm?: string | null;
  deptCd?: string | null;
  deptNm?: string | null;
  useYn?: "Y" | "N" | string | null;
}

/** 결재선 헤더 + 단계 */
export interface ApprovalLine {
  apprLineCd: string;
  apprLineNm: string;
  useYn: "Y" | "N";
  steps: ApprovalStep[];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 회사 결재선 목록을 받는다
 *   2) 화면 조회·점검항목 콤보가 호출한다
 *   3) 없으면 빈 배열
 */
export async function listApprovalLines(): Promise<ApprovalLine[]> {
  const { data } = await http.get<CommonResponse<ApprovalLine[]>>("/api/v1/bas/approval-lines/list");
  return data.data ?? [];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 결재선 1건을 저장한다
 *   2) 좌측 저장에서 호출한다
 *   3) 단계는 항상 작성·검토·승인 3건
 */
export async function saveApprovalLine(row: ApprovalLine): Promise<void> {
  await http.put("/api/v1/bas/approval-lines/save", row);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 삭제 가능 여부만 검사한다
 *   2) 확인창 직전에 호출한다
 *   3) Body는 [{ apprLineCd }] — HTTP DELETE 금지
 */
export async function validateDeleteApprovalLines(keys: { apprLineCd: string }[]): Promise<void> {
  await http.post("/api/v1/bas/approval-lines/validate-delete", keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 검증을 통과한 결재선을 삭제한다
 *   2) 왼쪽 삭제 버튼이 호출한다
 *   3) 참조 중이면 업무 오류
 */
export async function deleteApprovalLines(keys: { apprLineCd: string }[]): Promise<void> {
  await http.post("/api/v1/bas/approval-lines/delete", keys);
}
