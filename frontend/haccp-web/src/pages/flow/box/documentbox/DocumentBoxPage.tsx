/**
 * DocumentBoxPage — 통합 문서함·결재 패널 (document-inbox/sign-ready/sign-ok).
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 작성 화면과 같은 SearchArea 로 일자·문서번호·작성자를 조회하고 타입 필터를 얹는다
 *   2) 목록은 MesEditableGrid + 타입(docKind)·상태 배지. 문서함은 조회 전용이다
 *   3) 결재 모드(sign-ready·sign-ok)만 결재 툴바를 낸다. 본문 미리보기는 세 화면 공통
 *      문서함은 체크한 행을 HTML A4 일괄·HWP PDF 건별로 인쇄한다
 *
 * PIPELINE[HF83] DOC 화면
 * PIPELINE[HF187] 문서함 인쇄
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
// 역할 — 페이지 카드·검색 영역·좌우 분할
import { PageCard } from "@/components/layout/PageCard";
import { SearchArea, SearchButton, SearchDateRange, SearchField, SearchSelect } from "@/components/layout/SearchArea";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import { gridHeadClass, pageRootClass, splitPanelClass } from "@/components/layout/pageClasses";
import { searchInputClass } from "@/components/ui/Input";
// 역할 — 표준 버튼
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 인쇄 아이콘
import { Printer } from "lucide-react";
// 역할 — 공통 조회 헤더
import { defaultDocFormSearch, type DocFormSearchValues } from "@/components/form/docFormSearch";
// 역할 — 늦게 온 상세가 최신 선택을 덮지 않게 한다
import { useLatestOnly } from "@/hooks/useLatestOnly";
import { fromInputDate, toDisplayDateOnly, toInputDate } from "@/lib/docDateTime";
// 역할 — 확인 토스트
import { mesToast } from "@/shell/dialog";
// 역할 — 오류 업무 문구
import { mesError } from "@/shell/errors";
// 역할 — 공통 안내 문구
import { MES } from "@/shell/messages";
// 역할 — 셸 조회·인쇄 명령
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — URL ?docIdx= 자동 선택
import { useDocIdxQuery } from "@/hooks/useDocIdxQuery";
import type { EditableRow } from "@/types/editable";
import {
  downloadDocumentFile,
  getDocumentDetail,
  listSignOk,
  listSignReady,
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
// 역할 — 미리보기 펼침·접기·높이 드래그
import { DocumentPreviewPane } from "@/components/document/DocumentPreviewPane";
// 역할 — 결재 단계 순서형 스테퍼 — 첨부화면과 같은 마크업
import { ApprovalLineSteps } from "@/components/document/ApprovalLineSteps";
// 역할 — HTML A4 일괄 인쇄 레이어
import { DocumentPrintLayer, type HtmlPrintJob } from "@/components/document/DocumentPrintLayer";
// 역할 — HWP PDF 건별 인쇄
import { printHwpDocuments } from "@/components/document/printHwpDocuments";
// 역할 — 양식 유형(HWP/HTML) 라벨·판별
import { docKindLabel, isHwpKind } from "@/lib/docKind";
// 역할 — 문서상태 배지 색·코드 — 목록·상세가 같은 톤을 쓴다
import { DOC_STATUS, docStatusBadgeClass } from "@/lib/docStatus";
import {
  DOC_KIND_OPTIONS,
  buildApprovalLineSteps,
  buildListColumns,
  listPersistIdOf,
  scrnCdOf,
  splitKeyOf,
  type DocumentBoxMode,
  type ListRow,
} from "./DocumentBoxRule";
// 역할 — 우측 섹션 제목·사유 칸·파일 카드 (결재첨부와 같다)
import { DocSectionHead } from "@/components/document/DocSectionHead";
import { DocReasonBox } from "@/components/document/DocReasonBox";
import { DocFileList, splitFiles } from "@/components/document/DocFileList";

interface DocumentBoxPageProps {
  /**
   * inbox=작성문서, approval=내 차례, history=내가 결재한 문서.
   * screenRegistry가 화면코드별로 반드시 지정하므로 선택값이 아니다.
   * (구 approvalMode boolean prop은 사용처 0으로 2026-08-10 STEP 01 에서 제거)
   */
  mode: DocumentBoxMode;
}

/** 문서함에 모이는 상태 — 결재까지 끝난 문서 */
const DONE_STATUS = DOC_STATUS.APV;

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 문서함/결재함 공통 화면을 그린다
 *   2) screenRegistry가 mode="inbox"|"approval"|"history" 로 세 화면을 구분해 마운트한다
 *   3) 조회·결재·파일·인쇄 오류는 업무 문구 토스트로 처리한다
 */
