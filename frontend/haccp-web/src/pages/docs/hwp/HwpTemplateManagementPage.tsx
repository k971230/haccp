/**
 * HwpTemplateManagementPage — 사용양식 관리 (시스템제공 / 사용자추가).
 *
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) 구분(시스템제공/사용자추가)은 서버가 정하고 화면은 badge로만 보여준다 — 신규는 항상 사용자추가다
 *   2) 파일 기능(업로드·내보내기·불러오기·초기화)은 구분과 무관하게 쓸 수 있고, 삭제만 사용자추가로 제한한다
 *   3) 업로드는 덮어쓰지 않고 버전 1건을 쌓는다 — 불러오기는 과거 버전, 초기화는 기본 제공본으로 되돌린다
 *
 * PIPELINE[HF123] 사용양식관리
 * PIPELINE[HF82, HF84, HF120] 연관 모듈
 *
 * 컬럼·잠금·버튼 판정은 HwpTemplateManagementRule이 갖고 이 파일은 렌더·상태·API만 담당한다
 */
// 역할 — 이벤트·상태·DOM 참조
import { useCallback, useEffect, useMemo, useRef, useState, type ChangeEvent } from "react";
// 역할 — rhwp iframe 에디터 생성·수명 관리 타입
import { createEditor, type RhwpEditor } from "@rhwp/editor";
// 역할 — rhwp 동일출처 studioUrl·도구상자 조기 접기
import { foldRhwpToolboxes, installRhwpEarlyFold, resolveRhwpStudioUrl, waitForHostSize } from "@/lib/rhwpStudio";
// 역할 — 화면별 쓰기·수정 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 비동기 중복 실행 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — 편집 그리드 행 상태
import { useEditableRows } from "@/hooks/useEditableRows";
// 역할 — 공통코드 use-yn(사용유무)·sys-yn(목록 구분)
import { SYS_YN_MAIN_CD, isCompanyForm, useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — 사용여부 콤보 fallback
import { ynOptions } from "@/lib/yn";
// 역할 — 자사 양식코드 채번 — 접두는 USR_TMPL_PREFIX
import { nextUsrTmplCd } from "../html-form/htmlFormTemplateShared";
// 역할 — 표준 버튼·검색 입력 스타일
import { MesButton } from "@/components/ui/MesButton";
import { searchInputClass } from "@/components/ui/Input";
// 역할 — 업무 오류·성공 안내
import { mesError, toUserMessage } from "@/shell/errors";
import { mesConfirm, mesConfirmDanger, mesToast } from "@/shell/dialog";
import { MES } from "@/shell/messages";
// 역할 — 상단 공통 버튼(조회·저장·삭제) 연결
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — 편집 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — 그리드 헤더 행추가·저장·삭제 — 공통코드 관리와 같은 묶음
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
// 역할 — 그리드 잠금 — tmplCd 는 신규행만
import { useGridAccess } from "@/hooks/useGridAccess";
// 역할 — 편집행 타입
import type { EditableRow } from "@/types/editable";
// 역할 — 페이지 카드·검색 영역·좌우 분할(공통코드 관리와 같은 뼈대)
import { PageCard } from "@/components/layout/PageCard";
import { SearchArea, SearchButton, SearchField, SearchSelect } from "@/components/layout/SearchArea";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import { gridHeadClass, pageRootClass, splitPanelClass } from "@/components/layout/pageClasses";
// 역할 — HWP 원본 읽기·업로드 API
import { loadHwpTemplateFile, saveHwpTemplateForm } from "@/api/documentApi";
// 역할 — 사용양식 목록·저장·삭제·파일 이력·불러오기/초기화 API
import {
  applyHwpTemplateFile,
  deleteCompanyTemplates,
  listHwpTemplateFiles,
  listHwpTemplates,
  saveHwpTemplate,
  validateDeleteCompanyTemplates,
  type HwpTemplateFile,
} from "@/api/docs/hwpTemplateApi";
// 역할 — 선택행 우선 삭제 대상
import { resolveRowsForDelete } from "@/shell/resolveDelete";
// 역할 — 구분 헤더 배지 — 공통코드 sys-yn
import { SysYnBadge } from "@/components/ui/SysYnBadge";
// 역할 — 파일 이력 불러오기 팝업 — 코드조회와 같은 그리드 셸
import { HwpTemplateFileHistModal } from "./HwpTemplateFileHistModal";
// 역할 — 화면 규칙(컬럼·잠금·버튼 판정·pref 키)
import {
  LIST_GRID_RULES,
  PERSIST_ID,
  SCRN_CD,
  SPLIT_KEY,
  USR_TMPL_PREFIX,
  buildButtonState,
  buildListColumns,
  type TmplListRow,
} from "./HwpTemplateManagementRule";

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 좌 목록·우 미리보기를 HTML양식 원본과 같은 50:50으로 제공한다
 *   2) 일지설정「사용양식 관리」(hwp-template-management)에서 연다
 *   3) 권한·원본 부재는 업무 토스트만 표시한다
 */
