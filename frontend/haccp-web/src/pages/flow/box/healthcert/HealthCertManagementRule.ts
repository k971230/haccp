/**
 * HealthCertManagementRule — 보건증 화면 컬럼·식별자.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) Page 는 렌더·API 만. 컬럼·검색 거름·캘린더 칩은 여기
 *   2) persistId 는 폴더를 옮겨도 고정
 *   3) 상태 콤보는 공통코드 HC_STATUS. 검색어는 사원명만
 *
 * PIPELINE[HF215] 보건증 규칙
 */
import type { GridColumn } from "@/types/grid";
import type { ScreenGridRules } from "@/shell/gridRules/types";
import type { HealthCertCal, HealthCertEmp, HealthCertHist } from "@/api/flow/healthCertApi";
import { todayYmd } from "@/lib/docDateTime";

export const SCRN_CD = "health-cert-management" as const;
export const EMP_PERSIST_ID = "health-cert-emp" as const;
export const HIST_PERSIST_ID = "health-cert-hist" as const;
export const SPLIT_KEY = "haccp-split-health-cert-30";

/** 좌 사원 — 조회만. 등록은 우 행추가 팝업 */
export const EMP_RULES: ScreenGridRules = {};
/** 우 이력 — 셀 수정 없음. 추가는 팝업, 삭제는 체크 행 */
export const HIST_RULES: ScreenGridRules = {};

/** 검색 상태 공통코드 — 빈값=전체. sub_cd 는 거름 값과 같다 */
export const HC_STATUS_MAIN_CD = "HC_STATUS" as const;
export const EMP_STATUS_ALL = "";
export const EMP_STATUS_DUE = "DUE";
export const EMP_STATUS_EXPIRED = "EXPIRED";

/** YYYYMMDD 에 일수를 더한다 — 임박 창 끝 */
function addDaysYmd(ymd: string, days: number): string {
  const y = Number(ymd.slice(0, 4));
  const m = Number(ymd.slice(4, 6));
  const d = Number(ymd.slice(6, 8));
  const dt = new Date(y, m - 1, d);
  dt.setDate(dt.getDate() + days);
  const yy = dt.getFullYear();
  const mm = String(dt.getMonth() + 1).padStart(2, "0");
  const dd = String(dt.getDate()).padStart(2, "0");
  return `${yy}${mm}${dd}`;
}

/** 캘린더 칩 종류 — 등록·만료는 항상, 1·2·3차는 그 사이만 */
export type HealthCertCalKind = "reg" | "expire" | "a1" | "a2" | "a3";

/** 같은 날·같은 사원 한 행 */
export type HealthCertCalChip = {
  userId: string;
  userNm: string;
  kinds: HealthCertCalKind[];
};

export const CAL_CHIP_LABEL: Record<HealthCertCalKind, string> = {
  reg: "등록",
  expire: "만료",
  a1: "1차",
  a2: "2차",
  a3: "3차",
};

/** 일정 캘린더 TASK_TONE_CLASS 와 같은 문법 — 진한 테두리 + 300 틴트 + 검정 글씨 */
export const CAL_CHIP_TONE: Record<HealthCertCalKind, string> = {
  reg: "border border-blue-500 bg-blue-300 text-slate-900",
  expire: "border border-rose-500 bg-rose-300 text-slate-900",
  a1: "border border-emerald-500 bg-emerald-300 text-slate-900",
  a2: "border border-amber-500 bg-amber-300 text-slate-900",
  a3: "border border-orange-500 bg-orange-300 text-slate-900",
};

/** 헤더 범례 도트 — CalendarPage 와 같은 400 원 */
export const CAL_CHIP_DOT: Record<HealthCertCalKind, string> = {
  reg: "bg-blue-400",
  expire: "bg-rose-400",
  a1: "bg-emerald-400",
  a2: "bg-amber-400",
  a3: "bg-orange-400",
};

/** 범례 표시 순서 — 등록·만료·1·2·3차 */
export const CAL_CHIP_LEGEND: HealthCertCalKind[] = ["reg", "expire", "a1", "a2", "a3"];

const TONE_ORDER: HealthCertCalKind[] = ["expire", "reg", "a3", "a2", "a1"];

/**
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) pill 색은 한 줄에 하나. 일정 캘린더와 같다
 *   2) 만료가 있으면 빨강. 등록만이면 파랑. 1·2·3차는 초록·노랑·주황
 *   3) 등록+만료 같은 날은 만료 빨강. 글자는 calChipLabel 이 둘 다 남긴다
 */
export function calChipTone(
  // 한 행의 배지 종류
  kinds: HealthCertCalKind[],
): string {
  const k = TONE_ORDER.find((x) => kinds.includes(x));
  return k ? CAL_CHIP_TONE[k] : "";
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) pill 글자 — 종류 라벨을 · 로 이은 뒤 사원명
 *   2) 같은 날 등록·만료면 '등록·만료 김보건'
 *   3) title 과 본문이 같다
 */
export function calChipLabel(
  // 칸의 사원 칩
  chip: HealthCertCalChip,
): string {
  const kinds = chip.kinds.map((k) => CAL_CHIP_LABEL[k]).join("·");
  return kinds ? `${kinds} ${chip.userNm}` : chip.userNm;
}

