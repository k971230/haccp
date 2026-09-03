/**
 * DocumentApprovalToolbar — 문서·일지 상세 공통 결재 버튼.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 화면 성격과 문서 상태에 따라 지금 할 수 있는 결재 행위만 버튼으로 낸다
 *      작성·결재첨부: 전송·전송취소 / 결재 대기·완료: 승인·취소·반려
 *   2) 사유가 필요한 반려·결재취소는 ReasonAction 팝업을 연다. 한 줄 input 을 헤더에 두지 않는다
 *   3) 라벨은 버튼에 하드코딩한다 (전송·전송취소·승인·반려·취소). APPR_ACTION 코드는 API 값이다
 *
 * PIPELINE[HF103] 문서 결재 툴바
 * PIPELINE[HF82, HF102] 연관 모듈
 */
// 역할 — 표준 버튼
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 확인·토스트
import { mesConfirm, mesToast } from "@/shell/dialog";
// 역할 — 오류 문구
import { mesError } from "@/shell/errors";
// 역할 — 결재 API
import { processDocumentApproval } from "@/api/documentApi";
// 역할 — 문서상태 코드 상수
import { DOC_STATUS } from "@/lib/docStatus";
// 역할 — 공통코드 라벨
import { useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — 사유 팝업
import { useModalStore } from "@/stores/modalStore";

export type ApprovalAction = "REQUEST" | "CANCEL" | "APPROVE" | "REJECT" | "UNDO";

export interface DocumentApprovalToolbarProps {
  // 저장 후 부여된 문서 idx — 없으면 결재 버튼 숨김
  docIdx: number | null | undefined;
  // 문서 상태 WRK/REQ/APV/RJT
  status?: string | null;
  // 저장 버튼 노출·핸들러
  onSave?: () => void;
  // 저장 가능
  canSave?: boolean;
  // 결재 가능 (수정 권한 등)
  canApprove?: boolean;
  // 저장 busy
  saveBusy?: boolean;
  // 결재 busy
  approvalBusy?: boolean;
  // 결재 성공 후 재조회
  onApproved?: () => void;
  // 상태 표시 텍스트 (이미 코드 라벨이면 그대로)
  statusLabel?: string;
  // 상태·문서번호 배지 노출 — 기본 true. 문서작성은 우측 요약에만 둘 때 false
  showStatus?: boolean;
  /**
   * true면 작성자 화면용 — 상신·상신취소만 노출.
   * 승인·반려는 결재 대기(sign-ready)에서 처리한다.
   */
  writerActionsOnly?: boolean;
  /**
   * true면 결재 완료(sign-ok) 화면용 — 본인이 처리한 결재를 되돌리는 「취소」만 노출한다.
   * 실제 취소 가능 여부(뒷 단계가 이미 처리됐는지)는 SP 가 다시 검증한다.
   */
  approverUndo?: boolean;
  /**
   * 전송(REQUEST) 직전 검사 — false 를 반환하면 확인 창을 열지 않는다.
   * 결재첨부가 지면 필수값(validateForTransfer)을 여기서 본다.
   */
  onBeforeAction?: (actionCd: ApprovalAction) => Promise<boolean | void> | boolean | void;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 상태별로 가능한 결재 행위만 버튼으로 보여 준다
 *   2) 문서함 상세 헤더 오른쪽·일지 상세에서 호출한다
 *   3) 반려·결재취소 시 팝업에서 사유를 받는다. 비면 API를 호출하지 않는다
 */
