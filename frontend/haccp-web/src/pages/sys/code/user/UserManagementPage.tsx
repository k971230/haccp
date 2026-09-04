/**
 * UserManagementPage — 사용자 관리 MesEditableGrid 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 인라인 편집 그리드로 변경행만 저장한다 — 권한그룹·부서는 룩업, 서명은 서명 모달
 *   2) 사용자ID·사용자명·사용여부는 전건 조회 후 FE 필터한다(사용 기본 Y)
 *   3) 부서는 선택이므로 룩업에 (없음) 행을 넣고, 필수 검사는 REQUIRED_FIELDS(ID·명·권한그룹)만 본다
 *
 * PIPELINE[HF99] 사용자 관리 그리드 화면
 * PIPELINE[HF92, HF96, HF97, HF98] 연관 모듈
 */
// 역할 — 상태·메모·초기 조회
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
// 역할 — 페이지 루트·검색·그리드 패널
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
import { mesConfirmDanger, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
// 역할 — 셸 상단·단축키 CRUD 명령 등록
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — 저장 가드
import { runGridSave, stripRowMeta } from "@/shell/gridRules";
// 역할 — 선택행 우선 삭제 대상
import { resolveRowsForDelete } from "@/shell/resolveDelete";
// 역할 — 편집 행 타입
import type { EditableRow } from "@/types/editable";
// 역할 — 전역 공통 모달 열기(코드 룩업·서명)
import { useModalStore } from "@/stores/modalStore";
// 역할 — 사용자 도메인 API
import {
  deleteUsers,
  listUsers,
  saveUsers,
  validateDeleteUsers,
} from "@/api/sys/userApi";
// 역할 — 권한그룹·부서 룩업 후보
import { listRoles } from "@/api/sys/roleApi";
import { listDepartments } from "@/api/sys/departmentApi";
import type { SysRow } from "@/api/sys/sysTypes";
// 역할 — 사용여부 Y/N 공용 옵션
import { DEFAULT_USE_YN, ynMap, ynOptions } from "@/lib/yn";
// 역할 — 화면 규칙(컬럼·잠금·초기값·필수항목)
import {
  NON_EDITABLE_FIELDS,
  PERSIST_ID,
  REQUIRED_FIELDS,
  SCRN_CD,
  USER_RULES,
  buildUserColumns,
  matchUser,
  newUserRow,
  type UserRow,
} from "./UserManagementRule";

/** 코드 룩업 1건 — 권한그룹·부서 공통 */
type CodeOpt = { value: string; label: string };

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 사용자 관리 그리드를 렌더링한다
 *   2) user-management 화면에서 마운트한다
 *   3) ProcessPage와 같은 useEditableRows·선택삭제·잠금 흐름을 따른다
 */
