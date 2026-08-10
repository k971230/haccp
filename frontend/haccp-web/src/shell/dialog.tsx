/**
 * dialog — 확인·알림 모달과 토스트를 전역 한 곳에서 띄운다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) mesConfirm/mesAlert는 Promise를 반환해 화면 코드가 await로 사용자 응답을 기다릴 수 있다
 *   2) mesConfirmUnsaved는 저장/저장안함/취소 3버튼 — HWP 행 이동 미저장 가드용
 *   3) mes-web의 터치PC(kiosk) 대형 모드는 걷어냈다 — HACCP는 사무실 PC에서만 쓴다
 *
 * PIPELINE[HF56] 셸 인프라
 * PIPELINE[HF49] 연관 — 셸
 */
// 역할 — 모달 키보드 단축키 등록
import { useEffect } from "react";
// 역할 — 모달·토스트 전역 상태 스토어
import { create } from "zustand";
// 역할 — 톤별 아이콘 (info/success/warn/error)
import { AlertCircle, AlertTriangle, CheckCircle, Info } from "lucide-react";
// 역할 — className 병합 유틸
import { cn } from "@/lib/cn";
// 역할 — 모달 하단 확인·취소 버튼
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 토스트 표시 시간 (OPS_GLOBAL_CONFIG)
import { TOAST_DURATION_MS, TOAST_ERROR_DURATION_MS } from "@/config/envConfig";

/** 모달·토스트 톤 — 아이콘과 색을 결정한다 */
export type Tone = "info" | "success" | "warn" | "error";

/** 토스트 1건 */
interface ToastItem {
  id: number;
  message: string;
  tone: Tone;
}

/** 미저장 확인 3버튼 결과 — 저장 / 저장 안 함 / 취소 */
export type UnsavedChoice = "save" | "discard" | "cancel";

/** 모달·토스트 전역 상태와 조작 함수 */
interface DialogState {
  /** 모달 열림 여부 */
  open: boolean;
  /** alert(확인만) / confirm(확인·취소) / unsaved(저장·저장안함·취소) */
  kind: "alert" | "confirm" | "unsaved";
  /** 모달 제목 */
  title: string;
  /** 모달 본문 — 개행이 그대로 반영된다 */
  message: string;
  /** 아이콘·테두리 색을 정하는 톤 */
  tone: Tone;
  /** 확인 버튼 문구 */
  okText: string;
  /** 취소 버튼 문구 */
  cancelText: string;
  /** 저장 안 함 버튼 문구 — unsaved 전용 */
  discardText: string;
  /** 저장 버튼 문구 — unsaved 전용 */
  saveText: string;
  /** 사용자 응답을 호출부에 돌려주는 Promise resolve — 닫힐 때 소비된다 */
  resolve?: (v: boolean) => void;
  /** unsaved 3버튼 resolve */
  resolveUnsaved?: (v: UnsavedChoice) => void;
  /** 화면 우하단에 쌓인 토스트 목록 */
  toasts: ToastItem[];
  /** 모달을 띄우고 응답을 기다린다 */
  show: (
    kind: "alert" | "confirm",
    message: string,
    o?: Partial<Pick<DialogState, "title" | "tone" | "okText" | "cancelText">>
  ) => Promise<boolean>;
  /** 미저장 3버튼 모달을 띄운다 */
  showUnsaved: (
    message: string,
    o?: Partial<Pick<DialogState, "title" | "tone" | "saveText" | "discardText" | "cancelText">>
  ) => Promise<UnsavedChoice>;
  /** 모달을 닫고 결과를 전달한다 */
  close: (v: boolean) => void;
  /** unsaved 모달을 닫고 선택 결과를 전달한다 */
  closeUnsaved: (v: UnsavedChoice) => void;
  /** 토스트를 추가한다 */
  pushToast: (message: string, tone: Tone) => void;
  /** 토스트를 제거한다 */
  dropToast: (id: number) => void;
}

// 토스트 key로 쓸 증가 시퀀스 — 같은 문구가 동시에 떠도 서로 구분된다
let _tid = 1;

