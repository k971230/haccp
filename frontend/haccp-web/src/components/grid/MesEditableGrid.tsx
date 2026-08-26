/**
 * MesEditableGrid — 편집 그리드.
 * useMesTable + useEditableRows/rules(meta) + activeCell 키보드 네비.
 *
 * 확정 UX (docs/07 ADR-031·032 · docs/02 그리드 UX):
 *   - 덮개식 편집: .mes-cellwrap-editing + .mes-egrid-input absolute inset — 행 높이(h-mes-row) 고정
 *   - 열 너비: td style=colWidthStyle(widthOf) + .mes-grid table-layout:fixed — 데이터 글자수와 무관
 *   - 입력 검증: col.maxLength / sanitize / validate · 콤보 oneOfCodes (BE MesPatterns·RefValidation 대칭)
 *   - 키보드: 비편집 ArrowUp/Down=행이동, Tab=셀이동(목적지 canEdit일 때만 편집). Left/Right는 쓰지 않음
 *
 * PIPELINE[F90] 편집 가능 그리드
 * PIPELINE[F75, F83, F52, F173] 연관 모듈
 */
// 역할 — React 훅·이벤트·ref 타입
import { useCallback, useContext, useEffect, useRef, useState, type KeyboardEvent, type MouseEvent } from "react";
// 역할 — 화면코드 — pref 저장 키
import { PageScrnContext } from "@/shell/pageCommands";
// 역할 — 그리드 컬럼·접근제어 Props 타입
import { codeSelectHasEmptyOption, type GridColumn, type GridAccessProps } from "@/types/grid";
// 역할 — 편집 행 타입
import type { EditableRow } from "@/types/editable";
// 역할 — gridRules 잠금 판정용 행 타입
import type { GridRow } from "@/shell/gridRules/types";
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
// 역할 — 대량 행 가상 스크롤
import { useGridVirtual, scrollGridToActiveRow } from "./useGridVirtual";
// 역할 — 키보드 행/셀 좌표·툴바 입력 가드
import { isTypingTarget, nextCell, nextRowIndex } from "./gridNav";
// 역할 — 그리드 런타임 오류 격리
import { GridErrorBoundary } from "./GridErrorBoundary";
// 역할 — 셀 버튼 더보기 아이콘
import { MoreHorizontal } from "lucide-react";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 셀 표면(locked/required/editable) 클래스
import { gridCellSurfaceClass } from "./gridCellClasses";

interface MesEditableGridProps<T extends Record<string, any>> extends GridAccessProps {
  rows: EditableRow<T>[];
  columns: GridColumn<T>[];
  height?: number | string;
  editable?: boolean;
  activeKey?: string | null;
  loading?: boolean;
  title?: string;
  showRowNum?: boolean;
  onActivate?: (row: EditableRow<T>) => void;
  /** 행 더블클릭 — 오늘 할 일처럼 화면 이동은 클릭과 같이 쓸 수 있다 */
  onRowDoubleClick?: (row: EditableRow<T>) => void;
  /** 행 tr 추가 클래스 — 기한경과 빨강(mes-row-overdue) 등 */
  rowClassName?: (row: EditableRow<T>) => string | undefined;
  onCellChange?: (key: string, field: keyof T, value: unknown) => void;
  onSetActive?: () => void;
  suppressActivate?: boolean;
  /** 키오스크: 인라인 대신 cellButton 팝업 */
  touchKiosk?: boolean;
  /** pref v2 저장 키 (화면 내 그리드 id) */
  persistId?: string;
  /** pref 저장용 화면코드 — 없으면 PageScrnContext */
  scrnCd?: string;
  /** 행 다중선택 (__select; 데이터 Y/N checkbox와 별개) — ADR-026 삭제용 */
  selectable?: boolean;
  /** 체크 선택 변경 시 부모에 선택 행 전달 */
  onSelectionChange?: (rows: EditableRow<T>[]) => void;
  /** 값 변경 시 체크 선택 초기화 — 삭제 후 clearSelection 연동 */
  selectionResetKey?: number | string;
  /** 하단 총 N건 푸터 — 헤더에 건수를 안 두는 화면은 false */
  showFooter?: boolean;
  /** 빈 그리드 제목 — 마스터 미선택 디테일은 MES.noInfo */
  emptyTitle?: string;
  /** 빈 그리드 힌트 — 기본은 조회 조건 안내 */
  emptyHint?: string;
}

