/**
 * MesDataGrid — 읽기전용 그리드 (useMesTable + 가상스크롤 + pref).
 *
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) loading 중에도 table을 유지하고 GridLoadingOverlay만 띄운다
 *   2) pref는 persistId + scrnCd(prop 또는 PageScrnContext)로 저장한다
 *   3) 코드 룩업·로그 그리드도 scrnCd prop으로 열 너비·숨김을 DB에 남긴다
 *   4) singleSelect는 라디오 리드 열 — activeKey와 동기이며 selectable(다중 체크박스)과 같이 쓰지 않는다
 *
 * PIPELINE[F89] 읽기전용 데이터 그리드
 * PIPELINE[F90, F75, F173] 연관 모듈
 */
// 역할 — React 훅·ref
import { useCallback, useContext, useEffect, useRef } from "react";
// 역할 — 화면코드 — pref 저장 키
import { PageScrnContext } from "@/shell/pageCommands";
// 역할 — 그리드 컬럼·MesDataGrid Props 타입
import type { GridColumn, MesDataGridProps } from "@/types/grid";
// 역할 — 날짜·숫자 표시 포맷
import { fmtDate, fmtDateTime, fmtNumber } from "@/utils/date";
// 역할 — TanStack Table 뷰 상태 훅
import { useMesTable } from "./useMesTable";
// 역할 — CSV보내기
import { exportCsv } from "./gridCsv";
// 역할 — 셀 정렬·열 너비 고정 스타일
import { colAlign, colWidthStyle } from "./gridUtils";
// 역할 — 툴바·헤더·필터·푸터 UI
import { GridToolbar, GridHeadCell, GridFilterRow, GridFooter, GridSelectHeadCell, gridLeadLeftPx } from "./GridChrome";
// 역할 — 데이터 갱신 중 오버레이 — loading 중 테이블 유지(skeleton 교체 금지)
import { GridLoadingOverlay } from "./GridLoadingOverlay";
// 역할 — 조회 결과 없음 표시
import { GridEmptyState } from "./GridEmptyState";
// 역할 — 행번호·셀 텍스트/배지 표시
import { GridRowNumCell, GridCellDisplay } from "./GridCellDisplay";
// 역할 — 대량 행 가상 스크롤·활성 행 스크롤(F173)
import { useGridVirtual, scrollGridToActiveRow } from "./useGridVirtual";
// 역할 — 그리드 런타임 오류 격리
import { GridErrorBoundary } from "./GridErrorBoundary";
// 역할 — 셀 버튼 더보기 아이콘
import { MoreHorizontal } from "lucide-react";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 셀 표면 클래스
import { gridCellSurfaceClass } from "./gridCellClasses";

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) ErrorBoundary 래퍼
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — ErrorBoundary 래퍼
export function MesDataGrid<T extends Record<string, any>>(props: MesDataGridProps<T>) {
  return (
    <GridErrorBoundary label={props.persistId ?? props.title ?? "data"}>
      <MesDataGridInner {...props} />
    </GridErrorBoundary>
  );
}

