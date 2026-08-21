/**
 * dialog — 확인·알림 모달과 토스트를 전역 한 곳에서 띄운다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 확인창·토스트는 왼쪽 색 바 + 원형 아이콘 카드
 *   2) 확인·저장은 MesButton save(파랑), 취소는 danger(빨강). 삭제 확인의 실행 버튼은 '삭제'
 *   3) 삭제·안내는 왼쪽 바·아이콘 색으로 구분. 저장 완료는 모달로 바꾸지 않는다
 *
 * PIPELINE[HF56] 셸 인프라
 * PIPELINE[HF49] 연관 — 셸
 */
// 역할 — 모달 키보드 단축키 등록
import { useEffect } from "react";
// 역할 — 모달·토스트 전역 상태 스토어
import { create } from "zustand";
// 역할 — className 병합 유틸
import { cn } from "@/lib/cn";
// 역할 — 안내 원형 아이콘 (i / ! / 체크 / X)
import { AlertTriangle, Check, Info, X } from "lucide-react";
// 역할 — 확인·취소 색을 저장·삭제 툴바와 같게
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 토스트 표시 시간 (OPS_GLOBAL_CONFIG)
import { TOAST_DURATION_MS, TOAST_ERROR_DURATION_MS } from "@/config/envConfig";

/** 모달·토스트 톤 — 확인 빨강·배너 제목색을 결정한다 */
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
  /** 확인 버튼 색(파랑/빨강)·배너 제목색 */
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
  /** 화면 우측 하단에 쌓인 토스트 목록 */
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
        // 톤 미지정 시 — confirm·alert 모두 안내(info). 삭제·초기화는 mesConfirmDanger가 error를 넘긴다
        tone: o?.tone ?? "info",
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
 *   2) 저장·업로드·적용처럼 안내 확인에 쓴다. 확인은 시스템 파랑
 *   3) 확인이면 true, 취소·Escape·백드롭 클릭이면 false다
 */
export const mesConfirm = (
  // 확인 문구 — 여러 줄이면 그대로 줄바꿈되어 표시된다
  message: string,
  // 제목·톤·버튼 문구 재정의 — 생략하면 확인 모달 기본값(info)을 쓴다
  o?: Parameters<DialogState["show"]>[2]
) => useDialogStore.getState().show("confirm", message, o);

/**
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) 삭제·초기화처럼 되돌리기 어려운 확인에 쓴다
 *   2) 실행 버튼은 '삭제', 제목도 '삭제'. 취소는 툴바 삭제와 같은 빨강
 *   3) 확인이면 true, 취소·Escape·백드롭이면 false다
 */
export const mesConfirmDanger = (
  // 확인 문구 — MES.deleteConfirm 또는 초기화 질문
  message: string,
  // 제목·실행 버튼 문구 — 생략하면 삭제
  o?: Partial<Pick<DialogState, "title" | "okText" | "cancelText">>
) => useDialogStore.getState().show("confirm", message, {
  tone: "error",
  title: o?.title ?? "삭제",
  okText: o?.okText ?? "삭제",
  cancelText: o?.cancelText,
});

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
 *   1) 화면 우측 하단에 스스로 사라지는 안내 카드를 띄운다
 *   2) 저장 완료처럼 흐름을 끊지 않아야 하는 안내에 쓴다
 *   3) 반환값이 없다 — 사용자 응답을 기다리지 않는다
 */
