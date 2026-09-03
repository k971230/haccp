/**
 * TodayTasksPage — 오늘 할 일 랜딩 (KPI + 오늘과제·최근문서 2열).
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 로그인 후 최초 화면이다 — 중앙 문서 미리보기 없이 카드·목록으로 화면을 채운다
 *   2) 좌 오늘 과제 · 우 최근 문서 2열이며 빈 목록은 안내 문구만 둔다
 *   3) 상단 헤더는 바 없이 제목만. KPI 만 mes-notice 왼쪽 색 바. 제목은 이름(아이디)의 오늘 할 일 + 배지
 *
 * PIPELINE[HF88] 오늘 할 일 화면
 * PIPELINE[HF87, HF51, HB95] 연관 모듈
 */
// 역할 — React 상태·효과·메모
import { useCallback, useEffect, useMemo, useState } from "react";
// 역할 — 화면 이동
import { useNavigate } from "react-router-dom";
// 역할 — KPI 카드 문서형 아이콘 (이모지 대신 Lucide)
import { ClipboardList, FileCheck2, FileClock, FileText, FileWarning, Files, type LucideIcon } from "lucide-react";
// 역할 — 오늘 과제 API
import { listTodayRecentDocs, listTodayTasks, type WorkflowRow } from "@/api/board/taskWorkflowApi";
// 역할 — 결재대기
import { listSignReady, type DocumentListRow } from "@/api/documentApi";
// 역할 — 2분 폴링 주기
import { DASHBOARD_POLLING_MS } from "@/config/envConfig";
// 역할 — mes-web형 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — SoPage형 패널 헤더·활성 섹션
import { gridHeadClass, gridPanelClass } from "@/components/layout/pageClasses";
import { useSection } from "@/shell/useSection";
// 역할 — 공통 UI·오류·비동기·셸
import { MesButton } from "@/components/ui/MesButton";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { usePageCommands } from "@/shell/pageCommands";
import { mesError } from "@/shell/errors";
import { routeOf } from "@/shell/tabRoute";
import { routeForDocument } from "@/lib/documentNav";
import { todayYmd, toDisplayDate, toInputTime } from "@/lib/docDateTime";
import { useCommonCodes } from "@/hooks/useCommonCodes";
import { useAuthStore } from "@/stores/authStore";
import type { EditableRow } from "@/types/editable";
// 역할 — 화면 상수·컬럼·상태 라벨
import {
  DOC_PAGE_SIZE,
  DOC_PERSIST_ID,
  EMPTY_DOC,
  EMPTY_TASK,
  KPI_DEFS,
  TASK_PERSIST_ID,
  buildDocColumns,
  buildTaskColumns,
  compareTodayTask,
  filterTodayTasks,
  formatHeaderUpdatedAt,
  isDoneWriteTask,
  isOpenCaTask,
  isOpenWriteTask,
  isOverdueTodayTask,
  kpiCardClass,
  pageCount,
  pageOffset,
  recentDocRange,
  sessionRoleLabel,
  sessionWho,
  taskStatusLabel,
  todayTaskHref,
  type DocRow,
  type FilterKind,
  type KpiKind,
  type TaskRow,
} from "./TodayTasksRule";

/** KPI 아이콘 이름 → Lucide. Rule 은 JSX 를 두지 않는다 */
const KPI_ICONS: Record<typeof KPI_DEFS[number]["icon"], LucideIcon> = {
  FileText,
  FileCheck2,
  FileClock,
  FileWarning,
  Files,
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) KPI·오늘과제·최근문서를 한 화면에서 제공한다
 *   2) screenRegistry today-tasks · 홈 "/" 리다이렉트 대상이다
 *   3) API 실패는 업무 토스트만 표시한다
 */
