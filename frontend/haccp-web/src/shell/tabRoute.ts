/**
 * tabRoute — 화면코드와 URL 경로를 서로 변환한다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 화면 식별자는 역할 기반 kebab-case라 주소에 기술·모듈 약어를 노출하지 않는다
 *   2) 주소창에 /screen/ccp-cold-monitor 처럼 남겨 두면 즐겨찾기·새로고침으로도 같은 화면을 다시 열 수 있다
 *   3) 화면 식별자는 DB tbl_screen.scrn_cd와 같으므로 별도 모듈 추론 없이 그대로 라우팅한다
 *
 * PIPELINE[HF68] 셸 인프라
 * PIPELINE[HF49] 연관 모듈
 */

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 화면 식별자를 라우터 경로로 바꾼다 (ccp-cold-monitor → /screen/ccp-cold-monitor)
 *   2) 메뉴·탭 클릭으로 화면을 이동할 때 호출한다
 *   3) 빈 값은 홈 경로를 돌려 잘못된 탭 주소를 만들지 않는다
 */
export function routeOf(
  // 이동할 화면코드 — tbl_screen.scrn_cd와 문자 그대로 같아야 한다
  scrnCd: string,
  // 선택 쿼리 — 문서 열기 docIdx 등. 빈 값은 붙이지 않는다
  query?: Record<string, string | number | null | undefined>
): string {
  if (!scrnCd) return "/";
  const path = `/screen/${scrnCd}`;
  if (!query) return path;
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value == null || value === "") continue;
    params.set(key, String(value));
  }
  const qs = params.toString();
  return qs ? `${path}?${qs}` : path;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) URL 경로에서 화면코드를 뽑는다
 *   2) 셸이 주소 변경을 감지해 어떤 탭을 열지 정할 때 호출한다
 *   3) /screen/화면식별자 형태만 인식한다. 홈("/")이나 그 밖의 경로는 null이다
 */
export function parseRoute(
  // 현재 주소의 pathname — 쿼리스트링은 포함하지 않는다
  pathname: string
): string | null {
  const m = pathname.match(/^\/screen\/([^/]+)\/?$/);
  return m ? m[1] : null;
}
