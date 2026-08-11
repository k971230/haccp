/**
 * bizOpsApi — 시설·재고·공정 DB형 양식 6종 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) 역할 기반 screenCode가 API 경로와 양식 화면의 단일 식별자다
 *   2) 삭제는 POST validate-delete → 확인 → delete 순서이며 키는 객체 배열만 전송한다
 *   3) header·rows는 양식별 필드를 가진 JSON이지만 회사코드는 JWT에서 결정되어 보내지 않는다
 *
 * G-15(STEP 23): BE는 fac/inv/prc 6 base가 잔존한다. 활성 작성 UI는
 * screenRegistry의 facility-equipment-check(BizOpsFormPage)뿐이다.
 * waste/inventory/receiving/process는 HWP leaf(documentApi)로 이전되었고
 * 이 모듈을 HWP 화면에서 import하지 않는다. 잔존 API 삭제는 별도 승인.
 *
 * PIPELINE[HF84] 시설·재고·공정 API
 * PIPELINE[HF3, HF85] 연관 모듈
 */
// 역할 — 일반 타임아웃 Axios
import { http } from "./http";
// 역할 — 공통 응답 래퍼
import type { CommonResponse } from "@/types/common";

export type BizOpsScreenCode =
  | "facility-equipment-check"
  | "calibration-target-management"
  | "waste-disposal-check"
  | "inventory-check"
  | "receiving-inspection"
  | "process-control-check";

export interface BizOpsListRow {
  docIdx: number;
  docNo: string;
  baseDt: string;
  title: string;
  status: string;
  rowCnt: number;
  ngCnt: number;
}

export interface BizOpsDetail {
  header: Record<string, unknown> | null;
  rows: Record<string, unknown>[];
  corrective?: {
    deviationDesc?: string | null;
    actionDesc?: string | null;
    actionUserNm?: string | null;
    confirmUserNm?: string | null;
  } | null;
}

function endpoint(screenCode: BizOpsScreenCode): string {
  if (screenCode === "facility-equipment-check") return "/api/v1/fac/facility-equipment-check";
  if (screenCode === "calibration-target-management") return "/api/v1/fac/calibration-target-management";
  if (screenCode === "waste-disposal-check") return "/api/v1/fac/waste-disposal-check";
  if (screenCode === "inventory-check") return "/api/v1/inv/inventory-check";
  if (screenCode === "receiving-inspection") return "/api/v1/inv/receiving-inspection";
  return "/api/v1/prc/process-control-check";
}

export async function listBizOps(
  screenCode: BizOpsScreenCode,
  // 기간·문서번호·작성자 — 공백이면 SP 전체
  params: { fromDt?: string; toDt?: string; docNo?: string; writer?: string }
): Promise<BizOpsListRow[]> {
  const { data } = await http.get<CommonResponse<BizOpsListRow[]>>(`${endpoint(screenCode)}/list`, { params });
  return data.data ?? [];
}

export async function getBizOpsDetail(screenCode: BizOpsScreenCode, docIdx?: number | null): Promise<BizOpsDetail> {
  const { data } = await http.get<CommonResponse<BizOpsDetail>>(`${endpoint(screenCode)}/detail`, {
    params: docIdx && docIdx > 0 ? { docIdx } : {},
  });
  return data.data;
}

export async function saveBizOps(
  screenCode: BizOpsScreenCode,
  docIdx: number | null,
  payload: Record<string, unknown>,
  corrective?: {
    deviationDesc?: string | null;
    actionDesc?: string | null;
    actionUserNm?: string | null;
    confirmUserNm?: string | null;
  } | null
): Promise<number> {
  const { data } = await http.put<CommonResponse<{ docIdx: number }>>(`${endpoint(screenCode)}/save`, {
    docIdx,
    payload,
    corrective,
  });
  return data.data.docIdx;
}

export async function validateDeleteBizOps(screenCode: BizOpsScreenCode, keys: { docIdx: number }[]): Promise<void> {
  await http.post(`${endpoint(screenCode)}/validate-delete`, keys);
}

export async function deleteBizOps(screenCode: BizOpsScreenCode, keys: { docIdx: number }[]): Promise<void> {
  await http.post(`${endpoint(screenCode)}/delete`, keys);
}
