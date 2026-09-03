/**
 * htmlFormDraftShared — 양식 작성(draft) 화면 공통 규칙·컬럼·상태·필수값.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) HYG(hyg-process)·CCP(ccp-verify)가 같은 업무 규칙을 쓴다. 화면마다 판정 함수를 복제하지 않는다
 *   2) 결재 여부 3단계(전송대기/전송/결재완료)는 DOC_STATUS 를 묶어 만든다. 새 코드 도메인을 만들지 않는다
 *   3) 필수값 검증은 validateForTransfer 한 함수뿐이다 — 기준이 바뀌면 이 함수만 고친다
 *      화면·코드·문서 용어는 「결재 여부」로 통일한다 (「결제」 금지)
 *
 * 화면별로 다른 값(scrnCd·persistId·양식군·지면 제목·Paper)은 각 Rule 파일이 갖는다. JSX/API 없음.
 *
 * PIPELINE[HF172] 양식 작성 공통 규칙
 */
// 역할 — 그리드 컬럼 정의
import type { GridColumn } from "@/types/grid";
// 역할 — 그리드 잠금 규칙
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 공통 안내 문구
import { MES } from "@/shell/messages";
// 역할 — 입력유형별 라디오·숫자·문자 판정
import { htmlFormInputLayout, type HtmlFormItem } from "@/api/docs/htmlFormApi";
// 역할 — 지면 메타 항목(제목·부제·캡션) 제외 · 지면 props · 기록 표 행 타입
import {
  fillBlankItemJudges,
  fillBlankLogJudges,
  isFixedLabelRow,
  paperBodyItems,
  type HtmlFormLogRow,
  type HtmlFormPaperProps,
  type HtmlFormPassRow,
} from "@/components/form/htmlFormPaperShared";
// 역할 — 일자 YYYYMMDD ↔ input[type=date] · 오늘
import { toInputDate, todayYmd } from "@/lib/docDateTime";

/** 결재 여부 3단계 — 화면 표시 단위 */
export type SendState = "wait" | "sent" | "done";

/** 3단계 문구 — 그리드 code 컬럼 codeMap·검색 콤보 */
export const SEND_STATE_NM: Record<SendState, string> = {
  wait: "전송대기",
  sent: "전송",
  done: "결재완료",
};

/** 3단계 배지 색 — 전송대기 회색, 전송 파랑, 결재완료 초록 */
export const SEND_STATE_BADGE = { wait: "gray", sent: "blue", done: "green" } as const;

/** BE saveAutoIfNg 가 체크만으로 CA 를 남길 때 넣는 문구. 지면 이탈내용에는 안 보여 준다 */
export const AUTO_DEVIATION_DESC = "자동생성: 부적합이 감지되었습니다. 조치 내용을 입력·보완하세요.";

/** 자동문구면 빈 칸 — 이탈 시그널(체크)은 호출측이 raw 값으로 판정한다 */
function paperNote(s: string): string {
  return s.trim() === AUTO_DEVIATION_DESC ? "" : s;
}

/** 양식 미선택 표시 — 행 추가 직후 양식코드가 비어 있을 때 */
export const TMPL_NOT_SELECTED_NM = "미선택";

/**
 * 개발자: 박승우
 * 일자: 2026-09-02
 * 코멘트:
 *   1) 반려(RJT) 행을 노란색으로 칠할 클래스명을 준다
 *   2) 작성 목록·결재 첨부 목록이 호출한다
 *   3) 배지(전송대기)로는 반려를 못 가리므로 행 색으로 구분한다
 */
export function draftRejectedRowClass(
  // DOC_STATUS 원본
  status: string | null | undefined,
): string | undefined {
  return (status ?? "").trim().toUpperCase() === "RJT" ? "mes-row-rejected" : undefined;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) DOC_STATUS 원본을 화면 3단계로 묶는다
 *   2) 목록 행 변환과 버튼 활성 판정이 호출한다
 *   3) 저장 전(status 없음)은 전송대기로 본다. 구 TMP 도 전송대기
 */