const KIND_ORDER: HealthCertCalKind[] = ["reg", "expire", "a1", "a2", "a3"];

function ymd8(v: string | undefined): string {
  const s = String(v ?? "").replace(/-/g, "");
  return s.length === 8 ? s : "";
}

function alarmN(v: number | undefined, fallback: number): number {
  return v && v > 0 ? v : fallback;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 등록·만료는 해당 칸에 항상 둔다. 같으면 한 행
 *   2) 1·2·3차는 만료-N일. 등록 < 알림 < 만료 일 때만
 *   3) 칸 맵은 ymd → 사원 칩. 페이지가 렌더만 한다
 */
export function buildCalChipMap(
  // 사원별 최신 이력
  rows: HealthCertCal[],
  // 회사 알림 일수 — can. 없으면 30·7·1
  alarmDays: { alarmDay1?: number; alarmDay2?: number; alarmDay3?: number },
): Map<string, HealthCertCalChip[]> {
  const n1 = alarmN(alarmDays.alarmDay1, 30);
  const n2 = alarmN(alarmDays.alarmDay2, 7);
  const n3 = alarmN(alarmDays.alarmDay3, 1);
  const byDayUser = new Map<string, Map<string, HealthCertCalChip>>();
  const put = (ymd: string, userId: string, userNm: string, kind: HealthCertCalKind) => {
    if (!ymd || !userId) return;
    let people = byDayUser.get(ymd);
    if (!people) {
      people = new Map();
      byDayUser.set(ymd, people);
    }
    const cur = people.get(userId);
    if (cur) {
      if (!cur.kinds.includes(kind)) cur.kinds.push(kind);
      return;
    }
    people.set(userId, { userId, userNm, kinds: [kind] });
  };
  for (const r of rows) {
    const userId = String(r.userId ?? "");
    const userNm = String(r.userNm ?? userId);
    const reg = ymd8(r.regDt);
    const exp = ymd8(r.expireDt);
    if (reg) put(reg, userId, userNm, "reg");
    if (exp) put(exp, userId, userNm, "expire");
    if (reg && exp) {
      const alarms: [HealthCertCalKind, number][] = [
        ["a1", n1],
        ["a2", n2],
        ["a3", n3],
      ];
      for (const [kind, n] of alarms) {
        const alarm = addDaysYmd(exp, -n);
        if (alarm.length !== 8) continue;
        if (reg < alarm && alarm < exp) put(alarm, userId, userNm, kind);
      }
    }
  }
  const out = new Map<string, HealthCertCalChip[]>();
  for (const [ymd, people] of byDayUser) {
    const list = [...people.values()].map((c) => ({
      ...c,
      kinds: KIND_ORDER.filter((k) => c.kinds.includes(k)),
    }));
    list.sort((a, b) => a.userNm.localeCompare(b.userNm, "ko"));
    out.set(ymd, list);
  }
  return out;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 검색어는 사원명 부분일치. 서버 LIKE 가 없다
 *   2) 상태 임박은 오늘~오늘+N일. 만료는 오늘 이전. 만료일 없는 행은 전체에만 남는다
 *   3) 빈 검색·빈 상태는 통과
 */
export function matchEmp(
  // 대상 사원 한 행
  row: HealthCertEmp,
  // 사원명 검색어
  q: string,
  // 전체·임박·만료
  status: string,
  // 임박 창 일수 — 설정 MAX. 없으면 30
  windowDays: number | undefined,
): boolean {
  const needle = q.trim().toLowerCase();
  if (needle) {
    const nm = String(row.userNm ?? "").toLowerCase();
    if (!nm.includes(needle)) return false;
  }
  const exp = String(row.expireDt ?? "").replace(/-/g, "");
  if (status === EMP_STATUS_DUE || status === EMP_STATUS_EXPIRED) {
    if (exp.length !== 8) return false;
    const today = todayYmd();
    if (status === EMP_STATUS_EXPIRED) return exp < today;
    const n = windowDays && windowDays > 0 ? windowDays : 30;
    return exp >= today && exp <= addDaysYmd(today, n);
  }
  return true;
}

export function buildEmpColumns(): GridColumn<HealthCertEmp>[] {
  return [
    { field: "userNm", header: "사원명", width: 120, editable: false },
    { field: "deptNm", header: "부서", width: 120, editable: false },
    { field: "expireDt", header: "만료일", width: 100, editable: false, type: "date" },
    { field: "histCnt", header: "이력", width: 60, editable: false, align: "right" },
  ];
}

export function buildHistColumns(
  onView: (row: HealthCertHist) => void,
): GridColumn<HealthCertHist>[] {
  return [
    { field: "regDt", header: "등록일", width: 100, editable: false, type: "date" },
    { field: "expireDt", header: "만료일", width: 100, editable: false, type: "date" },
    {
      field: "fileNm",
      header: "파일",
      width: 220,
      editable: false,
      cellButton: { title: "열람", onClick: (row: HealthCertHist) => onView(row) },
    },
    { field: "insNm", header: "등록자", width: 100, editable: false },
  ];
}

export function empKey(row: HealthCertEmp): string {
  return String(row.userId ?? "");
}

export function histKey(row: HealthCertHist): string {
  return String(row.idx ?? "");
}
