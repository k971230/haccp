/**
 * ReasonActionModal — 사유가 필요한 행위(반려·결재취소) 공통 팝업.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 비밀번호 변경과 같은 셸 — 보라 헤더·본문·푸터 버튼. 화면은 openModal("ReasonAction") 만 부른다
 *   2) textarea 는 팝업 폭을 채운다. 확인·닫기도 푸터에 둔다
 *   3) 사유가 비면 여기서 막고 닫지 않는다. 성공한 onConfirm 뒤에 닫는다
 *
 * PIPELINE[HF99] 공통 모달
 */
import { useCallback, useEffect, useState } from "react";
import { MesButton, type MesButtonVariant } from "@/components/ui/MesButton";
import { gridHeadClass } from "@/components/layout/pageClasses";
import { cn } from "@/lib/cn";
import { mesToast } from "@/shell/dialog";
import { useModalStore } from "@/stores/modalStore";
import type { ReasonActionModalProps } from "./modalTypes";

/** 사유 칸 기본 상한 — tbl_document.reject_reason / cancel_reason varchar(500) */
const REASON_MAX = 500;

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 사유를 받아 onConfirm 에 넘긴다
 *   2) 결재 툴바의 반려·취소가 연다. 다른 사유도 같은 팝업을 쓴다
 *   3) Escape·배경 클릭으로 닫는다. 처리 중이면 닫지 않는다
 */
export function ReasonActionModal({
  // 팝업 제목 — 결재 취소·반려
  title,
  // 확인 버튼 글자 — 기본 「확인」. 헤더의 취소·반려와 겹치지 않는다
  confirmLabel = "확인",
  // 확인 버튼 색 — 없으면 조회 파란 틴트
  confirmVariant = "search",
  // textarea 안내
  placeholder = "사유를 입력하세요",
  // 글자 상한
  maxLength = REASON_MAX,
  // 확인 시 사유 전달
  onConfirm,
}: ReasonActionModalProps) {
  const closeModal = useModalStore((s) => s.closeModal);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);

  const handleClose = useCallback(() => {
    if (busy) return;
    closeModal();
  }, [busy, closeModal]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.preventDefault();
        handleClose();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [handleClose]);

  const handleSubmit = async () => {
    if (busy) return;
    const text = reason.trim();
    if (!text) {
      mesToast("사유를 입력하세요.", "warn");
      return;
    }
    setBusy(true);
    try {
      await onConfirm(text);
      closeModal();
    } catch {
      // 호출부가 이미 업무 토스트. 팝업은 연 채로 다시 고친다
    } finally {
      setBusy(false);
    }
  };

  return (
    <div
      // 사유 입력 오버레이 — 비밀번호 변경과 같은 레이어
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label={title}
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) handleClose();
      }}
    >
      <form
        className="flex w-full max-w-lg flex-col overflow-hidden rounded border border-slate-200 bg-white shadow-lg"
        onMouseDown={(e) => e.stopPropagation()}
        onSubmit={(e) => {
          e.preventDefault();
          void handleSubmit();
        }}
      >
        <div
          // 보라 헤더 — 비밀번호 변경·서명과 같음
          className={cn(gridHeadClass, "mes-modal-grid-head")}
        >
          <b>{title}</b>
        </div>
        <div className="flex flex-col gap-2 px-3 py-2.5">
          <textarea
            // 사유 본문 — 팝업 폭을 채운다. 한 줄 입력이 아니다
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder={placeholder}
            rows={6}
            maxLength={maxLength}
            autoFocus
            className="w-full rounded border border-slate-300 px-2 py-1.5 text-sm outline-none focus:border-brand-700 focus:ring-2 focus:ring-brand-100"
          />
          <div className="flex justify-end text-xs text-slate-400">
            {reason.length} / {maxLength}자
          </div>
        </div>
        <div
          // 푸터 — 확인·닫기. textarea 와 같이 폭을 채운다. 크기는 MesButton 기본(md)
          className="flex shrink-0 items-stretch gap-1.5 border-t border-slate-200 bg-slate-50/70 px-3 py-2"
        >
          <MesButton
            // 확인 — 헤더 결재 버튼과 같은 md. 가로를 채운다
            variant={confirmVariant as MesButtonVariant}
            loading={busy}
            disabled={busy}
            type="submit"
            className="flex-1"
          >
            {confirmLabel}
          </MesButton>
          <MesButton
            // 닫기 — 삭제와 같은 빨간 틴트. 확인과 같은 폭
            variant="danger"
            disabled={busy}
            type="button"
            className="flex-1"
            onClick={handleClose}
          >
            닫기
          </MesButton>
        </div>
      </form>
    </div>
  );
}