export function sendStateOf(
  // DOC_STATUS — WRK/RJT/REQ/APV/TMP. 저장 전이면 null
  status: string | null | undefined,
): SendState {
  const st = (status ?? "").trim().toUpperCase();
  // 승인완료일 때(= 결재가 끝남) 이 화면에서는 아무것도 못 한다
  if (st === "APV") return "done";
  // 승인요청일 때(= 이미 상신됨) 전송으로 묶는다
  if (st === "REQ") return "sent";
  // 그 밖(작성중·반려·임시·저장 전)은 전송대기
  return "wait";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 수정(U)·삭제(D) 가능 여부를 한곳에서 정한다
 *   2) 저장·삭제 판정이 호출한다
 *   3) 전송대기일 때만 true. 전송 이후는 전송취소가 먼저다
 */
export function canModifyDoc(
  // DOC_STATUS 원본
  status: string | null | undefined,
): boolean {
  return sendStateOf(status) === "wait";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 오른쪽 상세 작성 영역을 편집할 수 있는지 정한다
 *   2) 지면 locked·editable 과 우측 저장 버튼이 호출한다
 *   3) 저장 전 신규 행(docIdx 없음)은 편집 불가 — 왼쪽 기본정보를 먼저 저장해야 한다
 */
export function canEditDetail(
  // 저장된 문서 idx — 신규 draft 는 null
  docIdx: number | null | undefined,
  // DOC_STATUS 원본
  status: string | null | undefined,
  // 화면 쓰기·수정 권한 합
  canWriteOrModify: boolean,
): boolean {
  return !!docIdx && canModifyDoc(status) && canWriteOrModify;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 전송(상신) 가능 여부를 정한다
 *   2) 전송·모두 전송 버튼 활성 판정이 호출한다
 *   3) 저장된 문서이고 전송대기일 때만 true
 */
export function canSendDoc(
  // 저장된 문서 idx — 신규 draft 는 null
  docIdx: number | null | undefined,
  // DOC_STATUS 원본
  status: string | null | undefined,
): boolean {
  return !!docIdx && sendStateOf(status) === "wait";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 전송취소 가능 여부를 정한다
 *   2) 전송취소 버튼 활성 판정이 호출한다
 *   3) REQ 만 true — 승인이 들어가면 결재 SP 가 거부하므로 버튼을 열지 않는다
 */
export function canCancelSendDoc(
  // 저장된 문서 idx
  docIdx: number | null | undefined,
  // DOC_STATUS 원본
  status: string | null | undefined,
): boolean {
  return !!docIdx && (status ?? "").trim().toUpperCase() === "REQ";
}

/** 좌측 그리드 행 — 서버 목록 + 신규 draft */
export type HtmlFormDraftRowView = {
  docIdx?: number | null;
  docNo?: string;
  tmplCd?: string;
  tmplNm?: string;
  // 일자 표시용 YYYY-MM-DD
  baseDtDisp?: string;
  writerNm?: string;
  // 3단계 상태 키 — codeMap 이 문구로 바꾼다
  sendState?: SendState;
  // DOC_STATUS 원본 — 반려 행 노란 표시에 쓴다
  status?: string;
  // 식별 제목 — tbl_document.title. 언제·무엇을 썼는지 목록에서만 쓴다. 지면 제목이 아니다
  title?: string;
  /** 이탈여부 Y/N — 이탈 칸을 쓰는 화면(HWP)만 채운다 */
  deviationYn?: string;
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 일자는 전송대기 행에서 셀 편집한다. 양식코드는 팝업 전용이라 셀 입력을 막는다
 *   2) useGridAccess 에 넘긴다
 *   3) 전송 이후 행은 행을 잠근다. 제목만 화이트리스트로 연다
 */
export const htmlFormDraftGridRules: ScreenGridRules = {
  // 팝업·업무상태로만 정해지는 칸 — 셀에서 절대 못 고친다
  alwaysReadonly: ["tmplNm", "writerNm", "sendState", "docNo"],
  // 저장 후에도 바꿀 수 없는 칸 — 양식코드는 팝업(canOpenPopup 이 저장행을 막는다)
  newOnly: ["tmplCd"],
  // 전송·결재완료 행은 통째로 잠근다. 제목만 예외
  isRowEditLocked: (row) => (row as { sendState?: SendState }).sendState !== "wait",
  // 식별 제목 = tbl_document.title. 지면·결재 헤더에 안 실린다. 상태와 무관
  editableWhenLocked: ["title"],
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 좌측 목록 컬럼을 만든다 — 결재 여부·일자·양식코드·양식명·작성자 순서
 *   2) 공통 화면이 useMemo 로 호출한다. 맨 앞 체크박스는 MesEditableGrid selectable 이 그린다
 *   3) 양식코드는 직접 입력하지 않는다. 셀 버튼이 양식 선택 팝업을 연다
 */
