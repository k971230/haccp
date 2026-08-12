/**
 * BizOpsFormPage — 시설·재고·공정 DB형 양식 문서형 기록 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 신규 시 좌측 draft(C)를 쌓고 dirty 전건 검증 후 단건 save를 순차 호출한다
 *   2) 날짜·셀은 docDateTime·DocCellSelect로 DocForm 계약을 맞춘다
 *   3) 검교정은 연도·재고는 연월·그 외는 일자를 baseKey로 쓴다
 *
 * PIPELINE[HF85] 시설·재고·공정 화면
 * PIPELINE[HF120, HF29, HF56] 연관 모듈
 */
// 역할 — React 상태
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 홈·문서함 ?docIdx= deep-link
import { useDocIdxQuery } from "@/hooks/useDocIdxQuery";
import {
  deleteBizOps,
  getBizOpsDetail,
  listBizOps,
  saveBizOps,
  validateDeleteBizOps,
  type BizOpsScreenCode,
} from "@/api/bizOpsApi";
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — DB형 문서 draft·다건 버퍼 세션
import { useDocFormSession, type DocListMeta } from "@/hooks/useDocFormSession";
// 역할 — 셸 툴바·단축키 CRUD 등록
import { usePageCommands } from "@/shell/pageCommands";
import { mesConfirm, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — 목록 그리드 잠금(신규만 기준키 편집)
import { useGridAccess } from "@/hooks/useGridAccess";
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
import {
  DocFormBody,
  DocFormDocumentList,
  DocFormLayout,
  DocFormMainPanel,
  DocFormSidePanel,
} from "@/components/form/DocFormLayout";
// 역할 — 공통 조회·CRUD 헤더
import {
  DocFormSearchToolbar,
  defaultDocFormSearch,
  type DocFormSearchValues,
} from "@/components/form/DocFormSearchToolbar";
import { DocPaper } from "@/components/form/DocPaper";
import { DocCellInput, DocCellSelect, DocMetaTable } from "@/components/form/DocCell";
import { DocDeviationFooter, type DocCorrectiveValue } from "@/components/form/DocDeviationFooter";
import { DocRowToolbar } from "@/components/form/DocRowToolbar";
import { DocSummaryPanel } from "@/components/form/DocSummaryPanel";
// 역할 — 상신·검토·승인·반려 공통 툴바
import { DocumentApprovalToolbar } from "@/components/document/DocumentApprovalToolbar";
// 역할 — 문서상태 공통코드
import { useCommonCodes } from "@/hooks/useCommonCodes";
import { cn } from "@/lib/cn";
// 역할 — DocForm 날짜·시각 변환
import { fromInputDate, toInputDate, todayYmd } from "@/lib/docDateTime";

type FormRow = Record<string, unknown>;
type Field = { key: string; label: string; type?: "date" | "number" | "select"; options?: string[]; readOnly?: boolean };

const formMeta: Record<BizOpsScreenCode, { title: string; headers: Field[]; columns: Field[] }> = {
  "facility-equipment-check": {
    title: "시설·설비·처리도구 점검표",
    headers: [{ key: "baseDt", label: "점검일", type: "date" }, { key: "checkerNm", label: "점검자" }],
    columns: [
      { key: "placeNm", label: "위치" },
      { key: "grpNm", label: "관리항목", readOnly: true }, { key: "itemNm", label: "점검사항", readOnly: true },
      { key: "methodNm", label: "방법", readOnly: true }, { key: "cycleNm", label: "주기", readOnly: true },
      { key: "mngNm", label: "담당" }, { key: "judgeCd", label: "판정", type: "select", options: ["", "O", "X"] },
      { key: "actionRmk", label: "이탈시 조치" },
      { key: "actionDesc", label: "조치사항" },
    ],
  },
  "calibration-target-management": {
    title: "검·교정 대상 점검표",
    headers: [{ key: "baseYear", label: "대상연도" }, { key: "baseDt", label: "작성일", type: "date" }],
    columns: [
      { key: "deviceCd", label: "계측기 코드", readOnly: true }, { key: "deviceNm", label: "계측기명", readOnly: true },
      { key: "officialCalibDt", label: "공인 검교정일", type: "date" },
      { key: "selfCalibDt", label: "자체 검교정일", type: "date" },
      { key: "nextCalibDt", label: "차기 예정일", type: "date" }, { key: "remark", label: "비고" },
    ],
  },
  "waste-disposal-check": {
    title: "폐기물 처리 점검표",
    headers: [{ key: "baseDt", label: "시작일", type: "date" }, { key: "baseDtTo", label: "종료일", type: "date" }],
    columns: [
      { key: "procDt", label: "처리일", type: "date" }, { key: "wasteGbn", label: "구분", type: "select", options: ["", "BAD", "tmpl_prp-waste-check", "EXPIRE"] },
      { key: "itemNm", label: "품명" }, { key: "weightKg", label: "중량(kg)", type: "number" },
      { key: "badDesc", label: "부적합 내용" }, { key: "procDesc", label: "처리방법" },
      { key: "partnerNm", label: "수거업체" }, { key: "mngNm", label: "담당자" },
    ],
  },
  "inventory-check": {
    title: "입·출고 및 재고 점검표",
    headers: [{ key: "baseYm", label: "기준연월" }],
    columns: [
      { key: "txnDt", label: "거래일", type: "date" }, { key: "txnGbn", label: "입출고", type: "select", options: ["IN", "OUT"] },
      { key: "itemGbn", label: "품목구분", type: "select", options: ["MEAT", "SUB", "PACK", "PROD"] },
      { key: "itemNm", label: "품명" }, { key: "qty", label: "수량", type: "number" },
      { key: "unitNm", label: "단위" }, { key: "lotNo", label: "로트번호" }, { key: "remark", label: "비고" },
    ],
  },
  "receiving-inspection": {
    title: "입고검사 일지",
    headers: [
      { key: "baseDt", label: "입고일", type: "date" }, { key: "recvGbn", label: "입고구분", type: "select", options: ["MEAT", "SUB", "PACK"] },
      { key: "partnerNm", label: "반입처" }, { key: "itemNm", label: "품명" }, { key: "recvQty", label: "입고수량", type: "number" },
    ],
    columns: [
      { key: "grpCd", label: "구분", readOnly: true }, { key: "itemNm", label: "검사항목", readOnly: true },
      { key: "judgeCd", label: "판정", type: "select", options: ["", "P", "F"] }, { key: "evalDesc", label: "평가내용" },
    ],
  },
  "process-control-check": {
    title: "공정관리 점검표",
    headers: [{ key: "baseDt", label: "시작일", type: "date" }, { key: "baseDtTo", label: "종료일", type: "date" }, { key: "cycleNm", label: "점검주기" }],
    columns: [
      { key: "procNm", label: "공정", readOnly: true }, { key: "itemNm", label: "점검사항", readOnly: true },
      { key: "resultSummary", label: "일자별 판정", readOnly: true },
    ],
  },
};

/** unknown → date input — DocForm 공통 변환 래핑 */
function toDateCell(value: unknown): string {
  return toInputDate(String(value ?? "").replace(/\D/g, "").slice(0, 8));
}
function editableStatus(status: unknown): boolean { return !status || status === "WRK" || status === "RJT"; }

/** 양식별 기준키 라벨 */
function baseKeyHeader(screenCode: BizOpsScreenCode): string {
  if (screenCode === "calibration-target-management") return "연도";
  if (screenCode === "inventory-check") return "연월";
  return "기준일";
}

/** 헤더/목록에서 baseKey 추출 */
function extractBaseKey(screenCode: BizOpsScreenCode, header: FormRow, fallback = ""): string {
  if (screenCode === "calibration-target-management") {
    return String(header.baseYear ?? fallback ?? todayYmd().slice(0, 4)).replace(/\D/g, "").slice(0, 4);
  }
  if (screenCode === "inventory-check") {
    return String(header.baseYm ?? fallback ?? todayYmd().slice(0, 6)).replace(/\D/g, "").slice(0, 6);
  }
  return String(header.baseDt ?? fallback ?? todayYmd()).replace(/\D/g, "").slice(0, 8);
}

/** baseKey를 헤더 필드에 반영 */
function applyBaseKey(screenCode: BizOpsScreenCode, header: FormRow, baseKey: string): FormRow {
  if (screenCode === "calibration-target-management") {
    return { ...header, baseYear: baseKey };
  }
  if (screenCode === "inventory-check") {
    return { ...header, baseYm: baseKey };
  }
  return { ...header, baseDt: baseKey };
}

/** 기준키 표시 */
function formatBaseKey(screenCode: BizOpsScreenCode, baseKey: string): string {
  if (screenCode === "calibration-target-management") return baseKey;
  if (screenCode === "inventory-check") {
    return baseKey.length === 6 ? `${baseKey.slice(0, 4)}-${baseKey.slice(4, 6)}` : baseKey;
  }
  return toInputDate(baseKey);
}

/** 기준키 형식 검증 */
function validateBaseKey(screenCode: BizOpsScreenCode, baseKey: string): string | null {
  if (screenCode === "calibration-target-management") {
    return /^\d{4}$/.test(baseKey) ? null : MES.required("연도");
  }
  if (screenCode === "inventory-check") {
    return /^\d{6}$/.test(baseKey) ? null : MES.required("기준연월");
  }
  return /^\d{8}$/.test(baseKey) ? null : MES.required("기준일");
}

/** 좌측 목록 메타 */
type ListMeta = DocListMeta & {
  baseDtDisp?: string;
  statusNm?: string;
};

/** 건별 본문 버퍼 */
type Buf = {
  docIdx: number | null;
  docNo: string;
  status: string | null;
  baseKey: string;
  header: FormRow;
  rows: FormRow[];
  corrective: DocCorrectiveValue;
};

function emptyHeader(screenCode: BizOpsScreenCode, userNm?: string): FormRow {
  const next: FormRow = { baseDt: todayYmd() };
  if (screenCode === "calibration-target-management") next.baseYear = todayYmd().slice(0, 4);
  if (screenCode === "inventory-check") next.baseYm = todayYmd().slice(0, 6);
  if (screenCode === "receiving-inspection") next.recvGbn = "MEAT";
  if (screenCode === "facility-equipment-check") next.checkerNm = userNm ?? "";
  return next;
}

function detailToBuf(screenCode: BizOpsScreenCode, detail: { header: FormRow | null; rows: FormRow[]; corrective?: DocCorrectiveValue | null }, userNm?: string): Buf {
  const nextHeader = detail.header ?? emptyHeader(screenCode, userNm);
  if (!detail.header && screenCode === "calibration-target-management") nextHeader.baseYear = todayYmd().slice(0, 4);
  if (!detail.header && screenCode === "inventory-check") nextHeader.baseYm = todayYmd().slice(0, 6);
  if (!detail.header && screenCode === "receiving-inspection") nextHeader.recvGbn = "MEAT";
  if (!detail.header && screenCode === "facility-equipment-check") nextHeader.checkerNm = userNm ?? "";
  const baseKey = extractBaseKey(screenCode, nextHeader);
  const ca = detail.corrective;
  return {
    docIdx: Number(detail.header?.docIdx ?? 0) || null,
    docNo: String(nextHeader.docNo ?? ""),
    status: nextHeader.status ? String(nextHeader.status) : null,
    baseKey,
    header: nextHeader,
    rows: detail.rows ?? [],
    corrective: {
      deviationDesc: ca?.deviationDesc ?? "",
      actionDesc: ca?.actionDesc ?? "",
      actionUserNm: ca?.actionUserNm ?? "",
      confirmUserNm: ca?.confirmUserNm ?? "",
    },
  };
}

export interface BizOpsFormPageProps { screenCode: BizOpsScreenCode; }

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 시설·재고·공정 문서형 화면을 draft 세션으로 렌더링한다
 *   2) screenRegistry가 화면코드로 마운트한다
 *   3) 저장·삭제 실패는 업무 토스트만 표시한다
 */
