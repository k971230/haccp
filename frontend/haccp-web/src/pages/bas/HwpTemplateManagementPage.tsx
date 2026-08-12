/**
 * HwpTemplateManagementPage — 사용양식관리(일지설정·HWP).
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 회사 사용 HWP 템플릿 목록을 좌측 그리드로 보여주고 선택 시 rhwp로 원본을 연다
 *   2) 신규는 선택 기준양식+한글 HWP 업로드 → 볼륨(_template/{coCd})·sys_yn=N 등록
 *   3) 내보내기/불러오기는 HWP 설정 export-hist만 관리 (바이너리는 볼륨이 정본)
 *
 * PIPELINE[HF123] 사용양식관리
 * PIPELINE[HF82, HF84, HF120] 연관 모듈
 */
// 역할 — 이벤트·상태·DOM 참조
import { useCallback, useEffect, useMemo, useRef, useState, type ChangeEvent } from "react";
// 역할 — rhwp iframe 에디터 생성·수명 관리 타입
import { createEditor, type RhwpEditor } from "@rhwp/editor";
// 역할 — rhwp 동일출처 studioUrl·도구상자 조기 접기
import { foldRhwpToolboxes, installRhwpEarlyFold, resolveRhwpStudioUrl } from "@/lib/rhwpStudio";
// 역할 — 화면별 쓰기·수정 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 비동기 중복 실행 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — 편집 그리드 행 상태
import { useEditableRows } from "@/hooks/useEditableRows";
// 역할 — 표준 버튼
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 업무 오류·성공 안내
import { mesError } from "@/shell/errors";
import { mesConfirm, mesToast } from "@/shell/dialog";
import { MES } from "@/shell/messages";
// 역할 — 편집 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — 목록 그리드 잠금(읽기 전용 목록)
import { useGridAccess } from "@/hooks/useGridAccess";
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 문서 공통 헤더·레이아웃
import {
  DocFormBody,
  DocFormDocumentList,
  DocFormLayout,
} from "@/components/form/DocFormLayout";
import {
  DocFormSearchToolbar,
  defaultDocFormSearch,
  type DocFormSearchValues,
} from "@/components/form/DocFormSearchToolbar";
// 역할 — HWP 템플릿 목록·원본·저장 API
import {
  listDocumentTemplates,
  loadHwpTemplateFile,
  saveHwpTemplateForm,
  type DocumentTemplateRow,
} from "@/api/documentApi";
// 역할 — 자사 업로드·삭제·설정 export/import
import {
  createCompanyTemplateCustom,
  deleteCompanyTemplates,
  exportTemplateHist,
  importTemplateHist,
  listTemplateExportHist,
  validateDeleteCompanyTemplates,
  type TemplateExportHist,
} from "@/api/workflowApi";
// 역할 — 선택행 우선 삭제 대상
import { resolveRowsForDelete } from "@/shell/resolveDelete";

/** 좌측 템플릿 그리드 행 — 서버 템플릿 + 로컬 draft */
type TmplListRow = DocumentTemplateRow & {
  // 그리드 표시용 — 원본 파일명 유무
  formFileDisp?: string;
  // 그리드 표시용 — 시스템/자사/미저장
  sysYnDisp?: string;
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) HWP 템플릿 목록·rhwp 원본 편집·양식 파일 저장을 한 화면에서 제공한다
 *   2) 일지설정「사용양식관리」(hwp-template-management)에서 연다
 *   3) 원본 부재·권한 실패는 업무 토스트만 표시한다
 */
