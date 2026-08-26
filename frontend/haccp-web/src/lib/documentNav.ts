/**
 * documentNav — 문서 목록 행 → 작성/편집 화면 경로.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 홈·문서함에서 최근 문서를 열 때 tmplCd·docKind로 대상 화면을 고른다
 *   2) 자사 HTML 양식은 접두로, HWP 문서형은 단일 작성 화면(hwp-write)으로 보낸다
 *   3) 알 수 없는 양식은 문서함으로 보낸다
 *
 * PIPELINE[HF82] 문서 네비게이션
 */
// 역할 — 화면코드 → URL
import { routeOf } from "@/shell/tabRoute";
// 역할 — 양식 유형(HWP/HTML) 판별
import { isHwpKind } from "@/lib/docKind";

/** 자사 양식 접두 → 작성 화면코드 — 코드가 가변(NNN)이라 표에 못 넣는다 */
const TMPL_PREFIX_SCREEN: Array<{ prefix: string; scrnCd: string }> = [
  // 위생공정 양식 작성 — html_hyg_prc_001 이상. 예시 000 은 작성 대상이 아니다
  { prefix: "html_hyg_prc_", scrnCd: "hyg-process" },
  // CCP 검증점검 양식 작성 — tml_ccp_chk_001 이상
  { prefix: "tml_ccp_chk_", scrnCd: "ccp-verify" },
  // CCP 모니터링일지 작성 — 포장·가열·금속검출
  { prefix: "tml_ccp_pkg_", scrnCd: "ccp-pkg" },
  { prefix: "tml_ccp_htg_", scrnCd: "ccp-htg" },
  { prefix: "tml_ccp_mtl_", scrnCd: "ccp-mtl" },
];

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 접두로 작성 화면을 찾는다 — 자사 양식은 코드 뒤 3자리가 회사마다 다르다
 *   2) routeForDocument 가 정확 매핑에 실패했을 때 호출한다
 *   3) 예시(000)는 작성 화면이 없으므로 제외한다
 */
function screenByPrefix(
  // 문서 양식코드
  tmplCd: string
): string | undefined {
  const cd = (tmplCd || "").trim();
  // 예시 000 일 때(= 작성 대상 아님) 문서함으로 보낸다
  if (cd.endsWith("_000")) return undefined;
  return TMPL_PREFIX_SCREEN.find((row) => cd.startsWith(row.prefix))?.scrnCd;
}

export interface DocumentNavInput {
  // 문서 대리키 — 쿼리 docIdx
  docIdx: number;
  // 양식코드 — 화면 매핑
  tmplCd: string;
  // DB | HWP
  docKind?: string | null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 문서 행을 작성 화면 URL로 바꾼다 (?docIdx=)
 *   2) 홈 최근 문서·문서함 「작성화면」에서 호출한다
 *   3) 매핑 실패 시 문서함으로 보내고 같은 docIdx를 넘긴다
 */
export function routeForDocument(
  // 열 문서 — idx·양식·종류
  row: DocumentNavInput
): string {
  // 자사 HTML 양식은 접두로 작성 화면을 찾는다
  const scrn = screenByPrefix(row.tmplCd);
  if (scrn) {
    return routeOf(scrn, { docIdx: String(row.docIdx) });
  }
  // HWP 문서형은 작성 화면이 하나뿐이다 — 양식코드와 무관하게 그쪽으로 보낸다
  if (isHwpKind(row.docKind)) {
    return routeOf("hwp-write", { docIdx: String(row.docIdx) });
  }
  return routeOf("document-inbox", { docIdx: String(row.docIdx) });
}
