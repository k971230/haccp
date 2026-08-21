/**
 * useCommonCodes — 공통코드 조회·캐시 훅.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) DOC_STATUS·APPR_*·sys-yn 등 화면 하드코딩 라벨을 tbl_code 조회로 대체한다
 *   2) React Query로 mainCd별 캐시해 같은 코드를 화면마다 반복 호출하지 않는다
 *   3) subCd='*' 그룹 헤더는 옵션 목록에서 제외한다. sys-yn 은 레거시 Y/N 별칭을 훅이 붙인다
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

/** 사용양식 구분 대분류 — 공통코드 관리(sys-yn). src-ty(불러오기 팝업)와 다르다 */
export const SYS_YN_MAIN_CD = "sys-yn" as const;

/** 구분 열 badge — 문서주기·사용양식·HTML양식 목록. 레거시 Y/N 별칭 포함 */
export const SYS_YN_BADGE = {
  sys: "blue",
  usr: "green",
  Y: "blue",
  N: "green",
} as const;

/** 예/아니오 라디오 문구 — 공통코드 관리(judge-yn). y=예, n=아니오 */
export const JUDGE_YN_MAIN_CD = "judge-yn" as const;

/** 적합/부적합 라디오 문구 — 공통코드 관리(JUDGE_PF). P=적합, F=부적합 */
export const JUDGE_PF_MAIN_CD = "JUDGE_PF" as const;

/** HTML 양식 입력유형 — 공통코드 관리(html-input-ty). radio·radio-num·radio-text·num·text */
export const HTML_INPUT_TY_MAIN_CD = "html-input-ty" as const;

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 공통코드 맵에 레거시 Y/N 별칭을 붙인다
 *   2) 옛 행이 Y/N 이어도 그리드가 시스템제공/사용자추가로 보이게 한다
 *   3) sys/usr 문구가 아직 안 왔을 때(= 코드 미로드) 별칭을 붙이지 않는다
 */
export function withSysYnLegacyAliases(
  // sys-yn subCd → codeNm. * 헤더는 훅이 이미 뺀다
  codeMap: Record<string, string>,
): Record<string, string> {
  const next = { ...codeMap };
  if (codeMap.sys) next.Y = codeMap.sys;
  if (codeMap.usr) next.N = codeMap.usr;
  return next;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 사용자추가(usr·레거시 N)인지 판정한다 — 문구는 공통코드, 삭제 가능만 이 함수
 *   2) 삭제 가능 판정·구분 badge 색 결정에서 호출한다
 *   3) 값이 비었을 때(= 서버가 구분을 안 준 옛 응답) 시스템제공으로 보아 삭제를 막는다
 */
export function isCompanyForm(
  // 서버 sysYn — sys/usr 또는 레거시 Y/N
  sysYn?: string | null,
): boolean {
  const value = String(sysYn ?? "").toLowerCase();
  return value === "usr" || value === "n";
}

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
  const codeMap = useMemo(() => {
    const map = Object.fromEntries(codes.map((row) => [row.subCd, row.codeNm]));
    // sys-yn일 때(= 사용양식 구분) 옛 Y/N 행도 시스템제공/사용자추가로 보이게 한다
    return mainCd === SYS_YN_MAIN_CD ? withSysYnLegacyAliases(map) : map;
  }, [codes, mainCd]);
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
