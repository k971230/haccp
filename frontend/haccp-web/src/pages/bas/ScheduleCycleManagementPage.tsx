/**
 * ScheduleCycleManagementPage — 작성주기 관리 (SoPage형 상·하).
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) mes-web SoPage와 동일 — PageCardSplit 상·하 + 패널별 GridCrudButtons
 *   2) 상단 사용(Y) 문서 등록·선택, 하단 선택 문서의 주기 규칙 CRUD
 *   3) 셸 단축키만 useSection으로 라우팅한다
 *
 * PIPELINE[HF89] 작성주기 관리 화면
 * PIPELINE[HF86, HF29, HF39, HF96, HF101] 연관 모듈
 */
// 역할 — 상태·메모·초기 목록 조회
import { useCallback, useEffect, useMemo, useState } from "react";
// 역할 — 권한·비동기 처리·업무 UI
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useGridAccess } from "@/hooks/useGridAccess";
import { useEditableRows } from "@/hooks/useEditableRows";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
import { PageCard, PageCardSplit } from "@/components/layout/PageCard";
import { PageHead, SearchArea, SearchButton } from "@/components/layout/SearchArea";
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
// 역할 — 사용양식·작성주기 API
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
// 역할 — 양식코드 newOnly 규칙
import { SCHEDULE_CYCLE_GRID_RULES } from "./ScheduleCycleManagementPage.rules";

const CYCLE_OPTIONS = [
  { value: "D", label: "매일" },
  { value: "W", label: "매주" },
  { value: "M", label: "매월" },
  { value: "Y", label: "매년" },
  { value: "E", label: "수시" },
] as const;

const YN_OPTIONS = [
  { value: "Y", label: "사용" },
  { value: "N", label: "미사용" },
] as const;

type DocRow = CompanyTemplate & { _key?: string };
type RuleRow = ScheduleRule & { _key?: string };
function emptyRule(tmplCd: string): RuleRow {
  return { tmplCd, cycleCd: "D", dueTime: "1800", useYn: "Y" };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 좌·우 분할로 작성 가능 문서와 선택 문서의 주기를 관리한다
 *   2) 메뉴에서 화면을 열면 양식·규칙 목록을 함께 읽는다
 *   3) 권한·검증 실패는 업무 토스트로만 안내한다
 */