export default function TodayTasksPage() {
  const navigate = useNavigate();
  const asyncAct = useAsyncAction();
  // 세션 사용자 — 헤더 제목 이름(아이디)의 오늘 할 일 + 옆 배지
  const user = useAuthStore((s) => s.user);
  const who = sessionWho(user?.userNm, user?.userId);
  const roleNm = sessionRoleLabel(user?.usrgrpCd);
  const roleAdmin = roleNm === "관리자";
  // h=오늘 할 일, d=최근 문서 — 활성 패널 강조
  const sec = useSection();
  // 최근 문서 WRK→작성중 등 — DOC_STATUS 공통코드
  const { codeMap: docStatusNm } = useCommonCodes("DOC_STATUS");
  // 개선조치 OPEN→미조치 등 — CA_STATUS 공통코드
  const { codeMap: caStatusNm } = useCommonCodes("CA_STATUS");
  const [tasks, setTasks] = useState<WorkflowRow[]>([]);
  const [docs, setDocs] = useState<DocumentListRow[]>([]);
  const [docTotal, setDocTotal] = useState(0);
  const [docPageNo, setDocPageNo] = useState(1);
  const [approvalCnt, setApprovalCnt] = useState(0);
  const [filter, setFilter] = useState<FilterKind>("ALL");
  // 기본 체크 — 조치내용 없거나 완료 안 된 것만. 해제하면 오늘 할 일 전체
  const [incompleteOnly, setIncompleteOnly] = useState(true);
  const [taskActiveKey, setTaskActiveKey] = useState<string | null>(null);
  const [docActiveKey, setDocActiveKey] = useState<string | null>(null);
  // 헤더 마지막 업데이트 — load 성공 시각. 실패하면 이전 값을 유지한다
  const [updatedAt, setUpdatedAt] = useState<Date | null>(null);

  const taskColumns = useMemo(() => buildTaskColumns(), []);
  const docColumns = useMemo(() => buildDocColumns(docStatusNm), [docStatusNm]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 과제·최근문서 1페이지·결재대기 건수를 병렬 재조회한다
   *   2) 새로고침·셸 조회에서 호출한다. 최근 문서는 1페이지로 되돌린다
   *   3) 실패 시 기존 데이터를 유지하고 오류만 안내한다
   */
  const load = useCallback(async () => {
    try {
      const { fromDt, toDt } = recentDocRange();
      setDocPageNo(1);
      const [nextTasks, docPage, approvalList] = await Promise.all([
        listTodayTasks(),
        listTodayRecentDocs({
          fromDt,
          toDt,
          offset: pageOffset(1, DOC_PAGE_SIZE),
          limit: DOC_PAGE_SIZE,
        }),
        listSignReady({ fromDt, toDt }),
      ]);
      setTasks(nextTasks);
      setDocs(docPage.rows);
      setDocTotal(docPage.total);
      setApprovalCnt(approvalList.length);
      // 헤더 시각 — 조회가 끝난 로컬 시각
      setUpdatedAt(new Date());
    } catch (error) {
      mesError(error);
    }
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 최근 문서만 지정 페이지로 다시 가져온다
   *   2) 페이저 이전·다음에서 호출한다
   *   3) 실패 시 현재 페이지를 유지하고 오류만 안내한다
   */
  const loadDocsPage = useCallback(async (
    // 1부터 시작하는 페이지 번호
    page: number,
  ) => {
    try {
      const { fromDt, toDt } = recentDocRange();
      const docPage = await listTodayRecentDocs({
        fromDt,
        toDt,
        offset: pageOffset(page, DOC_PAGE_SIZE),
        limit: DOC_PAGE_SIZE,
      });
      setDocPageNo(page);
      setDocs(docPage.rows);
      setDocTotal(docPage.total);
    } catch (error) {
      mesError(error);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  // 2분 무소음 폴링 — 일하고 있는 상태를 맞춘다. 실패는 다음 주기에 다시 본다
  useEffect(() => {
    const id = window.setInterval(() => {
      void load().catch(() => {
        // 폴링 실패는 조용히 넘긴다
      });
    }, DASHBOARD_POLLING_MS);
    return () => window.clearInterval(id);
  }, [load]);

  usePageCommands({
    search: () => { void asyncAct.run(load, "search"); },
  });

  /**
   * 개발자: 박승우
   * 일자: 2026-08-26
   * 코멘트:
   *   1) 오늘 할 일 행을 작성·개선조치 화면으로 보낸다
   *   2) 행 더블클릭이 호출한다. 한 번 클릭은 선택만
   *   3) 예정은 작성 화면 행추가, 그 외는 기존 문서·개선조치 조회. 경로가 비면 이동하지 않는다
   */
  const openTask = (row: WorkflowRow) => {
    const href = todayTaskHref(row);
    if (href) navigate(href);
  };

  const taskCnt = useMemo(
    () => tasks.filter((row) => isOpenWriteTask(row.taskType, row.status)).length,
    [tasks],
  );
  const doneCnt = useMemo(
    () => tasks.filter((row) => isDoneWriteTask(row.taskType, row.status)).length,
    [tasks],
  );
  const caCnt = useMemo(
    () => tasks.filter((row) => isOpenCaTask(row.taskType, row.status, row.content)).length,
    [tasks],
  );

  const filteredTasks = useMemo(() => {
    return filterTodayTasks(tasks, filter, incompleteOnly)
      .slice()
      .sort((a, b) => compareTodayTask(a, b, todayYmd()));
  }, [filter, incompleteOnly, tasks]);

  const taskRows = useMemo<TaskRow[]>(
    () => filteredTasks.map((row, index) => ({
      ...row,
      _key: String(row.taskIdx ?? row.idx ?? `${row.taskType ?? "t"}-${index}`),
      typeNm: String(row.taskType ?? ""),
      statusNm: taskStatusLabel(row.taskType, row.status, caStatusNm, docStatusNm),
      // 마감 — 저장형(YYYYMMDD·HHMM)을 그대로 붙이면 `20260827 1800` 생숫자가 나온다.
      // 현장에서 8월 18일 18시인지 한눈에 안 읽혀서 사람이 읽는 꼴로 바꾼다
      dueText: `${toDisplayDate(row.dueDt) === "-" ? "" : toDisplayDate(row.dueDt)} ${toInputTime(row.dueTime)}`.trim(),
    })),
    [caStatusNm, docStatusNm, filteredTasks],
  );

  const docRows = useMemo<DocRow[]>(
    () => docs.map((row) => ({ ...row, _key: String(row.docIdx) })),
    [docs],
  );

  const kpiCount = (kind: KpiKind): number => {
    if (kind === "TASK") return taskCnt;
    if (kind === "DONE") return doneCnt;
    if (kind === "APPR") return approvalCnt;
    if (kind === "CA") return caCnt;
    return docTotal;
  };

  const onKpiClick = (kind: KpiKind) => {
    if (kind === "TASK") {
      setFilter(filter === "TASK" ? "ALL" : "TASK");
      return;
    }
    if (kind === "DONE") {
      setFilter(filter === "DONE" ? "ALL" : "DONE");
      return;
    }
    if (kind === "APPR") {
      setFilter("APPR");
      navigate(routeOf("sign-ready"));
      return;
    }
    if (kind === "CA") {
      setFilter(filter === "CA" ? "ALL" : "CA");
      return;
    }
    navigate(routeOf("document-inbox"));
  };

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 p-3">
      {/* 상단은 KPI 바와 겹치지 않게 mes-notice 없이 페이지 타이틀만 */}
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="flex min-w-0 flex-wrap items-center gap-1.5 text-xl font-bold text-slate-900">
            {/* 세션 이름(아이디)의 오늘 할 일 — 없을 때(= 세션 없음) 화면명만 */}
            <span className="truncate">{who ? `${who}의 오늘 할 일` : "오늘 할 일"}</span>
            {who ? (
              <span
                // 관리자(= danger 빨강) · 사용자(= search 파랑, 옆 새로고침과 같음)
                className={
                  roleAdmin
                    ? "shrink-0 rounded px-1.5 py-0.5 text-[11px] font-medium bg-red-50 text-red-600"
                    : "shrink-0 rounded px-1.5 py-0.5 text-[11px] font-medium bg-blue-100 text-blue-700"
                }
              >
                {roleNm}
              </span>
            ) : null}
          </h1>
          <p className="mt-0.5 text-sm text-slate-500">작성 · 결재 현황을 확인하고, 행을 더블클릭하면 해당 화면으로 이동합니다.</p>
        </div>
        <div className="flex shrink-0 flex-col items-end gap-1">
          <MesButton
            // 대시보드 전체 재조회 — 조회 틴트 + 되돌리기 아이콘
            variant="search"
            icon="reset"
            disabled={asyncAct.isBusy("search")}
            onClick={() => void asyncAct.run(load, "search")}
          >
            새로고침
          </MesButton>
          {updatedAt ? (
            <p className="text-[11px] text-slate-400">
              {/* load 성공 시각 — YYYY.MM.DD HH:mm. 실패하면 이전 값을 유지한다 */}
              마지막 업데이트: {formatHeaderUpdatedAt(updatedAt)}
            </p>
          ) : null}
        </div>
      </div>

      <div className="grid grid-cols-2 gap-2 lg:grid-cols-5">
        {KPI_DEFS.map((kpi) => {
          const Icon = KPI_ICONS[kpi.icon];
          const active = kpi.kind !== "DOCS" && kpi.kind !== "APPR" && filter === kpi.filter;
          return (
            <button
              key={kpi.kind}
              type="button"
              className={kpiCardClass(active, kpi.noticeTone)}
              onClick={() => onKpiClick(kpi.kind)}
            >
              {/* 톤 색 세로 바 — 토스트와 같다 */}
              <div className="mes-notice-bar" aria-hidden />
              <div className="mes-notice-content">
                <div className="mes-notice-row">
                  {/* 왼쪽 원형 아이콘 배지 */}
                  <div className="mes-notice-icon" aria-hidden>
                    <Icon strokeWidth={2.4} />
                  </div>
                  <div className="mes-notice-copy">
                    {/* 카드 제목 — 오늘 작성 과제 / 과제 완료 / 미결재 / 이탈·개선조치 / 최근 문서 */}
                    <div className="mes-notice-title">{kpi.label}</div>
                    {/* KPI 건수 — 토스트 본문 자리에 큰 숫자 */}
                    <div className="mes-notice-msg text-2xl font-semibold text-slate-800">{kpiCount(kpi.kind)}</div>
                  </div>
                </div>
              </div>
            </button>
          );
        })}
      </div>

      <div className="grid min-h-0 flex-1 grid-cols-1 gap-3 lg:grid-cols-2">
        <div {...sec.bind("h", gridPanelClass)}>
          <div className={gridHeadClass}>
            {/* 보이는 그리드명 — title prop과 동일 */}
            <b>오늘 할 일</b>
            <label className="flex cursor-pointer items-center gap-1.5">
              <input
                // 미완료만 — 작성과제 APV·조치내용 있는 CA 를 숨긴다. 기본 체크
                type="checkbox"
                className="h-3.5 w-3.5 cursor-pointer accent-[#1a3676]"
                checked={incompleteOnly}
                onChange={(e) => setIncompleteOnly(e.target.checked)}
              />
              <span className="whitespace-nowrap text-[11px] text-slate-600">미완료 과제만 보기</span>
            </label>
          </div>
          {taskRows.length === 0 ? (
            <div className="flex flex-1 flex-col items-center justify-center gap-2 p-6 text-center">
              <div
                className="flex h-10 w-10 items-center justify-center rounded-full bg-slate-100 text-slate-400"
                aria-hidden
              >
                <ClipboardList className="h-5 w-5" strokeWidth={2} />
              </div>
              <p className="text-sm font-medium text-slate-600">{EMPTY_TASK.title}</p>
              <p className="text-xs text-slate-400">{EMPTY_TASK.hint}</p>
            </div>
          ) : (
            <MesEditableGrid
              // 오늘 과제 그리드 설정 키
              persistId={TASK_PERSIST_ID}
              // 필터된 과제 행 — 상태 한글은 statusNm
              rows={taskRows as EditableRow<TaskRow>[]}
              // 구분·업무·상태 배지·마감
              columns={taskColumns}
              // 읽기 전용 — 행 활성화로 화면 이동
              editable={false}
              // 패널 제목
              title="오늘 할 일"
              // 부모 flex 높이 채움
              height="100%"
              // 조회 busy
              loading={asyncAct.isBusy("search")}
              // 활성 행 — 클릭은 선택만
              activeKey={taskActiveKey}
              // 행 클릭 — 선택만. 이동은 더블클릭
              onActivate={(row) => {
                sec.setSec("h");
                setTaskActiveKey(row._key ?? null);
              }}
              // 더블클릭 — 예정은 행추가, 그 외는 조회
              onRowDoubleClick={(row) => {
                sec.setSec("h");
                setTaskActiveKey(row._key ?? null);
                openTask(row);
              }}
              // 기한경과(전날·기간 지남) — 빨간 행
              rowClassName={(row) => (isOverdueTodayTask(row, todayYmd()) ? "mes-row-overdue" : undefined)}
              // 활성 섹션을 과제로
              onSetActive={() => sec.setSec("h")}
              showRowNum
            />
          )}
        </div>

        <div {...sec.bind("d", gridPanelClass)}>
          <div className={gridHeadClass}>
            {/* 보이는 그리드명 — title prop과 동일 */}
            <b>최근 문서</b>
          </div>
          {docTotal === 0 ? (
            <div className="flex flex-1 flex-col items-center justify-center gap-2 p-6 text-center">
              <div
                className="flex h-10 w-10 items-center justify-center rounded-full bg-slate-100 text-slate-400"
                aria-hidden
              >
                <Files className="h-5 w-5" strokeWidth={2} />
              </div>
              <p className="text-sm font-medium text-slate-600">{EMPTY_DOC.title}</p>
              <p className="text-xs text-slate-400">{EMPTY_DOC.hint}</p>
            </div>
          ) : (
            <>
              <div className="min-h-0 flex-1">
                <MesEditableGrid
                  // 최근 문서 그리드 설정 키
                  persistId={DOC_PERSIST_ID}
                  // 현재 페이지 행 — 전체는 docTotal
                  rows={docRows as EditableRow<DocRow>[]}
                  // 문서·번호·상태 배지(작성중)·기준일
                  columns={docColumns}
                  // 읽기 전용
                  editable={false}
                  // 패널 제목
                  title="최근 문서"
                  // 페이저 위에 그리드만 채움
                  height="100%"
                  // 조회 busy
                  loading={asyncAct.isBusy("search")}
                  // 활성 문서 — 클릭은 선택만, 화면 이동은 더블클릭
                  activeKey={docActiveKey}
                  // 행 클릭 시 선택만. 이동은 onRowDoubleClick
                  onActivate={(row) => {
                    sec.setSec("d");
                    setDocActiveKey(row._key ?? null);
                  }}
                  // 모든 셀 더블클릭 — 작성 화면 deep-link
                  onRowDoubleClick={(row) => {
                    sec.setSec("d");
                    setDocActiveKey(row._key ?? null);
                    navigate(routeForDocument({
                      docIdx: row.docIdx,
                      tmplCd: row.tmplCd,
                      docKind: row.docKind,
                    }));
                  }}
                  // 활성 섹션을 최근 문서로
                  onSetActive={() => sec.setSec("d")}
                  showRowNum
                  // 푸터 총건수는 페이지 길이라 숨기고 아래 페이저가 전체 건수를 보여 준다
                  showFooter={false}
                />
              </div>
              <div className="flex shrink-0 items-center justify-between border-t border-slate-200 bg-slate-50 px-3 py-1.5">
                <span className="text-[12px] text-slate-600">
                  총 <b className="font-semibold text-blue-600">{docTotal}</b>건
                  {" · "}
                  {docPageNo} / {pageCount(docTotal, DOC_PAGE_SIZE)}
                </span>
                <div className="flex gap-1">
                  <MesButton
                    // 이전 페이지 — 1페이지면 비활성
                    size="sm"
                    variant="secondary"
                    disabled={docPageNo <= 1 || asyncAct.isBusy("search")}
                    onClick={() => void asyncAct.run(() => loadDocsPage(docPageNo - 1), "search")}
                  >
                    이전
                  </MesButton>
                  <MesButton
                    // 다음 페이지 — 마지막이면 비활성
                    size="sm"
                    variant="secondary"
                    disabled={
                      docPageNo >= pageCount(docTotal, DOC_PAGE_SIZE) || asyncAct.isBusy("search")
                    }
                    onClick={() => void asyncAct.run(() => loadDocsPage(docPageNo + 1), "search")}
                  >
                    다음
                  </MesButton>
                </div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