export function buildDraftListColumns(
  // 양식코드 셀 버튼 클릭 — 그 행의 양식 선택 팝업을 연다
  onPickForm: (row: HtmlFormDraftRowView) => void,
  // 이탈여부 칸 노출 — 지면이 없어 시그널을 목록에 두는 화면(HWP)만 켠다
  showDeviation = false,
): GridColumn<HtmlFormDraftRowView>[] {
  return [
    {
      // 결재 여부 — 전송대기/전송/결재완료 3단계. 사용자가 바꿀 수 없고 업무 상태가 정한다
      field: "sendState",
      header: "결재 여부",
      width: 96,
      type: "code",
      editable: false,
      codeMap: SEND_STATE_NM,
      badge: SEND_STATE_BADGE,
    },
    {
      // 일자 — 행 추가 시 오늘 날짜. 전송대기 행에서 셀 편집(isRowEditLocked 가 sent/done 을 잠근다)
      field: "baseDtDisp",
      header: "일자",
      width: 110,
      type: "date",
      editable: true,
      required: true,
    },
    {
      // 양식코드 — 직접 입력 금지. 버튼을 누르면 양식 선택 팝업이 열린다
      // 값이 비었을 때(= 아직 안 고름) codeMap 이 「미선택」으로 보여 준다
      field: "tmplCd",
      header: "양식코드",
      width: 150,
      type: "code",
      editable: false,
      codeMap: { "": TMPL_NOT_SELECTED_NM },
      cellButton: { title: "양식 선택", onClick: onPickForm },
    },
    {
      // 양식명 — 팝업에서 양식코드와 함께 채워진다
      field: "tmplNm",
      header: "양식명",
      width: 160,
      type: "code",
      editable: false,
      codeMap: { "": TMPL_NOT_SELECTED_NM },
    },
    {
      // 작성자 — 행 추가는 로그인 사용자, 저장 후에는 tbl_document.writer_id 의 사용자명
      field: "writerNm",
      header: "작성자",
      width: 90,
      editable: false,
    },
    {
      // 식별 제목 — 언제·무엇을 썼는지. 지면 제목(양식 hdr-title)과 다르다. 언제든 고친다
      field: "title",
      header: "제목",
      width: 160,
      type: "text",
      editable: true,
      maxLength: 300,
    },
    // 이탈여부 — HTML 5화면은 지면 하단 시그널이 같은 일을 한다. 두 곳에 두지 않는다
    ...(showDeviation ? [{
      /**
       * 이탈여부 — 켜면 저장 때 개선조치 행을 만들고 이탈·개선조치 화면에 올린다.
       * 전송 이후 행은 htmlFormDraftGridRules 가 행 전체를 잠근다.
       */
      field: "deviationYn" as const,
      header: "이탈여부",
      width: 84,
      type: "checkbox" as const,
      editable: true,
    }] : []),
  ];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 전송(상신) 직전 필수값을 검사한다. 저장(전송대기)에서는 호출하지 않는다
 *   2) 전송·모두 전송이 호출한다. 통과면 null, 아니면 안내 문구
 *   3) 현재 기준은 「모든 입력 항목 필수」다. 기준이 바뀌면 이 함수만 고친다
 *      (예: 항목별 required 플래그가 생기면 아래 for 문 조건만 교체) — HYG·CCP 가 같이 바뀐다
 */
export function validateForTransfer(
  // 일자 YYYYMMDD
  baseKey: string,
  // 지면 항목 전체 — 제목·부제 메타 포함
  items: HtmlFormItem[],
  // 기록 표 행 — CCP 모니터링일지 작성만 채워 온다. 있으면 이쪽이 사용자 입력이다
  logRows?: HtmlFormLogRow[],
  // 항목형 지면인지 — HWP 문서형은 false. 자세한 것은 firstInvalidTarget
  itemPaper = true,
  // 금속 제품통과표 — 있으면 품명을 본다
  passRows?: HtmlFormPassRow[],
): string | null {
  return firstInvalidTarget(baseKey, items, logRows, itemPaper, passRows)?.message ?? null;
}

