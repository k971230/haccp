/**
 * HwpTaskLookupModal — 오늘 할일 HWP 문서주기 선택 팝업.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 행 추가를 누르면 먼저 뜬다 — 오늘 처리해야 할 HWP 문서주기를 고르는 자리다
 *   2) 고르면 그 양식·기준일로 행이 채워지고 rhwp 가 그 양식을 연다
 *   3) 취소하면 빈 행만 추가되고 양식 선택 팝업으로 이어진다 — 주기와 무관한 임의 작성 경로다
 *
 * 겉모양·조작은 양식 선택 팝업(HtmlFormLookupModal)과 같게 맞춘다.
 * 두 팝업이 연달아 뜨므로 서로 달라 보이면 사용자가 다른 기능으로 읽는다.
 *
 * PIPELINE[HF183] HWP 오늘 할일 팝업
 */
// 역할 — 선택 상태
import { useMemo, useState } from "react";
// 역할 — 조회 전용 그리드
import { MesDataGrid } from "@/components/grid/MesDataGrid";
// 역할 — 표준 버튼
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 팝업 헤더(보라 accent)
import { gridHeadClass } from "@/components/layout/pageClasses";
// 역할 — 공통 모달 바디 높이 — 양식 선택 팝업과 같은 크기
import { COMMON_MODAL_BODY_H } from "@/components/common/modal/modalTypes";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 오늘 할일 행
import type { HwpDraftTask } from "@/api/draft/hwpDraftApi";

/** 할일 상태 표시 — 코드값을 사용자 문구로 바꾼다. 새 코드 도메인을 만들지 않는다 */
const TASK_STATUS_NM: Record<string, string> = {
  TODO: "예정",
  ING: "진행",
  LATE: "지연",
};

/** 팝업 그리드 행 — 상태 문구를 미리 붙인다 */
type TaskLookupRow = HwpDraftTask & { statusNm: string };

export function HwpTaskLookupModal({
  // scrnCd: 열 너비 pref 화면코드
  scrnCd,
  // tasks: 오늘 할일 목록 — 행 추가 직전에 조회한 값
  tasks,
  // onSelect: 선택 확정 — 그 양식·기준일로 행을 채운다
  onSelect,
  // onSkip: 취소 — 빈 행만 추가하고 양식 선택 팝업으로 넘긴다
  onSkip,
}: {
  scrnCd: string;
  tasks: HwpDraftTask[];
  onSelect: (task: HwpDraftTask) => void;
  onSkip: () => void;
}) {
  const title = "오늘 할일 — HWP 문서주기";
  const [picked, setPicked] = useState<string | null>(null);

  const rows = useMemo<TaskLookupRow[]>(
    () => tasks.map((task) => ({ ...task, statusNm: TASK_STATUS_NM[task.status] ?? task.status })),
    [tasks],
  );

  const columns = useMemo<GridColumn<TaskLookupRow>[]>(
    () => [
      {
        // 양식명 — 무엇을 쓰는 일인지 가장 먼저 읽는 칸
        field: "tmplNm",
        header: "양식명",
        width: 220,
      },
      {
        // 양식코드 — 선택 시 작성 행에 그대로 들어간다
        field: "tmplCd",
        header: "양식코드",
        width: 150,
      },
      {
        // 마감일 — 지연 여부를 눈으로 본다
        field: "dueDt",
        header: "마감일",
        width: 100,
      },
      {
        // 상태 — 예정·진행·지연
        field: "statusNm",
        header: "상태",
        width: 70,
      },
    ],
    [],
  );

  const pick = (row: TaskLookupRow) => {
    onSelect(row);
  };

  return (
    <div
      // 오늘 할일 팝업 오버레이 — 배경 클릭 시 취소(빈 행 추가)로 넘어간다
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label={title}
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onSkip();
      }}
    >
      <div
        className="flex w-full max-w-lg flex-col overflow-hidden rounded border border-slate-200 bg-white shadow-lg"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <div
          // 양식 선택 팝업과 같은 헤더 — 보라 accent
          className={cn(gridHeadClass, "mes-modal-grid-head")}
        >
          <b>{title}</b>
        </div>
        <div className="flex flex-col gap-2 p-3">
          <p className="text-xs text-slate-500">
            오늘 처리할 문서주기를 고르면 그 양식으로 작성을 시작합니다.
            주기와 무관하게 쓰려면 취소를 누르세요.
          </p>
          <MesDataGrid
            // 열 설정 저장 키 — 양식 선택 팝업과 나눠 둔다
            persistId="hwp-draft-task-lookup"
            // pref 저장용 화면코드
            scrnCd={scrnCd}
            rows={rows}
            columns={columns}
            // 할일 idx 가 행 키
            rowKey={(r) => String(r.taskIdx)}
            activeKey={picked}
            showToolbar
            showFooter
            showRowNum={false}
            sortable
            height={COMMON_MODAL_BODY_H}
            title={title}
            // 행 클릭 — 바로 확정한다. 양식 선택 팝업과 같은 조작이다
            onRowClick={pick}
          />
        </div>
        <div
          // 공통 모달 푸터 — 취소 우측 끝
          className="flex shrink-0 items-center justify-end gap-2 border-t border-slate-200 bg-slate-50/70 px-3 py-2.5"
        >
          <MesButton
            // 취소 — 닫기가 아니라 빈 행 추가로 이어진다. 문구로 그 뜻을 밝힌다
            variant="secondary"
            onClick={() => { setPicked(null); onSkip(); }}
          >
            취소 (양식 직접 선택)
          </MesButton>
        </div>
      </div>
    </div>
  );
}