export default function ScheduleCycleManagementPage() {
  const screenCode = "schedule-cycle-management";
  const canWrite = useAuthStore((state) => state.can(screenCode, "write"));
  const canModify = useAuthStore((state) => state.can(screenCode, "modify"));
  const canDelete = useAuthStore((state) => state.can(screenCode, "delete"));
  const asyncAct = useAsyncAction();
  // h=문서, d=주기 — SoPage sec 계약
  const sec = useSection();
  const [allTemplates, setAllTemplates] = useState<CompanyTemplate[]>([]);
  const [selectedTmplCd, setSelectedTmplCd] = useState("");
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
  // 상단 문서 — tmplCd newOnly
  const grid = useGridAccess(SCHEDULE_CYCLE_GRID_RULES, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });
  // 하단 작성주기 — 활성 그리드와 동일 access·onLockedAttempt
  const ruleGrid = useGridAccess({ newOnly: [] }, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });

  // 미사용·미등록 양식 — 좌측 행추가 콤보
  const unusedOptions = useMemo(
    () => allTemplates
      .filter((form) => form.useYn !== "Y")
      .map((form) => ({ value: form.tmplCd, label: form.tmplNm ?? form.tmplCd })),
    [allTemplates],
  );
  const unusedMap = useMemo(
    () => Object.fromEntries(unusedOptions.map((opt) => [opt.value, opt.label])),
    [unusedOptions],
  );

  const docColumns = useMemo<GridColumn<DocRow>[]>(() => {
    const editable = canWrite || canModify;
    return [
      {
        // 양식코드 — 신규(미사용 등록) 행에서만 선택
        field: "tmplCd",
        header: "양식",
        width: 160,
        type: "code",
        required: true,
        editableOnNew: true,
        codeOptions: unusedOptions,
        codeMap: unusedMap,
      },
      {
        field: "tmplNm",
        header: "양식명",
        width: 180,
        editable: false,
      },
      {
        field: "useYn",
        header: "사용",
        width: 80,
        type: "code",
        editable,
        codeOptions: [...YN_OPTIONS],
        codeMap: { Y: "사용", N: "미사용" },
      },
    ];
  }, [canModify, canWrite, unusedMap, unusedOptions]);

  const ruleColumns = useMemo<GridColumn<RuleRow>[]>(() => {
    const editable = canWrite || canModify;
    return [
      {
        field: "cycleCd",
        header: "주기",
        width: 90,
        type: "code",
        required: true,
        editable,
        codeOptions: [...CYCLE_OPTIONS],
        codeMap: Object.fromEntries(CYCLE_OPTIONS.map((opt) => [opt.value, opt.label])),
      },
      { field: "weekDays", header: "요일(1~7)", width: 100, editable },
      { field: "monthDay", header: "기준일", width: 80, type: "number", editable },
      { field: "monthNo", header: "기준월", width: 80, type: "number", editable },
      { field: "dueTime", header: "마감시각", width: 90, editable },
      { field: "deptCd", header: "담당부서", width: 100, editable },
      { field: "userId", header: "담당자 ID", width: 110, editable },
      {
        field: "useYn",
        header: "사용",
        width: 80,
        type: "code",
        editable,
        codeOptions: [...YN_OPTIONS],
        codeMap: { Y: "사용", N: "미사용" },
      },
    ];
  }, [canModify, canWrite]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 전체 양식과 작성주기 규칙을 읽고 좌측은 사용 Y만 채운다
   *   2) 최초 진입·조회·저장·삭제 뒤에 호출한다
   *   3) 실패하면 토스트만 표시한다
   */
  const load = useCallback(async (preferCd?: string) => {
    try {
      const [ruleRows, forms] = await Promise.all([listScheduleRules(), listCompanyTemplates()]);
      setAllTemplates(forms);
      const used = forms.filter((form) => form.useYn === "Y");
      docs.load(used);
      const nextCd = preferCd
        || (used.some((row) => row.tmplCd === selectedTmplCd) ? selectedTmplCd : "")
        || used[0]?.tmplCd
        || "";
      setSelectedTmplCd(nextCd);
      setDocActiveKey(nextCd || null);
      rules.load(ruleRows.filter((row) => row.tmplCd === nextCd));
      setRuleActiveKey(null);
      clearDocSel();
      clearRuleSel();
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- docs/rules.load 안정 참조
  }, [selectedTmplCd]);

  useEffect(() => { void load(); }, []); // eslint-disable-line react-hooks/exhaustive-deps -- 최초 1회

  const selectDoc = (tmplCd: string) => {
    setSelectedTmplCd(tmplCd);
    setDocActiveKey(tmplCd);
    sec.setSec("h");
    sec.reset();
    void (async () => {
      try {
        const ruleRows = await listScheduleRules();
        rules.load(ruleRows.filter((row) => row.tmplCd === tmplCd));
        setRuleActiveKey(null);
        clearRuleSel();
      } catch (error) {
        mesToast(mesError(error), "error");
      }
    })();
  };

  const handleAddDoc = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    if (unusedOptions.length === 0) return mesToast("등록할 미사용 양식이 없습니다.", "warn");
    sec.setSec("h");
    const first = unusedOptions[0];
    setDocActiveKey(docs.addRow({
      tmplCd: first.value,
      tmplNm: first.label,
      useYn: "Y",
    }));
  };

  const handleAddRule = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    if (!selectedTmplCd) return mesToast("좌측에서 양식을 선택하세요.", "warn");
    sec.setSec("d");
    setRuleActiveKey(rules.addRow(emptyRule(selectedTmplCd)));
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 좌측 변경행을 saveCompanyTemplate으로 저장한다(useYn 등록·토글)
   *   2) 좌측 GridCrudButtons·포커스 패인 저장에서 호출한다
   *   3) 양식코드 필수·권한 실패는 토스트만
   */
  const handleSaveDocs = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    const dirty = docs.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    for (const row of dirty) {
      if (!String(row.tmplCd ?? "").trim()) {
        mesToast(MES.required("양식"), "warn");
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
          tmplNm: row.tmplNm ?? src?.tmplNm ?? String(row.tmplCd),
          apprLineCd: src?.apprLineCd ?? null,
          cycleCd: src?.cycleCd ?? null,
          retentionMonth: src?.retentionMonth ?? null,
          useYn: (row.useYn as "Y" | "N") ?? "Y",
        });
      }
      mesToast(MES.saveDone, "success");
      const prefer = dirty[dirty.length - 1]?.tmplCd;
      await load(prefer ? String(prefer) : undefined);
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 선택 문서의 작성주기 변경행만 저장한다
   *   2) 우측 GridCrudButtons·포커스 패인 저장에서 호출한다
   *   3) tmplCd는 좌측 선택값으로 고정한다
   */
  const handleSaveRules = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    if (!selectedTmplCd) return mesToast("좌측에서 양식을 선택하세요.", "warn");
    const dirty = rules.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    const guard = guardSaveWithKey(grid.rules, grid.ctx, dirty, ruleColumns);
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
        const toNum = (value: unknown): number | null => {
          if (value == null || value === "") return null;
          const num = Number(value);
          return Number.isFinite(num) ? num : null;
        };
        await saveScheduleRule({
          idx: row._rowState === "C" ? undefined : row.idx,
          tmplCd: selectedTmplCd,
          cycleCd: row.cycleCd,
          weekDays: row.weekDays ?? null,
          monthDay: toNum(row.monthDay),
          monthNo: toNum(row.monthNo),
          dueTime: row.dueTime ?? null,
          deptCd: row.deptCd ?? null,
          userId: row.userId ?? null,
          useYn: row.useYn ?? "Y",
        });
      }
      mesToast(MES.saveDone, "success");
      await load(selectedTmplCd);
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 좌측 삭제 — 신규행 제거 또는 useYn=N 저장(시스템 tmpl 물리 삭제 금지)
   *   2) 좌측 GridCrudButtons·포커스 패인 삭제에서 호출한다
   *   3) 확인 후 저장·재조회한다
   */
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
    if (!(await mesConfirm("선택한 양식을 미사용으로 전환하시겠습니까? (시스템 양식은 물리 삭제하지 않습니다)"))) return;
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
      mesToast(mesError(error), "error");
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 우측 선택행 삭제 — validate-delete·확인·delete·재조회
   *   2) GridCrudButtons·셸 삭제 단축키에서 호출한다
   *   3) 참조 차단·권한 실패는 업무 토스트로만 안내한다
   */
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
      mesToast(mesError(error), "error");
    }
  };

  const doSearch = () => asyncAct.run(() => load(selectedTmplCd || undefined), "search");

  // 셸 단축키 — 활성 섹션으로만 라우팅 (패널 버튼은 고정 타겟)
  usePageCommands({
    search: () => { void doSearch(); },
    add: () => { if (sec.is("d")) handleAddRule(); else handleAddDoc(); },
    save: () => { void asyncAct.run(sec.is("d") ? handleSaveRules : handleSaveDocs, "save"); },
    del: () => { void asyncAct.run(sec.is("d") ? handleDeleteRules : handleDeleteDocs, "del"); },
  });

  return (
    <div className={pageRootClass}>
      <PageHead
        // 화면 제목 — mes-web SoPage와 동일 슬롯
        title="작성주기 관리"
      />
      <PageCard
        // 조회만 검색 카드 — CRUD는 각 그리드 헤더
        search={(
          <SearchArea
            onSearch={() => { void doSearch(); }}
            actions={(
              <SearchButton
                // 조회 busy 스피너
                loading={asyncAct.isBusy("search")}
              />
            )}
          />
        )}
      >
        <PageCardSplit>
          <div {...sec.bind("h", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>작성 가능 문서</b>
              <GridCrudButtons
                // useAsyncAction.run — busy 키 래핑
                run={asyncAct.run}
                // 상단 문서 전용 행추가(미사용→사용 Y)
                onAdd={canWrite ? handleAddDoc : undefined}
                // 상단 문서 전용 저장
                onSave={canWrite || canModify ? handleSaveDocs : undefined}
                // 상단 문서 미사용 전환
                onDel={canDelete ? handleDeleteDocs : undefined}
                busy={{
                  save: asyncAct.isBusy("save"),
                  del: asyncAct.isBusy("del"),
                }}
              />
            </div>
            <MesEditableGrid
              // 열 설정 저장 키 — 작성주기 상단 문서
              persistId="bas-schedule-cycle-docs"
              // CSV·오류경계 라벨 — 패널 제목과 동일
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
                  if (hit) docs.updateCell(key, "tmplNm", hit.tmplNm);
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
              </b>
              <GridCrudButtons
                run={asyncAct.run}
                onAdd={canWrite ? handleAddRule : undefined}
                onSave={canWrite || canModify ? handleSaveRules : undefined}
                onDel={canDelete ? handleDeleteRules : undefined}
                busy={{
                  save: asyncAct.isBusy("save"),
                  del: asyncAct.isBusy("del"),
                }}
              />
            </div>
            <MesEditableGrid
              // 열 설정 저장 키 — 작성주기 하단 규칙
              persistId="bas-schedule-cycle-rules"
              // CSV·오류경계 라벨 — 패널 제목과 동일
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
              // 하단도 활성 그리드와 동일하게 잠금·권한 이벤트
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
