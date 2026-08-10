/**
 * TodayTasksPage — 오늘 할 일 랜딩 (KPI + 오늘과제·최근문서 2열).
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 로그인 후 최초 화면이다 — 중앙 문서 미리보기 없이 카드·목록으로 화면을 채운다
 *   2) 좌 오늘 과제 · 우 최근 문서 2열이며 빈 목록은 안내와 바로가기를 둔다
 *   3) 행 클릭으로 작성·문서함 deep-link 한다
 *
 * PIPELINE[HF88] 오늘 할 일 화면
 * PIPELINE[HF87, HF51, HB95] 연관 모듈
 */
// 역할 — React 상태·효과·메모
import { useCallback, useEffect, useMemo, useState } from "react";
// 역할 — 화면 이동
import { useNavigate } from "react-router-dom";
// 역할 — 오늘 과제 API
import { listTodayTasks, type WorkflowRow } from "@/api/taskWorkflowApi";
// 역할 — 결재대기·최근 문서
import { listApprovalInbox, listDocuments, type DocumentListRow } from "@/api/documentApi";
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
import { cn } from "@/lib/cn";
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";

type FilterKind = "ALL" | "TASK" | "CA" | "APPR";
type TaskRow = WorkflowRow & { _key?: string; dueText?: string; typeNm?: string };
type DocRow = DocumentListRow & { _key?: string };

function todayYmd(): string {
  const d = new Date();
  return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) KPI·오늘과제·최근문서를 한 화면에서 제공한다
 *   2) screenRegistry today-tasks · 홈 "/" 리다이렉트 대상이다
 *   3) API 실패는 업무 토스트만 표시한다
 */
