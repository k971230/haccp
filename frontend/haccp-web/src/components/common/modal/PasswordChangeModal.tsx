/**
 * PasswordChangeModal — 본인 비밀번호 변경 팝업.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 푸터 키 아이콘이 openModal("PasswordChange") 로 연다
 *   2) 현재·새·확인 3칸. 일치는 여기서 먼저 본다
 *   3) 서버가 다시 검증한다
 *
 * PIPELINE[HF213] 비밀번호 변경 팝업
 */
import { useCallback, useEffect, useState } from "react";
import { MesButton } from "@/components/ui/MesButton";
import { searchInputClass } from "@/components/ui/Input";
import { gridHeadClass } from "@/components/layout/pageClasses";
import { cn } from "@/lib/cn";
import { changePassword } from "@/api/authApi";
import { mesError } from "@/shell/errors";
import { mesToast } from "@/shell/dialog";
import { useModalStore } from "@/stores/modalStore";

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 비밀번호 3칸을 받아 변경 API를 호출한다
 *   2) 푸터에서 연다
 *   3) 성공 시 토스트 후 닫는다
 */
export function PasswordChangeModal() {
  const closeModal = useModalStore((s) => s.closeModal);
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
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
    if (!currentPassword) {
      mesToast("현재 비밀번호를 입력해 주세요.", "warn");
      return;
    }
    if (!newPassword) {
      mesToast("새 비밀번호를 입력해 주세요.", "warn");
      return;
    }
    if (newPassword !== confirmPassword) {
      mesToast("새 비밀번호가 서로 다릅니다.", "warn");
      return;
    }
    if (currentPassword === newPassword) {
      mesToast("새 비밀번호는 현재 비밀번호와 달라야 합니다.", "warn");
      return;
    }
    setBusy(true);
    try {
      await changePassword({ currentPassword, newPassword });
      mesToast("비밀번호를 변경했습니다.", "success");
      closeModal();
    } catch (e) {
      mesError(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div
      // 비밀번호 변경 오버레이
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label="비밀번호 변경"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) handleClose();
      }}
    >
      <form
        // 브라우저 자동완성을 끈다 — 현재 비밀번호는 사람이 친다
        autoComplete="off"
        className="flex w-full max-w-xs flex-col overflow-hidden rounded border border-slate-200 bg-white shadow-lg"
        onMouseDown={(e) => e.stopPropagation()}
        onSubmit={(e) => {
          e.preventDefault();
          void handleSubmit();
        }}
      >
        <div
          // 보라 헤더 — 서명 모달과 같음
          className={cn(gridHeadClass, "mes-modal-grid-head")}
        >
          <b>비밀번호 변경</b>
        </div>
        <div className="flex flex-col gap-2 px-3 py-2.5">
          <label className="flex flex-col gap-1 text-xs text-slate-600">
            <span>
              현재 비밀번호
              <span className="ml-0.5 text-rose-500">*</span>
            </span>
            <input
              // 현재 비밀번호 — 자동입력 금지, 사람이 친다. 폭은 모달을 채운다
              type="password"
              name="haccp-pw-current"
              autoComplete="off"
              autoCorrect="off"
              spellCheck={false}
              required
              readOnly
              onFocus={(e) => e.currentTarget.removeAttribute("readonly")}
              className={cn(searchInputClass, "w-full")}
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
            />
          </label>
          <label className="flex flex-col gap-1 text-xs text-slate-600">
            <span>
              새 비밀번호
              <span className="ml-0.5 text-rose-500">*</span>
            </span>
            <input
              // 새 비밀번호 — 빈칸만 아니면 된다
              type="password"
              name="haccp-pw-next"
              autoComplete="off"
              autoCorrect="off"
              spellCheck={false}
              required
              readOnly
              onFocus={(e) => e.currentTarget.removeAttribute("readonly")}
              className={cn(searchInputClass, "w-full")}
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
            />
          </label>
          <label className="flex flex-col gap-1 text-xs text-slate-600">
            <span>
              새 비밀번호 확인
              <span className="ml-0.5 text-rose-500">*</span>
            </span>
            <input
              // 확인 — 프론트에서 먼저 맞춘다
              type="password"
              name="haccp-pw-confirm"
              autoComplete="off"
              autoCorrect="off"
              spellCheck={false}
              required
              readOnly
              onFocus={(e) => e.currentTarget.removeAttribute("readonly")}
              className={cn(searchInputClass, "w-full")}
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
            />
          </label>
        </div>
        <div
          // 푸터 — 변경(조회 파란 틴트) / 취소(삭제 빨간 틴트)
          className="flex shrink-0 items-center justify-end gap-1.5 border-t border-slate-200 bg-slate-50/70 px-3 py-2"
        >
          <MesButton
            // 변경 — 새로고침과 같은 파란 틴트
            variant="search"
            size="sm"
            loading={busy}
            disabled={busy}
            type="submit"
          >
            변경
          </MesButton>
          <MesButton
            // 취소 — 삭제와 같은 빨간 틴트
            variant="danger"
            size="sm"
            disabled={busy}
            type="button"
            onClick={handleClose}
          >
            취소
          </MesButton>
        </div>
      </form>
    </div>
  );
}
