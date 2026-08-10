/**
 * ColdMonitorPage — CCP 냉장·냉동 보관 모니터링 일지 (ccp-cold-monitor).
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 신규 시 좌측 draft(C)를 쌓고 건별 버퍼를 편집한 뒤 dirty 전건 검증·순차 저장한다
 *   2) 점검시간은 DocCellTime(HHMM), CCP·판정은 DocCellSelect로 DocForm 셀 계약을 맞춘다
 *   3) 결재 진행·완료 문서는 수정·삭제할 수 없고, 결재 툴바는 docIdx가 있을 때만 노출한다
 *
 * PIPELINE[HF81] CCP 화면
 * PIPELINE[HF80, HF29, HF39, HF56, HF120] 연관 모듈
 */
// 역할 — 상태·효과
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 로그인 사용자(담당자 기본값)
import { useAuthStore } from "@/stores/authStore";
// 역할 — 중복 클릭 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — DB형 문서 draft·다건 버퍼 세션
import { useDocFormSession, type DocListMeta } from "@/hooks/useDocFormSession";
// 역할 — 셸 툴바·단축키 CRUD 등록
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — 확인·토스트
import { mesConfirm, mesToast } from "@/shell/dialog";
// 역할 — 업무 예외 → 문구
import { mesError } from "@/shell/errors";
// 역할 — 공통 안내 문구
import { MES } from "@/shell/messages";
// 역할 — mes-web형 좌측 문서목록 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — 목록 그리드 잠금(신규만 작성일 편집)
import { useGridAccess } from "@/hooks/useGridAccess";
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
// 역할 — DB형 문서 공통 화면 구조
import {
  DocFormBody,
  DocFormDocumentList,
  DocFormLayout,
  DocFormMainPanel,
  DocFormSidePanel,
} from "@/components/form/DocFormLayout";
// 역할 — 공통 조회·CRUD 헤더 (시작일·종료일·문서번호·작성자)
import {
  DocFormSearchToolbar,
  defaultDocFormSearch,
  type DocFormSearchValues,
} from "@/components/form/DocFormSearchToolbar";
// 역할 — 종이 서식 용지·결재란
import { DocPaper } from "@/components/form/DocPaper";
// 역할 — 문서 셀 입력·판정·시간 선택
import { DocCellInput, DocCellSelect, DocCellTime } from "@/components/form/DocCell";
// 역할 — PDF 메타(한계·주기·방법)
import { DocFormMeta } from "@/components/form/DocFormMeta";
// 역할 — 이탈 푸터
import { DocDeviationFooter, type DocCorrectiveValue } from "@/components/form/DocDeviationFooter";
// 역할 — 행 추가·삭제
import { DocRowToolbar } from "@/components/form/DocRowToolbar";
// 역할 — 문서 식별·판정·필수값 요약 표시
import { DocSummaryPanel } from "@/components/form/DocSummaryPanel";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — DocForm 날짜·시각 변환
import { fromInputDate, toInputDate, todayYmd } from "@/lib/docDateTime";
// 역할 — CCP 냉장보관 API
import {
  deleteColdMonitor,
  getColdMonitorDetail,
  listColdMonitors,
  saveColdMonitor,
  validateDeleteColdMonitor,
  type CcpLimitRow,
  type ColdMonitorDetail,
  type ColdMonitorRowDto,
  type StorageRow,
} from "@/api/ccpColdApi";
// 역할 — 문서상태 공통코드 라벨
import { useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — 상신·검토·승인·반려 공통 툴바
import { DocumentApprovalToolbar } from "@/components/document/DocumentApprovalToolbar";
// 역할 — 홈·문서함 ?docIdx= deep-link
import { useDocIdxQuery } from "@/hooks/useDocIdxQuery";
// 역할 — 로그인 사용자 서명 경로·미등록 시 업로드
import { fetchMySignPath, uploadMySign } from "@/api/systemApi";

/** 편집 가능 여부 — 신규이거나 임시·반려 */
function isEditable(status?: string | null): boolean {
  return !status || status === "WRK" || status === "RJT";
}

/** 한계기준 범위로 셀 미리보기 판정 */
function previewJudge(
  temp: number | null | undefined,
  storage: StorageRow | undefined,
  limits: CcpLimitRow[],
): string | null {
  if (temp === null || temp === undefined || Number.isNaN(temp)) return null;
  let min = storage?.tempMin ?? null;
  let max = storage?.tempMax ?? null;
  if (min == null || max == null) {
    const lim = limits.find((l) => l.ccpCd === (storage?.ccpCd || "CCP-1B"));
    min = lim?.minVal ?? null;
    max = lim?.maxVal ?? null;
  }
  if (min != null && temp < Number(min)) return "F";
  if (max != null && temp > Number(max)) return "F";
  return "P";
}

/** 수동 적부 O/X — DDL judge_cd 계약 */
const OX = [{ value: "O", label: "○" }, { value: "X", label: "×" }];

/** 화면 표시용 O/X — 자동 P/F도 ○/×로 보여 준다 */
function rowJudgeOx(judgeCd?: string | null): string {
  if (judgeCd === "O" || judgeCd === "X") return judgeCd;
  if (judgeCd === "P") return "O";
  if (judgeCd === "F") return "X";
  return "";
}

/** 빈 점검행 N개 — 보관고 열·작성자 기본값을 미리 깐다 */
function emptyRows(
  storages: StorageRow[],
  // 로그인 작성자 ID
  writerId = "",
  // 로그인 작성자명
  writerNm = "",
  count = 6,
): ColdMonitorRowDto[] {
  return Array.from({ length: count }, (_, i) => ({
    rowSeq: i + 1,
    checkTime: "",
    judgeCd: null,
    judgeModYn: "N",
    checkerId: writerId,
    checkerNm: writerNm,
    writerId,
    writerNm,
    signPath: null,
    temps: storages.map((s) => ({
      storageCd: s.storageCd,
      tempVal: null,
      judgeCd: null,
    })),
  }));
}

/** 좌측 목록 메타 */
type ListMeta = DocListMeta & {
  // 작성일 표시 YYYY-MM-DD
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
  // 작성일 YYYYMMDD
  baseKey: string;
  // CCP 코드
  ccpCd: string;
  // 담당자
  mngUserId: string;
  mngNm: string;
  // 점검행
  rows: ColdMonitorRowDto[];
  // 이탈 푸터
  corrective: DocCorrectiveValue;
};

/** 상세 → 버퍼 */
function detailToBuf(detail: ColdMonitorDetail, userId: string, userNm: string): Buf {
  if (detail.header) {
    const nextCcp = detail.header.ccpCd || "";
    const st = (detail.storages ?? []).filter((s) => {
      const typeOk = s.storageType === "COLD" || s.storageType === "FROZEN";
      return typeOk && (!nextCcp || !s.ccpCd || s.ccpCd === nextCcp);
    });
    return {
      docIdx: detail.header.docIdx,
      docNo: detail.header.docNo,
      status: detail.header.status,
      baseKey: detail.header.baseDt,
      ccpCd: nextCcp,
      mngUserId: detail.header.mngUserId || "",
      mngNm: detail.header.mngNm || "",
      rows: (detail.rows ?? []).map((r) => ({
        ...r,
        // 작성자 — 없으면 점검자·로그인명으로 채움
        writerId: r.writerId || r.checkerId || userId,
        writerNm: r.writerNm || r.checkerNm || userNm,
        temps: st.map((s) => {
          const found = (r.temps || []).find((t) => t.storageCd === s.storageCd);
          return {
            storageCd: s.storageCd,
            tempVal: found?.tempVal ?? null,
            judgeCd: found?.judgeCd ?? null,
          };
        }),
      })),
      corrective: {
        deviationDesc: detail.corrective?.deviationDesc ?? "",
        actionDesc: detail.corrective?.actionDesc ?? "",
        actionUserNm: detail.corrective?.actionUserNm ?? "",
        confirmUserNm: detail.corrective?.confirmUserNm ?? "",
      },
    };
  }
  const firstCcp = (detail.limits ?? []).find((l) => (l.limitType || "").toUpperCase() !== "METAL")?.ccpCd
    || (detail.limits ?? [])[0]?.ccpCd
    || "";
  const st = (detail.storages ?? []).filter((s) => {
    const typeOk = s.storageType === "COLD" || s.storageType === "FROZEN";
    return typeOk && (!firstCcp || !s.ccpCd || s.ccpCd === firstCcp);
  });
  return {
    docIdx: null,
    docNo: "",
    status: null,
    baseKey: todayYmd(),
    ccpCd: firstCcp,
    mngUserId: userId,
    mngNm: userNm,
    rows: emptyRows(st, userId, userNm),
    corrective: {},
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 냉장·냉동 보관 모니터링 일지 화면을 그린다
 *   2) screenRegistry가 ccp-cold-monitor 식별자로 마운트한다
 *   3) CCP 콤보 변경 시 한계·주기·방법·보관고 열이 함께 바뀐다
 */
export default function ColdMonitorPage() {
  const user = useAuthStore((s) => s.user);
  const canWrite = useAuthStore((s) => s.can("ccp-cold-monitor", "write"));
  const canModify = useAuthStore((s) => s.can("ccp-cold-monitor", "modify"));
  const canDelete = useAuthStore((s) => s.can("ccp-cold-monitor", "delete"));
  // 좌측 문서 목록 — 신규행만 작성일 편집
  const listGrid = useGridAccess({ newOnly: ["baseDtDisp", "baseKey"] }, {
    scrnCd: "ccp-cold-monitor",
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

  // 공통 목록 검색 — 기간·문서번호·작성자 (조회 클릭 시 반영)
  const [search, setSearch] = useState<DocFormSearchValues>(() => defaultDocFormSearch());
  const searchRef = useRef(search);
  searchRef.current = search;
  // 마스터 — 화면 공통 (문서 버퍼와 분리)
  const [storages, setStorages] = useState<StorageRow[]>([]);
  const [limits, setLimits] = useState<CcpLimitRow[]>([]);
  const [selectedRowSeq, setSelectedRowSeq] = useState<number | null>(null);

  const buf = activeBuffer;
  const docIdx = buf?.docIdx ?? null;
  const docNo = buf?.docNo ?? "";
  const status = buf?.status ?? null;
  const baseDt = buf?.baseKey ?? "";
  const ccpCd = buf?.ccpCd ?? "";
  const mngNm = buf?.mngNm ?? "";
  const rows = buf?.rows ?? [];
  const corrective = buf?.corrective ?? {};
  const editable = isEditable(status) && (docIdx ? canModify : canWrite);

  const listColumns = useMemo<GridColumn<ListMeta>[]>(() => [
    // 작성일 — YYYY-MM-DD 표시, 신규 draft만 편집
    { field: "baseDtDisp", header: "작성일", width: 120, editableOnNew: true, type: "date" },
    { field: "docNo", header: "문서번호", width: 120 },
    { field: "statusNm", header: "상태", width: 80 },
    { field: "ngCnt", header: "부적합", width: 70, type: "number" },
  ], []);

  const ccpOptions = useMemo(
    () => limits.filter((l) => (l.limitType || "").toUpperCase() !== "METAL"),
    [limits],
  );

  const limitBanner = useMemo(() => {
    return ccpOptions.find((l) => l.ccpCd === ccpCd) || ccpOptions[0] || null;
  }, [ccpOptions, ccpCd]);

  const visibleStorages = useMemo(
    () => storages.filter((s) => {
      const typeOk = s.storageType === "COLD" || s.storageType === "FROZEN";
      if (!typeOk) return false;
      if (!ccpCd) return true;
      return !s.ccpCd || s.ccpCd === ccpCd;
    }),
    [storages, ccpCd],
  );

  const formTitle = limitBanner?.formTitle?.trim() || "CCP 냉장·냉동 보관 모니터링 일지";
  const cycleText = limitBanner?.cycleRmk?.trim()
    || (limitBanner?.cycleMin != null ? `작업 중 ${Math.round(Number(limitBanner.cycleMin) / 60)}시간마다` : "");

  // 행 서명 미등록 시 파일 선택 — 숨김 input
  const signFileRef = useRef<HTMLInputElement | null>(null);
  // 서명 업로드 대상 행 순번
  const signTargetRowRef = useRef<number | null>(null);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-07
   * 코멘트:
   *   1) 로그인 사용자 서명 경로를 해당 행 signPath에 붙인다
   *   2) 미등록이면 이미지 선택을 열어 즉시 등록 후 적용한다
   *   3) 임시·반려 편집 행에서만 호출한다
   */
  const applyRowSign = useCallback(async (rowSeq: number) => {
    if (!editable) return;
    try {
      let path = await fetchMySignPath();
      if (!path) {
        signTargetRowRef.current = rowSeq;
        signFileRef.current?.click();
        mesToast("등록된 서명이 없습니다. 서명 이미지 파일을 선택하세요.", "warn");
        return;
      }
      patchRow(rowSeq, { signPath: path });
      mesToast("서명을 적용했습니다.", "success");
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  }, [editable]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-07
   * 코멘트:
   *   1) 선택한 서명 이미지를 본인 서명으로 등록한 뒤 대상 행에 경로를 넣는다
   *   2) applyRowSign이 미등록일 때 연 파일 입력에서 호출한다
   *   3) 실패 시 업무 토스트
   */
  const onSignFilePicked = useCallback(async (file: File | null) => {
    const rowSeq = signTargetRowRef.current;
    signTargetRowRef.current = null;
    if (!file || rowSeq == null) return;
    try {
      const path = await uploadMySign(file);
      patchRow(rowSeq, { signPath: path });
      mesToast("서명을 등록·적용했습니다.", "success");
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 목록을 조회해 draft를 유지한 채 좌측 그리드를 갱신한다
   *   2) 조회·저장·삭제·결재 후 호출한다
   *   3) 실패 시 토스트
   */
  const loadList = useCallback(async () => {
    // 헤더 입력값은 조회 시점에만 읽는다 — 타이핑 중 재조회 방지
    const q = searchRef.current;
    try {
      const server = await listColdMonitors({
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
          statusNm: statusLabel(row.status, row.status),
          ngCnt: row.ngCnt,
        } satisfies ListMeta)),
        (row) => String(row.docIdx),
      );
    } catch (e) {
      mesToast(mesError(e), "error");
    }
  }, [replaceServerList, statusLabel]);

  /** 마스터(보관고·한계) 1회 적재 */
  const loadMaster = useCallback(async () => {
    try {
      const detail = await getColdMonitorDetail(null);
      setStorages(detail.storages ?? []);
      setLimits(detail.limits ?? []);
    } catch (e) {
      mesToast(mesError(e), "error");
    }
  }, []);

  // 목록 — 검색조건·코드 라벨 준비 후 재조회 (마스터와 분리해 루프 방지)
  useEffect(() => {
    void loadList();
  }, [loadList]);

  // 보관고·한계기준 — 마운트 1회만
  useEffect(() => {
    void loadMaster();
  }, [loadMaster]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 좌측 행을 선택하고 버퍼가 없으면 상세 API로 적재한다
   *   2) 목록 onActivate에서 호출한다
   *   3) 실패 시 토스트
   */
  const handleSelect = useCallback(async (key: string | null) => {
    setSelectedRowSeq(null);
    await selectKey(key, async (k, row) => {
      const cached = getBuffer(k);
      if (cached) return cached;
      if (row._rowState === "C" || !row.docIdx) {
        const st = storages.filter((s) => {
          const typeOk = s.storageType === "COLD" || s.storageType === "FROZEN";
          return typeOk;
        });
        return {
          docIdx: null,
          docNo: "",
          status: null,
          baseKey: row.baseKey || todayYmd(),
          ccpCd: ccpOptions[0]?.ccpCd || "",
          mngUserId: user?.userId || "",
          mngNm: user?.userNm || "",
          rows: emptyRows(st, user?.userId || "", user?.userNm || ""),
          corrective: {},
        };
      }
      try {
        const detail = await getColdMonitorDetail(row.docIdx);
        setStorages(detail.storages ?? []);
        setLimits(detail.limits ?? []);
        return detailToBuf(detail, user?.userId || "", user?.userNm || "");
      } catch (e) {
        mesToast(mesError(e), "error");
        return null;
      }
    });
  }, [ccpOptions, getBuffer, selectKey, storages, user?.userId, user?.userNm]);

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
   *   3) 상세(null) 뼈대로 버퍼를 만든다
   */
  const handleNew = () =>
    asyncAct.run(async () => {
      if (!canWrite) return;
      // 당일 복수 문서 허용 — 기존 기준키 행이 있어도 항상 새 draft
      const today = todayYmd();
      try {
        const detail = await getColdMonitorDetail(null);
        setStorages(detail.storages ?? []);
        setLimits(detail.limits ?? []);
        const next = detailToBuf(detail, user?.userId || "", user?.userNm || "");
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
            statusNm: "신규",
            ngCnt: 0,
          },
          next,
        );
        setSelectedRowSeq(null);
      } catch (e) {
        mesToast(mesError(e), "error");
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
  const handleSave = () =>
    asyncAct.run(async () => {
      try {
        const err = await saveAll({
          validate: (dirty, getBuf) => {
            const seen = new Set<string>();
            for (const row of dirty) {
              const key = row._key;
              if (!key) continue;
              const b = getBuf(key);
              if (!b) return { message: "편집 내용이 없습니다.", rowKey: key };
              if (!isEditable(b.status) && b.docIdx) {
                return { message: MES.inApprovalLocked, rowKey: key };
              }
              if (!b.baseKey || b.baseKey.length !== 8) {
                return { message: MES.required("작성일"), rowKey: key };
              }
              if (!b.ccpCd) return { message: MES.required("CCP"), rowKey: key };
              if (seen.has(b.baseKey)) {
                return { message: `작성일이 중복되었습니다: ${b.baseKey}`, rowKey: key };
              }
              seen.add(b.baseKey);
              const filled = b.rows.filter((r) => (r.checkTime || "").trim().length >= 3);
              if (filled.length === 0) {
                return { message: MES.required("점검시간"), rowKey: key };
              }
            }
            return null;
          },
          saveOne: async (_row, b) => {
            const filled = b.rows
              .filter((r) => (r.checkTime || "").trim().length >= 3)
              .map((r, i) => {
                // 작성자 — 로그인 기본, 행 편집값 우선
                const writerId = r.writerId || r.checkerId || user?.userId || "";
                const writerNm = r.writerNm || r.checkerNm || user?.userNm || "";
                return {
                  ...r,
                  rowSeq: i + 1,
                  // DocCellTime hhmm — 4자리로 정규화
                  checkTime: (r.checkTime || "").replace(/\D/g, "").padEnd(4, "0").slice(0, 4),
                  judgeModYn: r.judgeModYn || "N",
                  checkerId: writerId,
                  checkerNm: writerNm,
                  writerId,
                  writerNm,
                  signPath: r.signPath || null,
                };
              });
            const saved = await saveColdMonitor({
              docIdx: b.docIdx,
              baseDt: b.baseKey,
              ccpCd: b.ccpCd,
              mngUserId: b.mngUserId,
              mngNm: b.mngNm,
              rows: filled,
              corrective: b.corrective,
            });
            return {
              docIdx: saved,
              listMeta: {
                docIdx: saved,
                status: "WRK",
                statusNm: statusLabel("WRK", "WRK"),
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
      } catch (e) {
        mesToast(mesError(e), "error");
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
  const handleDelete = () =>
    asyncAct.run(async () => {
      if (!activeKey) {
        mesToast(MES.selectRow, "warn");
        return;
      }
      const row = listRows.find((r) => r._key === activeKey);
      if (!row) return;
      if (row._rowState === "C") {
        removeDraft(activeKey);
        setSelectedRowSeq(null);
        return;
      }
      if (!docIdx || !canDelete) return;
      if (!editable) {
        mesToast(MES.inApprovalLocked, "warn");
        return;
      }
      try {
        const keys = [{ docIdx }];
        await validateDeleteColdMonitor(keys);
        if (!(await mesConfirm(MES.deleteConfirm(docNo || "문서")))) return;
        await deleteColdMonitor(keys);
        mesToast(MES.deleteDone, "success");
        await loadList();
        await handleSelect(null);
      } catch (e) {
        mesToast(mesError(e), "error");
      }
    }, "del");

  usePageCommands({
    search: () => { void loadList(); },
    add: () => { void handleNew(); },
    save: () => { void handleSave(); },
    del: () => { void handleDelete(); },
  });

  const handleCcpChange = (nextCcp: string) => {
    if (!editable) return;
    const nextStorages = storages.filter((s) => {
      const typeOk = s.storageType === "COLD" || s.storageType === "FROZEN";
      return typeOk && (!s.ccpCd || s.ccpCd === nextCcp);
    });
    patchActive((prev) => ({
      ...prev,
      ccpCd: nextCcp,
      rows: prev.rows.map((r) => ({
        ...r,
        temps: nextStorages.map((s) => {
          const found = (r.temps || []).find((t) => t.storageCd === s.storageCd);
          return {
            storageCd: s.storageCd,
            tempVal: found?.tempVal ?? null,
            judgeCd: found?.judgeCd ?? null,
          };
        }),
      })),
    }));
  };

  const setBaseKey = (next: string) => {
    if (!editable) return;
    patchActive(
      (prev) => ({ ...prev, baseKey: next }),
      { baseKey: next, baseDtDisp: toInputDate(next) },
    );
  };

  const patchRow = (rowSeq: number, patch: Partial<ColdMonitorRowDto>) => {
    if (!editable) return;
    patchActive((prev) => ({
      ...prev,
      rows: prev.rows.map((r) => (r.rowSeq === rowSeq ? { ...r, ...patch } : r)),
    }));
  };

  const patchTemp = (rowSeq: number, storageCd: string, raw: string) => {
    if (!editable) return;
    const num = raw.trim() === "" ? null : Number(raw);
    patchActive((prev) => ({
      ...prev,
      rows: prev.rows.map((r) => {
        if (r.rowSeq !== rowSeq) return r;
        const temps = r.temps.map((t) => {
          if (t.storageCd !== storageCd) return t;
          const storage = storages.find((s) => s.storageCd === storageCd);
          return {
            ...t,
            tempVal: num !== null && Number.isNaN(num) ? t.tempVal : num,
            judgeCd: previewJudge(
              num !== null && Number.isNaN(num) ? null : num,
              storage,
              limits,
            ),
          };
        });
        // 수동 판정일 때(= judgeModYn=Y) 온도 미리보기로 덮지 않는다
        if (r.judgeModYn === "Y") {
          return { ...r, temps };
        }
        let rowJudge: string | null = null;
        for (const t of temps) {
          if (t.judgeCd === "F") { rowJudge = "F"; break; }
          if (t.judgeCd === "P") rowJudge = "P";
        }
        return { ...r, temps, judgeCd: rowJudge };
      }),
    }));
  };

  const addRow = () => {
    if (!editable) return;
    patchActive((prev) => {
      const nextSeq = (prev.rows.reduce((m, r) => Math.max(m, r.rowSeq), 0) || 0) + 1;
      return {
        ...prev,
        rows: [
          ...prev.rows,
          {
            rowSeq: nextSeq,
            checkTime: "",
            judgeCd: null,
            judgeModYn: "N",
            checkerId: user?.userId || "",
            checkerNm: user?.userNm || "",
            writerId: user?.userId || "",
            writerNm: user?.userNm || "",
            signPath: null,
            temps: visibleStorages.map((s) => ({ storageCd: s.storageCd, tempVal: null, judgeCd: null })),
          },
        ],
      };
    });
  };

  const removeRow = () => {
    if (!editable || selectedRowSeq == null) {
      mesToast("삭제할 행을 선택하세요.", "warn");
      return;
    }
    patchActive((prev) => ({
      ...prev,
      rows: prev.rows.filter((r) => r.rowSeq !== selectedRowSeq).map((r, i) => ({ ...r, rowSeq: i + 1 })),
    }));
    setSelectedRowSeq(null);
  };

  return (
    <DocFormLayout>
      {/* 행 서명 미등록 시 이미지 선택 — 화면에는 보이지 않음 */}
      <input
        ref={signFileRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => {
          const file = e.target.files?.[0] ?? null;
          e.target.value = "";
          void onSignFilePicked(file);
        }}
      />
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
        // 삭제 — draft이거나 임시·반려 저장행
        canDelete={!!activeKey && !asyncAct.isBusy("del") && (!docIdx || (canDelete && editable))}
        // 조회 busy
        searchBusy={asyncAct.isBusy()}
        // 저장·신규·삭제 busy
        actionBusy={asyncAct.isBusy()}
      />

      {docIdx ? (
        <DocumentApprovalToolbar
          // 저장 후 문서 idx
          docIdx={docIdx}
          // WRK/REQ/REV/APV/RJT
          status={status}
          // 저장 — 다건 saveAll
          onSave={() => void handleSave()}
          // 임시·반려만
          canSave={editable}
          // 결재 권한
          canApprove={canWrite || canModify}
          // 작성 화면 — 상신·취소만 (검토·승인은 결재함)
          writerActionsOnly
          // 저장 busy
          saveBusy={asyncAct.isBusy("save")}
          // 결재 후 재조회
          onApproved={() => {
            void loadList();
            if (activeKey) void handleSelect(activeKey);
          }}
          // 상태 라벨
          statusLabel={status ? statusLabel(status, status) : "신규"}
        />
      ) : null}

      <DocFormBody withSummary>
        <DocFormDocumentList>
          <MesEditableGrid
            // 냉장·냉동 문서목록 설정 키
            persistId="ccp-cold-doc-list"
            // 서버 목록 + draft
            rows={listRows as EditableRow<ListMeta>[]}
            // 작성일·문서번호·상태·부적합
            columns={listColumns}
            // 신규 C행만 작성일 편집
            editable
            // 패널 제목
            title="문서 목록"
            // 부모 flex 높이 채움
            height="100%"
            // 선택 문서
            activeKey={activeKey}
            // 행 클릭 시 버퍼 전환
            onActivate={(row) => { void handleSelect(row._key ?? null); }}
            // 좌측 작성일 편집 → 버퍼 동기
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
            <div className="flex h-full items-center justify-center text-sm text-slate-400">
              좌측에서 문서를 선택하거나 신규를 누르세요.
            </div>
          ) : (
            <DocPaper
              title={formTitle}
              writerNm={mngNm || user?.userNm}
            >
              <DocFormMeta
                key={`meta-${ccpCd}`}
                baseDtNode={(
                  <DocCellInput
                    type="date"
                    value={toInputDate(baseDt)}
                    disabled={!editable}
                    onChange={(v) => setBaseKey(fromInputDate(v))}
                  />
                )}
                managerNode={(
                  <DocCellInput
                    value={mngNm}
                    disabled={!editable}
                    onChange={(v) => patchActive((prev) => ({ ...prev, mngNm: v }))}
                  />
                )}
                extraRows={[
                  {
                    label: "CCP",
                    // CCP 한계기준 콤보 — DocCellSelect 표준
                    node: (
                      <DocCellSelect
                        // 선택 CCP 코드
                        value={ccpCd}
                        // 임시·반려만 · 옵션 있을 때만
                        disabled={!editable || ccpOptions.length === 0}
                        // 한계기준 목록
                        options={ccpOptions.map((opt) => ({
                          value: opt.ccpCd,
                          label: `${opt.ccpCd} ${opt.ccpNm || ""}`.trim(),
                        }))}
                        // 미등록 안내
                        emptyLabel="한계기준을 등록하세요"
                        // CCP 변경 → 보관고 열 재구성
                        onChange={(v) => handleCcpChange(v)}
                      />
                    ),
                  },
                ]}
                limitRmk={limitBanner?.limitRmk || "-"}
                cycleRmk={cycleText || "-"}
                methodRmk={limitBanner?.methodRmk || "-"}
              />

              {visibleStorages.length === 0 ? (
                <div className="rounded border border-amber-200 bg-amber-50 px-3 py-4 text-sm text-amber-800">
                  선택 CCP에 연결된 냉장·냉동 보관고가 없습니다. 보관고 관리에서 유형(냉장/냉동)과 CCP를 연결하세요.
                </div>
              ) : (
                <>
                  <p className="doc-section-title">모니터링 기록</p>
                  <div className="overflow-x-auto">
                    <table className="doc-table">
                      <thead>
                        <tr>
                          <th>점검시간</th>
                          {visibleStorages.map((s) => (
                            <th key={s.storageCd}>
                              {s.storageNm}
                              <div className="font-normal text-slate-400">
                                ({s.storageType === "FROZEN" ? "냉동" : "냉장"}
                                {s.placeNm ? ` · ${s.placeNm}` : ""} ℃)
                              </div>
                            </th>
                          ))}
                          <th>결과(O/X)</th>
                          <th>작성자</th>
                          <th>서명</th>
                        </tr>
                      </thead>
                      <tbody>
                        {rows.map((r) => {
                          // 표시용 O/X — 수동·자동(P/F) 모두 ○/×로
                          const ox = rowJudgeOx(r.judgeCd);
                          const ng = ox === "X" || r.judgeCd === "F";
                          return (
                          <tr
                            key={r.rowSeq}
                            className={cn(selectedRowSeq === r.rowSeq && "doc-row-selected")}
                            onClick={() => setSelectedRowSeq(r.rowSeq)}
                          >
                            <td>
                              <DocCellTime
                                // 점검시간 — type=time 콤보, 저장 HHMM
                                value={r.checkTime}
                                // 임시·반려만 편집
                                disabled={!editable}
                                // varchar(4) HHMM
                                storage="hhmm"
                                // 버퍼 반영
                                onChange={(v) => patchRow(r.rowSeq, { checkTime: v })}
                              />
                            </td>
                            {visibleStorages.map((s) => {
                              const cell = r.temps.find((t) => t.storageCd === s.storageCd);
                              const j = cell?.judgeCd;
                              return (
                                <td key={s.storageCd} className={cn(j === "F" && "bg-red-50", j === "P" && "bg-emerald-50/40")}>
                                  <DocCellInput
                                    // 온도 수치
                                    type="number"
                                    // 소수 1자리
                                    step="0.1"
                                    // 셀 값
                                    value={cell?.tempVal ?? ""}
                                    // 임시·반려만
                                    disabled={!editable}
                                    // 온도·미리보기 판정
                                    onChange={(v) => patchTemp(r.rowSeq, s.storageCd, v)}
                                  />
                                </td>
                              );
                            })}
                            <td className={cn("text-center font-medium", ng ? "text-red-600" : "text-slate-700")}>
                              <DocCellSelect
                                // 수동 적부 O/X
                                value={ox}
                                // 임시·반려만
                                disabled={!editable}
                                // ○/× 옵션
                                options={OX}
                                // 빈 선택
                                emptyLabel=""
                                // 수동 판정 확정
                                onChange={(v) => patchRow(r.rowSeq, {
                                  judgeCd: v || null,
                                  judgeModYn: v ? "Y" : "N",
                                })}
                              />
                            </td>
                            <td>
                              <DocCellInput
                                // 작성자명 — 로그인 기본
                                value={r.writerNm || r.checkerNm || ""}
                                // 임시·반려만
                                disabled={!editable}
                                // 작성자·점검자 동기
                                onChange={(v) => patchRow(r.rowSeq, {
                                  writerNm: v,
                                  checkerNm: v,
                                  writerId: r.writerId || user?.userId || "",
                                  checkerId: r.checkerId || user?.userId || "",
                                })}
                              />
                            </td>
                            <td className="text-center">
                              {/* 서명 경로가 있을 때(= 행 서명 적용됨) 표시·재적용 */}
                              {(r.signPath || "").trim() ? (
                                <button
                                  type="button"
                                  className="text-xs text-emerald-700 underline disabled:no-underline disabled:text-slate-500"
                                  disabled={!editable}
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    void applyRowSign(r.rowSeq);
                                  }}
                                >
                                  서명됨
                                </button>
                              ) : (
                                <button
                                  type="button"
                                  className="text-xs text-sky-700 underline disabled:no-underline disabled:text-slate-400"
                                  disabled={!editable}
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    void applyRowSign(r.rowSeq);
                                  }}
                                >
                                  서명
                                </button>
                              )}
                            </td>
                          </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                  {editable ? (
                    <DocRowToolbar
                      onAdd={addRow}
                      onRemove={removeRow}
                      canRemove={selectedRowSeq != null}
                    />
                  ) : null}
                </>
              )}

              <DocDeviationFooter
                value={corrective}
                onChange={(next) => patchActive((prev) => ({ ...prev, corrective: next }))}
                editable={editable}
              />
            </DocPaper>
          )}
        </DocFormMainPanel>

        <DocFormSidePanel>
          <DocSummaryPanel
            documentNumber={docNo}
            statusLabel={status ? statusLabel(status, status) : "신규"}
            automaticJudgement={
              rows.some((row) => row.judgeCd === "F" || row.judgeCd === "X")
                ? "부적합"
                : rows.some((row) => row.judgeCd === "P" || row.judgeCd === "O")
                  ? "적합"
                  : null
            }
            requiredFieldProgress={{
              completed: Number(Boolean(baseDt)) + Number(rows.some((row) => Boolean(row.checkTime))),
              total: 2,
            }}
            hint="모든 온도가 한계기준 범위에 있으면 '적합'으로 자동 판정됩니다. 최종 판정은 저장 시 서버가 확정합니다."
            approvalLine="작성 → 검토 → 승인"
          />
        </DocFormSidePanel>
      </DocFormBody>
    </DocFormLayout>
  );
}
