/**
 * codeApi — 공통코드 조회 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) /api/v1/code/list 를 감싼다 — 화면의 모든 콤보는 이 한 경로에서 값을 얻는다
 *   2) 응답에는 플랫폼 표준코드와 업체 고유코드가 합쳐져 오고, 겹치면 업체 값이 남는다(서버 판정)
 *   3) 사용여부 기본값은 'Y'다. 코드 관리 화면처럼 사용중지 코드까지 봐야 할 때만 빈 값을 넘긴다
 *
 * PIPELINE[HF17] API 레이어
 */
// 역할 — 일반 타임아웃 Axios 인스턴스
import { http } from "./http";
// 역할 — 공통 응답·공통코드 타입
import type { CodeRow, CommonResponse } from "@/types/common";

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 대분류 기준으로 공통코드 목록을 조회한다
 *   2) 화면 진입 시 콤보를 채울 때 호출한다
 *   3) 성공 시 코드 배열을 반환하고, 해당 대분류가 없으면 빈 배열이다
 */
export async function getCodes(
  // 대분류 코드 — 콤보 그룹 식별자(예: DOC_STATUS). 서버가 부분 일치로 비교하므로 정확히 넘긴다
  mainCd: string,
  // 사용여부 필터 — 기본 'Y'(사용중만). 빈 문자열이면 사용중지 코드까지 포함한다
  useYn: string = "Y"
): Promise<CodeRow[]> {
  const { data } = await http.get<CommonResponse<CodeRow[]>>("/api/v1/code/list", {
    params: { mainCd, useYn },
  });
  return data.data;
}