export default function DocumentBoxPage({ mode: boxMode }: DocumentBoxPageProps) {
  // 홈 등에서 넘긴 문서 idx — 목록 로드 후 자동 선택
  const openDocIdx = useDocIdxQuery();
  const screenCd = scrnCdOf(boxMode);
  const canWrite = useAuthStore((s) => s.can(screenCd, "write"));
  const canModify = useAuthStore((s) => s.can(screenCd, "modify"));
  const canPrint = useAuthStore((s) => s.can(screenCd, "print"));
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
  // 문서함 인쇄 대상 — 체크한 행만. 행 클릭(상세)과 별개다
  const [printSel, setPrintSel] = useState<ListRow[]>([]);
  // HTML 일괄 인쇄 작업 — null 이면 레이어를 안 그린다
  const [htmlPrintJobs, setHtmlPrintJobs] = useState<HtmlPrintJob[] | null>(null);
  // HWP 인쇄 대기열 — HTML 인쇄가 끝난 뒤 이어서 찍는다
  const hwpQueueRef = useRef<number[]>([]);

  const listColumns = useMemo(() => buildListColumns(statusCodeMap), [statusCodeMap]);

  const listRows = useMemo<ListRow[]>(
    () => rows.map((row) => ({
      ...row,
      _key: String(row.docIdx),
      docKindNm: docKindLabel(row.docKind),
      writerDisp: row.writerNm || row.writerId || "",
    })),
    [rows],
  );

  const lineSteps = useMemo(
    () => buildApprovalLineSteps(
      detail?.approvals ?? [],
      roleLabel,
      resultLabel,
      toDisplayDateOnly,
    ),
    [detail?.approvals, resultLabel, roleLabel],
  );

  const fileSplit = useMemo(() => splitFiles(detail?.files ?? []), [detail?.files]);

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
        // 결재대기 — BE에서 내 차례만. keyword=문서번호, writerId=작성자
        list = await listSignReady({
          fromDt: q.fromDt,
          toDt: q.toDt,
          keyword: q.docNo.trim() || undefined,
          writerId: q.writer.trim() || undefined,
        });
      } else if (boxMode === "history") {
        // 결재완료 — 내가 처리한 문서
        list = await listSignOk({
          fromDt: q.fromDt,
          toDt: q.toDt,
          keyword: q.docNo.trim() || undefined,
          writerId: q.writer.trim() || undefined,
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
      setPrintSel([]);
    } catch (e) {
      mesError(e);
    } finally {
      setListLoading(false);
    }
  }, [boxMode]);

  const beginDetail = useLatestOnly();

  /**
   * 문서 상세·결재·첨부를 갱신.
   *
   * 강조와 상세를 **따로** 바꾼다 — 강조는 동기, 상세는 응답이 와야 바뀐다.
   * 그 사이 다른 행을 누르면 좌측은 새 행인데 우측 지면과 결재 툴바는 옛 문서다.
   * 툴바가 `detail.header.docIdx` 로 승인을 걸기 때문에 그 창에서 승인하면
   * **보고 있던 문서가 아니라 옛 문서가 승인된다.** 그래서 최신 적재만 상세를 쓴다.
   *
   * 적재 중에는 우측을 비운다. 옛 문서를 띄워 둔 채 기다리면 그게 곧 오승인의 미끼다.
   */
  const loadDetail = useCallback(async (row: DocumentListRow) => {
    const isLatest = beginDetail();
    setSelected(row);
    setListActiveKey(String(row.docIdx));
    setDetail(null);
    try {
      const next = await getDocumentDetail(row.docIdx);
      if (!isLatest()) return;
      setDetail(next);
    } catch (e) {
      if (isLatest()) mesError(e);
    }
  }, [beginDetail]);

  useEffect(() => {
    void loadList();
  }, [loadList]);

  /*
   * deep-link ?docIdx= — 목록에 있으면 상세를 **한 번만** 연다.
   *
   * openDocIdx 는 URL 이 살아 있는 동안 계속 같은 값이라, 표식이 없으면
   * 목록이 다시 읽힐 때마다(조회·인쇄·첨부·결재 뒤 loadList) 이 효과가 또 터져
   * 사용자가 고른 다른 문서를 말없이 처음 그 문서로 되돌린다.
   * 결재첨부에서는 입력 중이던 비고까지 서버 값으로 덮였다.
   */
  const openedDeepLink = useRef<number | null>(null);
  useEffect(() => {
    if (openDocIdx == null || rows.length === 0) return;
    if (openedDeepLink.current === openDocIdx) return;
    const row = rows.find((r) => r.docIdx === openDocIdx);
    if (!row) return;
    openedDeepLink.current = openDocIdx;
    void loadDetail(row);
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

  /**
   * 개발자: 박승우
   * 일자: 2026-09-03
   * 코멘트:
   *   1) 대기 중인 HWP 문서를 건별 PDF 인쇄한다
   *   2) HTML 일괄 인쇄가 끝난 뒤, 또는 HTML 이 없을 때 바로 호출한다
   *   3) 한 건 실패는 토스트만 하고 다음 건을 이어 간다
   */
  const runHwpPrintQueue = useCallback(async () => {
    const queue = hwpQueueRef.current;
    hwpQueueRef.current = [];
    if (queue.length === 0) return;
    await printHwpDocuments(queue, (error) => { mesError(error); });
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-09-03
   * 코멘트:
   *   1) 체크한 행을 HTML 일괄 인쇄와 HWP PDF 인쇄로 나눈다
   *   2) 문서함 인쇄 버튼·셸 print 명령이 호출한다
   *   3) 선택이 없으면 안내만. 인쇄 중이면 useAsyncAction 이 두 번째를 막는다
   */
  const handlePrint = useCallback(async () => {
    if (boxMode !== "inbox") return;
    if (!canPrint) {
      mesToast("인쇄 권한이 없습니다.", "warn");
      return;
    }
    if (printSel.length === 0) {
      mesToast(MES.selectRow, "warn");
      return;
    }
    const htmlJobs: HtmlPrintJob[] = printSel
      .filter((row) => !isHwpKind(row.docKind))
      .map((row) => ({ docIdx: row.docIdx, tmplCd: row.tmplCd, tmplNm: row.tmplNm }));
    hwpQueueRef.current = printSel.filter((row) => isHwpKind(row.docKind)).map((row) => row.docIdx);
    if (htmlJobs.length > 0) {
      setHtmlPrintJobs(htmlJobs);
      return;
    }
    await runHwpPrintQueue();
  }, [boxMode, canPrint, printSel, runHwpPrintQueue]);

  /**
   * 개발자: 박승우
   * 일자: 2026-09-03
   * 코멘트:
   *   1) HTML 인쇄 레이어가 끝나면 HWP 대기열을 이어 찍는다
   *   2) DocumentPrintLayer onDone
   *   3) 구양식을 뺀 건수는 안내만 한다
   */
  const handleHtmlPrintDone = useCallback((skipped: number) => {
    setHtmlPrintJobs(null);
    if (skipped > 0) {
      mesToast(`미리보기가 없는 양식 ${skipped}건은 인쇄에서 뺐습니다.`, "warn");
    }
    void asyncAct.run(runHwpPrintQueue, "print", mesError);
  }, [asyncAct, runHwpPrintQueue]);

  usePageCommands({
    // 세 화면 모두 조회 전용 — 셸 삭제 명령을 붙이지 않는다
    search: () => { void asyncAct.run(loadList, "search"); },
    // 문서함만 인쇄 — 체크한 행. 결재 2화면은 인쇄 버튼을 내지 않는다
    print: boxMode === "inbox" && canPrint
      ? () => { void asyncAct.run(handlePrint, "print", mesError); }
      : undefined,
  });

  return (
    <div className={pageRootClass}>
      {htmlPrintJobs ? (
        <DocumentPrintLayer
          // 체크한 HTML 문서 — A4 Paper 를 쌓아 window.print()
          jobs={htmlPrintJobs}
          // 대화상자가 닫히면 HWP 대기열로 이어 간다
          onDone={handleHtmlPrintDone}
        />
      ) : null}
      <PageCard
        search={(
          <SearchArea
            // 조회 — 검색조건으로 좌측 목록을 다시 읽는다. 이 영역은 검색 전용이다
            onSearch={() => void asyncAct.run(loadList, "search")}
            actions={(
              <div className="flex items-end gap-1.5">
                {boxMode === "inbox" && canPrint ? (
                  <MesButton
                    // 체크한 문서 인쇄 — HTML A4 일괄, HWP 는 PDF 건별
                    variant="excel"
                    icon={Printer}
                    loading={asyncAct.isBusy("print") || htmlPrintJobs != null}
                    disabled={asyncAct.isBusy("print") || htmlPrintJobs != null}
                    onClick={() => { void asyncAct.run(handlePrint, "print", mesError); }}
                  >
                    인쇄
                  </MesButton>
                ) : null}
                <SearchButton loading={listLoading || asyncAct.isBusy("search")} />
              </div>
            )}
          >
            <SearchDateRange
              // 일자 — YYYYMMDD 상태를 input[type=date] 로 변환한 구간 검색
              label="일자"
              from={toInputDate(search.fromDt)}
              to={toInputDate(search.toDt)}
              onFrom={(v) => setSearch((prev) => ({ ...prev, fromDt: fromInputDate(v) }))}
              onTo={(v) => setSearch((prev) => ({ ...prev, toDt: fromInputDate(v) }))}
            />
            <SearchField label="문서번호">
              <input
                // 문서번호 부분검색 — SP ILIKE
                className={searchInputClass}
                value={search.docNo}
                placeholder="문서번호"
                onChange={(event) => setSearch((prev) => ({ ...prev, docNo: event.target.value }))}
              />
            </SearchField>
            <SearchField label="작성자">
              <input
                // 작성자 ID·이름 부분검색
                className={searchInputClass}
                value={search.writer}
                placeholder="ID 또는 이름"
                onChange={(event) => setSearch((prev) => ({ ...prev, writer: event.target.value }))}
              />
            </SearchField>
            {boxMode === "inbox" ? (
              <SearchSelect
                // 양식 유형 — HWP/HTML/전체. 바꾸면 즉시 조회
                label="타입"
                value={docKind}
                onChange={setDocKind}
              >
                {DOC_KIND_OPTIONS.map((opt) => (
                  <option key={opt.value || "ALL"} value={opt.value}>{opt.label}</option>
                ))}
              </SearchSelect>
            ) : null}
          </SearchArea>
        )}
      >
        <ResizableSplit
          // 좌 목록 50 · 우 상세 50 — 작성 화면과 같은 프레임
          orientation="horizontal"
          // 비율 저장 키 — 문서함/결재대기/결재완료가 화면마다 따로 기억한다
          storageKey={splitKeyOf(boxMode)}
          // 좌 기본 50 — 가로 분할은 30 또는 50만
          defaultPrimaryPct={50}
          // 드래그 하한 — 목록이 안 보이게 접히지 않게
          minPct={25}
          // 드래그 상한 — 상세가 안 보이게 접히지 않게
          maxPct={75}
          className="mes-page-split min-h-0 h-full flex-1 gap-0"
          primary={(
            <div className={splitPanelClass}>
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
            // 문서함만 체크박스 — 인쇄 대상. 결재 2화면은 단건 미리보기만
            selectable={boxMode === "inbox"}
            // 체크 변경 — 인쇄 대상 행. 조회 후 비운다
            onSelectionChange={boxMode === "inbox" ? (picked) => setPrintSel(picked as ListRow[]) : undefined}
            showRowNum
          />
            </div>
          )}
          secondary={(
            <div className={splitPanelClass}>
              {/* 바깥 패널은 overflow-hidden. 상세만 스크롤한다 */}
              <div className="min-h-0 flex-1 overflow-auto">
          {!detail ? (
            <div className="flex h-full items-center justify-center text-sm text-slate-400">
              목록에서 문서를 선택하세요.
            </div>
          ) : (
            <div className="space-y-5">
              <section className="border-b border-slate-100 pb-3">
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <h2
                        // 문서 제목은 양식명 그대로. 작성 목록 title 은 언제·무엇을 썼는지 식별용이라 여기 안 넣는다
                        className="min-w-0 text-base font-semibold text-slate-800"
                      >
                        {detail.header.tmplNm || detail.header.title}
                      </h2>
                      <span
                        // 제목 옆 상태 — 결재첨부와 같다. 좌측 목록 배지와 같은 색. 줄바꿈하지 않는다
                        className={`shrink-0 rounded border px-2 py-1 text-xs font-medium ${docStatusBadgeClass(detail.header.status)}`}
                      >
                        {statusLabel(detail.header.status, detail.header.status ?? "")}
                      </span>
                      {/*
                        * 미조치 개선조치 건수 — sp_sign_ready_r_000 가 세어 보내는데
                        * 어느 화면도 안 그려서 결재자가 「이 문서에 안 끝난 조치가 있는지」를 몰랐다.
                        * 막지는 않는다 — 조치는 문서보다 늦게 끝나는 것이 정상이다. 보이기만 한다.
                        */}
                      {(selected?.openCaCnt ?? 0) > 0 ? (
                        <span
                          className="shrink-0 rounded border border-amber-300 bg-amber-50 px-2 py-1 text-xs font-medium text-amber-700"
                          title="이 문서에서 나온 개선조치 중 아직 끝나지 않은 건수입니다"
                        >
                          미조치 {selected?.openCaCnt}
                        </span>
                      ) : null}
                    </div>
                    <p className="mt-1 text-xs text-slate-500">
                      {detail.header.docNo} · {isHwpKind(detail.header.docKind) ? "한글 문서형" : "DB 입력형"} · 작성자 {detail.header.writerNm || detail.header.writerId || "-"}
                      {/*
                        * 상신일·보존기한은 서버가 상세에 늘 실어 보내는데 그리는 자리가 없었다.
                        * 결재자가 「언제 올라온 것인지」를 목록으로 돌아가서 봐야 했다.
                        */}
                      {detail.header.writeDt ? ` · 상신 ${toDisplayDateOnly(detail.header.writeDt)}` : ""}
                      {detail.header.retentionUntil ? ` · 보존 ~${toDisplayDateOnly(detail.header.retentionUntil)}` : ""}
                    </p>
                  </div>
                  <div className="flex shrink-0 flex-wrap items-center gap-2">
                    {boxMode !== "inbox" && (
                      <DocumentApprovalToolbar
                        // 선택 문서 idx — 없으면 결재 버튼 숨김
                        docIdx={detail.header.docIdx}
                        // WRK/REQ/APV/RJT
                        status={detail.header.status}
                        // 결재 2화면만 여기 온다 — 수정 권한이 있으면 결재한다
                        canApprove={canWrite || canModify}
                        // 이 화면은 작성자가 아니다 — 전송·전송취소는 결재첨부 몫
                        writerActionsOnly={false}
                        // 결재완료(sign-ok) 에서만 본인 결재를 되돌리는 「취소」를 낸다
                        approverUndo={boxMode === "history"}
                        // 결재 후 목록·상세 재조회
                        onApproved={() => {
                          void loadList();
                          if (selected) void loadDetail(selected);
                        }}
                        // 헤더 배지와 같은 상태 문구를 툴바에 다시 두지 않는다
                        showStatus={false}
                      />
                    )}
                  </div>
                </div>
              </section>

              <DocumentPreviewPane
                // HWP 는 호스트 높이 고정, HTML 은 원본 길이만큼 펼친다
                kind={isHwpKind(detail.header.docKind) ? "hwp" : "html"}
              >
                <ApprovalDocumentPreview
                  // 선택 문서 1건만 그린다 — 목록 전체를 미리 그리지 않는다
                  docIdx={detail.header.docIdx}
                  tmplCd={detail.header.tmplCd}
                  tmplNm={detail.header.tmplNm}
                  // hwp:rhwp 본문 · html:작성 지면
                  docKind={detail.header.docKind}
                  // HWP 본문(HWP_SRC)을 찾는 데 쓴다
                  files={detail.files}
                  // 문서 상태 — 승인 직후 같은 docIdx 여도 지면 도장을 다시 읽는다
                  status={detail.header.status}
                />
              </DocumentPreviewPane>

              <ApprovalLineSteps
                // 실제 결재 단계 — 첨부화면과 같은 점·선 스테퍼
                steps={lineSteps}
              />

              <section>
                <DocSectionHead title="원본 파일" />
                <DocFileList
                  // 최신 HWP_SRC 1건 + PDF — 다운로드만
                  files={fileSplit.originals}
                  onDownload={(fileIdx, name) => void handleDownload(fileIdx, name)}
                  emptyHint={
                    isHwpKind(detail.header.docKind)
                      ? "원본 파일이 없습니다."
                      : "HTML 지면 문서 — 미리보기에서 확인"
                  }
                />
              </section>

              <section>
                <DocSectionHead title="첨부 파일" />
                <DocFileList
                  // 사용자 첨부(ATTACH·PHOTO)
                  files={fileSplit.attachments}
                  onDownload={(fileIdx, name) => void handleDownload(fileIdx, name)}
                  emptyHint="첨부 파일이 없습니다."
                />
              </section>

              {(detail.header.rejectReason ?? "").trim() ? (
                <section>
                  <DocSectionHead
                    // 반려는 예외 상태 — 파란 배지와 구분해 빨강
                    title="반려 사유"
                    danger
                  />
                  <DocReasonBox value={(detail.header.rejectReason ?? "").trim()} />
                </section>
              ) : null}

              {(detail.header.cancelReason ?? "").trim() ? (
                <section>
                  <DocSectionHead
                    title="결재 취소 사유"
                    danger
                  />
                  <DocReasonBox value={(detail.header.cancelReason ?? "").trim()} />
                </section>
              ) : null}
            </div>
          )}
              </div>
            </div>
          )}
        />
      </PageCard>
    </div>
  );
}