export const mesToast = (
  // 안내 문구
  message: string,
  // 톤 — 기본은 성공. 오류는 "error"로 넘겨 더 오래 남긴다
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

// 배너·확인창 제목 — 톤별 짧은 안내
const BANNER_KICKER: Record<Tone, string> = {
  info: "알림",
  success: "완료",
  warn: "안내",
  error: "오류",
};

// 원형 아이콘 — 정보 i, 경고 !, 성공 체크, 오류 X
const TONE_ICON = {
  info: Info,
  success: Check,
  warn: AlertTriangle,
  error: X,
} as const;

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 모달·토스트를 실제로 그리는 호스트 컴포넌트다
 *   2) 앱 루트(셸)에 한 번만 마운트한다 — 두 번 넣으면 모달이 겹쳐 보인다
 *   3) 열려 있는 동안 Enter는 확인, Escape는 취소. unsaved의 Enter는 무시
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
          // 반투명 배경 — 바깥을 클릭하면 취소
          className="mes-alert-backdrop"
          onClick={() => (kind === "unsaved" ? closeUnsaved("cancel") : close(false))}
        >
          <div
            // 확인 카드 — 토스트와 같은 왼쪽 바·원형 아이콘. 버튼은 확인·취소만
            className={cn("mes-notice mes-alert", `mes-notice-tone-${tone}`)}
            // 본체 클릭이 백드롭까지 올라가 모달이 닫히는 것을 막는다
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
            aria-labelledby="mes-alert-title"
          >
            <div
              // 톤 색 세로 바 — 삭제 빨강, 안내 파랑
              className="mes-notice-bar"
              aria-hidden
            />
            <div className="mes-notice-content">
              <div className="mes-notice-row">
                <div
                  // 원형 아이콘
                  className="mes-notice-icon"
                  aria-hidden
                >
                  <ToneIcon strokeWidth={2.4} />
                </div>
                <div className="mes-notice-copy">
                  <div
                    // 제목
                    id="mes-alert-title"
                    className="mes-notice-title"
                  >
                    {title}
                  </div>
                  <div
                    // 본문 — \n 줄바꿈 유지
                    className="mes-notice-msg"
                  >
                    {message}
                  </div>
                </div>
              </div>
              {kind === "unsaved" ? (
                <div
                  // 미저장만 3버튼. 일반 확인은 확인·취소만
                  className="mes-alert-actions"
                >
                  <MesButton
                    // 취소 — 툴바 삭제와 같은 빨강
                    type="button"
                    size="sm"
                    variant="danger"
                    onClick={() => closeUnsaved("cancel")}
                  >
                    {cancelText}
                  </MesButton>
                  <MesButton
                    // 저장 안 함
                    type="button"
                    size="sm"
                    variant="secondary"
                    onClick={() => closeUnsaved("discard")}
                  >
                    {discardText}
                  </MesButton>
                  <MesButton
                    // 저장 — 툴바 저장과 같은 파랑
                    type="button"
                    size="sm"
                    variant="save"
                    autoFocus
                    onClick={() => closeUnsaved("save")}
                  >
                    {saveText}
                  </MesButton>
                </div>
              ) : (
                <div
                  // 확인·저장(파랑) · 취소(빨강). 삭제 확인은 실행 문구가 '삭제'
                  className="mes-alert-actions"
                >
                  {kind === "confirm" ? (
                    <MesButton
                      // 취소 — 툴바 삭제와 같은 빨강
                      type="button"
                      size="sm"
                      variant="danger"
                      onClick={() => close(false)}
                    >
                      {cancelText}
                    </MesButton>
                  ) : null}
                  <MesButton
                    // 확인·삭제 실행 — 툴바 저장과 같은 파랑
                    type="button"
                    size="sm"
                    variant="save"
                    autoFocus
                    onClick={() => close(true)}
                  >
                    {okText}
                  </MesButton>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
      <div
        // 우측 하단 안내 스택
        className="mes-banner-stack"
      >
        {toasts.map((t) => {
          const Icon = TONE_ICON[t.tone];
          return (
            <div
              key={t.id}
              className={cn("mes-notice mes-banner", `mes-notice-tone-${t.tone}`)}
              // 카드 클릭으로도 닫힘
              onClick={() => dropToast(t.id)}
            >
              <div
                // 톤 색 세로 바
                className="mes-notice-bar"
                aria-hidden
              />
              <div className="mes-notice-content">
                <div className="mes-notice-row">
                  <div
                    // 원형 아이콘
                    className="mes-notice-icon"
                    aria-hidden
                  >
                    <Icon strokeWidth={2.4} />
                  </div>
                  <div className="mes-notice-copy">
                    <div className="mes-notice-title">{BANNER_KICKER[t.tone]}</div>
                    <div className="mes-notice-msg">{t.message}</div>
                  </div>
                  <button
                    // 닫기 X
                    type="button"
                    className="mes-notice-close"
                    aria-label="닫기"
                    onClick={(e) => {
                      e.stopPropagation();
                      dropToast(t.id);
                    }}
                  >
                    <X size={16} strokeWidth={2} />
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </>
  );
}
