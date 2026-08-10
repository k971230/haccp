/**
 * DocumentApprovalToolbar — 문서·일지 상세 공통 결재 툴바.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 저장·상신·상신취소·검토·승인·반려를 상태·권한에 따라 한 줄로 제공한다
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

export type ApprovalAction = "REQUEST" | "CANCEL" | "REVIEW" | "APPROVE" | "REJECT";

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
  // 미리보기 핸들러 — 있으면 버튼 노출
  onPreview?: () => void;
  // 작성 화면 열기 — 문서함에서 DB/HWP 편집 화면으로 이동
  onEdit?: () => void;
  /**
   * true면 작성자 화면용 — 상신·상신취소만 노출.
   * 검토·승인·반려는 결재함에서 처리한다.
   */
  writerActionsOnly?: boolean;
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
  onPreview,
  onEdit,
  writerActionsOnly = false,
}: DocumentApprovalToolbarProps) {
  const { label: actionLabel } = useCommonCodes("APPR_ACTION");
  const { label: statusNm } = useCommonCodes("DOC_STATUS");
  const [rejectOpinion, setRejectOpinion] = useState("");

  const run = async (actionCd: ApprovalAction) => {
    if (!docIdx) return mesToast("먼저 문서를 저장하세요.", "warn");
    if (!canApprove) return mesToast("결재 권한이 없습니다.", "warn");
    if (actionCd === "REJECT" && !rejectOpinion.trim()) {
      return mesToast("반려 사유를 입력하세요.", "warn");
    }
    const msg =
      actionCd === "REQUEST" ? "결재를 요청(상신)하시겠습니까?"
        : actionCd === "CANCEL" ? "상신을 취소하고 작성중으로 되돌리시겠습니까?\n(검토·승인이 시작되면 취소할 수 없습니다.)"
          : actionCd === "REVIEW" ? "검토 완료 처리하시겠습니까?"
            : actionCd === "APPROVE" ? "승인하시겠습니까?"
              : "반려하시겠습니까?";
    if (!(await mesConfirm(msg))) return;
    try {
      await processDocumentApproval({
        docIdx,
        actionCd,
        opinion: actionCd === "REJECT" ? rejectOpinion.trim() : undefined,
      });
      mesToast(
        actionCd === "REQUEST" ? "상신했습니다. 문서는 수정할 수 없습니다."
          : actionCd === "CANCEL" ? "상신을 취소했습니다. 다시 수정할 수 있습니다."
            : `${actionLabel(actionCd, actionCd)} 처리했습니다.`,
        "success",
      );
      setRejectOpinion("");
      onApproved?.();
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  };

  // 구 TMP는 작성중(WRK)과 동일 취급
  const st = status === "TMP" || !status ? "WRK" : status;
  // 작성중·반려 — 상신 가능
  const showRequest = st === "WRK" || st === "RJT";
  // 상신(REQ) — 검토 서명 전만 취소 가능 (REV 이후는 숨김)
  const showCancel = st === "REQ";
  // 결재함용 — 작성 화면(writerActionsOnly)에서는 숨김
  const showReview = !writerActionsOnly && st === "REQ";
  const showApprove = !writerActionsOnly && (st === "REV" || st === "REQ");
  const showReject = !writerActionsOnly && (st === "REQ" || st === "REV");
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
        {onPreview && (
          <MesButton
            // 미리보기 — 호출측이 PDF/인쇄 창을 연다
            variant="secondary"
            disabled={!docIdx}
            onClick={onPreview}
          >
            미리보기
          </MesButton>
        )}
        {onEdit && (
          <MesButton
            // 양식 작성·편집 화면 — ?docIdx= deep-link
            variant="secondary"
            disabled={!docIdx}
            onClick={onEdit}
          >
            작성화면
          </MesButton>
        )}
        {docIdx && canApprove && showRequest && (
          <MesButton variant="primary" disabled={approvalBusy} onClick={() => void run("REQUEST")}>
            {actionLabel("REQUEST", "상신")}
          </MesButton>
        )}
        {docIdx && canApprove && showCancel && (
          <MesButton variant="secondary" disabled={approvalBusy} onClick={() => void run("CANCEL")}>
            {/* 작성 화면은 「취소」, 결재함은 공통코드 상신취소 */}
            {writerActionsOnly ? "취소" : actionLabel("CANCEL", "상신취소")}
          </MesButton>
        )}
        {docIdx && canApprove && showReview && (
          <MesButton variant="secondary" disabled={approvalBusy} onClick={() => void run("REVIEW")}>
            {actionLabel("REVIEW", "검토완료")}
          </MesButton>
        )}
        {docIdx && canApprove && showApprove && (
          <MesButton variant="primary" disabled={approvalBusy} onClick={() => void run("APPROVE")}>
            {actionLabel("APPROVE", "승인")}
          </MesButton>
        )}
        {docIdx && canApprove && showReject && (
          <>
            <Input
              // 반려 사유 — REJECT 시에만 서버로 전달
              value={rejectOpinion}
              onChange={(e) => setRejectOpinion(e.target.value)}
              placeholder="반려 사유"
              className="w-40"
            />
            <MesButton variant="danger" disabled={approvalBusy} onClick={() => void run("REJECT")}>
              {actionLabel("REJECT", "반려")}
            </MesButton>
          </>
        )}
      </div>
    </div>
  );
}
