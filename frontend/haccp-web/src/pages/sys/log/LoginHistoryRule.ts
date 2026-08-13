/**
 * LoginHistoryRule — 로그인 이력 화면 설정(컬럼·조회·트리).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) LogPageShell에 넘길 설정 한 덩어리다 — 컬럼·pref 키·기간 기본값·조회 API를 갖는다
 *   2) 좌측 트리는 사용자 평면 목록이며 선택값이 곧 userId 필터다
 *   3) persistId는 기존 값(log-login-history)을 승계한다
 *
 * PIPELINE[HF98] 로그인 이력 규칙
 */
// 역할 — 로그인 이력 조회 API
import { listLoginHistory } from "@/api/sys/logApi";
// 역할 — 일시 표시 포맷(분 단위)
import { fmtDateTimeMinute } from "@/utils/date";
// 역할 — 셸 설정 계약·행 타입
import { TREE_ALL, type LogRow, type LogRule } from "./LogPageShell";

/** 기간 기본값 — 오늘부터 30일 전까지 */
const RANGE_DAYS = 30;

export const LOGIN_HISTORY_RULE: LogRule = {
  // 화면코드 — 권한·그리드 pref·탭 key
  scrnCd: "login-history",
  // 그리드 열 설정 저장 키 — 기존 값 승계
  persistId: "log-login-history",
  // 그리드·패널 제목
  title: "로그인 이력",
  // 좌측 패널 제목
  treeHead: "사용자",
  // 좌측 트리 — 사용자 평면 목록
  treeKind: "user",
  rangeDays: RANGE_DAYS,
  // 결과 컬럼 코드 대분류 — 성공/실패/로그아웃
  codeGroup: "login-result",

  /** 컬럼 — 결과는 공통코드 라벨로 표시한다 */
  buildColumns: (codeMap, codeOptions) => [
    { field: "loginDt", header: "로그인 일시", width: 140 },
    { field: "logoutDt", header: "로그아웃 일시", width: 140 },
    { field: "userId", header: "사용자 ID", width: 110 },
    { field: "userNm", header: "사용자명", width: 110 },
    {
      field: "resultCd",
      header: "결과",
      width: 80,
      type: "code",
      codeMap,
      codeOptions,
    },
    { field: "ipAddr", header: "접속 IP", width: 130 },
  ],

  /** 조회 — 트리에서 고른 사용자만, 일시는 분 단위로 잘라 보여준다 */
  fetchRows: async ({ fromDt, toDt, selKey }) => {
    const rows = await listLoginHistory({
      fromDt,
      toDt,
      // 「전체」면 아이디 필터 없이 기간 전건
      userId: selKey === TREE_ALL ? "" : selKey,
    });
    return rows.map((r): LogRow => ({
      ...r,
      loginDt: fmtDateTimeMinute(String(r.loginDt ?? "")) || r.loginDt,
      logoutDt: fmtDateTimeMinute(String(r.logoutDt ?? "")) || r.logoutDt,
    }));
  },
};
