/**
 * manualUrl — 활성 화면코드로 정적 매뉴얼 HTML 주소를 만든다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-29
 * 코멘트:
 *   1) 백엔드·SP 없이 public/manual/{scrnCd}.html 을 연다
 *   2) SCREEN_PATH 에 있는 소문자 케밥만 통과한다 — Linux 대소문자 404 를 막는다
 *   3) 빈 값·없는 화면은 null 이라 풋터 버튼을 그리지 않는다
 *
 * PIPELINE[HF64] 하단 상태 바
 */
// 역할 — 화면코드 화이트리스트. 파일명과 같은 표기다
import { SCREEN_PATH } from "@/shell/tabRoute";

/**
 * 개발자: 박승우
 * 일자: 2026-08-29
 * 코멘트:
 *   1) 풋터가 도움말 주소를 물을 때 호출한다
 *   2) undefined·null·빈 문자열은 전부 막는다
 *   3) 성공 시 /haccp/manual/ccp-htg.html 형태. 실패 시 null
 */
export function manualUrlOf(
  // 지금 활성 탭 화면코드 — 없으면 도움말을 열지 않는다
  scrnCd: string | null | undefined
): string | null {
  // 비었을 때(= 탭이 없거나 홈 직후) 주소를 만들지 않는다
  if (!scrnCd) return null;
  // Linux 는 대소문자를 가른다. 정본 키와 맞추기 위해 소문자로 고정한다
  const cd = scrnCd.toLowerCase();
  // SCREEN_PATH 에 없을 때(= 화면이 아닌 값) 가짜 파일을 열지 않는다
  if (!(cd in SCREEN_PATH)) return null;
  return `${import.meta.env.BASE_URL}manual/${cd}.html`;
}
