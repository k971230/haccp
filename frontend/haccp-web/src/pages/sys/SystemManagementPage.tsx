/**
 * SystemManagementPage — HACCP 시스템 관리 MesEditableGrid 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 사용자·부서·권한·메뉴·공통코드는 인라인 편집 그리드로 변경행만 저장한다
 *   2) 로그인·통계·감사 로그는 LogManagementPage로 분리한다
 *   3) ProcessPage와 같은 useEditableRows·선택삭제·newOnly 잠금 흐름을 따른다
 *
 * PIPELINE[HF99] 시스템 관리 그리드 화면
 * PIPELINE[HF92, HF96, HF97, HF98] 연관 모듈
 */
// 역할 — 상태·메모·초기 조회·파일 입력 참조
import { useCallback, useEffect, useMemo, useState } from "react";
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
// 역할 — 페이지 루트·검색·그리드 패널 (부서·메뉴와 동일 검색 헤더 높이)
import { PageCard, PageCardPanel } from "@/components/layout/PageCard";
import {
  SearchArea,
  SearchButton,
  SearchField,
  SearchSelect,
} from "@/components/layout/SearchArea";
import { pageRootClass } from "@/components/layout/pageClasses";
import { treePanelHeadClass } from "@/components/layout/TreePanelSearch";
import { searchInputClass } from "@/components/ui/Input";
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
  validateDeleteSystemRows,
  type SystemRow,
} from "@/api/systemApi";
// 역할 — 사용여부 Y/N 공용 옵션
import { DEFAULT_USE_YN, ynMap, ynOptions } from "@/lib/yn";
// 역할 — 화면별 잠금 규칙
import { SYSTEM_GRID_RULES, type SystemManageScreenCode } from "./SystemManagementPage.rules";
// 역할 — 사용자 서명 미리보기·업로드 팝업
import { UserSignDialog } from "./UserSignDialog";
import { CodeLookupDialog } from "./CodeLookupDialog";

const SCREEN_TITLE: Record<SystemManageScreenCode, string> = {
  "user-management": "사용자 관리",
  "department-management": "부서 관리",
  "role-management": "권한그룹 관리",
  "menu-management": "메뉴 관리",
  "common-code-management": "공통코드 관리",
};

type CodeOpt = { value: string; label: string };

type BuildColumnOpts = {
  roleOptions?: CodeOpt[];
  deptOptions?: CodeOpt[];
  onSign?: (row: SysRow) => void;
  // 권한그룹 코드 팝업
  onRoleLookup?: (row: SysRow) => void;
  // 부서 코드 팝업
  onDeptLookup?: (row: SysRow) => void;
};

type SysRow = SystemRow & { idx?: number | null; _key?: string; _hasSign?: string };

function todayYmd(): string {
  return new Date().toISOString().slice(0, 10).replace(/-/g, "");
}

