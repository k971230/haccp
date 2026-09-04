/**
 * ApprovalLineManagementPage — 결재선 좌 목록 · 우 단계.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 좌는 결재선 헤더(행추가·저장·삭제), 우는 고정 2단계(저장만)다
 *   2) 행추가·저장 시 1작성 2승인이 들어간다
 *   3) 결재자 셀 버튼은 문서주기 담당자와 같은 룩업이며 부서까지 채운다
 *
 * PIPELINE[HF87] 결재선 관리 화면
 * PIPELINE[HF86, HF29, HF39, HF90, HF52] 연관 모듈
 */
// 역할 — 상태·메모·목록 재조회
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 권한·비동기 중복 방지
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useGridAccess } from "@/hooks/useGridAccess";
import { useEditableRows } from "@/hooks/useEditableRows";
// 역할 — 편집 그리드·CRUD 버튼
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
// 역할 — 검색·좌우 분할
import { PageCard } from "@/components/layout/PageCard";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import {
  SearchArea,
  SearchButton,
  SearchField,
  SearchSelect,
} from "@/components/layout/SearchArea";
import { gridHeadClass, pageRootClass, splitPanelClass } from "@/components/layout/pageClasses";
import { searchInputClass } from "@/components/ui/Input";
// 역할 — 결재자 룩업
import { useModalStore } from "@/stores/modalStore";
// 역할 — 확인·토스트·오류
import { mesConfirm, mesConfirmDanger, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { usePageCommands } from "@/shell/pageCommands";
import { useSection } from "@/shell/useSection";
import { useRegisterPageDirty } from "@/shell/pageDirtyRegistry";
import { resolveRowsForDelete } from "@/shell/resolveDelete";
import { guardSaveWithKey } from "@/shell/gridRules";
import type { EditableRow } from "@/types/editable";
// 역할 — 결재선 API
import { deleteApprovalLines, listApprovalLines, saveApprovalLine, validateDeleteApprovalLines } from "@/api/sys/approvalLineApi";
// 역할 — 사용자 목록 — 결재자 룩업·부서 기본값
import { listUsers } from "@/api/sys/userApi";
import { DEFAULT_USE_YN, ynMap, ynOptions } from "@/lib/yn";
import {
  DEFAULT_APPR_LINE_CD,
  HEADER_PERSIST_ID,
  HEADER_RULES,
  ROLE_LABEL,
  SCRN_CD,
  SPLIT_KEY,
  STEP_PERSIST_ID,
  STEP_RULES,
  buildHeaderColumns,
  buildStepColumns,
  emptyLine,
  emptySteps,
  matchLine,
  normalizeSteps,
  stepsToPayload,
  type HeaderRow,
  type StepRow,
} from "./ApprovalLineManagementRule";

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 좌 결재선 30 · 우 단계 70 — 가로 분할은 30 또는 50만
 *   2) approval-line-management 에서 마운트한다
 *   3) 권한·검증 실패는 업무 토스트로만 안내한다
 */
