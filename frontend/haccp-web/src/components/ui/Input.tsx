/**
 * Input — 표준 텍스트 입력과 상황별 입력 클래스 모음.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 조회 조건·로그인·그리드 편집 셀은 높이와 테두리가 달라야 해서 용도별 클래스를 함께 내보낸다
 *   2) invalid를 켜면 붉은 테두리로 바뀐다 — 검증 실패 위치를 문구 없이도 알 수 있게 한다
 *   3) API 호출·검증 로직은 없다. 값 관리와 검증은 화면·훅이 한다
 *
 * PIPELINE[HF112] UI 컴포넌트
 */
// 역할 — 부모가 포커스를 줄 수 있게 ref 전달
import { forwardRef, type InputHTMLAttributes } from "react";
// 역할 — className 병합
import { cn } from "@/lib/cn";

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  /** 검증 실패 여부 — true이면 붉은 테두리로 표시한다 */
  invalid?: boolean;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 공통 스타일이 적용된 input 요소를 만든다
 *   2) 폼·모달의 단일 입력 항목에 쓴다. 그리드 셀은 gridInputClass를 직접 쓴다
 *   3) ref를 그대로 넘겨 저장 실패 시 해당 입력으로 포커스를 되돌릴 수 있다
 */
export const Input = forwardRef<HTMLInputElement, InputProps>(
  (
    {
      // 추가 클래스 — 폭 지정 등 화면별 조정
      className,
      // 검증 실패 여부 — 붉은 테두리 전환
      invalid,
      ...props
    },
    // 포커스 이동용 ref — 검증 실패 항목으로 커서를 보낼 때 쓴다
    ref
  ) => (
    <input
      ref={ref}
      className={cn(
        "h-mes-input w-full rounded-mes border border-slate-300 bg-white px-2 text-mes-ui text-slate-900 outline-none transition",
        "placeholder:text-slate-400 focus:border-brand-700 focus:ring-2 focus:ring-brand-100",
        "disabled:bg-slate-100 disabled:text-slate-400",
        // invalid일 때(= 검증 실패) 테두리·포커스 링을 붉게
        invalid && "border-rose-500 focus:border-rose-500 focus:ring-rose-100",
        className,
      )}
      {...props}
    />
  ),
);
Input.displayName = "Input";

/** 조회 조건 영역 입력 — 날짜·코드 입력에 쓰는 고정 폭 스타일 */
export const searchInputClass =
  "h-mes-input w-[140px] rounded-md border border-slate-200 bg-slate-50 px-2.5 text-mes-ui transition focus:border-blue-500 focus:bg-white focus:ring-2 focus:ring-blue-100";

/** 그리드 인라인 편집 셀 — 실제 스타일은 global.css의 .mes-egrid-input에 있다 */
export const gridInputClass = "mes-egrid-input";

/** 로그인 폼 입력 — 흰 패널 위 알약 형태 */
export const loginInputClass =
  "h-11 w-full appearance-none rounded-full border border-slate-200 bg-white px-4 text-sm text-slate-800 outline-none transition placeholder:text-slate-400 focus:border-[#1a3676] focus:ring-2 focus:ring-[#1a3676]/15";
