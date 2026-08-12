/**
 * TemplateCheckItemManagementPage — 문서별 점검항목·작성주기 admin.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) mes-web SoPage와 동일 — PageCardSplit 상·하 + 패널별 GridCrudButtons
 *   2) fixedTmplCd(tmpl_prp-hygiene-daily/tmpl_prp-facility-check/tmpl_ccp-verify-check) 전용 — 범용 메뉴는 제거했다
 *   3) 셸 CRUD는 useSection(h=항목, d=주기)으로만 라우팅한다
 *
 * PIPELINE[HF88] 점검항목·작성주기 admin
 * PIPELINE[HF90, HF86, HF29, HF52] 연관 모듈
 */
// 역할 — 상태·양식·주기 목록
import { useCallback, useEffect, useMemo, useState } from "react";
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — 그리드 잠금(접근) — 활성 그리드마다 access·onLockedAttempt 필수
import { useGridAccess } from "@/hooks/useGridAccess";
import { MesButton } from "@/components/ui/MesButton";
import { searchInputClass } from "@/components/ui/Input";
import { mesConfirm, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { usePageCommands } from "@/shell/pageCommands";
import { useSection } from "@/shell/useSection";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
import { PageCard, PageCardSplit } from "@/components/layout/PageCard";
import { PageHead, SearchArea, SearchButton, SearchField } from "@/components/layout/SearchArea";
import { gridHeadClass, gridPanelClass, pageRootClass } from "@/components/layout/pageClasses";
import { useEditableRows } from "@/hooks/useEditableRows";
import { resolveRowsForDelete } from "@/shell/resolveDelete";
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
import {
  deleteCompanyCheckItems,
  deleteScheduleRules,
  listApprovalLines,
  listCompanyCheckItems,
  listCompanyTemplates,
  listScheduleRules,
  saveCompanyCheckItem,
  saveCompanyTemplate,
  saveScheduleRule,
  validateDeleteCompanyCheckItems,
  validateDeleteScheduleRules,
  type CompanyCheckItem,
  type CompanyTemplate,
  type ScheduleRule,
} from "@/api/workflowApi";

type ItemRow = CompanyCheckItem & { _key?: string };
type RuleRow = ScheduleRule & { _key?: string };

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

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 문서별 admin 메뉴에서 fixedTmplCd로 연다
 *   2) 좌·우 그리드 CRUD와 양식 헤더 저장을 분리한다
 *   3) 권한·검증 실패는 업무 토스트만 표시한다
 */
export interface TemplateCheckItemManagementPageProps {
  // 권한·화면코드 — 문서별 admin leaf scrn_cd
  screenCode: string;
  // 양식 고정 — tmpl_prp-hygiene-daily / tmpl_ccp-verify-check / tmpl_prp-facility-check
  fixedTmplCd: string;
}

