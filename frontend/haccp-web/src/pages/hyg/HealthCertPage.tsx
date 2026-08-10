/**
 * HealthCertPage — 건강진단관리기록부 MesEditableGrid 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 성명·검진일·만료·비고·첨부파일명·사용여부 인라인 편집 그리드를 제공한다
 *   2) 첨부는 저장 완료된 활성 행에만 업로드하며 fileNm은 읽기전용이다
 *   3) 삭제는 validate-delete → 확인 → delete → 재조회 순서와 [{ idx }] 키를 지킨다
 *
 * PIPELINE[HF125] 건강진단 화면
 * PIPELINE[HF29, HF39, HF56, HF96, HF124] 연관 모듈
 */
// 역할 — 상태·콜백·화면 진입 후 목록 조회·파일 입력 ref
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 화면별 조회·등록·수정·삭제 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 중복 클릭 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — 그리드 잠금 훅
import { useGridAccess } from "@/hooks/useGridAccess";
// 역할 — 편집 행 상태
import { useEditableRows } from "@/hooks/useEditableRows";
// 역할 — 편집 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — mes-web형 행추가·저장·삭제 버튼 묶음
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
// 역할 — SoPage형 그리드 패널 헤더(보이는 그리드명)
import { gridHeadClass } from "@/components/layout/pageClasses";
// 역할 — 표준 버튼·입력
import { MesButton } from "@/components/ui/MesButton";
import { Input } from "@/components/ui/Input";
// 역할 — 확인창·성공 및 오류 토스트
import { mesConfirm, mesToast } from "@/shell/dialog";
// 역할 — 서버 예외를 업무 문구로 변환
import { mesError } from "@/shell/errors";
// 역할 — 공통 저장·삭제·필수 안내 문구
import { MES } from "@/shell/messages";
// 역할 — 셸 상단·단축키 CRUD 명령 등록
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — 저장 가드
import { guardSaveWithKey } from "@/shell/gridRules";
// 역할 — 선택행 우선 삭제 대상
import { resolveRowsForDelete } from "@/shell/resolveDelete";
// 역할 — 그리드·편집 행 타입
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
// 역할 — 건강진단 API
import {
  deleteHealthCertRows,
  listHealthCertRows,
  saveHealthCertRows,
  uploadHealthCertFile,
  validateDeleteHealthCertRows,
  type HealthCertRow,
} from "@/api/healthCertApi";

const SCREEN_CODE = "health-cert-record";

const YES_NO_OPTIONS = [
  { value: "Y", label: "사용" },
  { value: "N", label: "미사용" },
] as const;

type Row = HealthCertRow & { idx?: number | null; _key?: string };

/** 신규 행 — 사용여부는 사용으로 시작 */
function createEmptyRow(): Row {
  return {
    personNm: "",
    examDt: "",
    expireDt: "",
    remark: "",
    fileNm: "",
    filePath: "",
    useYn: "Y",
  };
}

/** 저장 payload — 빈 문자열은 null, 수정행은 idx를 포함한다. */
function normalizeRow(row: Row): HealthCertRow {
  const next: HealthCertRow = {
    personNm: String(row.personNm ?? "").trim() || null,
    examDt: String(row.examDt ?? "").trim() || null,
    expireDt: String(row.expireDt ?? "").trim() || null,
    remark: String(row.remark ?? "").trim() || null,
    useYn: String(row.useYn ?? "Y").trim() || "Y",
  };
  // 수정 행일 때(= 대리키 있음) SP가 같은 회사 행을 UPDATE하도록 idx를 넣는다
  if (row.idx != null && Number(row.idx) > 0) {
    next.idx = Number(row.idx);
  }
  // 화면에서 이미 올린 첨부가 있을 때(= 경로 유지) 저장 시 덮어쓰지 않도록 전달
  if (row.filePath) next.filePath = row.filePath;
  if (row.fileNm) next.fileNm = row.fileNm;
  return next;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 건강진단 인라인 편집 그리드와 첨부 업로드를 렌더링한다
 *   2) screenRegistry의 health-cert-record에서 마운트한다
 *   3) API 오류·권한 부족은 업무 문구로만 안내한다
 */