/** 전송을 막은 첫 자리 — 문구와 그 자리를 함께 준다 */
export interface TransferBlock {
  // 사용자에게 보일 문구
  message: string;
  // 항목형 지면에서 막힌 항목 코드 — 기록 표 화면이면 없다
  itemCd?: string;
  // 기록 표에서 막힌 행의 rowSeq — 항목형이면 없다. 지면이 phase 로 갈라 그려서 배열 위치로는 못 찾는다
  logRowSeq?: number;
  // 금속 제품통과표에서 막힌 행의 rowSeq — data-pass-seq 와 짝
  passRowSeq?: number;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 전송을 막은 첫 자리를 문구와 함께 돌려준다 — validateForTransfer 는 문구만 꺼내 쓴다
 *   2) 작성 화면이 그 칸으로 스크롤·포커스할 때 호출한다
 *   3) 막을 것이 없으면 null
 *
 * 문구만 띄우면 항목이 수십 개인 지면에서 어느 칸인지 사람이 찾아야 한다.
 * 실제로 「빈칸 술래잡기」가 됐다는 현장 보고가 있어 자리까지 같이 준다.
 */
export function firstInvalidTarget(
  // 일자 YYYYMMDD
  baseKey: string,
  // 지면 항목 전체 — 제목·부제 메타 포함
  items: HtmlFormItem[],
  // 기록 표 행 — CCP 모니터링일지 작성만 채워 온다
  logRows?: HtmlFormLogRow[],
  /*
   * 항목형 지면인지 — 기본 true.
   *
   * HWP 문서형(`hwp-write`)은 본문이 rhwp 파일이라 점검 항목이 **원래 없다**.
   * 그런데 항목형과 같은 규칙을 태우면 「점검 행이 없습니다」로 전송이 막힌다.
   * 그래서 운영에서 HWP 문서가 한 건도 전송된 적이 없었다 — 전부 작성중으로 남았다.
   * 문서형은 일자만 본다.
   */
  itemPaper = true,
  // 금속 제품통과표 — 감도 검사가 끝난 뒤 품명을 본다
  passRows?: HtmlFormPassRow[],
): TransferBlock | null {
  if (!/^\d{8}$/.test(baseKey)) return { message: MES.required("일자") };
  // 문서형일 때(= HWP) 볼 항목이 없다. 일자만 맞으면 전송한다
  if (!itemPaper) return null;
  // 기록 표가 있는 화면일 때(= CCP 모니터링) items 는 한계기준·주기·방법 안내문이라 입력값이 아니다.
  // 사용자가 채우는 곳은 기록 표뿐이므로 그 행만 본다
  if (logRows && logRows.length > 0) {
    // 금속은 통과표가 있다. 포장·가열만 온도(cells.temp)를 본다
    return firstInvalidLogRow(logRows, !passRows?.length) ?? firstInvalidPassRow(passRows);
  }
  const body = paperBodyItems(items);
  if (body.length === 0) return { message: "점검 행이 없습니다." };
  for (const item of body) {
    const layout = htmlFormInputLayout(item.inputType);
    const label = (item.itemNm || item.itemCd || "점검항목").trim();
    // 라디오 칸이 있을 때(= 예/아니오 판정 항목) 판정이 비면 전송 불가
    if (layout.radio && !String(item.yn ?? "").trim()) {
      return { message: MES.required(label), itemCd: item.itemCd };
    }
    // 값 칸이 있을 때(= 숫자·문자 입력 항목) 값이 비면 전송 불가
    if (layout.valueCell && !String(item.valNm ?? "").trim()) {
      return { message: MES.required(label), itemCd: item.itemCd };
    }
  }
  return null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-01
 * 코멘트:
 *   1) 기록 표(CCP 포장·가열·금속검출)의 전송 필수값을 본다
 *   2) validateForTransfer 가 기록 표가 있는 화면에서만 호출한다
 *   3) 시각·판정은 공통. 품명은 구간 첫 줄이 라벨이라 비어 있는 게 정상이다.
 *      포장·가열은 온도(cells.temp)도 필수. 금속검출 칸은 해당 없음 열이 있어 값 유무로 막지 않는다
 */