export default function TemplateCheckItemManagementPage({
  screenCode,
  fixedTmplCd,
}: TemplateCheckItemManagementPageProps) {
  const canWrite = useAuthStore((state) => state.can(screenCode, "write"));
  const canModify = useAuthStore((state) => state.can(screenCode, "modify"));
  const canDelete = useAuthStore((state) => state.can(screenCode, "delete"));
  const asyncAct = useAsyncAction();
  // h=점검항목, d=작성주기 — SoPage sec 계약
  const sec = useSection();
  const [lines, setLines] = useState<string[]>([]);
  const [template, setTemplate] = useState<CompanyTemplate | null>(null);
  const [itemActiveKey, setItemActiveKey] = useState<string | null>(null);
  const [ruleActiveKey, setRuleActiveKey] = useState<string | null>(null);
  const [itemSelKeys, setItemSelKeys] = useState<string[]>([]);
  const [ruleSelKeys, setRuleSelKeys] = useState<string[]>([]);
  const [itemSelReset, setItemSelReset] = useState(0);
  const [ruleSelReset, setRuleSelReset] = useState(0);
  const items = useEditableRows<ItemRow>("itemCd");
  const rules = useEditableRows<RuleRow>("idx");
  // 상단 점검항목 — 읽기전용·잠금 안내(활성 그리드 이벤트)
  const itemGrid = useGridAccess({ newOnly: [] }, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });
  // 하단 작성주기 — 동일 권한·잠금 이벤트
  const ruleGrid = useGridAccess({ newOnly: [] }, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });

  const clearItemSel = () => { setItemSelKeys([]); setItemSelReset((n) => n + 1); };
  const clearRuleSel = () => { setRuleSelKeys([]); setRuleSelReset((n) => n + 1); };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 고정 양식 헤더·결재선·점검항목·해당 양식 주기 규칙을 다시 읽는다
   *   2) 최초 진입·조회·저장·삭제 뒤에 호출한다
   *   3) fixedTmplCd가 비면 점검항목 API를 호출하지 않고 안내만 한다
   */
  const loadAll = useCallback(async () => {
    // 양식 코드 — 레지스트리 fixedTmplCd (공백이면 필수 쿼리 누락 방지)
    const tmpl = String(fixedTmplCd ?? "").trim();
    if (!tmpl) {
      mesToast("양식 코드가 없습니다.", "warn");
      return;
    }
    try {
      const [allTmpl, nextLines, nextItems, nextRules] = await Promise.all([
        listCompanyTemplates(),
        listApprovalLines(),
        listCompanyCheckItems(tmpl),
        listScheduleRules(),
      ]);
      const hit = allTmpl.find((row) => row.tmplCd === tmpl) ?? null;
      setTemplate(hit ? { ...hit } : {
        tmplCd: tmpl,
        tmplNm: tmpl,
        useYn: "Y",
      });
      setLines(nextLines.map((line) => line.apprLineCd));
      items.load(nextItems.map((row) => ({ ...row, itemNmOvr: row.itemNmOvr ?? "" })));
      // 하단은 고정 양식 주기만
      rules.load(nextRules.filter((row) => row.tmplCd === tmpl));
      setItemActiveKey(null);
      setRuleActiveKey(null);
      clearItemSel();
      clearRuleSel();
    } catch (error) {
      mesError(error);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- load 안정 참조
  }, [fixedTmplCd]);

  useEffect(() => { void loadAll(); }, [loadAll]);

  const itemColumns = useMemo<GridColumn<EditableRow<ItemRow>>[]>(() => {
    const editable = canWrite || canModify;
    return [
      { field: "grpNm", header: "구분", width: 100, editable: false },
      { field: "itemCd", header: "항목코드", width: 120, editable: false },
      { field: "itemNm", header: "표준 문구", width: 220, editable: false },
      {
        // 업체 문구 — CUST 신규은 여기가 필수 표시명
        field: "itemNmOvr",
        header: "업체 문구",
        width: 260,
        editable,
      },
      { field: "sortNo", header: "순서", width: 70, editable, type: "number" },
      {
        field: "useYn",
        header: "표시",
        width: 80,
        editable,
        type: "code",
        codeOptions: [{ value: "Y", label: "표시" }, { value: "N", label: "숨김" }],
        codeMap: { Y: "표시", N: "숨김" },
      },
    ];
  }, [canModify, canWrite]);

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

  const handleAddItem = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    sec.setSec("h");
    setItemActiveKey(items.addRow({
      tmplCd: fixedTmplCd,
      itemCd: "",
      itemNm: "",
      itemNmOvr: "",
      sortNo: (items.rows.length + 1) * 10,
      useYn: "Y",
    }));
  };

  const handleAddRule = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    sec.setSec("d");
    setRuleActiveKey(rules.addRow({
      tmplCd: fixedTmplCd,
      cycleCd: "D",
      dueTime: "1800",
      useYn: "Y",
    }));
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 양식 헤더(결재선·보존·사용)만 저장한다 — 그리드 CRUD와 분리
   *   2) 헤더 옆 「양식 저장」에서 호출한다
   *   3) 권한·확인 실패는 토스트만
   */
  const handleSaveHeader = async () => {
    if (!template || (!canWrite && !canModify)) return mesToast("수정 권한이 없습니다.", "warn");
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      await saveCompanyTemplate(template);
      mesToast(MES.saveDone, "success");
      await loadAll();
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 점검항목 변경행만 저장한다 — CUST 신규는 itemCd 빈 채로 보내 서버 채번
   *   2) 좌측 GridCrudButtons·포커스 패인 저장에서 호출한다
   *   3) CUST 문구 필수·권한 실패는 토스트만
   */
  const handleSaveItems = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    const dirty = items.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    for (const row of dirty) {
      const ovr = String(row.itemNmOvr ?? "").trim();
      const isNew = row._rowState === "C" || !String(row.itemCd ?? "").trim();
      if (isNew && !ovr) {
        mesToast(MES.required("업체 문구"), "warn");
        setItemActiveKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      for (const row of dirty) {
        await saveCompanyCheckItem({
          tmplCd: fixedTmplCd,
          itemCd: String(row.itemCd ?? ""),
          itemNm: String(row.itemNm ?? row.itemNmOvr ?? ""),
          itemNmOvr: row.itemNmOvr ?? null,
          sortNo: row.sortNo ?? null,
          useYn: (row.useYn as "Y" | "N") ?? "Y",
          grpNm: row.grpNm ?? null,
        });
      }
      mesToast(MES.saveDone, "success");
      await loadAll();
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 고정 양식의 작성주기 변경행만 저장한다
   *   2) 우측 GridCrudButtons·포커스 패인 저장에서 호출한다
   *   3) 주기 필수·권한 실패는 토스트만
   */
  const handleSaveRules = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    const dirty = rules.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
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
          tmplCd: fixedTmplCd,
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
      await loadAll();
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 선택 점검항목 삭제 — 신규행 제거 또는 CUST validate-delete·delete
   *   2) 좌측 삭제·포커스 패인 삭제에서 호출한다
   *   3) 표준 항목은 서버가 숨김 안내로 차단한다
   */
  const handleDeleteItems = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(items.rows, itemActiveKey, setItemActiveKey, itemSelKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");
    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    let lastFocus = itemActiveKey;
    for (const row of newRows) {
      const { focusKey } = items.removeNewRow(row._key);
      lastFocus = focusKey;
    }
    if (newRows.length > 0) {
      setItemActiveKey(lastFocus);
      clearItemSel();
    }
    if (persisted.length === 0) return;
    const keys = persisted.map((row) => ({
      tmplCd: fixedTmplCd,
      itemCd: String(row.itemCd),
    }));
    try {
      await validateDeleteCompanyCheckItems(keys);
      if (!(await mesConfirm(MES.deleteConfirm()))) return;
      await deleteCompanyCheckItems(keys);
      clearItemSel();
      mesToast(MES.deleteDone, "success");
      await loadAll();
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 선택 작성주기 삭제 — validate-delete·확인·delete·재조회
   *   2) 우측 삭제·포커스 패인 삭제에서 호출한다
   *   3) 참조·권한 실패는 업무 토스트만
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
      await loadAll();
    } catch (error) {
      mesError(error);
    }
  };

  const doSearch = () => asyncAct.run(async () => {
    sec.reset();
    await loadAll();
  }, "search");

  // 셸 단축키 — 활성 섹션으로만 라우팅 (패널 버튼은 고정 타겟)
  usePageCommands({
    search: () => { void doSearch(); },
    add: () => { if (sec.is("d")) handleAddRule(); else handleAddItem(); },
    save: () => { void asyncAct.run(sec.is("d") ? handleSaveRules : handleSaveItems, "save"); },
    del: () => { void asyncAct.run(sec.is("d") ? handleDeleteRules : handleDeleteItems, "del"); },
  });

  return (
    <div className={pageRootClass}>
      <PageHead
        // 화면 제목 — 고정 양식명
        title={template?.tmplNm ?? fixedTmplCd}
      />
      <PageCard
        // 검색 카드 — 조회 + 양식 헤더(결재선·보존·사용)
        search={(
          <SearchArea
            onSearch={() => { void doSearch(); }}
            actions={(
              <>
                <MesButton
                  // 결재선·보존·사용만 저장 — 그리드 CRUD와 분리
                  variant="secondary"
                  disabled={(!canWrite && !canModify) || asyncAct.isBusy("header")}
                  onClick={() => void asyncAct.run(handleSaveHeader, "header")}
                >
                  양식 저장
                </MesButton>
                <SearchButton
                  // 조회 busy 스피너
                  loading={asyncAct.isBusy("search")}
                />
              </>
            )}
          >
            <SearchField label="결재선">
              <select
                // 업체 기본 결재선 코드
                value={template?.apprLineCd ?? ""}
                disabled={!canModify && !canWrite}
                onChange={(e) => template && setTemplate({ ...template, apprLineCd: e.target.value || null })}
                className={searchInputClass}
              >
                <option value="">미지정</option>
                {lines.map((code) => <option key={code}>{code}</option>)}
              </select>
            </SearchField>
            <SearchField label="보존개월">
              <input
                // 보존 개월 수
                type="number"
                className={searchInputClass}
                value={String(template?.retentionMonth ?? "")}
                disabled={!canModify && !canWrite}
                onChange={(e) => template && setTemplate({
                  ...template,
                  retentionMonth: e.target.value ? Number(e.target.value) : null,
                })}
              />
            </SearchField>
            <SearchField label="사용">
              <select
                // 업체 양식 사용여부
                value={template?.useYn ?? "Y"}
                disabled={!canModify && !canWrite}
                onChange={(e) => template && setTemplate({ ...template, useYn: e.target.value as "Y" | "N" })}
                className={searchInputClass}
              >
                <option value="Y">사용</option>
                <option value="N">미사용</option>
              </select>
            </SearchField>
          </SearchArea>
        )}
      >
        <PageCardSplit storageKey="haccp-split-tmpl-check-item">
          <div {...sec.bind("h", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>점검항목</b>
              <GridCrudButtons
                // useAsyncAction.run — busy 키 래핑
                run={asyncAct.run}
                // 상단 항목 전용 행추가
                onAdd={canWrite ? handleAddItem : undefined}
                // 상단 항목 전용 저장
                onSave={canWrite || canModify ? handleSaveItems : undefined}
                // CUST 삭제(표준은 숨김 안내)
                onDel={canDelete ? handleDeleteItems : undefined}
                busy={{
                  save: asyncAct.isBusy("save"),
                  del: asyncAct.isBusy("del"),
                }}
              />
            </div>
            <MesEditableGrid
              // 열 설정 저장 키 — 문서별 admin 상단 항목
              persistId={`bas-check-items-${fixedTmplCd}`}
              // CSV·오류경계 라벨 — 패널 제목과 동일
              title="점검항목"
              rows={items.rows}
              columns={itemColumns}
              editable={canWrite || canModify}
              height="100%"
              loading={asyncAct.isBusy("search")}
              activeKey={itemActiveKey}
              onActivate={(row) => {
                sec.setSec("h");
                setItemActiveKey(row._key);
              }}
              onCellChange={(key, field, value) => items.updateCell(key, field as keyof ItemRow, value)}
              // 잠금·권한 접근 판정 — 활성 그리드 공통
              access={itemGrid.access}
              // 잠금 셀 시도 안내
              onLockedAttempt={itemGrid.onLockedAttempt}
              // 셸 CRUD 타겟을 상단(항목)으로
              onSetActive={() => sec.setSec("h")}
              selectable
              onSelectionChange={(rows) => setItemSelKeys(rows.map((row) => row._key))}
              selectionResetKey={itemSelReset}
              showRowNum
            />
          </div>

          <div {...sec.bind("d", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>
                작성주기
                {fixedTmplCd ? ` (${fixedTmplCd})` : ""}
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
              // 열 설정 저장 키 — 문서별 admin 하단 주기
              persistId={`bas-schedule-rules-${fixedTmplCd}`}
              // CSV·오류경계 라벨 — 패널 제목과 동일
              title="작성주기"
              rows={rules.rows as EditableRow<RuleRow>[]}
              columns={ruleColumns}
              editable={canWrite || canModify}
              height="100%"
              loading={asyncAct.isBusy("search")}
              activeKey={ruleActiveKey}
              onActivate={(row) => {
                sec.setSec("d");
                setRuleActiveKey(row._key);
              }}
              onCellChange={(key, field, value) => rules.updateCell(key, field as keyof RuleRow, value)}
              // 잠금·권한 접근 판정 — 활성 그리드 공통
              access={ruleGrid.access}
              // 잠금 셀 시도 안내
              onLockedAttempt={ruleGrid.onLockedAttempt}
              // 셸 CRUD 타겟을 하단(주기)으로
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
