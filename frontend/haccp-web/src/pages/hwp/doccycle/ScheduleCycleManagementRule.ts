/**
 * ScheduleCycleManagementRule — 문서주기관리 폼 규칙·변환·좌측 컬럼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 주기 상수·날짜 변환·details 펼치기는 이 파일에 둔다
 *   2) 주기 콤보에 따라 반복설정 영역이 바뀌므로 변환을 한 곳에 모아 저장 payload가 어긋나지 않게 한다
 *   3) persistId는 기존 값(doc-cycle-forms)을 승계한다
 *
 * PIPELINE[HF89] 문서주기관리 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 주기 목록·상세 타입
import type { DocCycleDetail, DocCycleFormRow } from "@/api/hwp/docCycleApi";
// 역할 — sys-yn 레거시 Y/N 별칭
import { withSysYnLegacyAliases } from "../formType";

/** 화면코드 — tbl_screen.scrn_cd·권한·pref 키 */
export const SCRN_CD = "schedule-cycle-management" as const;

/** 좌측 목록 열 설정 저장 키 — 폴더를 옮겨도 값을 바꾸지 않는다 */
export const PERSIST_ID = "doc-cycle-forms" as const;

/** 좌우 분할 비율 저장 키 */
export const SPLIT_KEY = "haccp-split-doc-cycle" as const;

/** 주기 콤보 기본값 — 공통코드 조회 실패 시에도 화면이 비지 않게 한다 */
export const CYCLE_FALLBACK = [
  { value: "D", label: "매일" },
  { value: "W", label: "매주" },
  { value: "M", label: "매월" },
  { value: "Q", label: "분기" },
  { value: "H", label: "반기" },
  { value: "Y", label: "매년" },
] as const;

/** 비영업일 처리 기본값 — keep 그대로 / prev 이전 영업일 / next 다음 영업일 */
export const NONWORK_FALLBACK = [
  { value: "keep", label: "그대로" },
  { value: "prev", label: "이전 영업일" },
  { value: "next", label: "다음 영업일" },
] as const;

/** 요일 토글 — ISO 요일(1 월 ~ 7 일) */
export const WEEK_DAYS = [
  { value: 1, label: "월" },
  { value: 2, label: "화" },
  { value: 3, label: "수" },
  { value: 4, label: "목" },
  { value: 5, label: "금" },
  { value: 6, label: "토" },
  { value: 7, label: "일" },
] as const;

/** 분기·반기 실행월 순번 — 분기는 1~3, 반기는 1~6 */
export const QUARTER_MONTHS = [1, 2, 3] as const;
export const HALF_MONTHS = [1, 2, 3, 4, 5, 6] as const;

/** 우측 폼 상태 — 서버 details 배열을 화면이 다루기 쉬운 형태로 펼쳐 둔다 */
export type CycleForm = {
  // 관리 시작일 — date input 값(yyyy-mm-dd)
  baseDt: string;
  cycleCd: string;
  nonworkRule: string;
  // 마감시각 — time input 값(HH:mm)
  dueTime: string;
  deptCd: string;
  deptNm: string;
  userId: string;
  userNm: string;
  useYn: "Y" | "N";
  // 매주 — 선택 요일(ISO)
  weekDays: number[];
  // 매월 — 실행일 목록
  monthDays: number[];
  // 매월 — 말일 실행 여부(31일 지정과 별개로 걸 수 있다)
  monthEnd: boolean;
  // 분기·반기 = 주기 내 월 순번, 매년 = 월 번호
  periodMonth: number;
  // 분기·반기·매년 실행일
  periodDay: number;
};

