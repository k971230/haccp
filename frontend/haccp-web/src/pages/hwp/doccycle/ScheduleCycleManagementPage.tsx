/**
 * ScheduleCycleManagementPage — 문서주기관리 (좌 양식 목록 30% · 우 주기 설정 70%).
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 좌측은 조회 전용이다 — 양식 등록·삭제는 사용양식 관리 몫이고 이 화면은 주기만 다룬다
 *   2) 양식 1개 = 주기 0..1건이라 우측은 그리드가 아닌 단일 폼이며 저장은 업서트다
 *   3) 반복설정은 주기 콤보에 따라 영역만 바뀐다 — 매일은 없음, 매주는 요일, 매월은 실행일·말일, 분기·반기·매년은 월+일
 *
 * PIPELINE[HF89] 문서주기관리 화면
 * PIPELINE[HF123, HF124] 연관 모듈
 *
 * 주기 상수·날짜 변환·details 펼치기·좌측 컬럼은 ScheduleCycleManagementRule이 갖고 이 파일은 렌더·상태·API만 담당한다
 */
// 역할 — 상태·메모·초기 조회
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 화면별 쓰기·수정·삭제 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 비동기 중복 실행 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — 공통코드 CYCLE_CD·nonwork-rule 콤보
import { useCommonCodes } from "@/hooks/useCommonCodes";
// 역할 — 조회 전용 그리드
import { MesDataGrid } from "@/components/grid/MesDataGrid";
// 역할 — 표준 버튼·입력 스타일
import { MesButton } from "@/components/ui/MesButton";
import { searchInputClass } from "@/components/ui/Input";
// 역할 — 페이지 카드·검색 영역·좌우 분할
import { PageCard } from "@/components/layout/PageCard";
import { PageHead, SearchArea, SearchButton, SearchField } from "@/components/layout/SearchArea";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import { gridHeadClass, gridPanelClass, pageRootClass } from "@/components/layout/pageClasses";
// 역할 — 담당부서·담당자 선택 공통 팝업
import { useModalStore } from "@/stores/modalStore";
// 역할 — 업무 확인·토스트·오류 안내
import { mesConfirm, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
// 역할 — 상단 공통 버튼(조회·저장·삭제) 연결
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — 미저장 변경 탭 이동 경고
import { useRegisterPageDirty } from "@/shell/pageDirtyRegistry";
// 역할 — 문서주기 조회·저장·삭제 API
import {
  deleteDocCycles,
  getDocCycle,
  listDocCycleForms,
  saveDocCycle,
  validateDeleteDocCycles,
  type DocCycleFormRow,
} from "@/api/hwp/docCycleApi";
// 역할 — 담당부서·담당자 후보 목록 (신규 조회 API를 만들지 않고 sys 목록을 재사용한다)
import { listDepartments } from "@/api/sys/departmentApi";
import { listUsers } from "@/api/sys/userApi";
// 역할 — 양식 구분 라벨 정본 (사용양식 관리와 동일 문구)
import { FORM_TYPE_LABEL, isCompanyForm } from "../formType";
// 역할 — 화면 규칙(주기 상수·변환·좌측 컬럼·pref 키)
import {
  CYCLE_FALLBACK,
  HALF_MONTHS,
  NONWORK_FALLBACK,
  PERSIST_ID,
  QUARTER_MONTHS,
  SCRN_CD,
  SPLIT_KEY,
  WEEK_DAYS,
  buildFormColumns,
  detailsToForm,
  emptyForm,
  formToDetails,
  hhmmToInput,
  inputToHhmm,
  inputToYmd,
  ymdToInput,
  type CycleForm,
} from "./ScheduleCycleManagementRule";

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 좌측 사용양식 목록과 우측 주기 폼을 30:70으로 제공한다
 *   2) 일지설정「문서주기관리」(schedule-cycle-management)에서 연다
 *   3) 권한·검증 실패는 업무 토스트로만 안내한다
 */
