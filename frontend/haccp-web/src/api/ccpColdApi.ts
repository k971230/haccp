/**
 * ccpColdApi — CCP 냉장보관 모니터링 API (ccp-cold-monitor).
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) /api/v1/ccp/cold-monitor 목록·상세·저장·삭제 검증·삭제를 감싼다
 *   2) 삭제는 POST validate-delete → delete, Body는 [{ docIdx }] 객체 배열
 *   3) 회사코드는 보내지 않는다 — JWT가 테넌트를 고정한다
 *
 * PIPELINE[HF80] API 레이어
 * PIPELINE[HF3] 연관 모듈
 */
// 역할 — 일반 타임아웃 Axios
import { http } from "./http";
// 역할 — 공통 응답 래퍼
import type { CommonResponse } from "@/types/common";

/** 목록 행 */
export interface ColdMonitorListRow {
  docIdx: number;
  hdrIdx: number;
  docNo: string;
  baseDt: string;
  ccpCd: string;
  title: string;
  status: string;
  mngUserId?: string;
  mngNm?: string;
  writerId?: string;
  rowCnt: number;
  ngCnt: number;
}

/** 보관고(열) */
export interface StorageRow {
  storageCd: string;
  storageNm: string;
  storageType: string;
  ccpCd?: string;
  // 위치 표기 — 열 머리글 보조
  placeNm?: string | null;
  tempMin?: number | null;
  tempMax?: number | null;
  sortNo: number;
}

/** 한계기준 — 일지 제목·한계·주기·방법 문구 원천 */
export interface CcpLimitRow {
  ccpCd: string;
  ccpNm: string;
  limitType?: string;
  minVal?: number | null;
  maxVal?: number | null;
  unitNm?: string;
  cycleMin?: number | null;
  formTitle?: string | null;
  cycleRmk?: string | null;
  limitRmk?: string;
  methodRmk?: string;
  feSize?: number | null;
  stsSize?: number | null;
}

/** 이탈 푸터 — tbl_corrective_action 문서 1건 */
export interface DocCorrectiveDto {
  idx?: number;
  deviationDesc?: string | null;
  actionDesc?: string | null;
  actionUserNm?: string | null;
  confirmUserNm?: string | null;
  status?: string | null;
}

/** 온도 셀 */
export interface ColdMonitorTempCell {
  storageCd: string;
  tempVal?: number | null;
  judgeCd?: string | null;
}

/** 점검행 */
export interface ColdMonitorRowDto {
  idx?: number;
  rowSeq: number;
  checkTime: string;
  // 행 판정 — 자동 P/F, 수동 O/X (judgeModYn=Y)
  judgeCd?: string | null;
  judgeModYn?: string;
  checkerId?: string;
  checkerNm?: string;
  // 작성자 — 로그인 기본, 행별 수정
  writerId?: string;
  writerNm?: string;
  // 행 서명 보유여부 Y/N — Y로 저장하면 SP가 점검자 서명 원본을 그 행에 복사한다
  signYn?: string | null;
  temps: ColdMonitorTempCell[];
}

/** 헤더 */
export interface ColdMonitorHeader {
  docIdx: number;
  hdrIdx: number;
  docNo: string;
  baseDt: string;
  ccpCd: string;
  title: string;
  status: string;
  mngUserId?: string;
  mngNm?: string;
  verNo?: number;
}

/** 상세 묶음 */
export interface ColdMonitorDetail {
  header: ColdMonitorHeader | null;
  rows: ColdMonitorRowDto[];
  storages: StorageRow[];
  limits: CcpLimitRow[];
  corrective?: DocCorrectiveDto | null;
}

/** 저장 요청 */
export interface ColdMonitorSaveRequest {
  docIdx?: number | null;
  baseDt: string;
  ccpCd: string;
  mngUserId?: string;
  mngNm?: string;
  rows: ColdMonitorRowDto[];
  corrective?: DocCorrectiveDto | null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 작성일 구간으로 일지 목록을 조회한다
 *   2) 화면 조회 버튼에서 호출한다
 *   3) 성공 시 목록 배열
 */
export async function listColdMonitors(
  // 조회 조건 — 날짜 YYYYMMDD, 문서번호·작성자 부분검색
  params: { fromDt?: string; toDt?: string; ccpCd?: string; docNo?: string; writer?: string }
): Promise<ColdMonitorListRow[]> {
  const { data } = await http.get<CommonResponse<ColdMonitorListRow[]>>(
    "/api/v1/ccp/cold-monitor/list",
    { params }
  );
  return data.data ?? [];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 문서 상세 또는 신규 양식 뼈대를 조회한다
 *   2) docIdx 없으면(= 신규) 보관고·한계기준만 온다
 *   3) 성공 시 ColdMonitorDetail
 */
export async function getColdMonitorDetail(
  // 문서 idx — 신규면 생략
  docIdx?: number | null
): Promise<ColdMonitorDetail> {
  const { data } = await http.get<CommonResponse<ColdMonitorDetail>>(
    "/api/v1/ccp/cold-monitor/detail",
    { params: docIdx && docIdx > 0 ? { docIdx } : {} }
  );
  return data.data;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 일지를 저장하고 문서 idx를 받는다
 *   2) 화면 저장 버튼에서 호출한다
 *   3) 성공 시 docIdx
 */
export async function saveColdMonitor(
  // 저장 본문 — 행 전체
  body: ColdMonitorSaveRequest
): Promise<number> {
  const { data } = await http.put<CommonResponse<{ docIdx: number }>>(
    "/api/v1/ccp/cold-monitor/save",
    body
  );
  return data.data.docIdx;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 삭제 가능 여부만 검사한다
 *   2) 확인창 전에 호출한다
 *   3) 차단 시 예외
 */
export async function validateDeleteColdMonitor(
  // 삭제 키 배열
  keys: { docIdx: number }[]
): Promise<void> {
  await http.post("/api/v1/ccp/cold-monitor/validate-delete", keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 임시·반려 문서를 삭제한다
 *   2) 확인 후 호출한다
 *   3) 성공 시 void
 */
export async function deleteColdMonitor(
  // 삭제 키 배열
  keys: { docIdx: number }[]
): Promise<void> {
  await http.post("/api/v1/ccp/cold-monitor/delete", keys);
}