export default function ApprovalLineManagementPage() {
  const canWrite = useAuthStore((state) => state.can(SCRN_CD, "write"));
  const canModify = useAuthStore((state) => state.can(SCRN_CD, "modify"));
  const canDelete = useAuthStore((state) => state.can(SCRN_CD, "delete"));
  const asyncAct = useAsyncAction();
  const openModal = useModalStore((s) => s.openModal);
  const sec = useSection();
  const editable = canWrite || canModify;
  const ynOpts = useMemo(() => ynOptions(), []);
  const ynLabels = useMemo(() => ynMap(), []);

  const [qCd, setQCd] = useState("");
  const [qNm, setQNm] = useState("");
  const [qUseYn, setQUseYn] = useState<string>(DEFAULT_USE_YN);
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [stepActiveKey, setStepActiveKey] = useState<string | null>(null);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  const [userRows, setUserRows] = useState<Array<{
    userId: string;
    userNm: string;
    deptCd?: string;
    deptNm?: string;
    // 권한그룹 — 승인 단계가 개설 관리자로 남아 있는지 알리는 데만 쓴다
    usrgrpCd?: string;
  }>>([]);

  const hg = useEditableRows<HeaderRow>("apprLineCd");
  const sg = useEditableRows<StepRow>("roleCd");
  const clearSel = () => { setSelKeys([]); setSelReset((n) => n + 1); };
  const grid = useGridAccess(HEADER_RULES, {
    scrnCd: SCRN_CD,
    gridRole: "single",
    readOnly: !editable,
    extra: { canWrite, canModify },
  });
  const stepGrid = useGridAccess(STEP_RULES, {
    scrnCd: SCRN_CD,
    gridRole: "single",
    readOnly: !editable,
    extra: { canWrite, canModify },
  });

  /**
   * 개발자: 박승우
   * 일자: 2026-08-19
   * 코멘트:
   *   1) 고른 결재선의 2단계를 오른쪽에 넣는다
   *   2) 좌측 행 선택·첫 로드·저장 후 유지에서 호출한다
   *   3) 선택이 없으면 빈 템플릿 2행을 깔지 않고 그리드를 비운다
   */
  const loadStepsFor = useCallback((line: HeaderRow | null) => {
    if (!line) {
      sg.load([]);
      setStepActiveKey(null);
      return;
    }
    const steps = normalizeSteps(line.steps);
    sg.load(steps.map((step) => ({ ...step, roleNm: ROLE_LABEL[step.roleCd] })));
    setStepActiveKey(null);
  // eslint-disable-next-line react-hooks/exhaustive-deps -- sg.load 안정 참조
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-19
   * 코멘트:
   *   1) 결재선 목록을 필터까지 적용해 가져온다
   *   2) 조회(load)·저장 후 선택 유지(reloadKeepSelection)에서 같이 쓴다
   *   3) 실패는 호출 쪽에서 토스트한다
   */
  const fetchHeaderRows = useCallback(async () => {
    const rows = await listApprovalLines();
    return rows
      .map((row) => ({ ...row, steps: normalizeSteps(row.steps) }))
      .filter((row) => matchLine(row, qCd, qNm, qUseYn));
  }, [qCd, qNm, qUseYn]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-19
   * 코멘트:
   *   1) 결재선 목록을 다시 읽고 첫 행을 고른 뒤 그 단계를 오른쪽에 넣는다
   *   2) 최초 진입·조회·삭제 재조회에서 호출한다 — 저장은 reloadKeepSelection
   *   3) 목록이 비면 우측은 정보가 없습니다. 실패하면 기존 행을 유지한다
   */
  const load = useCallback(async () => {
    try {
      const mapped = hg.loadReturn(await fetchHeaderRows());
      clearSel();
      const first = mapped[0] ?? null;
      setActiveKey(first?._key ?? null);
      loadStepsFor(first);
    } catch (error) {
      mesError(error);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- hg.loadReturn 안정 참조
  }, [fetchHeaderRows, loadStepsFor]);

  /*
   * 최초 한 번만 읽는다.
   *
   * load 의 의존에 검색 상태가 걸려 있어, 검색어를 한 글자 칠 때마다 목록을 다시 읽고
   * 저장 전 단계 편집까지 날아갔다. 선택도 첫 행으로 떨어졌다.
   * 조회는 조회 버튼이 한다.
   */
  // eslint-disable-next-line react-hooks/exhaustive-deps -- 최초 1회. 이후는 조회 버튼
  useEffect(() => { void load(); }, []);

  useEffect(() => {
    void (async () => {
      try {
        const users = await listUsers({ useYn: "Y" });
        setUserRows(users.map((row) => ({
          userId: String(row.userId ?? ""),
          userNm: String(row.userNm ?? row.userId ?? ""),
          deptCd: row.deptCd ? String(row.deptCd) : "",
          deptNm: row.deptNm ? String(row.deptNm) : "",
          // 권한그룹 — 승인 단계가 관리자로 남아 있는지 알리는 데만 쓴다(아래 adminIds)
          usrgrpCd: row.usrgrpCd ? String(row.usrgrpCd) : "",
        })));
      } catch (error) {
        mesError(error);
      }
    })();
  }, []);

  const activeHeader = useMemo(
    () => hg.rows.find((row) => row._key === activeKey) ?? null,
    [activeKey, hg.rows],
  );

  const dirty = hg.getSaveRows().length > 0 || sg.getSaveRows().length > 0;

  /*
   * 업체를 열면 기본 결재선(DEFAULT)의 승인자가 개설 관리자로 박힌 채 시작한다
   * (`db_sasshaccp/06_company_seed.sql`). 아무도 안 바꾸면 팀원이 쓴 일지가
   * 전부 관리자에게만 가고 팀장 결재대기는 0건으로 남는다 — 실제로 그렇게 굴러갔다.
   * 막지는 않는다. 담당자를 아직 안 정한 업체도 문서는 만들 수 있어야 한다. 다만 보이게 한다.
   */
  const adminIds = useMemo(
    () => new Set(userRows.filter((row) => row.usrgrpCd === "ADMIN").map((row) => row.userId)),
    [userRows],
  );
  // 승인 단계 결재자가 아직 관리자일 때(= 개설 직후 그대로) 안내 문구, 아니면 빈 값
  const approverWarn = useMemo(() => {
    const approve = sg.rows.find(
      (row) => String(row.roleCd ?? "") === "APPROVE" && String(row.useYn ?? "Y") !== "N",
    );
    if (!approve) return "";
    const id = String(approve.approverId ?? "");
    if (!id || !adminIds.has(id)) return "";
    return "승인자가 개설 관리자입니다. 실제 승인 담당자로 바꾸세요 — 그대로 두면 팀원이 올린 일지가 담당자에게 가지 않습니다.";
  }, [adminIds, sg.rows]);
  const dirtyRef = useRef(false);
  dirtyRef.current = dirty;
  useRegisterPageDirty(useCallback(() => dirtyRef.current, []));

  /**
   * 개발자: 박승우
   * 일자: 2026-08-19
   * 코멘트:
   *   1) 좌측 결재선을 고른다 — 미저장이면 이동 여부를 먼저 확인한다
   *   2) 좌측 그리드 행 클릭에서 호출한다
   *   3) 취소하면 선택·우측 단계를 바꾸지 않는다
   */
  const handleSelectHeader = async (row: HeaderRow) => {
    if (row._key === activeKey) return;
    if (dirty && !(await mesConfirm(MES.unsavedLeaveConfirm))) return;
    sec.setSec("h");
    setActiveKey(row._key ?? null);
    loadStepsFor(row);
  };

  const handleAdd = async () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    if (dirty && !(await mesConfirm(MES.unsavedLeaveConfirm))) return;
    sec.setSec("h");
    const created = emptyLine();
    const key = hg.addRow(created);
    setActiveKey(key ?? null);
    loadStepsFor(created);
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-19
   * 코멘트:
   *   1) 결재자 룩업 — 이름 옆에 부서를 붙여 찾고, 고르면 소속 부서를 넣는다
   *   2) 우측 결재자 셀 버튼에서 호출한다
   *   3) (없음)을 고르면 결재자·부서를 함께 비운다
   */
  const openApproverLookup = useCallback((row: StepRow) => {
    if (!editable || !row._key) return;
    const rowKey = row._key;
    setStepActiveKey(rowKey);
    sec.setSec("d");
    openModal("CodeLookup", {
      title: "결재자 선택",
      scrnCd: SCRN_CD,
      options: userRows.map((u) => ({
        value: u.userId,
        label: u.deptNm ? `${u.userNm} (${u.deptNm})` : u.userNm,
      })),
      value: String(row.approverId ?? ""),
      allowEmpty: true,
      onSelect: (code) => {
        if (!code) {
          sg.updateCell(rowKey, "approverId", null);
          sg.updateCell(rowKey, "approverNm", "");
          sg.updateCell(rowKey, "deptCd", null);
          sg.updateCell(rowKey, "deptNm", "");
          return;
        }
        const picked = userRows.find((u) => u.userId === code);
        sg.updateCell(rowKey, "approverId", code);
        sg.updateCell(rowKey, "approverNm", picked?.userNm ?? "");
        sg.updateCell(rowKey, "deptCd", picked?.deptCd || null);
        sg.updateCell(rowKey, "deptNm", picked?.deptNm ?? "");
      },
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps -- sg.updateCell 안정 참조
  }, [editable, openModal, userRows]);

  const headerColumns = useMemo(
    () => buildHeaderColumns(editable, ynOpts, ynLabels),
    [editable, ynLabels, ynOpts],
  );
  const stepColumns = useMemo(
    () => buildStepColumns(editable && !!activeKey, { onApproverLookup: openApproverLookup }, ynOpts, ynLabels),
    [activeKey, editable, openApproverLookup, ynLabels, ynOpts],
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-19
   * 코멘트:
   *   1) 활성 헤더와 우측 2단계를 한 번에 저장한다
   *   2) GridCrudButtons·셸 Ctrl+S에서 호출한다
   *   3) 성공 후 같은 결재선(apprLineCd)을 다시 고르고 우측 단계를 그 행으로 채운다
   */
  const handleSave = async () => {
    if (!editable) return mesToast("수정 권한이 없습니다.", "warn");
    const target = activeHeader
      ?? hg.rows.find((row) => row._rowState === "C" || row._rowState === "U")
      ?? null;
    if (!target) return mesToast(MES.selectRow, "warn");

    const stepDirty = sg.getSaveRows().length > 0;
    if (hg.getSaveRows().length === 0 && !stepDirty && target._rowState !== "C" && target._rowState !== "U") {
      return mesToast(MES.noChange, "warn");
    }
    const guard = guardSaveWithKey(grid.rules, grid.ctx, [target], headerColumns);
    if (guard) {
      mesToast(guard.message, "warn");
      if (guard.rowKey) setActiveKey(guard.rowKey);
      return;
    }
    if (!String(target.apprLineCd ?? "").trim() || !String(target.apprLineNm ?? "").trim()) {
      return mesToast("결재선 코드와 결재선명을 입력하세요.", "warn");
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;

    const stepSource = sg.rows.length > 0 ? sg.rows : emptySteps().map((s) => ({ ...s, roleNm: ROLE_LABEL[s.roleCd] }));
    try {
      const savedCd = String(target.apprLineCd).trim();
      await saveApprovalLine({
        apprLineCd: savedCd,
        apprLineNm: String(target.apprLineNm).trim(),
        useYn: (target.useYn as "Y" | "N") ?? "Y",
        /*
         * 신규 행인지 알려 준다 — 저장 SP 가 이걸로 업무키 중복을 막는다.
         *
         * 이 화면은 형제들과 달리 idx 를 안 주고받아서, 서버가 payload 만으로는
         * 「새 줄을 만드는 중」과 「기존 줄을 고치는 중」을 못 가른다. 그래서 UPSERT 가
         * 신규 행에 친 남의 코드까지 받아 그 결재선의 단계를 통째로 갈아 끼웠다.
         *
         * 저장이 끝나면 바로 아래 reloadKeepSelection 이 서버 값으로 갈아 끼워
         * _rowState 가 지워지므로, 같은 줄을 다시 고쳐 저장하면 "N" 으로 간다.
         * 그 재조회가 실패하면 _rowState 가 "C" 로 남아 다시 저장할 때
         * 「이미 등록된 결재선 코드입니다」가 뜬다 — 방금 만든 줄이 실제로 있으니 맞는 말이고,
         * 조회를 다시 하면 풀린다. 자료가 상하지는 않는다.
         */
        newYn: target._rowState === "C" ? "Y" : "N",
        steps: stepsToPayload(stepSource),
      });
      mesToast(MES.saveDone, "success");
      const kept = await hg.reloadKeepSelection(fetchHeaderRows, savedCd);
      setActiveKey(kept.key);
      loadStepsFor(kept.row);
      /*
       * 저장은 됐는데 **결재가 안 도는 결재선**을 알려 준다.
       *
       * 여기서 막지는 않는다 — 결재선은 두 걸음으로 만든다. 코드·명만 저장해 줄을 만들고
       * 그 줄을 골라 결재자를 넣는다. 첫 걸음에서 막으면 두 번째로 갈 방법이 없다.
       * 대신 아무 말도 안 하면 사람이 **눈으로 확인해야** 한다 — 세팅에서 가장 자주 놓치는 자리다.
       * 실제로 이 결재선을 문서주기에 걸 때는 문서주기 화면이 막는다.
       */
      const missing = stepsToPayload(stepSource).filter((step) =>
        step.useYn !== "N" && !String(step.approverId ?? "").trim(),
      );
      if (missing.length > 0) {
        mesToast("결재자를 아직 안 넣었습니다. 이 결재선으로는 결재가 가지 않습니다.", "warn");
      }
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-19
   * 코멘트:
   *   1) 선택행 우선 삭제 — validate-delete·확인·delete·재조회
   *   2) 왼쪽 GridCrudButtons·셸 삭제 단축키에서 호출한다
   *   3) 사용양식·문서 참조 중이면 업무 토스트만 표시한다
   */
  const handleDelete = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(hg.rows, activeKey, setActiveKey, selKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");
    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    const keys = persisted
      .map((row) => String(row.apprLineCd ?? "").trim())
      .filter(Boolean)
      .map((apprLineCd) => ({ apprLineCd }));
    if (keys.length === 0 && newRows.length === 0) {
      return mesToast(MES.selectRow, "warn");
    }
    if (keys.some((key) => key.apprLineCd.toUpperCase() === DEFAULT_APPR_LINE_CD)) {
      return mesToast("기본 결재선 'DEFAULT'은(는) 시스템 기본 설정이므로 삭제할 수 없습니다.", "warn");
    }
    try {
      if (keys.length > 0) await validateDeleteApprovalLines(keys);
      if (!(await mesConfirmDanger(MES.deleteConfirm()))) return;
      if (keys.length > 0) await deleteApprovalLines(keys);
      let lastFocus = activeKey;
      let lastRow: HeaderRow | null = null;
      for (const row of newRows) {
        if (!row._key) continue;
        const { focusKey, focusRow } = hg.removeNewRow(row._key);
        lastFocus = focusKey ?? null;
        lastRow = focusRow;
      }
      setActiveKey(lastFocus);
      clearSel();
      mesToast(MES.deleteDone, "success");
      if (keys.length > 0) await load();
      else loadStepsFor(lastRow);
    } catch (error) {
      mesError(error);
    }
  };

  const doSearch = () => asyncAct.run(async () => {
    sec.reset();
    await load();
  }, "search");

  usePageCommands({
    search: () => { void doSearch(); },
    add: () => { void handleAdd(); },
    save: () => { void asyncAct.run(handleSave, "save"); },
    del: () => { void asyncAct.run(handleDelete, "del"); },
  });

  const stepTitle = activeHeader
    ? `단계 (${activeHeader.apprLineNm || activeHeader.apprLineCd || "행추가"})`
    : "단계";

  return (
    <div className={pageRootClass}>
      <PageCard
        search={(
          <SearchArea
            onSearch={() => { void doSearch(); }}
            actions={(
              <SearchButton
                // 조회 busy 스피너
                loading={asyncAct.isBusy("search")}
              />
            )}
          >
            <SearchField label="결재선코드">
              <input
                // 결재선코드 부분검색 — FE 필터
                className={searchInputClass}
                value={qCd}
                onChange={(event) => setQCd(event.target.value)}
                placeholder="결재선코드"
              />
            </SearchField>
            <SearchField label="결재선명">
              <input
                // 결재선명 부분검색 — FE 필터
                className={searchInputClass}
                value={qNm}
                onChange={(event) => setQNm(event.target.value)}
                placeholder="결재선명"
              />
            </SearchField>
            <SearchSelect
              // 사용여부 — 기본 Y, 빈값=전체
              label="사용여부"
              value={qUseYn}
              onChange={setQUseYn}
            >
              <option value="">전체</option>
              {ynOpts.map((opt) => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </SearchSelect>
          </SearchArea>
        )}
      >
        <ResizableSplit
          // 좌 결재선 30 · 우 단계 70 — 가로 분할은 30 또는 50만
          orientation="horizontal"
          storageKey={SPLIT_KEY}
          defaultPrimaryPct={30}
          minPct={20}
          maxPct={80}
          className="mes-page-split min-h-0 h-full flex-1 gap-0"
          primary={(
            <div {...sec.bind("h", splitPanelClass)}>
              <div className={gridHeadClass}>
                <b>결재선</b>
                <GridCrudButtons
                  // useAsyncAction.run — busy 키 래핑
                  run={asyncAct.run}
                  // 좌측 전용 행추가 — 우측에 2단계가 바로 생긴다
                  onAdd={canWrite ? handleAdd : undefined}
                  // 헤더+단계 단건 저장
                  onSave={editable ? handleSave : undefined}
                  // 좌측 선택행 삭제 — 참조 중이면 차단
                  onDel={canDelete ? handleDelete : undefined}
                  busy={{
                    save: asyncAct.isBusy("save"),
                    del: asyncAct.isBusy("del"),
                  }}
                />
              </div>
              <MesEditableGrid
                // 열 설정 저장 키 — 결재선 헤더
                persistId={HEADER_PERSIST_ID}
                title="결재선"
                rows={hg.rows as EditableRow<HeaderRow>[]}
                columns={headerColumns}
                editable={editable}
                height="100%"
                loading={asyncAct.isBusy("search") || asyncAct.isBusy("save") || asyncAct.isBusy("del")}
                activeKey={activeKey}
                onActivate={(row) => { void handleSelectHeader(row); }}
                onCellChange={(key, field, value) => hg.updateCell(key, field as keyof HeaderRow, value)}
                access={grid.access}
                onLockedAttempt={grid.onLockedAttempt}
                onSetActive={() => sec.setSec("h")}
                selectable
                onSelectionChange={(rows) => setSelKeys(rows.map((row) => row._key))}
                selectionResetKey={selReset}
                showRowNum
              />
            </div>
          )}
          secondary={(
            <div {...sec.bind("d", splitPanelClass)}>
              <div className={gridHeadClass}>
                <b>{stepTitle}</b>
                <GridCrudButtons
                  // 우측은 고정 2단계 — 저장만. 결재자·사용여부 수정 후 바로 저장
                  run={asyncAct.run}
                  onSave={editable && activeKey ? handleSave : undefined}
                  // 개설 관리자가 승인자로 남아 있을 때 — 헤더에 안 깔고 저장 툴팁만
                  saveTitle={approverWarn || undefined}
                  busy={{
                    save: asyncAct.isBusy("save"),
                  }}
                />
              </div>
              <MesEditableGrid
                // 열 설정 저장 키 — 결재 단계 순서·역할·부서·결재자·사용
                persistId={STEP_PERSIST_ID}
                title={stepTitle}
                rows={sg.rows as EditableRow<StepRow>[]}
                columns={stepColumns}
                editable={editable && !!activeKey}
                height="100%"
                loading={asyncAct.isBusy("search") || asyncAct.isBusy("save") || asyncAct.isBusy("del")}
                activeKey={stepActiveKey}
                onActivate={(row) => {
                  sec.setSec("d");
                  setStepActiveKey(row._key);
                }}
                onCellChange={(key, field, value) => {
                  if (field === "useYn") {
                    mesToast("작성과 승인은 항상 사용입니다.", "warn");
                    return;
                  }
                  sg.updateCell(key, field as keyof StepRow, value);
                }}
                access={stepGrid.access}
                onLockedAttempt={stepGrid.onLockedAttempt}
                onSetActive={() => sec.setSec("d")}
                // 좌측 미선택·목록 0건일 때 빈 2단계 템플릿 대신 빈 화면
                emptyTitle={MES.noInfo}
                // 마스터를 고르라는 안내 — 조회 조건 힌트와 구분
                emptyHint="왼쪽에서 결재선을 선택하세요."
                showRowNum
              />
            </div>
          )}
        />
      </PageCard>
    </div>
  );
}