export default function ScheduleCycleManagementPage() {
  const canWrite = useAuthStore((state) => state.can(SCRN_CD, "write"));
  const canModify = useAuthStore((state) => state.can(SCRN_CD, "modify"));
  const canDeleteAuth = useAuthStore((state) => state.can(SCRN_CD, "delete"));
  const canEdit = canWrite || canModify;
  const asyncAct = useAsyncAction();
  const openModal = useModalStore((state) => state.openModal);
  const cycleCodes = useCommonCodes("CYCLE_CD");
  const nonworkCodes = useCommonCodes("nonwork-rule");

  // 검색 조건 — 양식코드·양식명 부분검색(서버 LIKE)
  const [qTmplCd, setQTmplCd] = useState("");
  const [qTmplNm, setQTmplNm] = useState("");
  const searchRef = useRef({ qTmplCd, qTmplNm });
  searchRef.current = { qTmplCd, qTmplNm };

  const [forms, setForms] = useState<DocCycleFormRow[]>([]);
  const [activeTmplCd, setActiveTmplCd] = useState<string | null>(null);
  const [form, setForm] = useState<CycleForm>(emptyForm);
  // 서버에서 읽은 마지막 값 — 미저장 변경 판정 기준
  const [snapshot, setSnapshot] = useState<string>(JSON.stringify(emptyForm()));
  // 선택 양식에 저장된 주기가 있는지 — 삭제 버튼 활성 판정
  const [hasRule, setHasRule] = useState(false);
  const [listLoading, setListLoading] = useState(false);

  // 담당부서·담당자 후보 — 팝업 목록으로만 쓰며 저장은 코드·ID로 한다
  const [deptOptions, setDeptOptions] = useState<{ value: string; label: string }[]>([]);
  const [userRows, setUserRows] = useState<{ userId: string; userNm: string; deptCd: string; deptNm: string }[]>([]);

  const dirty = useMemo(() => JSON.stringify(form) !== snapshot, [form, snapshot]);
  const dirtyRef = useRef(dirty);
  dirtyRef.current = dirty;
  useRegisterPageDirty(useCallback(() => dirtyRef.current, []));

  const cycleOptions = useMemo(
    () => (cycleCodes.codes.length
      // 수시(E)는 예정일을 만들 수 없어 이 화면 콤보에서 제외한다
      ? cycleCodes.codes.filter((code) => code.subCd !== "E").map((code) => ({ value: code.subCd, label: code.codeNm }))
      : CYCLE_FALLBACK.map((opt) => ({ value: opt.value, label: opt.label }))),
    [cycleCodes.codes],
  );
  const cycleLabels = useMemo(
    () => Object.fromEntries(cycleOptions.map((opt) => [opt.value, opt.label])),
    [cycleOptions],
  );
  const nonworkOptions = useMemo(
    () => (nonworkCodes.codes.length
      ? nonworkCodes.codes.map((code) => ({ value: code.subCd, label: code.codeNm }))
      : NONWORK_FALLBACK.map((opt) => ({ value: opt.value, label: opt.label }))),
    [nonworkCodes.codes],
  );

  const formColumns = useMemo(
    () => buildFormColumns(cycleLabels),
    [cycleLabels],
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 사용 중 양식 목록을 서버 검색으로 읽는다
   *   2) 진입·조회·저장/삭제 후 호출한다
   *   3) 선택 중이던 양식이 목록에 남아 있으면 선택을 유지한다
   */
  const loadForms = useCallback(async () => {
    setListLoading(true);
    try {
      const query = searchRef.current;
      const rows = await listDocCycleForms({
        tmplCd: query.qTmplCd.trim(),
        tmplNm: query.qTmplNm.trim(),
      });
      setForms(rows);
      setActiveTmplCd((prev) => {
        if (prev && rows.some((row) => row.tmplCd === prev)) return prev;
        return rows[0]?.tmplCd ?? null;
      });
    } catch (error) {
      mesError(error);
    } finally {
      setListLoading(false);
    }
  }, []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 선택 양식의 주기를 읽어 우측 폼과 미저장 판정 기준을 함께 갱신한다
   *   2) 좌측 행 선택·저장·삭제 후 호출한다
   *   3) 주기가 없으면 빈 폼(신규 등록)으로 두고 삭제 버튼을 잠근다
   */
  const loadCycle = useCallback(async (tmplCd: string | null) => {
    if (!tmplCd) {
      const blank = emptyForm();
      setForm(blank);
      setSnapshot(JSON.stringify(blank));
      setHasRule(false);
      return;
    }
    try {
      const rule = await getDocCycle(tmplCd);
      const base = emptyForm();
      const next = rule
        ? detailsToForm({
          ...base,
          baseDt: ymdToInput(rule.baseDt) || base.baseDt,
          cycleCd: String(rule.cycleCd ?? base.cycleCd).toUpperCase(),
          nonworkRule: String(rule.nonworkRule ?? "keep").toLowerCase(),
          dueTime: hhmmToInput(rule.dueTime ?? "1800"),
          deptCd: String(rule.deptCd ?? ""),
          deptNm: String(rule.deptNm ?? ""),
          userId: String(rule.userId ?? ""),
          userNm: String(rule.userNm ?? ""),
          useYn: String(rule.useYn ?? "Y").toUpperCase() === "N" ? "N" : "Y",
        }, rule.details)
        : base;
      setForm(next);
      setSnapshot(JSON.stringify(next));
      setHasRule(!!rule);
    } catch (error) {
      mesError(error);
    }
  }, []);

  useEffect(() => {
    void loadForms();
  }, [loadForms]);

  useEffect(() => {
    void loadCycle(activeTmplCd);
  }, [activeTmplCd, loadCycle]);

  // 담당부서·담당자 후보 — 화면 진입 시 1회. 팝업이 열릴 때마다 다시 읽지 않는다
  useEffect(() => {
    void (async () => {
      try {
        const [depts, users] = await Promise.all([listDepartments(), listUsers({ useYn: "Y" })]);
        setDeptOptions(depts
          .filter((row) => String(row.useYn ?? "Y").toUpperCase() === "Y")
          .map((row) => ({ value: String(row.deptCd ?? ""), label: String(row.deptNm ?? row.deptCd ?? "") }))
          .filter((opt) => opt.value));
        setUserRows(users.map((row) => ({
          userId: String(row.userId ?? ""),
          userNm: String(row.userNm ?? row.userId ?? ""),
          deptCd: String(row.deptCd ?? ""),
          deptNm: String(row.deptNm ?? ""),
        })).filter((row) => row.userId));
      } catch (error) {
        mesError(error);
      }
    })();
  }, []);

  const activeForm = useMemo(
    () => forms.find((row) => row.tmplCd === activeTmplCd) ?? null,
    [forms, activeTmplCd],
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 좌측 행을 고른다 — 미저장 변경이 있으면 이동 여부를 먼저 확인한다
   *   2) 그리드 행 클릭에서 호출한다
   *   3) 취소하면 선택을 바꾸지 않아 편집 중 값이 사라지지 않는다
   */
  const handleSelect = async (tmplCd: string) => {
    if (tmplCd === activeTmplCd) return;
    if (dirty && !(await mesConfirm(MES.unsavedLeaveConfirm))) return;
    setActiveTmplCd(tmplCd);
  };

  /** 담당부서 선택 팝업 — 공통 CodeLookup 재사용 */
  const openDeptLookup = () => {
    if (!canEdit) return;
    openModal("CodeLookup", {
      title: "담당부서 선택",
      scrnCd: SCRN_CD,
      options: deptOptions,
      value: form.deptCd,
      // 부서 미지정 주기도 허용한다(담당자만 지정하는 운영이 있다)
      allowEmpty: true,
      onSelect: (code, label) => setForm((prev) => ({ ...prev, deptCd: code, deptNm: label })),
    });
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 담당자 선택 팝업 — 고르면 소속 부서까지 함께 채운다
   *   2) 담당자 「선택」 버튼에서 호출한다
   *   3) 저장은 userId·deptCd로만 하고 이름은 표시 전용이다
   */
  const openUserLookup = () => {
    if (!canEdit) return;
    openModal("CodeLookup", {
      title: "담당자 선택",
      scrnCd: SCRN_CD,
      options: userRows.map((row) => ({
        value: row.userId,
        label: row.deptNm ? `${row.userNm} (${row.deptNm})` : row.userNm,
      })),
      value: form.userId,
      allowEmpty: true,
      onSelect: (code) => {
        const picked = userRows.find((row) => row.userId === code);
        setForm((prev) => ({
          ...prev,
          userId: code,
          userNm: picked?.userNm ?? "",
          // 담당자를 고르면 소속 부서를 같이 반영한다 — 부서만 따로 고칠 수도 있다
          deptCd: picked?.deptCd || prev.deptCd,
          deptNm: picked?.deptNm || prev.deptNm,
        }));
      },
    });
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 주기 1건을 저장한다 — 서버가 예정일까지 다시 만든다
   *   2) 우측 「저장」에서 호출한다
   *   3) 반복설정이 비면 저장 전에 막는다(주기별 필수 항목이 다르다)
   */
  const handleSave = async () => {
    if (!canEdit) {
      mesToast("수정 권한이 없습니다.", "warn");
      return;
    }
    if (!activeTmplCd) {
      mesToast("주기를 설정할 양식을 선택하세요.", "warn");
      return;
    }
    if (!inputToYmd(form.baseDt)) {
      mesToast(MES.required("관리 시작일"), "warn");
      return;
    }
    if (form.cycleCd === "W" && form.weekDays.length === 0) {
      mesToast("반복할 요일을 선택하세요.", "warn");
      return;
    }
    if (form.cycleCd === "M" && form.monthDays.length === 0 && !form.monthEnd) {
      mesToast("실행일 또는 말일을 선택하세요.", "warn");
      return;
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      await saveDocCycle({
        tmplCd: activeTmplCd,
        baseDt: inputToYmd(form.baseDt),
        cycleCd: form.cycleCd,
        nonworkRule: form.nonworkRule,
        dueTime: inputToHhmm(form.dueTime),
        deptCd: form.deptCd || null,
        userId: form.userId || null,
        useYn: form.useYn,
        details: formToDetails(form),
      });
      mesToast(MES.saveDone, "success");
      await loadForms();
      await loadCycle(activeTmplCd);
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 선택 양식의 주기를 삭제한다 — 과거·진행 문서는 남고 미래 예정일만 정리된다
   *   2) 우측 「삭제」에서 호출한다
   *   3) 주기가 없으면 버튼이 비활성이므로 여기서는 키만 확인한다
   */
  const handleDelete = async () => {
    if (!canDeleteAuth) {
      mesToast("삭제 권한이 없습니다.", "warn");
      return;
    }
    if (!activeTmplCd || !hasRule) {
      mesToast("삭제할 문서주기가 없습니다.", "warn");
      return;
    }
    const keys = [{ tmplCd: activeTmplCd }];
    try {
      await validateDeleteDocCycles(keys);
      if (!(await mesConfirm(MES.deleteConfirm(activeForm?.tmplNm ?? activeTmplCd)))) return;
      await deleteDocCycles(keys);
      mesToast(MES.deleteDone, "success");
      await loadForms();
      await loadCycle(activeTmplCd);
    } catch (error) {
      mesError(error);
    }
  };

  const doSearch = () => asyncAct.run(() => loadForms(), "search");

  usePageCommands({
    search: () => { void doSearch(); },
    save: () => { void asyncAct.run(handleSave, "save"); },
    del: () => { void asyncAct.run(handleDelete, "del"); },
  });

  /** 실행일 칩 토글 — 매월 1~31일 다중 선택 */
  const toggleMonthDay = (day: number) => {
    setForm((prev) => ({
      ...prev,
      monthDays: prev.monthDays.includes(day)
        ? prev.monthDays.filter((value) => value !== day)
        : [...prev.monthDays, day].sort((a, b) => a - b),
    }));
  };

  /** 요일 토글 — 매주 다중 선택(ISO 1 월 ~ 7 일) */
  const toggleWeekDay = (day: number) => {
    setForm((prev) => ({
      ...prev,
      weekDays: prev.weekDays.includes(day)
        ? prev.weekDays.filter((value) => value !== day)
        : [...prev.weekDays, day].sort((a, b) => a - b),
    }));
  };

  const chipClass = (on: boolean) =>
    `rounded border px-2 py-1 text-xs ${on
      ? "border-blue-300 bg-blue-50 font-medium text-blue-700"
      : "border-slate-200 bg-white text-slate-600 hover:bg-slate-50"}`;

  const periodMonths = form.cycleCd === "Q"
    ? QUARTER_MONTHS
    : form.cycleCd === "H"
      ? HALF_MONTHS
      : ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] as const);
  const periodMonthLabel = form.cycleCd === "Y" ? "실행월" : "주기 내 실행월";

  return (
    <div className={pageRootClass}>
      <PageHead title="문서주기관리" />
      <PageCard
        search={(
          <SearchArea
            onSearch={() => { void doSearch(); }}
            actions={<SearchButton loading={asyncAct.isBusy("search")} />}
          >
            <SearchField label="양식코드">
              <input
                className={searchInputClass}
                value={qTmplCd}
                onChange={(event) => setQTmplCd(event.target.value)}
                placeholder="tmpl_…"
              />
            </SearchField>
            <SearchField label="양식명">
              <input
                className={searchInputClass}
                value={qTmplNm}
                onChange={(event) => setQTmplNm(event.target.value)}
                placeholder="양식명"
              />
            </SearchField>
          </SearchArea>
        )}
      >
        <ResizableSplit
          // 좌 목록 30% · 우 주기 설정 70%
          orientation="horizontal"
          // 비율 저장 키 — 화면 고유
          storageKey={SPLIT_KEY}
          defaultPrimaryPct={30}
          minPct={20}
          maxPct={55}
          className="mes-page-split min-h-0 h-full flex-1 gap-0"
          primary={(
            <div className={gridPanelClass}>
              <div className={gridHeadClass}>
                <b>사용양식 — 사용 중 양식만</b>
                <span className="ml-auto text-xs text-slate-500">{forms.length}건</span>
              </div>
              <MesDataGrid
                // 열 설정 저장 키 — 문서주기 좌측 목록
                persistId={PERSIST_ID}
                // 화면 권한·pref 범위
                scrnCd={SCRN_CD}
                // 조회 전용 양식 목록
                rows={forms}
                // 양식코드·양식명·구분·주기
                columns={formColumns}
                // 행 키 — 양식코드가 회사 안에서 유일하다
                rowKey="tmplCd"
                // 선택 양식 강조
                activeKey={activeTmplCd}
                // 행 클릭 — 미저장 변경 확인 후 우측 폼 교체
                onRowClick={(row) => { void handleSelect(row.tmplCd); }}
                // 목록 조회 중
                loading={listLoading}
                // 결과 내 검색·열 설정
                showToolbar
                // 건수 푸터는 패널 헤더에 있어 숨긴다
                showFooter={false}
                sortable
                showRowNum
                // 부모 높이 채움
                height="100%"
                title="사용양식"
              />
            </div>
          )}
          secondary={(
            <div className={gridPanelClass}>
              <div className={gridHeadClass}>
                <b>
                  {activeForm ? `${activeForm.tmplNm} 주기설정` : "주기설정"}
                </b>
                {activeForm ? (
                  <span
                    // 구분 badge — 사용양식 관리와 같은 색·문구
                    className={`rounded px-1.5 py-0.5 text-[11px] font-medium ${isCompanyForm(activeForm.formTy)
                      ? "bg-emerald-50 text-emerald-700"
                      : "bg-blue-50 text-blue-700"}`}
                  >
                    {FORM_TYPE_LABEL[isCompanyForm(activeForm.formTy) ? "usr" : "sys"]}
                  </span>
                ) : null}
                {dirty ? (
                  <span className="text-xs text-amber-600">{MES.unsavedChanges}</span>
                ) : null}
                <div className="ml-auto flex gap-2">
                  <MesButton
                    // 주기 업서트 — 저장 후 예정일이 다시 생성된다
                    variant="save"
                    disabled={!canEdit || !activeTmplCd || asyncAct.isBusy("save")}
                    loading={asyncAct.isBusy("save")}
                    onClick={() => void asyncAct.run(handleSave, "save")}
                  >
                    저장
                  </MesButton>
                  <MesButton
                    // 주기 삭제 — 등록된 주기가 있을 때만
                    variant="danger"
                    disabled={!canDeleteAuth || !hasRule || asyncAct.isBusy("del")}
                    loading={asyncAct.isBusy("del")}
                    onClick={() => void asyncAct.run(handleDelete, "del")}
                  >
                    삭제
                  </MesButton>
                </div>
              </div>

              {!activeTmplCd ? (
                <div className="flex flex-1 items-center justify-center text-sm text-slate-500">
                  좌측에서 양식을 선택하세요.
                </div>
              ) : (
                <div className="min-h-0 flex-1 overflow-auto p-4">
                  <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                    <label className="flex flex-col gap-1 text-xs text-slate-600">
                      {/* 관리 시작일 — 이 날짜 이전 예정일은 만들지 않는다 */}
                      관리 시작일
                      <input
                        type="date"
                        className={searchInputClass}
                        value={form.baseDt}
                        disabled={!canEdit}
                        onChange={(event) => setForm((prev) => ({ ...prev, baseDt: event.target.value }))}
                      />
                    </label>
                    <label className="flex flex-col gap-1 text-xs text-slate-600">
                      {/* 주기 — 바꾸면 아래 반복설정 영역이 교체된다 */}
                      주기
                      <select
                        className={searchInputClass}
                        value={form.cycleCd}
                        disabled={!canEdit}
                        onChange={(event) => setForm((prev) => ({ ...prev, cycleCd: event.target.value }))}
                      >
                        {cycleOptions.map((opt) => (
                          <option key={opt.value} value={opt.value}>{opt.label}</option>
                        ))}
                      </select>
                    </label>
                    <label className="flex flex-col gap-1 text-xs text-slate-600">
                      {/* 비영업일 처리 — 토·일에 걸린 예정일 이동 방식 */}
                      비영업일 처리
                      <select
                        className={searchInputClass}
                        value={form.nonworkRule}
                        disabled={!canEdit}
                        onChange={(event) => setForm((prev) => ({ ...prev, nonworkRule: event.target.value }))}
                      >
                        {nonworkOptions.map((opt) => (
                          <option key={opt.value} value={opt.value}>{opt.label}</option>
                        ))}
                      </select>
                    </label>
                    <label className="flex flex-col gap-1 text-xs text-slate-600">
                      {/* 마감시간 — 알림은 이 시각 기준으로 앞당겨 보낸다 */}
                      마감시간
                      <input
                        type="time"
                        className={searchInputClass}
                        value={form.dueTime}
                        disabled={!canEdit}
                        onChange={(event) => setForm((prev) => ({ ...prev, dueTime: event.target.value }))}
                      />
                    </label>
                    <div className="flex flex-col gap-1 text-xs text-slate-600">
                      {/* 담당부서 — 팝업 선택, 저장은 부서코드 */}
                      담당부서
                      <div className="flex gap-2">
                        <input
                          className={searchInputClass}
                          value={form.deptNm || form.deptCd}
                          readOnly
                          placeholder="선택하세요"
                        />
                        <MesButton variant="secondary" disabled={!canEdit} onClick={openDeptLookup}>선택</MesButton>
                      </div>
                    </div>
                    <div className="flex flex-col gap-1 text-xs text-slate-600">
                      {/* 담당자 — 선택 시 소속 부서까지 함께 채운다 */}
                      담당자
                      <div className="flex gap-2">
                        <input
                          className={searchInputClass}
                          value={form.userNm || form.userId}
                          readOnly
                          placeholder="선택하세요"
                        />
                        <MesButton variant="secondary" disabled={!canEdit} onClick={openUserLookup}>선택</MesButton>
                      </div>
                    </div>
                    <label className="flex flex-col gap-1 text-xs text-slate-600">
                      {/* 사용유무 — N이면 예정일 생성이 멈추고 미래 미작성분이 정리된다 */}
                      사용유무
                      <select
                        className={searchInputClass}
                        value={form.useYn}
                        disabled={!canEdit}
                        onChange={(event) => setForm((prev) => ({
                          ...prev,
                          useYn: event.target.value === "N" ? "N" : "Y",
                        }))}
                      >
                        <option value="Y">사용</option>
                        <option value="N">미사용</option>
                      </select>
                    </label>
                  </div>

                  <fieldset className="mt-4 rounded border border-slate-200 p-3">
                    <legend className="px-1 text-xs font-medium text-slate-700">반복 설정</legend>

                    {form.cycleCd === "D" ? (
                      <p className="text-xs text-slate-500">
                        매일 반복합니다. 비영업일 처리 설정에 따라 주말 예정일이 이동합니다.
                      </p>
                    ) : null}

                    {form.cycleCd === "W" ? (
                      <div className="flex flex-wrap gap-1.5">
                        {WEEK_DAYS.map((day) => (
                          <button
                            // 요일 토글 — 선택한 요일마다 예정일이 생긴다
                            key={day.value}
                            type="button"
                            className={chipClass(form.weekDays.includes(day.value))}
                            disabled={!canEdit}
                            onClick={() => toggleWeekDay(day.value)}
                          >
                            {day.label}
                          </button>
                        ))}
                      </div>
                    ) : null}

                    {form.cycleCd === "M" ? (
                      <div className="flex flex-col gap-2">
                        <div className="flex flex-wrap gap-1.5">
                          {Array.from({ length: 31 }, (_, index) => index + 1).map((day) => (
                            <button
                              // 실행일 칩 — 해당 월에 없는 일자(31일 등)는 서버가 말일로 당긴다
                              key={day}
                              type="button"
                              className={chipClass(form.monthDays.includes(day))}
                              disabled={!canEdit}
                              onClick={() => toggleMonthDay(day)}
                            >
                              {day}
                            </button>
                          ))}
                        </div>
                        <label className="flex items-center gap-2 text-xs text-slate-600">
                          <input
                            // 말일 실행 — 실행일 지정과 함께 걸 수 있다
                            type="checkbox"
                            checked={form.monthEnd}
                            disabled={!canEdit}
                            onChange={(event) => setForm((prev) => ({ ...prev, monthEnd: event.target.checked }))}
                          />
                          말일에도 실행
                        </label>
                      </div>
                    ) : null}

                    {form.cycleCd === "Q" || form.cycleCd === "H" || form.cycleCd === "Y" ? (
                      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                        <label className="flex flex-col gap-1 text-xs text-slate-600">
                          {/* 분기·반기는 주기 내 월 순번(1=첫 달), 매년은 실제 월 번호 */}
                          {periodMonthLabel}
                          <select
                            className={searchInputClass}
                            value={form.periodMonth}
                            disabled={!canEdit}
                            onChange={(event) => setForm((prev) => ({
                              ...prev,
                              periodMonth: Number(event.target.value),
                            }))}
                          >
                            {periodMonths.map((month) => (
                              <option key={month} value={month}>
                                {form.cycleCd === "Y" ? `${month}월` : `${month}번째 달`}
                              </option>
                            ))}
                          </select>
                        </label>
                        <label className="flex flex-col gap-1 text-xs text-slate-600">
                          {/* 실행일 — 해당 월에 없는 일자는 말일로 당긴다 */}
                          실행일
                          <select
                            className={searchInputClass}
                            value={form.periodDay}
                            disabled={!canEdit}
                            onChange={(event) => setForm((prev) => ({
                              ...prev,
                              periodDay: Number(event.target.value),
                            }))}
                          >
                            {Array.from({ length: 31 }, (_, index) => index + 1).map((day) => (
                              <option key={day} value={day}>{day}일</option>
                            ))}
                          </select>
                        </label>
                      </div>
                    ) : null}
                  </fieldset>
                </div>
              )}
            </div>
          )}
        />
      </PageCard>
    </div>
  );
}
