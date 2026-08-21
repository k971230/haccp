/**
 * ccpGenericApi — 가열·세척 등 공통 CCP 모니터링 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 공공 기준일지 매핑으로 제공되는 공통 CCP 템플릿·상세·저장·삭제 API를 묶는다
 *   2) 냉장·금속은 특화 API를 유지하므로 이 모듈을 사용하지 않는다
 *   3) 회사 범위는 HTTP JWT가 서버에서 확정하므로 요청 DTO에 coCd를 넣지 않는다
 *
 * PIPELINE[HF94] 공통 CCP API
 * PIPELINE[HF86, HB98, HB97] 연관 모듈
 */
// 역할 — Axios 공통 HTTP 인스턴스
import { http } from "./http";
// 역할 — SCREEN_PATH 기준 API 베이스
import { apiOf } from "@/shell/tabRoute";
// 역할 — 공통 서버 응답
import type { CommonResponse } from "@/types/common";

export interface GenericCcpTemplate {
  tmplCd: string;
  tmplNm: string;
  diaryNo: string;
  diaryNm: string;
  limitItemKind?: string | null;
  criticalLimitCn?: string | null;
  monitoringCycleCn?: string | null;
  monitoringMethodCn?: string | null;
  improvementMethodCn?: string | null;
  companyUseYn: "Y" | "N";
}

export interface GenericCcpCell {
  itemCd: string;
  numVal?: number | null;
  txtVal?: string | null;
  judgeCd?: string | null;
}

export interface GenericCcpRow {
  rowSeq: number;
  checkTime: string;
  // 설비명 — 측정 셀 앞 열
  equipNm?: string | null;
  // 품명 — 측정 셀 앞 열
  productNm?: string | null;
  judgeCd?: string | null;
  judgeModYn?: string | null;
  checkerId?: string | null;
  checkerNm?: string | null;
  // 행 서명 보유여부 Y/N — Y로 저장하면 SP가 점검자 서명 원본을 그 행에 복사한다
  signYn?: string | null;
  cells: GenericCcpCell[];
}

export interface GenericCcpDetail {
  docIdx: number;
  docNo?: string;
  status?: string;
  baseDt: string;
  tmplCd: string;
  ccpCd?: string | null;
  diaryNo?: string | null;
  limitItemKind?: string | null;
  mngUserId?: string | null;
  mngNm?: string | null;
  rows: GenericCcpRow[];
}

export interface GenericCcpSaveRequest {
  docIdx?: number | null;
  baseDt: string;
  tmplCd: string;
  ccpCd?: string | null;
  diaryNo?: string | null;
  limitItemKind?: string | null;
  mngUserId?: string | null;
  mngNm?: string | null;
  rows: GenericCcpRow[];
}

/** 가열·살균·여과 화면 — 공유 서비스, URL 은 화면마다 다름 */
export type CcpGenericScrnCd =
  | "ccp-heat-monitor"
  | "ccp-sanitize-monitor"
  | "ccp-filter-monitor";

export async function listGenericCcpTemplates(
  // 화면코드 — SCREEN_PATH 3개만
  scrnCd: CcpGenericScrnCd
): Promise<GenericCcpTemplate[]> {
  const { data } = await http.get<CommonResponse<GenericCcpTemplate[]>>(
    `${apiOf(scrnCd)}/templates`
  );
  return data.data ?? [];
}

export async function getGenericCcpDetail(
  // 화면코드
  scrnCd: CcpGenericScrnCd,
  docIdx: number
): Promise<GenericCcpDetail> {
  const { data } = await http.get<CommonResponse<GenericCcpDetail>>(`${apiOf(scrnCd)}/${docIdx}`);
  return data.data;
}

export async function saveGenericCcpMonitor(
  // 화면코드
  scrnCd: CcpGenericScrnCd,
  req: GenericCcpSaveRequest
): Promise<number> {
  const { data } = await http.put<CommonResponse<{ docIdx: number }>>(`${apiOf(scrnCd)}/save`, req);
  return data.data?.docIdx ?? 0;
}

/** 삭제 사전 검증 — OPS_DELETE */
export async function validateDeleteGenericCcp(
  // 화면코드
  scrnCd: CcpGenericScrnCd,
  keys: { docIdx: number }[]
): Promise<void> {
  await http.post(`${apiOf(scrnCd)}/validate-delete`, keys);
}

/** 임시·반려 문서 삭제 */
export async function deleteGenericCcp(
  // 화면코드
  scrnCd: CcpGenericScrnCd,
  keys: { docIdx: number }[]
): Promise<void> {
  await http.post(`${apiOf(scrnCd)}/delete`, keys);
}
