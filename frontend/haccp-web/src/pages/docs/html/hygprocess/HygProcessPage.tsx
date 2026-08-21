/**
 * HygProcessPage — 일반위생관리 및 공정점검표 작성.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 신규는 적용 버전(없으면 표준) 항목을 빈칸으로 연다
 *   2) 표는 HygPrcPaper 하나. 헤더는 제목·결재·점검일자·점검자. 서명 있으면 이미지
 *      제목 메타(hdr-title)는 점검 행이 아니라서 저장 때 뺀다
 *   3) 삭제는 validate-delete → 확인 → delete
 *
 * PIPELINE[HF131] 공정점검 화면
 */
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useDocIdxQuery } from "@/hooks/useDocIdxQuery";
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useDocFormSession, type DocListMeta } from "@/hooks/useDocFormSession";
import { usePageCommands } from "@/shell/pageCommands";
import { mesConfirmDanger, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { useGridAccess } from "@/hooks/useGridAccess";
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
import {
  DocFormBody,
  DocFormDocumentList,
  DocFormLayout,
  DocFormMainPanel,
} from "@/components/form/DocFormLayout";
import {
  DocFormSearchToolbar,
  defaultDocFormSearch,
  type DocFormSearchValues,
} from "@/components/form/DocFormSearchToolbar";
import { DocumentApprovalToolbar } from "@/components/document/DocumentApprovalToolbar";
import { HygPrcPaper } from "@/pages/docs/html/htmltemplate/HygPrcPaper";
import { paperBodyItems } from "@/components/form/htmlFormPaperShared";
import { useCommonCodes } from "@/hooks/useCommonCodes";
import { fromInputDate, toInputDate, todayYmd } from "@/lib/docDateTime";
import type { HtmlFormItem } from "@/api/docs/htmlFormApi";
import {
  deleteHygProcess,
  getHygProcessDetail,
  listHygProcess,
  saveHygProcess,
  validateDeleteHygProcess,
} from "@/api/docs/htmlFormApi";
import { PAPER_SUBTITLE, PAPER_TITLE, PERSIST_ID, SCRN_CD, buildListColumns } from "./HygProcessRule";

function editableStatus(status: string | null | undefined): boolean {
  return !status || status === "WRK" || status === "RJT";
}

function asText(value: unknown): string {
  return value == null ? "" : String(value);
}

function asYn(value: unknown): string {
  return String(value ?? "").trim().toUpperCase() === "Y" ? "Y" : "N";
}

type ListMeta = DocListMeta & {
  baseDtDisp?: string;
  checkerNm?: string;
  statusNm?: string;
};

type Buf = {
  docIdx: number | null;
  docNo: string;
  status: string | null;
  baseKey: string;
  writerNm: string;
  writerId: string;
  writerSignYn: string;
  checkerNm: string;
  checkerId: string;
  checkerSignYn: string;
  approverNm: string;
  approverId: string;
  approverSignYn: string;
  verNo: number;
  items: HtmlFormItem[];
  specialNote: string;
  improveNote: string;
  actionNm: string;
  confirmNm: string;
  confirmId: string;
  confirmSignYn: string;
};

function detailToBuf(
  detail: Awaited<ReturnType<typeof getHygProcessDetail>>,
  user?: { userNm?: string; userId?: string } | null,
): Buf {
  const header = detail.header ?? {};
  const nextBase = asText(header.baseDt) || todayYmd();
  return {
    docIdx: Number(header.docIdx) || null,
    docNo: asText(header.docNo),
    status: asText(header.status) || null,
    baseKey: nextBase,
    writerNm: asText(header.writerNm ?? header.writer_nm) || user?.userNm || "",
    writerId: asText(header.writerId ?? header.writer_id) || user?.userId || "",
    writerSignYn: asYn(header.writerSignYn ?? header.writer_sign_yn),
    checkerNm: asText(header.checkerNm) || user?.userNm || "",
    checkerId: asText(header.checkerId ?? header.checker_id),
    checkerSignYn: asYn(header.checkerSignYn ?? header.checker_sign_yn),
    approverNm: asText(header.approverNm ?? header.approver_nm),
    approverId: asText(header.approverId ?? header.approver_id),
    approverSignYn: asYn(header.approverSignYn ?? header.approver_sign_yn),
    verNo: Number(header.verNo ?? header.ver_no) || 0,
    items: detail.items ?? [],
    specialNote: asText(header.specialNote ?? header.special_note),
    improveNote: asText(header.improveNote ?? header.improve_note),
    actionNm: asText(header.actionNm ?? header.action_nm),
    confirmNm: asText(header.confirmNm ?? header.confirm_nm),
    confirmId: asText(header.confirmId ?? header.confirm_id),
    confirmSignYn: asYn(header.confirmSignYn ?? header.confirm_sign_yn),
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 좌 문서목록 + 우 A4
 *   2) PRP 메뉴 hygiene-process-check 에서 연다
 *   3) 결재는 저장 문서만
 */
export default function HygProcessPage() {
  const user = useAuthStore((s) => s.user);
  const canWrite = useAuthStore((s) => s.can(SCRN_CD, "write"));
  const canModify = useAuthStore((s) => s.can(SCRN_CD, "modify"));
  const canDelete = useAuthStore((s) => s.can(SCRN_CD, "delete"));
  const action = useAsyncAction();
  const statusCodes = useCommonCodes("DOC_STATUS");
  const [search, setSearch] = useState<DocFormSearchValues>(defaultDocFormSearch);
  const {
    listRows, activeKey, activeBuffer: buf, addDraft, selectKey, patchActive,
    replaceServerList, removeDraft, saveAll, getBuffer, putBuffer,
  } = useDocFormSession<Buf, ListMeta>();
  const listGrid = useGridAccess({ newOnly: ["baseDtDisp", "baseKey"] }, { scrnCd: SCRN_CD, gridRole: "single", readOnly: false });
  const listCols = useMemo(() => buildListColumns() as GridColumn<ListMeta>[], []);

  const canEdit = !!buf && editableStatus(buf.status) && (buf.docIdx ? canModify || canWrite : canWrite);
  const docIdx = buf?.docIdx ?? null;
  const status = buf?.status ?? null;

  /**
   * 개발자: 박승우
   * 일자: 2026-08-19
   * 코멘트:
   *   1) 서버 목록을 좌측에 싣는다
   *   2) 조회·저장·삭제 후 호출한다
   *   3) draft 는 유지한다
   */
  const loadList = useCallback(async () => {
    const rows = await listHygProcess({
      fromDt: search.fromDt,
      toDt: search.toDt,
      docNo: search.docNo,
      writer: search.writer,
    });
    replaceServerList(
      rows.map((r) => ({
        docIdx: r.docIdx,
        docNo: r.docNo,
        status: r.status,
        baseKey: r.baseDt,
        baseDtDisp: toInputDate(r.baseDt),
        checkerNm: r.checkerNm ?? "",
        statusNm: statusCodes.codeMap[r.status] ?? r.status,
        ngCnt: r.ngCnt ?? 0,
      })),
      (r) => String(r.docIdx),
    );
  }, [replaceServerList, search, statusCodes.codeMap]);

  useEffect(() => {
    void action.run(async () => {
      try { await loadList(); } catch (e) { mesError(e); }
    }, "search");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleSelect = useCallback((key: string | null) => {
    void selectKey(key, async (k, row) => {
      const cached = getBuffer(k);
      if (cached) return cached;
      if (row._rowState === "C" || !row.docIdx) {
        try {
          const next = detailToBuf(await getHygProcessDetail(null), user);
          next.docIdx = null;
          next.docNo = "";
          next.status = null;
          next.baseKey = row.baseKey || todayYmd();
          return next;
        } catch (error) {
          mesError(error);
          return null;
        }
      }
      try {
        return detailToBuf(await getHygProcessDetail(row.docIdx), user);
      } catch (error) {
        mesError(error);
        return null;
      }
    });
  }, [getBuffer, selectKey, user]);

  const openDocIdx = useDocIdxQuery();
  const deepLinkRef = useRef<number | null>(null);
  useEffect(() => {
    if (openDocIdx == null || deepLinkRef.current === openDocIdx) return;
    if (!listRows.some((r) => r.docIdx === openDocIdx)) return;
    deepLinkRef.current = openDocIdx;
    void handleSelect(String(openDocIdx));
  }, [openDocIdx, listRows, handleSelect]);

  const handleNew = () => action.run(async () => {
    if (!canWrite) return;
    try {
      const next = detailToBuf(await getHygProcessDetail(null), user);
      next.docIdx = null;
      next.docNo = "";
      next.status = null;
      next.baseKey = todayYmd();
      addDraft({
        docIdx: null,
        docNo: "",
        status: null,
        baseKey: next.baseKey,
        baseDtDisp: toInputDate(next.baseKey),
        ngCnt: 0,
      }, next);
    } catch (error) {
      mesError(error);
    }
  }, "add");

  const handleSave = () => action.run(async () => {
    try {
      const savedIdxs: number[] = [];
      const err = await saveAll({
        validate: (dirty, getBuf) => {
          for (const row of dirty) {
            const key = row._key;
            if (!key) continue;
            const b = getBuf(key);
            if (!b) return { message: "편집 내용이 없습니다.", rowKey: key };
            if (!editableStatus(b.status) && b.docIdx) {
              return { message: MES.inApprovalLocked, rowKey: key };
            }
            if (!/^\d{8}$/.test(b.baseKey)) return { message: MES.required("점검일자"), rowKey: key };
            if (paperBodyItems(b.items).length === 0) return { message: "점검 행이 없습니다.", rowKey: key };
          }
          return null;
        },
        saveOne: async (_row, b) => {
          const saved = await saveHygProcess({
            docIdx: b.docIdx,
            baseDt: b.baseKey,
            checkerNm: b.checkerNm,
            approverNm: b.approverNm,
            verNo: b.verNo,
            items: paperBodyItems(b.items),
            specialNote: b.specialNote,
            improveNote: b.improveNote,
            actionNm: b.actionNm,
            confirmNm: b.confirmNm,
          });
          savedIdxs.push(saved);
          return {
            docIdx: saved,
            listMeta: {
              docIdx: saved,
              status: "WRK",
              baseKey: b.baseKey,
              baseDtDisp: toInputDate(b.baseKey),
            },
          };
        },
        afterAll: async () => {
          await loadList();
          for (const idx of savedIdxs) {
            try {
              const detail = await getHygProcessDetail(idx);
              putBuffer(String(idx), detailToBuf(detail, user), {
                status: asText(detail.header?.status) || "WRK",
                checkerNm: asText(detail.header?.checkerNm),
              });
            } catch (e) {
              mesError(e);
            }
          }
          mesToast(MES.saveDone, "success");
        },
      });
      if (err) mesToast(err.message, "warn");
    } catch (error) {
      mesError(error);
    }
  }, "save");

  const handleDelete = () => action.run(async () => {
    if (!activeKey) return mesToast(MES.selectRow, "warn");
    const row = listRows.find((r) => r._key === activeKey);
    if (!row) return;
    if (row._rowState === "C") {
      removeDraft(activeKey);
      return;
    }
    if (!docIdx || !canDelete) return;
    if (!canEdit) return mesToast(MES.inApprovalLocked, "warn");
    try {
      const keys = [{ docIdx }];
      await validateDeleteHygProcess(keys);
      if (!await mesConfirmDanger(`${buf?.docNo || PAPER_TITLE} 문서를 삭제하시겠습니까?`)) return;
      await deleteHygProcess(keys);
      mesToast(MES.deleteDone, "success");
      await loadList();
      await handleSelect(null);
    } catch (error) {
      mesError(error);
    }
  }, "del");

  usePageCommands({
    search: () => { void action.run(async () => { try { await loadList(); } catch (e) { mesError(e); } }, "search"); },
    add: () => { void handleNew(); },
    save: () => { void handleSave(); },
    del: () => { void handleDelete(); },
    print: () => { window.print(); },
  });

  return (
    <DocFormLayout>
      <div className="html-form-no-print">
      <DocFormSearchToolbar
        // 기간·문서번호·작성자
        values={search}
        // 조건 부분 갱신
        onChange={(patch) => setSearch((prev) => ({ ...prev, ...patch }))}
        // 목록 재조회
        onSearch={() => void action.run(async () => { try { await loadList(); } catch (e) { mesError(e); } }, "search")}
        // 좌측 draft 추가
        onAdd={() => void handleNew()}
        // dirty 전건 저장
        onSave={() => void handleSave()}
        // draft 제거 또는 서버 삭제
        onDelete={() => void handleDelete()}
        // 신규 권한
        canAdd={canWrite}
        // 삭제
        canDelete={!!activeKey && (canDelete || listRows.find((r) => r._key === activeKey)?._rowState === "C")}
        searchBusy={action.isBusy()}
        actionBusy={action.isBusy()}
      />
      {docIdx ? (
        <DocumentApprovalToolbar
          // 저장 후 문서 idx
          docIdx={docIdx}
          // 문서 상태
          status={status}
          onSave={() => void handleSave()}
          canSave={!!canEdit}
          canApprove={canWrite || canModify}
          saveBusy={action.isBusy("save")}
          writerActionsOnly
          onPreview={() => { window.print(); }}
          onApproved={() => {
            void loadList();
            if (docIdx && activeKey) {
              void getHygProcessDetail(docIdx).then((detail) => {
                putBuffer(activeKey, detailToBuf(detail, user), {
                  status: asText(detail.header?.status) || null,
                });
              }).catch((error) => mesError(error));
            }
          }}
        />
      ) : null}
      </div>
      <DocFormBody>
        <DocFormDocumentList>
          <MesEditableGrid
            // 열 너비·정렬 저장 키
            persistId={PERSIST_ID}
            // 서버 목록 + draft
            rows={listRows as EditableRow<ListMeta>[]}
            // 문서번호·점검일자·상태·점검자
            columns={listCols}
            // 신규행 점검일자만 편집
            editable={canWrite || canModify}
            // 패널 제목
            title="문서 목록"
            // 부모 flex 높이
            height="100%"
            // 선택 키
            activeKey={activeKey}
            // 행 클릭 시 버퍼 전환
            onActivate={(row) => { void handleSelect(row._key ?? null); }}
            onCellChange={(key, field, cellValue) => {
              if (field !== "baseDtDisp" && field !== "baseKey") return;
              const next = fromInputDate(String(cellValue ?? ""));
              const prevBuf = getBuffer(key);
              if (!prevBuf) return;
              putBuffer(key, { ...prevBuf, baseKey: next }, {
                baseKey: next,
                baseDtDisp: toInputDate(next),
              });
            }}
            // 잠금·권한
            access={listGrid.access}
            onLockedAttempt={listGrid.onLockedAttempt}
            showRowNum
          />
        </DocFormDocumentList>
        <DocFormMainPanel>
          {buf ? (
            <HygPrcPaper
              // 작성 모드
              mode="write"
              // 결재 잠금이 아니면 편집
              locked={!canEdit}
              editable={!!canEdit}
              // 제목·결재·점검일자·점검자. 서명 있으면 이미지
              header={{
                title: PAPER_TITLE,
                subtitle: PAPER_SUBTITLE,
                baseDt: toInputDate(buf.baseKey),
                writerNm: buf.writerNm,
                writerId: buf.writerId,
                writerSignYn: buf.writerSignYn,
                checkerNm: buf.checkerNm,
                checkerId: buf.checkerId,
                checkerSignYn: buf.checkerSignYn,
                approverNm: buf.approverNm,
                approverId: buf.approverId,
                approverSignYn: buf.approverSignYn,
                confirmId: buf.confirmId,
                confirmSignYn: buf.confirmSignYn,
              }}
              // 점검 행
              items={buf.items}
              // 하단 4열 — 확인은 풋터만
              footer={{
                specialNote: buf.specialNote,
                improveNote: buf.improveNote,
                actionNm: buf.actionNm,
                confirmNm: buf.confirmNm,
              }}
              onHeaderChange={(patch) => patchActive((cur) => {
                const next = { ...cur };
                if (patch.baseDt != null) next.baseKey = fromInputDate(patch.baseDt);
                if (patch.checkerNm != null) {
                  if (patch.checkerNm !== cur.checkerNm) {
                    next.checkerId = "";
                    next.checkerSignYn = "N";
                  }
                  next.checkerNm = patch.checkerNm;
                }
                if (patch.approverNm != null) {
                  if (patch.approverNm !== cur.approverNm) {
                    next.approverId = "";
                    next.approverSignYn = "N";
                  }
                  next.approverNm = patch.approverNm;
                }
                return next;
              })}
              onItemsChange={(items) => patchActive((cur) => ({ ...cur, items }))}
              onFooterChange={(patch) => patchActive((cur) => {
                const next = { ...cur, ...patch };
                if (patch.confirmNm != null && patch.confirmNm !== cur.confirmNm) {
                  next.confirmId = "";
                  next.confirmSignYn = "N";
                }
                return next;
              })}
            />
          ) : (
            <p className="p-6 text-sm text-slate-500">왼쪽에서 문서를 고르거나 신규를 누르세요.</p>
          )}
        </DocFormMainPanel>
      </DocFormBody>
    </DocFormLayout>
  );
}
