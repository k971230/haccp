/**
 * ScheduleCycleManagementPage — 작성 문서 관리 (SoPage형 상·하).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 상단 작성가능문서(양식코드·명·타입·시스템·사용) + 검색, 하단 작성주기
 *   2) 공통코드 sys-yn/tmpl-ty/use-yn, 주기는 일·주·월·연·기준일·마감시각
 *   3) 그리드 pref는 scrnCd+persistId로 저장한다
 *
 * PIPELINE[HF89] 작성 문서 관리 화면
 */
// 역할 — 상태·메모·초기 목록 조회
import { useCallback, useEffect, useMemo, useState } from "react";
// 역할 — 권한·비동기·그리드
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useGridAccess } from "@/hooks/useGridAccess";
import { useEditableRows } from "@/hooks/useEditableRows";
import { useCommonCodes } from "@/hooks/useCommonCodes";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
import { PageCard, PageCardSplit } from "@/components/layout/PageCard";
import { PageHead, SearchArea, SearchButton, SearchField } from "@/components/layout/SearchArea";
import { searchInputClass } from "@/components/ui/Input";
import { gridHeadClass, gridPanelClass, pageRootClass } from "@/components/layout/pageClasses";
import { mesConfirm, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { usePageCommands } from "@/shell/pageCommands";
import { useSection } from "@/shell/useSection";
import { guardSaveWithKey } from "@/shell/gridRules";
import { resolveRowsForDelete } from "@/shell/resolveDelete";
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
import {
  deleteScheduleRules,
  listCompanyTemplates,
  listScheduleRules,
  saveCompanyTemplate,
  saveScheduleRule,
  validateDeleteScheduleRules,
  type CompanyTemplate,
  type ScheduleRule,
} from "@/api/workflowApi";
import { SCHEDULE_CYCLE_GRID_RULES } from "./ScheduleCycleManagementPage.rules";

const CYCLE_OPTIONS = [
  { value: "D", label: "일" },
  { value: "W", label: "주" },
  { value: "M", label: "월" },
  { value: "Y", label: "연" },
] as const;

type DocRow = Omit<CompanyTemplate, "useYn" | "sysYn" | "docKind"> & {
  _key?: string;
  // 화면용 공통코드 값 — sys/usr, html/hwp, y/n
  sysYn?: string | null;
  docKind?: string | null;
  useYn?: string;
};
type RuleRow = ScheduleRule & { _key?: string };

/** yyyyMMdd → yyyy-mm-dd (date input) */
function ymdToInput(ymd?: string | null): string {
  const s = String(ymd ?? "").replace(/\D/g, "");
  if (s.length !== 8) return "";
  return `${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6, 8)}`;
}
/** yyyy-mm-dd → yyyyMMdd */
function inputToYmd(value: string): string {
  return String(value ?? "").replace(/\D/g, "").slice(0, 8);
}
/** HHMM → HH:mm */
function hhmmToTime(hhmm?: string | null): string {
  const s = String(hhmm ?? "").replace(/\D/g, "").padStart(4, "0").slice(0, 4);
  if (s.length < 4 || s === "0000" && !hhmm) return "";
  return `${s.slice(0, 2)}:${s.slice(2, 4)}`;
}
/** HH:mm → HHMM */
function timeToHhmm(value: string): string {
  const s = String(value ?? "").replace(/\D/g, "").slice(0, 4);
  return s.padStart(4, "0").slice(0, 4);
}

function toUiSys(v?: string | null): string {
  const s = String(v ?? "").toLowerCase();
  if (s === "usr" || s === "n") return "usr";
  return "sys";
}
function toUiTy(v?: string | null): string {
  const s = String(v ?? "").toLowerCase();
  if (s === "hwp" || s === "hwpx") return "hwp";
  if (s === "html" || s === "db") return "html";
  return s || "hwp";
}
function toUiUse(v?: string | null): string {
  const s = String(v ?? "y").toLowerCase();
  return s === "n" ? "n" : "y";
}
function toDbUse(v?: string | null): "Y" | "N" {
  return String(v ?? "y").toLowerCase() === "n" ? "N" : "Y";
}

function emptyRule(tmplCd: string): RuleRow {
  return {
    tmplCd,
    cycleCd: "D",
    baseDt: ymdToInput(new Date().toISOString().slice(0, 10).replace(/-/g, "")),
    dueTime: "18:00",
    deptCd: "",
    userNm: "",
    useYn: "y",
  };
}

function mapDoc(form: CompanyTemplate): DocRow {
  return {
    ...form,
    sysYn: toUiSys(form.sysYn),
    docKind: toUiTy(form.docKind),
    useYn: toUiUse(form.useYn),
  };
}

function mapRule(row: ScheduleRule): RuleRow {
  return {
    ...row,
    baseDt: ymdToInput(row.baseDt) || (row.monthDay != null
      ? ymdToInput(`${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, "0")}${String(row.monthDay).padStart(2, "0")}`)
      : ""),
    dueTime: hhmmToTime(row.dueTime) || "18:00",
    userNm: row.userNm ?? row.userId ?? "",
    useYn: toUiUse(row.useYn),
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 작성가능문서·작성주기 상하 관리, 공통코드 연동
 *   2) 메뉴에서 화면을 열면 목록을 읽고 검색·CRUD한다
 *   3) 권한·검증 실패는 업무 토스트로만 안내한다
 */
export default function ScheduleCycleManagementPage() {
  const screenCode = "schedule-cycle-management";
  const canWrite = useAuthStore((state) => state.can(screenCode, "write"));
  const canModify = useAuthStore((state) => state.can(screenCode, "modify"));
  const canDelete = useAuthStore((state) => state.can(screenCode, "delete"));
  const asyncAct = useAsyncAction();
  const sec = useSection();
  const sysCodes = useCommonCodes("sys-yn");
  const tyCodes = useCommonCodes("tmpl-ty");
  const useCodes = useCommonCodes("use-yn");

  const [allTemplates, setAllTemplates] = useState<CompanyTemplate[]>([]);
  const [selectedTmplCd, setSelectedTmplCd] = useState("");
  const [qTmplCd, setQTmplCd] = useState("");
  const [qTmplNm, setQTmplNm] = useState("");
  const [docActiveKey, setDocActiveKey] = useState<string | null>(null);
  const [ruleActiveKey, setRuleActiveKey] = useState<string | null>(null);
  const [docSelKeys, setDocSelKeys] = useState<string[]>([]);
  const [ruleSelKeys, setRuleSelKeys] = useState<string[]>([]);
  const [docSelReset, setDocSelReset] = useState(0);
  const [ruleSelReset, setRuleSelReset] = useState(0);
  const clearDocSel = () => { setDocSelKeys([]); setDocSelReset((n) => n + 1); };
  const clearRuleSel = () => { setRuleSelKeys([]); setRuleSelReset((n) => n + 1); };

  const docs = useEditableRows<DocRow>("tmplCd");
  const rules = useEditableRows<RuleRow>("idx");
  const grid = useGridAccess(SCHEDULE_CYCLE_GRID_RULES, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });
  const ruleGrid = useGridAccess({ newOnly: [] }, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });

  // 추가 가능 — 미사용 + hwp 타입만
  const unusedOptions = useMemo(
    () => allTemplates
      .filter((form) => toUiUse(form.useYn) !== "y" && toUiTy(form.docKind) === "hwp")
      .map((form) => ({ value: form.tmplCd, label: form.tmplNm ?? form.tmplCd })),
    [allTemplates],
  );
  const unusedMap = useMemo(
    () => Object.fromEntries(unusedOptions.map((opt) => [opt.value, opt.label])),
    [unusedOptions],
  );

  const sysOpts = useMemo(
    () => (sysCodes.codes.length ? sysCodes.codes : [
      { subCd: "sys", codeNm: "시스템" }, { subCd: "usr", codeNm: "사용자" },
    ]).map((c) => ({ value: c.subCd, label: c.codeNm })),
    [sysCodes.codes],
  );
  const tyOpts = useMemo(
    () => (tyCodes.codes.length ? tyCodes.codes : [
      { subCd: "html", codeNm: "HTML" }, { subCd: "hwp", codeNm: "HWP" },
    ]).map((c) => ({ value: c.subCd, label: c.codeNm })),
    [tyCodes.codes],
  );
  const useOpts = useMemo(
    () => (useCodes.codes.length ? useCodes.codes : [
      { subCd: "y", codeNm: "사용" }, { subCd: "n", codeNm: "미사용" },
    ]).map((c) => ({ value: c.subCd, label: c.codeNm })),
    [useCodes.codes],
  );

  const docColumns = useMemo<GridColumn<DocRow>[]>(() => {
    const editable = canWrite || canModify;
    return [
      {
        field: "tmplCd",
        header: "양식코드",
        width: 200,
        type: "code",
        required: true,
        editableOnNew: true,
        codeOptions: unusedOptions,
        codeMap: unusedMap,
      },
      {
        field: "tmplNm",
        header: "양식명",
        width: 200,
        editable,
      },
      {
        field: "docKind",
        header: "타입",
        width: 90,
        type: "code",
        editable: false,
        codeOptions: tyOpts,
        codeMap: Object.fromEntries(tyOpts.map((o) => [o.value, o.label])),
      },
      {
        field: "sysYn",
        header: "시스템유무",
        width: 100,
        type: "code",
        editable: false,
        codeOptions: sysOpts,
        codeMap: Object.fromEntries(sysOpts.map((o) => [o.value, o.label])),
      },
      {
        field: "useYn",
        header: "사용여부",
        width: 90,
        type: "code",
        editable,
        codeOptions: useOpts,
        codeMap: Object.fromEntries(useOpts.map((o) => [o.value, o.label])),
      },
    ];
  }, [canModify, canWrite, unusedMap, unusedOptions, sysOpts, tyOpts, useOpts]);

  const ruleColumns = useMemo<GridColumn<RuleRow>[]>(() => {
    const editable = canWrite || canModify;
    return [
      {
        field: "cycleCd",
        header: "주기",
        width: 80,
        type: "code",
        required: true,
        editable,
        codeOptions: [...CYCLE_OPTIONS],
        codeMap: Object.fromEntries(CYCLE_OPTIONS.map((o) => [o.value, o.label])),
      },
      {
        // 기준일 — 화면 yyyy-mm-dd, 저장 yyyyMMdd
        field: "baseDt",
        header: "기준일",
        width: 130,
        type: "date",
        editable,
      },
      {
        // 마감시간 — HH:mm 텍스트(저장 시 HHMM)
        field: "dueTime",
        header: "마감시간",
        width: 110,
        editable,
        kioskFormat: "time",
      },
      { field: "deptCd", header: "담당부서", width: 120, editable },
      { field: "userNm", header: "담당자명", width: 120, editable },
      {
        field: "useYn",
        header: "사용여부",
        width: 90,
        type: "code",
        editable,
        codeOptions: useOpts,
        codeMap: Object.fromEntries(useOpts.map((o) => [o.value, o.label])),
      },
      { field: "insId", header: "등록자", width: 100, editable: false },
      { field: "insDt", header: "등록일시", width: 150, editable: false },
    ];
  }, [canModify, canWrite, useOpts]);

  const load = useCallback(async (preferCd?: string) => {
    try {
      const [ruleRows, forms] = await Promise.all([listScheduleRules(), listCompanyTemplates()]);
      setAllTemplates(forms);
      const cdQ = qTmplCd.trim().toLowerCase();
      const nmQ = qTmplNm.trim().toLowerCase();
      const used = forms.filter((form) => {
        if (toUiUse(form.useYn) !== "y") return false;
        if (cdQ && !String(form.tmplCd ?? "").toLowerCase().includes(cdQ)) return false;
        if (nmQ && !String(form.tmplNm ?? "").toLowerCase().includes(nmQ)) return false;
        return true;
      }).map(mapDoc);
      docs.load(used);
      const nextCd = preferCd
        || (used.some((row) => row.tmplCd === selectedTmplCd) ? selectedTmplCd : "")
        || used[0]?.tmplCd
        || "";
      setSelectedTmplCd(nextCd);
      setDocActiveKey(nextCd || null);
      // 동일 양식은 API가 최신순 — 화면에도 그대로
      rules.load(ruleRows.filter((row) => row.tmplCd === nextCd).map(mapRule));
      setRuleActiveKey(null);
      clearDocSel();
      clearRuleSel();
    } catch (error) {
      mesError(error);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [qTmplCd, qTmplNm, selectedTmplCd]);

  useEffect(() => { void load(); }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const selectDoc = (tmplCd: string) => {
    setSelectedTmplCd(tmplCd);
    setDocActiveKey(tmplCd);
    sec.setSec("h");
    sec.reset();
    void (async () => {
      try {
        const ruleRows = await listScheduleRules();
        rules.load(ruleRows.filter((row) => row.tmplCd === tmplCd).map(mapRule));
        setRuleActiveKey(null);
        clearRuleSel();
      } catch (error) {
        mesError(error);
      }
    })();
  };

  const handleAddDoc = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    sec.setSec("h");
    // 추가 — 타입 hwp·시스템 usr 고정, 양식코드는 신규만 편집
    const first = unusedOptions[0];
    setDocActiveKey(docs.addRow({
      tmplCd: first?.value ?? "",
      tmplNm: first?.label ?? "",
      docKind: "hwp",
      sysYn: "usr",
      useYn: "y",
    }));
  };

  const handleAddRule = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    if (!selectedTmplCd) return mesToast("좌측에서 양식을 선택하세요.", "warn");
    sec.setSec("d");
    setRuleActiveKey(rules.addRow(emptyRule(selectedTmplCd)));
  };

  const handleSaveDocs = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    const dirty = docs.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    for (const row of dirty) {
      if (!String(row.tmplCd ?? "").trim()) {
        mesToast(MES.required("양식코드"), "warn");
        setDocActiveKey(row._key);
        return;
      }
      if (!String(row.tmplNm ?? "").trim()) {
        mesToast(MES.required("양식명"), "warn");
        setDocActiveKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      for (const row of dirty) {
        const src = allTemplates.find((form) => form.tmplCd === row.tmplCd);
        await saveCompanyTemplate({
          tmplCd: String(row.tmplCd),
          tmplNm: String(row.tmplNm ?? "").trim(),
          apprLineCd: src?.apprLineCd ?? null,
          cycleCd: src?.cycleCd ?? null,
          retentionMonth: src?.retentionMonth ?? null,
          useYn: toDbUse(row.useYn),
        });
      }
      mesToast(MES.saveDone, "success");
      const prefer = dirty[dirty.length - 1]?.tmplCd;
      await load(prefer ? String(prefer) : undefined);
    } catch (error) {
      mesError(error);
    }
  };

  const handleSaveRules = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    if (!selectedTmplCd) return mesToast("좌측에서 양식을 선택하세요.", "warn");
    const dirty = rules.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    const guard = guardSaveWithKey(ruleGrid.rules, ruleGrid.ctx, dirty, ruleColumns);
    if (guard) {
      mesToast(guard.message, "warn");
      if (guard.rowKey) setRuleActiveKey(guard.rowKey);
      return;
    }
    for (const row of dirty) {
      if (!String(row.cycleCd ?? "").trim()) {
        mesToast(MES.required("주기"), "warn");
        setRuleActiveKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      for (const row of dirty) {
        const baseYmd = inputToYmd(String(row.baseDt ?? ""));
        await saveScheduleRule({
          idx: row._rowState === "C" ? undefined : row.idx,
          tmplCd: selectedTmplCd,
          cycleCd: row.cycleCd,
          baseDt: baseYmd || null,
          dueTime: timeToHhmm(String(row.dueTime ?? "1800")),
          deptCd: row.deptCd ?? null,
          userId: row.userNm ?? row.userId ?? null,
          userNm: row.userNm ?? null,
          useYn: toDbUse(row.useYn),
        });
      }
      mesToast(MES.saveDone, "success");
      await load(selectedTmplCd);
    } catch (error) {
      mesError(error);
    }
  };

  const handleDeleteDocs = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(docs.rows, docActiveKey, setDocActiveKey, docSelKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");
    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    let lastFocus = docActiveKey;
    for (const row of newRows) {
      const { focusKey } = docs.removeNewRow(row._key);
      lastFocus = focusKey;
    }
    if (newRows.length > 0) {
      setDocActiveKey(lastFocus);
      clearDocSel();
    }
    if (persisted.length === 0) return;
    if (!(await mesConfirm("선택한 양식을 미사용으로 전환하시겠습니까?"))) return;
    try {
      for (const row of persisted) {
        const src = allTemplates.find((form) => form.tmplCd === row.tmplCd) ?? row;
        await saveCompanyTemplate({
          tmplCd: String(row.tmplCd),
          tmplNm: src.tmplNm ?? String(row.tmplCd),
          apprLineCd: src.apprLineCd ?? null,
          cycleCd: src.cycleCd ?? null,
          retentionMonth: src.retentionMonth ?? null,
          useYn: "N",
        });
      }
      clearDocSel();
      mesToast(MES.deleteDone, "success");
      await load();
    } catch (error) {
      mesError(error);
    }
  };

  const handleDeleteRules = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(rules.rows, ruleActiveKey, setRuleActiveKey, ruleSelKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");
    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    let lastFocus = ruleActiveKey;
    for (const row of newRows) {
      const { focusKey } = rules.removeNewRow(row._key);
      lastFocus = focusKey;
    }
    if (newRows.length > 0) {
      setRuleActiveKey(lastFocus);
      clearRuleSel();
    }
    if (persisted.length === 0) return;
    const keys = persisted
      .map((row) => Number(row.idx))
      .filter((idx) => Number.isFinite(idx) && idx > 0)
      .map((idx) => ({ idx }));
    if (keys.length === 0) return mesToast("삭제할 행의 키가 올바르지 않습니다.", "warn");
    try {
      await validateDeleteScheduleRules(keys);
      if (!(await mesConfirm(MES.deleteConfirm()))) return;
      await deleteScheduleRules(keys);
      clearRuleSel();
      mesToast(MES.deleteDone, "success");
      await load(selectedTmplCd);
    } catch (error) {
      mesError(error);
    }
  };

  const doSearch = () => asyncAct.run(() => load(selectedTmplCd || undefined), "search");

  usePageCommands({
    search: () => { void doSearch(); },
    add: () => { if (sec.is("d")) handleAddRule(); else handleAddDoc(); },
    save: () => { void asyncAct.run(sec.is("d") ? handleSaveRules : handleSaveDocs, "save"); },
    del: () => { void asyncAct.run(sec.is("d") ? handleDeleteRules : handleDeleteDocs, "del"); },
  });

  return (
    <div className={pageRootClass}>
      <PageHead title="작성 문서 관리" />
      <PageCard
        search={(
          <SearchArea
            onSearch={() => { void doSearch(); }}
            actions={<SearchButton loading={asyncAct.isBusy("search")} />}
          >
            <SearchField label="양식코드">
              <input
                className={searchInputClass}
                value={qTmplCd}
                onChange={(event) => setQTmplCd(event.target.value)}
                placeholder="tmpl_…"
              />
            </SearchField>
            <SearchField label="양식명">
              <input
                className={searchInputClass}
                value={qTmplNm}
                onChange={(event) => setQTmplNm(event.target.value)}
                placeholder="문서명"
              />
            </SearchField>
          </SearchArea>
        )}
      >
        <PageCardSplit storageKey="haccp-split-schedule-cycle">
          <div {...sec.bind("h", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>작성 가능 문서</b>
              <GridCrudButtons
                run={asyncAct.run}
                onAdd={canWrite ? handleAddDoc : undefined}
                onSave={canWrite || canModify ? handleSaveDocs : undefined}
                onDel={canDelete ? handleDeleteDocs : undefined}
                busy={{ save: asyncAct.isBusy("save"), del: asyncAct.isBusy("del") }}
              />
            </div>
            <MesEditableGrid
              persistId="bas-schedule-cycle-docs"
              scrnCd={screenCode}
              title="작성 가능 문서"
              rows={docs.rows as EditableRow<DocRow>[]}
              columns={docColumns}
              editable={canWrite || canModify}
              height="100%"
              loading={asyncAct.isBusy("search")}
              activeKey={docActiveKey}
              onActivate={(row) => {
                sec.setSec("h");
                if (row._rowState === "C") {
                  setDocActiveKey(row._key);
                  return;
                }
                selectDoc(String(row.tmplCd));
              }}
              onCellChange={(key, field, value) => {
                docs.updateCell(key, field as keyof DocRow, value);
                if (field === "tmplCd") {
                  const hit = allTemplates.find((form) => form.tmplCd === value);
                  if (hit) {
                    docs.updateCell(key, "tmplNm", hit.tmplNm);
                    docs.updateCell(key, "docKind", "hwp");
                    docs.updateCell(key, "sysYn", "usr");
                  }
                }
              }}
              access={grid.access}
              onLockedAttempt={grid.onLockedAttempt}
              onSetActive={() => sec.setSec("h")}
              selectable
              onSelectionChange={(rows) => setDocSelKeys(rows.map((row) => row._key))}
              selectionResetKey={docSelReset}
              showRowNum
            />
          </div>

          <div {...sec.bind("d", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>
                작성주기
                {selectedTmplCd ? ` (${selectedTmplCd})` : ""}
                {" — 최신 규칙 적용"}
              </b>
              <GridCrudButtons
                run={asyncAct.run}
                onAdd={canWrite ? handleAddRule : undefined}
                onSave={canWrite || canModify ? handleSaveRules : undefined}
                onDel={canDelete ? handleDeleteRules : undefined}
                busy={{ save: asyncAct.isBusy("save"), del: asyncAct.isBusy("del") }}
              />
            </div>
            <MesEditableGrid
              persistId="bas-schedule-cycle-rules"
              scrnCd={screenCode}
              title="작성주기"
              rows={rules.rows as EditableRow<RuleRow>[]}
              columns={ruleColumns}
              editable={canWrite || canModify}
              height="100%"
              loading={asyncAct.isBusy("search") || asyncAct.isBusy("save") || asyncAct.isBusy("del")}
              activeKey={ruleActiveKey}
              onActivate={(row) => {
                sec.setSec("d");
                setRuleActiveKey(row._key);
              }}
              onCellChange={(key, field, value) => rules.updateCell(key, field as keyof RuleRow, value)}
              access={ruleGrid.access}
              onLockedAttempt={ruleGrid.onLockedAttempt}
              onSetActive={() => sec.setSec("d")}
              selectable
              onSelectionChange={(rows) => setRuleSelKeys(rows.map((row) => row._key))}
              selectionResetKey={ruleSelReset}
              showRowNum
            />
          </div>
        </PageCardSplit>
      </PageCard>
    </div>
  );
}
