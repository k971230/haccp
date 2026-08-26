/**
 * DocumentApprovalToolbar — 문서·일지 상세 공통 결재 툴바.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 화면 성격과 문서 상태에 따라 지금 할 수 있는 결재 행위만 버튼으로 낸다
 *      작성·결재첨부: 전송·전송취소 / 결재 대기·완료: 승인·취소·반려
 *   2) 문서함과 CCP/일지 상세가 같은 API(processDocumentApproval)를 쓰도록 공통화한다
 *   3) 라벨은 APPR_ACTION 공통코드를 우선하고 없으면 기본 한글을 쓴다
 *
 * PIPELINE[HF103] 문서 결재 툴바
 * PIPELINE[HF82, HF102] 연관 모듈
 */
// 역할 — 상태
import { useState } from "react";
// 역할 — 표준 버튼·입력
import { MesButton } from "@/components/ui/MesButton";
import { Input } from "@/components/ui/Input";
// 역할 — 확인·토스트
import { mesConfirm, mesToast } from "@/shell/dialog";
// 역할 — 오류 문구
import { mesError } from "@/shell/errors";
// 역할 — 결재 API
import { processDocumentApproval } from "@/api/documentApi";
// 역할 — 공통코드 라벨
import { useCommonCodes } from "@/hooks/useCommonCodes";

export type ApprovalAction = "REQUEST" | "CANCEL" | "REVIEW" | "APPROVE" | "REJECT" | "UNDO";

