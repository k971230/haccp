/**
 * CommonCodePage — 공통코드 대분류 + 시스템/사용자 세부 3그리드.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 좌 대분류(조회), 우상 시스템(조회 전용), 우하 사용자(CRUD)
 *   2) 상단 대분류코드·명·사용여부로 FE 필터 조회한다(사용 기본 Y)
 *   3) 컬럼·잠금 규칙은 CommonCodeRule이 갖고 이 파일은 렌더·상태·API만 담당한다
 *
 * PIPELINE[HF99] 공통코드 관리
 */
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useGridAccess } from "@/hooks/useGridAccess";
import { useEditableRows } from "@/hooks/useEditableRows";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
import { PageCard, PageCardSplit } from "@/components/layout/PageCard";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import {
  SearchArea,
  SearchButton,
  SearchField,
  SearchSelect,
} from "@/components/layout/SearchArea";
import { gridHeadClass, pageRootClass } from "@/components/layout/pageClasses";
import { searchInputClass } from "@/components/ui/Input";
import { DEFAULT_USE_YN, ynMap, ynOptions } from "@/lib/yn";
import { mesConfirm, mesConfirmDanger, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { usePageCommands } from "@/shell/pageCommands";
import { guardSaveWithKey } from "@/shell/gridRules";
import { resolveRowsForDelete } from "@/shell/resolveDelete";
import type { EditableRow } from "@/types/editable";
// 역할 — 공통코드 도메인 API
import {
  deleteCommonCodes,
  listCodeDetails,
  listCodeGroups,
  saveCommonCodes,
  validateDeleteCommonCodes,
} from "@/api/sys/commonCodeApi";
import type { CodeManageRow } from "@/api/sys/sysTypes";
// 역할 — 화면 규칙(컬럼·잠금·초기값·pref 키)
import {
  GROUP_RULES,
  PERSIST_ID,
  SCRN_CD,
  SYS_RULES,
  USR_REQUIRED_LABEL,
  USR_RULES,
  buildGroupColumns,
  buildSysColumns,
  buildUsrColumns,
  matchGroup,
  newUsrRow,
  type CodeRow,
} from "./CommonCodeRule";

/** 저장 payload 정리 — 편집 메타(_key·_rowState·_original) 제거 */
function stripMeta(row: CodeRow): CodeManageRow {
  const { _key: _k, _rowState: _rs, _original: _o, ...rest } = row;
  return rest as CodeManageRow;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 공통코드 3그리드를 조회·저장한다
 *   2) common-code-management 화면에서 마운트한다
 *   3) 권한·검증 실패는 업무 토스트
 */