function firstInvalidLogRow(
  // rows: 기록 표 전체 행
  rows: HtmlFormLogRow[],
  // 포장·가열일 때 true. 금속은 온도 칸이 없다
  requireTemp: boolean,
): TransferBlock | null {
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i];
    const where = `${i + 1}번째 기록 행`;
    if (!String(row.checkTime ?? "").trim()) {
      return { message: `${where}의 시각을 입력하세요.`, logRowSeq: row.rowSeq };
    }
    if (!String(row.judgeCd ?? "").trim()) {
      return { message: `${where}의 판정을 선택하세요.`, logRowSeq: row.rowSeq };
    }
    if (requireTemp && !String(row.cells?.temp ?? "").trim()) {
      return { message: `${where}의 온도를 입력하세요.`, logRowSeq: row.rowSeq };
    }
    /*
     * 품명은 **사람이 더한 행에서만** 필수다.
     *
     * 영역 첫 줄(작업 전·작업 종료)은 고정 라벨 행이라 화면이 품명 자리에 라벨을 대신 그린다.
     * 그 행에 품명을 요구하면 아무도 채울 수 없는 칸으로 전송이 막힌다.
     * isFixedLabelRow 로 가른다 — 지면이 그 행을 라벨로 그리는 규칙과 같은 함수다.
     */
    if (!isFixedLabelRow(rows, row) && !String(row.productNm ?? "").trim()) {
      return { message: `${where}의 품명을 입력하세요.`, logRowSeq: row.rowSeq };
    }
  }
  return null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-29
 * 코멘트:
 *   1) 금속 제품통과표 품명을 본다. 감도 라벨 행은 품명 칸이 없어 여기로 온다
 *   2) firstInvalidTarget 이 기록 표 통과 뒤에 호출한다
 *   3) 첫 줄은 항상 필수. 나머지 시드 빈 줄은 건너뛴다. 통과량·검출량·비고를 쓴 줄은 품명도 필수
 */
function firstInvalidPassRow(
  // 제품통과표. 없으면(= 포장·가열) 볼 칸이 없다
  rows?: HtmlFormPassRow[],
): TransferBlock | null {
  if (!rows?.length) return null;
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i];
    const used = [row.productNm, row.passQty, row.detectQty, row.remark]
      .some((v) => String(v ?? "").trim());
    // 둘째 줄부터 전부 비었을 때(= 시드 빈 줄) 품명을 요구하지 않는다
    if (!used && i > 0) continue;
    if (!String(row.productNm ?? "").trim()) {
      return { message: `${i + 1}번째 통과 행의 품명을 입력하세요.`, passRowSeq: row.rowSeq };
    }
  }
  return null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 문자열 정규화 — SP 가 null 을 주는 칸이 있다
 *   2) detailToBuf 가 헤더 칸마다 호출한다
 *   3) null·undefined 는 빈 문자열
 */
function asText(value: unknown): string {
  return value == null ? "" : String(value);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) Y/N 정규화 — 서명 스냅샷 여부
 *   2) detailToBuf 가 서명 칸마다 호출한다
 *   3) 대소문자·공백을 흡수하고 Y 가 아니면 N
 */
function asYn(value: unknown): string {
  return String(value ?? "").trim().toUpperCase() === "Y" ? "Y" : "N";
}

/**
 * 지면 편집 버퍼 — 문서 1건.
 * 작성 화면(HtmlFormDraftPage)과 결재 미리보기(HtmlDocumentPreview)가 같은 모양을 쓴다.
 */
export type HtmlFormDraftBuf = {
  docIdx: number | null;
  docNo: string;
  tmplCd: string;
  tmplNm: string;
  status: string | null;
  baseKey: string;
  writerNm: string;
  writerId: string;
  writerSignYn: string;
  checkerNm: string;
  checkerId: string;
  checkerSignYn: string;
  approverNm: string;
  approverId: string;
  approverSignYn: string;
  verNo: number;
  items: HtmlFormItem[];
  specialNote: string;
  improveNote: string;
  actionNm: string;
  confirmNm: string;
  confirmId: string;
  confirmSignYn: string;
  // 이탈·개선조치 문서 표시 — 사용자가 직접 켠 값. 근거가 있으면 화면이 자동으로 켠다
  deviationYn: boolean;
  // 기록 표 행 — CCP 모니터링일지 작성만 쓴다. 다른 화면은 빈 배열이다
  logRows: HtmlFormLogRow[];
  // 금속검출 통과량 표 행 — MTL 만
  passRows: HtmlFormPassRow[];
};

