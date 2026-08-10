/** 그리드 초기 로딩 스켈레톤. 
 * PIPELINE[F87] 그리드 스켈레톤
 * PIPELINE[F90] 연관 모듈
 */
// 역할 — className 병합
import { cn } from "@/lib/cn";

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 초기 로딩 시 행·열 개수만큼 pulse 스켈레톤 표시
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 초기 로딩 시 행·열 개수만큼 pulse 스켈레톤 표시
export function GridSkeleton({ rows = 6, cols = 5 }: { rows?: number; cols?: number }) {
  return (
    <div className="flex min-h-[120px] flex-1 flex-col gap-1.5 p-2" aria-hidden>
      {Array.from({ length: rows }).map((_, r) => (
        <div key={r} className="flex gap-2">
          {Array.from({ length: cols }).map((__, c) => (
            <span
              // 행 _key 또는 busy 키
              // updateCell·run·포커스 식별에 사용
              key={c}
              // 추가 Tailwind/CSS 클래스
              // 기본 스타일 위에 병합(cn)
              className={cn("h-5 flex-1 animate-pulse rounded bg-slate-200")}
              style={{ maxWidth: `${50 + (c % 3) * 20}%` }}
            />
          ))}
        </div>
      ))}
    </div>
  );
}