export default function HwpTemplateManagementPage() {
  const canWrite = useAuthStore((state) => state.can(SCRN_CD, "write"));
  const canModify = useAuthStore((state) => state.can(SCRN_CD, "modify"));
  const canDeleteAuth = useAuthStore((state) => state.can(SCRN_CD, "delete"));
  const canEdit = canWrite || canModify;
  // 좌측 그리드 — tmplCd 는 신규(C) 행만 편집. 구분은 표시 전용이라 잠금 대상이 아니다
  const listGrid = useGridAccess(LIST_GRID_RULES, {
    scrnCd: SCRN_CD,
    gridRole: "single",
    readOnly: !canEdit,
    extra: { canWrite, canModify, canDelete: canDeleteAuth },
  });
  const asyncAct = useAsyncAction();
  const useCodes = useCommonCodes("USE_YN");
  // 목록 구분 문구 — 시스템제공/사용자추가. 불러오기 src-ty 와 섞지 않는다
  const sysYnCodes = useCommonCodes(SYS_YN_MAIN_CD);

  /*
   * 조회 조건 — 양식코드·양식명은 서버 LIKE, 구분·사용여부는 서버가 값으로 거른다.
   * 넷 다 빈값이 「전체」다. 사용여부 기본을 Y 로 두지 않는다 —
   * 이 화면은 미사용 양식을 다시 쓰게 만드는 곳이라 안 보이면 손을 못 댄다.
   */
  const [qTmplCd, setQTmplCd] = useState("");
  const [qTmplNm, setQTmplNm] = useState("");
  const [qSysYn, setQSysYn] = useState("");
  const [qUseYn, setQUseYn] = useState("");
  const searchRef = useRef({ qTmplCd, qTmplNm, qSysYn, qUseYn });
  searchRef.current = { qTmplCd, qTmplNm, qSysYn, qUseYn };

  const templates = useEditableRows<TmplListRow>("tmplCd");
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [listLoading, setListLoading] = useState(false);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  const clearSel = () => { setSelKeys([]); setSelReset((n) => n + 1); };

  const editorHostRef = useRef<HTMLDivElement>(null);
  const editorRef = useRef<RhwpEditor | null>(null);
  const [editorReady, setEditorReady] = useState(false);
  const [editorMessage, setEditorMessage] = useState("미리보기를 준비하고 있습니다.");
  // 숨은 업로드 input — 선택 즉시 서버 업로드(버전 1건 적재)
  const uploadFileRef = useRef<HTMLInputElement>(null);
  // 파일 이력 모달 — 불러오기
  const [histOpen, setHistOpen] = useState(false);
  const [histRows, setHistRows] = useState<HwpTemplateFile[]>([]);
  const [histActiveIdx, setHistActiveIdx] = useState<number | null>(null);

  const activeRow = useMemo(
    () => templates.rows.find((row) => row._key === activeKey) ?? null,
    [templates.rows, activeKey],
  );

  const useOpts = useMemo(
    () => (useCodes.codes.length
      ? useCodes.codes.map((code) => ({ value: String(code.subCd).toUpperCase(), label: code.codeNm }))
      : ynOptions()),
    [useCodes.codes],
  );

  const listColumns = useMemo(
    () => buildListColumns(canEdit, useOpts, sysYnCodes.codeMap),
    [canEdit, useOpts, sysYnCodes.codeMap],
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 사용양식 목록을 서버 검색(양식코드·양식명 LIKE)으로 읽어 그리드에 싣는다
   *   2) 진입·조회·저장/삭제/파일작업 후 호출한다
   *   3) 저장 전 신규 draft(C) 행은 재조회 후에도 남긴다
   */
  const loadList = useCallback(async () => {
    setListLoading(true);
    try {
      const query = searchRef.current;
      const rows = await listHwpTemplates({
        tmplCd: query.qTmplCd.trim(),
        tmplNm: query.qTmplNm.trim(),
        sysYn: query.qSysYn,
        useYn: query.qUseYn,
      });
      const drafts = templates.rowsRef.current.filter((row) => row._rowState === "C");
      templates.load(rows);
      if (drafts.length > 0) {
        templates.setRows((prev) => [...prev, ...drafts]);
      }
      setActiveKey((prev) => {
        if (prev && (rows.some((row) => String(row.tmplCd) === prev) || drafts.some((row) => row._key === prev))) {
          return prev;
        }
        return rows[0] ? String(rows[0].tmplCd) : drafts[0]?._key ?? null;
      });
    } catch (error) {
      mesError(error);
    } finally {
      setListLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- templates.load/setRows 안정 참조
  }, []);

  useEffect(() => {
    void loadList();
  }, [loadList]);

  // rhwp 에디터 마운트 — 조기 접기·언마운트 시 destroy
  useEffect(() => {
    const host = editorHostRef.current;
    let disposed = false;
    let createdEditor: RhwpEditor | null = null;
    if (!host) return undefined;

    const disposeEarlyFold = installRhwpEarlyFold(host);
    // 호스트 높이가 0인 채로 붙이면 CanvasView 가 「페이지 0 정보가 없습니다」를 남긴다 —
    // 작성 화면(HwpEditorPane)과 같은 가드를 쓴다
    const sizeAbort = new AbortController();

    void (async () => {
      try {
        await waitForHostSize(host, sizeAbort.signal);
        createdEditor = await createEditor(host, {
          studioUrl: resolveRhwpStudioUrl(),
          width: "100%",
          height: "100%",
          renderer: "canvas2d",
        });
        if (disposed) {
          createdEditor.destroy();
          return;
        }
        foldRhwpToolboxes(createdEditor.element);
        editorRef.current = createdEditor;
        setEditorReady(true);
        setEditorMessage("미리보기가 준비되었습니다. 왼쪽에서 양식을 선택하세요.");
      } catch (error) {
        // 언마운트로 끊긴 대기는 오류가 아니다 — 문구를 바꾸지 않는다
        if (!disposed && !(error instanceof DOMException && error.name === "AbortError")) {
          setEditorMessage(error instanceof Error ? error.message : "미리보기를 시작하지 못했습니다.");
        }
      }
    })();

    return () => {
      disposed = true;
      sizeAbort.abort();
      disposeEarlyFold();
      editorRef.current?.destroy();
      editorRef.current = null;
    };
  }, []);

  /** ArrayBuffer 원본을 현재 rhwp 편집기에 적재한다 */
  const loadIntoEditor = useCallback(async (
    content: ArrayBuffer,
    fileName: string,
    silent = false,
  ) => {
    const editor = editorRef.current;
    if (!editor) {
      if (!silent) mesToast("미리보기가 준비될 때까지 기다리세요.", "warn");
      return;
    }
    try {
      const result = await editor.loadFile(content, fileName, { suppressDialogs: true });
      setEditorMessage(`${fileName} 원본을 ${result.pageCount} 페이지로 열었습니다.`);
      if (!silent) mesToast("양식 원본을 열었습니다.", "success");
    } catch (error) {
      mesError(error);
    }
  }, []);

  /** 현재 적용 파일의 인증 다운로드 URL — 파일이 없으면 null */
  const formUrlOf = (row: EditableRow<TmplListRow> | null): string | null => {
    if (!row || row._rowState === "C") return null;
    if (!row.formFileNm) return null;
    return `/api/v1/docs/templates/${encodeURIComponent(String(row.tmplCd))}/form`;
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 좌측 행 선택 시 현재 적용 파일을 인증 요청으로 읽어 rhwp 미리보기에 적재한다
   *   2) 그리드 onActivate·조회 후 자동 선택에서 호출한다
   *   3) 미저장은 목록 getSaveRows만 본다. rhwp 편집 더티는 추적하지 않는다. 같은 행은 에디터 준비 후 재적재한다
   */
  const handleSelect = (key: string | null) =>
    asyncAct.run(async () => {
      if (key !== activeKey) {
        if (templates.getSaveRows().length > 0 && !(await mesConfirm(MES.unsavedLeaveConfirm))) return;
      }
      setActiveKey(key);
      if (!key) return;
      const row = templates.rowsRef.current.find((item) => item._key === key);
      // 로컬 draft일 때(= 아직 서버 미등록) 파일 API를 호출하지 않는다
      if (!row || row._rowState === "C") {
        setEditorMessage("아직 저장하지 않은 사용자추가 양식입니다. 저장한 뒤 업로드하세요.");
        return;
      }
      const url = formUrlOf(row);
      if (!url) {
        setEditorMessage("등록된 양식 파일이 없습니다. 업로드하세요.");
        return;
      }
      try {
        await loadIntoEditor(await loadHwpTemplateFile(url), row.formFileNm ?? String(row.tmplCd), true);
      } catch (error) {
        // 원본이 디스크에 없을 때(= 404) 미리보기 헤더에만 안내한다. 행 전환마다 토스트를 띄우지 않는다
        setEditorMessage(toUserMessage(error, MES.formNotUploaded));
      }
    }, "loadTemplate");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-18
   * 코멘트:
   *   1) 빈 행을 추가한다 — 구분은 사용자추가(usr) 고정이며 사용자가 바꿀 수 없다
   *   2) 양식코드는 hwp_usr_NNN 을 자동 채번한다. 양식명은 저장 전에 입력한다
   *   3) 목록 헤더 「행추가」에서 호출한다
   */
  const handleAdd = () => {
    if (!canWrite) {
      mesToast("등록 권한이 없습니다.", "warn");
      return;
    }
    const key = templates.addRow({
      tmplCd: nextUsrTmplCd(USR_TMPL_PREFIX, templates.rows),
      tmplNm: "",
      // 신규는 항상 사용자추가 — 서버도 usr 로 강제한다(요구사항 4)
      sysYn: "usr",
      useYn: "Y",
    });
    setActiveKey(key);
    setEditorMessage("아직 저장하지 않은 사용자추가 양식입니다. 양식명을 입력해 저장한 뒤 업로드하세요.");
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 변경된 행(신규·수정)을 저장한다 — 양식코드·양식명·사용유무만 보낸다
   *   2) 목록 헤더 「저장」에서 호출한다
   *   3) 구분은 보내지 않는다 — 신규는 자사양식, 기존 행은 구분 불변(요구사항 19)
   */
  const handleSave = async () => {
    if (!canEdit) {
      mesToast("수정 권한이 없습니다.", "warn");
      return;
    }
    const dirty = templates.getSaveRows();
    if (dirty.length === 0) {
      mesToast(MES.noChange, "warn");
      return;
    }
    for (const row of dirty) {
      if (!String(row.tmplCd ?? "").trim()) {
        mesToast(MES.required("양식코드"), "warn");
        setActiveKey(row._key);
        return;
      }
      if (!String(row.tmplNm ?? "").trim()) {
        mesToast(MES.required("양식명"), "warn");
        setActiveKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      for (const row of dirty) {
        await saveHwpTemplate({
          tmplCd: String(row.tmplCd).trim(),
          tmplNm: String(row.tmplNm).trim(),
          useYn: String(row.useYn ?? "Y").toUpperCase() === "N" ? "N" : "Y",
        });
      }
      // 저장된 draft 는 서버 목록으로 대체되므로 로컬 행을 지운다
      for (const row of dirty) {
        if (row._rowState === "C") templates.removeNewRow(row._key);
      }
      mesToast(MES.saveDone, "success");
      await loadList();
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 미저장 draft는 로컬 제거, 자사양식만 validate-delete 후 삭제한다
   *   2) 목록 헤더 「삭제」에서 호출한다
   *   3) 시스템양식은 요청 전에 막는다 — 서버·SP도 같은 문구로 다시 차단한다
   */
  const handleDelete = async () => {
    if (!canDeleteAuth) {
      mesToast("삭제 권한이 없습니다.", "warn");
      return;
    }
    const targets = resolveRowsForDelete(templates.rows, activeKey, setActiveKey, selKeys);
    if (targets.length === 0) {
      mesToast(MES.selectRow, "warn");
      return;
    }
    const drafts = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    let lastFocus = activeKey;
    for (const row of drafts) {
      const { focusKey } = templates.removeNewRow(row._key!);
      lastFocus = focusKey;
    }
    if (drafts.length > 0) {
      setActiveKey(lastFocus);
      clearSel();
    }
    if (persisted.length === 0) return;
    // 구분이 시스템일 때(= 프로그램 제공분) 삭제 차단 — 요구사항 6·14
    if (persisted.some((row) => !isCompanyForm(row.sysYn))) {
      mesToast("시스템에서 제공하는 양식은 삭제할 수 없습니다.", "warn");
      return;
    }
    const keys = persisted
      .map((row) => String(row.tmplCd ?? "").trim())
      .filter((tmplCd) => tmplCd.length > 0)
      .map((tmplCd) => ({ tmplCd }));
    if (keys.length === 0) {
      mesToast("삭제할 행의 키가 올바르지 않습니다.", "warn");
      return;
    }
    const label = String(persisted[0].tmplNm ?? persisted[0].tmplCd ?? "양식");
    try {
      await validateDeleteCompanyTemplates(keys);
      if (!(await mesConfirmDanger(MES.deleteConfirm(label)))) return;
      await deleteCompanyTemplates(keys);
      clearSel();
      mesToast(MES.deleteDone, "success");
      await loadList();
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 선택한 로컬 HWP/HWPX를 새 버전으로 업로드하고 현재 적용본으로 만든다
   *   2) 미리보기 헤더 「업로드」 파일 선택 후 호출된다
   *   3) 기존 파일은 덮어쓰지 않는다 — 이력에 남아 불러오기로 되돌릴 수 있다
   */
  const handleUploadFile = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0] ?? null;
    event.target.value = "";
    const row = activeRow;
    if (!file || !row) return;
    if (!(await mesConfirm(`'${file.name}' 파일을 '${row.tmplNm || row.tmplCd}' 양식으로 업로드하시겠습니까?`))) {
      return;
    }
    try {
      await saveHwpTemplateForm(String(row.tmplCd), file);
      mesToast("양식 파일을 업로드했습니다.", "success");
      await loadIntoEditor(await file.arrayBuffer(), file.name, true);
      await loadList();
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 현재 적용 파일을 로컬로 내려받는다
   *   2) 미리보기 헤더 「내보내기」에서 호출한다
   *   3) 파일이 없으면 버튼이 비활성이므로 여기서는 경로만 확인한다
   */
  const handleExportFile = () =>
    asyncAct.run(async () => {
      const row = activeRow;
      const url = formUrlOf(row);
      if (!row || !url) {
        mesToast("내려받을 양식 파일이 없습니다.", "warn");
        return;
      }
      try {
        const blob = new Blob([await loadHwpTemplateFile(url)], { type: "application/octet-stream" });
        const href = URL.createObjectURL(blob);
        const anchor = document.createElement("a");
        anchor.href = href;
        anchor.download = row.formFileNm || `${row.tmplCd}.hwp`;
        anchor.click();
        URL.revokeObjectURL(href);
        mesToast("양식 파일을 내려받았습니다.", "success");
      } catch (error) {
        mesError(error);
      }
    }, "export");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-18
   * 코멘트:
   *   1) 선택 양식의 파일 이력을 읽어 불러오기 팝업을 연다
   *   2) 미리보기 헤더 「불러오기」에서 호출한다
   *   3) SP 문구 '현재적용' 행을 라디오 기본 선택으로 두고, 이력이 없으면 팝업을 열지 않는다
   */
  const openHistModal = () =>
    asyncAct.run(async () => {
      const row = activeRow;
      if (!row || row._rowState === "C") {
        mesToast("양식을 선택하세요.", "warn");
        return;
      }
      try {
        const rows = await listHwpTemplateFiles(String(row.tmplCd));
        if (rows.length === 0) {
          mesToast("불러올 파일 이력이 없습니다.", "warn");
          return;
        }
        setHistRows(rows);
        setHistActiveIdx(rows.find((file) => file.currentYn === "현재적용")?.idx ?? rows[0].idx);
        setHistOpen(true);
      } catch (error) {
        mesError(error);
      }
    }, "hist-open");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 팝업에서 고른 이력 버전을 현재 적용본으로 바꾼다
   *   2) 불러오기 팝업 「적용」에서 호출한다
   *   3) 과거 이력은 지우지 않는다 — 언제든 다시 되돌릴 수 있다
   */
  const applyHist = () =>
    asyncAct.run(async () => {
      const row = activeRow;
      const pick = histRows.find((file) => file.idx === histActiveIdx);
      if (!row || !pick) {
        mesToast("불러올 파일을 선택하세요.", "warn");
        return;
      }
      if (!(await mesConfirm(`'${pick.fileNm}' 버전을 적용하시겠습니까?`))) return;
      try {
        await applyHwpTemplateFile({ tmplCd: String(row.tmplCd), fileIdx: pick.idx });
        setHistOpen(false);
        mesToast("선택한 양식 파일을 적용했습니다.", "success");
        await loadList();
        await handleSelect(String(row.tmplCd));
      } catch (error) {
        mesError(error);
      }
    }, "hist-apply");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 현재 적용본을 기본 제공본으로 되돌린다 — 시스템양식은 배포 원본, 자사양식은 최초 등록본
   *   2) 미리보기 헤더 「초기화」에서 호출한다
   *   3) 업로드 이력은 남으므로 다시 불러올 수 있다
   */
  const handleReset = () =>
    asyncAct.run(async () => {
      const row = activeRow;
      if (!row || row._rowState === "C") {
        mesToast("양식을 선택하세요.", "warn");
        return;
      }
      if (!(await mesConfirmDanger(`'${row.tmplNm || row.tmplCd}' 양식을 기본 제공 파일로 초기화하시겠습니까?`, {
        title: "초기화",
        okText: "초기화",
      }))) return;
      try {
        await applyHwpTemplateFile({ tmplCd: String(row.tmplCd) });
        mesToast("기본 제공 양식으로 초기화했습니다.", "success");
        await loadList();
        await handleSelect(String(row.tmplCd));
      } catch (error) {
        mesError(error);
      }
    }, "reset");

  // 버튼 활성 판정 단일 계산 — 구분은 삭제에만 관여하고 파일 기능은 양쪽 모두 허용한다
  const buttonState = useMemo(
    () => buildButtonState(activeRow, canEdit, canDeleteAuth),
    [activeRow, canDeleteAuth, canEdit],
  );

  usePageCommands({
    search: () => { void loadList(); },
    add: canWrite ? handleAdd : undefined,
    save: canEdit ? () => { void asyncAct.run(handleSave, "save"); } : undefined,
    del: canDeleteAuth ? () => { void asyncAct.run(handleDelete, "del"); } : undefined,
  });

  useEffect(() => {
    if (!editorReady || !activeKey) return;
    void handleSelect(activeKey);
  // eslint-disable-next-line react-hooks/exhaustive-deps -- 에디터 준비 1회
  }, [editorReady]);

  return (
    <div className={pageRootClass}>
      <PageCard
        search={(
          <SearchArea
            onSearch={() => { void loadList(); }}
            actions={<SearchButton loading={listLoading} />}
          >
            <SearchField label="양식코드">
              <input
                // 양식코드 부분검색 — 서버 LIKE
                className={searchInputClass}
                value={qTmplCd}
                placeholder="양식코드"
                onChange={(event) => setQTmplCd(event.target.value)}
              />
            </SearchField>
            <SearchField label="양식명">
              <input
                // 양식명 부분검색 — 서버 LIKE
                className={searchInputClass}
                value={qTmplNm}
                placeholder="양식명"
                onChange={(event) => setQTmplNm(event.target.value)}
              />
            </SearchField>
            <SearchSelect
              // 구분 — 시스템제공/자사. 빈값이 전체
              label="구분"
              // 검색 구분 — sys|usr 또는 빈값(전체)
              value={qSysYn}
              // 바꾸면 SearchSelect 가 즉시 조회를 건다
              onChange={setQSysYn}
            >
              <option value="">전체</option>
              {sysYnCodes.codes.map((code) => (
                <option key={code.subCd} value={String(code.subCd).toLowerCase()}>{code.codeNm}</option>
              ))}
            </SearchSelect>
            <SearchSelect
              // 사용여부 — 빈값이 전체. 미사용 양식을 되살리는 화면이라 기본을 Y 로 두지 않는다
              label="사용여부"
              // 검색 사용여부 — Y|N 또는 빈값(전체)
              value={qUseYn}
              onChange={setQUseYn}
            >
              <option value="">전체</option>
              {useOpts.map((opt) => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </SearchSelect>
          </SearchArea>
        )}
      >
        <input
          // 업로드용 숨은 file input — 선택 즉시 서버 업로드
          ref={uploadFileRef}
          type="file"
          accept=".hwp,.hwpx"
          className="hidden"
          onChange={(event) => void handleUploadFile(event)}
        />

        <ResizableSplit
          // 좌 목록 50 · 우 미리보기 50 — HTML양식 원본과 같은 프레임
          orientation="horizontal"
          storageKey={SPLIT_KEY}
          defaultPrimaryPct={50}
          minPct={25}
          maxPct={75}
          className="mes-page-split min-h-0 h-full flex-1 gap-0"
          primary={(
            <div className={splitPanelClass}>
              <div className={gridHeadClass}>
                <div className="flex min-w-0 items-center gap-2">
                  <b>사용양식 목록</b>
                </div>
                <div className="ml-auto flex shrink-0 items-center gap-1.5">
                  <GridCrudButtons
                    // 행추가·저장·삭제 — 공통코드 헤더와 같은 묶음
                    run={asyncAct.run}
                    onAdd={canWrite ? handleAdd : undefined}
                    onSave={canEdit ? handleSave : undefined}
                    onDel={canDeleteAuth ? handleDelete : undefined}
                    busy={{
                      save: asyncAct.isBusy("save"),
                      del: asyncAct.isBusy("del"),
                    }}
                  />
                </div>
              </div>
              <MesEditableGrid
                // 열 설정 저장 키 — 사용양식관리 전용
                persistId={PERSIST_ID}
                // 화면 권한·pref 범위
                scrnCd={SCRN_CD}
                // 서버 목록 + 신규 draft
                rows={templates.rows}
                // 양식코드·양식명·구분·양식파일·사용유무
                columns={listColumns}
                // 신규행 셀 편집 — 저장행은 newOnly 로 코드만 잠근다
                editable={canEdit}
                // 패널 제목
                title="사용양식 목록"
                // 부모 flex 높이 채움
                height="100%"
                // 목록 조회 중
                loading={listLoading}
                // 선택 양식 키
                activeKey={activeKey}
                // 행 클릭 시 현재 파일 미리보기
                onActivate={(row) => { void handleSelect(row._key ?? null); }}
                // 셀 변경 — 구분은 편집 대상이 아니라 그대로 유지된다
                onCellChange={(key, field, value) => {
                  templates.updateCell(key, field as keyof TmplListRow, value);
                }}
                // 잠금·권한 접근 판정
                access={listGrid.access}
                // 잠금 셀 시도 안내
                onLockedAttempt={listGrid.onLockedAttempt}
                // 다중 선택 삭제
                selectable
                onSelectionChange={(rows) => setSelKeys(rows.map((row) => row._key))}
                selectionResetKey={selReset}
                showRowNum
                // 헤더에 건수를 두지 않으므로 그리드 푸터 총 N건도 숨긴다
                showFooter={false}
              />
            </div>
          )}
          secondary={(
            <div className={splitPanelClass}>
              <div className={gridHeadClass}>
                <div className="flex min-w-0 items-center gap-2 overflow-hidden">
                  <b
                    // 폭이 모자라면 말줄임 — 미리보기 안내는 헤더 span 대신 title
                    className="truncate"
                    title={[
                      activeRow?.tmplNm || activeRow?.tmplCd || "양식 미리보기",
                      editorMessage,
                    ].filter(Boolean).join(" — ")}
                  >
                    {activeRow?.tmplNm || activeRow?.tmplCd || "양식 미리보기"}
                  </b>
                  {activeRow ? (
                    <SysYnBadge
                      // 미리보기 대상 구분 — sys/usr. 문구는 공통코드 sys-yn
                      sysYn={activeRow.sysYn}
                    />
                  ) : null}
                </div>
                <div className="ml-auto flex shrink-0 items-center gap-1.5">
                  <MesButton
                    // 로컬 HWP를 새 버전으로 업로드 — 저장·현재 적용이라 save(파랑)
                    variant="save"
                    size="sm"
                    icon="upload"
                    disabled={!buttonState.canUpload || asyncAct.isBusy()}
                    onClick={() => uploadFileRef.current?.click()}
                  >
                    업로드
                  </MesButton>
                  <MesButton
                    // 현재 적용 파일만 내려받기 — 적용 없음이라 excel(초록)
                    variant="excel"
                    size="sm"
                    icon="download"
                    disabled={!buttonState.canExport || asyncAct.isBusy("export")}
                    onClick={() => void handleExportFile()}
                  >
                    내보내기
                  </MesButton>
                  <MesButton
                    // 파일 이력에서 과거 버전 적용
                    variant="add"
                    size="sm"
                    icon="inbox"
                    disabled={!buttonState.canImport || asyncAct.isBusy("hist-open")}
                    onClick={() => void openHistModal()}
                  >
                    불러오기
                  </MesButton>
                  <MesButton
                    // 기본 제공 파일로 복원
                    variant="danger"
                    size="sm"
                    icon="reset"
                    disabled={!buttonState.canReset || asyncAct.isBusy("reset")}
                    onClick={() => void handleReset()}
                  >
                    초기화
                  </MesButton>
                </div>
              </div>
              <div
                // rhwp createEditor 호스트 — 패널 안에서만 스크롤되어 좌측 목록이 밀리지 않는다
                ref={editorHostRef}
                className="min-h-0 flex-1 overflow-hidden bg-slate-50"
              />
            </div>
          )}
        />
      </PageCard>

      <HwpTemplateFileHistModal
        // 불러오기 팝업 열림
        open={histOpen}
        // 선택 양식의 파일 이력
        rows={histRows}
        // 라디오로 고른 파일 idx
        activeIdx={histActiveIdx}
        // 적용 API 진행 중
        applying={asyncAct.isBusy("hist-apply")}
        // 행·라디오 클릭
        onSelect={setHistActiveIdx}
        // 푸터 적용 — mesConfirm 후 현재 적용본 변경
        onApply={() => void applyHist()}
        // 배경·취소
        onClose={() => setHistOpen(false)}
      />
    </div>
  );
}