export default function HealthCertPage() {
  const canWrite = useAuthStore((state) => state.can(SCREEN_CODE, "write"));
  const canModify = useAuthStore((state) => state.can(SCREEN_CODE, "modify"));
  const canDelete = useAuthStore((state) => state.can(SCREEN_CODE, "delete"));
  const asyncAct = useAsyncAction();
  const [personNm, setPersonNm] = useState("");
  const [useYn, setUseYn] = useState("");
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  // 숨은 파일 입력 — 첨부 버튼이 클릭을 위임한다
  const fileInputRef = useRef<HTMLInputElement>(null);
  const clearSel = () => {
    setSelKeys([]);
    setSelReset((n) => n + 1);
  };

  // 행 식별은 대리키 idx
  const g = useEditableRows<Row>("idx");
  const grid = useGridAccess(
    { newOnly: [] },
    {
      scrnCd: SCREEN_CODE,
      gridRole: "single",
      readOnly: !canModify && !canWrite,
      extra: { canWrite, canModify, canDelete },
    },
  );

  const editable = canWrite || canModify;
  const columns = useMemo<GridColumn<Row>[]>(
    () => [
      {
        // 성명 — 필수
        field: "personNm",
        header: "성명",
        width: 120,
        required: true,
        editable,
      },
      {
        // 검진일 YYYYMMDD
        field: "examDt",
        header: "검진일",
        width: 110,
        type: "date",
        required: true,
        editable,
      },
      {
        // 갱신만료일 YYYYMMDD
        field: "expireDt",
        header: "만료일",
        width: 110,
        type: "date",
        editable,
      },
      {
        // 비고
        field: "remark",
        header: "비고",
        width: 200,
        editable,
      },
      {
        // 첨부 파일명 — 업로드 API만 갱신, 셀 편집 금지
        field: "fileNm",
        header: "첨부파일",
        width: 160,
        editable: false,
      },
      {
        // 사용여부
        field: "useYn",
        header: "사용여부",
        width: 90,
        type: "code",
        codeOptions: [...YES_NO_OPTIONS],
        codeMap: Object.fromEntries(YES_NO_OPTIONS.map((opt) => [opt.value, opt.label])),
        editable,
      },
    ],
    [editable],
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-07
   * 코멘트:
   *   1) 검색 조건으로 건강진단 목록을 다시 읽는다
   *   2) 최초 진입·조회·저장·삭제·첨부 성공 뒤에 호출한다
   *   3) 실패하면 기존 행을 유지하고 오류 토스트만 표시한다
   */
  const loadRows = useCallback(async () => {
    try {
      const rows = await listHealthCertRows({ personNm, useYn });
      g.load(rows);
      setActiveKey(null);
      clearSel();
    } catch (error) {
      mesToast(mesError(error), "error");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- g.load 안정 참조
  }, [personNm, useYn]);

  useEffect(() => {
    void loadRows();
  }, [loadRows]);

  const handleAdd = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    setActiveKey(g.addRow(createEmptyRow()));
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-07
   * 코멘트:
   *   1) 변경행만 save API로 일괄 저장하고 목록을 다시 읽는다
   *   2) GridCrudButtons·셸 Ctrl+S·저장 버튼에서 호출한다
   *   3) 권한·가드·확인 실패는 토스트만, 성공 시 재조회한다
   */
  const handleSave = async () => {
    if (!canWrite && !canModify) {
      mesToast("수정 권한이 없습니다.", "warn");
      return;
    }
    const dirty = g.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    const guard = guardSaveWithKey(grid.rules, grid.ctx, dirty, columns);
    if (guard) {
      mesToast(guard.message, "warn");
      if (guard.rowKey) setActiveKey(guard.rowKey);
      return;
    }
    for (const row of dirty) {
      if (!String(row.personNm ?? "").trim()) {
        mesToast(MES.required("성명"), "warn");
        setActiveKey(row._key);
        return;
      }
      if (!String(row.examDt ?? "").trim()) {
        mesToast(MES.required("검진일"), "warn");
        setActiveKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      await saveHealthCertRows(dirty.map((row) => normalizeRow(row)));
      mesToast(MES.saveDone, "success");
      await loadRows();
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-07
   * 코멘트:
   *   1) 선택행 우선 삭제 — 신규는 로컬 제거, 저장행은 validate-delete·확인·delete
   *   2) GridCrudButtons·셸 삭제 단축키에서 호출한다
   *   3) 권한 실패는 업무 토스트로만 안내한다
   */
  const handleDelete = async () => {
    if (!canDelete) {
      mesToast("삭제 권한이 없습니다.", "warn");
      return;
    }
    const targets = resolveRowsForDelete(g.rows, activeKey, setActiveKey, selKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");

    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    let lastFocus = activeKey;
    for (const row of newRows) {
      const { focusKey } = g.removeNewRow(row._key);
      lastFocus = focusKey;
    }
    if (newRows.length > 0) {
      setActiveKey(lastFocus);
      clearSel();
    }
    if (persisted.length === 0) return;

    // 삭제 계약은 [{ idx }]
    const keys = persisted
      .map((row) => Number(row.idx))
      .filter((idx) => Number.isFinite(idx) && idx > 0)
      .map((idx) => ({ idx }));
    if (keys.length === 0) return mesToast("삭제할 행의 키가 올바르지 않습니다.", "warn");
    const label = String(persisted[0].personNm ?? "");
    try {
      await validateDeleteHealthCertRows(keys);
      if (!(await mesConfirm(MES.deleteConfirm(label)))) return;
      await deleteHealthCertRows(keys);
      clearSel();
      mesToast(MES.deleteDone, "success");
      await loadRows();
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  };

  /** 활성 저장 행 — 첨부 업로드 대상 */
  const activeRow = g.rows.find((row) => row._key === activeKey) ?? null;
  const canUpload =
    editable &&
    activeRow != null &&
    activeRow._rowState !== "C" &&
    Number(activeRow.idx) > 0;

  /**
   * 개발자: 박승우
   * 일자: 2026-08-07
   * 코멘트:
   *   1) 숨은 file input으로 선택한 파일을 활성 행에 업로드한다
   *   2) 첨부 버튼·파일 선택 변경에서 호출한다
   *   3) 성공 시 목록을 다시 읽어 fileNm을 반영한다
   */
  const handleFileSelected = async (file: File | null) => {
    if (!file) return;
    if (!canUpload || activeRow?.idx == null) {
      mesToast("저장한 행을 선택한 뒤 첨부하세요.", "warn");
      return;
    }
    try {
      await asyncAct.run(async () => {
        await uploadHealthCertFile(Number(activeRow.idx), file);
        mesToast("첨부 파일을 등록했습니다.", "success");
        await loadRows();
      }, "upload");
    } catch (error) {
      mesToast(mesError(error), "error");
    } finally {
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  };

  // mes-web CommonCode와 동일 — 셸 툴바·단축키에 조회/추가/저장/삭제 등록
  usePageCommands({
    search: () => {
      void asyncAct.run(loadRows, "search");
    },
    add: handleAdd,
    save: () => {
      void asyncAct.run(handleSave, "save");
    },
    del: () => {
      void asyncAct.run(handleDelete, "del");
    },
  });

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 p-3">
      <section className="flex flex-wrap items-end gap-2 rounded border border-slate-200 bg-white p-3">
        <label className="flex flex-col gap-1 text-xs text-slate-600">
          성명
          <Input
            // 성명 부분검색 서버 조회 조건
            value={personNm}
            // 조회 전까지 입력값만 보관한다
            onChange={(event) => setPersonNm(event.target.value)}
            placeholder="성명"
            className="w-40"
          />
        </label>
        <label className="flex flex-col gap-1 text-xs text-slate-600">
          사용여부
          <select
            // 전체·사용·미사용 행을 서버 목록 조건으로 전달한다
            value={useYn}
            // 선택한 사용여부 조건을 상태에 보관한다
            onChange={(event) => setUseYn(event.target.value)}
            className="h-mes-input rounded border border-slate-300 bg-white px-2 text-sm"
          >
            <option value="">전체</option>
            <option value="Y">사용</option>
            <option value="N">미사용</option>
          </select>
        </label>
        <MesButton
          // 현재 검색 조건으로 목록을 다시 읽는다
          variant="search"
          // 조회 처리 중 중복 요청을 막는다
          disabled={asyncAct.isBusy("search")}
          // 조회는 독립 key로 실행한다
          onClick={() => void asyncAct.run(loadRows, "search")}
        >
          조회
        </MesButton>
        <input
          // 숨은 파일 선택 — 첨부 버튼이 click을 위임한다
          ref={fileInputRef}
          type="file"
          className="hidden"
          // 파일 선택 시 활성 행에 업로드한다
          onChange={(event) => void handleFileSelected(event.target.files?.[0] ?? null)}
        />
      </section>

      <section className="flex min-h-0 flex-1 flex-col overflow-hidden rounded border border-slate-200 bg-white p-2">
        <div className={gridHeadClass}>
          {/* 보이는 그리드명 — title prop과 동일 */}
          <b>건강진단관리기록부</b>
          <div className="flex flex-wrap items-center gap-2">
            <MesButton
              // 활성 저장 행에 보건증 등 첨부 파일을 올린다
              variant="secondary"
              // 신규·미선택·권한 없을 때 비활성
              disabled={!canUpload || asyncAct.isBusy("upload")}
              // 숨은 file input을 연다
              onClick={() => fileInputRef.current?.click()}
            >
              첨부업로드
            </MesButton>
            <GridCrudButtons
              // useAsyncAction.run — save/del busy 키 래핑
              run={asyncAct.run}
              // 신규 건강진단 행 추가 — 등록 권한 있을 때만
              onAdd={canWrite ? handleAdd : undefined}
              // 변경행 일괄 저장
              onSave={canWrite || canModify ? handleSave : undefined}
              // validate-delete 후 삭제
              onDel={canDelete ? handleDelete : undefined}
              // 버튼별 busy — 중복 클릭 방지
              busy={{
                save: asyncAct.isBusy("save"),
                del: asyncAct.isBusy("del"),
              }}
              // mes-web과 동일 라벨 — 신규 대신 행추가
              addLabel="행추가"
            />
          </div>
        </div>
        <MesEditableGrid
          // 열 설정 저장 키 — 건강진단 화면 전용
          persistId="hyg-health-cert-record"
          // 조회·편집 행 목록
          rows={g.rows as EditableRow<Row>[]}
          // 성명·검진일·만료·비고·첨부·사용여부 컬럼
          columns={columns}
          // 등록·수정 권한이 있을 때만 편집
          editable={editable}
          // 그리드 제목 — 패널 헤더와 동일
          title="건강진단관리기록부"
          // 패널 높이를 채운다
          height="100%"
          // 조회·저장·삭제·첨부 busy 오버레이
          loading={
            asyncAct.isBusy("search") ||
            asyncAct.isBusy("save") ||
            asyncAct.isBusy("del") ||
            asyncAct.isBusy("upload")
          }
          // 활성 행 키
          activeKey={activeKey}
          // 행 활성화 — 첨부 업로드 대상
          onActivate={(row) => setActiveKey(row._key)}
          // 셀 변경 추적
          onCellChange={(key, field, value) => g.updateCell(key, field as keyof Row, value)}
          // newOnly·읽기전용 접근 판정
          access={grid.access}
          // 잠금 셀 안내
          onLockedAttempt={grid.onLockedAttempt}
          // 다중 선택 삭제
          selectable
          onSelectionChange={(rows) => setSelKeys(rows.map((row) => row._key))}
          selectionResetKey={selReset}
          showRowNum
        />
      </section>
    </div>
  );
}