/** 화면별 고정 컬럼 — 동적 Object.keys 목록을 쓰지 않는다 */
function buildColumns(
  screenCode: SystemManageScreenCode,
  editable: boolean,
  opts: BuildColumnOpts = {},
): GridColumn<SysRow>[] {
  const ynOpts = ynOptions();
  const ynLabels = ynMap();
  const ynCol = (field: keyof SysRow & string, header: string): GridColumn<SysRow> => ({
    field, header, width: 80, type: "code", editable, codeOptions: ynOpts, codeMap: ynLabels,
  });
  switch (screenCode) {
    case "user-management":
      return [
        { field: "userId", header: "사용자 ID", width: 110, required: true, editableOnNew: true },
        { field: "userNm", header: "사용자명", width: 110, editable, required: true },
        {
          // 권한그룹코드 — 기본 숨김, 「열」메뉴로 표시·pref 저장
          field: "usrgrpCd",
          header: "권한그룹코드",
          width: 100,
          defaultHidden: true,
          editable: false,
        },
        {
          // 권한그룹명 — 표시 + 룩업 박스 (필수)
          field: "usrgrpNm",
          header: "권한그룹",
          width: 140,
          editable: false,
          required: true,
          cellButton: editable
            ? {
              title: "권한그룹",
              onClick: (row) => opts.onRoleLookup?.(row),
            }
            : undefined,
        },
        {
          // 부서코드 — 기본 숨김, 「열」메뉴로 표시·pref 저장
          field: "deptCd",
          header: "부서코드",
          width: 100,
          defaultHidden: true,
          editable: false,
        },
        {
          // 부서명 — 표시 + 룩업 박스 (필수)
          field: "deptNm",
          header: "부서",
          width: 140,
          editable: false,
          required: true,
          cellButton: editable
            ? {
              title: "부서",
              onClick: (row) => opts.onDeptLookup?.(row),
            }
            : undefined,
        },
        { field: "email", header: "이메일", width: 160, editable, inputMode: "email" },
        { field: "mobile", header: "휴대폰", width: 120, editable, inputMode: "tel" },
        {
          // 서명 등록 여부 + 셀 버튼 팝업
          field: "_hasSign",
          header: "서명",
          width: 90,
          editable: false,
          type: "code",
          codeOptions: [{ value: "Y", label: "등록" }, { value: "N", label: "미등록" }],
          codeMap: { Y: "등록", N: "미등록" },
          cellButton: {
            title: "서명",
            onClick: (row) => opts.onSign?.(row),
          },
        },
        ynCol("useYn", "사용여부"),
      ];
    case "department-management":
      return [
        { field: "deptCd", header: "부서코드", width: 100, required: true, editableOnNew: true },
        { field: "deptNm", header: "부서명", width: 140, editable, required: true },
        { field: "hDeptCd", header: "상위부서", width: 100, editable },
        { field: "sortNo", header: "정렬", width: 70, type: "number", editable },
        ynCol("useYn", "사용여부"),
      ];
    case "role-management":
      return [
        { field: "usrgrpCd", header: "권한그룹코드", width: 120, required: true, editableOnNew: true },
        { field: "usrgrpNm", header: "권한그룹명", width: 140, editable, required: true },
        { field: "descRmk", header: "설명", width: 200, editable },
        ynCol("useYn", "사용여부"),
      ];
    case "menu-management":
      return [
        // 대·중·소 — 트리 산출 표시열. 편집 불가. 대분류는 필수 표시
        { field: "grpANm", header: "대분류", width: 120, editable: false, required: true },
        { field: "grpBNm", header: "중분류", width: 120, editable: false },
        { field: "grpCNm", header: "소분류", width: 140, editable: false },
        // 메뉴코드 — 필수·수정 불가
        { field: "menuCd", header: "메뉴코드", width: 140, editable: false, required: true },
        // 메뉴명 — 수정 가능·필수
        { field: "menuNm", header: "메뉴명", width: 160, editable, required: true },
        // 상위·화면·정렬 — 수정 불가
        { field: "hMenuCd", header: "상위메뉴", width: 120, editable: false },
        { field: "scrnCd", header: "화면코드", width: 160, editable: false },
        { field: "sortNo", header: "정렬코드", width: 80, type: "number", editable: false },
        // 사용여부 — 수정 가능·필수
        { ...ynCol("useYn", "사용여부"), required: true },
      ];
    case "common-code-management":
      return [
        { field: "mainCd", header: "대분류", width: 110, required: true, editableOnNew: true },
        { field: "subCd", header: "세부코드", width: 110, required: true, editableOnNew: true },
        { field: "codeNm", header: "코드명", width: 160, editable, required: true },
        { field: "sortNo", header: "정렬", width: 70, type: "number", editable },
        { field: "ref1", header: "참조1", width: 100, editable },
        { field: "ref2", header: "참조2", width: 100, editable },
        ynCol("useYn", "사용여부"),
      ];
  }
}

