/**
 * HtmlFormTemplatePage — HTML 양식 원본 공통 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 5개 HTML양식 원본이 같은 좌우 50:50 프레임을 쓴다. 지면 HTML 은 화면별 Paper
 *   2) 화면별 양식코드 접두·제목·scrnCd·지면 컴포넌트만 config로 받는다
 *   3) 표준은 수정 불가. 자사 양식은 행추가로만 만든다
 *
 * PIPELINE[HF130] HTML양식 원본 공통 화면
 */
// 역할 — 상태
import { useCallback, useEffect, useMemo, useRef, useState, type ComponentType } from "react";
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { usePageCommands } from "@/shell/pageCommands";
import { mesConfirm, mesConfirmDanger, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { MesButton } from "@/components/ui/MesButton";
import { searchInputClass } from "@/components/ui/Input";
import { PageCard } from "@/components/layout/PageCard";
import { SearchArea, SearchButton, SearchField } from "@/components/layout/SearchArea";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import { gridHeadClass, pageRootClass, splitPanelClass } from "@/components/layout/pageClasses";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
import { useGridAccess } from "@/hooks/useGridAccess";
import { SYS_YN_MAIN_CD, useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — 사용여부 Y/N 정규화·콤보 fallback
import { toYn, ynOptions } from "@/lib/yn";
import type { EditableRow } from "@/types/editable";
import type { HtmlFormPaperProps } from "@/components/form/htmlFormPaperShared";
import type { HtmlFormItem } from "@/api/docs/htmlFormApi";
import {
  copyHtmlFormVersion,
  deleteHtmlFormVersions,
  listHtmlFormItems,
  listHtmlFormVersions,
  saveHtmlFormItems,
  updateHtmlFormVerNm,
  validateDeleteHtmlFormVersions,
} from "@/api/docs/htmlFormApi";
import {
  PENDING_KEY,
  PENDING_VER_NO,
  buildListColumns,
  htmlFormListGridRules,
  isPendingRow,
  isStdVerRow,
  verRowKey,
  type VerListRow,
} from "./htmlFormTemplateShared";

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 서버에서 읽은 양식명·사용여부를 스냅샷한다
 *   2) 목록 재조회 후 셀만 바뀌었는지 비교한다
 *   3) pending은 호출하지 않는다
 */
function withSaved(row: VerListRow): VerListRow {
  return { ...row, savedVerNm: row.verNm, savedUseYn: toYn(row.useYn) };
}

export interface HtmlFormTemplatePageProps {
  // 화면코드 — tbl_screen.scrn_cd
  scrnCd: string;
  // 그리드 열 저장 키
  persistId: string;
  // 분할 비율 저장 키
  splitKey: string;
  // 예시 양식코드 — html_hyg_prc_000 / tml_ccp_chk_000 / tml_ccp_pkg_000 / tml_ccp_htg_000 / tml_ccp_mtl_000
  stdTmplCd: string;
  // 지면 제목
  paperTitle: string;
  // 지면 부제
  paperSubtitle: string;
  // pending 양식코드 제안
  nextTmplCd: (rows: Array<{ tmplCd?: string | null }>) => string;
  // 우측 지면 — 화면마다 다른 HTML Paper. 기본 양식 재사용 금지
  PaperComponent: ComponentType<HtmlFormPaperProps>;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 양식 그리드와 지면을 한 화면에서 본다. 기본 분할은 좌우 50:50
 *   2) HTML양식 원본 하위 메뉴가 config와 Paper 만 바꿔 연다
 *   3) 표준은 수정 버튼이 없다. 자사는 행추가로만 만든다
 */
