/**
 * bizOpsApi — 시설점검·검교정대상 HTML 양식 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 역할 기반 screenCode가 API 경로와 양식 화면의 단일 식별자다
 *   2) 삭제는 POST validate-delete → 확인 → delete 순서이며 키는 객체 배열만 전송한다
 *   3) 폐기·재고·입고·공정은 HWP leaf이며 이 모듈을 쓰지 않는다
 *
 * PIPELINE[HF84] 시설·검교정 API
 * PIPELINE[HF3, HF85] 연관 모듈
 */
import { http } from "./http";
import type { CommonResponse } from "@/types/common";

export type BizOpsScreenCode =
  | "facility-equipment-check"
  | "calibration-target-management";

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
  if (screenCode === "calibration-target-management") return "/api/v1/fac/calibration-target-management";
  return "/api/v1/fac/facility-equipment-check";
}

export async function listBizOps(
  screenCode: BizOpsScreenCode,
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