function defaultRow(screenCode: SystemManageScreenCode): SysRow {
  switch (screenCode) {
    case "user-management":
      return { userId: "", userNm: "", usrgrpCd: "USER", useYn: DEFAULT_USE_YN, _hasSign: "N" };
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

function requiredFields(screenCode: SystemManageScreenCode): Array<{ field: keyof SysRow & string; label: string }> {
  switch (screenCode) {
    case "user-management": return [
      { field: "userId", label: "사용자 ID" },
      { field: "userNm", label: "사용자명" },
      { field: "usrgrpCd", label: "권한그룹" },
      { field: "deptCd", label: "부서" },
    ];
    case "department-management": return [{ field: "deptCd", label: "부서코드" }, { field: "deptNm", label: "부서명" }];
    case "role-management": return [{ field: "usrgrpCd", label: "권한그룹코드" }, { field: "usrgrpNm", label: "권한그룹명" }];
    case "menu-management": return [
      { field: "grpANm", label: "대분류" },
      { field: "menuCd", label: "메뉴코드" },
      { field: "menuNm", label: "메뉴명" },
      { field: "useYn", label: "사용" },
    ];
    case "common-code-management": return [
      { field: "mainCd", label: "대분류" }, { field: "subCd", label: "세부코드" }, { field: "codeNm", label: "코드명" },
    ];
    default: return [];
  }
}

interface SystemManagementPageProps {
  screenCode: SystemManageScreenCode;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 사용자 관리 그리드를 렌더링한다 (로그 3화면은 LogManagementPage)
 *   2) 사용자ID·사용자명·사용여부 검색을 제공한다
 *   3) ProcessPage와 같은 useEditableRows·선택삭제·잠금 흐름을 따른다
 */
export default function SystemManagementPage({ screenCode }: SystemManagementPageProps) {
  const title = SCREEN_TITLE[screenCode];
  const isUser = screenCode === "user-management";
  const canWrite = useAuthStore((state) => state.can(screenCode, "write"));
  const canModify = useAuthStore((state) => state.can(screenCode, "modify"));
  const canDelete = useAuthStore((state) => state.can(screenCode, "delete"));
  const asyncAct = useAsyncAction();
  // 사용자관리 전용 검색 — 사용자ID·사용자명·사용여부(기본 Y)
  const [qUserId, setQUserId] = useState("");
  const [qUserNm, setQUserNm] = useState("");
  const [qUseYn, setQUseYn] = useState<string>(DEFAULT_USE_YN);
  const ynOpts = useMemo(() => ynOptions(), []);
  const fromDt = todayYmd();
  const toDt = todayYmd();
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  // 사용자 관리 — 권한·부서 콤보
  const [roleOptions, setRoleOptions] = useState<CodeOpt[]>([]);
  const [deptOptions, setDeptOptions] = useState<CodeOpt[]>([]);
  // 서명 팝업 — 저장된 사용자만
  const [signUser, setSignUser] = useState<{ userId: string; signPath?: string | null } | null>(null);
  // 권한그룹·부서 코드 팝업
  const [codeLookup, setCodeLookup] = useState<{
    kind: "role" | "dept";
    rowKey: string;
    value: string;
  } | null>(null);
  const clearSel = () => { setSelKeys([]); setSelReset((n) => n + 1); };

  const g = useEditableRows<SysRow>("idx");
  const rules = SYSTEM_GRID_RULES[screenCode];
  const grid = useGridAccess(rules, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify,
    extra: { canWrite, canModify, canDelete },
  });

  const openSign = useCallback((row: SysRow) => {
    const userId = String(row.userId ?? "").trim();
    if (!userId) {
      mesToast("사용자를 선택하세요.", "warn");
      return;
    }
    // 신규 미저장 행일 때(= 서명 API 대상 없음) 안내 후 팝업 미오픈
    if (row._rowState === "C") {
      mesToast("서명은 사용자를 저장한 뒤에 등록할 수 있습니다.", "warn");
      return;
    }
    setSignUser({ userId, signPath: String(row.signPath ?? "") });
  }, []);

  const openRoleLookup = useCallback((row: SysRow) => {
    if (!row._key) return;
    setActiveKey(row._key);
    setCodeLookup({
      kind: "role",
      rowKey: row._key,
      value: String(row.usrgrpCd ?? ""),
    });
  }, []);

  const openDeptLookup = useCallback((row: SysRow) => {
    if (!row._key) return;
    setActiveKey(row._key);
    setCodeLookup({
      kind: "dept",
      rowKey: row._key,
      value: String(row.deptCd ?? ""),
    });
  }, []);

  const columns = useMemo(
    () => buildColumns(screenCode, canWrite || canModify, {
      roleOptions,
      deptOptions,
      onSign: openSign,
      onRoleLookup: openRoleLookup,
      onDeptLookup: openDeptLookup,
    }),
    [
      canModify,
      canWrite,
      deptOptions,
      openDeptLookup,
      openRoleLookup,
      openSign,
      roleOptions,
      screenCode,
    ],
  );

  useEffect(() => {
    if (screenCode !== "user-management") return;
    void (async () => {
      try {
        const [roles, depts] = await Promise.all([
          listSystemRows("role-management", { keyword: "" }),
          listSystemRows("department-management", { keyword: "" }),
        ]);
        setRoleOptions(
          roles
            .filter((r) => String(r.useYn ?? "Y").toUpperCase() === "Y")
            .map((r) => ({
              value: String(r.usrgrpCd ?? ""),
              label: String(r.usrgrpNm ?? r.usrgrpCd ?? ""),
            }))
            .filter((o) => o.value),
        );
        setDeptOptions(
          depts
            .filter((r) => String(r.useYn ?? "Y").toUpperCase() === "Y")
            .map((r) => ({
              value: String(r.deptCd ?? ""),
              label: String(r.deptNm ?? r.deptCd ?? ""),
            }))
            .filter((o) => o.value),
        );
      } catch (error) {
        mesError(error);
      }
    })();
  }, [screenCode]);

  const load = useCallback(async () => {
    try {
      // 사용자는 전체 조회 후 FE 필터
      const rows = await listSystemRows(screenCode, { keyword: "", fromDt, toDt });
      let next: SysRow[] = rows.map((row) => ({
        ...row,
        userPw: "",
        _hasSign: String(row.signPath ?? "").trim() ? "Y" : "N",
      }));
      if (isUser) {
        const idQ = qUserId.trim().toLowerCase();
        const nmQ = qUserNm.trim().toLowerCase();
        const useQ = qUseYn.trim().toUpperCase();
        next = next.filter((row) => {
          if (idQ && !String(row.userId ?? "").toLowerCase().includes(idQ)) return false;
          if (nmQ && !String(row.userNm ?? "").toLowerCase().includes(nmQ)) return false;
          // 사용여부 — 전체("")가 아니면 Y/N 일치만 (기본 Y)
          if (useQ && String(row.useYn ?? "").toUpperCase() !== useQ) return false;
          return true;
        });
      }
      g.load(next);
      setActiveKey(null);
      clearSel();
    } catch (error) {
      mesError(error);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- g.load 안정 참조
  }, [fromDt, isUser, qUserId, qUserNm, qUseYn, screenCode, toDt]);

  useEffect(() => { void load(); }, [load]);

  const handleAdd = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    // 행추가 시 이전 체크 해제 — 미체크 삭제가 잔여 체크키로 동작하지 않게 함
    clearSel();
    const row = defaultRow(screenCode);
    // 사용자 기본 권한그룹코드(USER)에 맞는 표시명 채움
    if (screenCode === "user-management" && row.usrgrpCd) {
      const hit = roleOptions.find((o) => o.value === String(row.usrgrpCd));
      if (hit) row.usrgrpNm = hit.label;
    }
    setActiveKey(g.addRow(row));
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 변경행만 일괄 저장 API로 저장하고 목록을 다시 읽는다
   *   2) GridCrudButtons·셸 Ctrl+S에서 호출한다
   *   3) 권한 부족·가드 실패는 토스트만 표시한다
   */
  const handleSave = async () => {
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
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      const payload = dirty.map((row) => {
        const next: SystemRow = { ...row };
        delete (next as { _key?: string })._key;
        delete (next as { _rowState?: string })._rowState;
        delete (next as { _original?: unknown })._original;
        delete (next as { _hasSign?: string })._hasSign;
        // 대·중·소 표시열 — 저장 payload에서 제외
        delete next.grpANm;
        delete next.grpBNm;
        delete next.grpCNm;
        delete next.levelNm;
        // 비밀번호·사번·직위·잠금은 화면에서 다루지 않음
        if (screenCode === "user-management") {
          delete next.userPw;
          delete next.empCd;
          delete next.posCd;
          delete next.lockYn;
        }
        return next;
      });
      await saveSystemRows(screenCode, payload);
      mesToast(MES.saveDone, "success");
      await load();
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 선택행 우선 삭제 — validate-delete·확인·delete·재조회
   *   2) GridCrudButtons·셸 삭제 단축키에서 호출한다
   *   3) 참조 차단은 업무 토스트로만 안내한다
   */
  const handleDelete = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    // selectable — 체크된 행만 (activeKey·행추가 포커스만으로는 삭제 안 함)
    const targets = resolveRowsForDelete(g.rows, activeKey, setActiveKey, selKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");

    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    const keys = persisted
      .map((row) => Number(row.idx))
      .filter((idx) => Number.isFinite(idx) && idx > 0)
      .map((idx) => ({ idx }));
    if (keys.length === 0 && newRows.length === 0) {
      return mesToast(MES.selectRow, "warn");
    }
    try {
      if (keys.length > 0) await validateDeleteSystemRows(screenCode, keys);
      if (!(await mesConfirm(MES.deleteConfirm()))) return;
      if (keys.length > 0) await deleteSystemRows(screenCode, keys);
      let lastFocus = activeKey;
      for (const row of newRows) {
        const { focusKey } = g.removeNewRow(row._key);
        lastFocus = focusKey;
      }
      setActiveKey(lastFocus);
      clearSel();
      mesToast(MES.deleteDone, "success");
      if (keys.length > 0) await load();
    } catch (error) {
      mesError(error);
    }
  };

  const runSearch = useCallback(() => {
    void asyncAct.run(load, "search");
  }, [asyncAct, load]);

  usePageCommands({
    search: runSearch,
    add: handleAdd,
    save: () => { void asyncAct.run(handleSave, "save"); },
    del: () => { void asyncAct.run(handleDelete, "del"); },
  });

  return (
    <div className={pageRootClass}>
      <PageCard
        search={
          <SearchArea
            onSearch={runSearch}
            actions={<SearchButton loading={asyncAct.isBusy("search")} />}
          >
            <SearchField label="사용자 ID">
              <input
                // 사용자ID 부분검색
                className={searchInputClass}
                value={qUserId}
                onChange={(e) => setQUserId(e.target.value)}
                placeholder="사용자 ID"
              />
            </SearchField>
            <SearchField label="사용자명">
              <input
                // 사용자명 부분검색
                className={searchInputClass}
                value={qUserNm}
                onChange={(e) => setQUserNm(e.target.value)}
                placeholder="사용자명"
              />
            </SearchField>
            <SearchSelect
              // 사용여부 — 기본 Y, 빈값=전체
              label="사용여부"
              value={qUseYn}
              onChange={setQUseYn}
            >
              <option value="">전체</option>
              {ynOpts.map((o) => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </SearchSelect>
          </SearchArea>
        }
      >
        <PageCardPanel className="p-2">
          <div className={treePanelHeadClass}>
            <b>{title}</b>
            <GridCrudButtons
              // useAsyncAction.run — save/del busy 키 래핑
              run={asyncAct.run}
              // 신규 행 추가
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
          <MesEditableGrid
            // 열 설정 저장 키 — 화면코드별 분리
            // v2 — 코드열 defaultHidden·명 표시열 전환 후 구 pref 무효화
            persistId={screenCode === "user-management" ? "sys-user-management-v2" : `sys-${screenCode}`}
            // 조회·편집 행 목록
            rows={g.rows as EditableRow<SysRow>[]}
            // 화면별 고정 컬럼 정의
            columns={columns}
            // 권한에 따라 편집
            editable={canWrite || canModify}
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
            // 다중 선택 삭제
            selectable
            onSelectionChange={(rows) => setSelKeys(rows.map((row) => row._key))}
            selectionResetKey={selReset}
            showRowNum
          />
        </PageCardPanel>
      </PageCard>

      {screenCode === "user-management" && signUser ? (
        <UserSignDialog
          // 서명 팝업 표시
          open
          // 대상 사용자 ID
          userId={signUser.userId}
          // 기존 서명 경로 — 있으면 미리보기
          signPath={signUser.signPath}
          // 닫기
          onClose={() => setSignUser(null)}
          // 업로드 후 목록 재조회
          onUploaded={() => { void load(); }}
        />
      ) : null}

      {screenCode === "user-management" && codeLookup ? (
        <CodeLookupDialog
          // 권한그룹·부서 코드 선택
          open
          title={codeLookup.kind === "role" ? "권한그룹 선택" : "부서 선택"}
          // pref 저장용 화면코드
          scrnCd={screenCode}
          options={codeLookup.kind === "role" ? roleOptions : deptOptions}
          value={codeLookup.value}
          onClose={() => setCodeLookup(null)}
          onSelect={(code, label) => {
            // 코드·명 동시 갱신 — 표시열은 Nm, 저장은 Cd
            if (codeLookup.kind === "role") {
              g.updateCell(codeLookup.rowKey, "usrgrpCd", code);
              g.updateCell(codeLookup.rowKey, "usrgrpNm", label);
            } else {
              g.updateCell(codeLookup.rowKey, "deptCd", code);
              g.updateCell(codeLookup.rowKey, "deptNm", label);
            }
            setCodeLookup(null);
          }}
        />
      ) : null}
    </div>
  );
}
