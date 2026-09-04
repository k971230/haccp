/**
 * ApprovalAttachPage — 결재 첨부 (내가 상신한 문서의 첨부·비고·진행상태).
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 좌측은 로그인 사용자가 작성한 문서만 — 서버가 writerId 를 조건으로 걸러 준다
 *   2) 우측은 진행 스테퍼 + 원본 파일(다운만) + 첨부(추가·삭제) + 비고. 스크롤은 하나다. 본문 미리보기는 두지 않는다
 *   3) 버튼은 MesButton 틴트·아이콘. 「초기화」는 검색줄에서 저장하지 않은 화면 변경만 되돌린다
 *
 * 원본(HWP_SRC·PDF)은 시스템이 만든 파일이라 삭제하지 않는다. 사용자 첨부만 전송대기에서 고친다.
 * 비고는 메모라서 결재완료(APV) 직전까지 고칠 수 있다.
 * 「초기화」는 저장하지 않은 비고만 되돌린다. 저장된 첨부는 행마다 있는 「삭제」로만 지운다.
 *
 * PIPELINE[HF185] 결재 첨부 화면
 * PIPELINE[HF82, HF83] 연관 모듈
 */
// 역할 — 상태·콜백·계산
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 로그인 사용자·화면 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 비동기 중복 실행 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — URL ?docIdx= 자동 선택
import { useDocIdxQuery } from "@/hooks/useDocIdxQuery";
// 역할 — 문서상태·결재 역할/결과 공통코드
import { useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — 목록 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — 페이지 카드·검색 영역·좌우 분할
import { PageCard } from "@/components/layout/PageCard";
import { SearchArea, SearchButton, SearchDateRange, SearchField } from "@/components/layout/SearchArea";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import { gridHeadClass, pageRootClass, splitPanelClass } from "@/components/layout/pageClasses";
import { searchInputClass } from "@/components/ui/Input";
// 역할 — 표준 버튼
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 공통 조회 헤더
import { defaultDocFormSearch, type DocFormSearchValues } from "@/components/form/docFormSearch";
import { fromInputDate, toInputDate } from "@/lib/docDateTime";
// 역할 — 확인·토스트
import { mesConfirmDanger, mesToast } from "@/shell/dialog";
// 역할 — 오류 업무 문구
import { mesError } from "@/shell/errors";
// 역할 — 공통 안내 문구
import { MES } from "@/shell/messages";
// 역할 — 셸 조회 명령
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — 작성 화면 이동 (?docIdx= deep-link)
import { useNavigate } from "react-router-dom";
import { routeForDocument } from "@/lib/documentNav";
// 역할 — 편집 행 타입
import type { EditableRow } from "@/types/editable";
// 역할 — 문서 목록·상세·첨부·비고 API
import {
  deleteDocumentFile,
  downloadDocumentFile,
  getDocumentDetail,
  listDocuments,
  saveDocumentRemark,
  uploadDocumentFile,
  type DocumentDetail,
  type DocumentListRow,
} from "@/api/documentApi";
// 역할 — 일자·일시 사용자 표기
import { toDisplayDate } from "@/lib/docDateTime";
// 역할 — 문서상태 코드
import { DOC_STATUS } from "@/lib/docStatus";
// 역할 — 공통 결재 툴바 — 전송·전송취소
import { DocumentApprovalToolbar } from "@/components/document/DocumentApprovalToolbar";
// 역할 — 우측 섹션 제목·사유 칸·파일 카드 (문서함과 같다)
import { DocSectionHead } from "@/components/document/DocSectionHead";
import { DocReasonBox } from "@/components/document/DocReasonBox";
import { DocFileList } from "@/components/document/DocFileList";
// 역할 — 양식코드 → 작성 API (전송 전 필수값 검사에 쓴다)
import { previewEntryOf } from "@/components/document/documentPreviewRegistry";
// 역할 — 상세 → 지면 버퍼 · 전송 필수값 규칙 (작성 화면과 같은 함수)
import { detailToDraftBuf, validateForTransfer } from "@/pages/draft/htmlFormDraftShared";
// 역할 — 파일 크기 표기는 DocFileList 가 맡는다
// 역할 — 화면 상수·컬럼·잠금 판정
import {
  ATTACH_MAX,
  ATTACH_MAX_MSG,
  FILE_PERSIST_ID,
  PERSIST_ID,
  SCRN_CD,
  SPLIT_KEY,
  attachStepperCaption,
  attachStepperOf,
  attachStepperToneClass,
  buildAttachListColumns,
  canEditAttach,
  canEditRemark,
  countUserFiles,
  docStatusBadgeClass,
  splitFiles,
  type AttachListRow,
} from "./ApprovalAttachRule";

/** 비고 글자 상한 — textarea maxLength 와 같다 */
const REMARK_MAX = 500;

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 내가 쓴 문서를 골라 첨부·비고를 관리하고 결재 진행상태를 확인한다
 *   2) 결재 첨부 메뉴에서 연다
 *   3) 조회·업로드·삭제 오류는 업무 문구 토스트로 처리한다
 */