export default function UserManagementPage() {
  const canWrite = useAuthStore((state) => state.can(SCRN_CD, "write"));
  const canModify = useAuthStore((state) => state.can(SCRN_CD, "modify"));
  const canDelete = useAuthStore((state) => state.can(SCRN_CD, "delete"));
  const openModal = useModalStore((s) => s.openModal);
  const asyncAct = useAsyncAction();
  // 검색 — 사용자ID·사용자명·사용여부(기본 Y)
  const [qUserId, setQUserId] = useState("");
  const [qUserNm, setQUserNm] = useState("");
  const [qUseYn, setQUseYn] = useState<string>(DEFAULT_USE_YN);
  const ynOpts = useMemo(() => ynOptions(), []);
  const ynLabels = useMemo(() => ynMap(), []);
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  // 룩업 후보 — 사용중(Y)인 권한그룹·부서만
  const [roleOptions, setRoleOptions] = useState<CodeOpt[]>([]);
  const [deptOptions, setDeptOptions] = useState<CodeOpt[]>([]);
  const clearSel = () => { setSelKeys([]); setSelReset((n) => n + 1); };

  const g = useEditableRows<UserRow>("idx");
  const grid = useGridAccess(USER_RULES, {
    scrnCd: SCRN_CD,
    gridRole: "single",
    readOnly: !canModify,
    extra: { canWrite, canModify, canDelete },
  });

  const load = useCallback(async () => {
    try {
      // 전건 조회 후 FE 필터 — 헤더 3개 조건이 서로 조합된다
      const rows = await listUsers();
      const next: UserRow[] = rows
        .map((row) => ({
          ...row,
          userPw: "",
          // 서명 등록 여부 — SP가 내려준 signYn을 그대로 표시열로 쓴다
          _hasSign: String(row.signYn ?? "").trim().toUpperCase() === "Y" ? "Y" : "N",
        }))
        .filter((row) => matchUser(row, qUserId, qUserNm, qUseYn));
      g.load(next);
      setActiveKey(null);
      clearSel();
    } catch (error) {
      mesError(error);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- g.load 안정 참조
  }, [qUserId, qUserNm, qUseYn]);

  const openSign = useCallback((row: UserRow) => {
    const userId = String(row.userId ?? "").trim();
    if (!userId) {
      mesToast("사용자를 선택하세요.", "warn");
      return;
    }
    // 신규 미저장 행일 때(= 서명 API 대상 없음) 안내 후 모달 미오픈
    if (row._rowState === "C") {
      mesToast("서명은 사용자를 저장한 뒤에 등록할 수 있습니다.", "warn");
      return;
    }
    openModal("UserSign", {
      userId,
      hasSign: row._hasSign === "Y",
      // 업로드·삭제 후 목록 재조회 — 서명 표시열 갱신
      onUploaded: () => { void load(); },
    });
  }, [load, openModal]);

  const openRoleLookup = useCallback((row: UserRow) => {
    if (!row._key) return;
    const rowKey = row._key;
    setActiveKey(rowKey);
    openModal("CodeLookup", {
      title: "권한그룹 선택",
      scrnCd: SCRN_CD,
      options: roleOptions,
      value: String(row.usrgrpCd ?? ""),
      onSelect: (code, label) => {
        // 코드·명 동시 갱신 — 표시열은 Nm, 저장은 Cd
        g.updateCell(rowKey, "usrgrpCd", code);
        g.updateCell(rowKey, "usrgrpNm", label);
      },
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps -- g.updateCell 안정 참조
  }, [openModal, roleOptions]);

  const openDeptLookup = useCallback((row: UserRow) => {
    if (!row._key) return;
    const rowKey = row._key;
    setActiveKey(rowKey);
    openModal("CodeLookup", {
      title: "부서 선택",
      scrnCd: SCRN_CD,
      options: deptOptions,
      value: String(row.deptCd ?? ""),
      // 부서는 선택이므로 (없음) 행으로 빈 코드를 고를 수 있다
      allowEmpty: true,
      onSelect: (code, label) => {
        // 코드·명 동시 갱신 — 표시열은 Nm, 저장은 Cd. (없음)이면 둘 다 빈 문자열
        g.updateCell(rowKey, "deptCd", code);
        g.updateCell(rowKey, "deptNm", label);
      },
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps -- g.updateCell 안정 참조
  }, [deptOptions, openModal]);

  const columns = useMemo(
    () => buildUserColumns(
      canWrite || canModify,
      { onSign: openSign, onRoleLookup: openRoleLookup, onDeptLookup: openDeptLookup },
      ynOpts,
      ynLabels,
    ),
    [canModify, canWrite, openDeptLookup, openRoleLookup, openSign, ynLabels, ynOpts],
  );

  useEffect(() => {
    // 룩업 후보 — 화면 진입 시 한 번만 읽는다
    void (async () => {
      try {
        const [roles, depts] = await Promise.all([listRoles(), listDepartments()]);
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
  }, []);

  /*
   * 최초 한 번만 읽는다.
   *
   * 예전에는 `[load]` 였는데 load 의 의존이 [qUserId, qUserNm, qUseYn] 이라
   * **검색어를 한 글자 칠 때마다** 이 효과가 다시 돌았다. load 는 g.load 로 행을
   * 통째 치환하므로, 사용자를 새로 추가해 두고(저장 전) 이름 칸에 한 글자만 쳐도
   * 그 행이 사라졌다. 덤으로 글자 수만큼 전건 조회가 나갔다.
   *
   * 조회는 조회 버튼(runSearch)이 한다 — 부서관리와 같은 형태다.
   */
  // eslint-disable-next-line react-hooks/exhaustive-deps -- 최초 1회. 이후는 조회 버튼
  useEffect(() => { void load(); }, []);

  const handleAdd = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    // 행추가 시 이전 체크 해제 — 미체크 삭제가 잔여 체크키로 동작하지 않게 함
    clearSel();
    const row = newUserRow();
    // 기본 권한그룹코드(USER)에 맞는 표시명 채움
    const hit = roleOptions.find((o) => o.value === String(row.usrgrpCd));
    if (hit) row.usrgrpNm = hit.label;
    setActiveKey(g.addRow(row));
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-12
   * 코멘트:
   *   1) 변경행만 일괄 저장 API로 저장하고 목록을 다시 읽는다
   *   2) GridCrudButtons·셸 Ctrl+S에서 호출한다
   *   3) 권한 부족·가드 실패는 토스트만 표시한다
   */
  const handleSave = async () => {
    // 순서·문구는 gridSave 가 갖는다 — 이 화면은 필수값과 저장 대상만 준다
    await runGridSave<UserRow>({
      canWrite,
      canModify,
      dirty: g.getSaveRows(),
      rules: grid.rules,
      ctx: grid.ctx,
      columns,
      focusRow: setActiveKey,
      requiredOf: (row) => {
        for (const req of REQUIRED_FIELDS) {
          if (!String(row[req.field] ?? "").trim()) return MES.required(req.label);
        }
        return null;
      },
      // 서명 표시열과 비밀번호·사번·직위는 이 화면이 다루지 않는다.
      // 잠금(lockYn)은 다룬다 — 잠긴 계정을 푸는 유일한 화면이다
      save: (rows) =>
        saveUsers(rows.map((row) => stripRowMeta<SysRow>(row as never, ["_hasSign", ...NON_EDITABLE_FIELDS]))),
      reload: load,
    });
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-12
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
      if (keys.length > 0) await validateDeleteUsers(keys);
      if (!(await mesConfirmDanger(MES.deleteConfirm()))) return;
      if (keys.length > 0) await deleteUsers(keys);
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
            <b>사용자 관리</b>
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
            // 열 설정 저장 키 — 사용자 관리
            persistId={PERSIST_ID}
            // pref 저장용 화면코드
            scrnCd={SCRN_CD}
            // 조회·편집 행 목록
            rows={g.rows as EditableRow<UserRow>[]}
            // 고정 컬럼 정의 — Rule이 만든다
            columns={columns}
            // 권한에 따라 편집
            editable={canWrite || canModify}
            // 그리드 제목 — 패널 헤더와 동일
            title="사용자 관리"
            // 패널 높이를 채운다
            height="100%"
            // 조회·저장·삭제 busy 오버레이
            loading={asyncAct.isBusy("search") || asyncAct.isBusy("save") || asyncAct.isBusy("del")}
            // 활성 행 키
            activeKey={activeKey}
            // 행 활성화
            onActivate={(row) => setActiveKey(row._key)}
            // 셀 변경 추적
            onCellChange={(key, field, value) => g.updateCell(key, field as keyof UserRow, value)}
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
    </div>
  );
}
