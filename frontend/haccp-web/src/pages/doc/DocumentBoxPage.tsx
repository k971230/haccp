/**
 * DocumentBoxPage — 통합 문서함·결재 패널 (document-inbox/approval-inbox).
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 공통 DocFormSearchToolbar로 기간·문서번호·작성자를 조회하고 타입·상태 필터를 얹는다
 *   2) 목록은 MesEditableGrid selectable + 타입(docKind) 컬럼으로 값을 camelCase 정규화해 표시한다
 *   3) 결재함 모드에서는 REQ/REV만 남기고 문서 작성·삭제는 숨긴다
 *
 * PIPELINE[HF83] DOC 화면
 * PIPELINE[HF82, HF29, HF39, HF56, HF120] 연관 모듈
 */
// 역할 — 상태·콜백·계산·메모
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 화면 이동 (문서 등록 진입)
import { useNavigate } from "react-router-dom";
// 역할 — 인증 사용자·화면 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 비동기 중복 실행 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — mes-web형 목록 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — SoPage형 그리드 패널 헤더(보이는 그리드명)
import { gridHeadClass } from "@/components/layout/pageClasses";
// 역할 — 표준 버튼·입력
import { MesButton } from "@/components/ui/MesButton";
import { Input } from "@/components/ui/Input";
// 역할 — 공통 조회 헤더
import {
  DocFormSearchToolbar,
  defaultDocFormSearch,
  type DocFormSearchValues,
} from "@/components/form/DocFormSearchToolbar";
// 역할 — 토스트·확인
import { mesConfirmDanger, mesToast } from "@/shell/dialog";
// 역할 — 오류 업무 문구
import { mesError } from "@/shell/errors";
// 역할 — 공통 메시지
import { MES } from "@/shell/messages";
// 역할 — 셸 조회·삭제 명령
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — 화면 경로·문서 작성 deep-link
import { routeOf } from "@/shell/tabRoute";
import { routeForDocument } from "@/lib/documentNav";
// 역할 — URL ?docIdx= 자동 선택
import { useDocIdxQuery } from "@/hooks/useDocIdxQuery";
// 역할 — 그리드 컬럼·행 타입
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
// 역할 — 문서 API·타입
import {
  deleteDocument,
  downloadDocumentFile,
  getDocumentDetail,
  listApprovalHistory,
  listApprovalInbox,
  listDocuments,
  uploadDocumentFile,
  validateDeleteDocument,
  type DocumentDetail,
  type DocumentListRow,
} from "@/api/documentApi";
// 역할 — 문서 관계 목록·고정 관계 저장 API
import { listDocumentRelations, saveDocumentRelation, type WorkflowRow } from "@/api/taskWorkflowApi";
// 역할 — 문서상태·결재 역할/결과 공통코드
import { useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — 공통 결재 툴바
import { DocumentApprovalToolbar } from "@/components/document/DocumentApprovalToolbar";
// 역할 — Blob URL 해제 대기 — 파일 API 타임아웃과 동일
import { API_TIMEOUT_FILE_MS } from "@/config/envConfig";
// 역할 — 양식 유형(hwp/html) 정규화·라벨 — DB 정본은 소문자
import { DOC_KIND_HTML, DOC_KIND_HWP, docKindLabel, isHwpKind, toDocKind } from "@/lib/docKind";

/** byte → 사람이 읽는 크기 */
function fileSize(size?: number | null): string {
  if (size == null) return "";
  return `${(size / 1024).toFixed(1)} KB`;
}

/** 양식 타입 라벨 — value는 DB 정본 소문자(hwp/html) */
const DOC_KIND_OPTIONS = [
  { value: "", label: "전체" },
  { value: DOC_KIND_HTML, label: "DB형" },
  { value: DOC_KIND_HWP, label: "한글형" },
] as const;

/** 문서함 / 결재함 / 결재이력 */
export type DocumentBoxMode = "inbox" | "approval" | "history";

interface DocumentBoxPageProps {
  /**
   * inbox=작성문서, approval=내 차례, history=내가 결재한 문서.
   * screenRegistry가 화면코드별로 반드시 지정하므로 선택값이 아니다.
   * (구 approvalMode boolean prop은 사용처 0으로 2026-08-10 STEP 01 에서 제거)
   */
  mode: DocumentBoxMode;
}

type ListRow = DocumentListRow & {
  _key: string;
  statusNm?: string;
  docKindNm?: string;
  writerDisp?: string;
};

type ApprRow = DocumentDetail["approvals"][number] & {
  _key: string;
  roleNm?: string;
  resultNm?: string;
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 문서함/결재함 공통 화면을 그린다
 *   2) screenRegistry가 mode="inbox"|"approval"|"history" 로 세 화면을 구분해 마운트한다
 *   3) 조회·결재·파일 오류는 업무 문구 토스트로 처리한다
 */
