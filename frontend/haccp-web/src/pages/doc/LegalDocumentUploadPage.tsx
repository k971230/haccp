/**
 * LegalDocumentUploadPage — 법적서류 유형(좌)·등록 문서(우) M-D.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 좌측은 업로드 유형 CRUD + 템플릿 파일 1건 등록·다운로드이다
 *   2) 우측은 선택 유형의 등록 문서를 다건 행추가·저장·삭제한다
 *   3) 시스템 유형(sysYn=Y)은 삭제 불가, 코드는 신규 행만 입력한다
 *
 * PIPELINE[HF122] 법적서류 업로드
 * PIPELINE[HF83, HF120] 연관 모듈
 */
// 역할 — 상태·효과·파일 입력 참조
import { useCallback, useEffect, useMemo, useRef, useState, type ChangeEvent } from "react";
// 역할 — 화면별 등록·수정·삭제 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 편집 행 상태
import { useEditableRows } from "@/hooks/useEditableRows";
// 역할 — 그리드 잠금 훅
import { useGridAccess } from "@/hooks/useGridAccess";
// 역할 — 편집 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — 패널 헤더 행추가·저장·삭제
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
// 역할 — 표준 버튼(다운로드 — GridCrudButtons와 동일 sm·아이콘)
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 기간·문서번호·작성자 조회 조건
import {
  DocFormSearchToolbar,
  defaultDocFormSearch,
  type DocFormSearchValues,
} from "@/components/form/DocFormSearchToolbar";
// 역할 — mes-web PageCard·제목
import { PageCard } from "@/components/layout/PageCard";
import { PageHead } from "@/components/layout/SearchArea";
// 역할 — SoPage형 루트·패널 헤더·활성 섹션
import { gridHeadClass, gridPanelClass, pageRootClass } from "@/components/layout/pageClasses";
import { useSection } from "@/shell/useSection";
// 역할 — Blob URL revoke 대기
import { API_TIMEOUT_FILE_MS } from "@/config/envConfig";
// 역할 — 문서·템플릿 API
import {
  deleteDocument,
  downloadDocumentFile,
  getDocumentDetail,
  listDocumentTemplates,
  listDocuments,
  loadHwpTemplateFile,
  saveHwpDocument,
  saveHwpTemplateForm,
  uploadDocumentFile,
  validateDeleteDocument,
  type DocumentListRow,
  type DocumentTemplateRow,
} from "@/api/documentApi";
// 역할 — 법적서류 유형 저장·회사 양식 삭제
import {
  deleteCompanyTemplates,
  saveLegalType,
  validateDeleteCompanyTemplates,
} from "@/api/workflowApi";
// 역할 — 중복 클릭 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — 셸 단축키
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — 선택행 우선 삭제
import { resolveRowsForDelete } from "@/shell/resolveDelete";
// 역할 — 오류·확인·토스트·공통 문구
import { mesError } from "@/shell/errors";
import { mesConfirm, mesToast } from "@/shell/dialog";
import { MES } from "@/shell/messages";
// 역할 — 그리드·편집 행 타입
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";

/** 화면코드 — 권한 조회 키 */
const SCREEN_CODE = "legal-document-upload";

/** 좌측 유형 행 — 목록 + formUrl(다운로드) */
type TmplRow = DocumentTemplateRow & {
  formUrl?: string | null;
};

/** 등록 문서 편집 행 — 첨부 표시용 fileNm */
type DocRow = DocumentListRow & {
  fileNm?: string | null;
};

