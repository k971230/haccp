/**
 * UserSignModal — 사용자 서명 미리보기·업로드·삭제 공통 팝업.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) pages/sys/UserSignDialog에서 옮겨온 전역 모달 — openModal("UserSign", ...)로 연다
 *   2) 코드 룩업과 동일 모달 셸 — 보라 헤더·max-w-lg·280 미리보기·푸터
 *   3) 파일 선택 취소·팝업 닫기 시 포커스·busy·요청을 반드시 해제한다
 *
 * PIPELINE[HF99] 사용자 서명 팝업
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { isCancel } from "axios";
import { MesButton } from "@/components/ui/MesButton";
import { gridHeadClass } from "@/components/layout/pageClasses";
import { cn } from "@/lib/cn";
// 역할 — 서명 조회·업로드·삭제 API (사용자 도메인 소유)
import { deleteUserSign, fetchUserSignBlob, uploadUserSign } from "@/api/sys/userApi";
import { mesError } from "@/shell/errors";
import { mesConfirmDanger, mesToast } from "@/shell/dialog";
// 역할 — 모달 props 계약·공통 바디 높이
import { COMMON_MODAL_BODY_H, type UserSignModalProps } from "./modalTypes";
// 역할 — 전역 모달 닫기
import { useModalStore } from "@/stores/modalStore";

/** 서명 업로드 최대 크기 — 10MB */
export const SIGN_MAX_BYTES = 10 * 1024 * 1024;

const ACCEPT = "image/png,image/jpeg";

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 서명 미리보기·업로드·삭제 UI를 렌더한다
 *   2) 저장된 userId 행에서만 연다 — 신규 행은 호출부가 막는다
 *   3) 형식·용량·취소는 업무 토스트/무소음 처리
 */
