/**
 * useDocIdxQuery — URL ?docIdx= 로 전달된 문서 대리키를 읽는다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 홈·문서함 deep-link가 작성 화면에 넘긴 문서 idx를 파싱한다
 *   2) 목록 로드 후 해당 행을 선택할 때 쓴다
 *   3) 숫자가 아니면 null — 잘못된 쿼리는 무시한다
 *
 * PIPELINE[HF82] 문서 deep-link
 */
// 역할 — 주소 쿼리
import { useMemo } from "react";
import { useSearchParams } from "react-router-dom";

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) searchParams.docIdx를 number | null 로 반환한다
 *   2) 작성 화면·문서함 마운트 시 호출한다
 *   3) 파싱 실패 시 null
 */
export function useDocIdxQuery(): number | null {
  const [params] = useSearchParams();
  return useMemo(() => {
    const raw = params.get("docIdx");
    if (!raw) return null;
    const n = Number(raw);
    return Number.isFinite(n) && n > 0 ? n : null;
  }, [params]);
}