export default function CommonCodePage() {
  const canWrite = useAuthStore((s) => s.can(SCRN_CD, "write"));
  const canModify = useAuthStore((s) => s.can(SCRN_CD, "modify"));
  const canDelete = useAuthStore((s) => s.can(SCRN_CD, "delete"));
  const asyncAct = useAsyncAction();

  const groups = useEditableRows<CodeRow>("idx");
  const sysG = useEditableRows<CodeRow>("idx");
  const usrG = useEditableRows<CodeRow>("idx");
  // 대분류 전건 보관 — 헤더 검색은 서버 왕복 없이 이 목록을 거른다
  const allGroupsRef = useRef<CodeManageRow[]>([]);

  const groupGrid = useGridAccess(GROUP_RULES, {
    scrnCd: SCRN_CD,
    gridRole: "single",
    readOnly: true,
  });
  const sysGrid = useGridAccess(SYS_RULES, {
    scrnCd: SCRN_CD,
    gridRole: "single",
    readOnly: true,
  });
  const usrGrid = useGridAccess(USR_RULES, {
    scrnCd: SCRN_CD,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });

  const [qMainCd, setQMainCd] = useState("");
  const [qCodeNm, setQCodeNm] = useState("");
  const [qUseYn, setQUseYn] = useState<string>(DEFAULT_USE_YN);
  const [groupKey, setGroupKey] = useState<string | null>(null);
  const [sysKey, setSysKey] = useState<string | null>(null);
  const [usrKey, setUsrKey] = useState<string | null>(null);
  const [usrSel, setUsrSel] = useState<string[]>([]);
  const [usrSelReset, setUsrSelReset] = useState(0);

  const activeGroup = groups.rows.find((r) => r._key === groupKey);
  const mainCd = String(activeGroup?.mainCd ?? "").trim();
  const ynOpts = useMemo(() => ynOptions(), []);
  const ynLabels = useMemo(() => ynMap(), []);

  const groupCols = useMemo(() => buildGroupColumns(ynOpts, ynLabels), [ynLabels, ynOpts]);
  const sysCols = useMemo(() => buildSysColumns(ynOpts, ynLabels), [ynLabels, ynOpts]);
  const usrCols = useMemo(
    () => buildUsrColumns(canWrite || canModify, ynOpts, ynLabels),
    [canModify, canWrite, ynLabels, ynOpts],
  );

  const applyGroupFilter = useCallback(() => {
    const filtered = allGroupsRef.current.filter((r) =>
      matchGroup(r, qMainCd, qCodeNm, qUseYn),
    );
    groups.load(filtered.map((r) => ({ ...r })) as CodeRow[]);
    setGroupKey(null);
    sysG.load([]);
    usrG.load([]);
    setSysKey(null);
    setUsrKey(null);
    setUsrSel([]);
    setUsrSelReset((n) => n + 1);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [qCodeNm, qMainCd, qUseYn]);

  const loadGroups = useCallback(async () => {
    const rows = await listCodeGroups();
    allGroupsRef.current = rows;
    applyGroupFilter();
  }, [applyGroupFilter]);

  const loadDetails = useCallback(async (cd: string) => {
    if (!cd) {
      sysG.load([]);
      usrG.load([]);
      return;
    }
    const [sysRows, usrRows] = await Promise.all([
      listCodeDetails(cd, "Y"),
      listCodeDetails(cd, "N"),
    ]);
    sysG.load(sysRows.map((r) => ({ ...r })) as CodeRow[]);
    usrG.load(usrRows.map((r) => ({ ...r })) as CodeRow[]);
    setSysKey(null);
    setUsrKey(null);
    setUsrSel([]);
    setUsrSelReset((n) => n + 1);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    void asyncAct.run(async () => {
      try {
        await loadGroups();
      } catch (e) {
        mesError(e);
      }
    }, "search");
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!mainCd) return;
    void asyncAct.run(async () => {
      try {
        await loadDetails(mainCd);
      } catch (e) {
        mesError(e);
      }
    }, "detail");
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mainCd]);

  const handleAddUsr = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    if (!mainCd) return mesToast("대분류를 먼저 선택하세요.", "warn");
    // 행추가 시 이전 체크 해제
    setUsrSel([]);
    setUsrSelReset((n) => n + 1);
    setUsrKey(usrG.addRow(newUsrRow(mainCd)));
  };

  const handleSaveUsr = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    const dirty = usrG.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    const guard = guardSaveWithKey(usrGrid.rules, usrGrid.ctx, dirty, usrCols);
    if (guard) {
      mesToast(guard.message, "warn");
      if (guard.rowKey) setUsrKey(guard.rowKey);
      return;
    }
    for (const row of dirty) {
      if (!String(row.subCd ?? "").trim() || !String(row.codeNm ?? "").trim()) {
        mesToast(MES.required(USR_REQUIRED_LABEL), "warn");
        setUsrKey(row._key);
        return;
      }
      row.mainCd = mainCd;
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      await saveCommonCodes(dirty.map(stripMeta));
      mesToast(MES.saveDone, "success");
      await loadDetails(mainCd);
    } catch (e) {
      mesError(e);
    }
  };

  const handleDeleteUsr = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(usrG.rows, usrKey, setUsrKey, usrSel);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");
    const keys = targets
      .filter((r) => r._rowState !== "C" && r.idx != null)
      .map((r) => ({ idx: Number(r.idx) }));
    const localOnly = targets.filter((r) => r._rowState === "C");
    if (keys.length === 0 && localOnly.length === 0) return mesToast(MES.selectRow, "warn");
    try {
      if (keys.length > 0) await validateDeleteCommonCodes(keys);
      if (!(await mesConfirmDanger(MES.deleteConfirm()))) return;
      if (keys.length > 0) await deleteCommonCodes(keys);
      // 체크된 신규행만 로컬 제거 — 나머지 미저장 행추가분은 유지
      let lastFocus = usrKey;
      for (const r of localOnly) {
        const { focusKey } = usrG.removeNewRow(r._key!);
        lastFocus = focusKey;
      }
      setUsrKey(lastFocus);
      setUsrSel([]);
      setUsrSelReset((n) => n + 1);
      mesToast(MES.deleteDone, "success");
      // 서버 행 삭제 시에만 재조회 — 신규만 지우면 load 시 남은 행추가가 전부 사라짐
      if (keys.length > 0) await loadDetails(mainCd);
    } catch (e) {
      mesError(e);
    }
  };

  const runSearch = () => {
    void asyncAct.run(async () => {
      try {
        if (allGroupsRef.current.length === 0) await loadGroups();
        else applyGroupFilter();
      } catch (e) {
        mesError(e);
      }
    }, "search");
  };

  usePageCommands({
    search: runSearch,
    add: canWrite ? handleAddUsr : undefined,
    save: canWrite || canModify
      ? () => { void asyncAct.run(handleSaveUsr, "save"); }
      : undefined,
    del: canDelete ? () => { void asyncAct.run(handleDeleteUsr, "del"); } : undefined,
  });

  return (
    <div className={pageRootClass}>
      <PageCard
        search={
          <SearchArea
            onSearch={runSearch}
            actions={<SearchButton loading={asyncAct.isBusy("search")} />}
          >
            <SearchField label="대분류코드">
              <input
                // 대분류코드 부분검색
                className={searchInputClass}
                value={qMainCd}
                onChange={(e) => setQMainCd(e.target.value)}
                placeholder="대분류코드"
              />
            </SearchField>
            <SearchField label="대분류명">
              <input
                // 대분류명 부분검색
                className={searchInputClass}
                value={qCodeNm}
                onChange={(e) => setQCodeNm(e.target.value)}
                placeholder="대분류명"
              />
            </SearchField>
            <SearchSelect
              // 사용여부 — 기본 Y, 빈값=전체
              label="사용여부"
              value={qUseYn}
              onChange={setQUseYn}
            >
              <option value="">전체</option>
              {ynOpts.map((o) => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </SearchSelect>
          </SearchArea>
        }
      >
        <ResizableSplit
          // 좌 대분류 · 우 시스템/사용자
          orientation="horizontal"
          storageKey="haccp-split-common-code"
          defaultPrimaryPct={40}
          minPct={25}
          maxPct={70}
          primary={
            <div className="flex min-h-0 h-full flex-1 flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm p-2">
              <div className={gridHeadClass}>
                <b>대분류</b>
              </div>
              <MesEditableGrid
                // 열 설정 저장 키 — 공통코드 대분류
                persistId={PERSIST_ID.group}
                title="대분류"
                scrnCd={SCRN_CD}
                // 필터된 대분류(sub_cd=*) 행
                rows={groups.rows as EditableRow<CodeRow>[]}
                columns={groupCols}
                // 대분류는 선택만
                editable={false}
                height="100%"
                loading={asyncAct.isBusy("search")}
                activeKey={groupKey}
                onActivate={(row) => setGroupKey(row._key)}
                onCellChange={() => undefined}
                access={groupGrid.access}
                onLockedAttempt={groupGrid.onLockedAttempt}
                showRowNum
              />
            </div>
          }
          secondary={
            <PageCardSplit storageKey="haccp-split-common-code-detail">
              <div className="flex min-h-0 flex-1 flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm p-2">
                <div className={gridHeadClass}>
                  <b>시스템 코드{mainCd ? ` — ${mainCd}` : ""}</b>
                </div>
                <MesEditableGrid
                  // 열 설정 저장 키 — 시스템 세부(조회 전용)
                  persistId={PERSIST_ID.sys}
                  title="시스템 코드"
                  scrnCd={SCRN_CD}
                  rows={sysG.rows as EditableRow<CodeRow>[]}
                  columns={sysCols}
                  // 시스템 코드 CUD 불가
                  editable={false}
                  height="100%"
                  loading={asyncAct.isBusy("detail")}
                  activeKey={sysKey}
                  onActivate={(row) => setSysKey(row._key)}
                  onCellChange={() => undefined}
                  access={sysGrid.access}
                  onLockedAttempt={sysGrid.onLockedAttempt}
                  showRowNum
                />
              </div>

              <div className="flex min-h-0 flex-1 flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm p-2">
                <div className={gridHeadClass}>
                  <b>사용자 코드{mainCd ? ` — ${mainCd}` : ""}</b>
                  <GridCrudButtons
                    run={asyncAct.run}
                    onAdd={canWrite ? handleAddUsr : undefined}
                    onSave={canWrite || canModify ? handleSaveUsr : undefined}
                    onDel={canDelete ? handleDeleteUsr : undefined}
                    busy={{
                      save: asyncAct.isBusy("save"),
                      del: asyncAct.isBusy("del"),
                    }}
                  />
                </div>
                <MesEditableGrid
                  // 열 설정 저장 키 — 사용자 세부(CRUD)
                  persistId={PERSIST_ID.usr}
                  title="사용자 코드"
                  scrnCd={SCRN_CD}
                  rows={usrG.rows as EditableRow<CodeRow>[]}
                  columns={usrCols}
                  editable={canWrite || canModify}
                  height="100%"
                  loading={asyncAct.isBusy("detail") || asyncAct.isBusy("save") || asyncAct.isBusy("del")}
                  activeKey={usrKey}
                  onActivate={(row) => setUsrKey(row._key)}
                  onCellChange={(key, field, value) => usrG.updateCell(key, field as keyof CodeRow, value)}
                  access={usrGrid.access}
                  onLockedAttempt={usrGrid.onLockedAttempt}
                  selectable
                  onSelectionChange={(rows) => setUsrSel(rows.map((r) => r._key))}
                  selectionResetKey={usrSelReset}
                  showRowNum
                />
              </div>
            </PageCardSplit>
          }
        />
      </PageCard>
    </div>
  );
}