export default function TodayTasksPage() {
  const navigate = useNavigate();
  const asyncAct = useAsyncAction();
  // h=오늘 할 일, d=최근 문서 — 활성 패널 강조
  const sec = useSection();
  const [tasks, setTasks] = useState<WorkflowRow[]>([]);
  const [docs, setDocs] = useState<DocumentListRow[]>([]);
  const [approvalCnt, setApprovalCnt] = useState(0);
  const [filter, setFilter] = useState<FilterKind>("ALL");
  const [taskActiveKey, setTaskActiveKey] = useState<string | null>(null);
  const [docActiveKey, setDocActiveKey] = useState<string | null>(null);

  const taskColumns = useMemo<GridColumn<TaskRow>[]>(() => [
    { field: "typeNm", header: "구분", width: 90 },
    { field: "title", header: "업무", width: 220 },
    { field: "status", header: "상태", width: 80 },
    { field: "dueText", header: "마감", width: 120 },
  ], []);

  const docColumns = useMemo<GridColumn<DocRow>[]>(() => [
    { field: "tmplNm", header: "문서", width: 180 },
    { field: "docNo", header: "문서번호", width: 140 },
    { field: "status", header: "상태", width: 80 },
    { field: "baseDt", header: "기준일", width: 100 },
  ], []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-07
   * 코멘트:
   *   1) 과제·최근문서·결재대기 건수를 병렬 재조회한다
   *   2) 새로고침·셸 조회에서 호출한다
   *   3) 실패 시 기존 데이터를 유지하고 오류만 안내한다
   */
  const load = useCallback(async () => {
    try {
      const ymd = todayYmd();
      const [nextTasks, nextDocs, approvalList] = await Promise.all([
        listTodayTasks(),
        listDocuments({ fromDt: ymd.slice(0, 6) + "01", toDt: ymd }),
        listApprovalInbox({ fromDt: ymd.slice(0, 6) + "01", toDt: ymd }),
      ]);
      setTasks(nextTasks);
      setDocs(nextDocs.slice(0, 50));
      setApprovalCnt(approvalList.length);
    } catch (error) {
      mesError(error);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  usePageCommands({
    search: () => { void asyncAct.run(load, "search"); },
  });

  const openTask = (row: WorkflowRow) => {
    const screen = String(row.linkScrnCd ?? "");
    if (screen) navigate(routeOf(screen));
  };

  const taskCnt = useMemo(
    () => tasks.filter((row) => String(row.taskType ?? "").toUpperCase() !== "CA").length,
    [tasks],
  );
  const caCnt = useMemo(
    () => tasks.filter((row) => String(row.taskType ?? "").toUpperCase() === "CA").length,
    [tasks],
  );

  const filteredTasks = useMemo(() => {
    if (filter === "CA") return tasks.filter((row) => String(row.taskType ?? "").toUpperCase() === "CA");
    if (filter === "TASK") return tasks.filter((row) => String(row.taskType ?? "").toUpperCase() !== "CA");
    if (filter === "APPR") return [];
    return tasks;
  }, [filter, tasks]);

  const taskRows = useMemo<TaskRow[]>(
    () => filteredTasks.map((row, index) => ({
      ...row,
      _key: String(row.taskIdx ?? row.idx ?? `${row.taskType ?? "t"}-${index}`),
      typeNm: String(row.taskType ?? ""),
      dueText: `${String(row.dueDt ?? "")} ${String(row.dueTime ?? "")}`.trim(),
    })),
    [filteredTasks],
  );

  const docRows = useMemo<DocRow[]>(
    () => docs.map((row) => ({ ...row, _key: String(row.docIdx) })),
    [docs],
  );

  const cardCls = (active: boolean) =>
    cn(
      "cursor-pointer rounded border bg-white p-3 text-left transition hover:border-sky-300 hover:bg-sky-50",
      active ? "border-sky-400 ring-1 ring-sky-200" : "border-slate-200",
    );

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 p-3">
      <div className="flex items-center justify-between rounded border border-slate-200 bg-white p-3">
        <div>
          <h1 className="text-base font-semibold text-slate-800">오늘 할 일</h1>
          <p className="text-xs text-slate-500">작성·결재 현황을 확인하고 문서로 바로 이동합니다.</p>
        </div>
        <MesButton
          // 대시보드 전체 재조회
          variant="search"
          disabled={asyncAct.isBusy("search")}
          onClick={() => void asyncAct.run(load, "search")}
        >
          새로고침
        </MesButton>
      </div>

      <div className="grid grid-cols-2 gap-2 lg:grid-cols-4">
        <button type="button" className={cardCls(filter === "TASK")} onClick={() => setFilter(filter === "TASK" ? "ALL" : "TASK")}>
          <div className="text-xs text-slate-500">오늘 작성·과제</div>
          <div className="mt-1 text-2xl font-semibold text-slate-800">{taskCnt}</div>
        </button>
        <button
          type="button"
          className={cardCls(filter === "APPR")}
          onClick={() => { setFilter("APPR"); navigate(routeOf("approval-inbox")); }}
        >
          <div className="text-xs text-slate-500">미결재</div>
          <div className="mt-1 text-2xl font-semibold text-amber-700">{approvalCnt}</div>
        </button>
        <button type="button" className={cardCls(filter === "CA")} onClick={() => setFilter(filter === "CA" ? "ALL" : "CA")}>
          <div className="text-xs text-slate-500">이탈·개선조치</div>
          <div className="mt-1 text-2xl font-semibold text-red-700">{caCnt}</div>
        </button>
        <button type="button" className={cardCls(false)} onClick={() => navigate(routeOf("document-inbox"))}>
          <div className="text-xs text-slate-500">이번달 문서</div>
          <div className="mt-1 text-2xl font-semibold text-sky-700">{docs.length}</div>
        </button>
      </div>

      <div className="grid min-h-0 flex-1 grid-cols-1 gap-3 lg:grid-cols-2">
        <div {...sec.bind("h", gridPanelClass)}>
          <div className={gridHeadClass}>
            {/* 보이는 그리드명 — title prop과 동일 */}
            <b>오늘 할 일</b>
          </div>
          {taskRows.length === 0 ? (
            <div className="flex flex-1 flex-col items-center justify-center gap-3 p-6 text-center">
              <p className="text-sm text-slate-500">오늘 예정된 과제가 없습니다.</p>
              <div className="flex flex-wrap justify-center gap-2">
                <MesButton variant="primary" size="sm" onClick={() => navigate(routeOf("daily-hygiene-check"))}>일일위생점검표</MesButton>
                <MesButton variant="secondary" size="sm" onClick={() => navigate(routeOf("ccp-cold-monitor"))}>냉장냉동모니터링</MesButton>
                <MesButton variant="secondary" size="sm" onClick={() => navigate(routeOf("document-inbox"))}>문서함</MesButton>
              </div>
            </div>
          ) : (
            <MesEditableGrid
              // 오늘 과제 그리드 설정 키
              persistId="tsk-today-tasks"
              // 필터된 과제 행
              rows={taskRows as EditableRow<TaskRow>[]}
              // 구분·업무·상태·마감
              columns={taskColumns}
              // 읽기 전용 — 행 활성화로 화면 이동
              editable={false}
              // 패널 제목
              title="오늘 할 일"
              // 부모 flex 높이 채움
              height="100%"
              // 조회 busy
              loading={asyncAct.isBusy("search")}
              // 활성 행
              activeKey={taskActiveKey}
              // 행 클릭 시 업무 화면 이동
              onActivate={(row) => {
                sec.setSec("h");
                setTaskActiveKey(row._key ?? null);
                openTask(row);
              }}
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
          {docRows.length === 0 ? (
            <div className="flex flex-1 flex-col items-center justify-center gap-3 p-6 text-center">
              <p className="text-sm text-slate-500">이번달 최근 문서가 없습니다.</p>
              <MesButton variant="secondary" size="sm" onClick={() => navigate(routeOf("document-inbox"))}>문서함 열기</MesButton>
            </div>
          ) : (
            <MesEditableGrid
              // 최근 문서 그리드 설정 키
              persistId="tsk-today-recent-docs"
              // 최근 문서 행
              rows={docRows as EditableRow<DocRow>[]}
              // 문서·번호·상태·기준일
              columns={docColumns}
              // 읽기 전용
              editable={false}
              // 패널 제목
              title="최근 문서"
              // 부모 flex 높이 채움
              height="100%"
              // 조회 busy
              loading={asyncAct.isBusy("search")}
              // 활성 문서
              activeKey={docActiveKey}
              // 행 클릭 시 작성 화면 deep-link
              onActivate={(row) => {
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
            />
          )}
        </div>
      </div>
    </div>
  );
}
