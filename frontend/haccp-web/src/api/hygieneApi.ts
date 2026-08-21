/**
 * hygieneApi — 위생관리 HTML 양식(일일·방충) API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 의미 화면 ID를 URL로 사용해 일일·방충을 독립 호출한다
 *   2) 가변 양식 행은 payload JSON으로 보존하고 DB에서 정규화한다
 *   3) 삭제는 POST validate-delete → delete이며 Body는 객체 배열만 보낸다
 *
 * PIPELINE[HF82] 위생 API
 * PIPELINE[HF83, HB87] 연관 모듈
 */
// 역할 — 일반 CRUD Axios
import { http } from "./http";
// 역할 — SCREEN_PATH 기준 API 베이스
import { apiOf } from "@/shell/tabRoute";
// 역할 — 서버 공통 응답
import type { CommonResponse } from "@/types/common";

export type HygieneScreenCode =
  | "daily-hygiene-check"
  | "pest-control-check";

export interface HygieneListRow {
  docIdx: number;
  hdrIdx: number;
  docNo: string;
  baseDt: string;
  baseDtTo?: string | null;
  checkerNm?: string | null;
  status: string;
  rowCnt: number;
  ngCnt: number;
}

export interface HygieneDetail {
  header: Record<string, unknown> | null;
  entries: Record<string, unknown>[];
  signers: Record<string, unknown>[];
  checkers: Record<string, unknown>[];
  corrective?: {
    deviationDesc?: string | null;
    actionDesc?: string | null;
    actionUserNm?: string | null;
    confirmUserNm?: string | null;
  } | null;
}

export interface HygieneSaveRequest {
  docIdx?: number | null;
  baseDt: string;
  baseDtTo?: string;
  checkerNm?: string;
  payload: Record<string, unknown>;
  corrective?: {
    deviationDesc?: string | null;
    actionDesc?: string | null;
    actionUserNm?: string | null;
    confirmUserNm?: string | null;
  } | null;
}

/** 목록 조회 — 기준일·문서번호·작성자와 의미 화면 ID를 서버에 전달한다. */
export async function listHygiene(
  screenCode: HygieneScreenCode,
  params: { fromDt?: string; toDt?: string; docNo?: string; writer?: string }
): Promise<HygieneListRow[]> {
  const { data } = await http.get<CommonResponse<HygieneListRow[]>>(
    `${apiOf(screenCode)}/list`,
    { params }
  );
  return data.data ?? [];
}

/** 상세 또는 신규 기본행 조회 — docIdx 없으면 DB 표준 점검항목을 기본으로 받는다. */
export async function getHygieneDetail(
  screenCode: HygieneScreenCode,
  docIdx?: number | null
): Promise<HygieneDetail> {
  const { data } = await http.get<CommonResponse<HygieneDetail>>(
    `${apiOf(screenCode)}/detail`,
    { params: docIdx ? { docIdx } : {} }
  );
  return data.data;
}

/** 저장 — 양식 전체 행과 서명·점검자 자료를 교체 저장한다. */
export async function saveHygiene(
  screenCode: HygieneScreenCode,
  body: HygieneSaveRequest
): Promise<number> {
  const { data } = await http.put<CommonResponse<{ docIdx: number }>>(
    `${apiOf(screenCode)}/save`,
    body
  );
  return data.data.docIdx;
}

/** 삭제 검증 — 확인창 전에 객체 배열로 결재 잠금을 검사한다. */
export async function validateDeleteHygiene(
  screenCode: HygieneScreenCode,
  keys: { docIdx: number }[]
): Promise<void> {
  await http.post(`${apiOf(screenCode)}/validate-delete`, keys);
}

/** 삭제 — validate-delete 통과와 사용자 확인 뒤에만 호출한다. */
export async function deleteHygiene(
  screenCode: HygieneScreenCode,
  keys: { docIdx: number }[]
): Promise<void> {
  await http.post(`${apiOf(screenCode)}/delete`, keys);
}
