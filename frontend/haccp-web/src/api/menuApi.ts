/**
 * menuApi — 권한 반영 메뉴 목록 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) /api/v1/menu/list 하나만 감싼다 — 회사코드·권한그룹은 서버가 JWT에서 읽으므로 파라미터가 없다
 *   2) 서버는 평면 목록을 주고, 트리 조립은 SideMenu.buildTree가 담당한다
 *   3) 조회권한 없는 화면은 응답에 아예 오지 않는다 — 프론트에서 다시 걸러낼 필요가 없다
 *
 * PIPELINE[HF16] API 레이어
 */
// 역할 — 일반 타임아웃 Axios 인스턴스
import { http } from "./http";
// 역할 — 공통 응답 타입
import type { CommonResponse } from "@/types/common";

/** 메뉴 1건 — 백엔드 MenuRow와 동일 구조 */
export interface MenuRow {
  idx: number;
  /** 메뉴코드 — 트리 노드 식별자 */
  menuCd: string;
  /** 메뉴명 — 사이드 메뉴에 보이는 문구 */
  menuNm: string;
  /** 상위 메뉴코드 — null이면 최상위(대분류) 노드 */
  hMenuCd: string | null;
  /** 연결 화면코드 — null이면 분류 노드라 클릭해도 화면이 열리지 않는다 */
  scrnCd: string | null;
  /** 모듈 구분 — 화면이 붙은 메뉴만 값이 있다 */
  moduleCd: string | null;
  /** 정렬코드 — 대(1~9)*1000+중(0~9)*100+소(0~99), 예: 1001·2101 */
  sortNo: number | null;
  readYn: string;
  writeYn: string;
  modifyYn: string;
  deleteYn: string;
  printYn: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 사용자의 권한이 반영된 메뉴 평면 목록을 조회한다
 *   2) 셸이 마운트될 때 React Query로 1회 호출하고 60초간 캐시한다
 *   3) 성공 시 메뉴 배열을 반환하고, 권한이 없으면 빈 배열이다
 */
export async function getMenu(): Promise<MenuRow[]> {
  const { data } = await http.get<CommonResponse<MenuRow[]>>("/api/v1/menu/list");
  return data.data;
}