// 설명 — 읽기전용 그리드 본체
function MesDataGridInner<T extends Record<string, any>>(props: MesDataGridProps<T>) {
  const {
    rows, columns, rowKey, loading, height = 320, activeKey,
    // 행번호 열 표시 여부
    // 기본 true — 키오스크 등에서 false로 줄일 수 있음
    showRowNum = true, showToolbar = true, showFooter = true, sortable = true,
    rowNumHeader = "",
    // 행 다중선택(__select) 옵트인
    // 기본 off — 삭제는 페이지 activeKey 단건 유지 패턴과 병행
    selectable = false,
    // 단건 라디오 리드 열 — activeKey 행이 켜진다. selectable과 같이 쓰지 않는다
    singleSelect = false,
    onSelectionChange,
  } = props;
  // pref 저장용 화면코드 — prop 우선, 없으면 셸 PageScrnContext
  const ctxScrnCd = useContext(PageScrnContext);
  const scrnCd = props.scrnCd || ctxScrnCd;

// 설명 — rowKey 필드 또는 함수로 행 id 추출
  const getRowId = useCallback(
    (r: T) => (typeof rowKey === "function" ? rowKey(r) : String(r[rowKey])),
    [rowKey],
  );

// 설명 — 필터·정렬·CSV용 셀 텍스트(날짜·숫자·코드 포맷)
  const cellText = useCallback((r: T, c: GridColumn<T>): string => {
    const v = r[c.field];
    switch (c.type) {
      case "date": return fmtDate(v as string);
      case "datetime": return fmtDateTime(v as string);
      case "number":
      case "amount": return v === null || v === undefined || v === "" ? "" : fmtNumber(Number(v));
      case "code": return c.codeMap?.[String(v)] ?? String(v ?? "");
      default: return v === null || v === undefined ? "" : String(v);
    }
  }, []);

// 설명 — TanStack 뷰 — 읽기전용 mode
  const view = useMesTable<T>({
    columns,
    data: rows,
    getRowId,
    persistId: props.persistId,
    scrnCd,
    enableRowSelection: selectable,
    cellText,
    meta: { mode: "view" },
  });
  const cols = view.visibleCols;

// 설명 — 다중선택 변경 시 onSelectionChange 콜백
  const prevSel = useRef("");
  useEffect(() => {
    if (!selectable || !onSelectionChange) return;
    const keys = Object.keys(view.rowSelection).filter((k) => view.rowSelection[k]).sort().join(",");
    if (keys === prevSel.current) return;
    prevSel.current = keys;
    onSelectionChange(view.table.getSelectedRowModel().rows.map((r) => r.original));
  }, [view.rowSelection, selectable, onSelectionChange, view.table]);

// 설명 — 스크롤·가상화
  const scrollRef = useRef<HTMLDivElement>(null);
  const virt = useGridVirtual(scrollRef, view.displayRows.length);

  // 설명 — 활성 행 변경 시 스크롤 (F173) — 가상화 시 scrollToIndex
  useEffect(() => {
    if (!activeKey) return;
    const idx = view.table.getRowModel().rows.findIndex((r) => r.id === activeKey);
    scrollGridToActiveRow({ scrollRef, activeKey, rowIndex: idx, virt });
  }, [activeKey, rows.length, view.displayRows.length, virt.active]); // eslint-disable-line react-hooks/exhaustive-deps

// 설명 — height 100%/auto 시 flex fill 레이아웃
  const fill = height === "100%" || height === "auto";
  const leadCols = (showRowNum ? 1 : 0) + (singleSelect ? 1 : 0) + (selectable ? 1 : 0);
  const leadLeft = gridLeadLeftPx({ showRowNum, selectable, singleSelect });
  // 라디오는 행번호 다음, 다중 체크박스는 그 다음
  const singleLeft = showRowNum ? 32 : 0;
  const selectLeft = singleLeft + (singleSelect ? 36 : 0);

// 설명 — 왼쪽 pin 열 sticky left offset 계산
  const pinLeftStyle = (field: string): React.CSSProperties | undefined => {
    const left = view.columnPinning.left ?? [];
    const idx = left.indexOf(field);
    if (idx < 0) return undefined;
    let offset = leadLeft;
    for (let i = 0; i < idx; i++) {
      const id = left[i];
      if (id === "__select") continue;
      const c = cols.find((x) => x.field === id);
      if (c) offset += view.widthOf(c);
    }
    return { position: "sticky", left: offset, zIndex: 2 };
  };

// 설명 — tbody 행 렌더 — 가상스크롤 padding + 클릭/더블클릭
  const renderBodyRows = () => {
    const all = view.table.getRowModel().rows;
    const indices = virt.active
      ? virt.virtualRows.map((v) => v.index)
      : all.map((_, i) => i);

    return (
      <>
        {virt.active && virt.paddingTop > 0 && (
          <tr aria-hidden><td colSpan={cols.length + leadCols} style={{ height: virt.paddingTop, padding: 0, border: 0 }} /></tr>
        )}
        {indices.map((i) => {
          const row = all[i];
          if (!row) return null;
          const r = row.original;
          const k = row.id;
          const active = k === activeKey;
          return (
            <tr key={k} data-key={k} className={active ? "mes-row-active" : ""}
              // 클릭 핸들러
              // 비동기면 run/useAsyncAction으로 중복 클릭 방지 권장
              onClick={() => { props.onSetActive?.(); props.onRowClick?.(r); }}
              // onDoubleClick — 호출부/컴포넌트에 전달되는 의미 있는 값
              // 변경 시 화면·훅 동작에 영향 — 기본값·nullable 여부 확인
              onDoubleClick={() => props.onRowDoubleClick?.(r)}>
              {showRowNum && <GridRowNumCell index={i} active={active} />}
              {singleSelect && (
                <td
                  // 단건 라디오 — activeKey와 동기. 클릭은 onRowClick만
                  className="mes-col-select mes-col-pinned"
                  style={{ width: 36, position: "sticky", left: singleLeft }}
                  onClick={(e) => e.stopPropagation()}
                >
                  <div className="mes-cell mes-cellwrap mes-align-center">
                    <input
                      // HTML radio — 같은 persistId 그리드에서 1건만
                      type="radio"
                      name={`${props.persistId ?? "mes-grid"}-single`}
                      className="h-3.5 w-3.5 border-slate-300"
                      // 활성 행일 때 켜짐 — activeKey와 동기
                      checked={active}
                      // 라디오 클릭 — 행 클릭과 동일하게 onRowClick
                      onChange={() => { props.onSetActive?.(); props.onRowClick?.(r); }}
                      title="이 행 선택"
                    />
                  </div>
                </td>
              )}
              {selectable && (
                <td
                  // 추가 Tailwind/CSS 클래스
                  // 기본 스타일 위에 병합(cn)
                  className="mes-col-select mes-col-pinned"
                  style={{ width: 36, position: "sticky", left: selectLeft }}
                  // 클릭 핸들러
                  // 비동기면 run/useAsyncAction으로 중복 클릭 방지 권장
                  onClick={(e) => e.stopPropagation()}
                >
                  <div className="mes-cell mes-cellwrap mes-align-center">
                    <input
                      // HTML button/input type
                      // 폼 안 조회 버튼은 submit
                      type="checkbox"
                      // 추가 Tailwind/CSS 클래스
                      // 기본 스타일 위에 병합(cn)
                      className="h-3.5 w-3.5 rounded border-slate-300"
                      // 체크박스 선택 여부
                      // 제어 컴포넌트 value
                      checked={row.getIsSelected()}
                      // 값 변경 콜백
                      // 입력·체크·셀렉트 공통
                      onChange={row.getToggleSelectedHandler()}
                    />
                  </div>
                </td>
              )}
              {cols.map((c) => {
                const align = colAlign(c);
                const btn = c.cellButton;
                const text = cellText(r, c);
                const val = r[c.field];
                const pin = pinLeftStyle(c.field);
                // 열 너비 고정 — th와 동일 width/min/max
                const cellStyle = { ...colWidthStyle(view.widthOf(c)), ...pin };
                return (
                  <td
                    // 행 _key 또는 busy 키
                    // updateCell·run·포커스 식별에 사용
                    key={c.field}
                    // 추가 Tailwind/CSS 클래스
                    // 기본 스타일 위에 병합(cn)
                    className={cn(
                      gridCellSurfaceClass({ locked: false, required: c.required, value: val }),
                      pin && "mes-col-pinned",
                    )}
                    // 열 너비 고정 + pin sticky
                    style={cellStyle}
                  >
                    <div className={`mes-cell mes-cellwrap mes-align-${align}`}>
                      <GridCellDisplay row={r} col={c} text={text} />
                      {btn && (
                        <button type="button" className={cn("mes-cell-btn", c.required && "mes-cell-btn-required")} title={btn.title}
                          // 클릭 핸들러
                          // 비동기면 run/useAsyncAction으로 중복 클릭 방지 권장
                          onClick={(e) => { e.stopPropagation(); props.onRowClick?.(r); btn.onClick(r); }}>
                          <MoreHorizontal className="h-3 w-3" aria-hidden />
                        </button>
                      )}
                    </div>
                  </td>
                );
              })}
            </tr>
          );
        })}
        {virt.active && virt.paddingBottom > 0 && (
          <tr aria-hidden><td colSpan={cols.length + leadCols} style={{ height: virt.paddingBottom, padding: 0, border: 0 }} /></tr>
        )}
      </>
    );
  };

  return (
    <div
      // grid 행: 툴바 / 본문(1fr) / 푸터 — 총 n건이 마지막 행을 가리지 않음
      className={cn(
        "mes-grid-wrap",
        !showToolbar && "mes-grid-no-toolbar",
        !showFooter && "mes-grid-no-footer",
        fill
          ? "mes-grid-embedded mes-grid-fill min-h-0"
          : "overflow-hidden rounded-xl border border-slate-200 shadow-sm",
      )}
      style={fill ? undefined : { height }}
    >
      {showToolbar && (
        <GridToolbar view={view} columns={columns}
          onExport={() => exportCsv(props.title ?? "grid", cols, view.displayRows, cellText)} />
      )}
      <div className="mes-grid-body">
        <div ref={scrollRef} className="mes-grid-scroll">
          {/* loading 중에도 table 유지 — skeleton 교체 시 깜박임 방지 */}
          <table className="mes-grid">
            <thead>
              <tr>
                {showRowNum && <th className="mes-rownum">{rowNumHeader}</th>}
                {singleSelect && (
                  <th
                    // 단건 라디오 헤더 — 전체선택 없음
                    className="mes-rownum mes-col-pinned mes-col-select p-0"
                    style={{ width: 36, position: "sticky", left: singleLeft, zIndex: 4 }}
                  />
                )}
                {selectable && <GridSelectHeadCell view={view} leftOffset={selectLeft} />}
                {cols.map((c) => (
                  <GridHeadCell key={c.field} col={c} view={view} sortable={sortable} leadLeftPx={leadLeft} />
                ))}
              </tr>
            </thead>
            {view.showFilter && <GridFilterRow cols={cols} view={view} leadCols={leadCols} />}
            <tbody>
              {renderBodyRows()}
            </tbody>
          </table>
        </div>
        {!loading && view.displayRows.length === 0 && (
          <GridEmptyState variant="overlay" withFilter={view.showFilter} hint="조회 조건을 변경해 다시 조회하세요." />
        )}
        <GridLoadingOverlay show={!!loading} />
      </div>
      {showFooter && (
        <GridFooter cols={cols} total={view.totalCount} shown={view.shownCount} aggregates={view.aggregates} />
      )}
    </div>
  );
}
