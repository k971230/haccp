/**
 * prefApi — 사용자별 그리드 열 설정 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) /api/v1/pref/grid/{list,save} 를 감싼다 — 열 너비·표시여부를 사용자별로 보관한다
 *   2) mes-web과 다른 점 — 화면 단위로 목록을 한 번에 받는다(한 화면에 그리드가 여럿인 구조가 많다)
 *   3) prefJson을 빈 문자열로 저장하면 설정 초기화(서버가 행 삭제)다. 별도 삭제 API가 없는 이유다
 *
 * PIPELINE[HF18] API 레이어
 */
// 역할 — 일반 타임아웃 Axios 인스턴스
import { http } from "./http";
// 역할 — 공통 응답 타입
import type { CommonResponse } from "@/types/common";

/** 그리드 열 설정 1건 — 백엔드 GridPrefRow와 동일 구조 */
export interface GridPrefRow {
  idx: number;
  scrnCd: string;
  /** 그리드 식별자 — 편집 그리드의 persistId */
  gridId: string;
  /** 열 설정 JSON 원문 — 구조는 그리드 컴포넌트가 정하고 서버는 해석하지 않는다 */
  prefJson: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 해당 화면에 저장된 그리드 열 설정 목록을 조회한다
 *   2) 업무 화면이 마운트될 때 1회 호출한다
 *   3) 저장 이력이 없으면 빈 배열이다 — 이때 그리드는 컬럼 정의의 기본값을 쓴다
 */
export async function getGridPrefs(
  // 화면코드 — 이 화면에 속한 그리드 설정만 받는다
  scrnCd: string
): Promise<GridPrefRow[]> {
  const { data } = await http.get<CommonResponse<GridPrefRow[]>>("/api/v1/pref/grid/list", {
    params: { scrnCd },
  });
  return data.data ?? [];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 화면·그리드 식별자로 pref JSON 한 건을 조회한다
 *   2) useMesTable이 persistId별 열 설정을 로드할 때 호출한다
 *   3) 없으면 빈 문자열을 반환해 컬럼 기본값을 쓰게 한다
 */
export async function getGridPref(
  // 화면코드
  scrnCd: string,
  // 그리드 persistId
  gridId: string
): Promise<string> {
  const rows = await getGridPrefs(scrnCd);
  return rows.find((row) => row.gridId === gridId)?.prefJson ?? "";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 그리드 열 설정을 저장하거나, 빈 JSON이면 초기화한다
 *   2) 사용자가 열 너비·표시여부를 바꿔 저장할 때 호출한다
 *   3) 같은 키로 여러 번 호출해도 결과가 같다(서버 업서트)
 */
export async function saveGridPref(
  // 화면코드 — (아이디, 화면, 그리드) 조합이 저장 키다
  scrnCd: string,
  // 그리드 식별자 — 편집 그리드의 persistId
  gridId: string,
  // 열 설정 JSON 원문 — 빈 문자열이면 저장값을 지워 기본값으로 되돌린다
  prefJson: string
): Promise<void> {
  await http.put<CommonResponse<null>>("/api/v1/pref/grid/save", { scrnCd, gridId, prefJson });
}
