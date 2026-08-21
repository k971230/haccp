/**
 * CorrectiveActionManagementPage — 이탈·개선조치 MesEditableGrid 관리.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 공통 DocFormSearchToolbar로 기간·문서번호·작성자 조건을 맞춘다
 *   2) 목록은 selectable 그리드·우측 폼으로 저장·삭제한다
 *   3) 완료 상태는 서버 SP가 삭제를 차단한다
 *
 * PIPELINE[HF89] 개선조치 관리 화면
 * PIPELINE[HF87, HF52, HF90, HB95, HF120] 연관 모듈
 */
// 역할 — React 상태·메모
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — API
import {
  deleteCorrectiveActions,
  listCorrectiveActions,
  saveCorrectiveAction,
  validateDeleteCorrectiveActions,
  type WorkflowRow,
} from "@/api/taskWorkflowApi";
// 역할 — mes-web형 그리드·CRUD
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { MesButton } from "@/components/ui/MesButton";
import { Input } from "@/components/ui/Input";
// 역할 — SoPage형 그리드 패널 헤더(보이는 그리드명)
import { gridHeadClass } from "@/components/layout/pageClasses";
// 역할 — 공통 조회 헤더
import {
  DocFormSearchToolbar,
  defaultDocFormSearch,
  type DocFormSearchValues,
} from "@/components/form/DocFormSearchToolbar";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useEditableRows } from "@/hooks/useEditableRows";
import { usePageCommands } from "@/shell/pageCommands";
import { mesConfirm, mesConfirmDanger, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import type { EditableRow } from "@/types/editable";
import { fromInputDate, toInputDate, todayYmd } from "@/lib/docDateTime";
import {
  FIELD_LABELS,
  PERSIST_ID,
  STATUS_OPTIONS,
  buildColumns,
  type Row,
} from "./CorrectiveActionManagementRule";

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 개선조치 목록·상세를 조회·저장·삭제한다
 *   2) corrective-action-management 메뉴에서 마운트한다
 *   3) 권한·검증 실패는 업무 토스트로만 안내한다
 */
