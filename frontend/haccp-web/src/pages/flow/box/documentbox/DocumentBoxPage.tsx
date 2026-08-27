/**
 * DocumentBoxPage — 통합 문서함·결재 패널 (document-inbox/sign-ready/sign-ok).
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 공통 DocFormSearchToolbar로 기간·문서번호·작성자를 조회하고 타입 필터를 얹는다
 *   2) 목록은 MesEditableGrid + 타입(docKind)·상태 배지. 문서함은 조회 전용이다
 *   3) 결재 모드(sign-ready·sign-ok)만 결재 툴바를 낸다. 본문 미리보기는 세 화면 공통
 *
 * PIPELINE[HF83] DOC 화면
 * PIPELINE[HF82, HF29, HF39, HF56, HF120] 연관 모듈
 */
// 역할 — 상태·콜백·계산·메모
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 인증 사용자·화면 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 비동기 중복 실행 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — mes-web형 목록 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — SoPage형 그리드 패널 헤더(보이는 그리드명)
import { gridHeadClass } from "@/components/layout/pageClasses";
// 역할 — 표준 버튼
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 공통 조회 헤더
import {
  DocFormSearchToolbar,
  defaultDocFormSearch,
  type DocFormSearchValues,
} from "@/components/form/DocFormSearchToolbar";
// 역할 — 오류 업무 문구
import { mesError } from "@/shell/errors";
// 역할 — 셸 조회 명령
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — URL ?docIdx= 자동 선택
import { useDocIdxQuery } from "@/hooks/useDocIdxQuery";
import type { EditableRow } from "@/types/editable";
import {
  downloadDocumentFile,
  getDocumentDetail,
  listApprovalHistory,
  listApprovalInbox,
  listDocuments,
  type DocumentDetail,
  type DocumentListRow,
} from "@/api/documentApi";
// 역할 — 문서상태·결재 역할/결과 공통코드
import { useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — 공통 결재 툴바 — 결재 2화면만
import { DocumentApprovalToolbar } from "@/components/document/DocumentApprovalToolbar";
// 역할 — 결재 대상 문서 본문 미리보기 (HWP/HTML 분기는 이 컴포넌트가 한다)
import { ApprovalDocumentPreview } from "@/components/document/ApprovalDocumentPreview";
// 역할 — 양식 유형(HWP/HTML) 라벨·판별
import { docKindLabel, isHwpKind } from "@/lib/docKind";
// 역할 — 문서상태 배지 색 — 목록·상세가 같은 톤을 쓴다
import { docStatusBadgeClass } from "@/lib/docStatus";
import {
  APPR_HIST_PERSIST_ID,
  DOC_KIND_OPTIONS,
  buildApprColumns,
  buildListColumns,
  fileSize,
  listPersistIdOf,
  scrnCdOf,
  type ApprRow,
  type DocumentBoxMode,
  type ListRow,
} from "./DocumentBoxRule";

interface DocumentBoxPageProps {
  /**
   * inbox=작성문서, approval=내 차례, history=내가 결재한 문서.
   * screenRegistry가 화면코드별로 반드시 지정하므로 선택값이 아니다.
   * (구 approvalMode boolean prop은 사용처 0으로 2026-08-10 STEP 01 에서 제거)
   */
  mode: DocumentBoxMode;
}

/** 문서함에 모이는 상태 — 결재까지 끝난 문서 */
const DONE_STATUS = "APV";

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 문서함/결재함 공통 화면을 그린다
 *   2) screenRegistry가 mode="inbox"|"approval"|"history" 로 세 화면을 구분해 마운트한다
 *   3) 조회·결재·파일 오류는 업무 문구 토스트로 처리한다
 */
