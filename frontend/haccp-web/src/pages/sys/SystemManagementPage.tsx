/**
 * SystemManagementPage — HACCP 시스템 관리·이력 MesEditableGrid 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 회사·사용자·부서·권한·메뉴·공통코드는 인라인 편집 그리드로 변경행만 저장한다
 *   2) 로그인·통계·감사 이력은 읽기 전용 그리드와 기간 검색만 제공한다
 *   3) ProcessPage와 같은 useEditableRows·선택삭제·newOnly 잠금 흐름을 따른다
 *
 * PIPELINE[HF99] 시스템 관리 그리드 화면
 * PIPELINE[HF92, HF96, HF97, HF98] 연관 모듈
 */
// 역할 — 상태·메모·초기 조회·파일 입력 참조
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 화면별 5단계 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 중복 클릭 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — 그리드 잠금 훅
import { useGridAccess } from "@/hooks/useGridAccess";
// 역할 — 편집 행 상태
import { useEditableRows } from "@/hooks/useEditableRows";
// 역할 — 편집 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — mes-web형 행추가·저장·삭제 버튼 묶음
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
// 역할 — SoPage형 그리드 패널 헤더(보이는 그리드명)
import { gridHeadClass } from "@/components/layout/pageClasses";
// 역할 — 표준 버튼·입력
import { MesButton } from "@/components/ui/MesButton";
import { Input } from "@/components/ui/Input";
// 역할 — 확인·토스트·오류·공통 문구
import { mesConfirm, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
// 역할 — 셸 상단·단축키 CRUD 명령 등록
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — 저장 가드
import { guardSaveWithKey } from "@/shell/gridRules";
// 역할 — 선택행 우선 삭제 대상
import { resolveRowsForDelete } from "@/shell/resolveDelete";
// 역할 — 그리드 컬럼·편집 행 타입
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
// 역할 — 시스템 API
import {
  deleteSystemRows,
  listSystemRows,
  saveSystemRows,
  uploadUserSign,
  validateDeleteSystemRows,
  type SystemRow,
  type SystemScreenCode,
} from "@/api/systemApi";
// 역할 — 화면별 잠금 규칙
import { SYSTEM_GRID_RULES, SYSTEM_HISTORY_SCREENS } from "./SystemManagementPage.rules";

const SCREEN_TITLE: Record<SystemScreenCode, string> = {
  "company-management": "회사정보 관리",
  "user-management": "사용자 관리",
  "department-management": "부서 관리",
  "role-management": "권한그룹 관리",
  "menu-management": "메뉴 관리",
  "common-code-management": "공통코드 관리",
  "login-history": "로그인 이력",
  "screen-usage-statistics": "화면 이용 통계",
  "audit-log": "변경 감사 로그",
};

const YN = [
  { value: "Y", label: "사용" },
  { value: "N", label: "미사용" },
] as const;
const YN_MAP = { Y: "사용", N: "미사용" };

type SysRow = SystemRow & { idx?: number | null; _key?: string };

// 이력·통계 최초 조회 기본 기간(일) — 당일만이면 빈 그리드가 잦아 최근 구간으로 연다
const HISTORY_DEFAULT_RANGE_DAYS = 30;

function todayYmd(): string {
  return new Date().toISOString().slice(0, 10).replace(/-/g, "");
}

/** days일 전 날짜를 YYYYMMDD로 반환한다 — 이력 fromDt 초기값용 */
function daysAgoYmd(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return d.toISOString().slice(0, 10).replace(/-/g, "");
}

function inputDate(ymd: string): string {
  return ymd.length === 8 ? `${ymd.slice(0, 4)}-${ymd.slice(4, 6)}-${ymd.slice(6)}` : "";
}

/** 화면별 고정 컬럼 — 동적 Object.keys 목록을 쓰지 않는다 */
function buildColumns(screenCode: SystemScreenCode, editable: boolean): GridColumn<SysRow>[] {
  const ynCol = (field: keyof SysRow & string, header: string): GridColumn<SysRow> => ({
    field, header, width: 80, type: "code", editable, codeOptions: [...YN], codeMap: YN_MAP,
  });
  switch (screenCode) {
    case "company-management":
      return [
        { field: "coNm", header: "회사명", width: 160, editable, required: true },
        { field: "coNmEn", header: "영문명", width: 140, editable },
        { field: "bizNo", header: "사업자번호", width: 120, editable },
        { field: "ceoNm", header: "대표자", width: 100, editable },
        { field: "telNo", header: "전화", width: 110, editable },
        { field: "addrH", header: "주소", width: 180, editable },
        { field: "addrD", header: "상세주소", width: 140, editable },
        { field: "retentionMonth", header: "보존개월", width: 90, type: "number", editable },
      ];
    case "user-management":
      return [
        { field: "userId", header: "사용자 ID", width: 110, required: true, editableOnNew: true },
        { field: "userNm", header: "사용자명", width: 110, editable, required: true },
        { field: "userPw", header: "비밀번호", width: 120, editable, editableOnNew: true },
        { field: "empCd", header: "사번", width: 90, editable },
        { field: "usrgrpCd", header: "권한그룹", width: 100, editable, required: true },
        { field: "deptCd", header: "부서코드", width: 100, editable },
        { field: "posCd", header: "직위", width: 80, editable },
        { field: "email", header: "이메일", width: 160, editable },
        { field: "mobile", header: "휴대폰", width: 120, editable },
        // 서명 경로 — 업로드 버튼으로만 갱신(수기 편집 금지)
        { field: "signPath", header: "서명경로", width: 160, editable: false },
        { field: "lockYn", header: "잠금", width: 70, type: "code", editable, codeOptions: [{ value: "Y", label: "잠금" }, { value: "N", label: "정상" }], codeMap: { Y: "잠금", N: "정상" } },
        ynCol("useYn", "사용"),
      ];
    case "department-management":
      return [
        { field: "deptCd", header: "부서코드", width: 100, required: true, editableOnNew: true },
        { field: "deptNm", header: "부서명", width: 140, editable, required: true },
        { field: "hDeptCd", header: "상위부서", width: 100, editable },
        { field: "sortNo", header: "정렬", width: 70, type: "number", editable },
        ynCol("useYn", "사용"),
      ];
    case "role-management":
      return [
        { field: "usrgrpCd", header: "권한그룹코드", width: 120, required: true, editableOnNew: true },
        { field: "usrgrpNm", header: "권한그룹명", width: 140, editable, required: true },
        { field: "descRmk", header: "설명", width: 200, editable },
        ynCol("useYn", "사용"),
      ];
    case "menu-management":
      return [
        // MES GRPA/B/C 참고 — 트리 depth로 산출한 대·중·소 (편집 불가)
        { field: "grpANm", header: "대분류", width: 120, editable: false },
        { field: "grpBNm", header: "중분류", width: 120, editable: false },
        { field: "grpCNm", header: "소분류", width: 140, editable: false },
        { field: "menuCd", header: "메뉴코드", width: 140, required: true, editableOnNew: true },
        { field: "menuNm", header: "메뉴명", width: 160, editable, required: true },
        { field: "hMenuCd", header: "상위메뉴", width: 120, editable },
        { field: "scrnCd", header: "화면코드", width: 160, editable },
        { field: "sortNo", header: "정렬", width: 70, type: "number", editable },
        ynCol("useYn", "사용"),
      ];
    case "common-code-management":
      return [
        { field: "mainCd", header: "대분류", width: 110, required: true, editableOnNew: true },
        { field: "subCd", header: "세부코드", width: 110, required: true, editableOnNew: true },
        { field: "codeNm", header: "코드명", width: 160, editable, required: true },
        { field: "sortNo", header: "정렬", width: 70, type: "number", editable },
        { field: "ref1", header: "참조1", width: 100, editable },
        { field: "ref2", header: "참조2", width: 100, editable },
        ynCol("useYn", "사용"),
      ];
    case "login-history":
      return [
        { field: "loginDt", header: "로그인 일시", width: 150 },
        { field: "logoutDt", header: "로그아웃 일시", width: 150 },
        { field: "userId", header: "사용자 ID", width: 110 },
        { field: "userNm", header: "사용자명", width: 110 },
        { field: "resultCd", header: "결과", width: 80 },
        { field: "ipAddr", header: "접속 IP", width: 120 },
      ];
    case "screen-usage-statistics":
      return [
        { field: "statDt", header: "집계일", width: 100 },
        { field: "scrnCd", header: "화면코드", width: 160 },
        { field: "pvCnt", header: "PV", width: 80, type: "number" },
        { field: "uvCnt", header: "UV", width: 80, type: "number" },
        { field: "sessCnt", header: "세션수", width: 80, type: "number" },
      ];
    case "audit-log":
      return [
        { field: "insDt", header: "기록 일시", width: 150 },
        { field: "tblNm", header: "대상 테이블", width: 160 },
        { field: "actionCd", header: "행위", width: 80 },
        { field: "userId", header: "작업자", width: 110 },
        { field: "ipAddr", header: "접속 IP", width: 120 },
      ];
  }
}

function defaultRow(screenCode: SystemScreenCode): SysRow {
  switch (screenCode) {
    case "company-management":
      return { coNm: "", retentionMonth: 24 };
    case "user-management":
      return { userId: "", userNm: "", userPw: "", usrgrpCd: "USER", lockYn: "N", useYn: "Y" };
    case "department-management":
      return { deptCd: "", deptNm: "", sortNo: 0, useYn: "Y" };
    case "role-management":
      return { usrgrpCd: "", usrgrpNm: "", useYn: "Y" };
    case "menu-management":
      return { menuCd: "", menuNm: "", sortNo: 0, useYn: "Y" };
    case "common-code-management":
      return { mainCd: "", subCd: "", codeNm: "", sortNo: 0, useYn: "Y" };
    default:
      return {};
  }
}

function requiredFields(screenCode: SystemScreenCode): Array<{ field: keyof SysRow & string; label: string }> {
  switch (screenCode) {
    case "company-management": return [{ field: "coNm", label: "회사명" }];
    case "user-management": return [
      { field: "userId", label: "사용자 ID" }, { field: "userNm", label: "사용자명" }, { field: "usrgrpCd", label: "권한그룹" },
    ];
    case "department-management": return [{ field: "deptCd", label: "부서코드" }, { field: "deptNm", label: "부서명" }];
    case "role-management": return [{ field: "usrgrpCd", label: "권한그룹코드" }, { field: "usrgrpNm", label: "권한그룹명" }];
    case "menu-management": return [{ field: "menuCd", label: "메뉴코드" }, { field: "menuNm", label: "메뉴명" }];
    case "common-code-management": return [
      { field: "mainCd", label: "대분류" }, { field: "subCd", label: "세부코드" }, { field: "codeNm", label: "코드명" },
    ];
    default: return [];
  }
}

interface SystemManagementPageProps {
  screenCode: SystemScreenCode;
}

/**
 * 메뉴 트리에서 대·중·소 표시명을 채운다 (MES GRPA/B/C 참고).
 * depth0=대, depth1=중, depth2+=소. 이름은 경로상 메뉴명을 쓴다.
 */
function enrichMenuLevels(rows: SysRow[]): SysRow[] {
  const byCd = new Map<string, SysRow>();
  for (const row of rows) {
    const cd = String(row.menuCd ?? "").trim();
    if (cd) byCd.set(cd, row);
  }
  const pathOf = (row: SysRow): SysRow[] => {
    const chain: SysRow[] = [];
    let cur: SysRow | undefined = row;
    const guard = new Set<string>();
    while (cur) {
      const cd = String(cur.menuCd ?? "").trim();
      if (!cd || guard.has(cd)) break;
      guard.add(cd);
      chain.unshift(cur);
      const parent = String(cur.hMenuCd ?? "").trim();
      cur = parent ? byCd.get(parent) : undefined;
    }
    return chain;
  };
  return rows.map((row) => {
    const path = pathOf(row);
    const names = path.map((item) => String(item.menuNm ?? "").trim());
    return {
      ...row,
      grpANm: names[0] || "",
      grpBNm: names[1] || "",
      grpCNm: names.length >= 3 ? names[names.length - 1] : "",
      levelNm: path.length <= 1 ? "대분류" : path.length === 2 ? "중분류" : "소분류",
    };
  });
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 화면코드별 고정 컬럼으로 시스템 관리·이력 그리드를 렌더링한다
 *   2) 메뉴관리는 대·중·소·메뉴코드·메뉴명 검색을 제공한다
 *   3) ProcessPage와 같은 useEditableRows·선택삭제·newOnly 잠금 흐름을 따른다
 */