export function DocumentApprovalToolbar({
  docIdx,
  status,
  onSave,
  canSave = false,
  canApprove = false,
  saveBusy = false,
  approvalBusy = false,
  onApproved,
  statusLabel,
  showStatus = true,
  writerActionsOnly = false,
  approverUndo = false,
  onBeforeAction,
}: DocumentApprovalToolbarProps) {
  const { label: statusNm } = useCommonCodes("DOC_STATUS");
  const openModal = useModalStore((s) => s.openModal);

  const run = async (actionCd: ApprovalAction, opinion?: string) => {
    if (!docIdx) return mesToast("먼저 문서를 저장하세요.", "warn");
    if (!canApprove) return mesToast("결재 권한이 없습니다.", "warn");
    if (actionCd === "REJECT" && !opinion?.trim()) {
      return mesToast("반려 사유를 입력하세요.", "warn");
    }
    if (actionCd === "UNDO" && !opinion?.trim()) {
      return mesToast("취소 사유를 입력하세요.", "warn");
    }
    if (onBeforeAction) {
      const ok = await onBeforeAction(actionCd);
      if (ok === false) return;
    }
    // 사유 팝업이 이미 확인이다. 전송·승인만 한 번 더 묻는다
    if (actionCd !== "REJECT" && actionCd !== "UNDO") {
      const msg =
        actionCd === "REQUEST" ? "전송하시겠습니까?\n전송 후에는 첨부와 내용을 고칠 수 없습니다."
          : actionCd === "CANCEL" ? "전송을 취소하시겠습니까?\n전송대기로 돌아가 다시 고칠 수 있습니다."
            : "승인하시겠습니까?";
      if (!(await mesConfirm(msg))) return;
    }
    try {
      await processDocumentApproval({
        docIdx,
        actionCd,
        // 반려·결재취소는 사유 필수. 취소 사유는 감사 이력에 남긴다
        opinion: actionCd === "REJECT" || actionCd === "UNDO" ? opinion?.trim() || undefined : undefined,
      });
      mesToast(
        actionCd === "UNDO" ? "결재를 취소했습니다. 문서가 이전 결재 단계로 돌아갔습니다."
          : actionCd === "REQUEST" ? "전송했습니다."
          : actionCd === "CANCEL" ? "전송을 취소했습니다."
            : actionCd === "REJECT" ? "반려했습니다."
              : "승인했습니다.",
        "success",
      );
      onApproved?.();
    } catch (error) {
      mesError(error);
      throw error;
    }
  };

  const openReason = (actionCd: "REJECT" | "UNDO") => {
    if (!docIdx) return mesToast("먼저 문서를 저장하세요.", "warn");
    if (!canApprove) return mesToast("결재 권한이 없습니다.", "warn");
    const undo = actionCd === "UNDO";
    openModal("ReasonAction", {
      title: undo ? "결재 취소" : "반려",
      // 확인·닫기 — 헤더의 「취소」와 겹치지 않게 한다
      confirmLabel: "확인",
      confirmVariant: undo ? "search" : "danger",
      placeholder: undo ? "결재를 취소하는 이유를 입력하세요" : "반려 사유를 입력하세요",
      onConfirm: (reason) => run(actionCd, reason),
    });
  };

  // 구 TMP는 작성중(WRK)과 동일 취급
  const st = status === DOC_STATUS.TMP || !status ? DOC_STATUS.WRK : status;
  // 작성중·반려 — 상신 가능. 작성·결재첨부 화면이 쓴다
  const showRequest = writerActionsOnly && (st === DOC_STATUS.WRK || st === DOC_STATUS.RJT);
  // 상신(REQ) — 검토 서명 전만 전송취소 가능. 상신한 본인 화면에서만 낸다
  const showCancel = writerActionsOnly && st === DOC_STATUS.REQ;
  const showApprove = !writerActionsOnly && !approverUndo && st === DOC_STATUS.REQ;
  const showReject = !writerActionsOnly && !approverUndo && st === DOC_STATUS.REQ;
  // 취소 — 본인이 찍은 결재를 되돌린다. 결재 대기·결재 완료 두 화면이 같이 쓴다
  const showUndo = (approverUndo || !writerActionsOnly) && (st === DOC_STATUS.APV || st === DOC_STATUS.RJT);
  // 공통코드에 남은 임시저장 라벨을 WRK에서 쓰지 않는다
  const displayStatus = statusLabel
    || (st === DOC_STATUS.WRK ? "작성중" : statusNm(st, st));

  return (
    <div className="flex flex-wrap items-center gap-2">
      {showStatus ? (
        <span className="text-xs text-slate-600">
          상태: <b className="text-slate-800">{displayStatus}</b>
        </span>
      ) : null}
      {onSave && (
        <MesButton
          // 변경 내용 저장
          variant="save"
          disabled={!canSave || saveBusy}
          onClick={onSave}
        >
          저장
        </MesButton>
      )}
      {docIdx && canApprove && showRequest && (
        <MesButton
          // 전송(REQUEST) — 결재 프로세스 시작. 이후 첨부·본문 잠금
          variant="primary"
          icon="approve"
          disabled={approvalBusy}
          onClick={() => void run("REQUEST")}
        >
          전송
        </MesButton>
      )}
      {docIdx && canApprove && showCancel && (
        <MesButton
          // 전송취소(CANCEL) — 전송대기로 되돌린다. 승인이 들어가면 SP 가 막는다
          variant="secondary"
          icon="reset"
          disabled={approvalBusy}
          onClick={() => void run("CANCEL")}
        >
          전송취소
        </MesButton>
      )}
      {docIdx && canApprove && showApprove && (
        <MesButton
          // 승인(APPROVE) — 지정 결재자. 마지막 단계면 APV
          variant="primary"
          disabled={approvalBusy}
          onClick={() => void run("APPROVE")}
        >
          승인
        </MesButton>
      )}
      {docIdx && canApprove && showUndo && (
        <MesButton
          // 본인 결재 되돌리기 — 사유는 팝업에서 받는다. 다음 결재자가 처리했으면 SP 가 막는다
          variant="search"
          icon="reset"
          disabled={approvalBusy}
          onClick={() => openReason("UNDO")}
        >
          취소
        </MesButton>
      )}
      {docIdx && canApprove && showReject && (
        <MesButton
          // 반려 — 사유는 팝업에서 받는다
          variant="danger"
          disabled={approvalBusy}
          onClick={() => openReason("REJECT")}
        >
          반려
        </MesButton>
      )}
    </div>
  );
}