/** 상세 API 응답 최소 모양 — 화면별 api 가 이 형태로 맞춰 준다 */
export interface HtmlFormDraftDetailLike {
  header: Record<string, unknown> | null;
  items: HtmlFormItem[];
  logRows?: HtmlFormLogRow[];
  passRows?: HtmlFormPassRow[];
  // 이탈·개선조치 — 있으면 시그널 체크를 복원한다
  corrective?: { deviationDesc?: string | null; actionDesc?: string | null } | null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 양식 미선택 신규 행의 빈 버퍼를 만든다 — 일자만 오늘로 찍는다
 *   2) 행 추가가 호출한다
 *   3) 팝업에서 양식을 고르면 그 양식 상세로 교체된다
 */
export function emptyDraftBuf(
  // 로그인 사용자 — 작성자·점검자 기본값
  user?: { userNm?: string; userId?: string } | null,
): HtmlFormDraftBuf {
  return {
    docIdx: null, docNo: "", tmplCd: "", tmplNm: "", status: null,
    baseKey: todayYmd(),
    writerNm: user?.userNm ?? "", writerId: user?.userId ?? "", writerSignYn: "N",
    checkerNm: user?.userNm ?? "", checkerId: "", checkerSignYn: "N",
    approverNm: "", approverId: "", approverSignYn: "N",
    verNo: 0, items: [],
    specialNote: "", improveNote: "", actionNm: "", confirmNm: "",
    confirmId: "", confirmSignYn: "N",
    deviationYn: false,
    logRows: [], passRows: [],
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 상세 API 응답을 지면 편집 버퍼로 옮긴다
 *   2) 작성 화면의 행 선택·양식 선택·저장 후 재적재, 결재 미리보기의 최초 적재가 호출한다
 *   3) 작성자 이름이 비면 로그인 사용자, 점검자가 비면 작성자명. 자동생성 이탈문구는 칸을 비우고 체크만 켠다
 */
