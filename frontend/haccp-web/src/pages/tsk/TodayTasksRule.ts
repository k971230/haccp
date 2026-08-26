/**
 * TodayTasksRule — 오늘 할 일 화면 상수·컬럼·상태 라벨.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) Page는 조회·렌더만 담당하고 화면코드·pref 키·KPI 톤·컬럼은 이 파일이 갖는다
 *   2) 과제 상태는 TASK(예정·진행·지연)와 CA(미조치·조치중·완료)가 섞인다. 행마다 맵을 고른다
 *   3) 최근 문서 상태는 DOC_STATUS 공통코드(작성중 등) + 공유 배지 색
 *
 * PIPELINE[HF88] 오늘 할 일 화면
 */
// 역할 — 그리드 컬럼 정의
import type { GridColumn } from "@/types/grid";
// 역할 — 오늘 과제 행
import type { WorkflowRow } from "@/api/taskWorkflowApi";
// 역할 — 최근 문서 행
import type { DocumentListRow } from "@/api/documentApi";
// 역할 — 문서·과제·개선조치 상태 배지·과제 문구
import {
  CA_STATUS_BADGE,
  DOC_STATUS_BADGE,
  TASK_STATUS_BADGE,
  TASK_STATUS_NM,
  type StatusBadgeTone,
} from "@/lib/docStatus";
// 역할 — 오늘 YYYYMMDD. 최근 문서 구간 toDt
import { todayYmd } from "@/lib/docDateTime";
// 역할 — 최근 문서 일수·페이지 크기. .env 기본 7·20
import { TODAY_TASKS_PAGE_SIZE, TODAY_TASKS_RECENT_DAYS } from "@/config/envConfig";
// 역할 — 작성과제 양식 접두 → 작성 화면·예정 행추가
import { routeForDocument, routeForTmplAdd, routeForTmplWrite } from "@/lib/documentNav";
// 역할 — CA 화면
import { routeOf } from "@/shell/tabRoute";

/** 화면코드 — tbl_screen.scrn_cd. 폴더를 옮겨도 바꾸지 않는다 */
export const SCRN_CD = "today-tasks" as const;

/** 오늘 과제 그리드 열 설정 키 */
export const TASK_PERSIST_ID = "tsk-today-tasks" as const;

/** 최근 문서 그리드 열 설정 키 */
export const DOC_PERSIST_ID = "tsk-today-recent-docs" as const;

/** KPI 카드 필터 — ALL 은 카드 토글 해제, APPR 은 결재대기로 이동, DONE 은 오늘 승인완료 */
export type FilterKind = "ALL" | "TASK" | "DONE" | "CA" | "APPR";

/** KPI 카드 식별 — 클릭·아이콘·숫자 색을 한 키로 맞춘다 */
export type KpiKind = "TASK" | "DONE" | "APPR" | "CA" | "DOCS";

/** 오늘 과제 행 — 구분·상태 문구·마감을 미리 붙인다 */
export type TaskRow = WorkflowRow & {
  _key?: string;
  dueText?: string;
  typeNm?: string;
  statusNm?: string;
};

/** 최근 문서 행 */
export type DocRow = DocumentListRow & { _key?: string };

/** 구분 열 — SP task_type TASK/CA */
export const TASK_TYPE_NM: Record<string, string> = {
  TASK: "작성과제",
  CA: "개선조치",
};

/**
 * 오늘 할 일 상태 배지 — 코드와 한글 라벨 둘 다 받는다.
 * 그리드 field 가 statusNm(한글)이어도 코드 폴백이 회색이 아니게 한다.
 */
export const TASK_GRID_STATUS_BADGE: Record<string, StatusBadgeTone> = {
  ...TASK_STATUS_BADGE,
  ...CA_STATUS_BADGE,
  [TASK_STATUS_NM.TODO]: TASK_STATUS_BADGE.TODO,
  [TASK_STATUS_NM.ING]: TASK_STATUS_BADGE.ING,
  [TASK_STATUS_NM.LATE]: TASK_STATUS_BADGE.LATE,
  [TASK_STATUS_NM.APV]: TASK_STATUS_BADGE.APV,
  미조치: CA_STATUS_BADGE.OPEN,
  조치중: CA_STATUS_BADGE.ING,
  완료: CA_STATUS_BADGE.DONE,
};

