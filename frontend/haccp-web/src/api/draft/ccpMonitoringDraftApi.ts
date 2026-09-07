/**
 * ccpMonitoringDraftApi — CCP 포장·가열·금속검출 모니터링일지 작성 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 세 화면이 경로만 다르고 계약이 같다. 팩터리 하나로 만들어 파일을 복제하지 않는다
 *   2) 베이스는 apiOf(scrnCd) — SCREEN_PATH /draft/ccp-monitoring/{scrnCd} 와 같은 칸
 *   3) 삭제는 POST validate-delete → delete (OPS_DELETE). MTL 만 SP 가 양식코드를 요구해 tmplCd 를 붙인다
 *
 * 전송·전송취소는 여기 없다. 문서 허브 processDocumentApproval(REQUEST/CANCEL) 을 그대로 쓴다.
 *
 * PIPELINE[HF177] CCP 모니터링 작성 API
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
// 역할 — 기록 표 행 계약
import type { HtmlFormLogRow, HtmlFormPassRow, LogPhase } from "@/components/form/htmlFormPaperShared";
// 역할 — 작성 화면 공통 API 계약
import type {
  HtmlFormDraftApi,
  HtmlFormDraftDetail,
  HtmlFormDraftForm,
  HtmlFormDraftListParams,
  HtmlFormDraftListRow,
  HtmlFormDraftSaveRequest,
} from "./htmlFormDraftTypes";

/** 문자열 정규화 — 서버가 null 을 주는 칸이 있다 */
function s(value: unknown): string {
  return value == null ? "" : String(value);
}

/** 숫자 정규화 — rowSeq */
function n(value: unknown): number {
  const x = Number(value);
  return Number.isFinite(x) ? x : 0;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) SP cells EAV 배열 또는 이미 맵인 값을 지면 맵으로 맞춘다
 *   2) asLogRow 와 단위 테스트가 호출한다
 *   3) 배열이면 itemCd → numVal 또는 txtVal. 맵이면 키를 그대로 둔다
 */
export function cellsToMap(
  // raw: 서버 cells — 배열(EAV) 또는 { temp: "4" } 맵
  raw: unknown,
): Record<string, string> {
  const cells: Record<string, string> = {};
  if (Array.isArray(raw)) {
    for (const cell of raw) {
      if (!cell || typeof cell !== "object") continue;
      const rec = cell as Record<string, unknown>;
      const itemCd = s(rec.itemCd);
      if (!itemCd) continue;
      const num = s(rec.numVal);
      const txt = s(rec.txtVal);
      cells[itemCd] = num !== "" ? num : txt;
    }
    return cells;
  }
  if (raw && typeof raw === "object") {
    for (const [key, val] of Object.entries(raw as Record<string, unknown>)) {
      cells[key] = s(val);
    }
  }
  return cells;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 서버 기록행을 지면 행 계약으로 맞춘다
 *   2) 상세 응답 변환에서 호출한다
 *   3) phaseCd 가 비면 작업 전으로 본다 — 옛 문서(DURING)도 화면에서 자리를 잃지 않는다
 */
function asLogRow(raw: Record<string, unknown>): HtmlFormLogRow {
  const phase = s(raw.phaseCd).toUpperCase();
  const cells = cellsToMap(raw.cells);
  return {
    rowSeq: n(raw.rowSeq),
    // 저장된 값이 BEFORE·AFTER 가 아니면(= 옛 DURING·빈값) 작업 전으로 붙인다
    phaseCd: (phase === "AFTER" ? "AFTER" : "BEFORE") as LogPhase,
    productNm: s(raw.productNm),
    checkTime: s(raw.checkTime),
    judgeCd: s(raw.judgeCd),
    judgeModYn: s(raw.judgeModYn) === "Y" ? "Y" : "N",
    checkerNm: s(raw.checkerNm),
    signYn: s(raw.signYn) === "Y" ? "Y" : "N",
    cells,
  };
}

/** 서버 통과량 행 → 지면 행 */
function asPassRow(raw: Record<string, unknown>): HtmlFormPassRow {
  return {
    rowSeq: n(raw.rowSeq),
    productNm: s(raw.productNm),
    passQty: s(raw.passQty),
    detectQty: s(raw.detectQty),
    remark: s(raw.remark),
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 화면코드 하나로 작성 API 묶음을 만든다 — 경로만 다르고 계약은 같다
 *   2) 각 화면 Rule 이 자기 scrnCd 로 호출한다
 *   3) needsTmplOnDelete 는 MTL 처럼 SP 가 양식코드로 문서를 찾는 화면만 true
 */
