/**
 * hwpDraftApi — HWP 양식 작성 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) HTML 작성 5화면과 같은 HtmlFormDraftApi 계약을 그대로 구현한다 — 공통 화면이 이 화면만 다르게 다루지 않게 한다
 *   2) 지면 항목·기록 표가 없다. 본문은 rhwp 가 다루고 파일은 문서 첨부 API 가 올린다
 *   3) 오늘 할일 조회(tasks)만 이 화면 고유다 — 행 추가 팝업이 쓴다
 *
 * 전송·전송취소는 여기 없다. 문서 허브 processDocumentApproval(REQUEST/CANCEL) 을 그대로 쓴다.
 *
 * PIPELINE[HF182] HWP 작성 API
 */
// 역할 — 일반 CRUD Axios (10s)
import { http } from "../http";
// 역할 — SCREEN_PATH 기준 API 베이스
import { apiOf } from "@/shell/tabRoute";
// 역할 — 서버 공통 응답
import type { CommonResponse } from "@/types/common";
// 역할 — 작성 화면 공통 API 계약
import type {
  HtmlFormDraftApi,
  HtmlFormDraftFile,
  HtmlFormDraftDetail,
  HtmlFormDraftForm,
  HtmlFormDraftListParams,
  HtmlFormDraftListRow,
  HtmlFormDraftSaveRequest,
} from "./htmlFormDraftTypes";

/** 화면 API 베이스 — /api/v1/draft/hwp-doc/hwp-write */
const BASE = apiOf("hwp-write");

/** 오늘 할일 문서주기 1건 — 행 추가 팝업 행 */
export interface HwpDraftTask {
  // 할일 idx — 팝업 그리드 행 키
  taskIdx: number;
  // 양식코드 — 고르면 이 양식을 rhwp 에 연다
  tmplCd: string;
  // 양식명
  tmplNm: string;
  // 기준일 YYYYMMDD
  baseDt: string;
  // 마감일 YYYYMMDD
  dueDt?: string | null;
  // 마감시각 HH:MM
  dueTime?: string | null;
  // 할일 상태 — TODO 예정 · ING 진행 · LATE 지연
  status: string;
  // 이미 만들어진 문서 idx — 있으면 새로 만들지 않고 그 문서를 연다
  docIdx?: number | null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 기준일의 오늘 할일 중 HWP 문서주기를 조회한다
 *   2) 행 추가 버튼이 팝업을 열기 전에 호출한다
 *   3) 없으면 빈 배열 — 화면은 팝업 없이 빈 행만 추가한다
 */
export async function listHwpDraftTasks(
  // baseDt: 기준일 YYYYMMDD. 비우면 서버가 오늘로 본다
  baseDt?: string,
): Promise<HwpDraftTask[]> {
  const { data } = await http.get<CommonResponse<HwpDraftTask[]>>(`${BASE}/tasks`, {
    params: baseDt ? { baseDt } : undefined,
  });
  return data.data ?? [];
}

/** 문자열 정규화 — 서버가 null 을 주는 칸이 있다 */
function s(value: unknown): string {
  return value == null ? "" : String(value);
}

/** HWP 작성 API 묶음 — 공통 화면 HtmlFormDraftPage 가 이 6개만 호출한다 */
export const hwpDraftApi: HtmlFormDraftApi = {
  /** 작성 가능 양식 — 사용양식 관리 사용여부 예인 HWP 양식 */
  listForms: async (): Promise<HtmlFormDraftForm[]> => {
    const { data } = await http.get<CommonResponse<HtmlFormDraftForm[]>>(`${BASE}/forms`);
    return data.data ?? [];
  },

  /** 좌측 작성 목록 — 서버 검색 조건 5개 */
  list: async (params: HtmlFormDraftListParams): Promise<HtmlFormDraftListRow[]> => {
    const { data } = await http.get<CommonResponse<HtmlFormDraftListRow[]>>(`${BASE}/list`, { params });
    return data.data ?? [];
  },

  /**
   * 상세 — 헤더와 첨부 목록.
   * 지면 항목·기록 표가 없어 items·logRows 는 늘 빈 배열이다.
   * 신규(docIdx 없음)는 서버를 부르지 않는다 — 열 문서가 아직 없다.
   */
  detail: async (_tmplCd: string, docIdx?: number | null): Promise<HtmlFormDraftDetail> => {
    if (!docIdx) {
      return { header: null, items: [], logRows: [], passRows: [], corrective: null };
    }
    const { data } = await http.get<CommonResponse<Record<string, unknown>>>(`${BASE}/detail`, {
      params: { docIdx },
    });
    const raw = data.data ?? {};
    const header = (raw.header ?? null) as Record<string, unknown> | null;
    return {
      header: header
        ? {
            ...header,
            // 공통 화면이 읽는 이름으로 맞춘다 — 문서 허브는 baseDt·writerId 를 같은 이름으로 준다
            baseDt: s(header.baseDt),
            tmplCd: s(header.tmplCd),
            status: s(header.status),
          }
        : null,
      items: [],
      logRows: [],
      passRows: [],
      corrective: null,
      // 본문 파일 — rhwp 가 최신 HWP_SRC 를 열 때 쓴다
      files: Array.isArray(raw.files) ? (raw.files as HtmlFormDraftFile[]) : [],
    };
  },

  /** 저장 — 일자·양식코드만 보낸다. 본문 파일은 저장 뒤 따로 올린다 */
  save: async (body: HtmlFormDraftSaveRequest): Promise<number> => {
    const { data } = await http.put<CommonResponse<{ docIdx: number }>>(`${BASE}/save`, {
      tmplCd: body.tmplCd,
      docIdx: body.docIdx,
      baseDt: body.baseDt,
    });
    return data.data.docIdx;
  },

  /** 삭제 검증 — 확인창 전 */
  validateDelete: async (keys: { docIdx: number }[]): Promise<void> => {
    await http.post(`${BASE}/validate-delete`, keys);
  },

  /** 삭제 — HTTP DELETE 는 쓰지 않는다 */
  remove: async (keys: { docIdx: number }[]): Promise<void> => {
    await http.post(`${BASE}/delete`, keys);
  },
};