export interface DocumentApprovalToolbarProps {
  // 저장 후 부여된 문서 idx — 없으면 결재 버튼 숨김
  docIdx: number | null | undefined;
  // 문서 상태 WRK/REQ/REV/APV/RJT
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
   * 검토·승인·반려는 결재 대기(sign-ready)에서 처리한다.
   */
  writerActionsOnly?: boolean;
  /**
   * true면 결재 완료(sign-ok) 화면용 — 본인이 처리한 결재를 되돌리는 「취소」만 노출한다.
   * 실제 취소 가능 여부(뒷 단계가 이미 처리됐는지)는 SP 가 다시 검증한다.
   */
  approverUndo?: boolean;
  /**
   * 현재 대기 중인 결재 단계의 역할 — REVIEW 면 검토, APPROVE 면 승인이다.
   * 사용자에게는 둘 다 「승인」 한 버튼으로 보이고, 보내는 행위만 이 값으로 갈린다.
   */
  pendingRoleCd?: string | null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 상태별로 가능한 결재 행위만 버튼으로 보여 준다
 *   2) 일지·문서함 상세 상단에서 호출한다
 *   3) 반려 시 사유 없으면 토스트로 막고 API를 호출하지 않는다
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
  pendingRoleCd,
}: DocumentApprovalToolbarProps) {
  const { label: statusNm } = useCommonCodes("DOC_STATUS");
  // 반려 사유·취소 사유 — 같은 칸을 쓴다. 화면에 둘 중 하나만 뜬다
  const [opinion, setOpinion] = useState("");

  const run = async (actionCd: ApprovalAction) => {
    if (!docIdx) return mesToast("먼저 문서를 저장하세요.", "warn");
    if (!canApprove) return mesToast("결재 권한이 없습니다.", "warn");
    if (actionCd === "REJECT" && !opinion.trim()) {
      return mesToast("반려 사유를 입력하세요.", "warn");
    }
    const msg =
      actionCd === "UNDO" ? "결재를 취소하시겠습니까?\n(다음 결재자가 이미 처리했으면 취소할 수 없습니다.)"
        : actionCd === "REQUEST" ? "결재를 요청(상신)하시겠습니까?"
        : actionCd === "CANCEL" ? "상신을 취소하고 작성중으로 되돌리시겠습니까?\n(검토·승인이 시작되면 취소할 수 없습니다.)"
          : actionCd === "REVIEW" ? "검토 완료 처리하시겠습니까?"
            : actionCd === "APPROVE" ? "승인하시겠습니까?"
              : "반려하시겠습니까?";
    if (!(await mesConfirm(msg))) return;
    try {
      await processDocumentApproval({
        docIdx,
        actionCd,
        // 반려는 사유 필수, 취소는 남기면 감사 이력에 함께 기록된다
        opinion: actionCd === "REJECT" || actionCd === "UNDO" ? opinion.trim() || undefined : undefined,
      });
      mesToast(
        actionCd === "UNDO" ? "결재를 취소했습니다. 문서가 이전 결재 단계로 돌아갔습니다."
          : actionCd === "REQUEST" ? "상신했습니다. 문서는 수정할 수 없습니다."
          : actionCd === "CANCEL" ? "상신을 취소했습니다. 다시 수정할 수 있습니다."
            : actionCd === "REJECT" ? "반려했습니다."
              : "승인했습니다.",
        "success",
      );
      setOpinion("");
      onApproved?.();
    } catch (error) {
      mesError(error);
    }
  };

  // 구 TMP는 작성중(WRK)과 동일 취급
  const st = status === "TMP" || !status ? "WRK" : status;
  // 작성중·반려 — 상신 가능. 작성·결재첨부 화면이 쓴다
  const showRequest = writerActionsOnly && (st === "WRK" || st === "RJT");
  // 상신(REQ) — 검토 서명 전만 전송취소 가능. 상신한 본인 화면에서만 낸다
  const showCancel = writerActionsOnly && st === "REQ";
  /**
   * 결재 대기(sign-ready) — 사용자에게는 「승인」 하나로 보인다.
   * 결재선에 검토 단계가 있으면 그 단계에서는 REVIEW 를, 승인 단계에서는 APPROVE 를 보낸다.
   * 검토·승인을 별도 버튼으로 나누면 결재자가 무엇을 눌러야 하는지 알 수 없다.
   */
  const approveAction: ApprovalAction = pendingRoleCd === "REVIEW" ? "REVIEW" : "APPROVE";
  const showApprove = !writerActionsOnly && !approverUndo && (st === "REQ" || st === "REV");
  const showReject = !writerActionsOnly && !approverUndo && (st === "REQ" || st === "REV");
  // 취소 — 본인이 찍은 결재를 되돌린다. 결재 대기·결재 완료 두 화면이 같이 쓴다
  const showUndo = (approverUndo || !writerActionsOnly) && (st === "REV" || st === "APV" || st === "RJT");
  // 공통코드에 남은 임시저장 라벨을 WRK에서 쓰지 않는다
  const displayStatus = statusLabel
    || (st === "WRK" ? "작성중" : statusNm(st, st));

  return (
    <div className="flex flex-wrap items-center gap-2 rounded border border-slate-200 bg-slate-50 px-3 py-2">
      {showStatus ? (
        <span className="text-xs text-slate-600">
          상태: <b className="text-slate-800">{displayStatus}</b>
        </span>
      ) : null}
      <div className={showStatus ? "ml-auto flex flex-wrap items-center gap-2" : "flex flex-wrap items-center gap-2"}>
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
          <MesButton variant="primary" disabled={approvalBusy} onClick={() => void run("REQUEST")}>
            전송
          </MesButton>
        )}
        {docIdx && canApprove && showCancel && (
          <MesButton variant="secondary" disabled={approvalBusy} onClick={() => void run("CANCEL")}>
            전송취소
          </MesButton>
        )}
        {docIdx && canApprove && showApprove && (
          <MesButton variant="primary" disabled={approvalBusy} onClick={() => void run(approveAction)}>
            승인
          </MesButton>
        )}
        {docIdx && canApprove && showUndo && (
          <>
            <Input
              // 취소 사유 — 남기면 감사 이력에 함께 기록된다. 필수는 아니다
              value={opinion}
              onChange={(e) => setOpinion(e.target.value)}
              placeholder="취소 사유 (선택)"
              className="w-40"
            />
            <MesButton variant="secondary" disabled={approvalBusy} onClick={() => void run("UNDO")}>
              취소
            </MesButton>
          </>
        )}
        {docIdx && canApprove && showReject && (
          <>
            <Input
              // 반려 사유 — REJECT 는 사유가 필수다
              value={opinion}
              onChange={(e) => setOpinion(e.target.value)}
              placeholder="반려 사유"
              className="w-40"
            />
            <MesButton variant="danger" disabled={approvalBusy} onClick={() => void run("REJECT")}>
              반려
            </MesButton>
          </>
        )}
      </div>
    </div>
  );
}