export default function BizOpsFormPage({ screenCode }: BizOpsFormPageProps) {
  const meta = formMeta[screenCode];
  const user = useAuthStore((state) => state.user);
  const canWrite = useAuthStore((state) => state.can(screenCode, "write"));
  const canModify = useAuthStore((state) => state.can(screenCode, "modify"));
  const canDelete = useAuthStore((state) => state.can(screenCode, "delete"));
  // 좌측 문서 목록 — 신규행만 기준키 편집
  const listGrid = useGridAccess({ newOnly: ["baseDtDisp", "baseKey"] }, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });
  const asyncAct = useAsyncAction();
  const { label: statusLabel } = useCommonCodes("DOC_STATUS");
  const session = useDocFormSession<Buf, ListMeta>();
  const {
    listRows,
    activeKey,
    activeBuffer,
    addDraft,
    selectKey,
    patchActive,
    putBuffer,
    getBuffer,
    removeDraft,
    saveAll,
    replaceServerList,
  } = session;

  // 공통 목록 검색 — 기간·문서번호·작성자
  const [search, setSearch] = useState<DocFormSearchValues>(() => defaultDocFormSearch());
  const searchRef = useRef(search);
  searchRef.current = search;
  const [selectedRowSeq, setSelectedRowSeq] = useState<number | null>(null);

  const buf = activeBuffer;
  const docIdx = buf?.docIdx ?? null;
  const header = buf?.header ?? {};
  const canEdit = editableStatus(header.status) && (docIdx ? canModify : canWrite);
  const docNo = buf?.docNo ?? String(header.docNo ?? "");

  const listColumns = useMemo<GridColumn<ListMeta>[]>(() => {
    // 연도·연월 — 텍스트 / 일지 — YYYY-MM-DD 달력
    const baseCol: GridColumn<ListMeta> =
      screenCode === "calibration-target-management" || screenCode === "inventory-check"
        ? {
            field: "baseKey",
            header: baseKeyHeader(screenCode),
            width: 100,
            editableOnNew: true,
          }
        : {
            field: "baseDtDisp",
            header: baseKeyHeader(screenCode),
            width: 120,
            editableOnNew: true,
            type: "date",
          };
    return [
      baseCol,
      { field: "docNo", header: "문서번호", width: 120 },
      { field: "statusNm", header: "상태", width: 80 },
    ];
  }, [screenCode]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 목록을 조회해 draft를 유지한 채 좌측 그리드를 갱신한다
   *   2) 조회·저장·삭제 후 호출한다
   *   3) 실패 시 토스트
   */
  const loadList = useCallback(async () => {
    const q = searchRef.current;
    try {
      const server = await listBizOps(screenCode, {
        fromDt: q.fromDt,
        toDt: q.toDt,
        docNo: q.docNo.trim() || undefined,
        writer: q.writer.trim() || undefined,
      });
      replaceServerList(
        server.map((item) => {
          const baseKey = extractBaseKey(screenCode, { baseDt: item.baseDt, baseYear: item.baseDt, baseYm: item.baseDt }, item.baseDt);
          return {
            docIdx: item.docIdx,
            docNo: item.docNo,
            status: item.status,
            baseKey,
            baseDtDisp: formatBaseKey(screenCode, baseKey),
            statusNm: statusLabel(item.status, item.status),
            ngCnt: item.ngCnt,
          } satisfies ListMeta;
        }),
        (row) => String(row.docIdx),
      );
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  }, [replaceServerList, screenCode, statusLabel]);

  useEffect(() => { void loadList(); }, [loadList]);

  const handleSelect = useCallback(async (key: string | null) => {
    setSelectedRowSeq(null);
    await selectKey(key, async (k, row) => {
      const cached = getBuffer(k);
      if (cached) return cached;
      if (row._rowState === "C" || !row.docIdx) {
        try {
          const detail = await getBizOpsDetail(screenCode, null);
          const next = detailToBuf(screenCode, detail, user?.userNm);
          next.docIdx = null;
          next.docNo = "";
          next.status = null;
          next.baseKey = row.baseKey || extractBaseKey(screenCode, next.header);
          next.header = applyBaseKey(screenCode, next.header, next.baseKey);
          return next;
        } catch (error) {
          mesToast(mesError(error), "error");
          return null;
        }
      }
      try {
        return detailToBuf(screenCode, await getBizOpsDetail(screenCode, row.docIdx), user?.userNm);
      } catch (error) {
        mesToast(mesError(error), "error");
        return null;
      }
    });
  }, [getBuffer, screenCode, selectKey, user?.userNm]);

  // 홈·문서함 deep-link — 목록에 해당 문서가 있으면 1회 선택
  const openDocIdx = useDocIdxQuery();
  const deepLinkRef = useRef<number | null>(null);
  useEffect(() => {
    if (openDocIdx == null || deepLinkRef.current === openDocIdx) return;
    if (!listRows.some((r) => r.docIdx === openDocIdx)) return;
    deepLinkRef.current = openDocIdx;
    void handleSelect(String(openDocIdx));
  }, [openDocIdx, listRows, handleSelect]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 신규 draft와 기본 행 버퍼를 추가한다
   *   2) 신규 버튼에서 호출한다
   *   3) 상세(null) 실패 시 토스트
   */
  const handleNew = () => asyncAct.run(async () => {
    if (!canWrite) return;
    // 당일(당해·당월) 복수 문서 허용 — 기존 기준키 행이 있어도 항상 새 draft
    const nextKey = extractBaseKey(screenCode, emptyHeader(screenCode, user?.userNm));
    try {
      const detail = await getBizOpsDetail(screenCode, null);
      const next = detailToBuf(screenCode, detail, user?.userNm);
      next.docIdx = null;
      next.docNo = "";
      next.status = null;
      next.baseKey = nextKey;
      next.header = applyBaseKey(screenCode, { ...next.header, status: null, docNo: "" }, next.baseKey);
      addDraft(
        {
          docIdx: null,
          docNo: "",
          status: null,
          baseKey: next.baseKey,
          baseDtDisp: formatBaseKey(screenCode, next.baseKey),
          statusNm: "신규",
          ngCnt: 0,
        },
        next,
      );
      setSelectedRowSeq(null);
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  }, "add");

  const handleSave = () => asyncAct.run(async () => {
    try {
      const err = await saveAll({
        validate: (dirty, getBuf) => {
          const seen = new Set<string>();
          for (const row of dirty) {
            const key = row._key;
            if (!key) continue;
            const b = getBuf(key);
            if (!b) return { message: "편집 내용이 없습니다.", rowKey: key };
            if (!editableStatus(b.status) && b.docIdx) {
              return { message: MES.inApprovalLocked, rowKey: key };
            }
            const baseErr = validateBaseKey(screenCode, b.baseKey);
            if (baseErr) return { message: baseErr, rowKey: key };
            if (seen.has(b.baseKey)) return { message: `기준키가 중복되었습니다: ${b.baseKey}`, rowKey: key };
            seen.add(b.baseKey);
            if (b.rows.length === 0) return { message: MES.required("기록 행"), rowKey: key };
          }
          return null;
        },
        saveOne: async (_row, b) => {
          const payloadHeader = applyBaseKey(screenCode, b.header, b.baseKey);
          const saved = await saveBizOps(screenCode, b.docIdx, { ...payloadHeader, rows: b.rows }, b.corrective);
          return {
            docIdx: saved,
            listMeta: {
              docIdx: saved,
              status: "WRK",
              statusNm: statusLabel("WRK", "WRK"),
              baseKey: b.baseKey,
              baseDtDisp: formatBaseKey(screenCode, b.baseKey),
            },
          };
        },
        afterAll: async () => {
          await loadList();
          mesToast(MES.saveDone, "success");
        },
      });
      if (err) {
        mesToast(err.message, "warn");
        if (err.rowKey) void handleSelect(err.rowKey);
      }
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  }, "save");

  const handleDelete = () => asyncAct.run(async () => {
    if (!activeKey) return mesToast(MES.selectRow, "warn");
    const row = listRows.find((r) => r._key === activeKey);
    if (!row) return;
    if (row._rowState === "C") {
      removeDraft(activeKey);
      setSelectedRowSeq(null);
      return;
    }
    if (!docIdx) return mesToast(MES.selectRow, "warn");
    if (!canEdit) return mesToast(MES.inApprovalLocked, "warn");
    if (!canDelete) return;
    try {
      const keys = [{ docIdx }];
      await validateDeleteBizOps(screenCode, keys);
      if (!await mesConfirm(MES.deleteConfirm(docNo || "문서"))) return;
      await deleteBizOps(screenCode, keys);
      mesToast(MES.deleteDone, "success");
      await loadList();
      await handleSelect(null);
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  }, "del");

  usePageCommands({
    search: () => { void loadList(); },
    add: () => { void handleNew(); },
    save: () => { void handleSave(); },
    del: () => { void handleDelete(); },
  });

  const statusText = useMemo(
    () => (buf?.status ? statusLabel(String(buf.status), String(buf.status)) : "신규"),
    [buf?.status, statusLabel],
  );

  const setBaseKey = (next: string) => {
    if (!canEdit) return;
    const cleaned = next.replace(/\D/g, "");
    patchActive(
      (prev) => ({
        ...prev,
        baseKey: cleaned,
        header: applyBaseKey(screenCode, prev.header, cleaned),
      }),
      { baseKey: cleaned, baseDtDisp: formatBaseKey(screenCode, cleaned) },
    );
  };

  const patchHeader = (key: string, value: unknown) => {
    if (!canEdit) return;
    // 검교정 연도일 때(= baseKey) — 목록과 동기
    if (key === "baseYear" && screenCode === "calibration-target-management") {
      setBaseKey(String(value ?? "").replace(/\D/g, "").slice(0, 4));
      return;
    }
    // 재고 연월일 때(= baseKey) — 목록과 동기
    if (key === "baseYm" && screenCode === "inventory-check") {
      setBaseKey(String(value ?? "").replace(/\D/g, "").slice(0, 6));
      return;
    }
    // 일반 일지 기준일일 때(= baseKey) — 목록과 동기
    if (key === "baseDt" && screenCode !== "calibration-target-management" && screenCode !== "inventory-check") {
      setBaseKey(String(value ?? "").replace(/\D/g, "").slice(0, 8));
      return;
    }
    patchActive((prev) => ({ ...prev, header: { ...prev.header, [key]: value } }));
  };

  const patchRow = (rowSeq: number, key: string, value: unknown) => {
    if (!canEdit) return;
    patchActive((prev) => ({
      ...prev,
      rows: prev.rows.map((row) => (Number(row.rowSeq) === rowSeq ? { ...row, [key]: value } : row)),
    }));
  };

  const renderField = (field: Field, value: unknown, onChange: (v: string) => void, locked?: boolean) => {
    if (field.readOnly) return <span className="whitespace-normal leading-relaxed">{String(value ?? "")}</span>;
    if (field.type === "select") {
      return (
        <DocCellSelect
          value={String(value ?? "")}
          disabled={!canEdit || locked}
          options={(field.options ?? []).filter(Boolean).map((option) => ({ value: option, label: option }))}
          onChange={onChange}
          emptyLabel="-"
        />
      );
    }
    return (
      <DocCellInput
        type={field.type === "date" ? "date" : field.type === "number" ? "number" : "text"}
        value={field.type === "date" ? toDateCell(value) : String(value ?? "")}
        disabled={!canEdit || locked}
        onChange={(v) => onChange(field.type === "date" ? fromInputDate(v) : v)}
      />
    );
  };

  const rows = buf?.rows ?? [];
  const corrective = buf?.corrective ?? {};

  return (
    <DocFormLayout>
      <DocFormSearchToolbar
        // 기간·문서번호·작성자
        values={search}
        // 조건 부분 갱신
        onChange={(patch) => setSearch((prev) => ({ ...prev, ...patch }))}
        // 목록 재조회
        onSearch={() => void loadList()}
        // 좌측 draft 추가
        onAdd={() => void handleNew()}
        // dirty 전건 저장
        onSave={() => void handleSave()}
        // draft 제거 또는 서버 삭제
        onDelete={() => void handleDelete()}
        // 신규 권한
        canAdd={canWrite}
        // 삭제 — draft이거나 삭제 권한
        canDelete={!!activeKey && (canDelete || listRows.find((r) => r._key === activeKey)?._rowState === "C")}
        // 조회 busy
        searchBusy={asyncAct.isBusy()}
        // 저장·신규·삭제 busy
        actionBusy={asyncAct.isBusy()}
      />
      {docIdx ? (
        <DocumentApprovalToolbar
          // 저장 후 문서 idx
          docIdx={docIdx}
          // 문서 상태
          status={buf?.status ?? null}
          // dirty 전건 저장
          onSave={() => void handleSave()}
          // 임시·반려만
          canSave={!!canEdit}
          // 결재 권한
          canApprove={canWrite || canModify}
          // 작성 화면 — 상신·취소만 (검토·승인은 결재함)
          writerActionsOnly
          // 저장 busy
          saveBusy={asyncAct.isBusy("save")}
          // 결재 후 재조회
          onApproved={() => {
            void loadList();
            if (docIdx && activeKey) {
              void getBizOpsDetail(screenCode, docIdx).then((detail) => {
                putBuffer(activeKey, detailToBuf(screenCode, detail, user?.userNm), {
                  status: detail.header?.status ? String(detail.header.status) : null,
                  statusNm: statusLabel(String(detail.header?.status ?? ""), String(detail.header?.status ?? "")),
                });
              }).catch((error) => mesToast(mesError(error), "error"));
            }
          }}
          // 상태 라벨
          statusLabel={statusText}
        />
      ) : null}
      <DocFormBody withSummary>
        <DocFormDocumentList>
          <MesEditableGrid
            // 시설·재고·공정 문서목록 설정 키
            persistId={`ops-doc-list-${screenCode}`}
            // 서버 목록 + draft
            rows={listRows as EditableRow<ListMeta>[]}
            // 기준키·문서번호·상태
            columns={listColumns}
            // 신규행 기준키 편집
            editable={canWrite || canModify}
            // 패널 제목
            title="문서 목록"
            // 부모 flex 높이 채움
            height="100%"
            // 선택 키
            activeKey={activeKey}
            // 행 클릭 → 버퍼 전환
            onActivate={(row) => { void handleSelect(row._key ?? null); }}
            // 좌측 기준키 편집 → 버퍼·헤더 동기
            onCellChange={(key, field, cellValue) => {
              if (field !== "baseDtDisp" && field !== "baseKey") return;
              const next =
                screenCode === "calibration-target-management"
                  ? String(cellValue ?? "").replace(/\D/g, "").slice(0, 4)
                  : screenCode === "inventory-check"
                    ? String(cellValue ?? "").replace(/\D/g, "").slice(0, 6)
                    : fromInputDate(String(cellValue ?? ""));
              const prevBuf = getBuffer(key);
              if (!prevBuf) return;
              putBuffer(key, {
                ...prevBuf,
                baseKey: next,
                header: applyBaseKey(screenCode, prevBuf.header, next),
              }, {
                baseKey: next,
                baseDtDisp: formatBaseKey(screenCode, next),
              });
            }}
            // 잠금·권한 접근 판정
            access={listGrid.access}
            // 잠금 셀 시도 안내
            onLockedAttempt={listGrid.onLockedAttempt}
            showRowNum
          />
        </DocFormDocumentList>
        <DocFormMainPanel>
          {!buf ? (
            <p className="p-6 text-center text-sm text-slate-500">좌측에서 문서를 선택하거나 신규를 누르세요.</p>
          ) : (
            <DocPaper title={meta.title} writerNm={String(header.checkerNm ?? user?.userNm ?? "")}>
              <DocMetaTable
                rows={meta.headers.map((field) => ({
                  label: field.label,
                  node: renderField(field, header[field.key], (value) => patchHeader(field.key, value)),
                }))}
              />
              <p className="doc-section-title">기록 행</p>
              {rows.length === 0 ? (
                <p className="p-4 text-center text-xs text-slate-500">점검 행이 없습니다.</p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="doc-table">
                    <thead>
                      <tr>{meta.columns.map((column) => <th key={column.key}>{column.label}</th>)}</tr>
                    </thead>
                    <tbody>
                      {rows.map((row) => (
                        <tr
                          key={Number(row.rowSeq)}
                          className={cn(selectedRowSeq === Number(row.rowSeq) && "doc-row-selected")}
                          onClick={() => setSelectedRowSeq(Number(row.rowSeq))}
                        >
                          {meta.columns.map((column) => {
                            const raw = column.key === "resultSummary" ? JSON.stringify(row.results ?? []) : row[column.key];
                            return (
                              <td key={column.key}>
                                {renderField(column, raw, (value) => patchRow(Number(row.rowSeq), column.key, value), column.key === "resultSummary")}
                              </td>
                            );
                          })}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
              {canEdit ? (
                <DocRowToolbar
                  onAdd={() => patchActive((prev) => ({
                    ...prev,
                    rows: [...prev.rows, { rowSeq: (prev.rows.reduce((m, r) => Math.max(m, Number(r.rowSeq) || 0), 0) || 0) + 1 }],
                  }))}
                  onRemove={() => {
                    if (selectedRowSeq == null) { mesToast("삭제할 행을 선택하세요.", "warn"); return; }
                    patchActive((prev) => ({
                      ...prev,
                      rows: prev.rows.filter((r) => Number(r.rowSeq) !== selectedRowSeq).map((r, i) => ({ ...r, rowSeq: i + 1 })),
                    }));
                    setSelectedRowSeq(null);
                  }}
                  canRemove={selectedRowSeq != null}
                />
              ) : null}
              <DocDeviationFooter
                // 이탈·개선조치
                value={corrective}
                // 버퍼 갱신
                onChange={(next) => patchActive((prev) => ({ ...prev, corrective: next }))}
                // 임시·반려·신규만
                editable={!!canEdit}
              />
            </DocPaper>
          )}
        </DocFormMainPanel>
        <DocFormSidePanel>
          <DocSummaryPanel
            // 문서번호
            documentNumber={docNo}
            // 상태
            statusLabel={statusText}
            // 필수 진행
            requiredFieldProgress={{ completed: Number(rows.length > 0), total: 1 }}
            // 결재선
            approvalLine="작성 → 검토 → 승인"
            // 힌트
            hint="문서 표에서 직접 입력합니다. 여러 draft를 만든 경우 저장 시 전건이 순차 저장됩니다."
          />
        </DocFormSidePanel>
      </DocFormBody>
    </DocFormLayout>
  );
}
