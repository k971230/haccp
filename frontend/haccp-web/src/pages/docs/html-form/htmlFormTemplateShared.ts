/**
 * htmlFormTemplateShared — HTML 양식 원본 좌측 그리드 공통.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 공정점검·CCP 검증점검·포장일지 기준관리가 같은 목록 규칙을 쓴다
 *   2) 화면별 양식코드 접두·제목만 Rule에 둔다
 *   3) JSX/API는 없다
 *
 * PIPELINE[HF130] HTML양식 원본 공통 규칙
 */
// 역할 — 그리드 컬럼
import type { GridColumn } from "@/types/grid";
// 역할 — 그리드 잠금 규칙
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 구분 열 badge
import { SYS_YN_BADGE } from "@/hooks/useCommonCodes";
// 역할 — 양식 목록 행
import type { HtmlFormVerRow } from "@/api/docs/htmlFormApi";

/** pending 행 키 — DB 미기록 */
export const PENDING_KEY = "pending";

/** pending 센티널 순번 — 서버 자사 행은 1 */
export const PENDING_VER_NO = -1;

export type VerListRow = HtmlFormVerRow & {
  // 서버 양식명 — 셀만 바꾸면 savedVerNm과 달라져 미저장
  savedVerNm?: string;
  // 서버 사용여부 — 셀만 바꾸면 savedUseYn과 달라져 미저장
  savedUseYn?: string;
  // 행추가 원본. 항상 표준 0
  srcVerNo?: number;
  // pending 행만 C. 저장행은 없음
  _rowState?: "C" | "U";
};

/** 예시 양식(000)이면 true — 양식명 잠금 */
export function isStdVerRow(
  row: Pick<VerListRow, "tmplCd" | "verNo" | "lockedYn"> | null | undefined,
  stdTmplCd: string,
): boolean {
  if (!row) return false;
  const cd = (row.tmplCd || "").trim();
  return cd === stdTmplCd || Number(row.verNo) === 0 || row.lockedYn === "Y";
}

/** 양식코드·구분·작성자는 잠금. 표준은 양식명도 잠금 */
export function htmlFormListGridRules(stdTmplCd: string): ScreenGridRules {
  return {
    alwaysReadonly: ["tmplCd", "sysYn", "insNm", "insDt"],
    isRowEditLocked: (row) => isStdVerRow({
      tmplCd: String(row.tmplCd ?? ""),
      verNo: Number(row.verNo ?? 0),
      lockedYn: String(row.lockedYn ?? ""),
    }, stdTmplCd),
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 다음 자사 양식코드를 제안한다 — prefix + 001 …
 *   2) 행추가 pending 표시용. 최종 번호는 SP가 전역 MAX로 확정
 *   3) 000은 건너뛰고 빈 목록이면 001. 사용양식은 접두 hwp_usr_
 */
export function nextUsrTmplCd(
  // 접두 — html_hyg_prc_ / html_ccp_chk_ / hwp_usr_
  prefix: string,
  // 현재 그리드 행
  rows: Array<{ tmplCd?: string | null }>,
): string {
  let max = 0;
  const escaped = prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const pattern = new RegExp(`^${escaped}(\\d+)$`, "i");
  for (const row of rows) {
    const matched = pattern.exec(String(row.tmplCd ?? "").trim());
    if (!matched) continue;
    const n = Number(matched[1]);
    if (n > 0) max = Math.max(max, n);
  }
  return `${prefix}${String(max + 1).padStart(3, "0")}`;
}

/** pending 행이면 true */
export function isPendingRow(row: Pick<VerListRow, "verNo"> & { _rowState?: string } | null | undefined): boolean {
  return (row?._rowState === "C") || row?.verNo === PENDING_VER_NO;
}

/** 그리드 행 키 — pending은 고정 문자열, 저장행은 tmplCd */
export function verRowKey(row: Pick<VerListRow, "tmplCd" | "verNo"> & { _rowState?: string }): string {
  return isPendingRow(row) ? PENDING_KEY : (row.tmplCd || String(row.verNo));
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 좌측 양식 그리드 컬럼을 만든다. 순서 양식코드·양식명·구분·사용여부·작성자·작성일시
 *   2) Page가 useMemo로 호출한다. field 코드는 포장·가열·금속이 같다
 *   3) 적용 라디오는 없다. 주기는 문서주기 화면. 사용여부는 회사 양식
 */
export function buildListColumns(
  // 양식명·사용여부 셀 가능
  canEdit: boolean,
  // sys-yn 문구
  sysYnMap: Record<string, string>,
  // use-yn 콤보. 값은 Y/N
  useOpts: { value: string; label: string }[],
): GridColumn<VerListRow>[] {
  return [
    {
      // 양식코드 — 예시는 *000. 자사는 저장 시 SP 채번
      field: "tmplCd",
      header: "양식코드",
      width: 140,
      editable: false,
    },
    {
      // 양식명 — 사용자 양식은 언제든. 표준만 잠금
      field: "verNm",
      header: "양식명",
      width: 140,
      editable: canEdit,
      required: true,
    },
    {
      // 구분 — 시스템/사용자
      field: "sysYn",
      header: "구분",
      width: 88,
      type: "code",
      editable: false,
      codeMap: sysYnMap,
      badge: SYS_YN_BADGE,
    },
    {
      // 사용여부 — 회사 양식(ct.use_yn). 표준은 항상 N·잠금. 신규는 Y
      field: "useYn",
      header: "사용여부",
      width: 88,
      type: "code",
      editable: canEdit,
      codeOptions: useOpts,
      codeMap: Object.fromEntries(useOpts.map((opt) => [opt.value, opt.label])),
      badge: { Y: "green", N: "gray" },
    },
    {
      // 작성자 — tbl_user.user_nm. 표준·pending은 빈칸
      field: "insNm",
      header: "작성자",
      width: 88,
      editable: false,
    },
    {
      // 작성일시 — SP가 YYYY-MM-DD. 표준·pending은 빈칸
      field: "insDt",
      header: "작성일시",
      width: 110,
      type: "date",
      editable: false,
    },
  ];
}