export default function ApprovalAttachPage() {
  const user = useAuthStore((s) => s.user);
  const canWrite = useAuthStore((s) => s.can(SCRN_CD, "write"));
  const canModify = useAuthStore((s) => s.can(SCRN_CD, "modify"));
  const canDelete = useAuthStore((s) => s.can(SCRN_CD, "delete"));
  const asyncAct = useAsyncAction();
  const navigate = useNavigate();
  const openDocIdx = useDocIdxQuery();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { codeMap: statusCodeMap, label: statusLabel } = useCommonCodes("DOC_STATUS");

  // 공통 검색 — 기간·문서번호. 작성자 칸은 쓰지 않는다(항상 본인)
  const [search, setSearch] = useState<DocFormSearchValues>(() => defaultDocFormSearch());
  const searchRef = useRef(search);
  searchRef.current = search;

  const [rows, setRows] = useState<DocumentListRow[]>([]);
  const [selected, setSelected] = useState<DocumentListRow | null>(null);
  const [detail, setDetail] = useState<DocumentDetail | null>(null);
  const [listLoading, setListLoading] = useState(false);
  const [listActiveKey, setListActiveKey] = useState<string | null>(null);
  // 화면 입력 — 저장 전 비고. 「초기화」가 되돌리는 대상이다
  const [remark, setRemark] = useState("");

  const listColumns = useMemo(() => buildAttachListColumns(statusCodeMap), [statusCodeMap]);

  const listRows = useMemo<AttachListRow[]>(
    () => rows.map((row) => ({
      ...row,
      _key: String(row.docIdx),
      statusNm: statusLabel(row.status, row.status),
    })),
    [rows, statusLabel],
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 로그인 사용자가 작성한 문서만 조회한다
   *   2) 조회 버튼·업로드·삭제·비고 저장 후 호출한다
   *   3) writerId 는 화면이 아니라 로그인 사용자에서 온다 — 남의 문서를 조건으로 넣을 수 없다
   */
  const loadList = useCallback(async () => {
    const q = searchRef.current;
    const writerId = user?.userId ?? "";
    // 로그인 정보가 아직 없을 때(= 세션 복구 중) 남의 문서를 통째로 부르지 않는다
    if (!writerId) {
      setRows([]);
      return;
    }
    setListLoading(true);
    try {
      setRows(await listDocuments({
        fromDt: q.fromDt,
        toDt: q.toDt,
        keyword: q.docNo.trim() || undefined,
        writerId,
      }));
    } catch (e) {
      mesError(e);
    } finally {
      setListLoading(false);
    }
  }, [user?.userId]);

  /** 문서 상세·결재단계·첨부를 갱신하고 화면 입력을 서버 값으로 되돌린다 */
  const loadDetail = useCallback(async (row: DocumentListRow) => {
    try {
      setSelected(row);
      setListActiveKey(String(row.docIdx));
      const next = await getDocumentDetail(row.docIdx);
      setDetail(next);
      setRemark(next.header.remark ?? "");
      if (fileInputRef.current) fileInputRef.current.value = "";
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

  const attachEditable = canEditAttach(detail?.header.status) && (canWrite || canModify);
  const remarkEditable = canEditRemark(detail?.header.status) && (canWrite || canModify);
  const userFileCnt = countUserFiles(detail?.files ?? []);
  const fileSplit = useMemo(() => splitFiles(detail?.files ?? []), [detail?.files]);
  const stepper = attachStepperOf(detail?.header.status);
  const approveRow = detail?.approvals.find((s) => s.roleCd === "APPROVE");
  const approverNm = approveRow?.approverNm || approveRow?.approverId || detail?.header.approverNm;

  /** 첨부 업로드 — 파일 고르면 바로 올린다. 상한·잠금을 프론트에서 먼저 본다 */
  const handleUpload = (file: File) =>
    asyncAct.run(async () => {
      if (!selected) return;
      if (!attachEditable) {
        mesToast(MES.inApprovalLocked, "warn");
        return;
      }
      // 상한을 넘을 때(= 이미 5개) 요청을 보내지 않는다. 서버도 같은 기준으로 막는다
      if (userFileCnt >= ATTACH_MAX) {
        mesToast(ATTACH_MAX_MSG, "warn");
        return;
      }
      try {
        await uploadDocumentFile(selected.docIdx, "ATTACH", file);
        mesToast("파일이 첨부되었습니다.", "success");
        await loadDetail(selected);
        await loadList();
      } catch (e) {
        mesError(e);
      }
    }, "upload");

  /** 첨부 삭제 — 저장된 파일을 실제로 지운다. 「초기화」와 다른 동작이다 */
  const handleDeleteFile = (fileIdx: number, name: string) =>
    asyncAct.run(async () => {
      if (!selected || !attachEditable) {
        mesToast(MES.inApprovalLocked, "warn");
        return;
      }
      if (!(await mesConfirmDanger(MES.deleteConfirm(name)))) return;
      try {
        await deleteDocumentFile(fileIdx);
        mesToast(MES.deleteDone, "success");
        await loadDetail(selected);
        await loadList();
      } catch (e) {
        mesError(e);
      }
    }, "delFile");

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

  /** 비고 저장 */
  const handleSaveRemark = () =>
    asyncAct.run(async () => {
      if (!selected || !remarkEditable) {
        mesToast("결재가 완료된 문서의 비고는 고칠 수 없습니다.", "warn");
        return;
      }
      try {
        await saveDocumentRemark(selected.docIdx, remark.trim());
        mesToast(MES.saveDone, "success");
        await loadDetail(selected);
      } catch (e) {
        mesError(e);
      }
    }, "remark");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-25
   * 코멘트:
   *   1) 전송(상신) 전에 지면 필수값을 본다 — 이 화면은 지면을 띄우지 않으므로 상세를 읽어 검사한다
   *   2) 결재 툴바 REQUEST 직전(onBeforeAction)이 호출한다
   *   3) 기준은 작성 화면과 같은 validateForTransfer 한 곳이다. 여기서 규칙을 다시 쓰지 않는다
   *      지면이 없는 양식(HWP·구양식)은 검사 대상이 아니라 통과시킨다
   */
  const findMissingValue = async (row: DocumentListRow): Promise<string | null> => {
    const entry = previewEntryOf(row.tmplCd);
    if (!entry) return null;
    const buf = detailToDraftBuf(
      await entry.api.detail(row.tmplCd, row.docIdx),
      { tmplCd: row.tmplCd, tmplNm: row.tmplNm },
    );
    return validateForTransfer(
      buf.baseKey, buf.items, buf.logRows, true, buf.passRows,
      // 작성 화면과 같은 기준 — 부적합인데 이탈내용이 비면 여기서도 막는다
      { note: buf.specialNote, on: buf.deviationYn },
    );
  };

  /** 초기화 — 저장하지 않은 비고만 되돌린다. DB 첨부는 건드리지 않는다 */
  const handleReset = () => {
    setRemark(detail?.header.remark ?? "");
    if (fileInputRef.current) fileInputRef.current.value = "";
    mesToast("저장하지 않은 변경을 되돌렸습니다.", "success");
  };

  usePageCommands({
    search: () => { void asyncAct.run(loadList, "search"); },
  });

  return (
    <div className={pageRootClass}>
      <PageCard
        search={(
          <SearchArea
            // 조회 — 검색조건으로 좌측 목록을 다시 읽는다. 이 영역은 검색 전용이다
            onSearch={() => void asyncAct.run(loadList, "search")}
            actions={(
              <div className="flex items-end gap-1.5">
                <MesButton
                  // 저장하지 않은 비고·고른 파일만 되돌린다. 조회(blue-100)와 같은 농도 빨간 틴트
                  variant="danger"
                  icon="reset"
                  className="bg-red-100 hover:bg-red-200/80"
                  onClick={handleReset}
                >
                  초기화
                </MesButton>
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
          </SearchArea>
        )}
      >
        <ResizableSplit
          // 좌 내 문서 목록 50 · 우 첨부·비고 50 — 작성 화면과 같은 프레임
          orientation="horizontal"
          // 비율 저장 키 — 결재첨부 화면 고유
          storageKey={SPLIT_KEY}
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
                <b>내 문서 목록</b>
              </div>
              <MesEditableGrid
                // 열 너비·정렬·필터를 저장할 고유 키 — 화면코드 개명과 무관. 바꾸면 사용자 설정이 날아간다
                persistId={PERSIST_ID}
                // 내 문서 목록 행 — 상태 라벨을 더한 camelCase
                rows={listRows as EditableRow<AttachListRow>[]}
                // 기준일·문서번호·양식·제목·결재상태 배지·첨부 수
                columns={listColumns}
                // 목록만 조회 — 편집 금지
                editable={false}
                // 패널 제목 — 좌측 헤더와 같다
                title="내 문서 목록"
                // 부모 flex 높이 채움
                height="100%"
                // 목록 조회 중
                loading={listLoading || asyncAct.isBusy("search")}
                // 선택 문서 키
                activeKey={listActiveKey}
                // 행 클릭 시 우측 상세 로드
                onActivate={(row) => { void loadDetail(row); }}
                showRowNum
                // 반려 행은 노란색 — 작성 목록과 같은 클래스
                rowClassName={(row) => (row.status === DOC_STATUS.RJT ? "mes-row-rejected" : undefined)}
              />
            </div>
          )}
          secondary={(
            <div className={splitPanelClass}>
          {!detail ? (
            <div className="flex h-full items-center justify-center text-sm text-slate-400">
              목록에서 문서를 선택하세요.
            </div>
          ) : (
            <div className="min-h-0 flex-1 overflow-auto p-1">
              <div className="space-y-5">
              <section className="border-b border-slate-100 pb-3">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <h2
                        // 문서 제목은 양식명 그대로. 작성 목록 title 은 언제·무엇을 썼는지 식별용이라 여기 안 넣는다
                        className="text-base font-semibold text-slate-800"
                      >
                        {detail.header.tmplNm || detail.header.title}
                      </h2>
                      <span
                        // 제목 옆 상태 — 좌측 목록 배지와 같은 색
                        className={`rounded border px-2 py-1 text-xs font-medium ${docStatusBadgeClass(detail.header.status)}`}
                      >
                        {statusLabel(detail.header.status, detail.header.status ?? "")}
                      </span>
                    </div>
                    <p className="mt-1 text-xs text-slate-500">
                      문서번호 {detail.header.docNo} | 기준일 {toDisplayDate(detail.header.baseDt)}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <MesButton
                      // 작성화면 — 지면을 고치러 간다. 이 화면에는 지면이 없다
                      variant="add"
                      icon="edit"
                      onClick={() => navigate(routeForDocument({
                        docIdx: detail.header.docIdx,
                        tmplCd: detail.header.tmplCd,
                        docKind: detail.header.docKind,
                      }))}
                    >
                      작성화면
                    </MesButton>
                    <DocumentApprovalToolbar
                      // 선택 문서 idx — 없으면 결재 버튼 숨김
                      docIdx={detail.header.docIdx}
                      // WRK/REQ/APV/RJT
                      status={detail.header.status}
                      // 작성자 화면 — 전송·전송취소만. 승인·반려는 결재대기
                      writerActionsOnly
                      // 작성·수정 권한이 있으면 전송한다
                      canApprove={canWrite || canModify}
                      // 헤더 배지와 같은 상태 문구를 툴바에 다시 두지 않는다
                      showStatus={false}
                      // 전송 전 지면 필수값 — 이 화면은 지면이 없어 상세를 읽어 검사한다
                      onBeforeAction={async (actionCd) => {
                        if (actionCd !== "REQUEST" || !selected) return;
                        const missing = await findMissingValue(selected);
                        if (missing) {
                          mesToast(missing, "warn");
                          return false;
                        }
                      }}
                      // 전송·전송취소 후 목록·상세 재조회
                      onApproved={() => {
                        void loadList();
                        if (selected) void loadDetail(selected);
                      }}
                    />
                  </div>
                </div>
              </section>

              <section>
                <DocSectionHead title="결재 진행상태" />
                <ol className="mt-3 flex items-start">
                  {stepper.steps.map((step, at) => {
                    const vis = attachStepperToneClass(step.tone);
                    // 결재 칸 아래 — 끝나면 결재자명. 작성·전송은 「완료」, 반려면 「반려」
                    const sub = attachStepperCaption(step, approverNm);
                    return (
                      <li key={step.key} className={`flex min-w-0 ${at === 0 ? "flex-none" : "flex-1"}`}>
                        {at > 0 ? (
                          <span
                            // 앞 칸과 잇는 선 — 이 칸의 색과 같게
                            className={`mt-2 h-0.5 flex-1 ${vis.line}`}
                          />
                        ) : null}
                        <div className="flex w-16 flex-none flex-col items-center">
                          <span className={`h-4 w-4 rounded-full ${vis.dot}`} />
                          <span className={`mt-1 text-xs font-medium ${vis.label}`}>{step.label}</span>
                          <span className="mt-0.5 min-h-3 max-w-full truncate text-[10px] text-slate-400">
                            {sub || "\u00a0"}
                          </span>
                        </div>
                      </li>
                    );
                  })}
                </ol>
                <p className="mt-2 min-h-4 text-xs text-slate-400">{stepper.hint ?? "\u00a0"}</p>
              </section>
              <section>
                <DocSectionHead title="원본 파일" />
                <div
                  // 빈 안내와 카드가 바뀌어도 헤더가 안 뛰게 칸 높이를 확보한다
                  className="min-h-10"
                >
                  <DocFileList
                    // 최신 HWP_SRC 1건 + PDF — 다운로드만. 지우면 문서를 다시 열 수 없다
                    files={fileSplit.originals}
                    onDownload={(fileIdx, name) => void handleDownload(fileIdx, name)}
                    emptyHint={
                      detail.header.docKind === "HTML"
                        ? "HTML 지면 문서 — 작성화면에서 확인"
                        : "원본 파일이 없습니다."
                    }
                  />
                </div>
              </section>

              <section>
                <DocSectionHead
                  title="첨부 파일"
                  extra={(
                    <span className="flex items-center gap-2">
                      <span className="text-xs font-normal text-slate-400">
                        {userFileCnt}개 / 최대 {ATTACH_MAX}개
                      </span>
                      {attachEditable ? (
                        <>
                          <input
                            // 고른 파일을 바로 올린다 — 파일선택·첨부 두 버튼이 아니다
                            ref={fileInputRef}
                            type="file"
                            className="sr-only"
                            onChange={(e) => {
                              const picked = e.target.files?.[0];
                              e.target.value = "";
                              if (picked) void handleUpload(picked);
                            }}
                          />
                          <MesButton
                            // 숨긴 file input 을 연다. 그리드 헤더 행추가와 같은 sm
                            variant="add"
                            size="sm"
                            icon="plus"
                            disabled={userFileCnt >= ATTACH_MAX || asyncAct.isBusy("upload")}
                            onClick={() => fileInputRef.current?.click()}
                          >
                            파일 추가
                          </MesButton>
                        </>
                      ) : null}
                    </span>
                  )}
                />
                {!attachEditable ? (
                  <p className="mt-2 text-xs text-slate-400">
                    전송·결재완료 문서의 첨부는 고칠 수 없습니다. 전송취소 후 수정하세요.
                  </p>
                ) : userFileCnt >= ATTACH_MAX ? (
                  <p className="mt-2 text-xs text-amber-600">{ATTACH_MAX_MSG}</p>
                ) : null}
                <DocFileList
                  // 사용자 첨부(ATTACH·PHOTO) — 전송대기에서만 삭제
                  files={fileSplit.attachments}
                  onDownload={(fileIdx, name) => void handleDownload(fileIdx, name)}
                  onDelete={attachEditable && canDelete
                    ? (fileIdx, name) => void handleDeleteFile(fileIdx, name)
                    : undefined}
                  deleteBusy={asyncAct.isBusy("delFile")}
                  emptyHint="첨부 파일이 없습니다."
                  persistId={FILE_PERSIST_ID}
                />
              </section>

              <section>
                <DocSectionHead title="비고" />
                <textarea
                  // 문서 단위 메모 — 결재완료 전까지 고칠 수 있다
                  value={remark}
                  onChange={(e) => setRemark(e.target.value)}
                  disabled={!remarkEditable}
                  rows={3}
                  maxLength={REMARK_MAX}
                  className="mt-2 w-full rounded border border-slate-300 px-2 py-1.5 text-sm disabled:bg-slate-50 disabled:text-slate-400"
                  placeholder={remarkEditable ? "결재자에게 남길 메모" : "결재가 완료되어 고칠 수 없습니다."}
                />
                <div className="mt-2 flex items-center justify-end gap-3">
                  <span className="text-xs text-slate-400">
                    {remark.length} / {REMARK_MAX}자
                  </span>
                  <MesButton
                    // 비고 저장 — 결재완료(APV) 전까지만. 잠금은 SP 가 다시 막는다
                    variant="save"
                    icon="save"
                    disabled={!remarkEditable || asyncAct.isBusy("remark")}
                    onClick={() => void handleSaveRemark()}
                  >
                    저장
                  </MesButton>
                </div>
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
            </div>
          )}
            </div>
          )}
        />
      </PageCard>
    </div>
  );
}
