/**
 * ccpFormsApi — CCP 금속검출·검증점검표·연간 검증계획서 공통 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 화면별 semantic kebab-case 경로로 목록·상세·저장·삭제를 호출한다
 *   2) 삭제는 POST validate-delete 후 POST delete이며 복합키 객체 배열을 보낸다
 *   3) 회사코드는 보내지 않고 JWT의 테넌트 클레임만 사용한다
 *
 * PIPELINE[HF84] CCP 추가 양식 API
 * PIPELINE[HF3, HB75] 연관 모듈
 */
import { http } from "./http";
import type { CommonResponse } from "@/types/common";

export type CcpFormCode = "metal-monitor" | "verification-check" | "annual-verification-plan";
export type CcpRow = Record<string, unknown>;

export async function listCcpForms(
  form: CcpFormCode,
  // 기간·문서번호·작성자 — 공백이면 SP 전체
  params: { fromDt?: string; toDt?: string; docNo?: string; writer?: string }
): Promise<CcpRow[]> {
  const { data } = await http.get<CommonResponse<CcpRow[]>>(`/api/v1/ccp/${form}/list`, { params });
  return data.data ?? [];
}
export async function detailCcpForm(form: CcpFormCode, docIdx?: number | null): Promise<CcpRow> {
  const { data } = await http.get<CommonResponse<CcpRow>>(`/api/v1/ccp/${form}/detail`, { params: docIdx ? { docIdx } : {} });
  return data.data;
}
export async function saveCcpForm(form: CcpFormCode, body: CcpRow): Promise<number> {
  const { data } = await http.put<CommonResponse<{ docIdx: number }>>(`/api/v1/ccp/${form}/save`, body);
  return data.data.docIdx;
}
export async function validateDeleteCcpForm(form: CcpFormCode, keys: { docIdx: number }[]): Promise<void> {
  await http.post(`/api/v1/ccp/${form}/validate-delete`, keys);
}
export async function deleteCcpForm(form: CcpFormCode, keys: { docIdx: number }[]): Promise<void> {
  await http.post(`/api/v1/ccp/${form}/delete`, keys);
}
