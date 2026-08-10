/**
 * HwpDocumentEditorPage — HWP 일자별 문서 작성·rhwp 편집·저장 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 좌측=기준일 문서 목록(MesEditableGrid) · 중앙 rhwp · 우측 요약 — DB형 DocForm과 동일 계약
 *   2) leaf fixedTmplCd로 양식은 고정하고, 신규는 오늘 기준일 draft 행을 추가한다
 *   3) 양식 파일 자체 수정은 hwp-template-management 화면으로 분리한다
 *
 * PIPELINE[HF84] HWP 문서 편집 화면
 * PIPELINE[HF82, HF123, HF120, HF103] 연관 모듈
 */
// 역할 — 이벤트·상태·DOM 참조·컨텍스트
import { useCallback, useContext, useEffect, useMemo, useRef, useState, type ChangeEvent } from "react";
// 역할 — deep-link ?docIdx=
import { useSearchParams } from "react-router-dom";
// 역할 — 셸이 열어 둔 현재 화면코드(권한·pref 키)
import { PageScrnContext } from "@/shell/pageCommands";
// 역할 — rhwp iframe 에디터 생성·수명 관리 타입
import { createEditor, type RhwpEditor } from "@rhwp/editor";
// 역할 — 화면별 쓰기·수정·삭제·출력 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 비동기 중복 실행 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — 표준 버튼·입력
import { MesButton } from "@/components/ui/MesButton";
import { Input } from "@/components/ui/Input";
// 역할 — 업무 오류·성공 안내
import { mesError, toUserMessage } from "@/shell/errors";
import { mesConfirm, mesConfirmUnsaved, mesToast } from "@/shell/dialog";
import { MES } from "@/shell/messages";
// 역할 — 본인 서명 미등록 시 즉시 업로드
import { uploadMySign } from "@/api/systemApi";
// 역할 — 편집 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — 목록 그리드 잠금(신규만 기준일 편집)
import { useGridAccess } from "@/hooks/useGridAccess";
// 역할 — 그리드 컬럼·편집 행 타입
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
// 역할 — 문서 공통 헤더·레이아웃
import {
  DocFormBody,
  DocFormDocumentList,
  DocFormLayout,
  DocFormSidePanel,
} from "@/components/form/DocFormLayout";
import {
  DocFormSearchToolbar,
  defaultDocFormSearch,
  type DocFormSearchValues,
} from "@/components/form/DocFormSearchToolbar";
// 역할 — HWP 문서·템플릿·첨부 API
import {
  deleteDocument,
  downloadDocumentFile,
  exportDocumentPdf,
  fetchMySignImage,
  getDocumentDetail,
  listDocumentTemplates,
  listDocuments,
  loadHwpTemplateFile,
  saveHwpDocument,
  uploadDocumentFile,
  validateDeleteDocument,
  type DocumentDetail,
  type DocumentListRow,
  type DocumentTemplateRow,
} from "@/api/documentApi";
// 역할 — 상신·검토·승인·반려 공통 툴바
import { DocumentApprovalToolbar } from "@/components/document/DocumentApprovalToolbar";
// 역할 — 문서상태 공통코드
import { useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — rhwp 동일출처 studioUrl·도구상자 조기 접기·더티 감지
import {
  foldRhwpToolboxes,
  installRhwpDirtyListeners,
  installRhwpEarlyFold,
  resolveRhwpStudioUrl,
} from "@/lib/rhwpStudio";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — DocForm 날짜 변환
import { fromInputDate, toInputDate, todayYmd } from "@/lib/docDateTime";
// 역할 — DB형과 동일 draft·목록 세션
import { useDocFormSession, type DocListMeta } from "@/hooks/useDocFormSession";

/** 바이트 단위를 첨부 목록용 텍스트로 바꾼다 */
function fileSize(size?: number | null): string {
  return size == null ? "" : `${(size / 1024).toFixed(1)} KB`;
}

/**
 * 파일명에 쓸 토큰 — 경로·윈도 금지문자·공백을 _ 로 치환한다.
 * 양식명_일자_001.hwpx 의 양식명 부분에 쓴다.
 */
function sanitizeFileToken(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) return "양식";
  return trimmed
    .replace(/[\\/:*?"<>|]/g, "_")
    .replace(/\s+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "")
    || "양식";
}

/**
 * HWP_SRC 표시 파일명 — 양식명_YYYYMMDD_001.hwpx (연번 3자리).
 * 같은 문서 재저장 시 기존 연번을 유지한다.
 */
function buildHwpSrcFileName(
  // 양식 표시명 — 없으면 양식코드
  tmplNm: string,
  // 기준일 YYYYMMDD
  baseDt: string,
  // 연번 1부터 — 001로 패딩
  seq: number,
): string {
  const safeSeq = Number.isFinite(seq) && seq > 0 ? Math.floor(seq) : 1;
  return `${sanitizeFileToken(tmplNm)}_${baseDt}_${String(safeSeq).padStart(3, "0")}.hwpx`;
}

/** 기존 HWP_SRC 파일명에서 _001.hwpx 연번을 읽는다 — 없으면 null */
function parseHwpSrcSeq(fileNm?: string | null): number | null {
  if (!fileNm) return null;
  const m = fileNm.match(/_(\d{3})\.(hwp|hwpx)$/i);
  if (!m) return null;
  const n = Number.parseInt(m[1], 10);
  return Number.isFinite(n) && n > 0 ? n : null;
}

/** 좌측 일자 문서 목록 메타 */
type ListMeta = DocListMeta & {
  // YYYY-MM-DD 표시
  baseDtDisp?: string;
  // 상태 라벨
  statusNm?: string;
};

/** 건별 세션 버퍼 — HWP는 페이지 상태(docIdx·에디터)가 본문, 버퍼는 목록 동기용 */
type Buf = {
  docIdx: number | null;
  baseKey: string;
  tmplCd: string;
};

/** 메뉴 leaf 호환용 props — IA 이후는 PageScrnContext의 scrn_cd를 우선한다 */
export interface HwpDocumentEditorPageProps {
  // 권한 판정용 화면코드 — 없으면 PageScrnContext, 그것도 없으면 레거시 키
  screenCode?: string;
  // 문서작성 leaf별 고정 양식 — visitor-log 등은 이 값으로 양식 고정
  fixedTmplCd?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 좌측 일자 문서 목록·중앙 rhwp·우측 요약을 렌더링한다
 *   2) HWP leaf(visitor-log 등)는 fixedTmplCd로 양식을 고정한다
 *   3) 저장·삭제·원본 부재 실패는 업무 토스트만 표시한다
 */
export default function HwpDocumentEditorPage({
  screenCode: screenCodeProp,
  fixedTmplCd,
}: HwpDocumentEditorPageProps) {
  // 셸 탭의 현재 화면코드 — visitor-log·waste-hwp 등 HWP leaf마다 다르다
  const pageScrnCd = useContext(PageScrnContext);
  // prop > PageScrnContext > 레거시 단독 화면코드
  const screenCode = screenCodeProp || pageScrnCd || "hwp-document-editor";
  const canWrite = useAuthStore((state) => state.can(screenCode, "write") || state.can("hwp-document-editor", "write"));
  const canModify = useAuthStore((state) => state.can(screenCode, "modify") || state.can("hwp-document-editor", "modify"));
  const canDelete = useAuthStore((state) => state.can(screenCode, "delete") || state.can("hwp-document-editor", "delete"));
  // 좌측 문서 목록 — 신규행만 기준일 편집
  const listGrid = useGridAccess({ newOnly: ["baseDtDisp", "baseKey"] }, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });
  const canPrint = useAuthStore((state) => state.can(screenCode, "print") || state.can("hwp-document-editor", "print"));
  const canEditDocument = canWrite || canModify;
  const asyncAct = useAsyncAction();
  const { label: statusLabel } = useCommonCodes("DOC_STATUS");

  const [search, setSearch] = useState<DocFormSearchValues>(() => defaultDocFormSearch());
  const searchRef = useRef(search);
  searchRef.current = search;

  // 양식 메타(원본 URL·표시명) — 좌측 그리드가 아님
  const [templates, setTemplates] = useState<DocumentTemplateRow[]>([]);
  const [tmplMetaLoading, setTmplMetaLoading] = useState(false);

  // 좌측 일자 문서 목록 세션
  const session = useDocFormSession<Buf, ListMeta>();
  const {
    listRows,
    activeKey,
    addDraft,
    selectKey,
    putBuffer,
    getBuffer,
    removeDraft,
    replaceServerList,
  } = session;
  const activeKeyRef = useRef<string | null>(null);
  activeKeyRef.current = activeKey;

  const [tmplCd, setTmplCd] = useState(fixedTmplCd ?? "");
  const [baseDt, setBaseDt] = useState(todayYmd);
  const [docIdx, setDocIdx] = useState<number | null>(null);
  const [detail, setDetail] = useState<DocumentDetail | null>(null);
  const [attachmentFile, setAttachmentFile] = useState<File | null>(null);
  const [listLoading, setListLoading] = useState(false);

  const editorHostRef = useRef<HTMLDivElement>(null);
  const editorRef = useRef<RhwpEditor | null>(null);
  // 서명 미등록 시 파일 선택 — 숨김 input
  const signFileInputRef = useRef<HTMLInputElement>(null);
  // 일자 HWP/HWPX 파일 업로드 — 숨김 input
  const dateHwpFileInputRef = useRef<HTMLInputElement>(null);
  const [editorReady, setEditorReady] = useState(false);
  const [editorMessage, setEditorMessage] = useState("rhwp 에디터가 시작하는 중입니다.");
  // rhwp 편집 더티 — 저장·문서 교체 성공 시 false, 키입력 시 true
  const [editorDirty, setEditorDirty] = useState(false);
  const editorDirtyRef = useRef(false);
  editorDirtyRef.current = editorDirty;

  const docStatus = detail?.header.status ?? (docIdx ? null : "WRK");
  // 상신(REQ) 이후·승인 완료는 잠금 — WRK/RJT/미저장만 편집
  const editableStatus = !docStatus || docStatus === "WRK" || docStatus === "RJT" || docStatus === "TMP";
  const editorLocked = !!docIdx && !editableStatus;
  const editorLockedRef = useRef(editorLocked);
  editorLockedRef.current = editorLocked;
  /**
   * 화면용 상태 — TMP/임시저장 문구 폐기.
   * 미저장·재편집(dirty)=작성중(빨강), 저장완료·clean WRK=파랑, 그 외 결재상태는 공통코드.
   */
  const workStatusKind: "draft" | "saved" | "other" = !docIdx
    ? "draft"
    : (docStatus === "WRK" || docStatus === "TMP" || !docStatus)
      ? (editorDirty ? "draft" : "saved")
      : "other";
  const workStatusText =
    workStatusKind === "draft" ? "작성중"
      : workStatusKind === "saved" ? "저장완료"
        : statusLabel(docStatus ?? "", docStatus ?? "");

  const listColumns = useMemo<GridColumn<ListMeta>[]>(
    () => [
      // 기준일 표시 — YYYY-MM-DD, 신규 draft만 편집
      { field: "baseDtDisp", header: "기준일", width: 120, editableOnNew: true, type: "date" },
      { field: "docNo", header: "문서번호", width: 120 },
      { field: "statusNm", header: "상태", width: 80 },
    ],
    [],
  );

  /** 저장 후 문서 상세와 첨부 목록을 최신 상태로 바꾼다 */
  const loadDetail = useCallback(async (savedDocIdx: number) => {
    try {
      const next = await getDocumentDetail(savedDocIdx);
      setDetail(next);
      setDocIdx(next.header.docIdx);
      setTmplCd(next.header.tmplCd);
      setBaseDt(next.header.baseDt);
      if (activeKeyRef.current) {
        putBuffer(activeKeyRef.current, {
          docIdx: next.header.docIdx,
          baseKey: next.header.baseDt,
          tmplCd: next.header.tmplCd,
        }, {
          docIdx: next.header.docIdx,
          docNo: next.header.docNo,
          status: next.header.status,
          statusNm: statusLabel(next.header.status === "TMP" ? "WRK" : next.header.status, next.header.status),
          baseKey: next.header.baseDt,
          baseDtDisp: toInputDate(next.header.baseDt),
        });
      }
    } catch (error) {
      mesError(error);
    }
  }, [putBuffer, statusLabel]);

  /** ArrayBuffer를 현재 rhwp 편집기에 적재한다 — 호스트가 미저장 가드를 처리하므로 skipUnsavedGuard */
  const loadIntoEditor = useCallback(async (
    // HWP/HWPX 바이너리
    content: ArrayBuffer,
    // 파일명
    fileName: string,
    // true면 성공 토스트 생략
    silent = false,
  ): Promise<boolean> => {
    const editor = editorRef.current;
    if (!editor) {
      if (!silent) mesToast("rhwp 에디터가 준비될 때까지 기다리세요.", "warn");
      return false;
    }
    try {
      const result = await editor.loadFile(content, fileName, {
        // 호스트 mesConfirmUnsaved가 가드 — 스튜디오 중복 확인 방지
        skipUnsavedGuard: true,
        suppressDialogs: true,
      });
      setEditorDirty(false);
      setEditorMessage(`${fileName}을(를) ${result.pageCount} 페이지로 열었습니다.`);
      if (!silent) mesToast("문서를 열었습니다.", "success");
      return true;
    } catch (error) {
      mesError(error);
      return false;
    }
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) dirty일 때 저장/저장안함/취소를 묻고 행 이동 진행 여부를 돌려준다
   *   2) 행 이동·신규·헤더 조회 직전에 호출한다
   *   3) 저장안함만 true(이동). 저장은 저장만 하고 false(행 유지). 취소도 false
   */
  const confirmLeaveIfDirty = useCallback(async (
    // 확인 문구에 넣을 현재 문서/양식 표시명
    fileLabel: string,
    // 저장 선택 시 호출 — 성공해도 행은 이동하지 않는다
    saveFn: () => Promise<boolean>,
  ): Promise<boolean> => {
    // dirty가 아닐 때(= 바로 진행)
    if (!editorDirtyRef.current) return true;
    const choice = await mesConfirmUnsaved(
      `"${fileLabel}" 문서에 저장하지 않은 변경사항이 있습니다.\n계속하기 전에 저장하시겠습니까?`,
    );
    // 취소일 때(= 행 포커스 유지)
    if (choice === "cancel") return false;
    // 저장 안 함일 때(= 변경 버리고 행 이동)
    if (choice === "discard") return true;
    // 저장일 때 — 현재 문서만 저장하고 행은 그대로 둔다
    await saveFn();
    return false;
  }, []);

  /** 템플릿 원본을 formUrl로 읽어 rhwp에 적재한다 */
  const loadTemplateByCd = useCallback(async (
    // 회사 사용 HWP 템플릿 코드
    nextTmplCd: string,
    // true면 성공 토스트 생략
    silent = false,
    // 템플릿 스냅샷 — 상태 반영 전 호출 시 사용
    sourceRows?: DocumentTemplateRow[],
  ): Promise<boolean> => {
    const list = sourceRows ?? templates;
    const template = list.find((row) => row.tmplCd === nextTmplCd);
    if (!template?.formUrl || !template.formFileNm) {
      setEditorMessage("표준 원본 파일이 없습니다. 양식 파일 관리에서 업로드하세요.");
      if (!silent) mesToast("표준 원본 파일이 없습니다. 양식 파일 관리에서 업로드하세요.", "warn");
      return false;
    }
    try {
      return await loadIntoEditor(await loadHwpTemplateFile(template.formUrl), template.formFileNm, silent);
    } catch {
      setEditorMessage("표준 원본 파일이 없습니다. 양식 파일 관리에서 업로드하세요.");
      if (!silent) mesToast("표준 원본 파일이 없습니다. 양식 파일 관리에서 업로드하세요.", "warn");
      return false;
    }
  }, [loadIntoEditor, templates]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 회사 HWP 양식 메타(원본 URL)만 로드한다 — 좌측 그리드용 아님
   *   2) leaf fixedTmplCd가 있으면 그 양식만 남긴다
   *   3) LAW·DB형은 제외한다
   */
  const loadTemplateMeta = useCallback(async () => {
    setTmplMetaLoading(true);
    try {
      const rows = await listDocumentTemplates();
      let next = rows.filter(
        (row) =>
          row.docKind === "HWP"
          && row.categoryCd !== "LAW"
          && !String(row.tmplCd || "").startsWith("LAW_"),
      );
      if (fixedTmplCd) next = next.filter((row) => row.tmplCd === fixedTmplCd);
      setTemplates(next);
      const nextTmpl = fixedTmplCd
        || (next.some((row) => row.tmplCd === tmplCd) ? tmplCd : next[0]?.tmplCd)
        || "";
      if (nextTmpl) setTmplCd(nextTmpl);
    } catch (error) {
      mesError(error);
    } finally {
      setTmplMetaLoading(false);
    }
  }, [fixedTmplCd, tmplCd]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 기간·양식 기준으로 좌측 일자 문서 목록을 채운다
   *   2) 조회·저장·삭제 후 호출한다
   *   3) draft(C) 행은 replaceServerList가 유지한다
   */
  const loadDocList = useCallback(async () => {
    const filterTmpl = fixedTmplCd || tmplCd;
    if (!filterTmpl) {
      replaceServerList([], (row) => String(row.docIdx));
      return;
    }
    const q = searchRef.current;
    setListLoading(true);
    try {
      const server = await listDocuments({
        fromDt: q.fromDt,
        toDt: q.toDt,
        tmplCd: filterTmpl,
        keyword: q.docNo.trim() || undefined,
        writerId: q.writer.trim() || undefined,
      });
      const hwpOnly = server.filter((row) => row.docKind === "HWP" && row.tmplCd === filterTmpl);
      replaceServerList(
        hwpOnly.map((row: DocumentListRow) => ({
          docIdx: row.docIdx,
          docNo: row.docNo,
          status: row.status,
          baseKey: row.baseDt,
          baseDtDisp: toInputDate(row.baseDt),
          statusNm: statusLabel(row.status === "TMP" ? "WRK" : row.status, row.status),
          ngCnt: 0,
        } satisfies ListMeta)),
        (row) => String(row.docIdx),
      );
    } catch (error) {
      mesError(error);
    } finally {
      setListLoading(false);
    }
  }, [fixedTmplCd, replaceServerList, statusLabel, tmplCd]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 메타+HWPX를 서버에 저장하고 dirty를 해제한다
   *   2) 툴바 저장·미저장 확인의 「저장」에서 호출한다
   *   3) 성공이면 true — 실패·권한 없음이면 false
   */
  const saveDocumentCore = useCallback(async (): Promise<boolean> => {
    if (!canEditDocument) {
      mesToast("수정 권한이 없습니다.", "warn");
      return false;
    }
    if (!tmplCd || !baseDt) {
      mesToast("양식과 기준일을 입력하세요.", "warn");
      return false;
    }
    if (!editableStatus) {
      mesToast(MES.inApprovalLocked, "warn");
      return false;
    }
    const editor = editorRef.current;
    if (!editor || !editorReady) {
      mesToast(editorMessage, "warn");
      return false;
    }
    try {
      const saved = await saveHwpDocument({
        docIdx: docIdx ?? undefined,
        tmplCd,
        baseDt,
      });
      // 양식명 — 파일명 앞부분 (코드 대신 표시명)
      const tmplNm = templates.find((row) => row.tmplCd === tmplCd)?.tmplNm || tmplCd;
      // 연번 — 기존 HWP_SRC 유지, 없으면 같은 양식·기준일 문서 순번
      let seq = parseHwpSrcSeq(detail?.files.find((f) => f.fileKind === "HWP_SRC")?.fileNm);
      if (seq == null) {
        const peers = (await listDocuments({
          tmplCd,
          fromDt: baseDt,
          toDt: baseDt,
        }))
          .filter((row) => row.docKind === "HWP" && row.tmplCd === tmplCd && row.baseDt === baseDt)
          .sort((a, b) => a.docIdx - b.docIdx);
        const peerIdx = peers.findIndex((row) => row.docIdx === saved.docIdx);
        seq = peerIdx >= 0 ? peerIdx + 1 : peers.length + 1;
      }
      const fileNm = buildHwpSrcFileName(tmplNm, baseDt, seq);
      const bytes = await editor.exportHwpx();
      const uploadBytes = Uint8Array.from(bytes);
      const file = new File([uploadBytes], fileNm, {
        type: "application/vnd.hancom.hwpx",
      });
      await uploadDocumentFile(saved.docIdx, "HWP_SRC", file);
      try {
        await editor.notifySaved(file.name);
      } catch (notifyError) {
        console.warn("rhwp 저장 완료 통지 실패", notifyError);
      }
      setEditorDirty(false);
      await loadDetail(saved.docIdx);
      mesToast(MES.saveDone, "success");
      return true;
    } catch (error) {
      mesError(error);
      return false;
    }
  }, [baseDt, canEditDocument, detail?.files, docIdx, editableStatus, editorMessage, editorReady, loadDetail, templates, tmplCd]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 저장 문서 idx의 HWP/HWPX 원본을 에디터에 연다
   *   2) 불러오기 모달·적용에서 호출한다
   *   3) 상신 전(WRK/RJT)만 허용 — 그 외는 업무 토스트
   */
  const openSavedDocument = useCallback(async (
    // 열 문서 대리키
    targetDocIdx: number,
    // true면 상신 후에도 열기(잠금 조회). 불러오기 모달은 false
    allowLocked = false,
  ): Promise<boolean> => {
    const next = await getDocumentDetail(targetDocIdx);
    const st = next.header.status === "TMP" ? "WRK" : next.header.status;
    // 상신·결재 진행 중일 때 — 불러오기 모달은 차단, deep-link는 잠금으로 연다
    if (!allowLocked && st !== "WRK" && st !== "RJT") {
      mesToast("상신 전(작성중·반려) 문서만 불러와 수정할 수 있습니다.", "warn");
      return false;
    }
    if (next.header.docKind !== "HWP") {
      mesToast("HWP 문서만 이 화면에서 열 수 있습니다.", "warn");
      return false;
    }
    // HWP_SRC — .hwp / .hwpx 모두 loadFile로 연다
    const hwpSrc = next.files.find((file) => file.fileKind === "HWP_SRC");
    let opened = false;
    if (hwpSrc) {
      const blob = await downloadDocumentFile(hwpSrc.idx);
      opened = await loadIntoEditor(await blob.arrayBuffer(), hwpSrc.fileNm, true);
    } else {
      opened = await loadTemplateByCd(next.header.tmplCd, true);
      if (opened) mesToast("원본 파일이 없어 양식 원본을 열었습니다. 저장 시 HWPX가 등록됩니다.", "warn");
    }
    // 열기 실패일 때
    if (!opened) return false;
    setDetail(next);
    setDocIdx(next.header.docIdx);
    setTmplCd(next.header.tmplCd);
    setBaseDt(next.header.baseDt);
    setEditorDirty(false);
    return true;
  }, [loadIntoEditor, loadTemplateByCd]);

  // 홈·문서함 deep-link — ?docIdx= 가 있고 에디터가 준비되면 1회 연다
  const [searchParams, setSearchParams] = useSearchParams();
  const deepLinkDoneRef = useRef<string | null>(null);
  useEffect(() => {
    const raw = searchParams.get("docIdx");
    if (!raw || !editorReady) return;
    // 같은 docIdx를 이미 처리했을 때
    if (deepLinkDoneRef.current === raw) return;
    const n = Number(raw);
    if (!Number.isFinite(n) || n <= 0) return;
    deepLinkDoneRef.current = raw;
    void (async () => {
      try {
        const ok = await openSavedDocument(n, true);
        if (!ok) deepLinkDoneRef.current = null;
      } catch (error) {
        deepLinkDoneRef.current = null;
        mesError(error);
      } finally {
        // 쿼리를 지워 탭 재진입 시 중복 로드를 막는다
        const next = new URLSearchParams(searchParams);
        next.delete("docIdx");
        setSearchParams(next, { replace: true });
      }
    })();
  }, [editorReady, openSavedDocument, searchParams, setSearchParams]);

  useEffect(() => {
    void loadTemplateMeta();
  // eslint-disable-next-line react-hooks/exhaustive-deps -- leaf 양식 고정 시 1회
  }, [fixedTmplCd]);

  useEffect(() => {
    if (!tmplCd && !fixedTmplCd) return;
    void loadDocList();
  }, [fixedTmplCd, loadDocList, tmplCd]);

  // rhwp 에디터 마운트 — 조기 접기·더티 리스너
  useEffect(() => {
    const host = editorHostRef.current;
    let disposed = false;
    let createdEditor: RhwpEditor | null = null;
    let disposeDirty: (() => void) | undefined;
    if (!host) return undefined;

    // iframe 등장 즉시 도구상자 접기 + visibility 게이트
    const disposeEarlyFold = installRhwpEarlyFold(host);

    void (async () => {
      try {
        createdEditor = await createEditor(host, {
          // 동일출처 스튜디오 — Vite/nginx /rhwp 프록시 (교차출처 CDN이면 도구상자 접기 불가)
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
        // ready 후에도 한 번 더 접기 — SPA 재진입·DOM 재구성 대비
        foldRhwpToolboxes(createdEditor.element);
        disposeDirty = installRhwpDirtyListeners(createdEditor.element, () => {
          // 상신 잠금일 때(= 편집 불가) 더티로 올리지 않음
          if (editorLockedRef.current) return;
          setEditorDirty(true);
        });
        editorRef.current = createdEditor;
        setEditorReady(true);
        setEditorMessage("rhwp 에디터가 준비되었습니다. 좌측에서 문서를 선택하거나 신규를 누르세요.");
      } catch (error) {
        if (!disposed) {
          setEditorMessage(error instanceof Error ? error.message : "rhwp 에디터를 시작하지 못했습니다.");
        }
      }
    })();

    return () => {
      disposed = true;
      disposeEarlyFold();
      disposeDirty?.();
      editorRef.current?.destroy();
      editorRef.current = null;
    };
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 좌측 일자 문서 행을 선택해 저장 문서를 열거나 draft면 양식 원본을 연다
   *   2) 그리드 onActivate에서 호출한다
   *   3) dirty·취소면 전환하지 않는다
   */
  const handleSelectDoc = (key: string | null) =>
    asyncAct.run(async () => {
      if (!key || key === activeKeyRef.current) return;
      const label = detail?.header.docNo
        || templates.find((t) => t.tmplCd === tmplCd)?.tmplNm
        || tmplCd
        || "현재 문서";
      if (!(await confirmLeaveIfDirty(label, saveDocumentCore))) return;
      await selectKey(key, async (k, row) => {
        const cached = getBuffer(k);
        if (cached) {
          if (cached.docIdx) {
            await openSavedDocument(cached.docIdx, true);
          } else {
            setDocIdx(null);
            setDetail(null);
            setBaseDt(cached.baseKey || todayYmd());
            setTmplCd(cached.tmplCd || fixedTmplCd || tmplCd);
            if (editorReady) await loadTemplateByCd(cached.tmplCd || fixedTmplCd || tmplCd, true);
          }
          return cached;
        }
        if (row._rowState === "C" || !row.docIdx) {
          const nextBase = row.baseKey || todayYmd();
          const nextTmpl = fixedTmplCd || tmplCd;
          setDocIdx(null);
          setDetail(null);
          setBaseDt(nextBase);
          setTmplCd(nextTmpl);
          if (editorReady && nextTmpl) await loadTemplateByCd(nextTmpl, true);
          return { docIdx: null, baseKey: nextBase, tmplCd: nextTmpl };
        }
        const ok = await openSavedDocument(row.docIdx, true);
        if (!ok) return null;
        return {
          docIdx: row.docIdx,
          baseKey: row.baseKey,
          tmplCd: fixedTmplCd || tmplCd,
        };
      });
    }, "select");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 오늘 기준일 문서가 있으면 선택하고, 없으면 draft 행을 추가한 뒤 양식 원본을 연다
   *   2) 신규 버튼에서 호출한다
   *   3) 양식 미등록이면 안내만 하고 중단한다
   */
  const handleAdd = () =>
    asyncAct.run(async () => {
      if (!canWrite) {
        mesToast("등록 권한이 없습니다.", "warn");
        return;
      }
      const nextTmpl = fixedTmplCd || tmplCd || templates[0]?.tmplCd || "";
      if (!nextTmpl) {
        mesToast("사용 가능한 HWP 양식이 없습니다.", "warn");
        return;
      }
      const label = detail?.header.docNo
        || templates.find((t) => t.tmplCd === tmplCd)?.tmplNm
        || tmplCd
        || "현재 문서";
      if (!(await confirmLeaveIfDirty(label, saveDocumentCore))) return;
      // 당일 복수 문서 허용 — 기존 당일 행이 있어도 항상 새 draft 를 추가한다
      const today = todayYmd();
      const opened = editorReady ? await loadTemplateByCd(nextTmpl, true) : true;
      if (editorReady && !opened) return;
      setDocIdx(null);
      setDetail(null);
      setTmplCd(nextTmpl);
      setBaseDt(today);
      addDraft(
        {
          docIdx: null,
          docNo: "",
          status: null,
          baseKey: today,
          baseDtDisp: toInputDate(today),
          statusNm: "신규",
          ngCnt: 0,
        },
        { docIdx: null, baseKey: today, tmplCd: nextTmpl },
      );
      if (!editorReady) setEditorMessage("에디터 준비 후 양식 원본을 엽니다.");
      mesToast("신규 작성입니다. 저장하면 문서가 생성됩니다.", "success");
    }, "add");

  /** 메타 저장 + rhwp HWPX 본문 업로드 — 성공 시 좌측 목록 재조회 */
  const handleSave = () =>
    asyncAct.run(async () => {
      const ok = await saveDocumentCore();
      if (ok) await loadDocList();
    }, "save");

  /** 저장된 문서 삭제(validate-delete → delete) — draft면 목록에서만 제거 */
  const handleDelete = () =>
    asyncAct.run(async () => {
      // draft 행일 때(= 미저장) 목록에서만 제거
      if (activeKey && listRows.find((r) => r._key === activeKey)?._rowState === "C") {
        removeDraft(activeKey);
        setDocIdx(null);
        setDetail(null);
        setEditorDirty(false);
        return;
      }
      if (!docIdx) {
        mesToast("삭제할 저장 문서가 없습니다. 신규로 작성 중인 행을 선택하세요.", "warn");
        return;
      }
      if (!canDelete) {
        mesToast("삭제 권한이 없습니다.", "warn");
        return;
      }
      if (docStatus && docStatus !== "WRK" && docStatus !== "RJT") {
        mesToast(MES.approvedDeleteLocked, "warn");
        return;
      }
      const keys = [{ docIdx }];
      try {
        await validateDeleteDocument(keys);
        if (!(await mesConfirm(MES.deleteConfirm(detail?.header.docNo || "문서")))) return;
        await deleteDocument(keys);
        setDocIdx(null);
        setDetail(null);
        setEditorDirty(false);
        await loadDocList();
        if (tmplCd) await loadTemplateByCd(tmplCd, true);
        mesToast(MES.deleteDone, "success");
      } catch (error) {
        mesError(error);
      }
    }, "del");

  /** 일반 첨부 파일을 현재 문서에 연결한다 */
  const handleAttachmentUpload = () =>
    asyncAct.run(async () => {
      if (!docIdx || !attachmentFile) {
        mesToast("저장할 문서와 첨부 파일을 확인하세요.", "warn");
        return;
      }
      try {
        await uploadDocumentFile(docIdx, "ATTACH", attachmentFile);
        setAttachmentFile(null);
        await loadDetail(docIdx);
        mesToast("첨부 파일을 보관했습니다.", "success");
      } catch (error) {
        mesError(error);
      }
    }, "uploadAttachment");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-07
   * 코멘트:
   *   1) 고정 양식(leaf)에서 기준일을 바꾸면 같은 양식·일자의 문서를 찾아 연다
   *   2) 우측 기준일 date input 변경 시 호출한다
   *   3) 없으면 신규(양식 원본) 상태를 유지하고, dirty·취소면 일자를 되돌린다
   */
  const handleBaseDtChange = useCallback(async (
    // 새 기준일 YYYYMMDD
    nextBaseDt: string,
  ) => {
    if (!nextBaseDt || nextBaseDt.length !== 8) return;
    // 잠금 문서일 때(= 상신 후) 기준일 변경 금지
    if (docIdx && !editableStatus) {
      mesToast(MES.inApprovalLocked, "warn");
      return;
    }
    // 고정 양식이 아닐 때(= 양식 선택형) 일자만 갱신
    if (!fixedTmplCd) {
      setBaseDt(nextBaseDt);
      return;
    }
    const label = detail?.header.docNo
      || templates.find((t) => t.tmplCd === tmplCd)?.tmplNm
      || tmplCd
      || "현재 문서";
    if (!(await confirmLeaveIfDirty(label, saveDocumentCore))) return;
    try {
      const peers = (await listDocuments({
        tmplCd: fixedTmplCd,
        fromDt: nextBaseDt,
        toDt: nextBaseDt,
      })).filter((row) => row.docKind === "HWP" && row.tmplCd === fixedTmplCd && row.baseDt === nextBaseDt)
        .sort((a, b) => a.docIdx - b.docIdx);
      // 해당 일자 문서가 있을 때(= 기존 작성분 열기)
      if (peers.length > 0) {
        const ok = await openSavedDocument(peers[0].docIdx, true);
        if (!ok) return;
        await loadDocList();
        await selectKey(String(peers[0].docIdx));
        mesToast("해당 일자의 문서를 열었습니다.", "success");
        return;
      }
      // 없을 때(= 신규 유지) 양식 원본으로 되돌린다
      setBaseDt(nextBaseDt);
      setDocIdx(null);
      setDetail(null);
      setEditorDirty(false);
      if (activeKey) {
        putBuffer(activeKey, { docIdx: null, baseKey: nextBaseDt, tmplCd: fixedTmplCd || tmplCd }, {
          baseKey: nextBaseDt,
          baseDtDisp: toInputDate(nextBaseDt),
          docIdx: null,
          docNo: "",
          statusNm: "신규",
        });
      }
      if (editorReady && (fixedTmplCd || tmplCd)) {
        await loadTemplateByCd(fixedTmplCd || tmplCd, true);
      }
    } catch (error) {
      mesError(error);
    }
  }, [
    activeKey,
    confirmLeaveIfDirty,
    detail?.header.docNo,
    docIdx,
    editableStatus,
    editorReady,
    fixedTmplCd,
    loadDocList,
    loadTemplateByCd,
    openSavedDocument,
    putBuffer,
    saveDocumentCore,
    selectKey,
    templates,
    tmplCd,
  ]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-07
   * 코멘트:
   *   1) 선택한 .hwp/.hwpx를 HWP_SRC로 올린 뒤 에디터에 연다
   *   2) 「일자 파일 업로드」 버튼·숨김 file input에서 호출한다
   *   3) docIdx 없으면 메타 저장 후 업로드, 있으면 덮어쓴다
   */
  const handleDateHwpFileSelected = (
    // 숨김 input change — HWP/HWPX 1건
    event: ChangeEvent<HTMLInputElement>,
  ) => {
    const file = event.target.files?.[0] ?? null;
    event.target.value = "";
    if (!file) return;
    void asyncAct.run(async () => {
      if (!canEditDocument) {
        mesToast("수정 권한이 없습니다.", "warn");
        return;
      }
      if (!tmplCd || !baseDt) {
        mesToast("양식과 기준일을 입력하세요.", "warn");
        return;
      }
      if (!editableStatus) {
        mesToast(MES.inApprovalLocked, "warn");
        return;
      }
      const lower = file.name.toLowerCase();
      if (!lower.endsWith(".hwp") && !lower.endsWith(".hwpx")) {
        mesToast("HWP 또는 HWPX 파일만 업로드할 수 있습니다.", "warn");
        return;
      }
      try {
        let targetDocIdx = docIdx;
        // 미저장일 때(= docIdx 없음) 메타만 먼저 만들어 파일 자리를 확보
        if (!targetDocIdx) {
          const saved = await saveHwpDocument({ tmplCd, baseDt });
          targetDocIdx = saved.docIdx;
          setDocIdx(targetDocIdx);
        }
        await uploadDocumentFile(targetDocIdx, "HWP_SRC", file);
        const opened = await loadIntoEditor(await file.arrayBuffer(), file.name, true);
        await loadDetail(targetDocIdx);
        if (opened) {
          setEditorDirty(false);
          mesToast("일자 파일을 업로드했습니다.", "success");
        }
      } catch (error) {
        mesError(error);
      }
    }, "dateHwpUpload");
  };

  /** 서버 rhwp CLI로 최신 HWP_SRC를 PDF로 변환·보관한다 */
  const handleExportPdf = () =>
    asyncAct.run(async () => {
      if (!docIdx) {
        mesToast("문서를 먼저 저장하세요.", "warn");
        return;
      }
      const hasHwpSrc = detail?.files.some((file) => file.fileKind === "HWP_SRC");
      if (!hasHwpSrc) {
        mesToast("PDF로 변환할 HWPX 본문을 먼저 저장하세요.", "warn");
        return;
      }
      try {
        await exportDocumentPdf(docIdx);
        await loadDetail(docIdx);
        mesToast("PDF를 보관했습니다.", "success");
      } catch (error) {
        mesError(error);
      }
    }, "exportPdf");

  /** 서버 인증을 유지한 Blob 다운로드를 브라우저 파일 저장으로 연결한다 */
  const handleDownload = async (fileIdx: number, fileName: string) => {
    try {
      const blob = await downloadDocumentFile(fileIdx);
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = fileName;
      anchor.click();
      URL.revokeObjectURL(url);
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 서명 이미지를 클립보드에 넣고 붙여넣기 안내를 띄운다.
   * Clipboard API 실패 시에도 이미지는 받았다는 안내만 한다.
   */
  const copySignBlobToClipboard = async (
    // 서버에서 받은 서명 바이너리 — image/* MIME 권장
    blob: Blob
  ) => {
    const mime = blob.type && blob.type.startsWith("image/") ? blob.type : "image/png";
    const imageBlob = mime === blob.type ? blob : new Blob([blob], { type: mime });
    try {
      await navigator.clipboard.write([new ClipboardItem({ [mime]: imageBlob })]);
      mesToast("서명을 클립보드에 복사했습니다. 편집기에서 붙여넣기 하세요.", "success");
    } catch {
      mesToast("서명 이미지를 받았습니다. 편집기에 붙여넣기(Ctrl+V)로 삽입하세요.", "warn");
    }
  };

  /**
   * 서명 복사 — 등록 서명 이미지를 클립보드에 넣고 편집기 붙여넣기를 안내한다.
   * 미등록(400)이면 숨김 파일 선택으로 즉시 업로드한 뒤 다시 복사한다.
   */
  const handleCopySign = () =>
    asyncAct.run(async () => {
      try {
        const blob = await fetchMySignImage();
        await copySignBlobToClipboard(blob);
      } catch (error) {
        const msg = toUserMessage(error);
        // 서명이 없을 때(= 시스템관리 미등록) 같은 화면에서 이미지 선택·등록
        if (msg.includes("등록된 서명")) {
          mesToast("등록된 서명이 없습니다. 서명 이미지 파일을 선택하세요.", "warn");
          signFileInputRef.current?.click();
          return;
        }
        mesError(error);
      }
    }, "sign");

  /**
   * 서명 파일 선택 완료 — 본인 서명으로 업로드한 뒤 클립보드 복사를 이어 간다.
   */
  const handleSignFileSelected = (
    // 숨김 input change — 이미지 1건
    event: ChangeEvent<HTMLInputElement>
  ) => {
    const file = event.target.files?.[0] ?? null;
    event.target.value = "";
    if (!file) return;
    void asyncAct.run(async () => {
      try {
        // 본인 서명 경로 저장 — tbl_user.sign_path
        await uploadMySign(file);
        const blob = await fetchMySignImage();
        await copySignBlobToClipboard(blob);
      } catch (error) {
        mesError(error);
      }
    }, "sign");
  };

  return (
    <DocFormLayout>
      <input
        // 서명 미등록 시 이미지 선택 — 화면에는 보이지 않음
        ref={signFileInputRef}
        // 파일 입력 — 이미지만
        type="file"
        // png/jpg 등 서명 이미지
        accept="image/png,image/jpeg,image/jpg,image/gif,image/webp"
        // 숨김 — 서명 복사 버튼이 연다
        className="hidden"
        // 선택 완료 시 업로드+복사
        onChange={handleSignFileSelected}
      />
      <input
        // 일자 HWP/HWPX 원본 업로드 — 화면에는 보이지 않음
        ref={dateHwpFileInputRef}
        // 파일 입력
        type="file"
        // HWP·HWPX만
        accept=".hwp,.hwpx,application/x-hwp,application/vnd.hancom.hwp,application/vnd.hancom.hwpx"
        // 숨김 — 「일자 파일 업로드」가 연다
        className="hidden"
        // 선택 완료 시 HWP_SRC 업로드·에디터 적재
        onChange={handleDateHwpFileSelected}
      />
      <DocFormSearchToolbar
        // 기간·문서번호·작성자 — 좌측 일자 문서 목록 조건
        values={search}
        // 조건 부분 갱신
        onChange={(patch) => setSearch((prev) => ({ ...prev, ...patch }))}
        // 조회 = 좌측 문서 목록 재조회
        onSearch={() => void asyncAct.run(loadDocList, "search")}
        // 조회 busy
        searchBusy={asyncAct.isBusy("search") || listLoading || tmplMetaLoading}
        // 액션 busy
        actionBusy={asyncAct.isBusy("save") || asyncAct.isBusy("del") || asyncAct.isBusy("add")}
        // 우측 액션 — 신규/저장/삭제/서명 복사/일자 파일
        actions={(
          <>
            <MesButton
              // 오늘 기준일 draft 추가(당일 복수 허용)
              variant="add"
              disabled={!canWrite || asyncAct.isBusy("add") || editorLocked}
              loading={asyncAct.isBusy("add")}
              onClick={() => void handleAdd()}
            >
              신규
            </MesButton>
            <MesButton
              // 메타+HWPX 저장 — 상신 후에는 잠금
              variant="save"
              disabled={!canEditDocument || !editableStatus || asyncAct.isBusy("save") || editorLocked}
              loading={asyncAct.isBusy("save")}
              onClick={() => void handleSave()}
            >
              저장
            </MesButton>
            <MesButton
              // draft 제거 또는 저장 문서 삭제 — 상신 전만
              variant="danger"
              disabled={
                (!docIdx && !(activeKey && listRows.find((r) => r._key === activeKey)?._rowState === "C"))
                || !editableStatus
                || asyncAct.isBusy("del")
                || editorLocked
              }
              loading={asyncAct.isBusy("del")}
              onClick={() => void handleDelete()}
            >
              삭제
            </MesButton>
            <MesButton
              // 내 서명 이미지 — insertImage 미지원 시 붙여넣기 안내
              variant="secondary"
              disabled={asyncAct.isBusy("sign") || editorLocked}
              loading={asyncAct.isBusy("sign")}
              onClick={() => void handleCopySign()}
            >
              서명 복사
            </MesButton>
            <MesButton
              // 일자별 HWP/HWPX 원본 업로드 — 없으면 메타 저장 후 HWP_SRC
              variant="secondary"
              disabled={!canEditDocument || !editableStatus || editorLocked || asyncAct.isBusy("dateHwpUpload")}
              loading={asyncAct.isBusy("dateHwpUpload")}
              onClick={() => dateHwpFileInputRef.current?.click()}
            >
              일자 파일 업로드
            </MesButton>
          </>
        )}
      />

      {docIdx ? (
        <DocumentApprovalToolbar
          // 저장 후 문서 idx
          docIdx={docIdx}
          // WRK/REQ/REV/APV/RJT
          status={docStatus === "TMP" ? "WRK" : docStatus}
          // 작성자 — 상신·취소만 (검토·승인은 결재함)
          canApprove={canWrite || canModify}
          writerActionsOnly
          // 결재 후 상세 재조회 — 상신 시 잠금·취소 시 해제
          onApproved={() => {
            if (docIdx) void loadDetail(docIdx);
          }}
          // 작성중/저장완료 — 임시저장 문구 사용 안 함
          statusLabel={workStatusText}
          // 상태 배지 숨김 — 우측 요약에만 표시
          showStatus={false}
        />
      ) : null}

      <DocFormBody withSummary>
        <DocFormDocumentList label="문서 목록">
          <MesEditableGrid
            // 열 설정 저장 키 — 일자 문서 목록
            persistId={`hwp-document-list-${screenCode}`}
            // 서버 문서 + draft
            rows={listRows as EditableRow<ListMeta>[]}
            // 기준일·문서번호·상태
            columns={listColumns}
            // 신규행 기준일만 편집
            editable={canWrite || canModify}
            // 패널 제목 — Cold/DocForm과 동일
            title="문서 목록"
            // 부모 flex 높이 채움
            height="100%"
            // 목록 조회·행 전환 중
            loading={listLoading || asyncAct.isBusy("select")}
            // 선택 문서 키
            activeKey={activeKey}
            // 행 클릭 → 일자 문서 오픈
            onActivate={(row) => { void handleSelectDoc(row._key ?? null); }}
            // 신규행 기준일 셀 → baseKey 동기
            onCellChange={(key, field, cellValue) => {
              if (field !== "baseDtDisp") return;
              const next = fromInputDate(String(cellValue ?? ""));
              const prevBuf = getBuffer(key);
              if (!prevBuf) return;
              putBuffer(key, { ...prevBuf, baseKey: next }, {
                baseKey: next,
                baseDtDisp: toInputDate(next),
              });
              if (key === activeKey) {
                setBaseDt(next);
                void asyncAct.run(() => handleBaseDtChange(next), "baseDt");
              }
            }}
            // 잠금·권한 접근 판정
            access={listGrid.access}
            // 잠금 셀 시도 안내
            onLockedAttempt={listGrid.onLockedAttempt}
            showRowNum
          />
        </DocFormDocumentList>

        <section
          // rhwp 편집 영역 — 도구상자는 스튜디오 DOM에서 접음 (호스트 클립 없음)
          aria-label="HWP 문서 편집"
          className="relative flex min-h-0 flex-col overflow-hidden rounded border border-slate-200 bg-white"
        >
          <div
            // rhwp createEditor 호스트 — 패널 전체 높이
            ref={editorHostRef}
            className={cn(
              "min-h-0 flex-1 overflow-hidden bg-slate-50 [&_iframe]:block [&_iframe]:h-full [&_iframe]:w-full [&_iframe]:border-0",
              // 상신·결재 중일 때(= 편집 잠금) 포인터 차단
              editorLocked && "pointer-events-none select-none opacity-80",
            )}
          />
          {editorLocked ? (
            <div
              // 잠금 안내 — 상신 후 수정 불가, 취소로만 해제
              className="pointer-events-none absolute inset-x-0 top-0 z-10 bg-amber-50/95 px-3 py-2 text-center text-xs font-medium text-amber-900"
            >
              상신된 문서는 수정할 수 없습니다. 검토·승인이 시작되기 전에 「취소」하면 다시 수정할 수 있습니다.
            </div>
          ) : null}
        </section>

        <DocFormSidePanel label="문서 요약">
          <div className="space-y-3">
            <div>
              <h2 className="text-xs font-semibold text-slate-700">문서 정보</h2>
              <dl className="mt-1.5 space-y-1.5 rounded bg-slate-50 p-2 text-xs text-slate-600">
                <div className="flex items-center justify-between gap-1">
                  <dt className="text-slate-400">상태</dt>
                  <dd>
                    <span
                      // 작성중=삭제(danger) 틴트, 저장완료=저장(save) 틴트
                      className={cn(
                        "inline-flex items-center rounded-[2px] border px-2 py-0.5 text-xs font-bold",
                        workStatusKind === "draft" && "border-red-200 bg-red-50 text-red-600",
                        workStatusKind === "saved" && "border-blue-200 bg-blue-50 text-blue-600",
                        workStatusKind === "other" && "border-slate-200 bg-slate-100 text-slate-700",
                      )}
                    >
                      {workStatusText}
                    </span>
                  </dd>
                </div>
                <div className="flex justify-between gap-1">
                  <dt className="text-slate-400">번호</dt>
                  <dd className="truncate">{detail?.header.docNo ?? (docIdx ? "-" : "(신규)")}</dd>
                </div>
                <div>
                  <dt className="mb-0.5 text-slate-400">양식</dt>
                  <dd className="font-medium text-slate-800">
                    {templates.find((t) => t.tmplCd === tmplCd)?.tmplNm || tmplCd || "-"}
                  </dd>
                </div>
                <div>
                  <dt className="mb-0.5 text-slate-400">기준일</dt>
                  <dd>
                    <Input
                      // 문서 생성·저장 기준일 — 고정양식이면 일자별 문서 전환
                      type="date"
                      value={toInputDate(baseDt)}
                      onChange={(event) => {
                        const next = fromInputDate(event.target.value);
                        void asyncAct.run(() => handleBaseDtChange(next), "baseDt");
                      }}
                      disabled={(!!docIdx && !editableStatus) || asyncAct.isBusy("baseDt")}
                      className="h-8 w-full"
                    />
                  </dd>
                </div>
                <div>
                  <dt className="mb-0.5 text-slate-400">편집기</dt>
                  <dd className="break-words text-slate-500">
                    {editorLocked
                      ? "상신됨 — 편집 잠금. 「취소」로 작성중으로 되돌릴 수 있습니다."
                      : editorMessage}
                  </dd>
                </div>
              </dl>
            </div>
            <div className="flex flex-col gap-1.5">
              <h2 className="text-xs font-semibold text-slate-700">PDF·첨부</h2>
              <MesButton
                // 서버 rhwp CLI PDF 변환
                variant="secondary"
                size="sm"
                disabled={
                  !docIdx
                  || !canPrint
                  || !detail?.files.some((file) => file.fileKind === "HWP_SRC")
                  || asyncAct.isBusy("exportPdf")
                }
                loading={asyncAct.isBusy("exportPdf")}
                onClick={() => void handleExportPdf()}
                className="w-full"
              >
                PDF 내보내기
              </MesButton>
              <div className="space-y-1.5 rounded bg-slate-50 p-2">
                <Input
                  type="file"
                  onChange={(event: ChangeEvent<HTMLInputElement>) => {
                    setAttachmentFile(event.target.files?.[0] ?? null);
                  }}
                  className="text-xs"
                />
                <MesButton
                  variant="secondary"
                  size="sm"
                  disabled={!docIdx || !attachmentFile || !canEditDocument || editorLocked}
                  loading={asyncAct.isBusy("uploadAttachment")}
                  onClick={() => void handleAttachmentUpload()}
                  className="w-full"
                >
                  첨부 보관
                </MesButton>
              </div>
              <ul className="max-h-40 space-y-1 overflow-auto">
                {!detail || detail.files.length === 0 ? (
                  <li className="text-xs text-slate-400">파일 없음</li>
                ) : (
                  detail.files.map((file) => (
                    <li key={file.idx} className="rounded border border-slate-100 p-1.5 text-xs">
                      <p className="break-all text-slate-700">{file.fileNm}</p>
                      <p className="text-slate-400">{file.fileKind} · {fileSize(file.fileSize)}</p>
                      <MesButton
                        variant="ghost"
                        size="sm"
                        onClick={() => void handleDownload(file.idx, file.fileNm)}
                      >
                        다운로드
                      </MesButton>
                    </li>
                  ))
                )}
              </ul>
            </div>
          </div>
        </DocFormSidePanel>
      </DocFormBody>

    </DocFormLayout>
  );
}