/** 오늘 — 신규 주기의 관리 시작일 기본값 */
export function todayInput(): string {
  const now = new Date();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${now.getFullYear()}-${month}-${day}`;
}

/** yyyyMMdd → yyyy-mm-dd (date input) */
export function ymdToInput(ymd?: string | null): string {
  const digits = String(ymd ?? "").replace(/\D/g, "");
  if (digits.length !== 8) return "";
  return `${digits.slice(0, 4)}-${digits.slice(4, 6)}-${digits.slice(6, 8)}`;
}

/** yyyy-mm-dd → yyyyMMdd */
export function inputToYmd(value: string): string {
  return String(value ?? "").replace(/\D/g, "").slice(0, 8);
}

/** HHMM → HH:mm (time input) */
export function hhmmToInput(hhmm?: string | null): string {
  const digits = String(hhmm ?? "").replace(/\D/g, "").padStart(4, "0").slice(0, 4);
  return `${digits.slice(0, 2)}:${digits.slice(2, 4)}`;
}

/** HH:mm → HHMM */
export function inputToHhmm(value: string): string {
  const digits = String(value ?? "").replace(/\D/g, "").slice(0, 4);
  return digits.length === 4 ? digits : "1800";
}

/** 빈 폼 — 주기 미설정 양식을 고르면 이 값으로 채운다(매일·그대로·18:00·당일) */
export function emptyForm(): CycleForm {
  return {
    baseDt: todayInput(),
    cycleCd: "D",
    nonworkRule: "keep",
    dueTime: "18:00",
    deptCd: "",
    deptNm: "",
    userId: "",
    userNm: "",
    useYn: "Y",
    weekDays: [],
    monthDays: [],
    monthEnd: false,
    periodMonth: 1,
    periodDay: 1,
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 서버 details 배열을 폼 상태(요일·실행일·말일·월+일)로 펼친다
 *   2) 좌측 행 선택 후 주기 단건을 읽었을 때 호출한다
 *   3) 상세가 없으면 빈 선택으로 두고 관리 시작일 기준으로 안내만 한다
 */
export function detailsToForm(base: CycleForm, details?: DocCycleDetail[]): CycleForm {
  const next: CycleForm = { ...base, weekDays: [], monthDays: [], monthEnd: false };
  for (const detail of details ?? []) {
    const type = String(detail.detailTy ?? "").toLowerCase();
    const val1 = Number(detail.val1 ?? 0);
    const val2 = Number(detail.val2 ?? 0);
    if (type === "week-day" && val1 >= 1) next.weekDays.push(val1);
    else if (type === "month-day" && val1 >= 1) next.monthDays.push(val1);
    else if (type === "month-end") next.monthEnd = true;
    else if (type === "quarter-month" || type === "half-month" || type === "year-month") {
      if (val1 >= 1) next.periodMonth = val1;
      if (val2 >= 1) next.periodDay = val2;
    }
  }
  next.weekDays.sort((a, b) => a - b);
  next.monthDays.sort((a, b) => a - b);
  return next;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 폼 상태를 서버 details 배열로 되돌린다 — 주기와 무관한 값은 보내지 않는다
 *   2) 저장 직전에 호출한다
 *   3) 매일은 항상 빈 배열이다(반복설정이 없다)
 */
export function formToDetails(form: CycleForm): DocCycleDetail[] {
  switch (form.cycleCd) {
    case "W":
      return form.weekDays.map((day) => ({ detailTy: "week-day", val1: day }));
    case "M": {
      const rows: DocCycleDetail[] = form.monthDays.map((day) => ({ detailTy: "month-day", val1: day }));
      if (form.monthEnd) rows.push({ detailTy: "month-end" });
      return rows;
    }
    case "Q":
      return [{ detailTy: "quarter-month", val1: form.periodMonth, val2: form.periodDay }];
    case "H":
      return [{ detailTy: "half-month", val1: form.periodMonth, val2: form.periodDay }];
    case "Y":
      return [{ detailTy: "year-month", val1: form.periodMonth, val2: form.periodDay }];
    default:
      return [];
  }
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) 좌측 조회 전용 목록 컬럼을 만든다
 *   2) Page가 sys-yn 맵을 넘겨 useMemo로 호출한다
 *   3) 구분 문구는 공통코드 sys-yn 이다. 불러오기 src-ty 와 섞지 않는다
 */
export function buildFormColumns(
  // sys-yn 공통코드 맵 — 시스템제공/사용자추가
  sysYnMap: Record<string, string>,
): GridColumn<DocCycleFormRow>[] {
  return [
    {
      // 양식코드 — 조회 전용. 등록·수정은 사용양식 관리에서 한다
      field: "tmplCd",
      header: "양식코드",
      width: 180,
    },
    {
      // 양식명 — 회사 표시명(tmpl_nm_ovr) 우선
      field: "tmplNm",
      header: "양식명",
      width: 200,
    },
    {
      // 구분 — 시스템제공/사용자추가 badge. 주기 설정은 구분과 무관하게 가능하다
      field: "formTy",
      header: "구분",
      width: 96,
      type: "code",
      // sys-yn 문구 + 레거시 Y/N 별칭. src-ty 와 섞지 않는다
      codeMap: withSysYnLegacyAliases(sysYnMap),
      badge: { sys: "blue", usr: "green", Y: "blue", N: "green" },
    },
    {
      // 사용여부 — 양식(ct.use_yn). 미사용도 검색 전체에서 보인다
      field: "useYn",
      header: "사용여부",
      width: 88,
      type: "code",
      codeMap: { Y: "사용", N: "미사용" },
      badge: { Y: "green", N: "gray" },
    },
  ];
}