function makeCcpMonitoringApi(
  // scrnCd: ccp-pkg | ccp-htg | ccp-mtl
  scrnCd: string,
  // needsTmplOnDelete: 삭제 요청에 tmplCd 쿼리를 붙일지
  needsTmplOnDelete = false,
): HtmlFormDraftApi {
  const BASE = apiOf(scrnCd);
  return {
    /** 작성 가능 양식 — 양식관리 사용여부 예 */
    listForms: async (): Promise<HtmlFormDraftForm[]> => {
      const { data } = await http.get<CommonResponse<HtmlFormDraftForm[]>>(`${BASE}/forms`);
      return data.data ?? [];
    },

    /** 좌측 작성 목록 — 서버 검색 조건 5개 */
    list: async (params: HtmlFormDraftListParams): Promise<HtmlFormDraftListRow[]> => {
      const { data } = await http.get<CommonResponse<HtmlFormDraftListRow[]>>(`${BASE}/list`, { params });
      return data.data ?? [];
    },

    /** 상세 또는 신규 기본행 — header·items·logRows·passRows */
    detail: async (tmplCd: string, docIdx?: number | null): Promise<HtmlFormDraftDetail> => {
      const { data } = await http.get<CommonResponse<Record<string, unknown>>>(`${BASE}/detail`, {
        params: docIdx ? { tmplCd, docIdx } : { tmplCd },
      });
      const raw = data.data ?? {};
      const itemsRaw = Array.isArray(raw.items) ? raw.items : [];
      const logRaw = Array.isArray(raw.logRows) ? raw.logRows : [];
      const passRaw = Array.isArray(raw.passRows) ? raw.passRows : [];
      return {
        header: (raw.header ?? null) as Record<string, unknown> | null,
        items: itemsRaw.map((row, i) => asItem(row as Record<string, unknown>, i)),
        logRows: logRaw.map((row) => asLogRow(row as Record<string, unknown>)),
        passRows: passRaw.map((row) => asPassRow(row as Record<string, unknown>)),
        corrective: (raw.corrective as DocCorrectiveValue | null) ?? null,
        // 문서 스탬프 — 저장 때 seenUpdDt 로 되돌린다
        updDt: typeof raw.updDt === "string" ? raw.updDt : null,
      };
    },

    /** 저장 — 전송하지 않고 전송대기를 유지한다 */
    save: async (body: HtmlFormDraftSaveRequest): Promise<number> => {
      const { data } = await http.put<CommonResponse<{ docIdx: number }>>(`${BASE}/save`, body);
      return data.data.docIdx;
    },

    /** 삭제 검증 — 확인창 전 */
    validateDelete: async (keys: { docIdx: number }[]): Promise<void> => {
      await http.post(`${BASE}/validate-delete`, keys);
    },

    /** 삭제 — HTTP DELETE 는 쓰지 않는다 */
    remove: async (keys: { docIdx: number }[], tmplCd?: string): Promise<void> => {
      await http.post(`${BASE}/delete`, keys, {
        // MTL 은 SP 가 양식코드로 문서를 찾아 tmplCd 를 함께 넘긴다
        params: needsTmplOnDelete && tmplCd ? { tmplCd } : undefined,
      });
    },
  };
}

/** CCP 포장(CCP-1B) 작성 API — /api/v1/draft/ccp-monitoring/ccp-pkg */
export const ccpPkgDraftApi: HtmlFormDraftApi = makeCcpMonitoringApi("ccp-pkg");

/** CCP 가열(CCP-2B) 작성 API — /api/v1/draft/ccp-monitoring/ccp-htg */
export const ccpHtgDraftApi: HtmlFormDraftApi = makeCcpMonitoringApi("ccp-htg");

/** CCP 금속검출(CCP-3P) 작성 API — /api/v1/draft/ccp-monitoring/ccp-mtl. 삭제에 양식코드가 붙는다 */
export const ccpMtlDraftApi: HtmlFormDraftApi = makeCcpMonitoringApi("ccp-mtl", true);
