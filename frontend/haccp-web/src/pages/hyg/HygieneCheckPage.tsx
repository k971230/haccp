/**
 * HygieneCheckPage — 위생관리 DB형 양식 문서형 편집 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 신규 시 좌측 draft(C)를 쌓고 dirty 전건 검증 후 단건 save를 순차 호출한다
 *   2) O/X·방충 콤보·일일 시각은 DocCellSelect·DocCellTime으로 DocForm 셀을 맞춘다
 *   3) 결재 툴바는 저장 문서(docIdx)에만 노출한다
 *
 * PIPELINE[HF83] 위생 화면
 * PIPELINE[HF120, HF82, HF29] 연관 모듈
 */
// 역할 — React 상태·초기 로드·메모
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 홈·문서함 ?docIdx= deep-link
import { useDocIdxQuery } from "@/hooks/useDocIdxQuery";
// 역할 — 로그인·권한
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — DB형 문서 draft·다건 버퍼 세션
import { useDocFormSession, type DocListMeta } from "@/hooks/useDocFormSession";
// 역할 — 셸 툴바·단축키 CRUD 등록
import { usePageCommands } from "@/shell/pageCommands";
import { mesConfirm, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { MesButton } from "@/components/ui/MesButton";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — 목록 그리드 잠금(신규만 기준일 편집)
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
import { DocCellInput, DocCellSelect, DocCellTime, DocMetaTable } from "@/components/form/DocCell";
import { DocDeviationFooter, type DocCorrectiveValue } from "@/components/form/DocDeviationFooter";
import { DocRowToolbar } from "@/components/form/DocRowToolbar";
import { DocSummaryPanel } from "@/components/form/DocSummaryPanel";
// 역할 — 상신·검토·승인·반려 공통 툴바
import { DocumentApprovalToolbar } from "@/components/document/DocumentApprovalToolbar";
// 역할 — 문서상태 공통코드
import { useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — DocForm 날짜·시각 변환
import { fromInputDate, toInputDate, todayYmd } from "@/lib/docDateTime";
import {
  deleteHygiene,
  getHygieneDetail,
  listHygiene,
  saveHygiene,
  validateDeleteHygiene,
  type HygieneDetail,
  type HygieneScreenCode,
} from "@/api/hygieneApi";

/** 적부 콤보 — DocCellSelect 표준 */
const OX_OPTIONS = [
  { value: "O", label: "O" },
  { value: "X", label: "X" },
];
/** 방충 체크그룹 콤보 — Y/N/미관리 */
const PEST_SELECT_OPTIONS = [
  { value: "Y", label: "V" },
  { value: "N", label: "-" },
  { value: "/", label: "/" },
];

type Entry = Record<string, unknown>;
type FormKind = "daily" | "personal" | "area" | "pest" | "water";

export interface HygienePageProps {
  screenCode: HygieneScreenCode;
  title: string;
  kind: FormKind;
}

/** 방충방서 체크그룹 — Y=발견, N=미발견, /=관리대상아님 */
const PEST_YN_COLS: { key: string; label: string; group: string }[] = [
  { key: "flyYn", label: "파리", group: "비래" },
  { key: "mothYn", label: "나방", group: "비래" },
  { key: "mosqYn", label: "모기", group: "비래" },
  { key: "midgeYn", label: "하루살이", group: "비래" },
  { key: "etcFlyYn", label: "기타", group: "비래" },
  { key: "roachYn", label: "바퀴", group: "보행" },
  { key: "spiderYn", label: "거미", group: "보행" },
  { key: "antYn", label: "개미", group: "보행" },
  { key: "etcWalkYn", label: "기타", group: "보행" },
  { key: "ratYn", label: "쥐", group: "설치류" },
  { key: "etcRatYn", label: "기타", group: "설치류" },
];
const PERSONAL_OX: { key: string; label: string }[] = [
  { key: "healthCd", label: "건강" },
  { key: "clothCd", label: "복장" },
  { key: "belongingsCd", label: "장신구" },
  { key: "workerStateCd", label: "상태" },
  { key: "anteroomCd", label: "전실" },
  { key: "handwashCd", label: "손세척" },
];

const WATER_WEEKS = [1, 2, 3, 4, 5] as const;

function editableStatus(status: string | null | undefined): boolean { return !status || status === "WRK" || status === "RJT"; }
function asText(value: unknown): string { return value == null ? "" : String(value); }
function isStd(entry: Entry): boolean { return asText(entry.stdYn) !== "N"; }

/** 기준일~종료일 YYYYMMDD 열거 — 구역 다중 일자 열 (최대 31일) */
function eachYmd(from: string, to: string): string[] {
  if (!from || from.length !== 8) return [];
  const end = to && to.length === 8 ? to : from;
  const dates: string[] = [];
  const cur = new Date(Number(from.slice(0, 4)), Number(from.slice(4, 6)) - 1, Number(from.slice(6)));
  const last = new Date(Number(end.slice(0, 4)), Number(end.slice(4, 6)) - 1, Number(end.slice(6)));
  while (cur <= last && dates.length < 31) {
    const y = cur.getFullYear();
    const m = String(cur.getMonth() + 1).padStart(2, "0");
    const d = String(cur.getDate()).padStart(2, "0");
    dates.push(`${y}${m}${d}`);
    cur.setDate(cur.getDate() + 1);
  }
  return dates;
}

function shortMd(ymd: string): string {
  return ymd.length === 8 ? `${ymd.slice(4, 6)}/${ymd.slice(6)}` : ymd;
}

function resultJudgeByDt(entry: Entry, checkDt: string): string {
  const results = Array.isArray(entry.results) ? (entry.results as Entry[]) : [];
  return asText(results.find((row) => asText(row.checkDt) === checkDt)?.judgeCd);
}

function resultJudgeByWeek(entry: Entry, weekNo: number): string {
  const results = Array.isArray(entry.results) ? (entry.results as Entry[]) : [];
  return asText(results.find((row) => Number(row.weekNo) === weekNo)?.judgeCd);
}

/** 좌측 목록 메타 */
type ListMeta = DocListMeta & {
  baseDtDisp?: string;
};

/** 건별 본문 버퍼 */
type Buf = {
  docIdx: number | null;
  docNo: string;
  status: string | null;
  baseKey: string;
  baseDtTo: string;
  checkerNm: string;
  beforeTime: string;
  duringTime: string;
  entries: Entry[];
  signers: Entry[];
  checkers: Entry[];
  corrective: DocCorrectiveValue;
};

/** 상세 → 버퍼 */
function detailToBuf(kind: FormKind, detail: HygieneDetail, userNm?: string): Buf {
  const header = detail.header ?? {};
  const nextBase = asText(header.baseDt) || todayYmd();
  return {
    docIdx: Number(header.docIdx) || null,
    docNo: asText(header.docNo),
    status: asText(header.status) || null,
    baseKey: nextBase,
    baseDtTo: asText(header.baseDtTo),
    checkerNm: asText(header.checkerNm) || userNm || "",
    beforeTime: asText(header.beforeTime),
    duringTime: asText(header.duringTime),
    entries: (detail.entries ?? []).map((entry) => ({
      ...entry,
      stdYn: entry.stdYn ?? (kind === "daily" ? "Y" : "N"),
    })),
    signers: detail.signers ?? [],
    checkers: detail.checkers ?? [],
    corrective: {
      deviationDesc: detail.corrective?.deviationDesc ?? "",
      actionDesc: detail.corrective?.actionDesc ?? "",
      actionUserNm: detail.corrective?.actionUserNm ?? "",
      confirmUserNm: detail.corrective?.confirmUserNm ?? "",
    },
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 위생 양식 문서형 목록·입력을 draft 세션으로 렌더링한다
 *   2) screenRegistry가 의미 화면 ID로 마운트한다
 *   3) API 실패는 업무 토스트만 표시한다
 */
export default function HygieneCheckPage({ screenCode, title, kind }: HygienePageProps) {
  const user = useAuthStore((s) => s.user);
  const canWrite = useAuthStore((s) => s.can(screenCode, "write"));
  const canModify = useAuthStore((s) => s.can(screenCode, "modify"));
  const canDelete = useAuthStore((s) => s.can(screenCode, "delete"));
  const action = useAsyncAction();
  // 좌측 문서 목록 — 신규행만 기준일 편집
  const listGrid = useGridAccess({ newOnly: ["baseDtDisp", "baseKey"] }, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });
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
  const [selectedEntry, setSelectedEntry] = useState<number | null>(null);

  const buf = activeBuffer;
  const docIdx = buf?.docIdx ?? null;
  const status = buf?.status ?? null;
  const canEdit = editableStatus(status) && (docIdx ? canModify : canWrite);
  const areaDates = useMemo(
    () => (kind === "area" && buf ? eachYmd(buf.baseKey, buf.baseDtTo || buf.baseKey) : []),
    [buf, kind],
  );

  const listColumns = useMemo<GridColumn<ListMeta>[]>(() => [
    // 기준일 — YYYY-MM-DD 달력, 신규 draft만 편집
    { field: "baseDtDisp", header: "기준일", width: 120, editableOnNew: true, type: "date" },
    { field: "docNo", header: "문서", width: 120 },
    { field: "ngCnt", header: "부적합", width: 70, type: "number" },
  ], []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 위생 목록을 조회해 draft를 유지한 채 좌측 그리드를 갱신한다
   *   2) 조회·저장·삭제 후 호출한다
   *   3) 실패 시 토스트
   */
  const loadList = useCallback(async () => {
    const q = searchRef.current;
    try {
      const server = await listHygiene(screenCode, {
        fromDt: q.fromDt,
        toDt: q.toDt,
        docNo: q.docNo.trim() || undefined,
        writer: q.writer.trim() || undefined,
      });
      replaceServerList(
        server.map((row) => ({
          docIdx: row.docIdx,
          docNo: row.docNo,
          status: row.status,
          baseKey: row.baseDt,
          baseDtDisp: toInputDate(row.baseDt),
          ngCnt: row.ngCnt,
        } satisfies ListMeta)),
        (row) => String(row.docIdx),
      );
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  }, [replaceServerList, screenCode]);

  useEffect(() => { void loadList(); }, [loadList]);

  // 구역 — 기간 변경 시 서명 행을 일자에 맞춘다
  useEffect(() => {
    if (kind !== "area" || !canEdit || !buf) return;
    const nextSigners = areaDates.map((dt) => {
      const found = buf.signers.find((row) => asText(row.checkDt) === dt);
      return found ?? { checkDt: dt, writerNm: "", reviewerNm: "", approverNm: "" };
    });
    const same = nextSigners.length === buf.signers.length
      && nextSigners.every((s, i) => asText(s.checkDt) === asText(buf.signers[i]?.checkDt));
    if (same) return;
    patchActive((prev) => ({ ...prev, signers: nextSigners }));
  }, [areaDates, buf, canEdit, kind, patchActive]);

  // 용수 — 1~5주 점검자 행 기본값
  useEffect(() => {
    if (kind !== "water" || !canEdit || !buf) return;
    if (buf.checkers.length === WATER_WEEKS.length) return;
    patchActive((prev) => ({
      ...prev,
      checkers: WATER_WEEKS.map((weekNo) => {
        const found = prev.checkers.find((row) => Number(row.weekNo) === weekNo);
        return found ?? { weekNo, checkDt: "", checkerNm: "" };
      }),
    }));
  }, [buf, canEdit, kind, patchActive]);

  const handleSelect = useCallback(async (key: string | null) => {
    setSelectedEntry(null);
    await selectKey(key, async (k, row) => {
      const cached = getBuffer(k);
      if (cached) return cached;
      if (row._rowState === "C" || !row.docIdx) {
        try {
          const detail = await getHygieneDetail(screenCode, null);
          const next = detailToBuf(kind, detail, user?.userNm);
          next.docIdx = null;
          next.docNo = "";
          next.status = null;
          next.baseKey = row.baseKey || todayYmd();
          return next;
        } catch (error) {
          mesToast(mesError(error), "error");
          return null;
        }
      }
      try {
        return detailToBuf(kind, await getHygieneDetail(screenCode, row.docIdx), user?.userNm);
      } catch (error) {
        mesToast(mesError(error), "error");
        return null;
      }
    });
  }, [getBuffer, kind, screenCode, selectKey, user?.userNm]);

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
   *   1) 신규 draft와 표준 점검항목 버퍼를 추가한다
   *   2) 신규 버튼에서 호출한다
   *   3) 상세(null) 실패 시 토스트
   */
  const handleNew = () => action.run(async () => {
    if (!canWrite) return;
    // 당일 복수 문서 허용 — 기존 기준키 행이 있어도 항상 새 draft
    const today = todayYmd();
    try {
      const detail = await getHygieneDetail(screenCode, null);
      const next = detailToBuf(kind, detail, user?.userNm);
      next.docIdx = null;
      next.docNo = "";
      next.status = null;
      next.baseKey = today;
      addDraft(
        {
          docIdx: null,
          docNo: "",
          status: null,
          baseKey: next.baseKey,
          baseDtDisp: toInputDate(next.baseKey),
          ngCnt: 0,
        },
        next,
      );
      setSelectedEntry(null);
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  }, "add");

  const handleSave = () => action.run(async () => {
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
            if (!/^\d{8}$/.test(b.baseKey)) return { message: MES.required("기준일"), rowKey: key };
            if ((kind === "area" || kind === "water") && b.baseDtTo && !/^\d{8}$/.test(b.baseDtTo)) {
              return { message: MES.required("종료일"), rowKey: key };
            }
            if (seen.has(b.baseKey)) return { message: `기준키가 중복되었습니다: ${b.baseKey}`, rowKey: key };
            seen.add(b.baseKey);
            if (b.entries.length === 0) return { message: "점검 행이 없습니다.", rowKey: key };
          }
          return null;
        },
        saveOne: async (_row, b) => {
          const saved = await saveHygiene(screenCode, {
            docIdx: b.docIdx,
            baseDt: b.baseKey,
            baseDtTo: b.baseDtTo,
            checkerNm: b.checkerNm,
            payload: {
              entries: b.entries,
              signers: b.signers,
              checkers: b.checkers,
              beforeTime: b.beforeTime,
              duringTime: b.duringTime,
              cycleNm: kind === "water" ? "1회/주" : "",
            },
            corrective: b.corrective,
          });
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

  const handleDelete = () => action.run(async () => {
    if (!activeKey) return mesToast(MES.selectRow, "warn");
    const row = listRows.find((r) => r._key === activeKey);
    if (!row) return;
    if (row._rowState === "C") {
      removeDraft(activeKey);
      setSelectedEntry(null);
      return;
    }
    if (!docIdx || !canDelete) return;
    if (!canEdit) return mesToast(MES.inApprovalLocked, "warn");
    try {
      const keys = [{ docIdx }];
      await validateDeleteHygiene(screenCode, keys);
      if (!await mesConfirm(`${buf?.docNo || title} 문서를 삭제하시겠습니까?`)) return;
      await deleteHygiene(screenCode, keys);
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

  const patch = (index: number, key: string, value: unknown) => {
    if (!canEdit) return;
    patchActive((current) => ({
      ...current,
      entries: current.entries.map((entry, i) => (i === index ? { ...entry, [key]: value } : entry)),
    }));
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 구역 일자별·용수 주차별 results[] 판정을 갱신한다
   *   2) O/X 버튼 클릭 시 호출한다
   *   3) 해당 키 행이 없으면 새로 추가한다
   */
  const patchResults = (index: number, match: Entry, judgeCd: string) => {
    if (!canEdit) return;
    patchActive((current) => ({
      ...current,
      entries: current.entries.map((entry, i) => {
        if (i !== index) return entry;
        const results = Array.isArray(entry.results) ? [...(entry.results as Entry[])] : [];
        const hit = results.findIndex((row) => (
          match.checkDt != null
            ? asText(row.checkDt) === asText(match.checkDt)
            : Number(row.weekNo) === Number(match.weekNo)
        ));
        if (hit >= 0) results[hit] = { ...results[hit], judgeCd };
        else results.push({ ...match, judgeCd });
        return { ...entry, results };
      }),
    }));
  };

  /** 스칼라 OX 키(healthCd·deviceNgCd·judgeCd) — DocCellSelect */
  const scalarOxSelect = (entry: Entry, index: number, key: string) => (
    <DocCellSelect
      // 현재 적부
      value={asText(entry[key])}
      // 임시·반려만
      disabled={!canEdit}
      // O/X 옵션
      options={OX_OPTIONS}
      emptyLabel=""
      onChange={(v) => patch(index, key, v)}
    />
  );

  /** results[] 배열용 O/X — 구역 checkDt / 용수 weekNo */
  const resultsOxSelect = (index: number, match: Entry, current: string) => (
    <DocCellSelect
      // 일자·주차 판정
      value={current}
      disabled={!canEdit}
      options={OX_OPTIONS}
      emptyLabel=""
      onChange={(v) => patchResults(index, match, v)}
    />
  );

  const addDailyRow = () => {
    if (!canEdit || kind !== "daily") return;
    patchActive((current) => ({
      ...current,
      entries: [...current.entries, {
        rowSeq: current.entries.length + 1,
        itemCd: `USR_${Date.now()}`,
        itemNm: "",
        grpCd: "EXTRA",
        grpNm: "추가 점검",
        inputType: "OX",
        stdYn: "N",
        judgeCd: "",
        remark: "",
      }],
    }));
  };
  const removeDailyRow = (index: number) => {
    if (!canEdit || kind !== "daily" || !buf) return;
    if (isStd(buf.entries[index])) {
      mesToast("표준 점검항목은 삭제할 수 없습니다.", "warn");
      return;
    }
    patchActive((current) => ({
      ...current,
      entries: current.entries.filter((_, i) => i !== index).map((row, i) => ({ ...row, rowSeq: i + 1 })),
    }));
  };

  const entries = buf?.entries ?? [];
  const signers = buf?.signers ?? [];
  const checkers = buf?.checkers ?? [];
  const baseKey = buf?.baseKey ?? "";
  const baseDtTo = buf?.baseDtTo ?? "";
  const checkerNm = buf?.checkerNm ?? "";
  const beforeTime = buf?.beforeTime ?? "";
  const duringTime = buf?.duringTime ?? "";
  const corrective = buf?.corrective ?? {};
  const docNo = buf?.docNo ?? "";

  const bodyTable = () => {
    if (kind === "personal") {
      return (
        <table className="doc-table">
          <thead>
            <tr>
              <th>작업자</th>
              {PERSONAL_OX.map((col) => <th key={col.key}>{col.label}</th>)}
              <th>비고</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((entry, index) => (
              <tr
                key={index}
                className={selectedEntry === index ? "doc-row-selected" : undefined}
                onClick={() => setSelectedEntry(index)}
              >
                <td><DocCellInput value={asText(entry.workerNm)} disabled={!canEdit} onChange={(v) => patch(index, "workerNm", v)} /></td>
                {PERSONAL_OX.map((col) => (
                  <td key={col.key}>{scalarOxSelect(entry, index, col.key)}</td>
                ))}
                <td><DocCellInput value={asText(entry.remark)} disabled={!canEdit} onChange={(v) => patch(index, "remark", v)} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      );
    }

    if (kind === "pest") {
      return (
        <div className="overflow-x-auto">
          <table className="doc-table">
            <thead>
              <tr>
                <th>설비</th>
                <th>설치위치</th>
                <th>상태</th>
                {PEST_YN_COLS.map((col) => (
                  <th key={col.key} title={col.group}>{col.label}</th>
                ))}
                <th>비고</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((entry, index) => (
                <tr key={asText(entry.pestCd) || index}>
                  <td className="whitespace-normal">{asText(entry.pestNm)}</td>
                  <td className="whitespace-normal">{asText(entry.placeNm)}</td>
                  <td>{scalarOxSelect(entry, index, "deviceNgCd")}</td>
                  {PEST_YN_COLS.map((col) => (
                    <td key={col.key}>
                      <DocCellSelect
                        // 체크그룹 값 — Y/N/미관리
                        value={asText(entry[col.key]) || "N"}
                        disabled={!canEdit}
                        options={PEST_SELECT_OPTIONS}
                        emptyLabel=""
                        onChange={(v) => patch(index, col.key, v)}
                      />
                    </td>
                  ))}
                  <td><DocCellInput value={asText(entry.remark)} disabled={!canEdit} onChange={(v) => patch(index, "remark", v)} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
    }

    if (kind === "area") {
      return (
        <div className="space-y-3">
          <div className="overflow-x-auto">
            <table className="doc-table">
              <thead>
                <tr>
                  <th>점검항목</th>
                  {areaDates.map((dt) => <th key={dt}>{shortMd(dt)}</th>)}
                  <th>비고</th>
                </tr>
              </thead>
              <tbody>
                {entries.map((entry, index) => (
                  <tr key={`${asText(entry.itemCd)}-${index}`}>
                    <td className="whitespace-normal leading-relaxed">{asText(entry.itemNm)}</td>
                    {areaDates.map((dt) => (
                      <td key={dt}>{resultsOxSelect(index, { checkDt: dt }, resultJudgeByDt(entry, dt))}</td>
                    ))}
                    <td><DocCellInput value={asText(entry.remark)} disabled={!canEdit} onChange={(v) => patch(index, "remark", v)} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="doc-section-title">일자별 서명</p>
          <table className="doc-table">
            <thead>
              <tr><th>일자</th><th>작성</th><th>검토</th><th>승인</th></tr>
            </thead>
            <tbody>
              {signers.map((row, index) => (
                <tr key={asText(row.checkDt) || index}>
                  <td>{shortMd(asText(row.checkDt))}</td>
                  {(["writerNm", "reviewerNm", "approverNm"] as const).map((key) => (
                    <td key={key}>
                      <DocCellInput
                        value={asText(row[key])}
                        disabled={!canEdit}
                        onChange={(v) => patchActive((cur) => ({
                          ...cur,
                          signers: cur.signers.map((s, i) => (i === index ? { ...s, [key]: v } : s)),
                        }))}
                      />
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
    }

    if (kind === "water") {
      return (
        <div className="space-y-3">
          <table className="doc-table">
            <thead>
              <tr>
                <th className="w-24">구분</th>
                <th>점검항목</th>
                {WATER_WEEKS.map((w) => <th key={w}>{w}주</th>)}
              </tr>
            </thead>
            <tbody>
              {entries.map((entry, index) => (
                <tr key={`${asText(entry.itemCd)}-${index}`}>
                  <td className="whitespace-normal">{asText(entry.grpNm || entry.grpCd)}</td>
                  <td className="whitespace-normal leading-relaxed">{asText(entry.itemNm)}</td>
                  {WATER_WEEKS.map((weekNo) => (
                    <td key={weekNo}>{resultsOxSelect(index, { weekNo }, resultJudgeByWeek(entry, weekNo))}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
          <p className="doc-section-title">주차별 점검자</p>
          <table className="doc-table">
            <thead>
              <tr><th>주차</th><th>점검일</th><th>점검자</th></tr>
            </thead>
            <tbody>
              {checkers.map((row, index) => (
                <tr key={Number(row.weekNo) || index}>
                  <td>{asText(row.weekNo)}주</td>
                  <td>
                    <DocCellInput
                      type="date"
                      value={toInputDate(asText(row.checkDt))}
                      disabled={!canEdit}
                      onChange={(v) => patchActive((cur) => ({
                        ...cur,
                        checkers: cur.checkers.map((c, i) => (i === index ? { ...c, checkDt: fromInputDate(v) } : c)),
                      }))}
                    />
                  </td>
                  <td>
                    <DocCellInput
                      value={asText(row.checkerNm)}
                      disabled={!canEdit}
                      onChange={(v) => patchActive((cur) => ({
                        ...cur,
                        checkers: cur.checkers.map((c, i) => (i === index ? { ...c, checkerNm: v } : c)),
                      }))}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
    }

    // daily — inputType별 OX / NUM / NUM2
    return (
      <table className="doc-table">
        <thead>
          <tr>
            <th className="w-24">구분</th>
            <th>점검항목</th>
            <th className="w-24">판정</th>
            <th className="w-28">수치</th>
            <th className="w-16">단위</th>
            <th className="w-32">비고</th>
            <th className="w-16">행</th>
          </tr>
        </thead>
        <tbody>
          {entries.length === 0 ? (
            <tr><td colSpan={7} className="p-4 text-center text-slate-500">점검항목이 없습니다.</td></tr>
          ) : entries.map((entry, index) => {
            const inputType = asText(entry.inputType) || "OX";
            const isNum = inputType === "NUM" || inputType === "NUM2";
            return (
              <tr
                key={`${asText(entry.itemCd)}-${index}`}
                className={selectedEntry === index ? "doc-row-selected" : undefined}
                onClick={() => setSelectedEntry(index)}
              >
                <td className="whitespace-normal">
                  {/* 구분 — 표준행·추가행 모두 수정 가능 (HA-HYG-01) */}
                  <DocCellInput value={asText(entry.grpNm || entry.grpCd)} disabled={!canEdit} onChange={(v) => patch(index, "grpNm", v)} />
                </td>
                <td className="whitespace-normal leading-relaxed">
                  {/* 점검항목 — 표준행도 문구 수정 가능 */}
                  <DocCellInput value={asText(entry.itemNm)} disabled={!canEdit} onChange={(v) => patch(index, "itemNm", v)} placeholder="점검항목 문구" />
                </td>
                <td>{isNum ? <span className="text-xs text-slate-400">-</span> : scalarOxSelect(entry, index, "judgeCd")}</td>
                <td>
                  {isNum ? (
                    <div className="flex flex-col gap-1">
                      <DocCellInput type="number" value={asText(entry.numVal)} disabled={!canEdit} onChange={(v) => patch(index, "numVal", v)} />
                      {inputType === "NUM2" ? (
                        <DocCellInput type="number" value={asText(entry.numVal2)} disabled={!canEdit} onChange={(v) => patch(index, "numVal2", v)} />
                      ) : null}
                    </div>
                  ) : <span className="text-xs text-slate-400">-</span>}
                </td>
                <td className="text-center text-xs">{asText(entry.unitNm)}</td>
                <td><DocCellInput value={asText(entry.remark)} disabled={!canEdit} onChange={(v) => patch(index, "remark", v)} /></td>
                <td className="text-center">
                  {!isStd(entry) && canEdit ? (
                    <MesButton size="sm" variant="danger" onClick={() => removeDailyRow(index)}>삭제</MesButton>
                  ) : <span className="text-slate-400">표준</span>}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    );
  };

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
        searchBusy={action.isBusy()}
        // 저장·신규·삭제 busy
        actionBusy={action.isBusy()}
      />
      {docIdx ? (
        <DocumentApprovalToolbar
          // 저장 후 문서 idx
          docIdx={docIdx}
          // 문서 상태
          status={status}
          // dirty 전건 저장
          onSave={() => void handleSave()}
          // 임시·반려만 저장
          canSave={!!canEdit}
          // 결재 권한
          canApprove={canWrite || canModify}
          // 작성 화면 — 상신·취소만 (검토·승인은 결재함)
          writerActionsOnly
          // 저장 busy
          saveBusy={action.isBusy("save")}
          // 결재 후 재조회
          onApproved={() => {
            void loadList();
            if (docIdx && activeKey) {
              void getHygieneDetail(screenCode, docIdx).then((detail) => {
                putBuffer(activeKey, detailToBuf(kind, detail, user?.userNm), {
                  status: asText(detail.header?.status) || null,
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
            // 위생 문서목록 설정 키 — 화면코드별 분리
            persistId={`hyg-doc-list-${screenCode}`}
            // 서버 목록 + draft
            rows={listRows as EditableRow<ListMeta>[]}
            // 기준일·문서번호·부적합
            columns={listColumns}
            // 신규행 기준일 편집
            editable={canWrite || canModify}
            // 패널 제목
            title="문서 목록"
            // 부모 flex 높이 채움
            height="100%"
            // 선택 키
            activeKey={activeKey}
            // 행 클릭 시 버퍼 전환
            onActivate={(row) => { void handleSelect(row._key ?? null); }}
            // 좌측 기준일 편집 → 버퍼 동기
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
            <DocPaper title={title} writerNm={checkerNm || user?.userNm}>
              <DocMetaTable
                rows={[
                  {
                    label: "기준일",
                    node: (
                      <DocCellInput
                        type="date"
                        value={toInputDate(baseKey)}
                        disabled={!canEdit}
                        onChange={(v) => {
                          const next = fromInputDate(v);
                          patchActive((prev) => ({ ...prev, baseKey: next }), {
                            baseKey: next,
                            baseDtDisp: toInputDate(next),
                          });
                        }}
                      />
                    ),
                  },
                  ...(kind === "area" || kind === "water"
                    ? [{
                        label: "종료일",
                        node: (
                          <DocCellInput
                            type="date"
                            value={toInputDate(baseDtTo)}
                            disabled={!canEdit}
                            onChange={(v) => patchActive((prev) => ({ ...prev, baseDtTo: fromInputDate(v) }))}
                          />
                        ),
                      }]
                    : []),
                  ...(kind === "daily"
                    ? [
                        {
                          label: "작업전 시각",
                          node: (
                            <DocCellTime
                              // 작업전 시각 — HHMM 저장
                              value={beforeTime}
                              disabled={!canEdit}
                              storage="hhmm"
                              onChange={(v) => patchActive((p) => ({ ...p, beforeTime: v }))}
                            />
                          ),
                        },
                        {
                          label: "작업중 시각",
                          node: (
                            <DocCellTime
                              // 작업중 시각 — HHMM 저장
                              value={duringTime}
                              disabled={!canEdit}
                              storage="hhmm"
                              onChange={(v) => patchActive((p) => ({ ...p, duringTime: v }))}
                            />
                          ),
                        },
                      ]
                    : []),
                  ...(kind !== "water"
                    ? [{ label: "점검자", node: <DocCellInput value={checkerNm} disabled={!canEdit} onChange={(v) => patchActive((p) => ({ ...p, checkerNm: v }))} /> }]
                    : []),
                ]}
              />
              <p className="doc-section-title">점검 기록 ({entries.length}항목)</p>
              {bodyTable()}
              {kind === "daily" && canEdit ? (
                <DocRowToolbar
                  onAdd={addDailyRow}
                  onRemove={() => {
                    if (selectedEntry == null) { mesToast("삭제할 행을 선택하세요.", "warn"); return; }
                    removeDailyRow(selectedEntry);
                    setSelectedEntry(null);
                  }}
                  canRemove={selectedEntry != null && !isStd(entries[selectedEntry])}
                  addLabel="점검항목 행 추가"
                />
              ) : null}
              {kind === "personal" && canEdit ? (
                <DocRowToolbar
                  onAdd={() => patchActive((c) => ({
                    ...c,
                    entries: [...c.entries, {
                      rowSeq: c.entries.length + 1,
                      workerNm: "",
                      healthCd: "",
                      clothCd: "",
                      belongingsCd: "",
                      workerStateCd: "",
                      anteroomCd: "",
                      handwashCd: "",
                      remark: "",
                      stdYn: "N",
                    }],
                  }))}
                  onRemove={() => {
                    if (selectedEntry == null) { mesToast("삭제할 행을 선택하세요.", "warn"); return; }
                    patchActive((c) => ({
                      ...c,
                      entries: c.entries.filter((_, i) => i !== selectedEntry).map((row, i) => ({ ...row, rowSeq: i + 1 })),
                    }));
                    setSelectedEntry(null);
                  }}
                  canRemove={selectedEntry != null}
                  addLabel="작업자 추가"
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
            statusLabel={status ? statusLabel(status, status) : "신규"}
            // 필수 진행
            requiredFieldProgress={{
              completed: Number(Boolean(baseKey)) + Number(entries.length > 0),
              total: 2,
            }}
            // 결재선
            approvalLine="작성 → 검토 → 승인"
            // kind별 힌트
            hint={
              kind === "daily"
                ? "OX 항목은 판정, 온도(NUM/NUM2)는 수치·단위를 입력합니다. 표준행은 삭제할 수 없습니다."
                : kind === "area"
                  ? "기준일~종료일 각 일자 열에 O/X를 입력하고 하단 서명을 작성합니다."
                  : kind === "water"
                    ? "1~5주 열에 O/X를 입력하고 주차별 점검자를 기록합니다."
                    : kind === "pest"
                      ? "설비 상태(O/X)와 해충·설치류 카운트를 입력합니다."
                      : "작업자별 위생 판정(O/X)을 입력합니다."
            }
          />
        </DocFormSidePanel>
      </DocFormBody>
    </DocFormLayout>
  );
}