export default function HwpTemplateManagementPage() {
  const screenCode = "hwp-template-management";
  const canWrite = useAuthStore((state) => state.can(screenCode, "write"));
  const canModify = useAuthStore((state) => state.can(screenCode, "modify"));
  const canDelete = useAuthStore((state) => state.can(screenCode, "delete"));
  const canEdit = canWrite || canModify;
  // 좌측 사용양식 목록 — 셀 편집 없음(읽기 전용 access)
  const listGrid = useGridAccess({ newOnly: [] }, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: true,
    extra: { canWrite, canModify, canDelete },
  });
  const asyncAct = useAsyncAction();

  // 조회 조건 — 템플릿은 기간·작성자 없이 docNo 슬롯을 양식코드/명 필터로 쓴다
  const [search, setSearch] = useState<DocFormSearchValues>(() => defaultDocFormSearch());
  const searchRef = useRef(search);
  searchRef.current = search;

  // 서버에서 받은 전체 HWP 템플릿(LAW 제외) — 클라이언트 필터 원천
  const [allTemplates, setAllTemplates] = useState<DocumentTemplateRow[]>([]);
  const templates = useEditableRows<TmplListRow>("tmplCd");
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [listLoading, setListLoading] = useState(false);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  const clearSel = () => { setSelKeys([]); setSelReset((n) => n + 1); };

  const editorHostRef = useRef<HTMLDivElement>(null);
  const editorRef = useRef<RhwpEditor | null>(null);
  const [editorReady, setEditorReady] = useState(false);
  const [editorMessage, setEditorMessage] = useState("rhwp 에디터가 시작하는 중입니다.");
  // 숨은 로컬 파일 input — rhwp에만 적재(저장 전 미리보기)
  const localFileRef = useRef<HTMLInputElement>(null);
  // 숨은 자사 신규 업로드 input — 선택 기준양식에 한글 HWP 연결
  const customUploadRef = useRef<HTMLInputElement>(null);
  // 설정 불러오기 모달
  const [importOpen, setImportOpen] = useState(false);
  const [importRows, setImportRows] = useState<{ kind: "SERVER" | "HIST"; idx?: number; label: string }[]>([]);
  const [importActiveKey, setImportActiveKey] = useState("SERVER");

  const activeRow = useMemo(
    () => templates.rows.find((row) => row._key === activeKey) ?? null,
    [templates.rows, activeKey],
  );

  const listColumns = useMemo<GridColumn<TmplListRow>[]>(
    () => [
      { field: "tmplCd", header: "양식코드", width: 120, editable: false },
      { field: "tmplNm", header: "양식명", width: 160, editable: false },
      { field: "sysYnDisp", header: "구분", width: 80, editable: false },
      { field: "formFileDisp", header: "원본파일", width: 140, editable: false },
    ],
    [],
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 회사 사용 HWP 템플릿을 조회하고 LAW를 제외한 뒤 검색어로 좁힌다
   *   2) 조회 버튼·최초 진입·저장 후 호출한다
   *   3) 실패 시 업무 토스트만 표시한다
   */
  const loadList = useCallback(async () => {
    setListLoading(true);
    try {
      const rows = await listDocumentTemplates();
      // HWP만 — 법적서류(LAW)는 legal-document-upload 화면 전용
      const hwp = rows.filter(
        (row) =>
          row.docKind === "HWP"
          && row.categoryCd !== "LAW"
          && !String(row.tmplCd || "").startsWith("LAW_"),
      );
      setAllTemplates(hwp);
      const q = searchRef.current;
      const keyword = (q.docNo || q.writer || "").trim().toLowerCase();
      const filtered = keyword
        ? hwp.filter(
          (row) =>
            row.tmplCd.toLowerCase().includes(keyword)
            || (row.tmplNm || "").toLowerCase().includes(keyword),
        )
        : hwp;
      const mapped = filtered.map((row) => ({
        ...row,
        formFileDisp: row.formFileNm || "(없음)",
        // 시스템 배포분 / 자사 커스텀 / draft 표시
        sysYnDisp: row.sysYn === "N" ? "자사" : "시스템",
      }));
      // draft(C) 행은 재조회 후에도 남긴다 — 서버에 없는 자사 커스텀 자리표시
      const drafts = templates.rowsRef.current.filter((row) => row._rowState === "C");
      templates.load(mapped);
      if (drafts.length > 0) {
        templates.setRows((prev) => [...prev, ...drafts]);
      }
      setActiveKey((prev) => {
        if (prev && (mapped.some((row) => String(row.tmplCd) === prev) || drafts.some((d) => d._key === prev))) {
          return prev;
        }
        return mapped[0] ? String(mapped[0].tmplCd) : drafts[0]?._key ?? null;
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

    // iframe 등장 즉시 도구상자 접기 + visibility 게이트
    const disposeEarlyFold = installRhwpEarlyFold(host);

    void (async () => {
      try {
        createdEditor = await createEditor(host, {
          // 동일출처 스튜디오 — Vite/nginx /rhwp 프록시
          studioUrl: resolveRhwpStudioUrl(),
          // iframe 폭 — 부모 편집 패널의 가용 폭 전체
          width: "100%",
          // iframe 높이 — flex 편집 영역의 가용 높이 전체
          height: "100%",
          // HACCP 문서는 호환 우선 Canvas2D 렌더러
          renderer: "canvas2d",
        });
        if (disposed) {
          createdEditor.destroy();
          return;
        }
        // ready 후에도 한 번 더 접기 — 기본+서식
        foldRhwpToolboxes(createdEditor.element);
        editorRef.current = createdEditor;
        setEditorReady(true);
        setEditorMessage("rhwp 에디터가 준비되었습니다. 좌측에서 양식을 선택하세요.");
      } catch (error) {
        if (!disposed) {
          setEditorMessage(error instanceof Error ? error.message : "rhwp 에디터를 시작하지 못했습니다.");
        }
      }
    })();

    return () => {
      disposed = true;
      disposeEarlyFold();
      editorRef.current?.destroy();
      editorRef.current = null;
    };
  }, []);

  /** ArrayBuffer 원본을 현재 rhwp 편집기에 적재한다 */
  const loadIntoEditor = useCallback(async (
    // HWP/HWPX 바이너리
    content: ArrayBuffer,
    // 파일명 — 확장자로 포맷 판별
    fileName: string,
    // true면 성공 토스트 생략
    silent = false,
  ) => {
    const editor = editorRef.current;
    if (!editor) {
      if (!silent) mesToast("rhwp 에디터가 준비될 때까지 기다리세요.", "warn");
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

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 좌측 행 선택 시 formUrl 원본을 인증 요청으로 읽어 rhwp에 적재한다
   *   2) 그리드 onActivate·조회 후 자동 선택에서 호출한다
   *   3) draft(C)·원본 부재는 안내만 하고 요청하지 않는다
   */
  const handleSelect = (key: string | null) =>
    asyncAct.run(async () => {
      setActiveKey(key);
      if (!key) return;
      const row = templates.rowsRef.current.find((r) => r._key === key);
      // 로컬 draft일 때(= 서버 템플릿 아님) 원본 API를 호출하지 않는다
      if (!row || row._rowState === "C") {
        setEditorMessage("자사 커스텀 draft입니다. 서버 양식 행을 선택해 원본을 수정하세요.");
        return;
      }
      if (!row.formUrl || !row.formFileNm) {
        setEditorMessage("표준 원본 파일이 없습니다. 로컬 불러오기 후 저장하세요.");
        mesToast("표준 원본 파일이 없습니다.", "warn");
        return;
      }
      try {
        await loadIntoEditor(await loadHwpTemplateFile(row.formUrl), row.formFileNm, true);
      } catch {
        setEditorMessage("표준 원본 파일이 없습니다. 로컬 불러오기 후 저장하세요.");
        mesToast("표준 원본 파일이 없습니다.", "warn");
      }
    }, "loadTemplate");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 좌측에서 기준 양식을 고른 뒤 자사 HWP 파일 선택을 연다
   *   2) 「신규」버튼에서 호출한다 — draft만 만들지 않고 서버·볼륨에 등록한다
   *   3) 기준 행이 없으면 안내만
   */
  const handleAdd = () => {
    if (!canWrite) {
      mesToast("등록 권한이 없습니다.", "warn");
      return;
    }
    const base = activeRow;
    if (!base?.tmplCd || base._rowState === "C") {
      mesToast("기준이 될 양식 행을 선택한 뒤 신규 업로드하세요.", "warn");
      return;
    }
    customUploadRef.current?.click();
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 선택한 기준 tmplCd에 한글 파일명으로 자사 원본을 올린다
   *   2) 숨은 file input onChange에서 호출한다
   *   3) 성공 시 목록 재조회 — 파일명은 서버가 번호 접두만 제거해 보존한다
   */
  const handleCustomUpload = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0] ?? null;
    event.target.value = "";
    if (!file) return;
    const base = activeRow;
    if (!base?.tmplCd) {
      mesToast("기준이 될 양식 행을 선택하세요.", "warn");
      return;
    }
    if (!(await mesConfirm(`'${base.tmplNm || base.tmplCd}' 기준에 자사 양식 '${file.name}'을(를) 등록하시겠습니까?`))) {
      return;
    }
    try {
      await createCompanyTemplateCustom({
        tmplCd: base.tmplCd,
        tmplNm: base.tmplNm || undefined,
        file,
      });
      mesToast(MES.saveDone, "success");
      await loadList();
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 미저장 draft는 로컬 제거, 자사(sys_yn=N)는 validate-delete 후 삭제한다
   *   2) 삭제 버튼·단축키에서 호출한다
   *   3) 시스템 배포분(sys_yn=Y)은 안내만 하고 요청하지 않는다
   */
  const handleDelete = async () => {
    if (!canDelete) {
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
    const systemRows = persisted.filter((row) => String(row.sysYn ?? "Y").toUpperCase() !== "N");
    if (systemRows.length > 0) {
      mesToast("시스템 배포 양식은 삭제할 수 없습니다. 자사 커스텀만 삭제하세요.", "warn");
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
      if (!(await mesConfirm(MES.deleteConfirm(label)))) return;
      await deleteCompanyTemplates(keys);
      clearSel();
      mesToast(MES.deleteDone, "success");
      await loadList();
    } catch (error) {
      mesError(error);
    }
  };

  /** rhwp 결과를 선택 양식 form 경로에 덮어쓴다 */
  const handleSave = () =>
    asyncAct.run(async () => {
      if (!canEdit) {
        mesToast("수정 권한이 없습니다.", "warn");
        return;
      }
      const row = activeRow;
      // draft이거나 양식코드 없을 때(= 서버 저장 대상 아님)
      if (!row || row._rowState === "C" || !row.tmplCd) {
        mesToast("서버 양식 행을 선택한 뒤 저장하세요.", "warn");
        return;
      }
      if (!(await mesConfirm(`${row.tmplNm || row.tmplCd} 양식 원본을 덮어쓰시겠습니까?`))) {
        return;
      }
      const editor = editorRef.current;
      if (!editor || !editorReady) {
        mesToast(editorMessage, "warn");
        return;
      }
      try {
        const bytes = await editor.exportHwpx();
        const uploadBytes = Uint8Array.from(bytes);
        const file = new File([uploadBytes], `${row.tmplCd}.hwpx`, {
          type: "application/vnd.hancom.hwpx",
        });
        await saveHwpTemplateForm(row.tmplCd, file);
        mesToast(MES.saveDone, "success");
        setEditorMessage("양식 원본을 덮어썼습니다. 이후 신규 문서는 이 원본으로 열립니다.");
        await loadList();
      } catch (error) {
        mesError(error);
      }
    }, "save");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) HWP 회사 양식·점검항목 설정을 export-hist에 저장한다 (바이너리 제외)
   *   2) 관리 화면 내보내기 버튼에서만 호출한다
   *   3) 성공 시 이력 idx 안내
   */
  const handleExport = () =>
    asyncAct.run(async () => {
      if (!canModify) return mesToast("수정 권한이 없습니다.", "warn");
      const stamp = new Date().toISOString().slice(0, 16).replace(/[-:T]/g, "");
      const packNm = `HWP설정_${stamp}`;
      if (!(await mesConfirm(`현재 HWP 양식 설정을 '${packNm}' 패키지로 내보내시겠습니까?`))) return;
      try {
        const histIdx = await exportTemplateHist({ packNm, docKind: "HWP" });
        mesToast(`내보내기를 완료했습니다. (이력 ${histIdx})`, "success");
      } catch (error) {
        mesError(error);
      }
    }, "export");

  /** 설정 불러오기 모달 — SERVER/이력 선택 */
  const openImportModal = () =>
    asyncAct.run(async () => {
      if (!canModify) return mesToast("수정 권한이 없습니다.", "warn");
      const picks: { kind: "SERVER" | "HIST"; idx?: number; label: string }[] = [
        { kind: "SERVER", label: "서버 템플릿 (표준 오버라이드 초기화)" },
      ];
      try {
        const hist: TemplateExportHist[] = await listTemplateExportHist({ docKind: "HWP" });
        for (const row of hist) {
          picks.push({
            kind: "HIST",
            idx: Number(row.idx),
            label: `${row.packNm} · ${row.insDt ?? ""}`.trim(),
          });
        }
      } catch (error) {
        mesError(error);
      }
      setImportRows(picks);
      setImportActiveKey("SERVER");
      setImportOpen(true);
    }, "import-open");

  const applyImport = () =>
    asyncAct.run(async () => {
      const pick = importRows.find((row) => {
        const key = row.kind === "SERVER" ? "SERVER" : `HIST-${row.idx}`;
        return key === importActiveKey;
      });
      if (!pick) return mesToast("불러올 대상을 선택하세요.", "warn");
      const msg = pick.kind === "SERVER"
        ? "서버 표준으로 오버라이드를 초기화하시겠습니까?"
        : `'${pick.label}' 이력을 적용하시겠습니까?`;
      if (!(await mesConfirm(msg))) return;
      try {
        if (pick.kind === "SERVER") {
          await importTemplateHist({ source: "SERVER", docKind: "HWP" });
        } else {
          await importTemplateHist({ histIdx: pick.idx });
        }
        setImportOpen(false);
        await loadList();
        mesToast("불러오기를 완료했습니다.", "success");
      } catch (error) {
        mesError(error);
      }
    }, "import");

  /** 로컬 HWP를 rhwp에만 연다 (저장은 별도) */
  const handleImportClick = () => {
    localFileRef.current?.click();
  };

  const handleLocalFile = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0] ?? null;
    event.target.value = "";
    if (!file) return;
    await loadIntoEditor(await file.arrayBuffer(), file.name);
  };

  // rhwp 준비 후 현재 선택 행 원본을 한 번 적재한다
  useEffect(() => {
    if (!editorReady || !activeKey) return;
    void handleSelect(activeKey);
  // eslint-disable-next-line react-hooks/exhaustive-deps -- 에디터 준비 1회
  }, [editorReady]);

  return (
    <DocFormLayout>
      <DocFormSearchToolbar
        // 기간·문서번호·작성자 — 템플릿은 docNo/writer를 양식코드·명 필터로 사용
        values={search}
        // 조건 부분 갱신
        onChange={(patch) => setSearch((prev) => ({ ...prev, ...patch }))}
        // 목록 재조회
        onSearch={() => void loadList()}
        // 조회 busy
        searchBusy={listLoading || asyncAct.isBusy("loadTemplate")}
        // 액션 busy
        actionBusy={asyncAct.isBusy("save")}
        // 우측 액션 — 신규/저장/내보내기/불러오기
        actions={(
          <>
            <MesButton
              // 선택 기준양식에 자사 HWP 업로드
              variant="add"
              disabled={!canWrite || asyncAct.isBusy()}
              onClick={handleAdd}
            >
              신규
            </MesButton>
            <MesButton
              // 선택 양식 form 덮어쓰기
              variant="save"
              disabled={!canEdit || !editorReady || asyncAct.isBusy("save")}
              loading={asyncAct.isBusy("save")}
              onClick={() => void handleSave()}
            >
              저장
            </MesButton>
            <MesButton
              // draft·자사 커스텀 삭제 — 시스템분 제외
              variant="danger"
              disabled={!canDelete || asyncAct.isBusy("del")}
              loading={asyncAct.isBusy("del")}
              onClick={() => void asyncAct.run(handleDelete, "del")}
            >
              삭제
            </MesButton>
            <MesButton
              // HWP 설정 export-hist
              variant="secondary"
              disabled={!canModify || asyncAct.isBusy("export")}
              onClick={() => void handleExport()}
            >
              내보내기
            </MesButton>
            <MesButton
              // 설정 이력 불러오기 모달
              variant="secondary"
              disabled={!canModify || asyncAct.isBusy("import-open")}
              onClick={() => void openImportModal()}
            >
              설정불러오기
            </MesButton>
            <MesButton
              // 로컬 파일 rhwp 미리보기 적재
              variant="secondary"
              disabled={!editorReady}
              onClick={handleImportClick}
            >
              로컬열기
            </MesButton>
          </>
        )}
      />

      <input
        // 자사 신규 업로드 — 한글 파일명 유지
        ref={customUploadRef}
        type="file"
        accept=".hwp,.hwpx"
        className="hidden"
        onChange={(event) => void asyncAct.run(async () => { await handleCustomUpload(event); }, "customUpload")}
      />
      <input
        // 로컬열기용 숨은 file input
        ref={localFileRef}
        type="file"
        accept=".hwp,.hwpx"
        className="hidden"
        onChange={(event) => void handleLocalFile(event)}
      />

      <DocFormBody withSummary={false}>
        <DocFormDocumentList label="사용양식 목록">
          <MesEditableGrid
            // 열 설정 저장 키 — 사용양식관리 전용
            persistId="hwp-template-management-list"
            // 서버 템플릿 + 로컬 draft
            rows={templates.rows}
            // 양식코드·양식명·구분·원본파일
            columns={listColumns}
            // 목록 조회 전용 — 셀 편집 없음
            editable={false}
            // 패널 제목 — DocFormDocumentList label과 동일
            title="사용양식 목록"
            // 부모 flex 높이 채움
            height="100%"
            // 목록 조회 중
            loading={listLoading}
            // 선택 양식 키
            activeKey={activeKey}
            // 행 클릭 시 원본 적재
            onActivate={(row) => { void handleSelect(row._key ?? null); }}
            // 잠금·권한 접근 판정
            access={listGrid.access}
            // 잠금 셀 시도 안내
            onLockedAttempt={listGrid.onLockedAttempt}
            // 다중 선택 삭제
            selectable
            onSelectionChange={(rows) => setSelKeys(rows.map((row) => row._key))}
            selectionResetKey={selReset}
            showRowNum
          />
        </DocFormDocumentList>

        <section
          // rhwp 편집 영역 — DocFormMainPanel 대신 overflow-hidden으로 iframe 면적 확보
          aria-label="사용양식 편집"
          className="flex min-h-0 flex-col overflow-hidden rounded border border-slate-200 bg-white"
        >
          <div className="flex items-center gap-2 border-b border-slate-100 px-3 py-1.5 text-xs text-slate-500">
            <span className="font-medium text-slate-700">
              {activeRow?.tmplNm || activeRow?.tmplCd || "양식 미선택"}
            </span>
            <span className="truncate">{editorMessage}</span>
            <span className="ml-auto text-slate-400">
              등록 {allTemplates.length}건
            </span>
          </div>
          <div
            // rhwp createEditor 호스트 — flex-1로 면적 최대
            ref={editorHostRef}
            className="min-h-0 flex-1 bg-slate-50"
          />
        </section>
      </DocFormBody>

      {importOpen ? (
        <div
          // 설정 불러오기 모달 — export-hist HWP
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
          role="dialog"
          aria-modal="true"
          aria-label="HWP 설정 불러오기"
        >
          <div className="flex max-h-[80vh] w-full max-w-lg flex-col gap-3 rounded border border-slate-200 bg-white p-4 shadow-lg">
            <h2 className="text-sm font-semibold text-slate-800">HWP 설정 불러오기</h2>
            <p className="text-xs text-slate-500">서버 표준 또는 내보내기 이력을 선택한 뒤 적용하세요. (양식 파일 바이너리는 볼륨이 정본입니다.)</p>
            <ul className="min-h-0 flex-1 overflow-auto rounded border border-slate-100">
              {importRows.map((row) => {
                const key = row.kind === "SERVER" ? "SERVER" : `HIST-${row.idx}`;
                return (
                  <li key={key}>
                    <button
                      type="button"
                      className={`block w-full px-3 py-2 text-left text-sm ${importActiveKey === key ? "bg-slate-100 font-medium" : "hover:bg-slate-50"}`}
                      onClick={() => setImportActiveKey(key)}
                    >
                      {row.label}
                    </button>
                  </li>
                );
              })}
            </ul>
            <div className="flex justify-end gap-2">
              <MesButton variant="secondary" onClick={() => setImportOpen(false)}>취소</MesButton>
              <MesButton
                variant="save"
                loading={asyncAct.isBusy("import")}
                onClick={() => void applyImport()}
              >
                적용
              </MesButton>
            </div>
          </div>
        </div>
      ) : null}
    </DocFormLayout>
  );
}