export default function CorrectiveActionManagementPage() {
  const asyncAct = useAsyncAction();
  const g = useEditableRows<Row>("idx");
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [editor, setEditor] = useState<WorkflowRow | null>(null);
  const [search, setSearch] = useState<DocFormSearchValues>(() => defaultDocFormSearch());
  const searchRef = useRef(search);
  searchRef.current = search;
  const [status, setStatus] = useState("");
  const statusRef = useRef(status);
  statusRef.current = status;
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);

  const columns = useMemo(() => buildColumns(), []);

  const activeRow = useMemo(
    () => g.rows.find((row) => row._key === activeKey) ?? null,
    [activeKey, g.rows],
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 기간·상태·문서번호·작성자 조건으로 목록을 다시 읽는다
   *   2) 조회·저장·삭제 성공 뒤에 호출한다
   *   3) 문서번호·작성자는 클라이언트 부분필터 (SP는 기간·상태)
   */
  const load = useCallback(async () => {
    const q = searchRef.current;
    try {
      const rows = await listCorrectiveActions({
        fromDt: q.fromDt,
        toDt: q.toDt,
        status: statusRef.current,
      });
      const docNo = q.docNo.trim().toLowerCase();
      const writer = q.writer.trim().toLowerCase();
      const filtered = rows.filter((row) => {
        const srcNo = String(row.srcDocNo ?? "").toLowerCase();
        const caNo = String(row.caNo ?? "").toLowerCase();
        const actionUser = String(row.actionUserId ?? "").toLowerCase();
        if (docNo && !srcNo.includes(docNo) && !caNo.includes(docNo)) return false;
        if (writer && !actionUser.includes(writer)) return false;
        return true;
      });
      g.load(filtered);
      setActiveKey(null);
      setEditor(null);
      setSelKeys([]);
      setSelReset((n) => n + 1);
    } catch (error) {
      mesError(error);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- g.load 안정 참조
  }, []);

  useEffect(() => { void load(); }, [load]);

  useEffect(() => {
    if (!activeRow) return;
    setEditor({ ...activeRow });
  }, [activeRow]);

  const handleAdd = () => {
    const key = g.addRow({
      occurDt: todayYmd(),
      status: "OPEN",
      deviationDesc: "",
      actionDesc: "",
    });
    setActiveKey(key);
    setEditor({ occurDt: todayYmd(), status: "OPEN" });
  };

  const handleSave = async () => {
    if (!editor) return mesToast("저장할 개선조치를 입력하세요.", "warn");
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      await saveCorrectiveAction(editor);
      mesToast(MES.saveDone, "success");
      await load();
    } catch (error) {
      mesError(error);
    }
  };

  const handleDelete = async () => {
    const picked = g.rows.filter((row) => selKeys.includes(row._key));
    const target = picked.length > 0 ? picked : (activeRow ? [activeRow] : []);
    if (target.length === 0 && !editor?.idx) return mesToast(MES.selectRow, "warn");

    const drafts = target.filter((row) => row._rowState === "C");
    for (const row of drafts) {
      g.removeNewRow(row._key);
    }
    const saved = target.filter((row) => row._rowState !== "C" && Number(row.idx) > 0);
    const soloIdx = Number(editor?.idx ?? 0);
    if (saved.length === 0 && drafts.length === 0) {
      if (!Number.isFinite(soloIdx) || soloIdx <= 0) return mesToast("삭제할 개선조치를 선택하세요.", "warn");
      saved.push({ idx: soloIdx, _key: String(soloIdx) } as EditableRow<Row>);
    }
    if (saved.length === 0) {
      setActiveKey(null);
      setEditor(null);
      return;
    }
    try {
      const keys = saved.map((row) => ({ idx: Number(row.idx) }));
      await validateDeleteCorrectiveActions(keys);
      if (!(await mesConfirmDanger(`선택한 개선조치 ${keys.length}건을 삭제하시겠습니까?`))) return;
      await deleteCorrectiveActions(keys);
      mesToast(MES.deleteDone, "success");
      await load();
    } catch (error) {
      mesError(error);
    }
  };

  usePageCommands({
    search: () => { void asyncAct.run(load, "search"); },
    add: handleAdd,
    save: () => { void asyncAct.run(handleSave, "save"); },
    del: () => { void asyncAct.run(handleDelete, "del"); },
  });

  const patch = (key: string, value: string) =>
    setEditor((current) => ({ ...(current ?? {}), [key]: value }));

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 p-3">
      <DocFormSearchToolbar
        // 기간·문서번호·작성자
        values={search}
        // 조건 부분 갱신
        onChange={(patch) => setSearch((prev) => ({ ...prev, ...patch }))}
        // 목록 재조회
        onSearch={() => void asyncAct.run(load, "search")}
        // 신규 행
        onAdd={handleAdd}
        // 폼 단건 저장
        onSave={() => void asyncAct.run(handleSave, "save")}
        // 체크/선택 삭제
        onDelete={() => void asyncAct.run(handleDelete, "del")}
        // 삭제 가능 — 선택 또는 활성
        canDelete={selKeys.length > 0 || !!activeKey || !!editor?.idx}
        // 조회 busy
        searchBusy={asyncAct.isBusy("search")}
        // 액션 busy
        actionBusy={asyncAct.isBusy()}
        // 상태 필터
        extraFilters={(
          <label className="flex flex-col gap-1 text-xs text-slate-600">
            상태
            <select
              className="h-mes-input rounded-mes border border-slate-300 bg-white px-2 text-sm"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
            >
              <option value="">전체</option>
              {STATUS_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </select>
          </label>
        )}
      />

      <div className="grid min-h-0 flex-1 grid-cols-1 gap-3 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <section className="flex min-h-0 flex-col overflow-hidden rounded border border-slate-200 bg-white p-2">
          <div className={gridHeadClass}>
            {/* 보이는 그리드명 — title prop과 동일 */}
            <b>개선조치 목록</b>
          </div>
          <MesEditableGrid
            // 열 설정 저장 키
            persistId={PERSIST_ID}
            // 개선조치 목록
            rows={g.rows as EditableRow<Row>[]}
            // 번호·발생일·원문서·이탈·상태
            columns={columns}
            // 목록은 선택용 — 상세는 우측 폼
            editable={false}
            // 그리드 제목
            title="개선조치 목록"
            // 패널 높이 채움
            height="100%"
            loading={asyncAct.isBusy("search") || asyncAct.isBusy("save") || asyncAct.isBusy("del")}
            // 활성 행
            activeKey={activeKey}
            onActivate={(row) => setActiveKey(row._key)}
            // 다중 선택 체크박스
            selectable
            onSelectionChange={(picked) => setSelKeys(picked.map((row) => row._key))}
            selectionResetKey={selReset}
            showRowNum
          />
        </section>

        <section className="flex min-h-0 flex-col overflow-hidden rounded border border-slate-200 bg-white p-1">
          <div className={gridHeadClass}>
            {/* 보이는 패널명 — 목록 헤더와 동일 밀도 */}
            <b>개선조치 입력</b>
          </div>
          <div className="min-h-0 flex-1 overflow-auto p-3">
          {FIELD_LABELS.map((field) => (
            <label key={field.key} className="mb-2 flex flex-col gap-1 text-xs text-slate-600">
              {field.label}
              <Input
                type={field.type === "date" ? "date" : "text"}
                value={
                  field.type === "date"
                    ? toInputDate(String(editor?.[field.key] ?? ""))
                    : String(editor?.[field.key] ?? "")
                }
                onChange={(event) =>
                  patch(
                    field.key,
                    field.type === "date" ? fromInputDate(event.target.value) : event.target.value,
                  )
                }
              />
            </label>
          ))}
          <label className="mb-2 flex flex-col gap-1 text-xs text-slate-600">
            상태
            <select
              className="h-mes-input rounded border border-slate-300 px-2 text-sm"
              value={String(editor?.status ?? "OPEN")}
              onChange={(event) => patch("status", event.target.value)}
            >
              {STATUS_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </select>
          </label>
          <div className="mt-3 flex gap-2">
            <MesButton variant="save" disabled={asyncAct.isBusy("save")} onClick={() => void asyncAct.run(handleSave, "save")}>
              저장
            </MesButton>
          </div>
          </div>
        </section>
      </div>
    </div>
  );
}
