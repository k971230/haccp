/**
     * htmlFormApi — HTML 양식 원본·공정점검 작성 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 기준관리는 /api/v1/docs/html-form, 작성은 /api/v1/docs/hyg-process
 *   2) 목록·복사는 tmplCd로 공정점검(html_hyg_prc)/검증점검(tml_ccp_chk)/포장일지(tml_ccp_pkg)/가열일지(tml_ccp_htg)/금속검출일지(tml_ccp_mtl) 테이블을 가른다
 *   3) 삭제는 POST validate-delete → delete, Body는 객체 배열
 *
 * PIPELINE[HF130] HTML양식 API
 */
// 역할 — 일반 CRUD Axios (10s)
import { http } from "../http";
// 역할 — 서버 공통 응답
import type { CommonResponse } from "@/types/common";
import type { DocCorrectiveValue } from "@/components/form/DocDeviationFooter";
// 역할 — 사용여부 Y/N 정규화
import { toYn } from "@/lib/yn";

export const HTML_SYS_001 = "html_sys_001";
export const HTML_HYG_PRC_000 = "html_hyg_prc_000";
export const HTML_HYG_000 = HTML_HYG_PRC_000;
export const TML_CCP_CHK_000 = "tml_ccp_chk_000";
export const TML_CCP_PKG_000 = "tml_ccp_pkg_000";
export const TML_CCP_HTG_000 = "tml_ccp_htg_000";
export const TML_CCP_MTL_000 = "tml_ccp_mtl_000";

export interface HtmlFormVerRow {
  // PK. 표준 가상행은 null
  idx?: number | null;
  // 양식코드 — 예시 html_hyg_prc_000, 자사 html_hyg_prc_001…
  tmplCd: string;
  verNo: number;
  // 양식코드와 같음. 검색 호환
  verCd: string;
  verNm: string;
  sysYn: string;
  applyYn: string;
  lockedYn: string;
  // 작성자명 — 표준 가상행은 빈칸
  insNm: string;
  // 작성일시 YYYY-MM-DD — 표준 가상행은 빈칸
  insDt: string;
  // 회사 양식 사용여부 Y/N — 문서주기가 이 값을 본다. 표준은 N
  useYn: string;
}

export interface HtmlFormItem {
  itemCd: string;
  sortNo: number;
  cycleNm: string;
  grpNm: string;
  itemNm: string;
  // html-input-ty — radio / radio-num / radio-text / num / text
  inputType: string;
  unitNm?: string | null;
  yn?: string | null;
  valNm?: string | null;
}

export interface HygProcessListRow {
  docIdx: number;
  hdrIdx: number;
  docNo: string;
  baseDt: string;
  checkerNm?: string | null;
  status: string;
  rowCnt?: number;
  ngCnt?: number;
}

export interface HygProcessDetail {
  header: Record<string, unknown> | null;
  items: HtmlFormItem[];
  corrective?: DocCorrectiveValue | null;
}

export interface HygProcessSaveRequest {
  docIdx?: number | null;
  baseDt: string;
  checkerNm?: string;
  verNo?: number;
  items: HtmlFormItem[];
  specialNote?: string;
  improveNote?: string;
  actionNm?: string;
  confirmNm?: string;
  // 승인자 — 헤더. 저장 시 서명 스냅샷
  approverNm?: string;
  corrective?: DocCorrectiveValue | null;
}

const FORM = "/api/v1/docs/html-form";
const PROC = "/api/v1/docs/hyg-process";

function n(v: unknown): number {
  const x = Number(v);
  return Number.isFinite(x) ? x : 0;
}

function s(v: unknown): string {
  return v == null ? "" : String(v);
}

const HTML_INPUT_TY_LEGACY: Record<string, string> = {
  YN: "radio",
  YN_NUM: "radio-num",
  YN_TEXT: "radio-text",
  NUM: "num",
  TEXT: "text",
};

/** kebab 입력유형 → 라디오·숫자·문자. 값칸은 num||text */
const HTML_INPUT_LAYOUT: Record<string, { radio: boolean; num: boolean; text: boolean }> = {
  radio: { radio: true, num: false, text: false },
  "radio-num": { radio: true, num: true, text: false },
  "radio-text": { radio: true, num: false, text: true },
  num: { radio: false, num: true, text: false },
  text: { radio: false, num: false, text: true },
};

const HTML_INPUT_TY_LABEL: Record<string, string> = {
  radio: "라디오",
  "radio-num": "라디오 숫자",
  "radio-text": "라디오 문자",
  num: "숫자",
  text: "문자",
};

