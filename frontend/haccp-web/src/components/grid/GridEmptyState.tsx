/**
 * GridEmptyState — 조회 결과 없음 (오버레이 / 행).
 * 오버레이는 스크롤 컨테이너 밖 래퍼에 두어 스크롤 시 공백이 생기지 않게 한다.
 
 * PIPELINE[F85] 그리드 빈 상태
 * PIPELINE[F90] 연관 모듈
 */
// 역할 — 조회 결과 없음 아이콘
import { Database } from "lucide-react";
// 역할 — MES 공통 메시지 카탈로그
import { MES } from "@/shell/messages";
// 역할 — className 병합
import { cn } from "@/lib/cn";

interface GridEmptyStateProps {
  colSpan?: number;
  hint?: string;
  variant?: "row" | "overlay";
  withFilter?: boolean;
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 조회 결과 없음 — tbody 행 또는 스크롤 영역 오버레이
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 조회 결과 없음 — tbody 행 또는 스크롤 영역 오버레이
export function GridEmptyState({ hint, variant = "row", withFilter }: GridEmptyStateProps) {
// 설명 — 아이콘·메시지·힌트 공통 콘텐츠
  const content = (
    <>
      <div className="mb-3 flex h-14 w-14 items-center justify-center rounded-full bg-slate-100 text-slate-400 shadow-inner">
        <Database className="h-7 w-7" aria-hidden />
      </div>
      <p className="text-sm font-semibold text-slate-700">{MES.noResult}</p>
      {hint && <p className="mt-1 max-w-xs text-xs text-slate-400">{hint}</p>}
    </>
  );

// 설명 — 오버레이 — 필터행 높이만큼 top 오프셋
  if (variant === "overlay") {
    return (
      <div
        // 추가 Tailwind/CSS 클래스
        // 기본 스타일 위에 병합(cn)
        className={cn(
          "pointer-events-none absolute inset-x-0 bottom-0 z-[1] flex flex-col items-center justify-center bg-grid-body text-center",
          withFilter ? "top-[56px]" : "top-[30px]",
        )}
      >
        {content}
      </div>
    );
  }

  return (
    <tr>
      <td colSpan={99} className="py-12 text-center align-middle">
        <div className="flex flex-col items-center justify-center text-center">{content}</div>
      </td>
    </tr>
  );
}