/** mes-notice 톤 — 토스트·확인창과 같은 왼쪽 바·원형 아이콘 색 */
export type NoticeTone = "info" | "warn" | "error" | "success";

/** 최근 문서·결재대기 조회 일수 — env VITE_TODAY_TASKS_RECENT_DAYS. 오늘을 포함한다 */
export const RECENT_DOC_DAYS = TODAY_TASKS_RECENT_DAYS;

/** 최근 문서 페이지 크기 — env VITE_TODAY_TASKS_PAGE_SIZE. SP LIMIT */
export const DOC_PAGE_SIZE = TODAY_TASKS_PAGE_SIZE;

/** KPI 카드 시각 — 라벨·아이콘·토스트 톤. 클릭은 Page */
export const KPI_DEFS: {
  kind: KpiKind;
  filter: FilterKind;
  label: string;
  icon: "FileText" | "FileCheck2" | "FileClock" | "FileWarning" | "Files";
  noticeTone: NoticeTone;
}[] = [
  {
    kind: "TASK",
    filter: "TASK",
    label: "오늘 작성 과제",
    icon: "FileText",
    noticeTone: "info",
  },
  {
    kind: "DONE",
    filter: "DONE",
    label: "과제 완료",
    icon: "FileCheck2",
    noticeTone: "success",
  },
  {
    kind: "APPR",
    filter: "APPR",
    label: "미결재",
    icon: "FileClock",
    noticeTone: "warn",
  },
  {
    kind: "CA",
    filter: "CA",
    label: "이탈·개선조치",
    icon: "FileWarning",
    noticeTone: "error",
  },
  {
    kind: "DOCS",
    filter: "ALL",
    label: "최근 문서",
    icon: "Files",
    noticeTone: "success",
  },
];

/** 빈 오늘 할 일 안내 */
export const EMPTY_TASK = {
  title: "오늘 예정된 과제가 없습니다.",
  hint: "작성과제·개선조치가 생기면 이 목록에 나타납니다.",
} as const;

/** 빈 최근 문서 안내 */
export const EMPTY_DOC = {
  title: `최근 ${RECENT_DOC_DAYS}일 문서가 없습니다.`,
  hint: `최근 ${RECENT_DOC_DAYS}일 작성·결재한 문서가 생기면 이 목록에 나타납니다.`,
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 최근 문서·결재대기 조회 구간을 만든다 — 오늘 포함 RECENT_DOC_DAYS 일
 *   2) 오늘 할 일 load 가 문서함·결재대기 API 에 넘긴다
 *   3) today 가 8자리가 아니면(= 테스트 오타) 오늘 날짜로 되돌린다
 */
export function recentDocRange(
  // 구간 끝 YYYYMMDD — 비우면 오늘
  today: string = todayYmd(),
): { fromDt: string; toDt: string } {
  const toDt = /^\d{8}$/.test(today) ? today : todayYmd();
  const at = new Date(
    Number(toDt.slice(0, 4)),
    Number(toDt.slice(4, 6)) - 1,
    Number(toDt.slice(6, 8)),
  );
  // 오늘을 포함하므로 6일 전(7일)부터
  at.setDate(at.getDate() - (RECENT_DOC_DAYS - 1));
  const y = at.getFullYear();
  const m = String(at.getMonth() + 1).padStart(2, "0");
  const d = String(at.getDate()).padStart(2, "0");
  return { fromDt: `${y}${m}${d}`, toDt };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 페이지 번호(1부터)를 SP OFFSET 으로 바꾼다
 *   2) 오늘 할 일 최근 문서 조회가 호출한다
 *   3) page·size 가 1 미만이면(= 오타) 첫 페이지·1건으로 본다
 */
export function pageOffset(
  // 1부터 시작하는 페이지 번호
  page: number,
  // 페이지 건수 — DOC_PAGE_SIZE
  size: number,
): number {
  const p = page < 1 ? 1 : page;
  const s = size < 1 ? 1 : size;
  return (p - 1) * s;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 총건수와 페이지 크기로 마지막 페이지 번호를 만든다
 *   2) 페이저 n / m 표시가 호출한다
 *   3) 0건이면 1페이지로 본다 — 빈 화면과 맞춘다
 */
