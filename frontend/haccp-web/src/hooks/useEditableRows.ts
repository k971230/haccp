/**
 * useEditableRows — 편집 그리드 행 상태 훅.
 *
 * [BIZ_CRUD_1: Dirty — _rowState C/U, getSaveRows / hasChanges]
 * 일자: 2026-07-09
 * 개발자: 박승우
 * 구현내용: 변경행만 배치 저장. 삭제는 별도 DELETE. 상세 docs/06_업무_CRUD.md.
 *
 * WinForms GridFunc.GetModifiedRows / SaveRows 대응.
 * masterDetailFocus.runMasterDelete / runDetailDelete 와 함께 사용.
 *
 * ## rowsRef (연속 삭제 핵심)
 * React 18 은 setRows(updater) 의 updater 를 즉시 실행하지 않을 수 있다.
 * 예전 removeNewRow 가 updater 내부에서 focusKey 를 채우면 { null, null } 이 반환되어
 * 연속 삭제 시 포커스가 사라지고 "선택하세요" 또는 엉뚱한 행으로 떨어졌다.
 *
 * setRows 래퍼가 rowsRef.current 를 **동기 갱신**하고, removeNewRow 는 ref 기준으로
 * 바로 윗행 focusKey/focusRow 를 계산한 뒤 state 를 한 번에 반영한다.
 *
 * ## 주요 API
 * - loadReturn: 재조회 후 EditableRow[] 동기 반환 → afterMasterLoad 포커스 계산용
 * - reloadKeepSelection: 저장 후 재조회 — _key·업무키로 선택 유지. 없으면 첫 행으로 떨어지지 않는다
 * - removeNewRow: 신규(C) 행 로컬 제거 + 윗행 { focusKey, focusRow } 반환
 * - getSaveRows: _rowState 있는 행만 (저장 API payload)
 *
 * PIPELINE[F41] 커스텀 훅
 */
// 역할 — React 상태·ref·콜백 훅
import { useCallback, useRef, useState } from "react";
// 역할 — 편집 행 타입(_key, _rowState, _original)
import type { EditableRow } from "@/types/editable";
// 역할 — 셸 beforeunload용 dirty 자동 등록
import { useRegisterPageDirty } from "@/shell/pageDirtyRegistry";

// 설명 — 신규행 _key 생성용 시퀀스
let _seq = 0;
// 설명 — 고유 신규행 키 생성 — Date.now + 시퀀스
const uid = () => `__new_${Date.now()}_${_seq++}`;

/** removeNewRow 반환 — focusRow 는 제거 **후** 목록 기준 객체 */
export type RemoveNewRowResult<T> = {
  focusKey: string | null;
  focusRow: EditableRow<T> | null;
};

/** reloadKeepSelection 반환 — 저장 후 같은 행을 다시 고르기 위한 키·행 */
export type ReloadKeepResult<T> = {
  key: string | null;
  row: EditableRow<T> | null;
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 재조회 목록에서 저장 전 선택행을 찾는다 — _key 또는 업무키
 *   2) 저장 성공 후 reloadKeepSelection / 마스터-디테일 우측 재로드에서 호출한다
 *   3) 키가 없거나 목록에 없으면 null — 첫 행으로 떨어지지 않는다
 */
export function pickKeptRow<T extends Record<string, unknown>>(
  mapped: EditableRow<T>[],
  rowKey: keyof T,
  prevKey: string | null | undefined,
): EditableRow<T> | null {
  const want = prevKey != null ? String(prevKey).trim() : "";
  if (!want) return null;
  return mapped.find((r) => r._key === want || String(r[rowKey] ?? "") === want) ?? null;
}