export default function DocumentBoxPage({ mode: boxMode }: DocumentBoxPageProps) {
  const navigate = useNavigate();
  // 홈 등에서 넘긴 문서 idx — 목록 로드 후 자동 선택
  const openDocIdx = useDocIdxQuery();
  const screenCd = boxMode === "approval" ? "approval-inbox" : boxMode === "history" ? "approval-history" : "document-inbox";
  const canWrite = useAuthStore((s) => s.can(screenCd, "write"));
  const canModify = useAuthStore((s) => s.can(screenCd, "modify"));
  const canDelete = useAuthStore((s) => s.can("document-inbox", "delete"));
  const asyncAct = useAsyncAction();
  const { codes: statusCodes, label: statusLabel } = useCommonCodes("DOC_STATUS");
  const { label: roleLabel } = useCommonCodes("APPR_ROLE");
  const { label: resultLabel } = useCommonCodes("APPR_RESULT");

  // 공통 검색 — 기간·문서번호·작성자 (조회 클릭 시 반영)
  const [search, setSearch] = useState<DocFormSearchValues>(() => defaultDocFormSearch());
  const searchRef = useRef(search);
  searchRef.current = search;
  // 화면 추가 필터 — 상태·타입 (문서함만)
  const [status, setStatus] = useState("");
  const [docKind, setDocKind] = useState("");
  const statusRef = useRef(status);
  statusRef.current = status;
  const docKindRef = useRef(docKind);
  docKindRef.current = docKind;

  const [rows, setRows] = useState<DocumentListRow[]>([]);
  const [selected, setSelected] = useState<DocumentListRow | null>(null);
  const [detail, setDetail] = useState<DocumentDetail | null>(null);
  const [uploadKind, setUploadKind] = useState<"ATTACH" | "PHOTO" | "HWP_SRC" | "PDF">("ATTACH");
  const [uploadFile, setUploadFile] = useState<File | null>(null);
  const [relations, setRelations] = useState<WorkflowRow[]>([]);
  const [relationType, setRelationType] = useState("PLAN_REPORT");
  const [relationDocIdx, setRelationDocIdx] = useState("");
  const [listLoading, setListLoading] = useState(false);
  const [listActiveKey, setListActiveKey] = useState<string | null>(null);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);

  const listColumns = useMemo<GridColumn<ListRow>[]>(() => [
    {
      // DB / HWP 구분
      field: "docKindNm",
      header: "타입",
      width: 80,
    },
    { field: "baseDt", header: "기준일", width: 100 },
    { field: "tmplNm", header: "양식", width: 140 },
    { field: "docNo", header: "문서번호", width: 130 },
    { field: "title", header: "제목", width: 160 },
    { field: "writerDisp", header: "작성자", width: 100 },
    { field: "statusNm", header: "상태", width: 90 },
  ], []);

  const apprColumns = useMemo<GridColumn<ApprRow>[]>(() => [
    { field: "roleNm", header: "단계", width: 90 },
    { field: "approverNm", header: "담당자", width: 110 },
    { field: "resultNm", header: "결과", width: 90 },
    { field: "opinion", header: "의견", width: 180 },
  ], []);

  const listRows = useMemo<ListRow[]>(
    () => rows.map((row) => ({
      ...row,
      _key: String(row.docIdx),
      statusNm: statusLabel(row.status, row.status),
      docKindNm: docKindLabel(row.docKind),
      writerDisp: row.writerNm || row.writerId || "",
    })),
    [rows, statusLabel],
  );

  const apprRows = useMemo<ApprRow[]>(
    () => (detail?.approvals ?? []).map((step) => ({
      ...step,
      _key: String(step.idx),
      roleNm: roleLabel(step.roleCd),
      resultNm: resultLabel(step.resultCd),
      approverNm: step.approverNm || step.approverId || "미지정",
    })),
    [detail?.approvals, resultLabel, roleLabel],
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 공통 헤더 조건으로 문서 목록을 조회한다
   *   2) 조회·삭제·결재 후 호출한다
   *   3) 타입(docKind)은 클라이언트 필터, 실패 시 토스트
   */
  const loadList = useCallback(async () => {
    const q = searchRef.current;
    const st = statusRef.current;
    const kind = docKindRef.current;
    setListLoading(true);
    try {
      let list: DocumentListRow[];
      if (boxMode === "approval") {
        // 결재함 — BE에서 내 차례만
        list = await listApprovalInbox({
          fromDt: q.fromDt,
          toDt: q.toDt,
          keyword: q.docNo.trim() || q.writer.trim() || undefined,
        });
      } else if (boxMode === "history") {
        // 결재 이력 — 내가 처리한 문서
        list = await listApprovalHistory({
          fromDt: q.fromDt,
          toDt: q.toDt,
          keyword: q.docNo.trim() || q.writer.trim() || undefined,
        });
      } else {
        list = await listDocuments({
          fromDt: q.fromDt,
          toDt: q.toDt,
          keyword: q.docNo.trim() || undefined,
          writerId: q.writer.trim() || undefined,
          status: st || undefined,
        });
      }
      let next = list;
      if (boxMode === "inbox" && kind) next = next.filter((row) => toDocKind(row.docKind) === kind);
      setRows(next);
      setSelKeys([]);
      setSelReset((n) => n + 1);
    } catch (e) {
      mesError(e);
    } finally {
      setListLoading(false);
    }
  }, [boxMode]);

  /** 문서 상세·결재·첨부·버전을 갱신 */
  const loadDetail = useCallback(async (row: DocumentListRow) => {
    try {
      setSelected(row);
      setListActiveKey(String(row.docIdx));
      setDetail(await getDocumentDetail(row.docIdx));
      setRelations(await listDocumentRelations(row.docIdx));
      setUploadFile(null);
    } catch (e) {
      mesError(e);
    }
  }, []);

  useEffect(() => {
    void loadList();
  }, [loadList]);

  // deep-link ?docIdx= — 목록에 있으면 상세를 연다
  useEffect(() => {
    if (openDocIdx == null || rows.length === 0) return;
    const row = rows.find((r) => r.docIdx === openDocIdx);
    if (row) void loadDetail(row);
  }, [openDocIdx, rows, loadDetail]);

  const editableFile = detail?.header.status === "WRK" || detail?.header.status === "RJT";

  /** 첨부 업로드 */
  const handleUpload = () =>
    asyncAct.run(async () => {
      if (!selected || !uploadFile) {
        mesToast("업로드할 파일을 선택하세요.", "warn");
        return;
      }
      if (!editableFile) {
        mesToast(MES.inApprovalLocked, "warn");
        return;
      }
      try {
        await uploadDocumentFile(selected.docIdx, uploadKind, uploadFile);
        mesToast("파일이 첨부되었습니다.", "success");
        await loadDetail(selected);
      } catch (e) {
        mesError(e);
      }
    }, "upload");

  /** 첨부 다운로드 */
  const handleDownload = async (fileIdx: number, name: string) => {
    try {
      const blob = await downloadDocumentFile(fileIdx);
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = name;
      anchor.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      mesError(e);
    }
  };

  /** 허용된 문서 업무쌍을 현재 문서에서 대상 문서로 연결한다. */
  const handleSaveRelation = () =>
    asyncAct.run(async () => {
      if (!selected || !Number(relationDocIdx)) {
        mesToast("연결할 대상 문서번호를 입력하세요.", "warn");
        return;
      }
      try {
        await saveDocumentRelation(selected.docIdx, relationType, Number(relationDocIdx));
        setRelations(await listDocumentRelations(selected.docIdx));
        setRelationDocIdx("");
        mesToast("관련 문서가 연결되었습니다.", "success");
      } catch (e) {
        mesError(e);
      }
    }, "relation");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 체크 선택 행 또는 활성 행의 HWP 임시·반려 문서를 삭제한다
   *   2) 문서함 삭제 버튼·셸 del에서 호출한다
   *   3) DB형은 양식 화면 삭제를 안내한다
   */
  const handleDelete = () =>
    asyncAct.run(async () => {
      const targets = listRows.filter((row) => selKeys.includes(row._key));
      const focus = targets.length > 0
        ? targets
        : selected
          ? listRows.filter((row) => row.docIdx === selected.docIdx)
          : [];
      if (focus.length === 0) {
        mesToast(MES.selectRow, "warn");
        return;
      }
      const nonHwp = focus.find((row) => !isHwpKind(row.docKind));
      if (nonHwp) {
        mesToast("DB형 문서는 해당 양식 화면에서 삭제하세요.", "warn");
        return;
      }
      try {
        const keys = focus.map((row) => ({ docIdx: row.docIdx }));
        await validateDeleteDocument(keys);
        if (!(await mesConfirmDanger(MES.deleteConfirm(`${focus.length}건`)))) return;
        await deleteDocument(keys);
        mesToast(MES.deleteDone, "success");
        setSelected(null);
        setDetail(null);
        await loadList();
      } catch (e) {
        mesError(e);
      }
    }, "del");

  usePageCommands({
    search: () => { void asyncAct.run(loadList, "search"); },
    del: boxMode === "inbox" ? () => { void handleDelete(); } : undefined,
  });

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 p-3">
      <DocFormSearchToolbar
        // 기간·문서번호·작성자
        values={search}
        // 조건 부분 갱신
        onChange={(patch) => setSearch((prev) => ({ ...prev, ...patch }))}
        // 목록 재조회
        onSearch={() => void asyncAct.run(loadList, "search")}
        // 조회 busy
        searchBusy={listLoading || asyncAct.isBusy("search")}
        // 액션 busy
        actionBusy={asyncAct.isBusy()}
        // 상태·타입 필터 — 문서함만
        extraFilters={boxMode === "inbox" ? (
          <>
            <label className="flex flex-col gap-1 text-xs text-slate-600">
              상태
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value)}
                className="h-mes-input rounded-mes border border-slate-300 bg-white px-2 text-sm"
              >
                <option value="">전체</option>
                {statusCodes.filter((c) => c.subCd !== "TMP").map((code) => (
                  <option key={code.subCd} value={code.subCd}>{code.codeNm}</option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1 text-xs text-slate-600">
              타입
              <select
                value={docKind}
                onChange={(e) => setDocKind(e.target.value)}
                className="h-mes-input rounded-mes border border-slate-300 bg-white px-2 text-sm"
              >
                {DOC_KIND_OPTIONS.map((opt) => (
                  <option key={opt.value || "ALL"} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </label>
          </>
        ) : undefined}
        // 문서함: 작성·삭제 / 결재함·이력: 안내
        actions={boxMode === "inbox" ? (
          <>
            <MesButton
              // HWP 문서 작성 화면
              variant="add"
              onClick={() => navigate(routeOf("handover-hwp"))}
            >
              신규
            </MesButton>
            <MesButton
              // 저장은 양식·상세에서 — 목록 헤더 자리만 맞춤
              variant="save"
              disabled
            >
              저장
            </MesButton>
            <MesButton
              // 체크/선택 HWP 문서 삭제
              variant="danger"
              disabled={!canDelete || asyncAct.isBusy("del")}
              onClick={() => void handleDelete()}
            >
              삭제
            </MesButton>
          </>
        ) : (
          <span className="text-xs text-slate-400">
            {boxMode === "approval" ? "내 결재 대기" : "내가 처리한 결재"}
          </span>
        )}
      />

      <div className="grid min-h-0 flex-1 grid-cols-1 gap-3 lg:grid-cols-[minmax(340px,42%)_1fr]">
        <section className="flex min-h-0 flex-1 flex-col overflow-hidden rounded border border-slate-200 bg-white p-2">
          <div className={gridHeadClass}>
            {/* 보이는 그리드명 — title prop과 동일 */}
            <b>
              {boxMode === "approval" ? "결재 대기 목록"
                : boxMode === "history" ? "결재 이력"
                  : "문서 목록"}
            </b>
          </div>
          <MesEditableGrid
            // 열 설정 저장 키 — 문서함/결재함/이력 분리
            persistId={
              boxMode === "approval" ? "doc-approval-inbox"
                : boxMode === "history" ? "doc-approval-history"
                  : "doc-document-inbox"
            }
            // 문서 목록 행 — camelCase·라벨 필드
            rows={listRows as EditableRow<ListRow>[]}
            // 타입·기준일·양식·문서번호·제목·작성자·상태
            columns={listColumns}
            // 목록만 조회 — 편집 금지
            editable={false}
            // 패널 제목
            title={
              boxMode === "approval" ? "결재 대기 목록"
                : boxMode === "history" ? "결재 이력"
                  : "문서 목록"
            }
            // 부모 flex 높이 채움
            height="100%"
            // 목록 조회 중
            loading={listLoading || asyncAct.isBusy("search")}
            // 선택 문서 키
            activeKey={listActiveKey}
            // 행 클릭 시 우측 상세 로드
            onActivate={(row) => { void loadDetail(row); }}
            // 다중 선택 체크박스 — 삭제 대상
            selectable
            onSelectionChange={(picked) => setSelKeys(picked.map((row) => row._key))}
            selectionResetKey={selReset}
            showRowNum
          />
        </section>

        <div className="min-h-0 overflow-auto rounded border border-slate-200 bg-white p-3">
          {!detail ? (
            <div className="flex h-full items-center justify-center text-sm text-slate-400">
              목록에서 문서를 선택하세요.
            </div>
          ) : (
            <div className="space-y-5">
              <section className="border-b border-slate-100 pb-3">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <h2 className="text-base font-semibold text-slate-800">{detail.header.title || detail.header.tmplNm}</h2>
                    <p className="mt-1 text-xs text-slate-500">
                      {detail.header.docNo} · {isHwpKind(detail.header.docKind) ? "한글 문서형" : "DB 입력형"} · 작성자 {detail.header.writerNm || detail.header.writerId || "-"}
                    </p>
                  </div>
                  <span className="rounded bg-slate-100 px-2 py-1 text-xs text-slate-700">
                    {statusLabel(detail.header.status, detail.header.status ?? "")}
                  </span>
                </div>
                <div className="mt-3 space-y-2">
                  <DocumentApprovalToolbar
                    // 선택 문서 idx — 없으면 결재 버튼 숨김
                    docIdx={detail.header.docIdx}
                    // WRK/REQ/REV/APV/RJT
                    status={detail.header.status}
                    // 결재함·문서함 쓰기/수정 권한
                    canApprove={canWrite || canModify}
                    // 문서함·이력 — 상신·취소만 / 결재함 — 검토·승인·반려
                    writerActionsOnly={boxMode !== "approval"}
                    // 결재 후 목록·상세 재조회
                    onApproved={() => {
                      void loadList();
                      if (selected) void loadDetail(selected);
                    }}
                    // 상태 라벨 — 공통코드
                    statusLabel={statusLabel(detail.header.status, detail.header.status ?? "")}
                    // 양식 작성 화면으로 — DB형 화면 또는 HWP 에디터
                    onEdit={() => {
                      navigate(routeForDocument({
                        docIdx: detail.header.docIdx,
                        tmplCd: detail.header.tmplCd,
                        docKind: detail.header.docKind,
                      }));
                    }}
                    // PDF/HWP 첨부 미리보기 — 새 탭 Blob URL
                    onPreview={() => {
                      const file = detail.files.find((f) => f.fileKind === "PDF")
                        ?? detail.files.find((f) => f.fileKind === "HWP_SRC")
                        ?? detail.files[0];
                      if (!file) {
                        mesToast("미리볼 첨부 파일이 없습니다.", "warn");
                        return;
                      }
                      void (async () => {
                        try {
                          const blob = await downloadDocumentFile(file.idx);
                          const url = URL.createObjectURL(blob);
                          window.open(url, "_blank", "noopener,noreferrer");
                          window.setTimeout(() => URL.revokeObjectURL(url), API_TIMEOUT_FILE_MS);
                        } catch (e) {
                          mesError(e);
                        }
                      })();
                    }}
                  />
                </div>
              </section>

              <section className="flex min-h-0 flex-col overflow-hidden rounded border border-slate-100">
                <div className={gridHeadClass}>
                  {/* 보이는 그리드명 — title prop과 동일 */}
                  <b>결재 이력</b>
                </div>
                <div className="h-48 min-h-0 overflow-hidden">
                  <MesEditableGrid
                    // 결재 이력 그리드 설정 키
                    persistId="doc-box-approval-history"
                    // 선택 문서 결재 단계 행
                    rows={apprRows as EditableRow<ApprRow>[]}
                    // 단계·담당자·결과·의견
                    columns={apprColumns}
                    // 읽기 전용
                    editable={false}
                    // 소형 이력 표
                    title="결재 이력"
                    // 고정 높이 — 상세 패널 내부
                    height="100%"
                    showRowNum
                  />
                </div>
              </section>

              <section>
                <h3 className="mb-2 text-sm font-semibold text-slate-700">관련 문서</h3>
                <div className="mb-2 flex flex-wrap gap-2">
                  <select value={relationType} onChange={(e) => setRelationType(e.target.value)} className="h-8 rounded border border-slate-300 px-2 text-xs">
                    <option value="PLAN_REPORT">검증계획 → 검증보고</option>
                    <option value="tmpl_admin-edu-plan_LOG">교육계획 → 교육일지</option>
                    <option value="tmpl_prp-calib-target_LOG">검교정대상 → 검교정일지</option>
                    <option value="RECV_INVENTORY">입고검사 → 재고</option>
                  </select>
                  <Input value={relationDocIdx} onChange={(e) => setRelationDocIdx(e.target.value)} placeholder="대상 문서번호" className="w-32" />
                  <MesButton variant="secondary" size="sm" disabled={asyncAct.isBusy("relation")} onClick={() => void handleSaveRelation()}>연결</MesButton>
                </div>
                {relations.map((relation) => (
                  <p key={String(relation.idx)} className="border-t border-slate-100 py-1 text-xs">
                    {String(relation.relType ?? "")}: {String(relation.tgtDocNo ?? "")} {String(relation.tgtTitle ?? "")}
                  </p>
                ))}
              </section>

              <section>
                <h3 className="mb-2 text-sm font-semibold text-slate-700">첨부 파일</h3>
                {editableFile && (
                  <div className="mb-2 flex flex-wrap items-center gap-2 rounded bg-slate-50 p-2">
                    <select
                      value={uploadKind}
                      onChange={(e) => setUploadKind(e.target.value as typeof uploadKind)}
                      className="h-8 rounded border border-slate-300 px-2 text-xs"
                    >
                      <option value="ATTACH">일반첨부</option>
                      <option value="PHOTO">사진</option>
                      <option value="HWP_SRC">HWPX 원본</option>
                      <option value="PDF">PDF</option>
                    </select>
                    <Input
                      type="file"
                      onChange={(e) => setUploadFile(e.target.files?.[0] ?? null)}
                      className="max-w-64"
                    />
                    <MesButton
                      variant="secondary"
                      disabled={!uploadFile || asyncAct.isBusy("upload")}
                      onClick={() => void handleUpload()}
                    >
                      첨부
                    </MesButton>
                  </div>
                )}
                {detail.files.length === 0 ? (
                  <p className="text-xs text-slate-400">첨부 파일이 없습니다.</p>
                ) : (
                  <ul className="space-y-1">
                    {detail.files.map((file) => (
                      <li key={file.idx} className="flex items-center justify-between gap-2 rounded border border-slate-100 px-2 py-1.5 text-xs">
                        <span>{file.fileNm} <span className="text-slate-400">({fileSize(file.fileSize)})</span></span>
                        <MesButton
                          variant="ghost"
                          size="sm"
                          onClick={() => void handleDownload(file.idx, file.fileNm)}
                        >
                          다운로드
                        </MesButton>
                      </li>
                    ))}
                  </ul>
                )}
              </section>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
