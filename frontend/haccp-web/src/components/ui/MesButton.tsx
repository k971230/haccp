/**
 * MesButton — 화면 전체가 공유하는 표준 버튼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) variant로 조회·저장·삭제 같은 의미를 지정하면 색·아이콘 크기가 자동으로 맞춰진다
 *   2) loading이 true면 스피너로 바뀌고 클릭이 막힌다 — 저장 중 두 번 눌러 중복 저장되는 사고를 막는다
 *   3) API를 직접 호출하지 않는다. 실제 처리는 화면·훅이 담당한다
 *
 * PIPELINE[HF113] UI 컴포넌트
 */
// 역할 — button 표준 속성·자식 노드 타입
import type { ButtonHTMLAttributes, ReactNode } from "react";
// 역할 — 아이콘 컴포넌트 타입
import type { LucideIcon } from "lucide-react";
// 역할 — 로딩 스피너
import { Loader2 } from "lucide-react";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — variant x size 스타일 조합
import { buttonVariants } from "@/lib/buttonVariants";
// 역할 — preset 아이콘 이름 해석
import { resolveMesIcon, type MesIconName } from "@/lib/icons";

/** 버튼 의미 — 색과 강조 수준을 결정한다 */
export type MesButtonVariant =
  | "search" | "save" | "add" | "edit" | "danger" | "dangerConfirm" | "secondary" | "excel" | "download" | "ghost" | "primary";

/** 버튼 크기 — sm은 그리드 툴바, md는 일반 */
export type MesButtonSize = "sm" | "md";

interface MesButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: MesButtonVariant;
  size?: MesButtonSize;
  loading?: boolean;
  /** preset 이름("plus", "save", …) 또는 lucide 컴포넌트 직접 전달 */
  icon?: MesIconName | LucideIcon | string;
  children?: ReactNode;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 표준 스타일이 적용된 button 요소를 만든다
 *   2) 화면의 모든 버튼은 이 컴포넌트를 쓴다 — 색·간격이 화면마다 어긋나는 것을 막는다
 *   3) loading이거나 disabled면 클릭 이벤트가 발생하지 않는다
 */
export function MesButton({
  // 버튼 의미 — 색·강조를 결정한다. 기본은 보조(회색) 버튼
  variant = "secondary",
  // 크기 — 그리드 툴바는 sm, 조회 조건·모달 하단은 md
  size = "md",
  // 처리 중 여부 — true이면 스피너로 바뀌고 클릭이 막힌다
  loading = false,
  // 좌측 아이콘 — preset 이름 문자열 또는 lucide 컴포넌트. 처리 중에는 스피너로 대체된다
  icon,
  // 버튼 라벨 — 아이콘만 쓰는 버튼이면 생략할 수 있다
  children,
  // 추가 클래스 — 기본 스타일 위에 병합된다(폭 고정 등)
  className = "",
  // 비활성 여부 — 권한이 없거나 대상 미선택일 때 true로 넘긴다
  disabled,
  // HTML type — 기본 button. 폼 안에서 Enter 제출이 필요할 때만 submit으로 바꾼다
  type = "button",
  ...rest
}: MesButtonProps) {
  // primary는 save의 별칭이다 — 두 이름이 섞여 쓰여도 같은 모양이 되게 흡수한다
  const v = variant === "primary" ? "save" : variant;
  // 함수·객체면 lucide 컴포넌트를 그대로, 문자열이면 preset 이름으로 해석한다
  const IconComp =
    icon && (typeof icon === "function" || (typeof icon === "object" && icon !== null))
      ? (icon as LucideIcon)
      : resolveMesIcon(typeof icon === "string" ? icon : undefined);

  return (
    <button
      type={type}
      className={cn(buttonVariants({ variant: v, size }), loading && "pointer-events-none", className)}
      // 처리 중에도 비활성으로 둔다 — 연속 클릭으로 같은 요청이 두 번 나가지 않게 한다
      disabled={disabled || loading}
      {...rest}
    >
      {loading && <Loader2 className="h-3.5 w-3.5 shrink-0 animate-spin" aria-hidden />}
      {!loading && IconComp && <IconComp className="h-3.5 w-3.5 shrink-0" aria-hidden />}
      {children != null && children !== "" && <span>{children}</span>}
    </button>
  );
}