export const HTML_INPUT_DEFAULT_TY = "radio";
export const HTML_INPUT_DEFAULT_UNIT = "℃";

/** 공통코드 html-input-ty 미로드 때 콤보 */
export const FALLBACK_HTML_INPUT_TY = Object.keys(HTML_INPUT_LAYOUT).map((subCd) => ({
  subCd,
  codeNm: HTML_INPUT_TY_LABEL[subCd] ?? subCd,
}));

export type HtmlFormInputFlags = { radio: boolean; num: boolean; text: boolean; valueCell: boolean };

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 입력유형을 html-input-ty kebab 으로 맞춘다
 *   2) 목록·저장 전 호출한다
 *   3) 옛 YN 계열이면 대응 코드, 맵에 없으면 radio
 */
export function normalizeHtmlInputTy(raw: string): string {
  const t = (raw || "").trim();
  if (!t) return HTML_INPUT_DEFAULT_TY;
  const mapped = HTML_INPUT_TY_LEGACY[t.toUpperCase()];
  if (mapped) return mapped;
  const lower = t.toLowerCase();
  return HTML_INPUT_LAYOUT[lower] ? lower : HTML_INPUT_DEFAULT_TY;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 입력유형 한 번으로 라디오·숫자·문자·값칸을 정한다
 *   2) 공정점검·검증점검 행 렌더와 유형 콤보가 호출한다
 *   3) 맵에 없으면 radio
 */
export function htmlFormInputLayout(raw: string): HtmlFormInputFlags {
  const row = HTML_INPUT_LAYOUT[normalizeHtmlInputTy(raw)] ?? HTML_INPUT_LAYOUT.radio;
  return { radio: row.radio, num: row.num, text: row.text, valueCell: row.num || row.text };
}

// (1) 공통화: 라디오·숫자·문자·값칸 판단을 htmlFormInputLayout 한 함수로 모았다.
// (2) 하드코딩 제거: kebab 유형 플래그·라벨·기본 단위를 HTML_INPUT_LAYOUT / LABEL / DEFAULT_* 맵으로 올렸다.
// (3) 로직 최적화: 유형 문자열 if-else 체인과 행마다 Has* 3회 호출을 맵 lookup 한 줄로 줄였다.

/** SP·Map 행을 camelCase 버전 행으로 맞춘다. */
export function asVerRow(raw: Record<string, unknown>): HtmlFormVerRow {
  const idxRaw = raw.idx;
  const verNo = n(raw.verNo ?? raw.ver_no);
  const tmplCd = s(raw.tmplCd ?? raw.tmpl_cd)
    || s(raw.verCd ?? raw.ver_cd)
    || (verNo === 0 ? HTML_HYG_PRC_000 : "");
  return {
    idx: idxRaw == null || idxRaw === "" ? null : n(idxRaw),
    tmplCd,
    verNo,
    verCd: s(raw.verCd ?? raw.ver_cd) || tmplCd,
    verNm: s(raw.verNm ?? raw.ver_nm),
    sysYn: s(raw.sysYn ?? raw.sys_yn) || "usr",
    applyYn: s(raw.applyYn ?? raw.apply_yn) || "N",
    lockedYn: s(raw.lockedYn ?? raw.locked_yn) || "N",
    insNm: s(raw.insNm ?? raw.ins_nm),
    insDt: s(raw.insDt ?? raw.ins_dt),
    // 표준(locked)은 컬럼 없어도 N. 자사는 Y
    useYn: toYn(raw.useYn ?? raw.use_yn ?? (s(raw.lockedYn ?? raw.locked_yn) === "Y" ? "N" : "Y")),
  };
}

/** SP·Map 행을 지면 항목으로 맞춘다. */
export function asItem(raw: Record<string, unknown>, index = 0): HtmlFormItem {
  return {
    itemCd: s(raw.itemCd ?? raw.item_cd) || `hp-u-${index + 1}`,
    sortNo: n(raw.sortNo ?? raw.sort_no) || index + 1,
    cycleNm: s(raw.cycleNm ?? raw.cycle_nm),
    grpNm: s(raw.grpNm ?? raw.grp_nm),
    itemNm: s(raw.itemNm ?? raw.item_nm),
    inputType: normalizeHtmlInputTy(s(raw.inputType ?? raw.input_type)),
    unitNm: s(raw.unitNm ?? raw.unit_nm) || null,
    yn: s(raw.yn) || "",
    valNm: s(raw.valNm ?? raw.val_nm),
  };
}