export function HtmlFormTemplatePage({
  scrnCd,
  persistId,
  splitKey,
  stdTmplCd,
  paperTitle,
  paperSubtitle,
  nextTmplCd,
  PaperComponent,
}: HtmlFormTemplatePageProps) {
  const canWrite = useAuthStore((s) => s.can(scrnCd, "write"));
  const canModify = useAuthStore((s) => s.can(scrnCd, "modify"));
  const canDeleteAuth = useAuthStore((s) => s.can(scrnCd, "delete"));
  const canEdit = canWrite || canModify;
  const action = useAsyncAction();
  const sysYnCodes = useCommonCodes(SYS_YN_MAIN_CD);
  const useCodes = useCommonCodes("use-yn");
  const useOpts = useMemo(
    () => (useCodes.codes.length
      ? useCodes.codes.map((code) => ({ value: String(code.subCd).toUpperCase(), label: code.codeNm }))
      : ynOptions()),
    [useCodes.codes],
  );
  const listRules = useMemo(() => htmlFormListGridRules(stdTmplCd), [stdTmplCd]);
  const listGrid = useGridAccess(listRules, {
    scrnCd,
    gridRole: "single",
    readOnly: !canEdit,
    extra: { canWrite: canEdit, canModify, canDelete: canDeleteAuth },
  });

  const [qTmplCd, setQTmplCd] = useState("");
  const [qVerNm, setQVerNm] = useState("");
  const searchRef = useRef({ qTmplCd, qVerNm });
  searchRef.current = { qTmplCd, qVerNm };

  const [versions, setVersions] = useState<VerListRow[]>([]);
  const versionsRef = useRef(versions);
  versionsRef.current = versions;
  const [activeTmplCd, setActiveTmplCd] = useState(stdTmplCd);
  const [items, setItems] = useState<HtmlFormItem[]>([]);
  const [pendingItems, setPendingItems] = useState<HtmlFormItem[] | null>(null);
  const [editing, setEditing] = useState(false);
  const [listLoading, setListLoading] = useState(false);

  const visibleVersions = useMemo(() => {
    const cd = qTmplCd.trim().toLowerCase();
    const nm = qVerNm.trim().toLowerCase();
    return versions.filter((row) => {
      if (isPendingRow(row)) return true;
      if (cd && !(row.tmplCd || "").toLowerCase().includes(cd)) return false;
      if (nm && !(row.verNm || "").toLowerCase().includes(nm)) return false;
      return true;
    });
  }, [versions, qTmplCd, qVerNm]);

  const listRows = useMemo<EditableRow<VerListRow>[]>(
    () => visibleVersions.map((row) => ({
      ...row,
      _key: verRowKey(row),
      _rowState: row._rowState,
    })),
    [visibleVersions],
  );
  const listCols = useMemo(
    () => buildListColumns(canEdit, sysYnCodes.codeMap, useOpts),
    [canEdit, sysYnCodes.codeMap, useOpts],
  );
  const active = versions.find((v) => verRowKey(v) === activeTmplCd)
    ?? versions.find((v) => v.tmplCd === activeTmplCd)
    ?? versions[0];
  const pending = isPendingRow(active);
  const locked = isStdVerRow(active, stdTmplCd) || pending;
  const paperEditing = editing && !locked && canEdit;
  const canEditPaper = canEdit && !locked && !pending;
  const activeKey = active ? verRowKey(active) : activeTmplCd;

  /**
   * 개발자: 박승우
   * 일자: 2026-08-20
   * 코멘트:
   *   1) 양식 목록을 다시 읽는다. tmplCd로 가족(공정점검/CCP)을 가른다
   *   2) 진입·좌 저장·삭제·조회 후 호출한다
   *   3) keepTmpl이 있으면 그 행을 유지
   */
  const loadVersions = useCallback(async (keepTmpl?: string, keepPending = true) => {
    setListLoading(true);
    try {
      const q = searchRef.current;
      const rows = (await listHtmlFormVersions({
        tmplCd: stdTmplCd,
        verCd: q.qTmplCd,
        verNm: q.qVerNm,
      })).map(withSaved);
      const draft = keepPending ? versionsRef.current.find((r) => r._rowState === "C") : undefined;
      const next = draft ? [...rows, draft] : rows;
      setVersions(next);
      const nextTmpl = keepTmpl && next.some((r) => (isPendingRow(r) ? PENDING_KEY : r.tmplCd) === keepTmpl)
        ? keepTmpl
        : (next[0]?.tmplCd ?? stdTmplCd);
      setActiveTmplCd(isPendingRow(next.find((r) => r.tmplCd === nextTmpl) ?? null) ? PENDING_KEY : nextTmpl);
      return nextTmpl;
    } finally {
      setListLoading(false);
    }
  }, [stdTmplCd]);

  const loadItems = useCallback(async (tmplCd: string) => {
    if (tmplCd === PENDING_KEY) {
      setItems(pendingItems ?? []);
      return;
    }
    const std = tmplCd === stdTmplCd;
    setItems(await listHtmlFormItems(std ? stdTmplCd : tmplCd, std ? 0 : 1));
  }, [pendingItems, stdTmplCd]);

  useEffect(() => {
    void action.run(async () => {
      const tmpl = await loadVersions();
      await loadItems(tmpl);
    }, "search");
    // 최초 1회
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-21
   * 코멘트:
   *   1) pending·양식명·사용여부·지면 수정 중이면 미저장이다
   *   2) 행 전환 확인에서 호출한다. 문서주기와 같은 문구
   *   3) 스냅샷은 목록 행. 지면은 editing 플래그
   */
  const hasUnsaved = (): boolean => {
    if (editing) return true;
    return versionsRef.current.some((row) => (
      row._rowState === "C"
      || (
        !isStdVerRow(row, stdTmplCd)
        && (
          (row.verNm || "").trim() !== (row.savedVerNm || "").trim()
          || toYn(row.useYn) !== toYn(row.savedUseYn)
        )
      )
    ));
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-20
   * 코멘트:
   *   1) 그리드 행 클릭은 조회만 한다
   *   2) pending이면 서버 호출 없이 미리보기 항목을 되돌린다
   *   3) 미저장이면 문서주기와 같이 확인한다. 취소면 행을 바꾸지 않는다
   */
  const viewTmpl = (tmplCd: string) => action.run(async () => {
    if (tmplCd === activeTmplCd) return;
    if (hasUnsaved() && !(await mesConfirm(MES.unsavedLeaveConfirm))) return;
    try {
      setEditing(false);
      setActiveTmplCd(tmplCd);
      if (tmplCd === PENDING_KEY) {
        setItems(pendingItems ?? []);
        return;
      }
      await loadItems(tmplCd);
    } catch (error) {
      mesError(error);
    }
  }, "search");

  const findPending = () => versionsRef.current.find((r) => r._rowState === "C");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-20
   * 코멘트:
   *   1) 표준 항목을 복사한 pending 행을 붙인다
   *   2) 행추가 버튼이 호출한다. 양식명은 입력, 코드는 제안만
   *   3) 이미 pending이면 토스트. DB에는 안 쓴다
   */
  const handleAdd = () => action.run(async () => {
    if (!canWrite) {
      mesToast("행추가 권한이 없습니다.", "warn");
      return;
    }
    if (findPending()) {
      mesToast("작성 중인 양식이 있습니다. 저장하거나 삭제하세요.", "warn");
      return;
    }
    try {
      const std = await listHtmlFormItems(stdTmplCd, 0);
      const tmplCd = nextTmplCd(versionsRef.current);
      const row: VerListRow = {
        idx: null,
        tmplCd,
        verNo: PENDING_VER_NO,
        verCd: tmplCd,
        verNm: "",
        sysYn: "usr",
        applyYn: "N",
        useYn: "Y",
        savedVerNm: "",
        savedUseYn: "Y",
        lockedYn: "N",
        insNm: "",
        insDt: "",
        srcVerNo: 0,
        _rowState: "C",
      };
      setVersions((prev) => [...prev, row]);
      setPendingItems(std);
      setItems(std);
      setActiveTmplCd(PENDING_KEY);
      setEditing(false);
    } catch (error) {
      mesError(error);
    }
  }, "add");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-20
   * 코멘트:
   *   1) pending copy와 바뀐 양식명·사용여부를 커밋한다
   *   2) 좌측 저장이 호출한다. 하나 실패 시 중단
   *   3) 성공 시 pending 해제, 그 행 선택. 사용여부는 회사 양식
   */
  const handleCommit = async () => {
    if (!canEdit) {
      mesToast("저장 권한이 없습니다.", "warn");
      return;
    }
    const draft = findPending();
    const dirty = versionsRef.current.filter((r) => (
      r._rowState !== "C"
      && !isStdVerRow(r, stdTmplCd)
      && (
        (r.verNm || "").trim() !== (r.savedVerNm || "").trim()
        || toYn(r.useYn) !== toYn(r.savedUseYn)
      )
    ));
    if (dirty.some((r) => !(r.verNm || "").trim())) {
      mesToast("양식명은 필수입니다.", "warn");
      return;
    }
    if (!draft && dirty.length === 0) {
      mesToast("저장할 변경이 없습니다.", "warn");
      return;
    }
    let copied = false;
    let keepTmpl = activeTmplCd === PENDING_KEY ? stdTmplCd : activeTmplCd;
    try {
      if (draft) {
        if (!(draft.verNm || "").trim()) {
          mesToast("양식명은 필수입니다.", "warn");
          return;
        }
        keepTmpl = await copyHtmlFormVersion({
          tmplCd: stdTmplCd,
          verNm: draft.verNm.trim(),
        });
        if (!keepTmpl) {
          mesToast("복사한 양식을 찾을 수 없습니다.", "warn");
          return;
        }
        copied = true;
        // 복사는 사용 Y. pending에서 N이면 회사 양식만 내린다
        if (toYn(draft.useYn) === "N") {
          await updateHtmlFormVerNm({
            tmplCd: keepTmpl,
            verNo: 1,
            verNm: draft.verNm.trim(),
            useYn: "N",
          });
        }
        setVersions((prev) => prev.filter((r) => r._rowState !== "C"));
        setPendingItems(null);
      }
      for (const row of dirty) {
        await updateHtmlFormVerNm({
          tmplCd: row.tmplCd,
          verNo: row.verNo,
          verNm: row.verNm.trim(),
          useYn: toYn(row.useYn),
        });
      }
      const tmpl = await loadVersions(keepTmpl, false);
      if (copied) {
        setEditing(false);
        await loadItems(tmpl);
      }
      mesToast(MES.saveDone, "success");
    } catch (error) {
      mesError(error);
      if (!copied) return;
      try {
        const tmpl = await loadVersions(keepTmpl, false);
        setPendingItems(null);
        setEditing(false);
        await loadItems(tmpl);
      } catch (reloadErr) {
        mesError(reloadErr);
      }
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-20
   * 코멘트:
   *   1) 자사 양식 항목만 PUT 한다
   *   2) 우측 저장이 호출한다. 좌 저장과 분리
   *   3) 표준·pending이면 거부
   */
  const handleSaveItems = () => action.run(async () => {
    if (locked || pending || !active) {
      mesToast("표준 항목은 수정할 수 없습니다.", "warn");
      return;
    }
    try {
      await saveHtmlFormItems(active.verNo, items, active.tmplCd);
      setEditing(false);
      await loadItems(active.tmplCd);
      mesToast(MES.saveDone, "success");
    } catch (error) {
      mesError(error);
    }
  }, "items");

  const handleCancel = () => action.run(async () => {
    try {
      await loadItems(activeTmplCd);
      setEditing(false);
    } catch (error) {
      mesError(error);
    }
  }, "search");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-20
   * 코멘트:
   *   1) pending은 로컬 행만 제거. 저장행은 validate-delete 후 소프트 삭제
   *   2) 삭제 버튼이 호출한다
   *   3) 표준은 막는다
   */
  const handleDelete = async () => {
    if (!canDeleteAuth) {
      mesToast("삭제 권한이 없습니다.", "warn");
      return;
    }
    if (!active) return;
    if (isPendingRow(active)) {
      const rest = versionsRef.current.filter((r) => r._rowState !== "C");
      setVersions(rest);
      setPendingItems(null);
      setEditing(false);
      const next = rest[0]?.tmplCd ?? stdTmplCd;
      setActiveTmplCd(next);
      try {
        await loadItems(next);
      } catch (error) {
        mesError(error);
      }
      return;
    }
    if (locked || isStdVerRow(active, stdTmplCd)) {
      mesToast("표준 양식은 삭제할 수 없습니다.", "warn");
      return;
    }
    try {
      const keys = [{ tmplCd: active.tmplCd, verNo: active.verNo }];
      await validateDeleteHtmlFormVersions(keys);
      const ok = await mesConfirmDanger("선택한 양식을 삭제할까요?");
      if (!ok) return;
      await deleteHtmlFormVersions(keys);
      setEditing(false);
      const tmpl = await loadVersions();
      await loadItems(tmpl);
      mesToast(MES.deleteDone, "success");
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-20
   * 코멘트:
   *   1) 자사 양식명·사용여부만 셀에서 고친다. 표준은 무시
   *   2) 양식코드·구분은 잠금
   *   3) 셀 편집 후 그리드가 호출한다
   */
  const handleCellChange = (key: string, field: string, value: unknown) => {
    const row = listRows.find((r) => r._key === key);
    if (!row) return;
    if (field !== "verNm" && field !== "useYn") return;
    if (isStdVerRow(row, stdTmplCd)) return;
    setVersions((prev) => prev.map((v) => {
      if (verRowKey(v) !== key) return v;
      if (field === "useYn") return { ...v, useYn: toYn(value) };
      return { ...v, verNm: String(value ?? "") };
    }));
  };

  usePageCommands({
    search: () => {
      void action.run(async () => {
        const tmpl = await loadVersions(activeTmplCd);
        if (tmpl !== PENDING_KEY) await loadItems(tmpl);
        setEditing(false);
      }, "search");
    },
    add: () => { void handleAdd(); },
    save: () => { void action.run(async () => { await handleCommit(); }, "save"); },
    del: () => { void action.run(async () => { await handleDelete(); }, "del"); },
  });

  return (
    <div className={pageRootClass}>
      <PageCard
        search={(
          <SearchArea
            onSearch={() => {
              void action.run(async () => {
                const tmpl = await loadVersions(activeTmplCd);
                if (tmpl !== PENDING_KEY) await loadItems(tmpl);
              }, "search");
            }}
            actions={<SearchButton loading={listLoading || action.isBusy("search")} />}
          >
            <SearchField label="양식코드">
              <input
                // 양식코드 부분검색 — 입력 즉시 클라이언트 필터. 조회는 서버 LIKE
                className={searchInputClass}
                value={qTmplCd}
                placeholder="양식코드"
                onChange={(event) => setQTmplCd(event.target.value)}
              />
            </SearchField>
            <SearchField label="양식명">
              <input
                // 양식명 부분검색 — 입력 즉시 클라이언트 필터. 조회는 서버 LIKE
                className={searchInputClass}
                value={qVerNm}
                placeholder="양식명"
                onChange={(event) => setQVerNm(event.target.value)}
              />
            </SearchField>
          </SearchArea>
        )}
      >
        <ResizableSplit
          // 좌 양식 그리드 50 · 우 지면 50 — 문서주기와 같은 프레임
          orientation="horizontal"
          storageKey={splitKey}
          defaultPrimaryPct={50}
          minPct={25}
          maxPct={75}
          className="mes-page-split min-h-0 h-full flex-1 gap-0"
          primary={(
            <div className={splitPanelClass}>
              <div className={gridHeadClass}>
                <div className="flex min-w-0 items-center gap-2">
                  <b>양식</b>
                </div>
                <div className="ml-auto flex shrink-0 items-center gap-1.5">
                  <GridCrudButtons
                    // 행추가=표준 복사 pending. 저장=copy·이름. 삭제
                    run={action.run}
                    onAdd={handleAdd}
                    onSave={handleCommit}
                    onDel={handleDelete}
                    busy={{
                      add: action.isBusy("add"),
                      save: action.isBusy("save"),
                      del: action.isBusy("del"),
                    }}
                  />
                </div>
              </div>
              <MesEditableGrid
                // 열 너비 저장 키
                persistId={persistId}
                // 권한·pref 범위
                scrnCd={scrnCd}
                // 예시 + 자사 양식 + pending
                rows={listRows}
                // 양식코드·양식명·구분·사용여부·작성자·작성일시. field 코드는 화면이 같다
                columns={listCols}
                // 사용자 양식명
                editable={canEdit}
                // 패널 제목
                title="양식"
                // 부모 flex 높이
                height="100%"
                loading={listLoading}
                // 조회 중인 양식
                activeKey={activeKey}
                // 행 클릭 = 조회. pending은 로컬 미리보기
                onActivate={(row) => {
                  void viewTmpl(row._key === PENDING_KEY ? PENDING_KEY : String(row.tmplCd ?? ""));
                }}
                onCellChange={handleCellChange}
                access={listGrid.access}
                onLockedAttempt={listGrid.onLockedAttempt}
                showRowNum
                showFooter={false}
              />
            </div>
          )}
          secondary={(
            <div className={splitPanelClass}>
              <div className={gridHeadClass}>
                <div className="flex min-w-0 items-center gap-2 overflow-hidden">
                  <b className="truncate">{active?.verNm || paperTitle}</b>
                  {pending ? (
                    <span className="text-xs font-normal text-slate-500">미저장 · 저장 후 수정</span>
                  ) : locked ? (
                    <span className="text-xs font-normal text-slate-500">표준 · 수정 불가</span>
                  ) : paperEditing ? (
                    <span className="text-xs font-normal text-slate-500">수정 중 · 저장하면 반영됩니다</span>
                  ) : null}
                </div>
                <div className="ml-auto flex shrink-0 items-center gap-1.5">
                  {paperEditing ? (
                    <>
                      <MesButton
                        // 항목 PUT — 좌 저장(copy)과 분리
                        size="sm"
                        variant="save"
                        icon="save"
                        disabled={action.isBusy()}
                        onClick={() => void handleSaveItems()}
                      >
                        저장
                      </MesButton>
                      <MesButton
                        // 수정 취소 — 서버 항목으로 되돌림
                        size="sm"
                        variant="ghost"
                        disabled={action.isBusy()}
                        onClick={() => void handleCancel()}
                      >
                        취소
                      </MesButton>
                    </>
                  ) : canEditPaper ? (
                    <MesButton
                      // 저장한 자사 양식만. 표준은 버튼 자체를 두지 않는다
                      size="sm"
                      variant="excel"
                      icon="edit"
                      disabled={action.isBusy()}
                      onClick={() => setEditing(true)}
                    >
                      수정
                    </MesButton>
                  ) : null}
                </div>
              </div>
              <div className="min-h-0 flex-1 overflow-auto">
                <PaperComponent
                  // 기준관리 · 패널 채움
                  mode="template"
                  variant="fill"
                  // 표준·pending이면 잠금
                  locked={locked}
                  // 저장된 자사 양식만
                  editable={canEditPaper}
                  // 수정 버튼 이후
                  editing={paperEditing}
                  header={{
                    title: paperTitle,
                    subtitle: paperSubtitle,
                    baseDt: "",
                    checkerNm: "",
                  }}
                  items={items}
                  footer={{ specialNote: "", improveNote: "", actionNm: "", confirmNm: "" }}
                  onItemsChange={setItems}
                />
              </div>
            </div>
          )}
        />
      </PageCard>
    </div>
  );
}