export function pageCount(
  // 기간 전체 건수 — API total
  total: number,
  // 페이지 건수 — DOC_PAGE_SIZE
  size: number,
): number {
  const s = size < 1 ? 1 : size;
  if (total <= 0) return 1;
  return Math.ceil(total / s);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 세션 사용자를 이름(아이디)로 붙인다 — 하단 바와 같은 형식
 *   2) 오늘 할 일 헤더가 호출한다
 *   3) 둘 다 없을 때(= 로그아웃 직후) 빈 문자열
 */
export function sessionWho(
  // 사용자명
  userNm?: string | null,
  // 로그인 아이디
  userId?: string | null,
): string {
  if (!userNm && !userId) return "";
  return `${userNm ?? "-"}(${userId ?? "-"})`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 헤더 배지 문구를 고른다 — ADMIN 만 관리자
 *   2) 오늘 할 일 헤더가 제목 옆에 붙인다
 *   3) 그 외 권한그룹은 사용자로 본다
 */
export function sessionRoleLabel(
  // JWT usrgrpCd
  usrgrpCd?: string | null,
): string {
  return (usrgrpCd ?? "").toUpperCase() === "ADMIN" ? "관리자" : "사용자";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 헤더 마지막 업데이트 시각을 YYYY.MM.DD HH:mm 으로 붙인다
 *   2) 오늘 할 일 헤더가 load 성공 시각을 표시할 때 호출한다
 *   3) 공유 toDisplayDateTime(하이픈)과 시안 표기가 달라 화면 전용으로 둔다
 */
export function formatHeaderUpdatedAt(
  // load 가 끝난 로컬 시각
  at: Date,
): string {
  const y = at.getFullYear();
  const m = String(at.getMonth() + 1).padStart(2, "0");
  const d = String(at.getDate()).padStart(2, "0");
  const hh = String(at.getHours()).padStart(2, "0");
  const mm = String(at.getMinutes()).padStart(2, "0");
  return `${y}.${m}.${d} ${hh}:${mm}`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) KPI 를 mes-notice 토스트와 같은 왼쪽 바·원형 아이콘으로 그린다
 *   2) Page 가 다섯 장 모두에 같은 클래스를 줄 때 호출한다
 *   3) 선택 중이면 하늘색 링만 더한다 — 구성(5장)은 바꾸지 않는다
 */
export function kpiCardClass(
  // 이 카드가 현재 필터인지
  active: boolean,
  // 토스트 톤 — info 파랑 · warn 주황 · error 빨강 · success 초록
  noticeTone: NoticeTone,
): string {
  const base = `mes-notice w-full cursor-pointer text-left mes-notice-tone-${noticeTone}`;
  return active ? `${base} ring-1 ring-sky-400` : base;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 개선조치(CA) 행인지 본다
 *   2) KPI 건수·목록 필터·상태 라벨이 호출한다
 *   3) 대소문자 섞여 와도 CA 만 개선조치로 본다
 */
export function isCaTask(
  // SP task_type — TASK 또는 CA
  taskType?: unknown,
): boolean {
  return String(taskType ?? "").toUpperCase() === "CA";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 아직 안 끝낸 오늘 작성과제인지 본다 — TODO/ING/LATE
 *   2) 「오늘 작성 과제」 KPI 건수·목록 필터가 호출한다
 *   3) CA 와 승인완료(APV) 는 여기 넣지 않는다
 */
export function isOpenWriteTask(
  // SP task_type — CA 면 false
  taskType?: unknown,
  // tbl_schedule_task.status
  status?: unknown,
): boolean {
  return !isCaTask(taskType) && ["TODO", "ING", "LATE"].includes(String(status ?? ""));
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 오늘 승인이 끝난 작성과제인지 본다 — APV
 *   2) 「과제 완료」 KPI 건수·목록 필터가 호출한다
 *   3) 작성 중(TODO/ING/LATE)·개선조치는 여기 넣지 않는다
 */
export function isDoneWriteTask(
  // SP task_type — CA 면 false
  taskType?: unknown,
  // tbl_schedule_task.status
  status?: unknown,
): boolean {
  return !isCaTask(taskType) && String(status ?? "") === "APV";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 조치내용이 아직 비어 있고 DONE 이 아닌 개선조치인지 본다
 *   2) KPI 이탈·개선조치 건수·미완료 필터가 호출한다
 *   3) SP content 는 action_desc. 공백이면 미입력으로 본다
 */
