/**
 * HaccpLogo — 제품 로고(텍스트 마크).
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 사이드바·로그인 화면에 쓰는 제품 표식이다
 *   2) 이미지 파일 대신 텍스트로 그린다 — 업체별 로고 교체 기능이 들어오기 전까지 별도 asset을 관리하지 않는다
 *   3) 접힌 사이드바에서는 compact를 켜 약어(HC)만 보여준다
 *
 * PIPELINE[HF169] UI 컴포넌트
 */
// 역할 — className 병합
import { cn } from "@/lib/cn";

/** 크기 단계 — 접힌 사이드바(xs)부터 로그인 화면(lg)까지 */
const sizeClass = {
  xs: "text-[11px]",
  sm: "text-[13px]",
  md: "text-sm",
  lg: "text-xl",
} as const;

interface HaccpLogoProps {
  className?: string;
  size?: keyof typeof sizeClass;
  /** 약어만 표시 — 접힌 사이드바처럼 폭이 좁을 때 */
  compact?: boolean;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 제품 로고를 텍스트로 그린다
 *   2) 사이드바 브랜드 영역과 로그인 화면 상단에서 사용한다
 *   3) compact면 "HC" 약어만, 아니면 "HACCP 기록관리" 전체를 보여준다
 */
export function HaccpLogo({
  // 추가 클래스 — 최대 폭 제한 등 배치 조정
  className,
  // 글자 크기 단계 — 배치 위치에 맞춰 고른다
  size = "md",
  // 약어 표시 여부 — 접힌 사이드바에서 true
  compact = false,
}: HaccpLogoProps) {
  return (
    <span
      className={cn(
        "inline-flex shrink-0 items-center gap-1 font-bold leading-none tracking-tight text-[#1a3676]",
        sizeClass[size],
        className,
      )}
      // 약어만 보일 때도 무엇인지 알 수 있도록 도움말을 남긴다
      title="HACCP 기록관리"
    >
      {compact ? "HC" : (
        <>
          <span>HACCP</span>
          <span className="font-medium text-slate-500">기록관리</span>
        </>
      )}
    </span>
  );
}