/** 모달·토스트 전역 스토어 — 컴포넌트 밖(예외 처리 유틸)에서도 getState로 접근한다 */
export const useDialogStore = create<DialogState>((set, get) => ({
  open: false,
  kind: "alert",
  title: "",
  message: "",
  tone: "info",
  okText: "확인",
  cancelText: "취소",
  discardText: "저장 안 함",
  saveText: "저장",
  toasts: [],
  show: (kind, message, o) =>
    // resolve를 상태에 보관해 두고, 버튼이 눌릴 때 호출한다
    new Promise<boolean>((resolve) =>
      set({
        open: true,
        kind,
        message,
        // 제목 미지정 시 — confirm은 "확인", alert는 "알림"
        title: o?.title ?? (kind === "confirm" ? "확인" : "알림"),
        // 톤 미지정 시 — confirm은 주의(warn), alert는 정보(info)
        tone: o?.tone ?? (kind === "confirm" ? "warn" : "info"),
        okText: o?.okText ?? "확인",
        cancelText: o?.cancelText ?? "취소",
        resolve,
        resolveUnsaved: undefined,
      })
    ),
  showUnsaved: (message, o) =>
    new Promise<UnsavedChoice>((resolve) =>
      set({
        open: true,
        kind: "unsaved",
        message,
        title: o?.title ?? "저장하지 않은 변경",
        tone: o?.tone ?? "warn",
        saveText: o?.saveText ?? "저장",
        discardText: o?.discardText ?? "저장 안 함",
        cancelText: o?.cancelText ?? "취소",
        resolve: undefined,
        resolveUnsaved: resolve,
      })
    ),
  close: (v) => {
    // 먼저 꺼내 둔다 — set으로 지운 뒤에는 접근할 수 없다
    const r = get().resolve;
    // unsaved가 열려 있을 때(= 잘못 close 호출) 취소로 처리
    const ru = get().resolveUnsaved;
    set({ open: false, resolve: undefined, resolveUnsaved: undefined });
    // ru가 있을 때(= unsaved) Escape/백드롭은 취소
    if (ru) {
      ru("cancel");
      return;
    }
    r?.(v);
  },
  closeUnsaved: (v) => {
    const ru = get().resolveUnsaved;
    set({ open: false, resolve: undefined, resolveUnsaved: undefined });
    ru?.(v);
  },
  pushToast: (message, tone) => {
    const id = _tid++;
    set((s) => ({ toasts: [...s.toasts, { id, message, tone }] }));
    // 오류일 때(= 원인을 읽어야 함) 더 오래 남긴다
    setTimeout(() => get().dropToast(id), tone === "error" ? TOAST_ERROR_DURATION_MS : TOAST_DURATION_MS);
  },
  dropToast: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),
}));

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 확인·취소 모달을 띄우고 사용자 선택을 Promise로 돌려준다
 *   2) 저장·삭제처럼 되돌리기 어려운 처리 직전에 await로 호출한다
 *   3) 확인이면 true, 취소·Escape·백드롭 클릭이면 false다
 */
export const mesConfirm = (
  // 확인 문구 — 여러 줄이면 그대로 줄바꿈되어 표시된다
  message: string,
  // 제목·톤·버튼 문구 재정의 — 생략하면 확인 모달 기본값을 쓴다
  o?: Parameters<DialogState["show"]>[2]
) => useDialogStore.getState().show("confirm", message, o);

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 확인 버튼만 있는 알림 모달을 띄운다
 *   2) 사용자가 반드시 읽어야 하는 안내(검증 실패 등)에 쓴다. 단순 완료 안내는 토스트가 낫다
 *   3) 사용자가 확인을 누르면 반환된 Promise가 완료된다
 */
export const mesAlert = (
  // 안내 문구
  message: string,
  // 제목·톤 재정의 — 생략하면 알림 기본값(info)
  o?: Parameters<DialogState["show"]>[2]
) => useDialogStore.getState().show("alert", message, o).then(() => undefined);

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 화면 우하단에 스스로 사라지는 토스트를 띄운다
 *   2) 저장 완료처럼 흐름을 끊지 않아야 하는 안내에 쓴다
 *   3) 반환값이 없다 — 사용자 응답을 기다리지 않는다
 */
export const mesToast = (
  // 안내 문구
  message: string,
  // 톤 — 기본은 성공(초록). 오류는 "error"로 넘겨 더 오래 남긴다
  tone: Tone = "success"
) => useDialogStore.getState().pushToast(message, tone);

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 저장 / 저장 안 함 / 취소 3버튼 확인을 띄운다
 *   2) HWP 양식 행 이동·문서 교체 전 미저장 가드에서 호출한다
 *   3) 백드롭·Escape는 cancel — 행 포커스를 유지한다
 */
export const mesConfirmUnsaved = (
  // 확인 문구 — 파일명 등을 포함해도 된다
  message: string,
  // 제목·버튼 문구 재정의
  o?: Parameters<DialogState["showUnsaved"]>[1]
) => useDialogStore.getState().showUnsaved(message, o);

// 톤별 아이콘
const TONE_ICON = { info: Info, success: CheckCircle, warn: AlertTriangle, error: AlertCircle } as const;
// 톤별 모달 상단 테두리 색
const TONE_BORDER = { info: "border-brand-700", success: "border-emerald-600", warn: "border-slate-400", error: "border-brand-800" } as const;
// 톤별 토스트 배경색
const TOAST_BG = { info: "bg-brand-700", success: "bg-emerald-600", warn: "bg-slate-600", error: "bg-brand-800" } as const;

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 모달·토스트를 실제로 그리는 호스트 컴포넌트다
 *   2) 앱 루트(셸·로그인 화면)에 한 번만 마운트한다 — 두 번 넣으면 모달이 겹쳐 보인다
 *   3) 열려 있는 동안 Enter는 확인, Escape는 취소로 동작한다
 */
