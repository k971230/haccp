/**
 * CcpGenericMonitorPage — 가열·멸균·여과 등 공통 CCP 모니터링 일지.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 메뉴 defaultTmplCd로 열 프리셋·양식을 강제한다 (멸균=LMTITMST, 소독과 분리)
 *   2) 회사양식 API가 비어도 FIXED_TEMPLATES로 신규·저장이 가능하다
 *   3) 행별 판정(O/X)·서명·행추가를 DocFormLayout에 맞춘다
 *
 * PIPELINE[HF95] 공통 CCP 모니터링 화면
 * PIPELINE[HF94, HF88, HB98, HF103] 연관 모듈
 */
// 역할 — React 상태·초기 템플릿 조회
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 홈·문서함 ?docIdx= deep-link
import { useDocIdxQuery } from "@/hooks/useDocIdxQuery";
// 역할 — 로그인 사용자·화면 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 중복 저장 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — DB형 문서 draft·다건 버퍼 세션
import { useDocFormSession, type DocListMeta } from "@/hooks/useDocFormSession";
// 역할 — 셸 툴바·단축키 CRUD 등록
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — 공통코드 상태 라벨
import { useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — 공통 CCP API·DTO
import {
  deleteGenericCcp,
  getGenericCcpDetail,
  listGenericCcpTemplates,
  saveGenericCcpMonitor,
  validateDeleteGenericCcp,
  type GenericCcpRow,
  type GenericCcpTemplate,
} from "@/api/ccpGenericApi";
// 역할 — 문서 목록 (목록 패널)
import { listDocuments, type DocumentListRow } from "@/api/documentApi";
// 역할 — 문서형 공통 UI 셸
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
import { DocFormMeta } from "@/components/form/DocFormMeta";
import { DocCellInput, DocCellSelect, DocCellTime } from "@/components/form/DocCell";
import { DocDeviationFooter, type DocCorrectiveValue } from "@/components/form/DocDeviationFooter";
import { DocRowToolbar } from "@/components/form/DocRowToolbar";
import { DocSummaryPanel } from "@/components/form/DocSummaryPanel";
import { DocumentApprovalToolbar } from "@/components/document/DocumentApprovalToolbar";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — 목록 그리드 잠금(신규만 기준일 편집)
import { useGridAccess } from "@/hooks/useGridAccess";
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
// 역할 — 로그인 사용자 서명 보유 확인(메타데이터)·미등록 시 업로드
import { fetchMySignInfo, uploadMySign } from "@/api/sys/userApi";
// 역할 — DocForm 날짜·시각 변환
import { fromInputDate, toInputDate, todayYmd } from "@/lib/docDateTime";
// 역할 — 확인·토스트·업무 오류
import { mesConfirmDanger, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { cn } from "@/lib/cn";

type ColumnPreset = { itemCd: string; label: string; numeric?: boolean };

/** limit_item_kind → 측정 열 — 메뉴 양식 강제 시 TMPL_KIND_OVERRIDE와 함께 사용 */
const PRESETS: Record<string, ColumnPreset[]> = {
  // 가열 — 온도·가열분초·경과 (품온은 스펙 외 보조로 제외)
  LMTITMCH: [
    { itemCd: "TEMP", label: "온도", numeric: true },
    { itemCd: "HEAT_MIN", label: "가열(분)", numeric: true },
    { itemCd: "HEAT_SEC", label: "가열(초)", numeric: true },
    { itemCd: "ELAPSED", label: "경과시간", numeric: true },
  ],
  LMTITMCW: [
    { itemCd: "QTY", label: "원료량", numeric: true },
    { itemCd: "tmpl_prp-water-check", label: "세척수량", numeric: true },
    { itemCd: "TIME", label: "세척시간", numeric: true },
    { itemCd: "COUNT", label: "세척횟수", numeric: true },
  ],
  // 멸균 — 시작/종료온도·총멸균시간 (소독 LMTITMCP와 분리)
  LMTITMST: [
    { itemCd: "START_TEMP", label: "시작온도", numeric: true },
    { itemCd: "END_TEMP", label: "종료온도", numeric: true },
    { itemCd: "STER_TIME", label: "총멸균시간", numeric: true },
  ],
  LMTITMCP: [
    { itemCd: "CONCENTRATION", label: "소독농도", numeric: true },
    { itemCd: "TIME", label: "소독시간", numeric: true },
    { itemCd: "CHLORINE", label: "잔류염소", numeric: true },
  ],
  // 여과 — 상태·파손·이물·청결·제품상태 (모니터링시간은 checkTime 열)
  LMTITMCF: [
    { itemCd: "STATUS", label: "상태" },
    { itemCd: "DAMAGE", label: "필터파손" },
    { itemCd: "FOREIGN_KIND", label: "이물종류" },
    { itemCd: "FOREIGN_SIZE", label: "이물크기" },
    { itemCd: "CLEAN", label: "청결세척" },
    { itemCd: "PROD_STATE", label: "제품상태" },
  ],
  LMTITMCB: [
    { itemCd: "PRESSURE", label: "세척압력", numeric: true },
    { itemCd: "TIME", label: "세척시간", numeric: true },
  ],
  LMTITMCBA: [
    { itemCd: "PRESSURE", label: "에어압력", numeric: true },
    { itemCd: "TIME", label: "세척시간", numeric: true },
  ],
  LMTITMCI: [
    { itemCd: "GAUSS", label: "자력", numeric: true },
    { itemCd: "CLEAN", label: "자석봉 청소" },
    { itemCd: "METAL", label: "쇳가루", numeric: true },
  ],
  LMTITMCM: [{ itemCd: "AW", label: "수분활성도", numeric: true }],
  LMTITMCQF: [
    { itemCd: "QTY", label: "동결량", numeric: true },
    { itemCd: "TEMP", label: "동결온도", numeric: true },
    { itemCd: "TIME", label: "동결시간", numeric: true },
    { itemCd: "CORE_TEMP", label: "심부온도", numeric: true },
  ],
  LMTITMCCA: [{ itemCd: "CO2", label: "탄산가스 볼륨", numeric: true }],
};

/** 메뉴 양식코드 → 프리셋 강제 (멸균은 소독 kind와 분리) */
const TMPL_KIND_OVERRIDE: Record<string, string> = {
  html_sys_003: "LMTITMCH",
  html_sys_004: "LMTITMST",
  html_sys_005: "LMTITMCF",
};

/** API 비었을 때 leaf 메뉴용 합성 템플릿 */
const FIXED_TEMPLATES: Record<string, GenericCcpTemplate> = {
  html_sys_003: {
    tmplCd: "html_sys_003",
    tmplNm: "가열 모니터링 일지",
    diaryNo: "C0010",
    diaryNm: "중요관리점관리(가열)",
    limitItemKind: "LMTITMCH",
    criticalLimitCn: "○ 온도·가열시간·경과시간",
    monitoringCycleCn: "배치마다(작업 시작·중·종료)",
    monitoringMethodCn: "가열 설비 온도·타이머를 확인하고 기록한다.",
    improvementMethodCn: "한계기준 이탈 시 재가열 후 이탈·개선조치를 기록한다.",
    companyUseYn: "Y",
  },
  html_sys_004: {
    tmplCd: "html_sys_004",
    tmplNm: "멸균 모니터링 일지",
    diaryNo: "C0061",
    diaryNm: "중요관리점관리(멸균)",
    limitItemKind: "LMTITMST",
    criticalLimitCn: "○ 시작온도·종료온도·총 멸균시간",
    monitoringCycleCn: "배치마다(작업 시작·종료)",
    monitoringMethodCn: "멸균기 시작/종료온도·총 멸균시간을 확인하고 기록한다.",
    improvementMethodCn: "한계기준 이탈 시 재멸균 후 이탈·개선조치를 기록한다.",
    companyUseYn: "Y",
  },
  html_sys_005: {
    tmplCd: "html_sys_005",
    tmplNm: "여과 모니터링 일지",
    diaryNo: "C0050",
    diaryNm: "중요관리점관리(여과)",
    limitItemKind: "LMTITMCF",
    criticalLimitCn: "○ 필터 상태·파손·이물·청결·제품상태",
    monitoringCycleCn: "작업 시작 전·작업 중·필터 교체 시",
    monitoringMethodCn: "여과망 상태·파손·이물·청결을 확인하고 기록한다.",
    improvementMethodCn: "필터 파손·이상 시 작업 중지 후 교체·전수검사한다.",
    companyUseYn: "Y",
  },
};

const OX = [
  { value: "O", label: "O" },
  { value: "X", label: "X" },
];

function resolveKind(tmplCd: string | null | undefined, limitItemKind: string | null | undefined): string {
  return (tmplCd && TMPL_KIND_OVERRIDE[tmplCd]) || limitItemKind || "";
}

function resolveColumns(tmplCd: string | null | undefined, limitItemKind: string | null | undefined): ColumnPreset[] {
  const kind = resolveKind(tmplCd, limitItemKind);
  return PRESETS[kind] ?? [{ itemCd: "VALUE", label: "측정값", numeric: true }];
}

/** 여과는 설비/품명 열 숨김 — 상태·모니터링시간 중심 */
function showEquipProduct(tmplCd: string | null | undefined): boolean {
  return tmplCd !== "html_sys_005";
}

function timeLabel(tmplCd: string | null | undefined): string {
  if (tmplCd === "html_sys_003") return "측정시간";
  if (tmplCd === "html_sys_005") return "모니터링시간";
  return "점검시간";
}

const editableStatus = (status: string | null | undefined) => !status || status === "WRK" || status === "RJT";

function rowJudgeOx(judgeCd?: string | null): string {
  if (judgeCd === "O" || judgeCd === "X") return judgeCd;
  if (judgeCd === "P") return "O";
  if (judgeCd === "F") return "X";
  return "";
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
  tmplCd: string;
  mngNm: string;
  rows: GenericCcpRow[];
  corrective: DocCorrectiveValue;
  limitItemKind?: string | null;
};

function makeEmptyRow(columns: ColumnPreset[], userId: string, userNm: string, rowSeq: number): GenericCcpRow {
  return {
    rowSeq,
    checkTime: "",
    equipNm: "",
    productNm: "",
    judgeCd: null,
    judgeModYn: "N",
    checkerId: userId,
    checkerNm: userNm,
    signYn: "N",
    cells: columns.map((column) => ({ itemCd: column.itemCd, numVal: null, txtVal: "", judgeCd: null })),
  };
}

function makeRows(columns: ColumnPreset[], userId: string, userNm: string): GenericCcpRow[] {
  return Array.from({ length: 6 }, (_, index) => makeEmptyRow(columns, userId, userNm, index + 1));
}

function mapDetailRows(
  detailRows: GenericCcpRow[] | undefined,
  columns: ColumnPreset[],
  userId: string,
  userNm: string,
): GenericCcpRow[] {
  const loaded = (detailRows ?? []).map((item, index) => ({
    rowSeq: item.rowSeq || index + 1,
    checkTime: item.checkTime ?? "",
    equipNm: item.equipNm ?? "",
    productNm: item.productNm ?? "",
    judgeCd: item.judgeCd ?? null,
    judgeModYn: item.judgeModYn ?? "N",
    checkerId: item.checkerId ?? userId,
    checkerNm: item.checkerNm ?? userNm,
    signYn: item.signYn === "Y" ? "Y" : "N",
    cells: columns.map((column) => {
      const cell = (item.cells ?? []).find((c) => c.itemCd === column.itemCd);
      return {
        itemCd: column.itemCd,
        numVal: cell?.numVal ?? null,
        txtVal: cell?.txtVal ?? "",
        judgeCd: cell?.judgeCd ?? null,
      };
    }),
  }));
  return loaded.length > 0 ? loaded : makeRows(columns, userId, userNm);
}

function mergeTemplates(api: GenericCcpTemplate[], defaultTmplCd?: string): GenericCcpTemplate[] {
  const byCd = new Map(api.map((row) => [row.tmplCd, row]));
  for (const fixed of Object.values(FIXED_TEMPLATES)) {
    if (!byCd.has(fixed.tmplCd)) byCd.set(fixed.tmplCd, fixed);
  }
  const list = Array.from(byCd.values());
  if (defaultTmplCd) {
    const preferred = list.filter((row) => row.tmplCd === defaultTmplCd);
    const rest = list.filter((row) => row.tmplCd !== defaultTmplCd);
    return preferred.length > 0 ? [...preferred, ...rest] : list;
  }
  return list;
}

export interface CcpGenericMonitorPageProps {
  // 권한 화면코드
  screenCode?: string;
  // 메뉴에서 양식을 고정할 때
  defaultTmplCd?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 공통 CCP 템플릿·draft 목록·측정 셀·결재 툴바를 DocFormLayout으로 제공한다
 *   2) ccp-generic-monitor 및 가열·멸균·여과 leaf에서 마운트한다
 *   3) 저장 실패 시 서버 업무 문구를 토스트로 표시한다
 */
export default function CcpGenericMonitorPage({
  screenCode = "ccp-generic-monitor",
  defaultTmplCd,
}: CcpGenericMonitorPageProps = {}) {
  const user = useAuthStore((state) => state.user);
  const canWrite = useAuthStore((state) => state.can(screenCode, "write") || state.can("ccp-generic-monitor", "write"));
  const canModify = useAuthStore((state) => state.can(screenCode, "modify") || state.can("ccp-generic-monitor", "modify"));
  const canDelete = useAuthStore((state) => state.can(screenCode, "delete") || state.can("ccp-generic-monitor", "delete"));
  // 좌측 문서 목록 — 신규행만 기준일 편집
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

  const [templates, setTemplates] = useState<GenericCcpTemplate[]>([]);
  const [pageTmplCd, setPageTmplCd] = useState(defaultTmplCd ?? "");
  const [selectedRowSeq, setSelectedRowSeq] = useState<number | null>(null);
  // 공통 목록 검색 — 기간·문서번호·작성자 (문서함 keyword·writerId)
  const [search, setSearch] = useState<DocFormSearchValues>(() => defaultDocFormSearch());
  const searchRef = useRef(search);
  searchRef.current = search;

  const buf = activeBuffer;
  const tmplCd = buf?.tmplCd || pageTmplCd || defaultTmplCd || "";
  const selected = useMemo(() => {
    const fromApi = templates.find((row) => row.tmplCd === tmplCd);
    if (fromApi) return fromApi;
    if (tmplCd && FIXED_TEMPLATES[tmplCd]) return FIXED_TEMPLATES[tmplCd];
    return null;
  }, [templates, tmplCd]);
  const columns = useMemo(
    () => resolveColumns(buf?.tmplCd ?? tmplCd, buf?.limitItemKind ?? selected?.limitItemKind),
    [buf?.limitItemKind, buf?.tmplCd, selected?.limitItemKind, tmplCd],
  );
  const docIdx = buf?.docIdx ?? null;
  const status = buf?.status ?? null;
  const editable = editableStatus(status) && (docIdx ? canModify : canWrite);
  const withEquip = showEquipProduct(tmplCd);

  const listColumns = useMemo<GridColumn<ListMeta>[]>(() => [
    // 기준일 — YYYY-MM-DD 표시, 신규 draft만 편집
    { field: "baseDtDisp", header: "기준일", width: 120, editableOnNew: true, type: "date" },
    { field: "docNo", header: "문서번호", width: 120 },
    { field: "statusNm", header: "상태", width: 80 },
  ], []);

  const loadTemplates = useCallback(async () => {
    try {
      const next = await listGenericCcpTemplates();
      const merged = mergeTemplates(next, defaultTmplCd);
      setTemplates(merged);
      const preferred = defaultTmplCd
        ? merged.find((row) => row.tmplCd === defaultTmplCd)
        : merged.find((row) => row.companyUseYn === "Y") ?? merged[0];
      setPageTmplCd((current) => current || preferred?.tmplCd || defaultTmplCd || "");
    } catch (error) {
      // API 실패 시에도 leaf 고정 양식으로 작성 가능
      const merged = mergeTemplates([], defaultTmplCd);
      setTemplates(merged);
      setPageTmplCd((current) => current || defaultTmplCd || merged[0]?.tmplCd || "");
      mesError(error);
    }
  }, [defaultTmplCd]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-07
   * 코멘트:
   *   1) 문서함 목록을 tmplCd·기간으로 조회해 draft를 유지한 채 교체한다
   *   2) 조회·저장·삭제 후 호출한다
   *   3) 실패 시 토스트
   */
  const loadList = useCallback(async () => {
    const filterTmpl = pageTmplCd || defaultTmplCd || "";
    if (!filterTmpl) {
      replaceServerList([], (row) => String(row.docIdx));
      return;
    }
    const q = searchRef.current;
    try {
      const server = await listDocuments({
        fromDt: q.fromDt,
        toDt: q.toDt,
        tmplCd: filterTmpl,
        // 문서번호 — 문서함 keyword (doc_no·title ILIKE)
        keyword: q.docNo.trim() || undefined,
        // 작성자 ID·이름 — SP writer_id 파라미터
        writerId: q.writer.trim() || undefined,
      });
      replaceServerList(
        server.map((row: DocumentListRow) => ({
          docIdx: row.docIdx,
          docNo: row.docNo,
          status: row.status,
          baseKey: row.baseDt,
          baseDtDisp: toInputDate(row.baseDt),
          statusNm: statusLabel(row.status, row.status),
          ngCnt: 0,
        } satisfies ListMeta)),
        (row) => String(row.docIdx),
      );
    } catch (error) {
      mesError(error);
    }
  }, [defaultTmplCd, pageTmplCd, replaceServerList, statusLabel]);

  useEffect(() => { void loadTemplates(); }, [loadTemplates]);
  useEffect(() => { void loadList(); }, [loadList]);

  const resolveTmpl = useCallback((cd: string) => {
    return templates.find((row) => row.tmplCd === cd)
      ?? (cd && FIXED_TEMPLATES[cd] ? FIXED_TEMPLATES[cd] : null);
  }, [templates]);

  const handleSelect = useCallback(async (key: string | null) => {
    await selectKey(key, async (k, row) => {
      const cached = getBuffer(k);
      if (cached) return cached;
      const lockTmpl = pageTmplCd || defaultTmplCd || selected?.tmplCd || "";
      const tmpl = resolveTmpl(lockTmpl);
      const kind = resolveKind(lockTmpl, tmpl?.limitItemKind);
      const cols = resolveColumns(lockTmpl, kind);
      if (row._rowState === "C" || !row.docIdx) {
        return {
          docIdx: null,
          docNo: "",
          status: null,
          baseKey: row.baseKey || todayYmd(),
          tmplCd: lockTmpl,
          mngNm: user?.userNm ?? "",
          rows: makeRows(cols, user?.userId ?? "", user?.userNm ?? ""),
          corrective: {},
          limitItemKind: kind,
        };
      }
      try {
        const detail = await getGenericCcpDetail(row.docIdx);
        const detailTmpl = detail.tmplCd || lockTmpl;
        const detailKind = resolveKind(detailTmpl, detail.limitItemKind ?? kind);
        const nextColumns = resolveColumns(detailTmpl, detailKind);
        return {
          docIdx: detail.docIdx,
          docNo: detail.docNo ?? "",
          status: detail.status ?? null,
          baseKey: detail.baseDt,
          tmplCd: detailTmpl,
          mngNm: detail.mngNm ?? user?.userNm ?? "",
          rows: mapDetailRows(detail.rows, nextColumns, user?.userId ?? "", user?.userNm ?? ""),
          corrective: {},
          limitItemKind: detailKind,
        };
      } catch (error) {
        mesError(error);
        return null;
      }
    });
  }, [defaultTmplCd, getBuffer, pageTmplCd, resolveTmpl, selectKey, selected?.tmplCd, user?.userId, user?.userNm]);

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
   * 일자: 2026-08-07
   * 코멘트:
   *   1) 신규 draft와 측정 행 버퍼를 추가한다
   *   2) 신규 버튼에서 호출한다
   *   3) 양식 미선택이면 안내만 하고 중단한다
   */
  const handleNew = () => {
    if (!canWrite) return;
    const lockTmpl = pageTmplCd || defaultTmplCd || "";
    const tmpl = resolveTmpl(lockTmpl) ?? templates[0] ?? null;
    if (!tmpl) return mesToast("공통 CCP 양식을 선택하세요.", "warn");
    // 당일 복수 문서 허용 — 기존 기준키 행이 있어도 항상 새 draft
    const baseKey = todayYmd();
    const kind = resolveKind(tmpl.tmplCd, tmpl.limitItemKind);
    const cols = resolveColumns(tmpl.tmplCd, kind);
    const next: Buf = {
      docIdx: null,
      docNo: "",
      status: null,
      baseKey,
      tmplCd: tmpl.tmplCd,
      mngNm: user?.userNm ?? "",
      rows: makeRows(cols, user?.userId ?? "", user?.userNm ?? ""),
      corrective: {},
      limitItemKind: kind,
    };
    setPageTmplCd(tmpl.tmplCd);
    addDraft(
      {
        docIdx: null,
        docNo: "",
        status: null,
        baseKey,
        baseDtDisp: toInputDate(baseKey),
        statusNm: "신규",
        ngCnt: 0,
      },
      next,
    );
  };

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
            if (!b.tmplCd) return { message: "공통 CCP 양식을 선택하세요.", rowKey: key };
            if (!/^\d{8}$/.test(b.baseKey)) return { message: MES.required("기준일"), rowKey: key };
            if (seen.has(b.baseKey)) return { message: `기준키가 중복되었습니다: ${b.baseKey}`, rowKey: key };
            seen.add(b.baseKey);
            if (b.rows.length === 0) return { message: MES.required("기록 행"), rowKey: key };
          }
          return null;
        },
        saveOne: async (_row, b) => {
          const tmpl = resolveTmpl(b.tmplCd);
          const kind = resolveKind(b.tmplCd, b.limitItemKind ?? tmpl?.limitItemKind);
          const saved = await saveGenericCcpMonitor({
            docIdx: b.docIdx,
            baseDt: b.baseKey,
            tmplCd: b.tmplCd,
            diaryNo: tmpl?.diaryNo,
            limitItemKind: kind,
            mngUserId: user?.userId ?? "",
            mngNm: b.mngNm,
            rows: b.rows,
          });
          if (!saved) throw new Error("문서번호를 받지 못했습니다.");
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
    } catch (error) {
      mesError(error);
    }
  }, "save");

  const handleDelete = () => asyncAct.run(async () => {
    if (!activeKey) return mesToast(MES.selectRow, "warn");
    const row = listRows.find((r) => r._key === activeKey);
    if (!row) return;
    if (row._rowState === "C") {
      removeDraft(activeKey);
      return;
    }
    if (!docIdx) return mesToast("삭제할 문서를 선택하세요.", "warn");
    if (!editable) return mesToast("결재 진행·완료 문서는 삭제할 수 없습니다.", "warn");
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    try {
      const keys = [{ docIdx }];
      await validateDeleteGenericCcp(keys);
      if (!(await mesConfirmDanger("선택한 공통 CCP 일지를 삭제하시겠습니까?"))) return;
      await deleteGenericCcp(keys);
      mesToast(MES.deleteDone, "success");
      await loadList();
      await handleSelect(null);
    } catch (error) {
      mesError(error);
    }
  }, "del");

  usePageCommands({
    search: () => { void loadList(); },
    add: handleNew,
    save: () => { void handleSave(); },
    del: () => { void handleDelete(); },
  });

  const patchCell = (rowSeq: number, itemCd: string, raw: string, numeric?: boolean) => {
    if (!editable) return;
    patchActive((current) => ({
      ...current,
      rows: current.rows.map((row) => (row.rowSeq !== rowSeq ? row : {
        ...row,
        cells: row.cells.map((cell) => (cell.itemCd !== itemCd ? cell : numeric
          ? { ...cell, numVal: raw.trim() === "" ? null : Number(raw) }
          : { ...cell, txtVal: raw })),
      })),
    }));
  };

  const patchRow = (rowSeq: number, patch: Partial<GenericCcpRow>) => {
    if (!editable) return;
    patchActive((current) => ({
      ...current,
      rows: current.rows.map((row) => (row.rowSeq !== rowSeq ? row : { ...row, ...patch })),
    }));
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-07
   * 코멘트:
   *   1) 로그인 사용자 서명이 등록돼 있으면 해당 행 signYn을 Y로 올린다
   *      서명 실물은 저장 시 SP가 tbl_user.sign_img에서 그 행으로 복사한다
   *   2) 미등록이면 파일 선택 업로드 후 적용한다
   *   3) 실패 시 토스트
   */
  const applyRowSign = async (rowSeq: number) => {
    if (!editable) return;
    try {
      // 서명 등록 여부만 확인 — 파일명·보유여부만 받고 이미지는 내려받지 않는다
      const info = await fetchMySignInfo();
      if (info.signYn !== "Y") {
        const input = document.createElement("input");
        input.type = "file";
        input.accept = "image/*";
        const file = await new Promise<File | null>((resolve) => {
          input.onchange = () => resolve(input.files?.[0] ?? null);
          input.click();
        });
        if (!file) return;
        await uploadMySign(file);
      }
      patchRow(rowSeq, {
        signYn: "Y",
        checkerId: user?.userId ?? "",
        checkerNm: user?.userNm ?? "",
      });
      mesToast("서명을 적용했습니다.", "success");
    } catch (error) {
      mesError(error);
    }
  };

  const handleAddRow = () => {
    if (!editable || !buf) return;
    const nextSeq = Math.max(0, ...buf.rows.map((r) => r.rowSeq)) + 1;
    patchActive((prev) => ({
      ...prev,
      rows: [...prev.rows, makeEmptyRow(columns, user?.userId ?? "", user?.userNm ?? "", nextSeq)],
    }));
    setSelectedRowSeq(nextSeq);
  };

  const handleRemoveRow = () => {
    if (!editable || !buf || selectedRowSeq == null) return;
    if (buf.rows.length <= 1) return mesToast("최소 1행은 남겨야 합니다.", "warn");
    patchActive((prev) => ({
      ...prev,
      rows: prev.rows.filter((r) => r.rowSeq !== selectedRowSeq).map((r, i) => ({ ...r, rowSeq: i + 1 })),
    }));
    setSelectedRowSeq(null);
  };

  const mngNm = buf?.mngNm ?? "";
  const baseKey = buf?.baseKey ?? "";
  const rows = buf?.rows ?? [];
  const corrective = buf?.corrective ?? {};
  const paperTitle = selected?.tmplNm ?? "공통 CCP 모니터링 일지";

  return (
    <DocFormLayout>
      <DocFormSearchToolbar
        // 기간·문서번호·작성자
        values={search}
        // 조건 부분 갱신
        onChange={(patch) => setSearch((prev) => ({ ...prev, ...patch }))}
        // 기간·양식 기준 목록 재조회
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
          status={status}
          // dirty 전건 저장
          onSave={() => void handleSave()}
          canSave={!!editable}
          canApprove={canWrite || canModify}
          // 작성 화면 — 상신·취소만 (검토·승인은 결재함)
          writerActionsOnly
          saveBusy={asyncAct.isBusy("save")}
          onApproved={() => {
            void loadList();
            if (docIdx && activeKey) {
              void getGenericCcpDetail(docIdx).then((d) => {
                const detailKind = resolveKind(d.tmplCd, d.limitItemKind);
                const nextColumns = resolveColumns(d.tmplCd, detailKind);
                putBuffer(activeKey, {
                  docIdx: d.docIdx,
                  docNo: d.docNo ?? "",
                  status: d.status ?? null,
                  baseKey: d.baseDt,
                  tmplCd: d.tmplCd,
                  mngNm: d.mngNm ?? user?.userNm ?? "",
                  rows: mapDetailRows(d.rows, nextColumns, user?.userId ?? "", user?.userNm ?? ""),
                  corrective: getBuffer(activeKey)?.corrective ?? {},
                  limitItemKind: detailKind,
                }, {
                  status: d.status ?? null,
                  statusNm: statusLabel(d.status ?? "", d.status ?? ""),
                });
              }).catch((error) => mesError(error));
            }
          }}
          statusLabel={status ? statusLabel(status, status) : "신규"}
        />
      ) : null}
      <DocFormBody withSummary>
        <DocFormDocumentList>
          <MesEditableGrid
            // 공통 CCP 문서목록 설정 키
            persistId={`ccp-generic-doc-list-${screenCode}`}
            // 서버 목록 + draft
            rows={listRows as EditableRow<ListMeta>[]}
            // 기준일·문서번호·상태
            columns={listColumns}
            // 신규행 기준일 편집
            editable={canWrite || canModify}
            // 패널 제목
            title="문서 목록"
            // 부모 flex 높이 채움
            height="100%"
            // 선택 키
            activeKey={activeKey}
            // 행 클릭 → 버퍼 전환
            onActivate={(row) => { void handleSelect(row._key ?? null); }}
            // 신규행 기준일 셀 → 버퍼 동기
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
            <DocPaper title={paperTitle} writerNm={mngNm}>
              <DocFormMeta
                // 작성일 — baseKey와 목록 동기
                baseDtNode={(
                  <DocCellInput
                    type="date"
                    value={toInputDate(baseKey)}
                    disabled={!editable}
                    onChange={(value) => {
                      const next = fromInputDate(value);
                      patchActive((prev) => ({ ...prev, baseKey: next }), {
                        baseKey: next,
                        baseDtDisp: toInputDate(next),
                      });
                    }}
                  />
                )}
                // 담당자
                managerNode={(
                  <DocCellInput
                    value={mngNm}
                    disabled={!editable}
                    onChange={(v) => patchActive((prev) => ({ ...prev, mngNm: v }))}
                  />
                )}
                // 공정(양식) — leaf 고정이면 숨겨 템플릿 혼동 방지
                extraRows={defaultTmplCd ? [] : [{
                  label: "공정",
                  node: (
                    <DocCellSelect
                      // 선택 양식코드
                      value={tmplCd}
                      // 저장 후 잠금
                      disabled={!editable || !!docIdx}
                      // 사용 가능 공통 CCP 양식
                      options={templates.map((row) => ({ value: row.tmplCd, label: row.tmplNm }))}
                      emptyLabel="양식을 선택하세요"
                      onChange={(value) => {
                        const nextTmpl = resolveTmpl(value);
                        if (!nextTmpl) return;
                        setPageTmplCd(nextTmpl.tmplCd);
                        const kind = resolveKind(nextTmpl.tmplCd, nextTmpl.limitItemKind);
                        const cols = resolveColumns(nextTmpl.tmplCd, kind);
                        patchActive((prev) => ({
                          ...prev,
                          tmplCd: nextTmpl.tmplCd,
                          limitItemKind: kind,
                          rows: makeRows(cols, user?.userId ?? "", user?.userNm ?? ""),
                        }));
                      }}
                    />
                  ),
                }]}
                limitRmk={selected?.criticalLimitCn || "-"}
                cycleRmk={selected?.monitoringCycleCn || "-"}
                methodRmk={selected?.monitoringMethodCn || "-"}
              />
              <div className="mt-3 overflow-x-auto">
                <table className="doc-table">
                  <thead>
                    <tr>
                      <th>{timeLabel(tmplCd)}</th>
                      {withEquip ? (
                        <>
                          <th>설비명</th>
                          <th>품명</th>
                        </>
                      ) : null}
                      {columns.map((column) => <th key={column.itemCd}>{column.label}</th>)}
                      <th>판정</th>
                      <th>점검자</th>
                      <th>서명</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((row) => {
                      const ox = rowJudgeOx(row.judgeCd);
                      const ng = ox === "X" || row.judgeCd === "F";
                      return (
                        <tr
                          key={row.rowSeq}
                          className={cn(selectedRowSeq === row.rowSeq && "doc-row-selected")}
                          onClick={() => setSelectedRowSeq(row.rowSeq)}
                        >
                          <td>
                            <DocCellTime
                              // 측정·모니터링 시각 — HH:MM 저장
                              value={row.checkTime}
                              disabled={!editable}
                              storage="hm"
                              onChange={(v) => patchRow(row.rowSeq, { checkTime: v })}
                            />
                          </td>
                          {withEquip ? (
                            <>
                              <td>
                                <DocCellInput
                                  // 설비명 — 가열·멸균
                                  value={row.equipNm ?? ""}
                                  disabled={!editable}
                                  onChange={(v) => patchRow(row.rowSeq, { equipNm: v })}
                                />
                              </td>
                              <td>
                                <DocCellInput
                                  // 품명 — 가열·멸균
                                  value={row.productNm ?? ""}
                                  disabled={!editable}
                                  onChange={(v) => patchRow(row.rowSeq, { productNm: v })}
                                />
                              </td>
                            </>
                          ) : null}
                          {columns.map((column) => {
                            const cell = row.cells.find((item) => item.itemCd === column.itemCd);
                            return (
                              <td key={`${row.rowSeq}-${column.itemCd}`}>
                                <DocCellInput
                                  // 측정 셀 — 숫자·텍스트
                                  type={column.numeric ? "number" : "text"}
                                  value={column.numeric ? String(cell?.numVal ?? "") : cell?.txtVal ?? ""}
                                  disabled={!editable}
                                  onChange={(v) => patchCell(row.rowSeq, column.itemCd, v, column.numeric)}
                                />
                              </td>
                            );
                          })}
                          <td className={cn("text-center font-medium", ng ? "text-red-600" : "text-slate-700")}>
                            <DocCellSelect
                              // 수동 적부 O/X
                              value={ox}
                              disabled={!editable}
                              options={OX}
                              emptyLabel=""
                              onChange={(v) => patchRow(row.rowSeq, {
                                judgeCd: v || null,
                                judgeModYn: v ? "Y" : "N",
                              })}
                            />
                          </td>
                          <td>
                            <DocCellInput
                              // 점검자명 — 로그인 기본
                              value={row.checkerNm || ""}
                              disabled={!editable}
                              onChange={(v) => patchRow(row.rowSeq, {
                                checkerNm: v,
                                checkerId: row.checkerId || user?.userId || "",
                              })}
                            />
                          </td>
                          <td className="text-center">
                            {row.signYn === "Y" ? (
                              <button
                                type="button"
                                className="text-xs text-emerald-700 underline disabled:no-underline disabled:text-slate-500"
                                disabled={!editable}
                                onClick={(e) => {
                                  e.stopPropagation();
                                  void applyRowSign(row.rowSeq);
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
                                  void applyRowSign(row.rowSeq);
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
              <DocRowToolbar
                // 행 추가 — 표 아래 표준 위치
                onAdd={handleAddRow}
                // 선택 행 삭제
                onRemove={handleRemoveRow}
                // 임시·반려만 추가
                canAdd={!!editable}
                // 선택 행이 있을 때만 삭제
                canRemove={!!editable && selectedRowSeq != null}
              />
              <DocDeviationFooter
                // 이탈·개선조치 푸터 값
                value={corrective}
                // 버퍼 패치
                onChange={(next) => patchActive((prev) => ({ ...prev, corrective: next }))}
                // 임시·반려만 편집
                editable={!!editable}
              />
            </DocPaper>
          )}
        </DocFormMainPanel>
        <DocFormSidePanel>
          <DocSummaryPanel
            // 문서번호
            documentNumber={buf?.docNo ?? ""}
            // 상태
            statusLabel={status ? statusLabel(status, status) : "신규"}
            // 필수 진행
            requiredFieldProgress={{ completed: Number(Boolean(baseKey)) + Number(rows.length > 0), total: 2 }}
            // 결재선
            approvalLine="작성 → 검토 → 승인"
            // 힌트
            hint="측정 셀을 입력한 뒤 저장하세요. 여러 draft를 만든 경우 저장 시 전건이 순차 저장됩니다."
          />
        </DocFormSidePanel>
      </DocFormBody>
    </DocFormLayout>
  );
}
