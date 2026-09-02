/**
 * AuditLogRule — 변경 감사 로그 화면 설정(컬럼·조회·트리).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) LogPageShell에 넘길 설정 한 덩어리다 — 컬럼·pref 키·기간 기본값·조회 API를 갖는다
 *   2) 좌측 메뉴 트리에서 리프를 고르면 서버 필터, 폴더면 기간 전건 후 하위 화면코드로 FE 필터한다
 *   3) persistId는 기존 값(log-audit-log)을 승계한다
 *
 * PIPELINE[HF98] 감사 로그 규칙
 */
// 역할 — 감사 이력 조회 API
import { listAuditLog } from "@/api/sys/auditLogApi";
// 역할 — 일시 표시 포맷(분 단위)
import { fmtDateTimeMinute } from "@/utils/date";
// 역할 — 셸 설정 계약·행 타입·트리 헬퍼
import { collectScrnCds, type LogRow, type LogRule } from "@/components/layout/LogPageShell";

/** 기간 기본값 — 오늘부터 30일 전까지 */
const RANGE_DAYS = 30;

export const AUDIT_LOG_RULE: LogRule = {
  // 화면코드 — 권한·그리드 pref·탭 key
  scrnCd: "audit-log",
  // 그리드 열 설정 저장 키 — 기존 값 승계
  persistId: "log-audit-log",
  // 그리드·패널 제목
  title: "변경 감사 로그",
  // 좌측 패널 제목
  treeHead: "메뉴 트리",
  // 좌측 트리 — 관리자 메뉴 계층
  treeKind: "menu",
  rangeDays: RANGE_DAYS,
  // 행위 컬럼 코드 대분류 — 등록/수정/삭제
  codeGroup: "AUDIT_RESULT",

  /** 컬럼 — 행위는 공통코드 라벨로 표시한다 */
  buildColumns: (codeMap, codeOptions) => [
    { field: "insDt", header: "기록 일시", width: 140, required: true },
    { field: "menuNm", header: "대상 메뉴", width: 140 },
    {
      field: "actionCd",
      header: "행위",
      width: 110,
      type: "code",
      codeMap,
      codeOptions,
    },
    { field: "userId", header: "작업자 ID", width: 110 },
    { field: "userNm", header: "작업자명", width: 110 },
    { field: "ipAddr", header: "접속 IP", width: 130 },
  ],

  /** 조회 — 리프는 서버 필터(화면코드), 폴더는 하위 화면코드로 FE 필터한다 */
  fetchRows: async ({ fromDt, toDt, selNode }) => {
    // 리프 노드일 때(= 하위 없음) 화면코드를 서버 조건으로 넘긴다
    const menuKey =
      selNode && selNode.children.length === 0
        ? String(selNode.scrnCd ?? "").trim()
        : "";
    const raw = await listAuditLog({ fromDt, toDt, menuKey });
    let rows = raw.map((r): LogRow => ({
      ...r,
      insDt: fmtDateTimeMinute(String(r.insDt ?? "")) || r.insDt,
    }));
    // 폴더 선택일 때(= menuKey 없음) 하위 화면코드로 걸러낸다
    if (selNode && !menuKey) {
      const keys = new Set(collectScrnCds(selNode));
      rows = rows.filter((r) => keys.has(String(r.scrnCd ?? "").trim()));
    }
    return rows;
  },
};