export default function DocumentBoxPage({ mode: boxMode }: DocumentBoxPageProps) {
  // 홈 등에서 넘긴 문서 idx — 목록 로드 후 자동 선택
  const openDocIdx = useDocIdxQuery();
  const screenCd = scrnCdOf(boxMode);
  const canWrite = useAuthStore((s) => s.can(screenCd, "write"));
  const canModify = useAuthStore((s) => s.can(screenCd, "modify"));
  const asyncAct = useAsyncAction();
  const { codeMap: statusCodeMap, label: statusLabel } = useCommonCodes("DOC_STATUS");
  const { label: roleLabel } = useCommonCodes("APPR_ROLE");
  const { label: resultLabel } = useCommonCodes("APPR_RESULT");

  // 공통 검색 — 기간·문서번호·작성자 (조회 클릭 시 반영)
  const [search, setSearch] = useState<DocFormSearchValues>(() => defaultDocFormSearch());
  const searchRef = useRef(search);
  searchRef.current = search;
  // 화면 추가 필터 — 타입 (문서함만). 상태는 승인완료 고정이라 필터를 두지 않는다
  const [docKind, setDocKind] = useState("");
  const docKindRef = useRef(docKind);
  docKindRef.current = docKind;

  const [rows, setRows] = useState<DocumentListRow[]>([]);
  const [selected, setSelected] = useState<DocumentListRow | null>(null);
  const [detail, setDetail] = useState<DocumentDetail | null>(null);
  const [listLoading, setListLoading] = useState(false);
  const [listActiveKey, setListActiveKey] = useState<string | null>(null);
  const [selReset, setSelReset] = useState(0);

  const listColumns = useMemo(() => buildListColumns(statusCodeMap), [statusCodeMap]);

  const apprColumns = useMemo(() => buildApprColumns(), []);

  const listRows = useMemo<ListRow[]>(
    () => rows.map((row) => ({
      ...row,
      _key: String(row.docIdx),
      docKindNm: docKindLabel(row.docKind),
      writerDisp: row.writerNm || row.writerId || "",
    })),
    [rows],
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
        // 문서함 — 결재까지 끝난 문서만 모아 보는 보관함이다. 진행 중 문서는 결재 화면에서 본다
        list = await listDocuments({
          fromDt: q.fromDt,
          toDt: q.toDt,
          keyword: q.docNo.trim() || undefined,
          writerId: q.writer.trim() || undefined,
          status: DONE_STATUS,
        });
      }
      let next = list;
      if (boxMode === "inbox" && kind) next = next.filter((row) => row.docKind === kind);
      setRows(next);
      setSelReset((n) => n + 1);
    } catch (e) {
      mesError(e);
    } finally {
      setListLoading(false);
    }
  }, [boxMode]);

  /** 문서 상세·결재·첨부를 갱신 */
  const loadDetail = useCallback(async (row: DocumentListRow) => {
    try {
      setSelected(row);
      setListActiveKey(String(row.docIdx));
      setDetail(await getDocumentDetail(row.docIdx));
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

  usePageCommands({
    // 세 화면 모두 조회 전용 — 셸 삭제 명령을 붙이지 않는다
    search: () => { void asyncAct.run(loadList, "search"); },
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
        ) : undefined}
        // 조회 전용 — 행추가·저장·삭제를 내지 않는다
        showCrudActions={false}
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
            persistId={listPersistIdOf(boxMode)}
            // 문서 목록 행 — camelCase·라벨 필드
            rows={listRows as EditableRow<ListRow>[]}
            // 타입·기준일·양식·문서번호·제목·작성자·상태 배지
            columns={listColumns}
            // 목록만 조회 — 편집 금지
            editable={false}
            /*
             * 빈 목록일 때 왜 비었는지 말해 준다.
             * 문서함은 승인완료(APV)만 담고 결재이력은 내가 처리한 것만 담는데,
             * 안내가 없어서 「작성한 문서가 사라졌다」로 읽혔다 — 실제로 그렇게 보고가 올라왔다
             */
            emptyHint={
              /*
               * 「없다」를 「고장났다」로 읽히게 쓰면 안 된다.
               * 앞 문구가 「결재선의 승인자를 확인하세요」로 시작해서,
               * 방금 본인이 승인해 비어 있는 정상 상태를 실무 검증에서
               * 「팀장 결재 길이 끊겼다」로 결론지은 일이 있었다.
               * 정상 상태를 먼저 말하고, 확인은 조건을 붙여 뒤에 둔다.
               */
              boxMode === "approval"
                ? "지금 결재할 문서가 없습니다. 방금 승인했다면 결재완료에서 볼 수 있습니다."
                  + " 올라온 문서가 있는데도 비어 있으면 그 문서의 결재선 승인자를 확인하세요."
                : boxMode === "history" ? "내가 처리한 결재 이력이 없습니다."
                  : "승인이 끝난(결재완료) 문서만 보입니다. 작성중·승인요청 문서는 작성 화면이나 결재첨부에 있습니다."
            }
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
                  <span
                    // 좌측 목록 배지와 같은 색 — 상태를 두 곳에서 다르게 보여 주지 않는다
                    className={`rounded border px-2 py-1 text-xs font-medium ${docStatusBadgeClass(detail.header.status)}`}
                  >
                    {statusLabel(detail.header.status, detail.header.status ?? "")}
                  </span>
                </div>
                {boxMode !== "inbox" && (
                  <div className="mt-3 space-y-2">
                    <DocumentApprovalToolbar
                      // 선택 문서 idx — 없으면 결재 버튼 숨김
                      docIdx={detail.header.docIdx}
                      // WRK/REQ/REV/APV/RJT
                      status={detail.header.status}
                      // 결재 2화면만 여기 온다 — 수정 권한이 있으면 결재한다
                      canApprove={canWrite || canModify}
                      // 결재완료 — 상신·취소만 / 결재대기 — 검토·승인·반려
                      writerActionsOnly={boxMode !== "approval"}
                      // 결재완료(sign-ok) 에서만 본인 결재를 되돌리는 「취소」를 낸다
                      approverUndo={boxMode === "history"}
                      // 대기 단계 역할 — 검토 단계면 「승인」이 REVIEW 를 보낸다
                      pendingRoleCd={detail.approvals.find((step) => step.resultCd === "W")?.roleCd}
                      // 결재 후 목록·상세 재조회
                      onApproved={() => {
                        void loadList();
                        if (selected) void loadDetail(selected);
                      }}
                      // 헤더 배지와 같은 상태 문구를 툴바에 다시 두지 않는다
                      showStatus={false}
                    />
                  </div>
                )}
              </section>

              {(
                <section className="flex min-h-0 flex-col overflow-hidden rounded border border-slate-100">
                  <div className={gridHeadClass}>
                    {/* 보이는 그리드명 — 본문을 확인하는 자리 */}
                    <b>문서 미리보기</b>
                  </div>
                  <div className="h-[32rem] min-h-0 overflow-auto">
                    <ApprovalDocumentPreview
                      // 선택 문서 1건만 그린다 — 목록 전체를 미리 그리지 않는다
                      docIdx={detail.header.docIdx}
                      tmplCd={detail.header.tmplCd}
                      tmplNm={detail.header.tmplNm}
                      // hwp:rhwp 본문 · html:작성 지면
                      docKind={detail.header.docKind}
                      // HWP 본문(HWP_SRC)을 찾는 데 쓴다
                      files={detail.files}
                    />
                  </div>
                </section>
              )}

              <section className="flex min-h-0 flex-col overflow-hidden rounded border border-slate-100">
                <div className={gridHeadClass}>
                  {/* 보이는 그리드명 — title prop과 동일 */}
                  <b>결재 이력</b>
                </div>
                <div className="h-48 min-h-0 overflow-hidden">
                  <MesEditableGrid
                    // 결재 이력 그리드 설정 키
                    persistId={APPR_HIST_PERSIST_ID}
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
                <h3 className="mb-2 text-sm font-semibold text-slate-700">첨부 파일</h3>
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
