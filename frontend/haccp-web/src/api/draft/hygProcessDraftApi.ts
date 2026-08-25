/**
 * hygProcessDraftApi — HYG 위생공정 양식 작성 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 베이스는 apiOf("hyg-process") — SCREEN_PATH /draft/hyg/hyg-process 와 같은 칸
 *   2) 양식관리 hyg-process-template 에서 사용여부 예로 둔 자사 양식(html_hyg_prc_NNN)만 온다
 *   3) 삭제는 POST validate-delete → delete, Body 는 객체 배열 (OPS_DELETE)
 *
 * 전송·전송취소는 여기 없다. 문서 허브 processDocumentApproval(REQUEST/CANCEL) 을 그대로 쓴다.
 * 행·요청 타입은 CCP 와 공유한다 — htmlFormDraftTypes.
 *
 * PIPELINE[HF172] 위생공정 작성 API
 */
// 역할 — 일반 CRUD Axios (10s)
import { http } from "../http";
// 역할 — SCREEN_PATH 기준 API 베이스
import { apiOf } from "@/shell/tabRoute";
// 역할 — 서버 공통 응답
import type { CommonResponse } from "@/types/common";
// 역할 — SP snake 항목을 camelCase 로 정규화
import { asItem } from "@/api/docs/htmlFormApi";
// 역할 — 이탈·개선조치 푸터 값
import type { DocCorrectiveValue } from "@/components/form/DocDeviationFooter";
// 역할 — 작성 화면 공통 API 계약
import type {
  HtmlFormDraftApi,
  HtmlFormDraftDetail,
  HtmlFormDraftForm,
  HtmlFormDraftListParams,
  HtmlFormDraftListRow,
  HtmlFormDraftSaveRequest,
} from "./htmlFormDraftTypes";

/** 화면코드 — tbl_screen.scrn_cd. API 베이스 조립 키 */
const SCRN_CD = "hyg-process";

/** 화면 API 베이스 — /api/v1/draft/hyg/hyg-process */
const BASE = apiOf(SCRN_CD);

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 작성에 쓸 수 있는 양식만 조회한다 — 양식관리 사용여부 예
 *   2) 화면 진입 시 한 번 호출해 양식 선택 팝업 목록으로 쓴다
 *   3) 없으면 빈 배열 — 화면이 양식관리 등록을 안내한다
 */
export async function listHygProcessDraftForms(): Promise<HtmlFormDraftForm[]> {
  const { data } = await http.get<CommonResponse<HtmlFormDraftForm[]>>(`${BASE}/forms`);
  return data.data ?? [];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 상단 검색 6개 중 서버 조건 5개(일자 구간·양식코드·양식명·작성자ID·작성자명)로 조회한다
 *   2) 조회 버튼·저장·삭제·전송 후 호출한다
 *   3) 빈 조건은 서버가 전체로 본다. 결재 여부는 파생값이라 화면이 거른다
 */
export async function listHygProcessDraft(
  // params: 서버 검색 조건 5개
  params: HtmlFormDraftListParams,
): Promise<HtmlFormDraftListRow[]> {
  const { data } = await http.get<CommonResponse<HtmlFormDraftListRow[]>>(`${BASE}/list`, { params });
  return data.data ?? [];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 기존 상세 또는 선택 양식의 신규 기본행을 조회한다
 *   2) 좌측 행 클릭·양식 선택이 호출한다
 *   3) 항목 snake 는 asItem 이 camelCase 로 맞춘다
 */
export async function getHygProcessDraftDetail(
  // tmplCd: 신규일 때 항목을 깔 양식코드. 필수
  tmplCd: string,
  // docIdx: 없으면 신규 기본행
  docIdx?: number | null,
): Promise<HtmlFormDraftDetail> {
  const { data } = await http.get<CommonResponse<Record<string, unknown>>>(`${BASE}/detail`, {
    params: docIdx ? { tmplCd, docIdx } : { tmplCd },
  });
  const raw = data.data ?? {};
  const header = (raw.header ?? null) as Record<string, unknown> | null;
  const itemsRaw = Array.isArray(raw.items) ? raw.items : [];
  return {
    header,
    items: itemsRaw.map((row, i) => asItem(row as Record<string, unknown>, i)),
    corrective: (raw.corrective as DocCorrectiveValue | null) ?? null,
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 작성 내용을 저장한다 — 전송대기 상태로 남는다
 *   2) 저장 버튼이 호출한다
 *   3) 성공 시 문서 idx. 전송 이후 문서는 서버가 막는다
 */
export async function saveHygProcessDraft(body: HtmlFormDraftSaveRequest): Promise<number> {
  const { data } = await http.put<CommonResponse<{ docIdx: number }>>(`${BASE}/save`, body);
  return data.data.docIdx;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 삭제 가능 여부만 검사한다
 *   2) 확인창 전에 호출한다
 *   3) 전송·결재완료면 서버가 차단 문구를 준다
 */
export async function validateDeleteHygProcessDraft(keys: { docIdx: number }[]): Promise<void> {
  await http.post(`${BASE}/validate-delete`, keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 문서와 하위 항목을 삭제한다
 *   2) 확인 후 호출한다
 *   3) HTTP DELETE 는 쓰지 않는다
 */
export async function deleteHygProcessDraft(keys: { docIdx: number }[]): Promise<void> {
  await http.post(`${BASE}/delete`, keys);
}

/** 공통 작성 화면에 넘길 API 묶음 — HtmlFormDraftPage 가 이것만 본다 */
export const hygProcessDraftApi: HtmlFormDraftApi = {
  listForms: listHygProcessDraftForms,
  list: listHygProcessDraft,
  detail: getHygProcessDraftDetail,
  save: saveHygProcessDraft,
  validateDelete: validateDeleteHygProcessDraft,
  remove: deleteHygProcessDraft,
};