/** 좌측 양식 목록 — 예시 html_hyg_prc_000 포함. verCd·verNm 빈값이면 전체 */
export async function listHtmlFormVersions(params?: {
  tmplCd?: string;
  verCd?: string;
  verNm?: string;
}): Promise<HtmlFormVerRow[]> {
  const { data } = await http.get<CommonResponse<Record<string, unknown>[]>>(`${FORM}/versions`, {
    params: {
      tmplCd: params?.tmplCd ?? "",
      verCd: params?.verCd ?? "",
      verNm: params?.verNm ?? "",
    },
  });
  return (data.data ?? []).map((row) => asVerRow(row));
}

/** 양식 항목 — html_hyg_prc_000 이면 시드 */
export async function listHtmlFormItems(tmplCd = HTML_HYG_PRC_000, verNo = 0): Promise<HtmlFormItem[]> {
  const { data } = await http.get<CommonResponse<Record<string, unknown>[]>>(`${FORM}/items`, {
    params: { tmplCd, verNo },
  });
  return (data.data ?? []).map((row, i) => asItem(row, i));
}

/** 표준 시드 복사 — 좌 저장이 pending을 INSERT. 새 tmplCd 반환 */
export async function copyHtmlFormVersion(body: {
  tmplCd?: string;
  srcVerNo?: number;
  verCd?: string;
  verNm: string;
}): Promise<string> {
  const { data } = await http.put<CommonResponse<{ tmplCd?: string }>>(`${FORM}/copy`, {
    srcVerNo: 0,
    ...body,
  });
  return s(data.data?.tmplCd);
}

/** 사용자 버전 항목 저장 */
export async function saveHtmlFormItems(verNo: number, items: HtmlFormItem[], tmplCd: string): Promise<void> {
  await http.put(`${FORM}/items`, { tmplCd, verNo, items });
}

/** 작성 신규 적용 — 좌 저장에서만 호출 */
export async function applyHtmlFormVersion(verNo: number, tmplCd = HTML_SYS_001): Promise<void> {
  await http.put(`${FORM}/apply`, { tmplCd, verNo });
}

/** 사용자 버전명·회사 사용여부 — 좌 저장이 바뀐 이름·useYn을 커밋. 표준은 서버가 막는다 */
export async function updateHtmlFormVerNm(body: {
  tmplCd?: string;
  verNo: number;
  verNm: string;
  // 회사 양식 사용여부 Y/N. 없으면 서버가 Y
  useYn?: string;
}): Promise<void> {
  await http.put(`${FORM}/name`, {
    tmplCd: body.tmplCd ?? HTML_HYG_PRC_000,
    verNo: body.verNo,
    verNm: body.verNm,
    useYn: body.useYn ?? "Y",
  });
}

/** 삭제 검증 — 표준은 서버가 막는다 */
export async function validateDeleteHtmlFormVersions(keys: { tmplCd: string; verNo: number }[]): Promise<void> {
  await http.post(`${FORM}/validate-delete`, keys);
}

/** 자사 양식 삭제 */
export async function deleteHtmlFormVersions(keys: { tmplCd: string; verNo: number }[]): Promise<void> {
  await http.post(`${FORM}/delete`, keys);
}

/** 작성 목록 */
export async function listHygProcess(params: {
  fromDt?: string;
  toDt?: string;
  docNo?: string;
  writer?: string;
}): Promise<HygProcessListRow[]> {
  const { data } = await http.get<CommonResponse<HygProcessListRow[]>>(`${PROC}/list`, { params });
  return data.data ?? [];
}

/** 상세 또는 적용 버전 신규 */
export async function getHygProcessDetail(docIdx?: number | null): Promise<HygProcessDetail> {
  const { data } = await http.get<CommonResponse<Record<string, unknown>>>(`${PROC}/detail`, {
    params: docIdx ? { docIdx } : {},
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

/** 저장 — 문서 idx 반환 */
export async function saveHygProcess(body: HygProcessSaveRequest): Promise<number> {
  const { data } = await http.put<CommonResponse<{ docIdx: number }>>(`${PROC}/save`, body);
  return data.data.docIdx;
}

/** 삭제 검증 */
export async function validateDeleteHygProcess(keys: { docIdx: number }[]): Promise<void> {
  await http.post(`${PROC}/validate-delete`, keys);
}

/** 삭제 */
export async function deleteHygProcess(keys: { docIdx: number }[]): Promise<void> {
  await http.post(`${PROC}/delete`, keys);
}
