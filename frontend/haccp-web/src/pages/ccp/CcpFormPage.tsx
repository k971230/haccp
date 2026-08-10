/**
 * CcpFormPage — CCP 금속검출·검증점검표·연간 검증계획서 문서형 편집 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 신규 시 좌측 draft(C)를 쌓고 건별 버퍼를 편집한 뒤 dirty 전건 검증·순차 저장한다
 *   2) 금속·검증·연간 본문(doc-table)은 유지하고 셸은 DocFormLayout 3열을 쓴다
 *   3) 결재 툴바는 저장 문서(docIdx)에만 노출하며 draft에는 결재하지 않는다
 *
 * PIPELINE[HF85] CCP 추가 양식 화면 공통
 * PIPELINE[HF120, HF84, HF51] 연관 모듈
 */
// 역할 — 상태·효과
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 비동기·권한
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useAuthStore } from "@/stores/authStore";
// 역할 — DB형 문서 draft·다건 버퍼 세션
import { useDocFormSession, type DocListMeta } from "@/hooks/useDocFormSession";
// 역할 — 셸 툴바·단축키 CRUD 등록
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — mes-web형 좌측 문서목록 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — 목록 그리드 잠금(신규만 기준키 편집)
import { useGridAccess } from "@/hooks/useGridAccess";
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
// 역할 — 대화·오류
import { mesConfirm, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
// 역할 — 문서형 레이아웃
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
import { DocCellInput, DocCellSelect, DocCellTime } from "@/components/form/DocCell";
import { DocFormMeta } from "@/components/form/DocFormMeta";
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
// 역할 — 홈·문서함 ?docIdx= deep-link
import { useDocIdxQuery } from "@/hooks/useDocIdxQuery";
import {
  deleteCcpForm,
  detailCcpForm,
  listCcpForms,
  saveCcpForm,
  validateDeleteCcpForm,
  type CcpFormCode,
  type CcpRow,
} from "@/api/ccpFormsApi";
import type { CcpLimitRow } from "@/api/ccpColdApi";

export interface CcpFormPageProps { form: CcpFormCode; screenCode: string; title: string; }

/** CcpRow 필드 조회 — camel/snake 모두 허용 */
const value = (row: CcpRow | null | undefined, key: string) => String(row?.[key] ?? row?.[key.replace(/[A-Z]/g, (x) => `_${x.toLowerCase()}`)] ?? "");
/** 임시·반려·신규만 편집 */
const editableStatus = (status: string | null | undefined) => !status || status === "WRK" || status === "RJT";

/** 금속 감도 통과 칸 — 검출 ○ / 불검출 × */
const OX = [{ value: "O", label: "○" }, { value: "X", label: "×" }];
const YN = [{ value: "Y", label: "예" }, { value: "N", label: "아니오" }];
const METAL_PASS_FIELDS = [
  { field: "feOnlyCd", label: "Fe만 통과" },
  { field: "stsOnlyCd", label: "STS만 통과" },
  { field: "prodOnlyCd", label: "제품만 통과" },
  { field: "feProdCd", label: "Fe+제품 통과" },
  { field: "stsProdCd", label: "STS+제품 통과" },
] as const;

/** 좌측 목록 메타 — baseKey는 일지 YYYYMMDD / 연간 YYYY */
type ListMeta = DocListMeta & {
  // 목록 표시용 기준키
  baseDtDisp?: string;
  // DOC_STATUS 라벨
  statusNm?: string;
};

/** 건별 본문 버퍼 */
type Buf = {
  // 저장 문서 PK — draft는 null
  docIdx: number | null;
  // 문서번호
  docNo: string;
  // DOC_STATUS
  status: string | null;
  // 기준키 — 연간은 YYYY, 그 외 YYYYMMDD
  baseKey: string;
  // 헤더(담당·CCP 등)
  header: CcpRow;
  // 감도·검증·연간 본문 행
  rows: CcpRow[];
  // 금속 제품통과 행
  passRows: CcpRow[];
  // 한계기준 배너
  limits: CcpLimitRow[];
  // 이탈·개선조치
  corrective: DocCorrectiveValue;
};

function blankRows(form: CcpFormCode): CcpRow[] {
  if (form === "metal-monitor") {
    return [{ rowSeq: 1, phaseCd: "BEFORE", placeNm: "", productNm: "", checkTime: "", feOnlyCd: "", stsOnlyCd: "", prodOnlyCd: "", feProdCd: "", stsProdCd: "", judgeCd: "", checkerNm: "" }];
  }
  if (form === "verification-check") {
    return [
      { rowSeq: 1, procNm: "원료육 냉장보관", verifyDesc: "", answerCd: "", recordDesc: "" },
      { rowSeq: 2, procNm: "금속검출", verifyDesc: "", answerCd: "", recordDesc: "" },
      { rowSeq: 3, procNm: "완제품 냉장보관", verifyDesc: "", answerCd: "", recordDesc: "" },
    ];
  }
  return [{ rowSeq: 1, verifyTarget: "", verifyMethod: "", months: Array.from({ length: 12 }, (_, i) => ({ monthNo: i + 1, planYn: "N" })) }];
}

/** 감도 O/X 조합으로 결과 미리보기 — 하나라도 ×면 부적합 */
function metalJudge(row: CcpRow): string {
  const codes = METAL_PASS_FIELDS.map((f) => value(row, f.field));
  if (codes.every((c) => !c)) return "";
  return codes.some((c) => c === "X") ? "F" : "P";
}

/** 기준키 표시 — 연간은 연도, 일지는 YYYY-MM-DD */
function formatBaseKey(form: CcpFormCode, baseKey: string): string {
  if (form === "annual-verification-plan") return baseKey;
  return toInputDate(baseKey);
}

/** 상세 API → 버퍼 */
function detailToBuf(form: CcpFormCode, data: CcpRow, userNm?: string): Buf {
  const detailHeader = (data.header as CcpRow | null) ?? null;
  const rawBase = detailHeader ? value(detailHeader, "baseDt") : "";
  const baseKey = rawBase
    ? rawBase.slice(0, form === "annual-verification-plan" ? 4 : 8)
    : (form === "annual-verification-plan" ? todayYmd().slice(0, 4) : todayYmd());
  const nextRows = (form === "metal-monitor" ? data.sensRows : data.rows) as CcpRow[] | undefined;
  const ca = data.corrective as DocCorrectiveValue | null | undefined;
  return {
    docIdx: detailHeader ? Number(value(detailHeader, "docIdx")) || null : null,
    docNo: detailHeader ? value(detailHeader, "docNo") : "",
    status: detailHeader ? value(detailHeader, "status") || null : null,
    baseKey,
    header: detailHeader ?? { mngNm: userNm, checkerNm: userNm, ccpCd: "CCP-2P" },
    rows: nextRows && nextRows.length > 0 ? nextRows : blankRows(form),
    passRows: (data.passRows as CcpRow[]) ?? [],
    limits: (data.limits as CcpLimitRow[]) ?? [],
    corrective: {
      deviationDesc: ca?.deviationDesc ?? "",
      actionDesc: ca?.actionDesc ?? "",
      actionUserNm: ca?.actionUserNm ?? "",
      confirmUserNm: ca?.confirmUserNm ?? "",
    },
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) CCP 추가 양식 문서형 화면을 draft 세션으로 렌더링한다
 *   2) Metal/Verify/Plan 페이지가 form props로 마운트한다
 *   3) API 실패는 업무 토스트만 표시한다
 */