// 설명 — 숫자 셀 표시 포맷 — 천단위 구분
const numFmt = (v: unknown) =>
  v === null || v === undefined || v === "" ? "" : Number(v).toLocaleString(undefined, { maximumFractionDigits: 4 });

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) ErrorBoundary 래퍼 — 오류 시 그리드만 격리
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — ErrorBoundary 래퍼 — 오류 시 그리드만 격리
export function MesEditableGrid<T extends Record<string, any>>(props: MesEditableGridProps<T>) {
  return (
    <GridErrorBoundary label={props.persistId ?? props.title ?? "edit"}>
      <MesEditableGridInner {...props} />
    </GridErrorBoundary>
  );
}

// 설명 — 편집 그리드 본체 — useMesTable + 셀 편집·키보드 네비
function MesEditableGridInner<T extends Record<string, any>>(props: MesEditableGridProps<T>) {
  const { rows, height = 320, editable, activeKey, loading, showRowNum = true, showFooter = true, access, onLockedAttempt, touchKiosk, selectable } = props;
  type ER = EditableRow<T>;
  const columns = props.columns as unknown as GridColumn<ER>[];
  // pref 저장용 화면코드 — prop 우선, 없으면 셸 PageScrnContext
  const ctxScrnCd = useContext(PageScrnContext);
  const scrnCd = props.scrnCd || ctxScrnCd;

  // Y/N 체크박스 값 판정
  const isYnChecked = (v: unknown) => {
    if (v === 1 || v === true) return true;
    const s = String(v ?? "N").toUpperCase();
    return s === "Y" || s === "1" || s === "TRUE" || s === "T";
  };

// 설명 — 필터·정렬·CSV용 셀 텍스트 변환
  const cellText = useCallback((row: ER, c: GridColumn<ER>): string => {
    const v = row[c.field];
    if (c.type === "checkbox" || c.type === "radio") return isYnChecked(v) ? "Y" : "N";
    if (c.type === "code") return c.codeMap?.[String(v)] ?? String(v ?? "");
    if (c.type === "number" || c.type === "amount") return numFmt(v);
    return v === null || v === undefined ? "" : String(v);
  }, []);

// 설명 — 컬럼·행 기본 편집 가능 여부(키오스크 cellButton 제외)
  const baseEditable = (c: GridColumn<ER>, isNew: boolean) => {
    if (touchKiosk && c.cellButton) return false;
    return !!editable && (c.editableOnNew ? isNew : !!c.editable);
  };

// 설명 — gridRules access 포함 최종 편집 가능 판정
  const canEdit = useCallback((row: ER, c: GridColumn<ER>, isNew: boolean) => {
    if (!baseEditable(c, isNew)) return false;
    if (!access) return true;
    return access.canEditCell(row as EditableRow<GridRow>, c.field).ok;
  }, [access, editable, touchKiosk]); // eslint-disable-line react-hooks/exhaustive-deps

// 설명 — TanStack 뷰 + 편집 meta(dirty-pin, updateCell, isCellEditable)
  const view = useMesTable<ER>({
    columns,
    data: rows,
    getRowId: (r) => r._key,
    persistId: props.persistId,
    scrnCd,
    enableDirtyPin: true,
    enableRowSelection: !!selectable,
    cellText,
    meta: {
      mode: "edit",
      updateCell: (rowKey, field, value) => {
        props.onCellChange?.(rowKey, field as keyof T, value);
      },
      isCellEditable: (row, field) => {
        const c = columns.find((x) => x.field === field);
        if (!c) return false;
        return canEdit(row, c, row._rowState === "C");
      },
    },
  });
  const cols = view.visibleCols;

// 설명 — 다중선택 변경 시 onSelectionChange 콜백
  const prevSel = useRef("");
  useEffect(() => {
    if (!selectable || !props.onSelectionChange) return;
    const keys = Object.keys(view.rowSelection).filter((k) => view.rowSelection[k]).sort().join(",");
    if (keys === prevSel.current) return;
    prevSel.current = keys;
    props.onSelectionChange?.(view.table.getSelectedRowModel().rows.map((r) => r.original));
  }, [view.rowSelection, selectable, props.onSelectionChange, view.table]); // eslint-disable-line react-hooks/exhaustive-deps

  // selectionResetKey 변경 시(= 삭제 후 clearSelection) 체크 선택 비움
  useEffect(() => {
    if (!selectable) return;
    if (props.selectionResetKey === undefined) return;
    view.setRowSelection({});
    prevSel.current = "";
  }, [props.selectionResetKey]); // eslint-disable-line react-hooks/exhaustive-deps

  const kioskBtnVisible = (c: GridColumn<ER>, isNew: boolean) =>
    !!touchKiosk && !!c.cellButton && (!c.cellButton.showOnNew || isNew);

  const fireCellBtn = (row: ER, c: GridColumn<ER>, isNew: boolean, e?: MouseEvent) => {
    const btn = c.cellButton && (!c.cellButton.showOnNew || isNew) ? c.cellButton : null;
    if (!btn) return;
    e?.stopPropagation();
    props.onActivate?.(row);
    btn.onClick(row);
  };

// 설명 — 셀 검증 오류 메시지 맵(key|field)
  const [cellErr, setCellErr] = useState<Record<string, string>>({});

// 설명 — 셀 값 변경 — access 잠금·validate·onCellChange
  const changeCell = (row: ER, c: GridColumn<ER>, value: unknown, isNew: boolean) => {
    if (!canEdit(row, c, isNew)) {
      const reason = access?.canEditCell(row as EditableRow<GridRow>, c.field).reason;
      if (reason) onLockedAttempt?.(reason, c.field);
      return;
    }
    if (c.validate) {
      const m = c.validate(value, row);
      setCellErr((s) => {
        const k = `${row._key}|${c.field}`;
        if (m) return { ...s, [k]: m };
        if (!(k in s)) return s;
        const next = { ...s }; delete next[k]; return next;
      });
    }
    props.onCellChange?.(row._key, c.field as keyof T, value);
  };

// 설명 — 스크롤 컨테이너 ref — 가상스크롤·포커스 스크롤
  const scrollRef = useRef<HTMLDivElement>(null);
  // wrap tabIndex=0 — 잠금 셀 클릭 후 방향키가 onGridKeyDown으로 들어오게 focus
  const wrapRef = useRef<HTMLDivElement>(null);
  // 마지막 활성 열 — 행만 클릭했거나 열이 숨겨져도 방향키 때 열 유지
  const lastActiveField = useRef<string | null>(null);
  const codeWarned = useRef(new Set<string>());
  const virt = useGridVirtual(scrollRef, view.displayRows.length);

// 설명 — 편집 모드 진입 시 해당 input 포커스
  useEffect(() => {
    const editCell = view.activeCell;
    if (!editCell?.isEditing) return;
    const tr = scrollRef.current?.querySelector<HTMLElement>(`tr[data-key="${editCell.rowKey}"]`);
    const input = tr?.querySelector<HTMLElement>(`[data-field="${editCell.field}"]`);
    input?.focus();
  }, [view.activeCell]);

// 설명 — 활성 행 변경 시 스크롤 영역으로 이동 (F173)
  // VIRTUAL_THRESHOLD+ 가상화: tr 미마운트 → scrollToIndex로 목록 끝(신규 추가 바닥)까지 점프
  useEffect(() => {
    if (!activeKey || view.activeCell?.isEditing) return;
    // displayRows(정렬·필터 후)에서 activeKey 인덱스 — addRow는 배열 끝에 append
    const idx = view.table.getRowModel().rows.findIndex((r) => r.id === activeKey);
    scrollGridToActiveRow({
      scrollRef,
      activeKey,
      rowIndex: idx,
      virt,
    });
  }, [activeKey, rows.length, view.activeCell?.isEditing, view.displayRows.length, virt.active]); // eslint-disable-line react-hooks/exhaustive-deps -- virt.virtualizer 안정

  const setEditCell = (cell: { rowKey: string; field: string } | null, isEditing = true) => {
    if (cell?.field) lastActiveField.current = cell.field;
    view.setActiveCell(cell ? { ...cell, isEditing } : null);
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 화살표는 행만(편집 진입 없음). Tab은 셀 이동이고 목적지 canEdit일 때만 편집
   *   2) wrap onKeyDown·잠금 셀 포커스 후 방향키/Tab에서 호출
   *   3) Tab이 그리드 밖이면 false — 호출측이 preventDefault를 하지 않아 네이티브 탭 아웃
   */
  // 설명 — activeCell 없으면 activeKey·lastActiveField로 복원. 성공 시 true
  const moveActive = (dRow: 0 | 1 | -1, dCol: 0 | 1 | -1, opts: { enterEditIfPossible?: boolean } = {}): boolean => {
    const tableRows = view.table.getRowModel().rows;
    const nRows = tableRows.length;
    const nCols = cols.length;
    if (nRows === 0 || nCols === 0) return false;

    const ac = view.activeCell;
    let curRowIdx = ac
      ? tableRows.findIndex((r) => r.id === ac.rowKey)
      : activeKey
        ? tableRows.findIndex((r) => r.id === activeKey)
        : -1;

    let curColIdx = ac
      ? cols.findIndex((c) => c.field === ac.field)
      : lastActiveField.current
        ? cols.findIndex((c) => c.field === lastActiveField.current)
        : 0;
    if (curColIdx < 0) curColIdx = 0;

    let targetRi: number;
    let targetCi: number;
    if (dCol === 0) {
      if (dRow === 0) return false;
      targetRi = nextRowIndex(nRows, curRowIdx, dRow);
      if (targetRi < 0) return false;
      targetCi = curColIdx;
    } else {
      if (curRowIdx < 0) curRowIdx = 0;
      const result = nextCell(curRowIdx, curColIdx, nRows, nCols, dCol);
      if (!result) return false;
      targetRi = result.ri;
      targetCi = result.ci;
    }

    const targetRow = tableRows[targetRi].original;
    const targetCol = cols[targetCi];
    const isNew = targetRow._rowState === "C";
    const overlayEdit = targetCol.type !== "checkbox" && targetCol.type !== "radio";
    const shouldEnterEdit = !!opts.enterEditIfPossible && overlayEdit && canEdit(targetRow, targetCol, isNew);

    props.onSetActive?.();
    if (!props.suppressActivate) props.onActivate?.(targetRow);
    setEditCell({ rowKey: targetRow._key, field: targetCol.field }, shouldEnterEdit);

    if (targetRi !== curRowIdx) {
      scrollGridToActiveRow({
        scrollRef,
        activeKey: targetRow._key,
        rowIndex: targetRi,
        virt,
      });
    }
    if (!shouldEnterEdit) wrapRef.current?.focus();
    return true;
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 편집 중·툴바/필터 타이핑은 가로채지 않음. 화살표=행, Tab=셀
   *   2) wrap tabIndex=0 에서 keydown
   *   3) Tab은 이동 성공일 때만 preventDefault — 그리드 끝은 네이티브 탈출
   */
  // 설명 — 비편집 키보드: Arrow 행이동, Tab 셀이동, Enter/F2 편집, Delete 비움
  const onGridKeyDown = (e: KeyboardEvent) => {
    if (view.activeCell?.isEditing) return;
    if (isTypingTarget(e)) return;

    if (e.key === "ArrowUp" || e.key === "ArrowDown") {
      e.preventDefault();
      moveActive(e.key === "ArrowUp" ? -1 : 1, 0);
      return;
    }
    if (e.key === "Tab") {
      const moved = moveActive(0, e.shiftKey ? -1 : 1, { enterEditIfPossible: true });
      if (moved) e.preventDefault();
      return;
    }
    if (e.key === "Enter" || e.key === "F2") {
      const ac = view.activeCell;
      if (!ac) return;
      e.preventDefault();
      const row = rows.find((r) => r._key === ac.rowKey);
      const c = cols.find((x) => x.field === ac.field);
      if (row && c && canEdit(row, c, row._rowState === "C") && c.type !== "checkbox" && c.type !== "radio") {
        setEditCell({ rowKey: ac.rowKey, field: ac.field }, true);
      }
    } else if (e.key === "Delete" || e.key === "Backspace") {
      const ac = view.activeCell;
      if (!ac) return;
      e.preventDefault();
      const row = rows.find((r) => r._key === ac.rowKey);
      const c = cols.find((x) => x.field === ac.field);
      if (row && c && canEdit(row, c, row._rowState === "C") && c.type !== "checkbox" && c.type !== "radio") {
        changeCell(row, c, c.type === "number" || c.type === "amount" ? null : "", row._rowState === "C");
      }
    }
  };

  const renderCellBtn = (row: ER, c: GridColumn<ER>, isNew: boolean) => {
    const btn = c.cellButton && (!c.cellButton.showOnNew || isNew) ? c.cellButton : null;
    if (!btn) return null;
    const pf = btn.popupField ?? c.field;
    const popOk = !access || access.canOpenPopup(row as EditableRow<GridRow>, pf).ok;
    return (
      <button type="button"
        // 추가 Tailwind/CSS 클래스
        // 기본 스타일 위에 병합(cn)
        className={cn("mes-cell-btn", c.required && "mes-cell-btn-required", !popOk && "mes-cell-btn-locked")}
        // 그리드 툴바/헤더에 표시할 제목
        // 비우면 제목 영역 생략 가능
        title={btn.title}
        // 비활성 여부
        // true이거나 loading이면 클릭 불가
        disabled={!popOk}
        // 클릭 핸들러
        // 비동기면 run/useAsyncAction으로 중복 클릭 방지 권장
        onClick={(e) => {
          e.stopPropagation();
          if (!popOk) {
            const reason = access?.canOpenPopup(row as EditableRow<GridRow>, pf).reason;
            if (reason) onLockedAttempt?.(reason, pf);
            return;
          }
          fireCellBtn(row, c, isNew, e);
        }}>
        {btn.icon
          ? <span className="touch-cell-btn-icon" aria-hidden>{btn.icon}</span>
          : <MoreHorizontal className="h-3 w-3" aria-hidden />}
      </button>
    );
  };

  const isEditing = (row: ER, c: GridColumn<ER>) =>
    c.type !== "checkbox" && c.type !== "radio"
    && view.activeCell?.rowKey === row._key
    && view.activeCell.field === c.field
    && view.activeCell.isEditing;

  const isFocused = (row: ER, c: GridColumn<ER>) =>
    view.activeCell?.rowKey === row._key && view.activeCell.field === c.field;

  const surfaceOf = (
    c: GridColumn<ER>,
    val: unknown,
    lockedCell: boolean,
    editableCell: boolean,
    rowActive: boolean,
  ) =>
    gridCellSurfaceClass({
      locked: lockedCell,
      required: c.required,
      value: val,
      editableOnActive: rowActive && editableCell && !lockedCell,
    });

  const tabNext = (row: ER, c: GridColumn<ER>, isNew: boolean, shift: boolean) => {
    const idx = cols.findIndex((x) => x.field === c.field);
    const dir = shift ? -1 : 1;
    const candidates = dir > 0 ? cols.slice(idx + 1) : [...cols.slice(0, idx)].reverse();
    const nextCol = candidates.find((nc) => canEdit(row, nc, isNew));
    if (nextCol) setEditCell({ rowKey: row._key, field: nextCol.field }, true);
    else setEditCell(null);
  };

  const renderCheckboxCell = (row: ER, c: GridColumn<ER>, isNew: boolean, editableCell: boolean, lockedCell: boolean, align: string) => {
    const val = row[c.field];
    const checked = isYnChecked(val);
    const rowActive = row._key === activeKey;
    // 열 너비 고정 + pin sticky
    const cellStyle = { ...colWidthStyle(view.widthOf(c)), ...pinLeftStyle(c.field) };
    return (
      <td
        // 행 _key 또는 busy 키
        // updateCell·run·포커스 식별에 사용
        key={c.field}
        // 추가 Tailwind/CSS 클래스
        // 기본 스타일 위에 병합(cn)
        className={cn(surfaceOf(c, val, lockedCell, editableCell, rowActive), isFocused(row, c) && "mes-cell-focus", pinLeftStyle(c.field) && "mes-col-pinned")}
        // 열 너비 고정 — table-layout:fixed와 함께 긴 글자 울렁임 방지
        style={cellStyle}
        // 클릭 핸들러
        // 비동기면 run/useAsyncAction으로 중복 클릭 방지 권장
        onClick={(e) => {
          e.stopPropagation();
          setEditCell({ rowKey: row._key, field: c.field }, false);
        }}
      >
        <div className={cn("mes-cell mes-cellwrap mes-cell-checkbox", `mes-align-${align}`)}>
          <input
            // radio=이력 팝업과 같은 원형. checkbox=사각. 행 높이 26px에 맞춤
            type={c.type === "radio" ? "radio" : "checkbox"}
            // 라디오는 열 단위 1건 — persistId+field 로 묶는다
            name={c.type === "radio" ? `${props.persistId ?? "mes-grid"}-${c.field}` : undefined}
            className={c.type === "radio"
              ? "h-3.5 w-3.5 border-slate-300"
              : "h-3.5 w-3.5 rounded border-slate-300 text-brand-700 focus:ring-brand-100"}
            // 체크·라디오 선택 여부
            checked={checked}
            disabled={!editableCell || lockedCell}
            onChange={(e) => {
              if (!rowActive) props.onActivate?.(row);
              if (c.type === "radio") {
                if (e.target.checked) changeCell(row, c, "Y", isNew);
                return;
              }
              changeCell(row, c, e.target.checked ? "Y" : "N", isNew);
            }}
          />
        </div>
      </td>
    );
  };

  const fill = height === "100%" || height === "auto";
  const leadCols = (showRowNum ? 1 : 0) + (selectable ? 1 : 0);
  const leadLeft = gridLeadLeftPx({ showRowNum, selectable: !!selectable });
  const selectLeft = showRowNum ? 32 : 0;

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
          const tRow = all[i];
          if (!tRow) return null;
          const row = tRow.original;
          const isNew = row._rowState === "C";
          const rowActive = row._key === activeKey;
          const rowCls = [
            rowActive ? "mes-row-active" : "",
            row._rowState === "U" ? "mes-row-dirty" : "",
            props.rowClassName?.(row) ?? "",
            (props.onActivate || props.onRowDoubleClick) ? "cursor-pointer" : "",
          ].join(" ");
          return (
            <tr key={row._key} data-key={row._key} className={rowCls}
              // 클릭 — 행 선택(onActivate). 화면 이동은 onRowDoubleClick
              onClick={() => {
                setEditCell(null);
                props.onSetActive?.();
                if (!props.suppressActivate) props.onActivate?.(row);
              }}
              // 더블클릭 — 오늘 할 일·최근 문서처럼 해당 화면으로 이동
              onDoubleClick={() => props.onRowDoubleClick?.(row)}
              title={props.onRowDoubleClick ? "해당 화면으로 이동합니다" : undefined}
            >
              {showRowNum && <GridRowNumCell index={i} active={rowActive} />}
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
                      checked={tRow.getIsSelected()}
                      // 값 변경 콜백
                      // 입력·체크·셀렉트 공통
                      onChange={tRow.getToggleSelectedHandler()}
                    />
                  </div>
                </td>
              )}
              {cols.map((c) => {
                const editableCell = canEdit(row, c, isNew);
                const lockedCell = !editableCell;
                const val = row[c.field];
                const align = colAlign(c);
                const cellBtn = renderCellBtn(row, c, isNew);
                const editing = editableCell && isEditing(row, c);
                const tdSurface = surfaceOf(c, val, lockedCell, editableCell, rowActive);
                const pin = pinLeftStyle(c.field);
                // 열 너비 고정(ADR-032) — th와 동일 width=min=max(pref→col.width→120), 데이터 길이와 무관 · pin sticky 병합
                const cellStyle = { ...colWidthStyle(view.widthOf(c)), ...pin };

                if (c.type === "checkbox" || c.type === "radio") {
                  return renderCheckboxCell(row, c, isNew, editableCell, lockedCell, align);
                }

                if (!editableCell) {
                  const kioskClick = kioskBtnVisible(c, isNew) && rowActive;
                  return (
                    <td
                      // 행 _key 또는 busy 키
                      // updateCell·run·포커스 식별에 사용
                      key={c.field}
                      // 추가 Tailwind/CSS 클래스
                      // 기본 스타일 위에 병합(cn)
                      className={cn(tdSurface, kioskClick && "cursor-pointer", isFocused(row, c) && "mes-cell-focus", pin && "mes-col-pinned")}
                      style={cellStyle}
                      // 클릭 핸들러
                      // stopPropagation — tr의 setEditCell(null)이 활성 셀을 지우지 않게
                      onClick={(e) => {
                        e.stopPropagation();
                        setEditCell({ rowKey: row._key, field: c.field }, false);
                        props.onSetActive?.();
                        if (!props.suppressActivate) props.onActivate?.(row);
                        wrapRef.current?.focus();
                        if (kioskClick) fireCellBtn(row, c, isNew, e);
                      }}
                      onDoubleClick={(e) => {
                        // 셀에서 막아 tr 과 두 번 타지 않게 한다. 모든 칸에서 더블클릭 이동
                        e.stopPropagation();
                        props.onRowDoubleClick?.(row);
                      }}
                    >
                      <div className={cn(`mes-cell mes-cellwrap mes-align-${align}`)}>
                        <GridCellDisplay row={row} col={c} text={cellText(row, c)} />{cellBtn}
                      </div>
                    </td>
                  );
                }

                if (!editing) {
                  return (
                    <td
                      // 행 _key 또는 busy 키
                      // updateCell·run·포커스 식별에 사용
                      key={c.field}
                      // 추가 Tailwind/CSS 클래스
                      // 기본 스타일 위에 병합(cn)
                      className={cn(tdSurface, isFocused(row, c) && "mes-cell-focus", pin && "mes-col-pinned")}
                      style={cellStyle}
                      // 클릭 핸들러
                      // 비동기면 run/useAsyncAction으로 중복 클릭 방지 권장
                      onClick={(e) => {
                        e.stopPropagation();
                        if (!rowActive) {
                          props.onSetActive?.();
                          if (!props.suppressActivate) props.onActivate?.(row);
                        }
                        if (touchKiosk && kioskBtnVisible(c, isNew)) {
                          fireCellBtn(row, c, isNew, e);
                          return;
                        }
                        if (lockedCell) {
                          const reason = access?.canEditCell(row as EditableRow<GridRow>, c.field).reason;
                          if (reason) onLockedAttempt?.(reason, c.field);
                          return;
                        }
                        setEditCell({ rowKey: row._key, field: c.field }, true);
                      }}
                      onDoubleClick={(e) => {
                        e.stopPropagation();
                        props.onRowDoubleClick?.(row);
                      }}
                    >
                      <div className={cn(`mes-cell mes-cellwrap mes-align-${align}`, "mes-cell-editable")}>
                        <GridCellDisplay row={row} col={c} text={cellText(row, c)} />{cellBtn}
                      </div>
                    </td>
                  );
                }

                if (c.type === "code") {
                  if (import.meta.env.DEV && !c.codeOptions?.length && !codeWarned.current.has(c.field)) {
                    codeWarned.current.add(c.field);
                    console.warn(`[MesEditableGrid] codeOptions missing: ${c.field}`);
                  }
                  return (
                    <td key={c.field} className={cn(tdSurface, pin && "mes-col-pinned")} style={cellStyle} onClick={(e) => e.stopPropagation()}>
                      {/* 편집 wrap — 셀 덮개식, 행 높이 고정 */}
                      <div className="mes-cellwrap mes-cellwrap-editing">
                        <select
                          data-field={c.field}
                          // 셀 전체를 덮는 편집 컨트롤 — global.css .mes-egrid-input
                          className="mes-egrid-input"
                          // 제어 컴포넌트 현재 값
                          // 부모 state와 양방향 동기화
                          value={String(val ?? "")}
                          onBlur={() => setEditCell(null)}
                          onKeyDown={(e) => {
                            if (e.key === "Escape") { e.preventDefault(); setEditCell(null); }
                            if (e.key === "Tab") {
                              e.preventDefault();
                              tabNext(row, c, isNew, e.shiftKey);
                            }
                          }}
                          // 값 변경 콜백
                          // 입력·체크·셀렉트 공통
                          onChange={(e) => changeCell(row, c, e.target.value, isNew)}
                        >
                          {/* 검색 「전체」와 달리 그리드 내부 Y/N·필수 콤보는 빈 option 없음 */}
                          {codeSelectHasEmptyOption(c) && <option value=""></option>}
                          {c.codeOptions?.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
                        </select>{cellBtn}
                      </div>
                    </td>
                  );
                }

                const errMsg = cellErr[`${row._key}|${c.field}`];
                return (
                  <td key={c.field} className={cn(tdSurface, pin && "mes-col-pinned")} style={cellStyle} onClick={(e) => e.stopPropagation()}>
                    {/* 편집 wrap — absolute input이 td(h-mes-row)를 덮어 울렁임 방지 */}
                    <div className="mes-cellwrap mes-cellwrap-editing">
                      <input
                        data-field={c.field}
                        // 셀 덮개식 편집 — mes-egrid-input + 정렬·검증 강조
                        className={cn(
                          "mes-egrid-input",
                          align === "right" && "mes-align-right",
                          align === "center" && "mes-align-center",
                          errMsg && "mes-cell-invalid",
                        )}
                        // 그리드 툴바/헤더에 표시할 제목
                        // 비우면 제목 영역 생략 가능
                        title={errMsg ?? undefined}
                        // HTML input type — date는 브라우저 달력, number는 숫자, 그 외 text
                        type={c.type === "number" ? "number" : c.type === "date" ? "date" : "text"}
                        inputMode={c.inputMode ?? (c.type === "number" || c.type === "amount" ? "decimal" : undefined)}
                        // 글자수 상한 — HTML maxlength (sanitize와 이중 방어)
                        maxLength={c.maxLength}
                        // 제어 컴포넌트 현재 값
                        // 부모 state와 양방향 동기화
                        value={val === null || val === undefined ? "" : String(val)}
                        onBlur={() => setEditCell(null)}
                        onKeyDown={(e) => {
                          if (e.key === "Escape") { e.preventDefault(); setEditCell(null); return; }
                          if (e.key === "Tab") {
                            e.preventDefault();
                            tabNext(row, c, isNew, e.shiftKey);
                            return;
                          }
                          if (e.key === "Enter") {
                            e.preventDefault();
                            setEditCell(null);
                            const idx = cols.findIndex((x) => x.field === c.field);
                            const nextCol = cols.slice(idx + 1).find((nc) => canEdit(row, nc, isNew));
                            if (nextCol) setEditCell({ rowKey: row._key, field: nextCol.field }, true);
                            else {
                              const tableRows = view.table.getRowModel().rows;
                              const ri = tableRows.findIndex((r) => r.id === row._key);
                              const next = tableRows[ri + 1];
                              if (next) {
                                const nc = cols.find((x) => canEdit(next.original, x, next.original._rowState === "C"));
                                if (nc) {
                                  props.onActivate?.(next.original);
                                  setEditCell({ rowKey: next.original._key, field: nc.field }, true);
                                }
                              }
                            }
                          }
                        }}
                        // 값 변경 콜백 — sanitize 후 maxLength 절단 → changeCell
                        onChange={(e) => {
                          let next = c.sanitize ? c.sanitize(e.target.value) : e.target.value;
                          // maxLength가 있을 때(= 장문 입력 방지) 초과분 절단
                          if (c.maxLength != null && next.length > c.maxLength) next = next.slice(0, c.maxLength);
                          changeCell(row, c,
                            c.type === "number" ? (next === "" ? null : Number(next)) : next, isNew);
                        }}
                      />{cellBtn}
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
      // wrap tabIndex=0 — 잠금 셀 클릭 후 방향키/Tab이 여기로 들어온다
      ref={wrapRef}
      // grid 행: 툴바 / 본문(1fr) / 푸터 — 총 n건이 마지막 행을 가리지 않음
      className={cn(
        "mes-grid-wrap",
        !showFooter && "mes-grid-no-footer",
        fill
          ? "mes-grid-embedded mes-grid-fill min-h-0"
          : "overflow-hidden rounded-xl border border-slate-200 shadow-sm",
      )}
      style={fill ? undefined : { height }}
      onKeyDown={onGridKeyDown}
      tabIndex={0}
    >
      <GridToolbar view={view} columns={columns}
        onExport={() => exportCsv(props.title ?? "grid", cols, view.displayRows, cellText)} />
      <div className="mes-grid-body">
        <div ref={scrollRef} className="mes-grid-scroll">
          {/* loading 중에도 table 유지 — skeleton 교체 시 깜박임 방지 */}
          <table className="mes-grid mes-egrid">
            <thead>
              <tr>
                {showRowNum && <th className="mes-rownum" />}
                {selectable && <GridSelectHeadCell view={view} leftOffset={selectLeft} />}
                {cols.map((c) => (
                  <GridHeadCell key={c.field} col={c} view={view} leadLeftPx={leadLeft} />
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
          <GridEmptyState
            // 오버레이 — 테이블 헤더는 남기고 본문만 빈 안내
            variant="overlay"
            // 필터행이 있으면 헤더+필터 높이만큼 아래로
            withFilter={view.showFilter}
            // 마스터 미선택 디테일은 noInfo, 그 외는 조회 없음
            title={props.emptyTitle}
            // 힌트가 없으면 조회 조건 안내
            hint={props.emptyHint ?? "조회 조건을 변경해 다시 조회하세요."}
          />
        )}
        <GridLoadingOverlay show={!!loading} />
      </div>
      {showFooter && (
        <GridFooter cols={cols} total={view.totalCount} shown={view.shownCount} aggregates={view.aggregates} />
      )}
    </div>
  );
}
