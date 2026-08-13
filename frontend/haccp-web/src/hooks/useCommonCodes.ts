/**
 * useCommonCodes — 공통코드 조회·캐시 훅.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) DOC_STATUS·APPR_* 등 화면 하드코딩 라벨을 tbl_code 조회로 대체한다
 *   2) React Query로 mainCd별 캐시해 같은 코드를 화면마다 반복 호출하지 않는다
 *   3) subCd='*' 그룹 헤더는 옵션 목록에서 제외한다
 *
 * PIPELINE[HF102] 공통코드 훅
 * PIPELINE[HF17] 연관 모듈
 */
// 역할 — 메모·콜백 안정화 (label 참조 루프 방지)
import { useCallback, useMemo } from "react";
// 역할 — React Query 캐시 조회
import { useQuery } from "@tanstack/react-query";
// 역할 — 공통코드 API
import { getCodes } from "@/api/codeApi";
// 역할 — 전역 폴링 env (캐시 수명도 동일 계층에서 통제)
import { DASHBOARD_POLLING_MS } from "@/config/envConfig";
// 역할 — 코드 행 타입
import type { CodeRow } from "@/types/common";

/** 공통코드 staleTime — 대시보드 폴링 주기의 30배(기본 5분대) */
const CODE_STALE_MS = DASHBOARD_POLLING_MS * 30;

/** 그룹 헤더(*)를 제외한 사용 코드만 남긴다 */
function usableCodes(rows: CodeRow[] | undefined): CodeRow[] {
  return (rows ?? []).filter((row) => row.subCd !== "*");
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 대분류 코드 목록과 subCd→표시명 맵을 반환한다
 *   2) Select·StatusBadge·결재 툴바에서 호출한다
 *   3) 실패 시 빈 배열·빈 맵으로 화면이 깨지지 않게 한다
 */
export function useCommonCodes(
  // 대분류 — DOC_STATUS, APPR_ACTION 등
  mainCd: string,
  // 사용중만 조회할지 — 기본 true
  onlyUseY = true,
) {
  const query = useQuery({
    queryKey: ["common-codes", mainCd, onlyUseY ? "Y" : ""],
    queryFn: () => getCodes(mainCd, onlyUseY ? "Y" : ""),
    staleTime: CODE_STALE_MS,
    // 대분류가 비면(= 코드 컬럼이 없는 화면) 서버가 거절하므로 호출 자체를 막는다
    enabled: mainCd.trim().length > 0,
  });

  // 쿼리 data 기준 메모 — 매 렌더 새 배열이면 label·loadList effect가 무한 루프한다
  const codes = useMemo(() => usableCodes(query.data), [query.data]);
  const codeMap = useMemo(
    () => Object.fromEntries(codes.map((row) => [row.subCd, row.codeNm])),
    [codes],
  );
  // subCd → 표시명 — 참조 안정 (loadList deps에 넣어도 안전)
  const label = useCallback(
    (subCd?: string | null, fallback = "") =>
      (subCd && codeMap[subCd]) || fallback || subCd || "",
    [codeMap],
  );

  return {
    codes,
    codeMap,
    loading: query.isLoading,
    label,
  };
}