export function isOpenCaTask(
  // SP task_type — CA 가 아니면 false
  taskType?: unknown,
  // tbl_corrective_action.status
  status?: unknown,
  // SP content — 조치내용. 있으면 미완료 목록에서 뺀다
  content?: unknown,
): boolean {
  return isCaTask(taskType)
    && String(status ?? "") !== "DONE"
    && String(content ?? "").trim() === "";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 미완료 과제인지 본다 — 작성과제 TODO/ING/LATE 또는 조치내용 없는 CA
 *   2) 「미완료 과제만 보기」 체크가 호출한다
 *   3) APV·조치내용 있는 CA 는 체크 해제 때만 남긴다
 */
export function isIncompleteTodayTask(
  // SP 행 — taskType·status·content
  row: Pick<WorkflowRow, "taskType" | "status" | "content">,
): boolean {
  if (isCaTask(row.taskType)) return isOpenCaTask(row.taskType, row.status, row.content);
  return isOpenWriteTask(row.taskType, row.status);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 마감일이 오늘보다 앞이면 기한경과로 본다
 *   2) 빨강 행·맨 위 정렬이 호출한다
 *   3) 8자리가 아니거나 오늘과 같으면(= 당일) 경과가 아니다
 */
export function isOverdueDueDt(
  // SP due_dt YYYYMMDD
  dueDt: unknown,
  // 오늘 YYYYMMDD
  today: string,
): boolean {
  const dt = String(dueDt ?? "");
  return /^\d{8}$/.test(dt) && /^\d{8}$/.test(today) && dt < today;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 기한경과 행인지 본다 — 마감일이 오늘보다 앞이거나 상태가 LATE
 *   2) 빨간 행·맨 위 정렬이 호출한다
 *   3) CA 는 due_dt 만 본다. LATE 는 작성과제 전용
 */
export function isOverdueTodayTask(
  // SP 행 — dueDt·status·taskType
  row: Pick<WorkflowRow, "dueDt" | "status" | "taskType">,
  // 오늘 YYYYMMDD
  today: string,
): boolean {
  if (isOverdueDueDt(row.dueDt, today)) return true;
  return !isCaTask(row.taskType) && String(row.status ?? "") === "LATE";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 기한경과를 먼저, 그다음 마감일·시각·idx
 *   2) 오늘 할 일 목록 정렬이 호출한다
 *   3) due_dt 가 비면 경과가 아니므로 뒤로 간다
 */
export function compareTodayTask(
  // 왼쪽 행
  a: Pick<WorkflowRow, "dueDt" | "dueTime" | "taskIdx" | "idx" | "status" | "taskType">,
  // 오른쪽 행
  b: Pick<WorkflowRow, "dueDt" | "dueTime" | "taskIdx" | "idx" | "status" | "taskType">,
  // 오늘 YYYYMMDD
  today: string,
): number {
  const ao = isOverdueTodayTask(a, today) ? 0 : 1;
  const bo = isOverdueTodayTask(b, today) ? 0 : 1;
  if (ao !== bo) return ao - bo;
  const byDue = String(a.dueDt ?? "").localeCompare(String(b.dueDt ?? ""));
  if (byDue !== 0) return byDue;
  const byTime = String(a.dueTime ?? "").localeCompare(String(b.dueTime ?? ""));
  if (byTime !== 0) return byTime;
  return Number(a.taskIdx ?? a.idx ?? 0) - Number(b.taskIdx ?? b.idx ?? 0);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) KPI 유형 필터 다음에 미완료 체크를 적용한다
 *   2) Page 가 그리드 행을 만들 때 호출한다
 *   3) APPR 은 화면 이동만 하므로 목록은 비운다
 */
export function filterTodayTasks(
  // SP 오늘 할 일 전체
  rows: WorkflowRow[],
  // KPI 카드 필터
  filter: FilterKind,
  // true 면 미완료만 — APV·조치내용 있는 CA 제외
  incompleteOnly: boolean,
): WorkflowRow[] {
  return rows.filter((row) => {
    if (filter === "APPR") return false;
    if (isCaTask(row.taskType)) {
      if (filter !== "ALL" && filter !== "CA") return false;
      return incompleteOnly ? isOpenCaTask(row.taskType, row.status, row.content) : true;
    }
    if (filter === "CA") return false;
    if (isOpenWriteTask(row.taskType, row.status)) return filter === "ALL" || filter === "TASK";
    if (isDoneWriteTask(row.taskType, row.status)) {
      if (incompleteOnly) return false;
      return filter === "ALL" || filter === "DONE";
    }
    return false;
  });
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 오늘 할 일 더블클릭 경로를 만든다
 *   2) 예정(TODO)은 작성 화면 행추가(add=1)에 그 행의 양식코드·일자를 실어 보낸다
 *   3) 예정이 아니면 문서가 있으면 조회(?docIdx=), CA 는 개선조치 화면. 없으면 목록만
 */