export default function SystemManagementPage({ screenCode }: SystemManagementPageProps) {
  const title = SCREEN_TITLE[screenCode];
  const isHistory = SYSTEM_HISTORY_SCREENS.has(screenCode);
  const isMenu = screenCode === "menu-management";
  const canWrite = useAuthStore((state) => state.can(screenCode, "write"));
  const canModify = useAuthStore((state) => state.can(screenCode, "modify"));
  const canDelete = useAuthStore((state) => state.can(screenCode, "delete"));
  const asyncAct = useAsyncAction();
  const [keyword, setKeyword] = useState("");
  // 메뉴관리 전용 검색 — 메뉴코드·메뉴명
  const [qMenuCd, setQMenuCd] = useState("");
  const [qMenuNm, setQMenuNm] = useState("");
  // 이력·통계만 최근 N일~오늘, 관리 화면은 기간 미사용(값은 무시)
  const [fromDt, setFromDt] = useState(() => (isHistory ? daysAgoYmd(HISTORY_DEFAULT_RANGE_DAYS) : todayYmd()));
  const [toDt, setToDt] = useState(todayYmd);
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  // 서명 이미지 파일 선택 — 사용자 관리 전용
  const signFileRef = useRef<HTMLInputElement>(null);
  const clearSel = () => { setSelKeys([]); setSelReset((n) => n + 1); };

  const g = useEditableRows<SysRow>("idx");
  const rules = SYSTEM_GRID_RULES[screenCode];
  const grid = useGridAccess(rules, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: isHistory || !canModify,
    extra: { canWrite, canModify, canDelete },
  });
  const columns = useMemo(
    () => buildColumns(screenCode, !isHistory && (canWrite || canModify)),
    [canModify, canWrite, isHistory, screenCode],
  );

  const load = useCallback(async () => {
    try {
      // 메뉴는 전체 조회 후 코드·명으로 필터 — 대·중·소 산출에 전체 트리 필요
      const kw = isMenu ? "" : keyword.trim();
      const rows = await listSystemRows(screenCode, { keyword: kw, fromDt, toDt });
      let next: SysRow[] = rows.map((row) => ({ ...row, userPw: "" }));
      if (isMenu) {
        next = enrichMenuLevels(next);
        const cdQ = qMenuCd.trim().toLowerCase();
        const nmQ = qMenuNm.trim().toLowerCase();
        next = next.filter((row) => {
          if (cdQ && !String(row.menuCd ?? "").toLowerCase().includes(cdQ)) return false;
          if (nmQ && !String(row.menuNm ?? "").toLowerCase().includes(nmQ)) return false;
          return true;
        });
      }
      g.load(next);
      setActiveKey(null);
      clearSel();
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- g.load 안정 참조
  }, [fromDt, isMenu, keyword, qMenuCd, qMenuNm, screenCode, toDt]);

  useEffect(() => { void load(); }, [load]);

  const handleAdd = () => {
    if (isHistory || !canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    setActiveKey(g.addRow(defaultRow(screenCode)));
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 활성 사용자 행에 서명 이미지를 업로드하고 목록을 다시 읽는다
   *   2) 사용자 관리 「서명 업로드」에서 호출한다
   *   3) 신규행·미선택·권한 부족은 업무 토스트
   */
  const handleSignUpload = (file: File | null) => {
    if (!file) return;
    void asyncAct.run(async () => {
      if (screenCode !== "user-management") return;
      if (!canModify && !canWrite) {
        mesToast("수정 권한이 없습니다.", "warn");
        return;
      }
      const row = g.rows.find((item) => item._key === activeKey);
      const userId = String(row?.userId ?? "").trim();
      if (!row || !userId) {
        mesToast("서명을 등록할 사용자를 선택하세요.", "warn");
        return;
      }
      if (row._rowState === "C") {
        mesToast("사용자를 먼저 저장한 뒤 서명을 등록하세요.", "warn");
        return;
      }
      try {
        await uploadUserSign(userId, file);
        mesToast("서명을 등록했습니다.", "success");
        await load();
      } catch (error) {
        mesToast(mesError(error), "error");
      } finally {
        if (signFileRef.current) signFileRef.current.value = "";
      }
    }, "sign");
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 변경행만 일괄 저장 API로 저장하고 목록을 다시 읽는다
   *   2) GridCrudButtons·셸 Ctrl+S에서 호출한다
   *   3) 이력 화면·권한 부족·가드 실패는 토스트만 표시한다
   */
  const handleSave = async () => {
    if (isHistory) return;
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    const dirty = g.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    const guard = guardSaveWithKey(grid.rules, grid.ctx, dirty, columns);
    if (guard) {
      mesToast(guard.message, "warn");
      if (guard.rowKey) setActiveKey(guard.rowKey);
      return;
    }
    for (const row of dirty) {
      for (const req of requiredFields(screenCode)) {
        if (!String(row[req.field] ?? "").trim()) {
          mesToast(MES.required(req.label), "warn");
          setActiveKey(row._key);
          return;
        }
      }
      if (screenCode === "user-management" && row._rowState === "C" && !String(row.userPw ?? "").trim()) {
        mesToast(MES.required("비밀번호"), "warn");
        setActiveKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      const payload = dirty.map((row) => {
        const next: SystemRow = { ...row };
        delete (next as { _key?: string })._key;
        delete (next as { _rowState?: string })._rowState;
        delete (next as { _original?: unknown })._original;
        // 대·중·소 표시열 — 저장 payload에서 제외
        delete next.grpANm;
        delete next.grpBNm;
        delete next.grpCNm;
        delete next.levelNm;
        if (screenCode === "user-management" && !String(next.userPw ?? "").trim()) delete next.userPw;
        return next;
      });
      await saveSystemRows(screenCode, payload);
      mesToast(MES.saveDone, "success");
      await load();
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 선택행 우선 삭제 — validate-delete·확인·delete·재조회
   *   2) GridCrudButtons·셸 삭제 단축키에서 호출한다
   *   3) 이력 화면은 무시하고, 참조 차단은 업무 토스트로만 안내한다
   */
  const handleDelete = async () => {
    if (isHistory) return;
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(g.rows, activeKey, setActiveKey, selKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");

    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    let lastFocus = activeKey;
    for (const row of newRows) {
      const { focusKey } = g.removeNewRow(row._key);
      lastFocus = focusKey;
    }
    if (newRows.length > 0) {
      setActiveKey(lastFocus);
      clearSel();
    }
    if (persisted.length === 0) return;

    const keys = persisted
      .map((row) => Number(row.idx))
      .filter((idx) => Number.isFinite(idx) && idx > 0)
      .map((idx) => ({ idx }));
    if (keys.length === 0) return mesToast("삭제할 행의 키가 올바르지 않습니다.", "warn");
    try {
      await validateDeleteSystemRows(screenCode, keys);
      if (!(await mesConfirm(MES.deleteConfirm()))) return;
      await deleteSystemRows(screenCode, keys);
      clearSel();
      mesToast(MES.deleteDone, "success");
      await load();
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  };

  // mes-web과 동일 — 이력은 조회만, 관리 화면은 CRUD를 셸에 등록
  usePageCommands({
    search: () => { void asyncAct.run(load, "search"); },
    add: isHistory ? undefined : handleAdd,
    save: isHistory ? undefined : () => { void asyncAct.run(handleSave, "save"); },
    del: isHistory ? undefined : () => { void asyncAct.run(handleDelete, "del"); },
  });

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 p-3">
      <section className="flex flex-wrap items-end gap-2 rounded border border-slate-200 bg-white p-3">
        {isMenu ? (
          <>
            <label className="flex flex-col gap-1 text-xs text-slate-600">
              메뉴코드
              <Input
                // 메뉴코드 부분검색 — kebab
                value={qMenuCd}
                onChange={(event) => setQMenuCd(event.target.value)}
                placeholder="메뉴코드"
                className="w-44"
              />
            </label>
            <label className="flex flex-col gap-1 text-xs text-slate-600">
              메뉴명
              <Input
                // 메뉴명 부분검색
                value={qMenuNm}
                onChange={(event) => setQMenuNm(event.target.value)}
                placeholder="메뉴명"
                className="w-44"
              />
            </label>
          </>
        ) : (
          <label className="flex flex-col gap-1 text-xs text-slate-600">
            검색어
            <Input value={keyword} onChange={(event) => setKeyword(event.target.value)} placeholder="검색어 입력" className="w-56" />
          </label>
        )}
        {isHistory && (
          <>
            <label className="flex flex-col gap-1 text-xs text-slate-600">시작일
              <Input type="date" value={inputDate(fromDt)} onChange={(event) => setFromDt(event.target.value.replace(/-/g, ""))} className="w-36" />
            </label>
            <label className="flex flex-col gap-1 text-xs text-slate-600">종료일
              <Input type="date" value={inputDate(toDt)} onChange={(event) => setToDt(event.target.value.replace(/-/g, ""))} className="w-36" />
            </label>
          </>
        )}
        <MesButton variant="search" disabled={asyncAct.isBusy("search")} onClick={() => void asyncAct.run(load, "search")}>조회</MesButton>
        {isHistory && <p className="ml-auto text-xs text-slate-500">이력·통계는 읽기 전용입니다.</p>}
      </section>

      <section className="flex min-h-0 flex-1 flex-col overflow-hidden rounded border border-slate-200 bg-white p-2">
        <div className={gridHeadClass}>
          {/* 보이는 그리드명 — SCREEN_TITLE과 title prop 동일 */}
          <b>{title}</b>
          {!isHistory ? (
            <div className="flex flex-wrap items-center gap-2">
              {screenCode === "user-management" && (canWrite || canModify) ? (
                <>
                  <input
                    // 서명 이미지 선택 — 숨김 input
                    ref={signFileRef}
                    type="file"
                    accept="image/png,image/jpeg,image/gif,image/webp"
                    className="hidden"
                    onChange={(event) => handleSignUpload(event.target.files?.[0] ?? null)}
                  />
                  <MesButton
                    // 활성 사용자 서명 업로드
                    variant="secondary"
                    disabled={asyncAct.isBusy("sign") || !activeKey}
                    loading={asyncAct.isBusy("sign")}
                    onClick={() => signFileRef.current?.click()}
                  >
                    서명 업로드
                  </MesButton>
                </>
              ) : null}
              <GridCrudButtons
                // useAsyncAction.run — save/del busy 키 래핑
                run={asyncAct.run}
                // 신규 행 추가 — 등록 권한 있을 때만
                onAdd={canWrite ? handleAdd : undefined}
                // 변경행 일괄 저장
                onSave={canWrite || canModify ? handleSave : undefined}
                // validate-delete 후 삭제
                onDel={canDelete ? handleDelete : undefined}
                // 버튼별 busy
                busy={{
                  save: asyncAct.isBusy("save"),
                  del: asyncAct.isBusy("del"),
                }}
                // mes-web과 동일 라벨
                addLabel="행추가"
              />
            </div>
          ) : null}
        </div>
        <MesEditableGrid
          // 열 설정 저장 키 — 화면코드별 분리
          persistId={`sys-${screenCode}`}
          // 조회·편집 행 목록
          rows={g.rows as EditableRow<SysRow>[]}
          // 화면별 고정 컬럼 정의
          columns={columns}
          // 이력은 잠금, 관리 화면은 권한에 따라 편집
          editable={!isHistory && (canWrite || canModify)}
          // 그리드 제목 — 패널 헤더와 동일
          title={title}
          // 패널 높이를 채운다
          height="100%"
          // 조회·저장·삭제 busy 오버레이
          loading={asyncAct.isBusy("search") || asyncAct.isBusy("save") || asyncAct.isBusy("del")}
          // 활성 행 키
          activeKey={activeKey}
          // 행 활성화
          onActivate={(row) => setActiveKey(row._key)}
          // 셀 변경 추적
          onCellChange={(key, field, value) => g.updateCell(key, field as keyof SysRow, value)}
          // newOnly·읽기전용 접근 판정
          access={grid.access}
          // 잠금 셀 안내
          onLockedAttempt={grid.onLockedAttempt}
          // 관리 화면만 다중 선택 삭제
          selectable={!isHistory}
          onSelectionChange={(rows) => setSelKeys(rows.map((row) => row._key))}
          selectionResetKey={selReset}
          showRowNum
        />
      </section>
    </div>
  );
}
