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
// 역할 — 지면 메타 항목(제목·부제·캡션) 제외 · 기록 표 행 타입
import { paperBodyItems, type HtmlFormLogRow } from "@/components/form/htmlFormPaperShared";

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

/** 양식 미선택 표시 — 행 추가 직후 양식코드가 비어 있을 때 */
export const TMPL_NOT_SELECTED_NM = "미선택";

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) DOC_STATUS 원본을 화면 3단계로 묶는다
 *   2) 목록 행 변환과 버튼 활성 판정이 호출한다
 *   3) 저장 전(status 없음)은 전송대기로 본다. 구 TMP 도 전송대기
 */
export function sendStateOf(
  // DOC_STATUS — WRK/RJT/REQ/REV/APV/TMP. 저장 전이면 null
  status: string | null | undefined,
): SendState {
  const st = (status ?? "").trim().toUpperCase();
  // 승인완료일 때(= 결재가 끝남) 이 화면에서는 아무것도 못 한다
  if (st === "APV") return "done";
  // 검토요청·검토완료일 때(= 이미 상신됨) 전송으로 묶는다
  if (st === "REQ" || st === "REV") return "sent";
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
 *   3) REQ 만 true — 검토 서명이 들어간 REV 는 결재 SP 가 거부하므로 버튼을 열지 않는다
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
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 일자는 전송대기 행에서 셀 편집한다. 양식코드는 팝업 전용이라 셀 입력을 막는다
 *   2) useGridAccess 에 넘긴다
 *   3) 전송 이후 행은 행 전체를 잠근다 — 셀 편집 시도는 토스트로만 안내
 */
export const htmlFormDraftGridRules: ScreenGridRules = {
  // 팝업·업무상태로만 정해지는 칸 — 셀에서 절대 못 고친다
  alwaysReadonly: ["tmplNm", "writerNm", "sendState", "docNo"],
  // 저장 후에도 바꿀 수 없는 칸 — 양식코드는 팝업(canOpenPopup 이 저장행을 막는다)
  newOnly: ["tmplCd"],
  // 전송·결재완료 행은 통째로 잠근다
  isRowEditLocked: (row) => (row as { sendState?: SendState }).sendState !== "wait",
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
): string | null {
  if (!/^\d{8}$/.test(baseKey)) return MES.required("일자");
  // 기록 표가 있는 화면일 때(= CCP 모니터링) items 는 한계기준·주기·방법 안내문이라 입력값이 아니다.
  // 사용자가 채우는 곳은 기록 표뿐이므로 그 행만 본다
  if (logRows && logRows.length > 0) return validateLogRows(logRows);
  const body = paperBodyItems(items);
  if (body.length === 0) return "점검 행이 없습니다.";
  for (const item of body) {
    const layout = htmlFormInputLayout(item.inputType);
    const label = (item.itemNm || item.itemCd || "점검항목").trim();
    // 라디오 칸이 있을 때(= 예/아니오 판정 항목) 판정이 비면 전송 불가
    if (layout.radio && !String(item.yn ?? "").trim()) {
      return MES.required(label);
    }
    // 값 칸이 있을 때(= 숫자·문자 입력 항목) 값이 비면 전송 불가
    if (layout.valueCell && !String(item.valNm ?? "").trim()) {
      return MES.required(label);
    }
  }
  return null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 기록 표(CCP 포장·가열·금속검출)의 전송 필수값을 본다
 *   2) validateForTransfer 가 기록 표가 있는 화면에서만 호출한다
 *   3) 시각·판정만 필수다. 품명은 구간 첫 줄이 라벨이라 비어 있는 게 정상이고,
 *      금속검출 칸은 해당 없음 열이 있어 값 유무로 막지 않는다
 */
function validateLogRows(
  // rows: 기록 표 전체 행
  rows: HtmlFormLogRow[],
): string | null {
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i];
    const where = `${i + 1}번째 기록 행`;
    if (!String(row.checkTime ?? "").trim()) return `${where}의 시각을 입력하세요.`;
    if (!String(row.judgeCd ?? "").trim()) return `${where}의 판정을 선택하세요.`;
  }
  return null;
}
