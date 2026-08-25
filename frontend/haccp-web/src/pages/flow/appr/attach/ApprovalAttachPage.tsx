/**
 * ApprovalAttachPage — 결재 첨부 (내가 상신한 문서의 첨부·비고·진행상태).
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 좌측은 로그인 사용자가 작성한 문서만 — 서버가 writerId 를 조건으로 걸러 준다
 *   2) 우측은 결재 진행상태 + 첨부 관리 + 비고. 문서 본문 미리보기는 두지 않는다(결재 화면 몫)
 *   3) 첨부는 문서당 5개까지. 프론트에서 막고 서버 SP 가 같은 기준으로 다시 막는다
 *
 * 첨부 추가·삭제는 전송대기(WRK·RJT)에서만 된다 — 상신 뒤에 기록물이 바뀌면 결재자가 본 것과 달라진다.
 * 비고는 메모라서 결재완료(APV) 직전까지 고칠 수 있다.
 * 「초기화」는 저장하지 않은 화면 변경(비고 입력·고른 파일)만 되돌린다. 저장된 첨부는 삭제 버튼으로만 지운다.
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
// 역할 — 그리드 패널 헤더
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
// 역할 — 확인·토스트
import { mesConfirm, mesConfirmDanger, mesToast } from "@/shell/dialog";
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
  processDocumentApproval,
  saveDocumentRemark,
  uploadDocumentFile,
  type DocumentDetail,
  type DocumentListRow,
} from "@/api/documentApi";
// 역할 — 일자·일시 사용자 표기
import { toDisplayDate, toDisplayDateTime } from "@/lib/docDateTime";
// 역할 — 양식코드 → 작성 API (전송 전 필수값 검사에 쓴다)
import { previewEntryOf } from "@/components/document/documentPreviewRegistry";
// 역할 — 상세 → 지면 버퍼 · 전송 필수값 규칙 (작성 화면과 같은 함수)
import { detailToDraftBuf, validateForTransfer } from "@/pages/draft/htmlFormDraftShared";
// 역할 — 파일 크기 표기 (문서함과 같은 함수)
import { fileSize } from "@/pages/flow/box/documentbox/DocumentBoxRule";
// 역할 — 화면 상수·컬럼·잠금 판정
import {
  ATTACH_MAX,
  ATTACH_MAX_MSG,
  FILE_PERSIST_ID,
  PERSIST_ID,
  SCRN_CD,
  buildAttachListColumns,
  canCancelSend,
  canEditAttach,
  canEditRemark,
  canSend,
  countUserFiles,
  docStatusBadgeClass,
  type AttachListRow,
} from "./ApprovalAttachRule";

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
  const { codeMap: statusCodeMap, label: statusLabel } = useCommonCodes("DOC_STATUS");
  const { label: roleLabel } = useCommonCodes("APPR_ROLE");
  const { label: resultLabel } = useCommonCodes("APPR_RESULT");

  // 공통 검색 — 기간·문서번호. 작성자 칸은 쓰지 않는다(항상 본인)
  const [search, setSearch] = useState<DocFormSearchValues>(() => defaultDocFormSearch());
  const searchRef = useRef(search);
  searchRef.current = search;

  const [rows, setRows] = useState<DocumentListRow[]>([]);
  const [selected, setSelected] = useState<DocumentListRow | null>(null);
  const [detail, setDetail] = useState<DocumentDetail | null>(null);
  const [listLoading, setListLoading] = useState(false);
  const [listActiveKey, setListActiveKey] = useState<string | null>(null);
  // 화면 입력 — 저장 전 값. 「초기화」가 되돌리는 대상이다
  const [uploadFile, setUploadFile] = useState<File | null>(null);
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

  const attachEditable = canEditAttach(detail?.header.status) && (canWrite || canModify);
  const remarkEditable = canEditRemark(detail?.header.status) && (canWrite || canModify);
  const userFileCnt = countUserFiles(detail?.files ?? []);

  /** 첨부 업로드 — 상한·잠금을 프론트에서 먼저 본다 */
  const handleUpload = () =>
    asyncAct.run(async () => {
      if (!selected || !uploadFile) {
        mesToast("업로드할 파일을 선택하세요.", "warn");
        return;
      }
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
        await uploadDocumentFile(selected.docIdx, "ATTACH", uploadFile);
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
   *   2) 전송 버튼이 호출한다
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
    return validateForTransfer(buf.baseKey, buf.items, buf.logRows);
  };

  /** 전송 — 결재 프로세스를 시작한다. 이후 첨부·수정이 잠긴다 */
  const handleSend = () =>
    asyncAct.run(async () => {
      if (!selected || !detail) return;
      if (!canSend(detail.header.status)) {
        mesToast("전송대기 문서만 전송할 수 있습니다.", "warn");
        return;
      }
      try {
        const missing = await findMissingValue(selected);
        if (missing) {
          mesToast(missing, "warn");
          return;
        }
        if (!(await mesConfirm("전송하시겠습니까?\n전송 후에는 첨부와 내용을 고칠 수 없습니다."))) return;
        await processDocumentApproval({ docIdx: selected.docIdx, actionCd: "REQUEST" });
        mesToast("전송했습니다.", "success");
        await loadDetail(selected);
        await loadList();
      } catch (e) {
        mesError(e);
      }
    }, "send");

  /** 전송취소 — 전송대기로 되돌린다. 검토·승인이 시작되면 서버가 막는다 */
  const handleCancelSend = () =>
    asyncAct.run(async () => {
      if (!selected || !detail) return;
      if (!canCancelSend(detail.header.status)) {
        mesToast("전송한 문서만 전송취소할 수 있습니다.", "warn");
        return;
      }
      if (!(await mesConfirm("전송을 취소하시겠습니까?\n전송대기로 돌아가 다시 고칠 수 있습니다."))) return;
      try {
        await processDocumentApproval({ docIdx: selected.docIdx, actionCd: "CANCEL" });
        mesToast("전송을 취소했습니다.", "success");
        await loadDetail(selected);
        await loadList();
      } catch (e) {
        mesError(e);
      }
    }, "cancelSend");

  /** 초기화 — 저장하지 않은 화면 변경만 되돌린다. DB 첨부는 건드리지 않는다 */
  const handleReset = () => {
    setUploadFile(null);
    setRemark(detail?.header.remark ?? "");
    mesToast("저장하지 않은 변경을 되돌렸습니다.", "success");
  };

  usePageCommands({
    search: () => { void asyncAct.run(loadList, "search"); },
  });

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 p-3">
      <DocFormSearchToolbar
        // 기간·문서번호 (작성자는 항상 로그인 사용자)
        values={search}
        onChange={(patch) => setSearch((prev) => ({ ...prev, ...patch }))}
        onSearch={() => void asyncAct.run(loadList, "search")}
        searchBusy={listLoading || asyncAct.isBusy("search")}
        actionBusy={asyncAct.isBusy()}
        actions={<span className="text-xs text-slate-400">내가 작성한 문서</span>}
      />

      <div className="grid min-h-0 flex-1 grid-cols-1 gap-3 lg:grid-cols-[minmax(340px,42%)_1fr]">
        <section className="flex min-h-0 flex-1 flex-col overflow-hidden rounded border border-slate-200 bg-white p-2">
          <div className={gridHeadClass}>
            {/* 보이는 그리드명 — title prop과 동일 */}
            <b>내 문서 목록</b>
          </div>
          <MesEditableGrid
            // 열 설정 저장 키
            persistId={PERSIST_ID}
            rows={listRows as EditableRow<AttachListRow>[]}
            columns={listColumns}
            // 목록만 조회 — 편집 금지
            editable={false}
            title="내 문서 목록"
            height="100%"
            loading={listLoading || asyncAct.isBusy("search")}
            activeKey={listActiveKey}
            onActivate={(row) => { void loadDetail(row); }}
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
                    <h2 className="text-base font-semibold text-slate-800">
                      {detail.header.title || detail.header.tmplNm}
                    </h2>
                    <p className="mt-1 text-xs text-slate-500">
                      문서번호 {detail.header.docNo} · 기준일 {toDisplayDate(detail.header.baseDt)}
                      {detail.header.writeDt ? ` · 전송일시 ${toDisplayDateTime(detail.header.writeDt)}` : ""}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span
                      // 좌측 목록 배지와 같은 색 — 상태를 두 곳에서 다르게 보여 주지 않는다
                      className={`rounded border px-2 py-1 text-xs font-medium ${docStatusBadgeClass(detail.header.status)}`}
                    >
                      {statusLabel(detail.header.status, detail.header.status ?? "")}
                    </span>
                    <MesButton
                      // 작성화면 — 지면을 고치러 간다. 이 화면에는 지면이 없다
                      variant="secondary"
                      onClick={() => navigate(routeForDocument({
                        docIdx: detail.header.docIdx,
                        tmplCd: detail.header.tmplCd,
                        docKind: detail.header.docKind,
                      }))}
                    >
                      작성화면
                    </MesButton>
                    {canSend(detail.header.status) && (canWrite || canModify) && (
                      <MesButton
                        // 전송 — 결재 프로세스 시작. 지면 필수값을 먼저 본다
                        variant="excel"
                        disabled={asyncAct.isBusy("send")}
                        onClick={() => void handleSend()}
                      >
                        전송
                      </MesButton>
                    )}
                    {canCancelSend(detail.header.status) && (canWrite || canModify) && (
                      <MesButton
                        // 전송취소 — 전송대기로 되돌린다
                        variant="secondary"
                        disabled={asyncAct.isBusy("cancelSend")}
                        onClick={() => void handleCancelSend()}
                      >
                        전송취소
                      </MesButton>
                    )}
                  </div>
                </div>
              </section>

              <section>
                <h3 className="mb-2 text-sm font-semibold text-slate-700">결재 진행상태</h3>
                {detail.approvals.length === 0 ? (
                  <p className="text-xs text-slate-400">아직 상신하지 않은 문서입니다.</p>
                ) : (
                  <ul className="space-y-1">
                    {detail.approvals.map((step) => (
                      <li
                        key={step.idx}
                        className="flex items-center justify-between gap-2 rounded border border-slate-100 px-2 py-1.5 text-xs"
                      >
                        <span>
                          {step.stepNo}차 {roleLabel(step.roleCd, step.roleCd)} · {step.approverNm || step.approverId || "미지정"}
                        </span>
                        <span className="text-slate-500">
                          {resultLabel(step.resultCd, step.resultCd)}
                          {step.actDt ? ` · ${toDisplayDateTime(step.actDt)}` : ""}
                        </span>
                      </li>
                    ))}
                  </ul>
                )}
              </section>

              <section>
                <div className="mb-2 flex items-center justify-between">
                  <h3 className="text-sm font-semibold text-slate-700">
                    첨부 파일{" "}
                    <span className="text-xs font-normal text-slate-400">
                      {userFileCnt}개 / 최대 {ATTACH_MAX}개
                    </span>
                  </h3>
                  <MesButton variant="secondary" size="sm" onClick={handleReset}>
                    초기화
                  </MesButton>
                </div>
                {attachEditable ? (
                  <div className="mb-2 flex flex-wrap items-center gap-2 rounded bg-slate-50 p-2">
                    <Input
                      type="file"
                      // 고른 파일은 화면 상태 — 「초기화」가 되돌린다
                      onChange={(e) => setUploadFile(e.target.files?.[0] ?? null)}
                      className="max-w-64"
                    />
                    <MesButton
                      variant="secondary"
                      disabled={!uploadFile || userFileCnt >= ATTACH_MAX || asyncAct.isBusy("upload")}
                      onClick={() => void handleUpload()}
                    >
                      첨부
                    </MesButton>
                    {userFileCnt >= ATTACH_MAX && (
                      <span className="text-xs text-amber-600">{ATTACH_MAX_MSG}</span>
                    )}
                  </div>
                ) : (
                  <p className="mb-2 text-xs text-slate-400">
                    전송·결재완료 문서의 첨부는 고칠 수 없습니다. 전송취소 후 작성 화면에서 수정하세요.
                  </p>
                )}
                {detail.files.length === 0 ? (
                  <p className="text-xs text-slate-400">첨부 파일이 없습니다.</p>
                ) : (
                  <ul className="space-y-1" data-persist-id={FILE_PERSIST_ID}>
                    {detail.files.map((file) => (
                      <li
                        key={file.idx}
                        className="flex items-center justify-between gap-2 rounded border border-slate-100 px-2 py-1.5 text-xs"
                      >
                        <span>
                          {file.fileNm}{" "}
                          <span className="text-slate-400">
                            {fileSize(file.fileSize)} · 등록 {file.insId ?? "-"} · {toDisplayDateTime(file.insDt)}
                          </span>
                        </span>
                        <span className="flex items-center gap-1">
                          <MesButton
                            variant="ghost"
                            size="sm"
                            onClick={() => void handleDownload(file.idx, file.fileNm)}
                          >
                            다운로드
                          </MesButton>
                          {attachEditable && canDelete && (
                            <MesButton
                              variant="danger"
                              size="sm"
                              disabled={asyncAct.isBusy("delFile")}
                              onClick={() => void handleDeleteFile(file.idx, file.fileNm)}
                            >
                              삭제
                            </MesButton>
                          )}
                        </span>
                      </li>
                    ))}
                  </ul>
                )}
              </section>

              <section>
                <h3 className="mb-2 text-sm font-semibold text-slate-700">비고</h3>
                <textarea
                  // 문서 단위 메모 — 결재완료 전까지 고칠 수 있다
                  value={remark}
                  onChange={(e) => setRemark(e.target.value)}
                  disabled={!remarkEditable}
                  rows={3}
                  maxLength={500}
                  className="w-full rounded border border-slate-300 px-2 py-1.5 text-sm disabled:bg-slate-50 disabled:text-slate-400"
                  placeholder={remarkEditable ? "결재자에게 남길 메모" : "결재가 완료되어 고칠 수 없습니다."}
                />
                <div className="mt-2 flex justify-end">
                  <MesButton
                    variant="save"
                    disabled={!remarkEditable || asyncAct.isBusy("remark")}
                    onClick={() => void handleSaveRemark()}
                  >
                    비고 저장
                  </MesButton>
                </div>
              </section>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