export function CcpFormPage({ form, screenCode, title }: CcpFormPageProps) {
  const asyncAction = useAsyncAction();
  const user = useAuthStore((s) => s.user);
  const canWrite = useAuthStore((s) => s.can(screenCode, "write"));
  const canModify = useAuthStore((s) => s.can(screenCode, "modify"));
  const canDelete = useAuthStore((s) => s.can(screenCode, "delete"));
  // 좌측 문서 목록 — 신규행만 기준키 편집
  const listGrid = useGridAccess({ newOnly: ["baseDtDisp", "baseKey"] }, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });
  // 문서상태 라벨 — DOC_STATUS 공통코드
  const { label: statusLabel } = useCommonCodes("DOC_STATUS");
  // draft·버퍼·일괄 저장 세션
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
  // 본문 표 행 선택 — 세션과 무관한 UI 포커스
  const [selectedRow, setSelectedRow] = useState<number | null>(null);
  const [selectedPass, setSelectedPass] = useState<number | null>(null);

  const buf = activeBuffer;
  const docIdx = buf?.docIdx ?? null;
  const status = buf?.status ?? null;
  const isEdit = editableStatus(status) && (docIdx ? canModify : canWrite);

  const listColumns = useMemo<GridColumn<ListMeta>[]>(() => [
    form === "annual-verification-plan"
      ? {
          // 연간 — YYYY 텍스트
          field: "baseKey",
          header: "연도",
          width: 100,
          editableOnNew: true,
        }
      : {
          // 일지 — YYYY-MM-DD 달력
          field: "baseDtDisp",
          header: "기준일",
          width: 120,
          editableOnNew: true,
          type: "date" as const,
        },
    { field: "docNo", header: "문서", width: 120 },
    { field: "statusNm", header: "상태", width: 80 },
  ], [form]);

  const limitBanner = useMemo(() => {
    if (!buf) return undefined;
    if (form === "metal-monitor") {
      return buf.limits.find((l) => l.ccpCd === "CCP-2P") || buf.limits.find((l) => l.limitType === "METAL") || buf.limits[0];
    }
    return buf.limits[0];
  }, [buf, form]);

  const paperTitle = form === "metal-monitor"
    ? (limitBanner?.formTitle?.trim() || "CCP 금속검출 모니터링 일지")
    : title;

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 서버 목록을 조회해 draft를 유지한 채 좌측 그리드를 갱신한다
   *   2) 조회·저장·삭제·결재 후 호출한다
   *   3) 실패 시 업무 토스트만 표시한다
   */
  const loadList = useCallback(async () => {
    const q = searchRef.current;
    try {
      const server = await listCcpForms(form, {
        fromDt: q.fromDt,
        toDt: q.toDt,
        docNo: q.docNo.trim() || undefined,
        writer: q.writer.trim() || undefined,
      });
      replaceServerList(
        server.map((item) => {
          const baseRaw = value(item, "baseDt");
          const baseKey = baseRaw.slice(0, form === "annual-verification-plan" ? 4 : 8);
          const st = value(item, "status");
          return {
            docIdx: Number(value(item, "docIdx")) || null,
            docNo: value(item, "docNo"),
            status: st || null,
            baseKey,
            baseDtDisp: formatBaseKey(form, baseKey),
            statusNm: statusLabel(st, st),
            ngCnt: Number(item.ngCnt) || 0,
          } satisfies ListMeta;
        }),
        (row) => String(row.docIdx),
      );
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  }, [form, replaceServerList, statusLabel]);

  useEffect(() => { void loadList(); }, [loadList]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 좌측 행을 선택하고 버퍼가 없으면 상세 API로 적재한다
   *   2) 목록 onActivate에서 호출한다
   *   3) 실패 시 토스트·선택 유지
   */
  const handleSelect = useCallback(async (key: string | null) => {
    setSelectedRow(null);
    setSelectedPass(null);
    await selectKey(key, async (k, row) => {
      const cached = getBuffer(k);
      if (cached) return cached;
      // draft인데 버퍼가 없을 때(= 비정상) — 빈 뼈대
      if (row._rowState === "C" || !row.docIdx) {
        return {
          docIdx: null,
          docNo: "",
          status: null,
          baseKey: row.baseKey || (form === "annual-verification-plan" ? todayYmd().slice(0, 4) : todayYmd()),
          header: { mngNm: user?.userNm, checkerNm: user?.userNm, ccpCd: "CCP-2P" },
          rows: blankRows(form),
          passRows: [],
          limits: [],
          corrective: {},
        };
      }
      try {
        const data = await detailCcpForm(form, row.docIdx);
        return detailToBuf(form, data, user?.userNm);
      } catch (error) {
        mesToast(mesError(error), "error");
        return null;
      }
    });
  }, [form, getBuffer, selectKey, user?.userNm]);

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
   *   1) 신규 draft 행과 본문 버퍼를 추가하고 포커스한다
   *   2) 신규 버튼·셸 add에서 호출한다
   *   3) 상세(null)로 한계·기본행을 받은 뒤 실패 시 토스트
   */
  const handleNew = () => asyncAction.run(async () => {
    if (!canWrite) return;
    // 당일(당해) 복수 문서 허용 — 기존 기준키 행이 있어도 항상 새 draft
    const nextKey = form === "annual-verification-plan" ? todayYmd().slice(0, 4) : todayYmd();
    try {
      const data = await detailCcpForm(form, null);
      const next = detailToBuf(form, data, user?.userNm);
      // 신규는 항상 오늘/올해 기준키로 시작
      next.docIdx = null;
      next.docNo = "";
      next.status = null;
      next.baseKey = nextKey;
      addDraft(
        {
          docIdx: null,
          docNo: "",
          status: null,
          baseKey: next.baseKey,
          baseDtDisp: formatBaseKey(form, next.baseKey),
          statusNm: "신규",
          ngCnt: 0,
        },
        next,
      );
      setSelectedRow(null);
      setSelectedPass(null);
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  }, "add");

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) dirty 전건을 검증한 뒤 단건 save를 순차 호출한다
   *   2) 저장 버튼·셸 save에서 호출한다
   *   3) 검증 실패 시 해당 draft로 포커스하고 API를 호출하지 않는다
   */
  const handleSave = () => asyncAction.run(async () => {
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
            if (form === "annual-verification-plan") {
              if (!/^\d{4}$/.test(b.baseKey)) return { message: MES.required("연도"), rowKey: key };
            } else if (!/^\d{8}$/.test(b.baseKey)) {
              return { message: MES.required("기준일"), rowKey: key };
            }
            if (seen.has(b.baseKey)) {
              return { message: `기준키가 중복되었습니다: ${b.baseKey}`, rowKey: key };
            }
            seen.add(b.baseKey);
            if (b.rows.length === 0) return { message: MES.required("기록 행"), rowKey: key };
          }
          return null;
        },
        saveOne: async (_row, b) => {
          const sens = form === "metal-monitor"
            ? b.rows.map((row, i) => ({ ...row, rowSeq: i + 1, judgeCd: value(row, "judgeCd") || metalJudge(row) }))
            : undefined;
          const limitBannerOne = form === "metal-monitor"
            ? (b.limits.find((l) => l.ccpCd === "CCP-2P") || b.limits.find((l) => l.limitType === "METAL") || b.limits[0])
            : b.limits[0];
          const saved = await saveCcpForm(form, {
            ...b.header,
            docIdx: b.docIdx,
            baseDt: b.baseKey,
            ccpCd: value(b.header, "ccpCd") || "CCP-2P",
            feSize: limitBannerOne?.feSize ?? b.header.feSize,
            stsSize: limitBannerOne?.stsSize ?? b.header.stsSize,
            mngNm: value(b.header, "mngNm") || value(b.header, "checkerNm") || user?.userNm || "",
            rows: form === "metal-monitor" ? [] : b.rows,
            sensRows: sens,
            passRows: form === "metal-monitor" ? b.passRows.map((row, i) => ({ ...row, rowSeq: i + 1 })) : undefined,
            checkerId: value(b.header, "checkerId") || user?.userId || "",
            checkerNm: value(b.header, "checkerNm") || value(b.header, "mngNm") || user?.userNm || "",
            // 검증점검표 — 모니터링 일지 확인 SPAN
            monitorChkRmk: value(b.header, "monitorChkRmk"),
            corrective: b.corrective,
          });
          return {
            docIdx: saved,
            listMeta: {
              docIdx: saved,
              status: "WRK",
              statusNm: statusLabel("WRK", "WRK"),
              baseKey: b.baseKey,
              baseDtDisp: formatBaseKey(form, b.baseKey),
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

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) C draft는 로컬 제거, 저장행은 validate-delete 후 삭제한다
   *   2) 삭제 버튼·셸 del에서 호출한다
   *   3) 실패 시 업무 토스트만 표시한다
   */
  const handleDelete = () => asyncAction.run(async () => {
    if (!activeKey) return mesToast(MES.selectRow, "warn");
    const row = listRows.find((r) => r._key === activeKey);
    if (!row) return;
    // C행일 때(= 미저장 draft) — 서버 호출 없이 로컬 제거
    if (row._rowState === "C") {
      removeDraft(activeKey);
      setSelectedRow(null);
      setSelectedPass(null);
      return;
    }
    if (!docIdx || !canDelete) return;
    if (!isEdit) return mesToast(MES.inApprovalLocked, "warn");
    try {
      await validateDeleteCcpForm(form, [{ docIdx }]);
      if (!await mesConfirm(MES.deleteConfirm(buf?.docNo || "문서"))) return;
      await deleteCcpForm(form, [{ docIdx }]);
      mesToast(MES.deleteDone, "success");
      await loadList();
      await handleSelect(null);
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  }, "del");

  // 셸 툴바·단축키 — 조회·신규·저장·삭제
  usePageCommands({
    search: () => { void loadList(); },
    add: () => { void handleNew(); },
    save: () => { void handleSave(); },
    del: () => { void handleDelete(); },
  });

  const patchRow = (index: number, key: string, next: unknown) => {
    if (!isEdit) return;
    patchActive((prev) => ({
      ...prev,
      rows: prev.rows.map((row, rowIndex) => {
        if (rowIndex !== index) return row;
        const updated = { ...row, [key]: next };
        if (form === "metal-monitor" && METAL_PASS_FIELDS.some((f) => f.field === key)) {
          updated.judgeCd = metalJudge(updated);
        }
        return updated;
      }),
    }));
  };

  const setBaseKey = (next: string) => {
    if (!isEdit) return;
    patchActive(
      (prev) => ({ ...prev, baseKey: next }),
      { baseKey: next, baseDtDisp: formatBaseKey(form, next) },
    );
  };

  const addSensRow = () => patchActive((prev) => ({
    ...prev,
    rows: [...prev.rows, { rowSeq: prev.rows.length + 1, placeNm: "", productNm: "", checkTime: "", feOnlyCd: "", stsOnlyCd: "", prodOnlyCd: "", feProdCd: "", stsProdCd: "", judgeCd: "", checkerNm: user?.userNm || "" }],
  }));
  const removeSensRow = () => {
    if (selectedRow == null) { mesToast("삭제할 행을 선택하세요.", "warn"); return; }
    patchActive((prev) => ({
      ...prev,
      rows: prev.rows.filter((_, i) => i !== selectedRow).map((r, i) => ({ ...r, rowSeq: i + 1 })),
    }));
    setSelectedRow(null);
  };
  const addPassRow = () => patchActive((prev) => ({
    ...prev,
    passRows: [...prev.passRows, { rowSeq: prev.passRows.length + 1, productNm: "", passQty: "", detectQty: "", remark: "" }],
  }));
  const removePassRow = () => {
    if (selectedPass == null) { mesToast("삭제할 행을 선택하세요.", "warn"); return; }
    patchActive((prev) => ({
      ...prev,
      passRows: prev.passRows.filter((_, i) => i !== selectedPass).map((r, i) => ({ ...r, rowSeq: i + 1 })),
    }));
    setSelectedPass(null);
  };

  const rows = buf?.rows ?? [];
  const passRows = buf?.passRows ?? [];
  const header = buf?.header ?? {};
  const corrective = buf?.corrective ?? {};
  const baseKey = buf?.baseKey ?? "";
  const docNo = buf?.docNo ?? "";

  return (
    <DocFormLayout>
      <DocFormSearchToolbar
        // 기간·문서번호·작성자
        values={search}
        // 조건 부분 갱신
        onChange={(patch) => setSearch((prev) => ({ ...prev, ...patch }))}
        // 목록 재조회 — draft C행 유지
        onSearch={() => void loadList()}
        // 좌측 C draft + 버퍼 추가
        onAdd={() => void handleNew()}
        // dirty 전건 검증 후 순차 저장
        onSave={() => void handleSave()}
        // C → removeDraft / 저장행 → validate-delete
        onDelete={() => void handleDelete()}
        // 신규 권한
        canAdd={canWrite}
        // 삭제 — draft이거나 삭제 권한
        canDelete={!!activeKey && (canDelete || listRows.find((r) => r._key === activeKey)?._rowState === "C")}
        // 조회 busy
        searchBusy={asyncAction.isBusy()}
        // 저장·신규·삭제 busy
        actionBusy={asyncAction.isBusy()}
      />
      {/* 저장 문서(docIdx)일 때만 결재 — draft는 미노출 */}
      {docIdx ? (
        <DocumentApprovalToolbar
          // 저장 후 문서 idx
          docIdx={docIdx}
          // 문서 상태
          status={status}
          // 저장 — dirty 전건
          onSave={() => void handleSave()}
          // 임시·반려만
          canSave={!!isEdit}
          // 결재 권한 — draft가 아니므로 true 가능
          canApprove={canWrite || canModify}
          // 작성 화면 — 상신·취소만 (검토·승인은 결재함)
          writerActionsOnly
          // 저장 busy
          saveBusy={asyncAction.isBusy("save")}
          // 결재 후 재조회·활성 버퍼 갱신
          onApproved={() => {
            void loadList();
            if (docIdx && activeKey) {
              void detailCcpForm(form, docIdx).then((data) => {
                putBuffer(activeKey, detailToBuf(form, data, user?.userNm), {
                  status: value((data.header as CcpRow) ?? {}, "status") || null,
                  statusNm: statusLabel(value((data.header as CcpRow) ?? {}, "status"), value((data.header as CcpRow) ?? {}, "status")),
                });
              }).catch((error) => mesToast(mesError(error), "error"));
            }
          }}
          // 상태 라벨
          statusLabel={status ? statusLabel(status, status) : "신규"}
        />
      ) : null}
      <DocFormBody withSummary>
        <DocFormDocumentList>
          <MesEditableGrid
            // CCP 양식 문서목록 설정 키
            persistId={`ccp-form-list-${form}`}
            // 서버 목록 + 로컬 draft
            rows={listRows as EditableRow<ListMeta>[]}
            // 기준키·문서·상태 — 신규행만 기준키 편집
            columns={listColumns}
            // 신규 C행 기준키 편집 허용
            editable={canWrite || canModify}
            // 패널 제목
            title="문서 목록"
            // 부모 flex 높이 채움
            height="100%"
            // 선택 draft/문서
            activeKey={activeKey}
            // 행 클릭 시 버퍼 전환·상세 적재
            onActivate={(row) => { void handleSelect(row._key ?? null); }}
            // 신규행 기준키 셀 변경 → 버퍼·목록 동기화
            onCellChange={(key, field, cellValue) => {
              if (field !== "baseDtDisp" && field !== "baseKey") return;
              const next = form === "annual-verification-plan"
                ? String(cellValue ?? "").replace(/\D/g, "").slice(0, 4)
                : fromInputDate(String(cellValue ?? ""));
              const prevBuf = getBuffer(key);
              if (!prevBuf) return;
              putBuffer(key, { ...prevBuf, baseKey: next }, {
                baseKey: next,
                baseDtDisp: formatBaseKey(form, next),
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
            <DocPaper title={paperTitle} writerNm={value(header, "mngNm") || value(header, "checkerNm") || user?.userNm}>
              <DocFormMeta
                // 기준일/연도 — 버퍼 baseKey와 좌측 목록 동기
                baseDtNode={form === "annual-verification-plan" ? (
                  <DocCellInput type="number" value={baseKey} disabled={!isEdit} onChange={setBaseKey} />
                ) : (
                  <DocCellInput type="date" value={toInputDate(baseKey)} disabled={!isEdit} onChange={(v) => setBaseKey(fromInputDate(v))} />
                )}
                managerLabel={form === "metal-monitor" ? "담당자" : "점검자"}
                managerNode={(
                  <DocCellInput
                    value={value(header, form === "metal-monitor" ? "mngNm" : "checkerNm") || user?.userNm || ""}
                    disabled={!isEdit}
                    onChange={(v) => patchActive((prev) => ({
                      ...prev,
                      header: {
                        ...prev.header,
                        mngNm: form === "metal-monitor" ? v : prev.header.mngNm,
                        checkerNm: v,
                      },
                    }))}
                  />
                )}
                showLimitBlock={form === "metal-monitor"}
                limitRmk={limitBanner?.limitRmk}
                cycleRmk={limitBanner?.cycleRmk}
                methodRmk={limitBanner?.methodRmk}
                // 검증점검표 — 모니터링 일지 확인 SPAN
                extraRows={form === "verification-check" ? [{
                  label: "모니터링 일지 확인",
                  node: (
                    <DocCellInput
                      // 헤더 monitorChkRmk — SP·API가 주면 라운드트립
                      value={value(header, "monitorChkRmk")}
                      // 임시·반려만
                      disabled={!isEdit}
                      // 헤더 버퍼 갱신
                      onChange={(v) => patchActive((prev) => ({
                        ...prev,
                        header: { ...prev.header, monitorChkRmk: v },
                      }))}
                    />
                  ),
                }] : undefined}
              />

              {form === "metal-monitor" ? (
                <>
                  <p className="doc-section-title">금속검출기 감도 모니터링 (판정 – 검출 : ○, 불검출 : ×)</p>
                  <div className="overflow-x-auto">
                    <table className="doc-table">
                      <thead>
                        <tr>
                          <th>위치</th>
                          <th>품명</th>
                          <th>점검시간</th>
                          {METAL_PASS_FIELDS.map((f) => <th key={f.field} className="doc-col-pass">{f.label}</th>)}
                          <th>결과</th>
                          <th>점검자서명</th>
                        </tr>
                      </thead>
                      <tbody>
                        {rows.map((row, index) => {
                          const judge = value(row, "judgeCd") || metalJudge(row);
                          return (
                            <tr
                              key={index}
                              className={cn(selectedRow === index && "doc-row-selected")}
                              onClick={() => setSelectedRow(index)}
                            >
                              <td>
                                <DocCellInput
                                  // 위치(비고) — place_nm
                                  value={value(row, "placeNm")}
                                  disabled={!isEdit}
                                  onChange={(v) => patchRow(index, "placeNm", v)}
                                />
                              </td>
                              <td><DocCellInput value={value(row, "productNm")} disabled={!isEdit} onChange={(v) => patchRow(index, "productNm", v)} /></td>
                              <td>
                                <DocCellTime
                                  // 점검시간 — type=time, 저장 HHMM
                                  value={value(row, "checkTime")}
                                  disabled={!isEdit}
                                  storage="hhmm"
                                  onChange={(v) => patchRow(index, "checkTime", v)}
                                />
                              </td>
                              {METAL_PASS_FIELDS.map((f) => (
                                <td key={f.field} className="text-center">
                                  <DocCellSelect value={value(row, f.field)} disabled={!isEdit} options={OX} onChange={(v) => patchRow(index, f.field, v)} emptyLabel="" />
                                </td>
                              ))}
                              <td className={cn("text-center font-medium", judge === "F" ? "text-red-600" : "text-slate-700")}>
                                {judge === "F" ? "부적합" : judge === "P" ? "적합" : ""}
                              </td>
                              <td><DocCellInput value={value(row, "checkerNm")} disabled={!isEdit} onChange={(v) => patchRow(index, "checkerNm", v)} /></td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                  {isEdit ? <DocRowToolbar onAdd={addSensRow} onRemove={removeSensRow} canRemove={selectedRow != null} addLabel="감도 행 추가" /> : null}

                  <p className="doc-section-title mt-4">금속검출기 제품 통과</p>
                  <table className="doc-table">
                    <thead><tr><th>품명</th><th>통과량</th><th>검출량</th><th>특이사항</th></tr></thead>
                    <tbody>
                      {passRows.map((row, index) => (
                        <tr
                          key={index}
                          className={cn(selectedPass === index && "doc-row-selected")}
                          onClick={() => setSelectedPass(index)}
                        >
                          {(["productNm", "passQty", "detectQty", "remark"] as const).map((field) => (
                            <td key={field}>
                              <DocCellInput
                                value={value(row, field)}
                                disabled={!isEdit}
                                onChange={(v) => patchActive((prev) => ({
                                  ...prev,
                                  passRows: prev.passRows.map((r, i) => (i === index ? { ...r, [field]: v } : r)),
                                }))}
                              />
                            </td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {isEdit ? <DocRowToolbar onAdd={addPassRow} onRemove={removePassRow} canRemove={selectedPass != null} addLabel="통과 행 추가" /> : null}
                </>
              ) : form === "verification-check" ? (
                <>
                  <p className="doc-section-title">검증 점검 내용</p>
                  <table className="doc-table">
                    <thead><tr><th>공정</th><th>검증 내용</th><th>예/아니오</th><th>기록</th></tr></thead>
                    <tbody>
                      {rows.map((row, index) => (
                        <tr key={index} className={cn(selectedRow === index && "doc-row-selected")} onClick={() => setSelectedRow(index)}>
                          <td><DocCellInput value={value(row, "procNm")} disabled={!isEdit} onChange={(v) => patchRow(index, "procNm", v)} /></td>
                          <td><DocCellInput value={value(row, "verifyDesc")} disabled={!isEdit} onChange={(v) => patchRow(index, "verifyDesc", v)} /></td>
                          <td><DocCellSelect value={value(row, "answerCd")} disabled={!isEdit} options={YN} onChange={(v) => patchRow(index, "answerCd", v)} emptyLabel="" /></td>
                          <td><DocCellInput value={value(row, "recordDesc")} disabled={!isEdit} onChange={(v) => patchRow(index, "recordDesc", v)} /></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {isEdit ? (
                    <DocRowToolbar
                      onAdd={() => patchActive((prev) => ({
                        ...prev,
                        rows: [...prev.rows, { rowSeq: prev.rows.length + 1, procNm: "", verifyDesc: "", answerCd: "", recordDesc: "" }],
                      }))}
                      onRemove={() => {
                        if (selectedRow == null) { mesToast("삭제할 행을 선택하세요.", "warn"); return; }
                        patchActive((prev) => ({
                          ...prev,
                          rows: prev.rows.filter((_, i) => i !== selectedRow).map((r, i) => ({ ...r, rowSeq: i + 1 })),
                        }));
                        setSelectedRow(null);
                      }}
                      canRemove={selectedRow != null}
                    />
                  ) : null}
                </>
              ) : (
                <>
                  <p className="doc-section-title">연간 검증계획</p>
                  <div className="overflow-x-auto">
                    <table className="doc-table">
                      <thead>
                        <tr>
                          <th>검증대상</th><th>검증방법</th>
                          {Array.from({ length: 12 }, (_, month) => <th key={month}>{month + 1}월</th>)}
                        </tr>
                      </thead>
                      <tbody>
                        {rows.map((row, index) => (
                          <tr key={index} className={cn(selectedRow === index && "doc-row-selected")} onClick={() => setSelectedRow(index)}>
                            <td>
                              <DocCellInput
                                value={value(row, "verifyTarget")}
                                disabled={!isEdit}
                                onChange={(v) => patchActive((prev) => ({
                                  ...prev,
                                  rows: prev.rows.map((r, i) => (i === index ? { ...r, verifyTarget: v, rowSeq: i + 1 } : r)),
                                }))}
                              />
                            </td>
                            <td>
                              <DocCellInput
                                value={value(row, "verifyMethod")}
                                disabled={!isEdit}
                                onChange={(v) => patchActive((prev) => ({
                                  ...prev,
                                  rows: prev.rows.map((r, i) => (i === index ? { ...r, verifyMethod: v } : r)),
                                }))}
                              />
                            </td>
                            {Array.from({ length: 12 }, (_, month) => {
                              const months = (row.months as CcpRow[] | undefined) ?? [];
                              const checked = months[month]?.planYn === "Y";
                              return (
                                <td key={month} className="text-center">
                                  <input
                                    type="checkbox"
                                    disabled={!isEdit}
                                    checked={checked}
                                    onChange={(e) => {
                                      patchActive((prev) => ({
                                        ...prev,
                                        rows: prev.rows.map((r, i) => {
                                          if (i !== index) return r;
                                          const curMonths = (r.months as CcpRow[] | undefined) ?? [];
                                          return {
                                            ...r,
                                            months: Array.from({ length: 12 }, (_, n) => ({
                                              ...curMonths[n],
                                              monthNo: n + 1,
                                              planYn: n === month ? (e.target.checked ? "Y" : "N") : (curMonths[n]?.planYn ?? "N"),
                                            })),
                                          };
                                        }),
                                      }));
                                    }}
                                  />
                                </td>
                              );
                            })}
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  {isEdit ? (
                    <DocRowToolbar
                      onAdd={() => patchActive((prev) => ({ ...prev, rows: [...prev.rows, ...blankRows(form)] }))}
                      onRemove={() => {
                        if (selectedRow == null) { mesToast("삭제할 행을 선택하세요.", "warn"); return; }
                        patchActive((prev) => ({
                          ...prev,
                          rows: prev.rows.filter((_, i) => i !== selectedRow).map((r, i) => ({ ...r, rowSeq: i + 1 })),
                        }));
                        setSelectedRow(null);
                      }}
                      canRemove={selectedRow != null}
                    />
                  ) : null}
                </>
              )}

              <DocDeviationFooter
                // 이탈·개선조치 값
                value={corrective}
                // 버퍼 갱신
                onChange={(next) => patchActive((prev) => ({ ...prev, corrective: next }))}
                // 임시·반려·신규만
                editable={!!isEdit}
              />
            </DocPaper>
          )}
        </DocFormMainPanel>
        <DocFormSidePanel>
          <DocSummaryPanel
            // 문서번호 — draft는 빈값
            documentNumber={docNo}
            // 상태 라벨
            statusLabel={status ? statusLabel(status, status) : "신규"}
            // 필수 진행률
            requiredFieldProgress={{ completed: Number(Boolean(baseKey)) + Number(rows.length > 0), total: 2 }}
            // 결재선 안내
            approvalLine="작성 → 검토 → 승인"
            // 입력 힌트
            hint="문서 표에 직접 입력합니다. 저장 후 상단 툴바에서 상신·승인·반려를 진행하세요."
          />
        </DocFormSidePanel>
      </DocFormBody>
    </DocFormLayout>
  );
}

export default CcpFormPage;