export function DialogHost() {
  const {
    open, kind, title, message, tone, okText, cancelText, discardText, saveText,
    close, closeUnsaved, toasts, dropToast,
  } = useDialogStore();

  // 모달이 열린 동안만 전역 키 리스너를 붙인다 — 닫히면 즉시 해제해 다른 화면 단축키와 충돌하지 않게 한다
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.preventDefault();
        // unsaved일 때(= 3버튼) Escape는 취소
        if (kind === "unsaved") closeUnsaved("cancel");
        else close(false);
      } else if (e.key === "Enter" && kind !== "unsaved") {
        e.preventDefault();
        close(true);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, kind, close, closeUnsaved]);

  const ToneIcon = TONE_ICON[tone];

  return (
    <>
      {open && (
        <div
          // 백드롭 — 바깥을 클릭하면 취소로 처리한다
          className="fixed inset-0 z-[1000] flex items-center justify-center bg-slate-900/40"
          onClick={() => (kind === "unsaved" ? closeUnsaved("cancel") : close(false))}
        >
          <div
            // 모달 본체 — 톤에 따라 상단 테두리 색이 바뀐다
            className={cn("w-full max-w-md overflow-hidden rounded-mes-xl border-t-[3px] bg-white shadow-xl", TONE_BORDER[tone])}
            // 본체 클릭이 백드롭까지 올라가 모달이 닫히는 것을 막는다
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal
          >
            <div className="flex items-center gap-2 px-4 pb-1 pt-3 text-sm">
              <ToneIcon className="h-4 w-4 text-brand-700" aria-hidden />
              <b>{title}</b>
            </div>
            {/* whitespace-pre-line — 문구의 \n을 줄바꿈으로 살린다 */}
            <div className="whitespace-pre-line px-4 pb-3 text-mes-ui leading-relaxed text-slate-700">{message}</div>
            <div className="flex flex-wrap justify-end gap-2 border-t border-slate-200 bg-slate-50 px-4 py-2">
              {/* unsaved — 저장 / 저장 안 함 / 취소 */}
              {kind === "unsaved" ? (
                <>
                  <MesButton
                    // 취소 — 행 포커스·문서 유지
                    variant="secondary"
                    onClick={() => closeUnsaved("cancel")}
                  >
                    {cancelText}
                  </MesButton>
                  <MesButton
                    // 저장 안 함 — 변경 버리고 행 이동
                    variant="secondary"
                    onClick={() => closeUnsaved("discard")}
                  >
                    {discardText}
                  </MesButton>
                  <MesButton
                    // 저장 — 호스트 handleSave 후 행 이동
                    variant="save"
                    autoFocus
                    onClick={() => closeUnsaved("save")}
                  >
                    {saveText}
                  </MesButton>
                </>
              ) : (
                <>
                  {/* confirm일 때만(= 취소 선택지가 있을 때) 취소 버튼을 둔다 */}
                  {kind === "confirm" && (
                    <MesButton variant="secondary" onClick={() => close(false)}>
                      {cancelText}
                    </MesButton>
                  )}
                  <MesButton
                    // 삭제처럼 주의가 필요한 확인이면 경고 색 버튼으로 바꿔 오클릭을 줄인다
                    variant={kind === "confirm" && (tone === "warn" || tone === "error") ? "dangerConfirm" : "save"}
                    // 열리자마자 Enter로 확인할 수 있게 포커스를 준다
                    autoFocus
                    onClick={() => close(true)}
                  >
                    {okText}
                  </MesButton>
                </>
              )}
            </div>
          </div>
        </div>
      )}
      {/* 토스트 스택 — 오래된 것이 위, 새 것이 아래로 쌓인다 */}
      <div className="fixed bottom-3.5 right-3.5 z-[1100] flex flex-col gap-1.5">
        {toasts.map((t) => {
          const Icon = TONE_ICON[t.tone];
          return (
            <div
              key={t.id}
              className={cn(
                "flex max-w-sm cursor-pointer items-center gap-2 rounded-mes px-3 py-2 text-mes-ui text-white shadow-lg",
                TOAST_BG[t.tone]
              )}
              // 다 읽었으면 클릭해서 바로 닫을 수 있다
              onClick={() => dropToast(t.id)}
            >
              <Icon className="h-4 w-4 shrink-0" aria-hidden />
              <span>{t.message}</span>
            </div>
          );
        })}
      </div>
    </>
  );
}