function todayYmd(): string {
  const d = new Date();
  return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}`;
}

/** 법적서류·건강진단 공통 props */
export interface LegalDocumentUploadPageProps {
  // 고정 양식코드 — 없으면 LAW 전체
  fixedTmplCd?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 좌 유형·우 문서 각각의 GridCrudButtons로 M-D CRUD를 분리한다 — 셸 상단 신규·저장·삭제는 등록하지 않는다
 *   2) 좌·우 다운로드는 GridCrudButtons와 같은 MesButton(sm·icon=download)이다
 *   3) legal-document-upload 메뉴에서 마운트하며 실패는 업무 토스트만
 */
export default function LegalDocumentUploadPage({
  fixedTmplCd,
}: LegalDocumentUploadPageProps = {}) {
  const asyncAct = useAsyncAction();
  const sec = useSection();
  const canWrite = useAuthStore((state) => state.can(SCREEN_CODE, "write"));
  const canModify = useAuthStore((state) => state.can(SCREEN_CODE, "modify"));
  const canDelete = useAuthStore((state) => state.can(SCREEN_CODE, "delete"));

  const [search, setSearch] = useState<DocFormSearchValues>(() => defaultDocFormSearch());
  const searchRef = useRef(search);
  searchRef.current = search;

  const tmpls = useEditableRows<TmplRow>("tmplCd");
  const docs = useEditableRows<DocRow>("docIdx");

  const [tmplKey, setTmplKey] = useState<string | null>(fixedTmplCd ?? null);
  const [docKey, setDocKey] = useState<string | null>(null);
  const [tmplSelKeys, setTmplSelKeys] = useState<string[]>([]);
  const [tmplSelReset, setTmplSelReset] = useState(0);
  const [docSelKeys, setDocSelKeys] = useState<string[]>([]);
  const [docSelReset, setDocSelReset] = useState(0);

  // 유형 템플릿 파일 pending — 저장 시 saveHwpTemplateForm
  const pendingTmplFilesRef = useRef<Map<string, File>>(new Map());
  const tmplFilePickKeyRef = useRef<string | null>(null);
  const tmplFileInputRef = useRef<HTMLInputElement>(null);
  // 문서 첨부 pending
  const pendingDocFilesRef = useRef<Map<string, File>>(new Map());
  const docFilePickKeyRef = useRef<string | null>(null);
  const docFileInputRef = useRef<HTMLInputElement>(null);

  const selectedTmpl = tmpls.rows.find((t) => t._key === tmplKey) ?? null;
  // 우측 활성 문서 — 다운로드 활성 조건에 사용
  const selectedDoc = docs.rows.find((d) => d._key === docKey) ?? null;

  const tmplGrid = useGridAccess(
    {
      newOnly: ["tmplCd"],
      alwaysReadonly: ["formFileNm", "sysYn"],
      isRowDeleteLocked: (row) => String(row.sysYn ?? "Y") === "Y",
    },
    {
      scrnCd: SCREEN_CODE,
      gridRole: "master",
      readOnly: !canModify && !canWrite,
      extra: { canWrite, canModify, canDelete },
    },
  );

  const docGrid = useGridAccess(
    {
      newOnly: [],
      alwaysReadonly: ["docNo", "status", "fileCnt", "fileNm"],
    },
    {
      scrnCd: SCREEN_CODE,
      gridRole: "detail",
      readOnly: !canModify && !canWrite,
      parentRow: selectedTmpl?.tmplCd ? { tmplCd: selectedTmpl.tmplCd } : null,
      extra: { canWrite, canModify, canDelete },
    },
  );

  const pickTmplFile = (row: EditableRow<TmplRow>) => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    tmplFilePickKeyRef.current = row._key;
    setTmplKey(row._key);
    sec.setSec("h");
    tmplFileInputRef.current?.click();
  };

  const pickDocFile = (row: EditableRow<DocRow>) => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    docFilePickKeyRef.current = row._key;
    setDocKey(row._key);
    sec.setSec("d");
    docFileInputRef.current?.click();
  };

  const tmplCols = useMemo<GridColumn<TmplRow>[]>(() => {
    const editable = canWrite || canModify;
    return [
      { field: "tmplCd", header: "코드", width: 120, editable, required: true },
      { field: "tmplNm", header: "유형명", width: 160, editable, required: true },
      {
        field: "formFileNm",
        header: "템플릿",
        width: 160,
        editable: false,
        cellButton: editable
          ? {
            title: "템플릿 선택",
            onClick: (row) => pickTmplFile(row as EditableRow<TmplRow>),
            showOnNew: true,
          }
          : undefined,
      },
      {
        field: "sysYn",
        header: "구분",
        width: 80,
        editable: false,
        type: "code",
        codeOptions: [
          { value: "Y", label: "시스템" },
          { value: "N", label: "회사" },
        ],
        codeMap: { Y: "시스템", N: "회사" },
      },
    ];
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canModify, canWrite]);

  const docCols = useMemo<GridColumn<DocRow>[]>(() => {
    const editable = canWrite || canModify;
    return [
      { field: "baseDt", header: "기준일", width: 100, editable, required: true },
      { field: "docNo", header: "문서번호", width: 140, editable: false },
      { field: "title", header: "제목", width: 160, editable },
      {
        field: "fileNm",
        header: "첨부파일",
        width: 180,
        editable: false,
        cellButton: editable
          ? {
            title: "파일 선택",
            onClick: (row) => pickDocFile(row as EditableRow<DocRow>),
            showOnNew: true,
          }
          : undefined,
      },
      { field: "status", header: "상태", width: 80, editable: false },
      { field: "fileCnt", header: "첨부", width: 70, type: "number", editable: false },
    ];
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canModify, canWrite]);

  const loadTemplates = useCallback(async () => {
    try {
      const rows = await listDocumentTemplates();
      const law = rows.filter((r) => {
        if (fixedTmplCd) return r.tmplCd === fixedTmplCd;
        return r.categoryCd === "LAW" || String(r.tmplCd || "").startsWith("LAW_");
      });
      pendingTmplFilesRef.current.clear();
      const mapped = tmpls.loadReturn(law);
      if (fixedTmplCd && mapped.some((r) => r.tmplCd === fixedTmplCd)) {
        setTmplKey(fixedTmplCd);
      } else if (tmplKey && mapped.some((r) => r._key === tmplKey || r.tmplCd === tmplKey)) {
        // keep
      } else if (mapped[0]) {
        setTmplKey(mapped[0]._key);
      } else {
        setTmplKey(null);
      }
    } catch (e) {
      mesError(e);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fixedTmplCd]);

  const loadDocs = useCallback(async () => {
    const q = searchRef.current;
    const tmplCd = selectedTmpl?.tmplCd;
    if (!tmplCd || selectedTmpl?._rowState === "C") {
      pendingDocFilesRef.current.clear();
      docs.load([]);
      return;
    }
    try {
      const list = await listDocuments({
        fromDt: q.fromDt,
        toDt: q.toDt,
        tmplCd,
        keyword: q.docNo.trim() || undefined,
        writerId: q.writer.trim() || undefined,
      });
      pendingDocFilesRef.current.clear();
      docs.load(list.map((r) => ({
        ...r,
        fileNm: Number(r.fileCnt) > 0 ? `첨부 ${r.fileCnt}건` : "",
      })));
      setDocKey(null);
      setDocSelKeys([]);
      setDocSelReset((n) => n + 1);
    } catch (e) {
      mesError(e);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedTmpl?.tmplCd, selectedTmpl?._rowState]);

  useEffect(() => { void loadTemplates(); }, [loadTemplates]);
  useEffect(() => { void loadDocs(); }, [loadDocs]);

  const handleAddTmpl = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    if (tmpls.rows.some((r) => r._rowState === "C")) {
      return mesToast("저장하지 않은 신규 유형이 있습니다.", "warn");
    }
    sec.setSec("h");
    const key = tmpls.addRow({
      tmplCd: "",
      tmplNm: "",
      docKind: "HWP",
      categoryCd: "LAW",
      sysYn: "N",
      formFileNm: "",
      formUrl: "",
    });
    setTmplKey(key);
  };

  const handleSaveTmpl = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    const dirtyMap = new Map(tmpls.getSaveRows().map((row) => [row._key, row]));
    for (const key of pendingTmplFilesRef.current.keys()) {
      if (!dirtyMap.has(key)) {
        const row = tmpls.rows.find((r) => r._key === key);
        if (row) dirtyMap.set(key, row);
      }
    }
    const dirty = [...dirtyMap.values()];
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    for (const row of dirty) {
      if (!String(row.tmplCd ?? "").trim()) {
        mesToast(MES.required("코드"), "warn");
        setTmplKey(row._key);
        return;
      }
      if (!String(row.tmplNm ?? "").trim()) {
        mesToast(MES.required("유형명"), "warn");
        setTmplKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      for (const row of dirty) {
        const code = String(row.tmplCd).trim();
        await saveLegalType({ tmplCd: code, tmplNm: String(row.tmplNm).trim() });
        const pending = pendingTmplFilesRef.current.get(row._key);
        if (pending) {
          await saveHwpTemplateForm(code, pending);
          pendingTmplFilesRef.current.delete(row._key);
        }
      }
      mesToast(MES.saveDone, "success");
      await loadTemplates();
    } catch (e) {
      mesError(e);
    }
  };

  const handleDeleteTmpl = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(tmpls.rows, tmplKey, setTmplKey, tmplSelKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");
    const sysHit = targets.find((row) => String(row.sysYn ?? "Y") === "Y" && row._rowState !== "C");
    if (sysHit) return mesToast("시스템 양식은 삭제할 수 없습니다.", "warn");
    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    let lastFocus = tmplKey;
    for (const row of newRows) {
      pendingTmplFilesRef.current.delete(row._key);
      const { focusKey } = tmpls.removeNewRow(row._key);
      lastFocus = focusKey;
    }
    if (newRows.length > 0) {
      setTmplKey(lastFocus);
      setTmplSelKeys([]);
      setTmplSelReset((n) => n + 1);
    }
    if (persisted.length === 0) return;
    const keys = persisted
      .map((row) => String(row.tmplCd ?? "").trim())
      .filter(Boolean)
      .map((tmplCd) => ({ tmplCd }));
    if (keys.length === 0) return mesToast("삭제할 유형 코드가 올바르지 않습니다.", "warn");
    try {
      await validateDeleteCompanyTemplates(keys);
      if (!(await mesConfirm(MES.deleteConfirm(`${keys.length}건`)))) return;
      await deleteCompanyTemplates(keys);
      mesToast(MES.deleteDone, "success");
      setTmplKey(null);
      setTmplSelKeys([]);
      setTmplSelReset((n) => n + 1);
      await loadTemplates();
    } catch (e) {
      mesError(e);
    }
  };

  const handleDownloadTmpl = () =>
    asyncAct.run(async () => {
      const row = tmpls.rows.find((t) => t._key === tmplKey);
      if (!row?.tmplCd || row._rowState === "C") {
        mesToast("다운로드할 유형을 선택하세요.", "warn");
        return;
      }
      const formUrl = String(row.formUrl ?? "").trim();
      const fileNm = String(row.formFileNm ?? "").trim();
      // 서버에 등록된 템플릿이 없을 때(= formUrl·파일명 없음·선택만 표시) 요청하지 않는다.
      // 문구는 백엔드 404(TemplateFileStorage.FORM_NOT_UPLOADED)와 동일하게 MES.formNotUploaded로 통일
      if (!formUrl || !fileNm || fileNm.startsWith("선택:")) {
        mesToast(MES.formNotUploaded, "warn");
        return;
      }
      try {
        const buf = await loadHwpTemplateFile(formUrl);
        const blob = new Blob([buf]);
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = fileNm;
        a.click();
        setTimeout(() => URL.revokeObjectURL(url), API_TIMEOUT_FILE_MS);
      } catch (e) {
        mesError(e);
      }
    }, "dl");

  const handleAddDoc = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    if (!selectedTmpl?.tmplCd || selectedTmpl._rowState === "C") {
      return mesToast("등록할 양식을 선택·저장하세요.", "warn");
    }
    sec.setSec("d");
    const key = docs.addRow({
      docIdx: null as unknown as number,
      tmplCd: selectedTmpl.tmplCd,
      tmplNm: selectedTmpl.tmplNm,
      docKind: "HWP",
      docNo: "",
      baseDt: todayYmd(),
      title: "",
      status: "",
      verNo: 0,
      fileCnt: 0,
      openCaCnt: 0,
      fileNm: "",
    });
    setDocKey(key);
  };

  const handleSaveDoc = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    if (!selectedTmpl?.tmplCd || selectedTmpl._rowState === "C") {
      return mesToast("등록할 양식을 선택·저장하세요.", "warn");
    }
    const dirtyMap = new Map(docs.getSaveRows().map((row) => [row._key, row]));
    for (const key of pendingDocFilesRef.current.keys()) {
      if (!dirtyMap.has(key)) {
        const row = docs.rows.find((r) => r._key === key);
        if (row) dirtyMap.set(key, row);
      }
    }
    const dirty = [...dirtyMap.values()];
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    for (const row of dirty) {
      if (!String(row.baseDt ?? "").trim()) {
        mesToast(MES.required("기준일"), "warn");
        setDocKey(row._key);
        return;
      }
      const isNew = row._rowState === "C" || row.docIdx == null || Number(row.docIdx) <= 0;
      if (isNew && !pendingDocFilesRef.current.get(row._key)) {
        mesToast("신규 행은 첨부파일을 선택하세요.", "warn");
        setDocKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      for (const row of dirty) {
        const pending = pendingDocFilesRef.current.get(row._key);
        const isNew = row._rowState === "C" || row.docIdx == null || Number(row.docIdx) <= 0;
        const { docIdx } = await saveHwpDocument({
          docIdx: isNew ? undefined : Number(row.docIdx),
          tmplCd: selectedTmpl.tmplCd,
          baseDt: String(row.baseDt).replace(/-/g, ""),
          title: String(row.title ?? "").trim() || (pending?.name ?? ""),
        });
        if (pending) {
          const kind = pending.name.toLowerCase().endsWith(".pdf") ? "PDF" : "HWP_SRC";
          await uploadDocumentFile(docIdx, kind as "PDF" | "HWP_SRC", pending);
          pendingDocFilesRef.current.delete(row._key);
        }
      }
      mesToast(MES.saveDone, "success");
      await loadDocs();
    } catch (e) {
      mesError(e);
    }
  };

  const handleDeleteDoc = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(docs.rows, docKey, setDocKey, docSelKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");
    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    let lastFocus = docKey;
    for (const row of newRows) {
      pendingDocFilesRef.current.delete(row._key);
      const { focusKey } = docs.removeNewRow(row._key);
      lastFocus = focusKey;
    }
    if (newRows.length > 0) {
      setDocKey(lastFocus);
      setDocSelKeys([]);
      setDocSelReset((n) => n + 1);
    }
    if (persisted.length === 0) return;
    const keys = persisted
      .map((row) => Number(row.docIdx))
      .filter((docIdx) => Number.isFinite(docIdx) && docIdx > 0)
      .map((docIdx) => ({ docIdx }));
    if (keys.length === 0) return mesToast("삭제할 문서 키가 올바르지 않습니다.", "warn");
    try {
      await validateDeleteDocument(keys);
      if (!(await mesConfirm(MES.deleteConfirm(`${keys.length}건`)))) return;
      await deleteDocument(keys);
      mesToast(MES.deleteDone, "success");
      setDocKey(null);
      setDocSelKeys([]);
      setDocSelReset((n) => n + 1);
      await loadDocs();
    } catch (e) {
      mesError(e);
    }
  };

  /** 우 문서 첨부 중 대표 파일 1건 — PDF 우선, 없으면 HWP_SRC·첫 파일 */
  const resolveDocFile = async (docIdx: number) => {
    const detail = await getDocumentDetail(docIdx);
    return detail.files.find((x) => x.fileKind === "PDF")
      ?? detail.files.find((x) => x.fileKind === "HWP_SRC")
      ?? detail.files[0]
      ?? null;
  };

  const handleDownloadDoc = () =>
    asyncAct.run(async () => {
      const row = docs.rows.find((d) => d._key === docKey);
      if (!row?.docIdx || Number(row.docIdx) <= 0) {
        mesToast("다운로드할 저장된 문서를 선택하세요.", "warn");
        return;
      }
      // 첨부가 없을 때(= fileCnt 0·선택만 표시) API 호출 전에 안내한다
      const fileNmHint = String(row.fileNm ?? "").trim();
      if (Number(row.fileCnt) <= 0 || fileNmHint.startsWith("선택:")) {
        mesToast("첨부 파일이 없습니다. 파일을 선택한 뒤 저장하세요.", "warn");
        return;
      }
      try {
        const f = await resolveDocFile(Number(row.docIdx));
        if (!f) {
          mesToast("첨부 파일이 없습니다.", "warn");
          return;
        }
        const blob = await downloadDocumentFile(f.idx);
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = String(f.fileNm ?? row.title ?? `doc_${row.docIdx}`).trim() || `doc_${row.docIdx}`;
        a.click();
        setTimeout(() => URL.revokeObjectURL(url), API_TIMEOUT_FILE_MS);
      } catch (e) {
        mesError(e);
      }
    }, "dl-doc");

  const onTmplFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0] ?? null;
    event.target.value = "";
    const key = tmplFilePickKeyRef.current;
    tmplFilePickKeyRef.current = null;
    if (!key || !file) return;
    pendingTmplFilesRef.current.set(key, file);
    tmpls.updateCell(key, "formFileNm", `선택: ${file.name}`);
    setTmplKey(key);
  };

  const onDocFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0] ?? null;
    event.target.value = "";
    const key = docFilePickKeyRef.current;
    docFilePickKeyRef.current = null;
    if (!key || !file) return;
    pendingDocFilesRef.current.set(key, file);
    docs.updateCell(key, "fileNm", `선택: ${file.name}`);
    if (!String(docs.rows.find((r) => r._key === key)?.title ?? "").trim()) {
      docs.updateCell(key, "title", file.name);
    }
    setDocKey(key);
  };

  // 셸 상단은 조회만 — 신규·저장·삭제는 좌·우 GridCrudButtons로만 처리한다
  usePageCommands({
    search: () => { void asyncAct.run(loadDocs, "search"); },
  });

  return (
    <div className={pageRootClass}>
      <PageHead title="법적서류 업로드" />
      <PageCard
        search={(
          <DocFormSearchToolbar
            values={search}
            onChange={(p) => setSearch((prev) => ({ ...prev, ...p }))}
            onSearch={() => void asyncAct.run(loadDocs, "search")}
            searchBusy={asyncAct.isBusy("search")}
          />
        )}
      >
        <div className="grid min-h-0 flex-1 grid-cols-1 gap-3 overflow-hidden lg:grid-cols-[minmax(280px,36%)_1fr] [&>*]:min-h-0">
          <div {...sec.bind("h", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>법적서류 양식</b>
              <div className="flex flex-wrap items-center gap-2">
                <GridCrudButtons
                  run={asyncAct.run}
                  onAdd={canWrite ? handleAddTmpl : undefined}
                  onSave={canWrite || canModify ? handleSaveTmpl : undefined}
                  onDel={canDelete ? handleDeleteTmpl : undefined}
                  busy={{
                    save: asyncAct.isBusy("save") && sec.is("h"),
                    del: asyncAct.isBusy("del") && sec.is("h"),
                  }}
                />
                <MesButton
                  // 행추가·저장·삭제와 동일 sm·아이콘 — download(indigo) 계열로 CSV(emerald)와 구분
                  variant="download"
                  size="sm"
                  icon="download"
                  // 등록된 원본이 없을 때(= formUrl·파일명 없음) 다운로드 비활성 — 빈 GET /form 404 방지
                  disabled={
                    !tmplKey
                    || asyncAct.isBusy("dl")
                    || !String(selectedTmpl?.formUrl ?? "").trim()
                    || !String(selectedTmpl?.formFileNm ?? "").trim()
                    || String(selectedTmpl?.formFileNm ?? "").startsWith("선택:")
                  }
                  // 비활성 이유를 마우스오버로 알린다 — 버튼이 회색인 채로 이유를 못 찾는 상황을 없앤다.
                  // 원본이 있을 때는 title을 비워 기본 커서 동작을 유지한다
                  title={
                    !String(selectedTmpl?.formUrl ?? "").trim()
                      ? MES.formNotUploaded
                      : undefined
                  }
                  loading={asyncAct.isBusy("dl")}
                  onClick={() => void handleDownloadTmpl()}
                >
                  다운로드
                </MesButton>
              </div>
            </div>
            <input
              ref={tmplFileInputRef}
              type="file"
              accept=".hwp,.hwpx,.pdf"
              className="hidden"
              onChange={onTmplFileChange}
            />
            <MesEditableGrid
              persistId="legal-tmpl-list"
              rows={tmpls.rows}
              columns={tmplCols}
              editable={canWrite || canModify}
              title="법적서류 양식"
              height="100%"
              activeKey={tmplKey}
              onActivate={(r) => {
                sec.setSec("h");
                setTmplKey(r._key);
              }}
              onSetActive={() => sec.setSec("h")}
              onCellChange={(key, field, value) => tmpls.updateCell(key, field as keyof TmplRow, value)}
              access={tmplGrid.access}
              onLockedAttempt={tmplGrid.onLockedAttempt}
              loading={asyncAct.isBusy("search")}
              selectable
              onSelectionChange={(rows) => setTmplSelKeys(rows.map((row) => row._key))}
              selectionResetKey={tmplSelReset}
              showRowNum
            />
          </div>
          <div {...sec.bind("d", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>등록 문서</b>
              <div className="flex flex-wrap items-center gap-2">
                <GridCrudButtons
                  run={asyncAct.run}
                  onAdd={canWrite ? handleAddDoc : undefined}
                  onSave={canWrite || canModify ? handleSaveDoc : undefined}
                  onDel={canDelete ? handleDeleteDoc : undefined}
                  busy={{
                    save: asyncAct.isBusy("save") && sec.is("d"),
                    del: asyncAct.isBusy("del") && sec.is("d"),
                  }}
                />
                <MesButton
                  // 행추가·저장·삭제와 동일 sm·아이콘 — download(indigo) 계열로 CSV(emerald)와 구분
                  variant="download"
                  size="sm"
                  icon="download"
                  // 저장된 문서·첨부가 있을 때만 활성 — 좌측 다운로드와 동일 역할
                  disabled={
                    !docKey
                    || asyncAct.isBusy("dl-doc")
                    || !selectedDoc
                    || Number(selectedDoc.docIdx) <= 0
                    || Number(selectedDoc.fileCnt) <= 0
                    || String(selectedDoc.fileNm ?? "").startsWith("선택:")
                  }
                  loading={asyncAct.isBusy("dl-doc")}
                  onClick={() => void handleDownloadDoc()}
                >
                  다운로드
                </MesButton>
              </div>
            </div>
            <input
              ref={docFileInputRef}
              type="file"
              accept=".pdf,.hwp,.hwpx"
              className="hidden"
              onChange={onDocFileChange}
            />
            <MesEditableGrid
              persistId="legal-doc-list"
              rows={docs.rows}
              columns={docCols}
              editable={canWrite || canModify}
              title="등록 문서"
              height="100%"
              activeKey={docKey}
              onActivate={(r) => {
                sec.setSec("d");
                setDocKey(r._key);
              }}
              onSetActive={() => sec.setSec("d")}
              onCellChange={(key, field, value) => docs.updateCell(key, field as keyof DocRow, value)}
              access={docGrid.access}
              onLockedAttempt={docGrid.onLockedAttempt}
              loading={asyncAct.isBusy("search") || asyncAct.isBusy("save")}
              selectable
              onSelectionChange={(rows) => setDocSelKeys(rows.map((row) => row._key))}
              selectionResetKey={docSelReset}
              showRowNum
            />
          </div>
        </div>
      </PageCard>
    </div>
  );
}
