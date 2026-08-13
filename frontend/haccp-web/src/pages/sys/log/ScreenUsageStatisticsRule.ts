/**
 * ScreenUsageStatisticsRule — 화면 이용 통계 화면 설정(컬럼·조회·트리).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) LogPageShell에 넘길 설정 한 덩어리다 — 컬럼·pref 키·기간 기본값·조회 API를 갖는다
 *   2) 좌측 메뉴 트리에서 리프(화면코드)는 서버 필터, 폴더는 하위 화면코드로 FE 필터한다
 *   3) persistId는 기존 값(log-screen-usage-statistics)을 승계한다
 *
 * PIPELINE[HF98] 화면 이용 통계 규칙
 */
// 역할 — 화면 이용 통계 조회 API
import { listScreenUsage } from "@/api/sys/logApi";
// 역할 — 셸 설정 계약·행 타입·트리 헬퍼
import { collectScrnCds, type LogRow, type LogRule } from "./LogPageShell";

/** 기간 기본값 — 오늘부터 30일 전까지 */
const RANGE_DAYS = 30;

/** 집계일 YYYYMMDD → YYYY-MM-DD 표시 */
function toDisplayDate(ymd: string): string {
  return ymd.length === 8 ? `${ymd.slice(0, 4)}-${ymd.slice(4, 6)}-${ymd.slice(6)}` : ymd;
}

export const SCREEN_USAGE_RULE: LogRule = {
  // 화면코드 — 권한·그리드 pref·탭 key
  scrnCd: "screen-usage-statistics",
  // 그리드 열 설정 저장 키 — 기존 값 승계
  persistId: "log-screen-usage-statistics",
  // 그리드·패널 제목
  title: "화면 이용 통계",
  // 좌측 패널 제목
  treeHead: "메뉴 트리",
  // 좌측 트리 — 관리자 메뉴 계층
  treeKind: "menu",
  rangeDays: RANGE_DAYS,
  // 코드 컬럼 없음 — 공통코드 조회를 하지 않는다
  codeGroup: "",

  /** 컬럼 — 집계 수치는 전부 number 정렬 */
  buildColumns: () => [
    { field: "statDt", header: "집계일", width: 100 },
    { field: "menuCd", header: "메뉴코드", width: 140 },
    { field: "menuNm", header: "메뉴명", width: 160 },
    { field: "pvCnt", header: "페이지뷰(PV)", width: 100, type: "number" },
    { field: "uvCnt", header: "유저뷰(UV)", width: 100, type: "number" },
    { field: "sessCnt", header: "세션수", width: 80, type: "number" },
    { field: "ipCnt", header: "IP 수", width: 80, type: "number" },
  ],

  /** 조회 — 리프는 화면코드로 서버 필터, 폴더는 하위 화면코드 집합으로 FE 필터한다 */
  fetchRows: async ({ fromDt, toDt, selNode }) => {
    // 리프(화면) 노드일 때만 scrnCd가 있다 — 폴더는 빈 값으로 전건 조회
    const scrnCd = String(selNode?.scrnCd ?? "").trim();
    const raw = await listScreenUsage({ fromDt, toDt, scrnCd });
    let rows = raw.map((r): LogRow => ({
      ...r,
      statDt: toDisplayDate(String(r.statDt ?? "")),
      // 통계 SP가 메뉴코드를 못 채우면 화면코드로 대체 표시
      menuCd: r.menuCd ?? r.scrnCd,
    }));
    if (selNode && !scrnCd) {
      const cds = new Set(collectScrnCds(selNode));
      rows = rows.filter((r) => cds.has(String(r.scrnCd ?? r.menuCd ?? "")));
    }
    return rows;
  },
};