export function todayTaskHref(
  // SP 행 — taskType·status·tmplCd/content·baseDt·docIdx·title
  row: WorkflowRow,
): string {
  if (isCaTask(row.taskType)) return routeOf("corrective-action-management");
  const tmplCd = String(row.tmplCd ?? row.content ?? "").trim();
  const docKind = String(row.docKind ?? "") || null;
  const tmplNm = String(row.title ?? "").trim();
  const baseDt = String(row.baseDt ?? "").trim();
  const status = String(row.status ?? "").toUpperCase();
  if (status === "TODO") {
    return routeForTmplAdd(tmplCd, { baseDt, tmplNm, docKind });
  }
  const docIdx = Number(row.docIdx ?? 0);
  if (docIdx > 0) return routeForDocument({ docIdx, tmplCd, docKind });
  return routeForTmplWrite(tmplCd, null, docKind);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 과제 상태 코드를 한글 문구로 바꾼다
 *   2) CA 는 공통코드 맵, 그 외는 TASK_STATUS_NM(예정·진행·지연·승인완료)
 *   3) 맵에 없을 때(= 새 코드) 원본 코드를 그대로 보여 빈칸이 없게 한다
 */
export function taskStatusLabel(
  // SP task_type — CA 이면 개선조치 상태
  taskType: unknown,
  // TASK: TODO/ING/LATE/APV · CA: OPEN/ING/DONE
  status: unknown,
  // CA_STATUS 공통코드 subCd → 표시명. 화면이 넘긴다
  caNm: Record<string, string>,
): string {
  const st = String(status ?? "");
  if (!st) return "";
  if (isCaTask(taskType)) return caNm[st] || st;
  return TASK_STATUS_NM[st] || st;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 오늘 과제 컬럼 — 구분·업무·상태 배지·마감
 *   2) Page 가 마운트 때 한 번 만든다
 *   3) 상태 칸은 statusNm(한글). 배지는 코드·라벨 키를 같이 받는다
 */
export function buildTaskColumns(): GridColumn<TaskRow>[] {
  return [
    {
      // 구분 — 작성과제/개선조치. SP 코드 TASK/CA 를 한글로 바꾼다
      field: "typeNm",
      header: "구분",
      width: 90,
      type: "code",
      codeMap: TASK_TYPE_NM,
      editable: false,
    },
    {
      // 업무 제목 — 양식명 또는 개선조치 안내. 이동은 행 더블클릭
      field: "title",
      header: "업무",
      width: 220,
    },
    {
      // 상태 — 예정·진행·지연 또는 미조치·조치중. 코드 원문은 status 에 남긴다
      field: "statusNm",
      header: "상태",
      width: 80,
      type: "code",
      editable: false,
      badge: TASK_GRID_STATUS_BADGE,
    },
    {
      // 마감일+시각 — Page 가 dueText 로 붙인다
      field: "dueText",
      header: "마감",
      width: 120,
    },
  ];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 최근 문서 컬럼 — 문서·번호·상태 배지·기준일
 *   2) Page 가 DOC_STATUS 공통코드 맵을 넘겨 한 번 만든다
 *   3) WRK 는 작성중으로 보인다. 색은 DOC_STATUS_BADGE
 */
export function buildDocColumns(
  // 상태코드 → 라벨 — DOC_STATUS 공통코드 맵. 화면이 넘긴다
  statusNm: Record<string, string>,
): GridColumn<DocRow>[] {
  return [
    {
      // 양식명
      field: "tmplNm",
      header: "문서",
      width: 180,
    },
    {
      // 문서번호
      field: "docNo",
      header: "문서번호",
      width: 140,
    },
    {
      // 결재상태 — 작성중·검토요청 등. 업무 상태가 정하고 사용자가 바꾸지 않는다
      field: "status",
      header: "상태",
      width: 80,
      type: "code",
      editable: false,
      codeMap: statusNm,
      badge: DOC_STATUS_BADGE,
    },
    {
      // 기준일 YYYYMMDD
      field: "baseDt",
      header: "기준일",
      width: 100,
    },
  ];
}