// 설명 — 서버 조회 결과 → EditableRow[] 매핑(_key·_original 부여)
// 업무키/대리키가 비어 있으면(= undefined·null·'') 고유 uid로 대체해 React duplicate key를 막는다
function mapServerRows<T extends Record<string, unknown>>(server: T[], rowKey: keyof T): EditableRow<T>[] {
  return (server ?? []).map((r) => {
    const snap = { ...r };
    const raw = r[rowKey];
    const key = raw != null && String(raw).trim() !== "" ? String(raw) : uid();
    return { ...r, _key: key, _original: snap } as EditableRow<T>;
  });
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 편집 그리드 행 상태 훅 — load/add/update/remove/save
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 편집 그리드 행 상태 훅 — load/add/update/remove/save
export function useEditableRows<T extends Record<string, any>>(rowKey: keyof T) {
  const [rows, setRowsState] = useState<EditableRow<T>[]>([]);
  /** 렌더와 무관하게 항상 최신 rows — removeNewRow 동기 계산용 */
  const rowsRef = useRef<EditableRow<T>[]>([]);

  /**
   * setRowsState 와 rowsRef 를 동시 갱신.
   * updater 형태일 때 rowsRef.current 를 prev 로 사용 (React 큐 지연 회피).
   */
  const setRows = useCallback(
    (updater: EditableRow<T>[] | ((prev: EditableRow<T>[]) => EditableRow<T>[])) => {
      const next = typeof updater === "function"
        ? (updater as (p: EditableRow<T>[]) => EditableRow<T>[])(rowsRef.current)
        : updater;
      rowsRef.current = next;
      setRowsState(next);
    },
    [],
  );

// 설명 — 서버 데이터로 전체 교체
  const load = useCallback(
    (server: T[]) => {
      setRows(mapServerRows(server, rowKey));
    },
    [rowKey, setRows],
  );

  /** load + mapped 배열 동기 반환 (afterMasterLoad / afterDetailLoad 에 전달) */
  const loadReturn = useCallback(
    (server: T[]): EditableRow<T>[] => {
      const mapped = mapServerRows(server, rowKey);
      setRows(mapped);
      return mapped;
    },
    [rowKey, setRows],
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-19
   * 코멘트:
   *   1) 재조회 후 저장 전 선택(_key·업무키)을 유지한다
   *   2) 그리드 저장 성공 뒤에 호출한다 — 조회(검색)는 load 로 포커스를 비운다
   *   3) 목록에 없으면 key/row 모두 null — 첫 행 자동 선택은 하지 않는다
   */
  const reloadKeepSelection = useCallback(
    async (fetchFn: () => Promise<T[]>, prevKey: string | null | undefined): Promise<ReloadKeepResult<T>> => {
      const data = await fetchFn();
      const mapped = mapServerRows(data, rowKey);
      setRows(mapped);
      const row = pickKeptRow(mapped, rowKey, prevKey);
      return { key: row?._key ?? null, row };
    },
    [rowKey, setRows],
  );

  /** _rowState "C" 부여, uid _key 반환 */
// 설명 — 신규행 추가 — _rowState "C" 부여
  const addRow = useCallback((defaults: Partial<T>) => {
    const key = uid();
    setRows((prev) => [...prev, { ...(defaults as T), _key: key, _rowState: "C" }]);
    return key;
  }, [setRows]);

// 설명 — 셀 값 변경 — C 유지, 기존행은 U 표시
  const updateCell = useCallback((key: string, field: keyof T, value: unknown) => {
    setRows((prev) =>
      prev.map((r) =>
        r._key === key
          ? { ...r, [field]: value, _rowState: r._rowState === "C" ? "C" : "U" }
          : r,
      ),
    );
  }, [setRows]);

  /**
   * 신규(C) 행만 로컬에서 제거.
   *
   * 포커스 규칙:
   * - 삭제 위치가 맨 위(idx===0) → 남은 목록의 첫 행
   * - 그 외 → 바로 윗행 (idx - 1)
   * - 목록 비면 focusKey/focusRow 모두 null
   */
  const removeNewRow = useCallback((key: string): RemoveNewRowResult<T> => {
    const prev = rowsRef.current;
    const idx = prev.findIndex((r) => r._key === key);
    if (idx < 0) return { focusKey: null, focusRow: null };
    const next = prev.filter((r) => r._key !== key);
    let focusKey: string | null = null;
    let focusRow: EditableRow<T> | null = null;
    if (next.length > 0) {
      const fi = idx > 0 ? idx - 1 : 0;
      focusRow = next[fi];
      focusKey = focusRow._key;
    }
    setRows(next);
    return { focusKey, focusRow };
  }, [setRows]);

// 설명 — 저장 대상 행만 추출(_rowState 있는 행)
  const getSaveRows = useCallback(() => rows.filter((r) => r._rowState), [rows]);

// 설명 — 미저장 변경 존재 여부
  const hasChanges = useCallback(() => rows.some((r) => r._rowState), [rows]);

  // keep-alive 탭 F5/닫기 시 미저장 경고 — MesShell beforeunload가 집계
  useRegisterPageDirty(hasChanges);

  return {
    rows, setRows, rowsRef,
    load,
    loadReturn,
    reloadKeepSelection,
    addRow,
    updateCell,
    removeNewRow,
    getSaveRows,
    hasChanges,
  };
}