export function detailToDraftBuf(
  // 상세 API 응답 — header·items
  detail: HtmlFormDraftDetailLike,
  // 신규일 때 채울 양식코드·양식명
  form: { tmplCd: string; tmplNm: string },
  // 로그인 사용자 — 이름 기본값. 미리보기는 넘기지 않는다(문서에 남은 이름만 쓴다)
  user?: { userNm?: string; userId?: string } | null,
): HtmlFormDraftBuf {
  const header = detail.header ?? {};
  const docIdx = Number(header.docIdx) || null;
  /*
   * 아직 저장 안 한 문서(= 신규)는 판정을 **적합으로 깔고 시작한다.**
   * 현장 기록은 대부분이 적합이라, 빈 값으로 두면 행마다 라디오를 한 번씩
   * 더 눌러야 한다. 부적합만 눌러 고치면 된다.
   *
   * 저장된 문서는 건드리지 않는다 — 사람이 비워 둔 「미판정」을 덮으면
   * 안 본 것을 봤다고 기록하는 셈이다.
   */
  /*
   * 금속검출도 이제 다른 화면과 같다.
   *
   * 예전에는 여기서 금속검출만 뺐다 — 서버가 감도 5칸으로 판정을 계산해서
   * 화면이 미리 적합으로 칠하면 저장하는 순간 뒤집혔기 때문이다.
   * 그 자동 판정을 걷어냈다(sp_tbl_ccp_metal_monitor_c_000). 판정은 사람이 정한 값이 그대로 남는다.
   */
  /*
   * **비어 있는 판정만** 적합으로 채운다. 이미 정해진 판정은 안 건드린다 —
   * 저장해 둔 부적합을 적합으로 덮으면 사람이 남긴 판정을 지우는 셈이다.
   *
   * docIdx 로 「신규」를 가르지 않는다. 작성 화면은 좌측을 먼저 저장해야
   * 우측 지면이 열려서, 지면을 처음 여는 시점에는 이미 docIdx 가 있다.
   * 빈 판정은 어차피 전송이 막히는 미완성 상태다(validateForTransfer).
   */
  const items = fillBlankItemJudges(detail.items ?? []);
  const logRows = fillBlankLogJudges(detail.logRows ?? []);
  const ca = detail.corrective;
  const rawNote = asText(header.specialNote);
  const hasCa = !!(String(ca?.deviationDesc ?? "").trim() || String(ca?.actionDesc ?? "").trim());
  const hasFailLog = logRows.some((row) => String(row.judgeCd ?? "").toUpperCase() === "F");
  // 작성자 — 문서 헤더, 없으면 로그인 사용자(작성 화면 신규)
  const writerNm = asText(header.writerNm) || user?.userNm || "";
  return {
    docIdx,
    docNo: asText(header.docNo),
    tmplCd: asText(header.tmplCd) || form.tmplCd,
    tmplNm: asText(header.tmplNm) || form.tmplNm,
    status: asText(header.status) || null,
    baseKey: asText(header.baseDt) || todayYmd(),
    writerNm,
    writerId: asText(header.writerId) || user?.userId || "",
    writerSignYn: asYn(header.writerSignYn),
    // 점검자 칸이 비었을 때(= 작성자가 안 채움·CCP mngNm 없음) 작성자명을 넣는다
    checkerNm: asText(header.checkerNm) || writerNm,
    checkerId: asText(header.checkerId),
    checkerSignYn: asYn(header.checkerSignYn),
    approverNm: asText(header.approverNm),
    approverId: asText(header.approverId),
    approverSignYn: asYn(header.approverSignYn),
    verNo: Number(header.verNo) || 0,
    items,
    specialNote: paperNote(rawNote),
    improveNote: asText(header.improveNote),
    actionNm: asText(header.actionNm),
    confirmNm: asText(header.confirmNm),
    confirmId: asText(header.confirmId),
    confirmSignYn: asYn(header.confirmSignYn),
    // CA·푸터·부적합 행이 있으면 시그널을 켠다. 저장한 Y 도 헤더에서 복원한다
    deviationYn: hasCa
      || !!asText(header.specialNote)
      || !!asText(header.improveNote)
      || hasFailLog
      || asYn(header.deviationYn) === "Y",
    // 기록행 — CCP 모니터링일지만 채워 온다. 나머지 화면은 빈 배열
    logRows,
    passRows: detail.passRows ?? [],
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 버퍼에서 지면 표시 props(header·items·footer·기록행)만 뽑는다
 *   2) 작성 화면과 결재 미리보기가 같은 값을 그리도록 한 곳에서 만든다
 *   3) onChange 계열은 넣지 않는다 — 편집 동작은 호출측이 붙인다
 */
export function draftPaperViewProps(
  // 열린 문서 버퍼
  buf: HtmlFormDraftBuf,
  // 양식명이 없을 때 쓸 지면 제목·부제
  meta: { paperTitle: string; paperSubtitle: string },
): Pick<HtmlFormPaperProps, "header" | "items" | "footer" | "logRows" | "passRows"> {
  return {
    // 제목·부제·일자·결재란. 서명이 있으면 이미지, 없으면 이름
    header: {
      // 지면 제목 fallback — 양식명. hdr-title 이 있으면 PaperTitleCell 이 그걸 쓴다.
      // 작성 목록 title 은 식별용이라 넣지 않는다
      title: buf.tmplNm || meta.paperTitle,
      subtitle: meta.paperSubtitle,
      baseDt: toInputDate(buf.baseKey),
      writerNm: buf.writerNm,
      writerId: buf.writerId,
      writerSignYn: buf.writerSignYn,
      checkerNm: buf.checkerNm,
      checkerId: buf.checkerId,
      checkerSignYn: buf.checkerSignYn,
      approverNm: buf.approverNm,
      approverId: buf.approverId,
      approverSignYn: buf.approverSignYn,
      confirmId: buf.confirmId,
      confirmSignYn: buf.confirmSignYn,
    },
    // 점검 행 — 예/아니오·숫자·문자
    items: buf.items,
    // 하단 4열 — 특이사항·개선조치 및 결과·조치·확인
    footer: {
      specialNote: buf.specialNote,
      improveNote: buf.improveNote,
      actionNm: buf.actionNm,
      confirmNm: buf.confirmNm,
    },
    // 기록 표 행 — CCP 모니터링일지만 값이 있다
    logRows: buf.logRows,
    passRows: buf.passRows,
  };
}