export function UserSignModal({
  // 대상 사용자 ID — 저장된 행만
  userId,
  // 서명 등록 여부 — true면 미리보기 시도
  hasSign: hasSignProp,
  // 업로드·삭제 성공 후 목록 재조회
  onUploaded,
}: UserSignModalProps) {
  // 역할 — 닫기·업로드 완료 후 모달 종료
  const closeModal = useModalStore((s) => s.closeModal);
  const fileRef = useRef<HTMLInputElement>(null);
  const previewAbortRef = useRef<AbortController | null>(null);
  const uploadAbortRef = useRef<AbortController | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  // 삭제 진행 중 — 교체·닫기와 동시 클릭 방지
  const [deleting, setDeleting] = useState(false);
  const hasSign = Boolean(hasSignProp);
  const busy = uploading || deleting;

  const revokePreview = useCallback(() => {
    setPreviewUrl((prev) => {
      if (prev) URL.revokeObjectURL(prev);
      return null;
    });
  }, []);

  /** 팝업·요청 정리 — 닫기·언마운트 공통 */
  const cleanupRequests = useCallback(() => {
    previewAbortRef.current?.abort();
    previewAbortRef.current = null;
    uploadAbortRef.current?.abort();
    uploadAbortRef.current = null;
    setLoading(false);
    setUploading(false);
    setDeleting(false);
    if (fileRef.current) fileRef.current.value = "";
  }, []);

  const handleClose = useCallback(() => {
    cleanupRequests();
    revokePreview();
    // 파일 선택창 취소 후 포커스가 남는 경우 클릭이 먹히지 않는 현상 완화
    requestAnimationFrame(() => {
      (document.activeElement as HTMLElement | null)?.blur?.();
    });
    closeModal();
  }, [cleanupRequests, closeModal, revokePreview]);

  useEffect(() => {
    // 서명 미등록일 때(= hasSign false) 미리보기 요청 없이 안내만 띄운다
    if (!userId || !hasSign) {
      revokePreview();
      setLoading(false);
      return;
    }

    const ac = new AbortController();
    previewAbortRef.current?.abort();
    previewAbortRef.current = ac;
    setLoading(true);
    revokePreview();

    void (async () => {
      try {
        const blob = await fetchUserSignBlob(userId, ac.signal);
        if (ac.signal.aborted) return;
        const url = URL.createObjectURL(blob);
        setPreviewUrl(url);
      } catch (e) {
        if (ac.signal.aborted || isCancel(e)) return;
        mesError(e);
      } finally {
        if (!ac.signal.aborted) setLoading(false);
      }
    })();

    return () => {
      ac.abort();
    };
  }, [hasSign, revokePreview, userId]);

  // 언마운트 정리 — 미리보기 objectURL 해제·잔여 요청 취소
  useEffect(() => {
    return () => {
      cleanupRequests();
      revokePreview();
    };
  }, [cleanupRequests, revokePreview]);

  // Esc — 업로드 중이어도 닫고 요청 취소
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

  /** 파일 선택창 열기 — 취소 시 busy/포커스 잔존 방지 */
  const openFilePicker = () => {
    const input = fileRef.current;
    if (!input || busy) return;
    input.value = "";

    const restoreFocus = () => {
      requestAnimationFrame(() => {
        (document.activeElement as HTMLElement | null)?.blur?.();
      });
    };

    // Chromium: 선택창 취소 시 cancel 이벤트 — change는 안 옴
    const onCancel = () => {
      input.removeEventListener("cancel", onCancel);
      restoreFocus();
    };
    input.addEventListener("cancel", onCancel);

    // cancel 미지원 브라우저 — 창 복귀 시 한 번 포커스 정리
    const onWinFocus = () => {
      window.removeEventListener("focus", onWinFocus);
      // 선택 직후 focus가 먼저 올 수 있어 짧게 지연
      window.setTimeout(restoreFocus, 0);
    };
    window.addEventListener("focus", onWinFocus);

    input.click();
  };

  const handleFile = async (file: File | null) => {
    if (!file) {
      // 취소·빈 선택 — 포커스만 복구
      requestAnimationFrame(() => {
        (document.activeElement as HTMLElement | null)?.blur?.();
      });
      return;
    }
    const mime = (file.type || "").toLowerCase();
    if (mime !== "image/png" && mime !== "image/jpeg") {
      mesToast("PNG 또는 JPG 파일만 업로드할 수 있습니다.", "warn");
      if (fileRef.current) fileRef.current.value = "";
      return;
    }
    if (file.size > SIGN_MAX_BYTES) {
      mesToast("서명 이미지는 10MB 이하만 업로드할 수 있습니다.", "warn");
      if (fileRef.current) fileRef.current.value = "";
      return;
    }

    const ac = new AbortController();
    uploadAbortRef.current?.abort();
    uploadAbortRef.current = ac;
    setUploading(true);
    try {
      await uploadUserSign(userId, file, ac.signal);
      if (ac.signal.aborted) return;
      mesToast("서명을 등록했습니다.", "success");
      onUploaded();
      handleClose();
    } catch (e) {
      if (ac.signal.aborted || isCancel(e)) return;
      mesError(e);
    } finally {
      if (!ac.signal.aborted) setUploading(false);
      if (fileRef.current) fileRef.current.value = "";
    }
  };

  /** 등록된 서명 삭제 — 확인 후 API */
  const handleDelete = async () => {
    if (!hasSign || busy) return;
    if (!(await mesConfirmDanger("등록된 서명을 삭제하시겠습니까?"))) return;
    const ac = new AbortController();
    uploadAbortRef.current?.abort();
    uploadAbortRef.current = ac;
    setDeleting(true);
    try {
      await deleteUserSign(userId, ac.signal);
      if (ac.signal.aborted) return;
      mesToast("서명을 삭제했습니다.", "success");
      onUploaded();
      handleClose();
    } catch (e) {
      if (ac.signal.aborted || isCancel(e)) return;
      mesError(e);
    } finally {
      if (!ac.signal.aborted) setDeleting(false);
    }
  };

  return (
    <div
      // 서명 관리 모달 오버레이 — 배경 클릭 시 닫기(요청 취소 포함)
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label="서명 관리"
      onMouseDown={(e) => {
        // 패널 밖(오버레이) 클릭일 때만 닫기
        if (e.target === e.currentTarget) handleClose();
      }}
    >
      <div
        className="flex w-full max-w-lg flex-col overflow-hidden rounded border border-slate-200 bg-white shadow-lg"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <div
          // 코드 룩업과 동일 — 보라 accent 헤더
          className={cn(gridHeadClass, "mes-modal-grid-head")}
        >
          <b>서명 관리 — {userId}</b>
        </div>
        <div className="flex flex-col gap-2 p-3">
          <p className="text-xs text-slate-500">JPG·PNG만 가능하며 최대 10MB입니다.</p>
          <div
            // 룩업 그리드와 동일 높이 — 이질감 방지
            className="flex items-center justify-center rounded border border-slate-100 bg-slate-50 p-3"
            style={{ height: COMMON_MODAL_BODY_H, minHeight: COMMON_MODAL_BODY_H }}
          >
            {loading ? (
              <span className="text-xs text-slate-500">불러오는 중…</span>
            ) : previewUrl ? (
              <img
                // 등록된 서명 미리보기
                src={previewUrl}
                alt="서명 미리보기"
                className="max-h-full max-w-full object-contain"
              />
            ) : (
              <span className="text-xs text-slate-500">등록된 서명이 없습니다.</span>
            )}
          </div>
          <input
            ref={fileRef}
            type="file"
            accept={ACCEPT}
            className="hidden"
            onChange={(e) => void handleFile(e.target.files?.[0] ?? null)}
          />
        </div>
        <div
          // 공통 모달 푸터 — 좌 액션 / 우 닫기
          className="flex shrink-0 items-center gap-2 border-t border-slate-200 bg-slate-50/70 px-3 py-2.5"
        >
          <MesButton
            // 미등록=업로드, 등록=교체
            variant="save"
            loading={uploading}
            disabled={busy}
            onClick={openFilePicker}
          >
            {hasSign ? "서명 교체" : "업로드"}
          </MesButton>
          {hasSign ? (
            <MesButton
              // 등록된 서명 삭제
              variant="danger"
              loading={deleting}
              disabled={busy}
              onClick={() => {
                void handleDelete();
              }}
            >
              삭제
            </MesButton>
          ) : null}
          <div className="ml-auto">
            <MesButton
              // 닫기 — 우측 끝 고정
              variant="secondary"
              onClick={handleClose}
            >
              {busy ? "취소" : "닫기"}
            </MesButton>
          </div>
        </div>
      </div>
    </div>
  );
}
