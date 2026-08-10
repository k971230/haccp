/** 그리드 데이터 갱신 중 반투명 오버레이. 
 * PIPELINE[F86] 그리드 로딩 오버레이
 * PIPELINE[F90] 연관 모듈
 */
// 역할 — 로딩 스피너 아이콘
import { Loader2 } from "lucide-react";

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 재조회 중 기존 데이터 위 반투명 오버레이·스피너
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 재조회 중 기존 데이터 위 반투명 오버레이·스피너
export function GridLoadingOverlay({ show }: { show: boolean }) {
  if (!show) return null;
  return (
    <div className="absolute inset-0 z-[5] flex items-center justify-center bg-white/65" aria-busy="true" aria-label="불러오는 중">
      <Loader2 className="h-7 w-7 animate-spin text-brand-900" />
    </div>
  );
}
