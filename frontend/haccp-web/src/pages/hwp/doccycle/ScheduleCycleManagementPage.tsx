/**
 * ScheduleCycleManagementPage — 문서주기관리 (좌 양식 목록 50% · 우 주기 설정 50%).
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 좌측은 조회 전용이다 — 양식 등록·삭제는 사용양식 관리 몫이고 이 화면은 주기만 다룬다
 *   2) 양식 1개 = 주기 0..1건이라 우측은 그리드가 아닌 단일 폼이며 저장은 업서트다
 *   3) 반복설정은 주기 콤보에 따라 영역만 바뀐다 — 매일은 안내, 매주는 요일, 매월은 실행일·말일, 분기·반기·매년은 월+일
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
import { SearchArea, SearchButton, SearchField, SearchSelect } from "@/components/layout/SearchArea";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import { gridHeadClass, pageRootClass } from "@/components/layout/pageClasses";
// 역할 — 담당자 선택 공통 팝업 — 고르면 소속 부서까지 채운다
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
// 역할 — 담당자 후보 목록 — 사용자 관리 목록을 재사용하고 부서까지 함께 받는다
import { listUsers } from "@/api/sys/userApi";
// 역할 — 사용여부 검색 기본값·콤보 옵션
import { DEFAULT_USE_YN, ynOptions } from "@/lib/yn";
// 역할 — 구분 헤더 배지 — 사용양식 관리와 동일 색·문구
import { FormTypeBadge } from "../FormTypeBadge";
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

/** 좌우 패널 — 공통코드 관리와 같은 높이 고정(반복설정이 커져도 좌측 목록이 밀리지 않는다) */
const splitPanelClass =
  "flex min-h-0 h-full flex-1 flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm p-2";

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 좌측 사용양식 목록과 우측 주기 폼을 50:50으로 제공한다
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

  // 검색 조건 — 양식코드·양식명 부분검색(서버 LIKE), 사용여부 기본 Y·빈값=전체
  const [qTmplCd, setQTmplCd] = useState("");
  const [qTmplNm, setQTmplNm] = useState("");
  const [qUseYn, setQUseYn] = useState<string>(DEFAULT_USE_YN);
  const searchRef = useRef({ qTmplCd, qTmplNm, qUseYn });
  searchRef.current = { qTmplCd, qTmplNm, qUseYn };
  const ynOpts = useMemo(() => ynOptions(), []);

  const [forms, setForms] = useState<DocCycleFormRow[]>([]);
  const [activeTmplCd, setActiveTmplCd] = useState<string | null>(null);
  const [form, setForm] = useState<CycleForm>(emptyForm);
  // 서버에서 읽은 마지막 값 — 미저장 변경 판정 기준
  const [snapshot, setSnapshot] = useState<string>(JSON.stringify(emptyForm()));
  // 선택 양식에 저장된 주기가 있는지 — 삭제 버튼 활성 판정
  const [hasRule, setHasRule] = useState(false);
  const [listLoading, setListLoading] = useState(false);

  // 담당자 후보 — 화면 진입 시 1회. 팝업이 열릴 때마다 다시 읽지 않는다
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
  const nonworkOptions = useMemo(
    () => (nonworkCodes.codes.length
      ? nonworkCodes.codes.map((code) => ({ value: code.subCd, label: code.codeNm }))
      : NONWORK_FALLBACK.map((opt) => ({ value: opt.value, label: opt.label }))),
    [nonworkCodes.codes],
  );

  const formColumns = useMemo(() => buildFormColumns(), []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 양식 목록을 서버 검색으로 읽는다 — 사용여부는 Y/N 등가, 공백이면 전체
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
        // 사용여부 — 빈값이면 SP가 전체로 본다
        useYn: query.qUseYn.trim(),
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

  // 담당자 후보 — 화면 진입 시 1회. 팝업이 열릴 때마다 다시 읽지 않는다. 부서코드·부서명이 조인되어 온다
  useEffect(() => {
    void (async () => {
      try {
        const users = await listUsers({ useYn: "Y" });
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

  /**
   * 개발자: 박승우
   * 일자: 2026-08-14
   * 코멘트:
   *   1) 담당자 선택 팝업 — 이름 옆에 부서를 붙여 부서명으로도 찾고, 고르면 소속 부서를 기본값으로 넣는다
   *   2) 담당자 「선택」 버튼에서 호출한다
   *   3) (없음)을 고르면 담당자·부서를 함께 비운다. 저장은 userId·deptCd 로만 한다
   */
  const openUserLookup = () => {
    if (!canEdit) return;
    openModal("CodeLookup", {
      title: "담당자 선택",
      scrnCd: SCRN_CD,
      options: userRows.map((row) => ({
        value: row.userId,
        // 이름 (부서) — 코드명 칸에서 부서로도 조회된다
        label: row.deptNm ? `${row.userNm} (${row.deptNm})` : row.userNm,
      })),
      value: form.userId,
      allowEmpty: true,
      onSelect: (code) => {
        // 빈 코드일 때(= 없음) 담당자·부서를 함께 지운다
        if (!code) {
          setForm((prev) => ({
            ...prev,
            userId: "",
            userNm: "",
            deptCd: "",
            deptNm: "",
          }));
          return;
        }
        const picked = userRows.find((row) => row.userId === code);
        setForm((prev) => ({
          ...prev,
          userId: code,
          userNm: picked?.userNm ?? "",
          // 담당자 소속 부서를 기본값으로 넣는다 — 이전 부서를 남기지 않는다
          deptCd: picked?.deptCd ?? "",
          deptNm: picked?.deptNm ?? "",
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
    `rounded border px-2.5 py-1.5 text-sm ${on
      ? "border-blue-300 bg-blue-50 font-medium text-blue-700"
      : "border-slate-200 bg-white text-slate-600 hover:bg-slate-50"}`;
  // 매월 1~31 칩 — 자릿수와 무관하게 같은 칸(1과 11이 같은 너비)
  const monthDayChipClass = (on: boolean) =>
    `h-9 w-9 shrink-0 inline-flex items-center justify-center rounded border text-sm tabular-nums ${on
      ? "border-blue-300 bg-blue-50 font-medium text-blue-700"
      : "border-slate-200 bg-white text-slate-600 hover:bg-slate-50"}`;
  // 말일 실행 — 날짜 칩(파랑)과 구분해 노랑. 꺼져 있어도 노랑 바탕
  const monthEndChipClass = (on: boolean) =>
    `h-9 shrink-0 inline-flex items-center justify-center rounded border px-3 text-sm ${on
      ? "border-amber-400 bg-amber-200 font-semibold text-amber-950"
      : "border-amber-300 bg-amber-50 text-amber-800 hover:bg-amber-100"}`;
  // 주기 폼 라벨·값 — 검색 영역보다 한 단계 크게
  const formLabelClass = "flex flex-col gap-1 text-sm text-slate-700";
  const formFieldClass = `${searchInputClass} w-full min-w-0 text-sm`;

  const periodMonths = form.cycleCd === "Q"
    ? QUARTER_MONTHS
    : form.cycleCd === "H"
      ? HALF_MONTHS
      : ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] as const);
  const periodMonthLabel = form.cycleCd === "Y" ? "실행월" : "주기 내 실행월";

  return (
    <div className={pageRootClass}>
      <PageCard
        search={(
          <SearchArea
            onSearch={() => { void doSearch(); }}
            actions={<SearchButton loading={asyncAct.isBusy("search")} />}
          >
            <SearchField label="양식코드">
              <input
                // 양식코드 부분검색 — 서버 LIKE
                className={searchInputClass}
                value={qTmplCd}
                onChange={(event) => setQTmplCd(event.target.value)}
                placeholder="양식코드"
              />
            </SearchField>
            <SearchField label="양식명">
              <input
                // 양식명 부분검색 — 서버 LIKE
                className={searchInputClass}
                value={qTmplNm}
                onChange={(event) => setQTmplNm(event.target.value)}
                placeholder="양식명"
              />
            </SearchField>
            <SearchSelect
              // 사용여부 — 기본 Y, 빈값=전체. 공통코드 검색과 같은 SearchSelect
              label="사용여부"
              // 검색 사용여부 — Y/N 또는 빈값(전체)
              value={qUseYn}
              // 바꾸면 SearchSelect가 즉시 조회를 건다
              onChange={setQUseYn}
            >
              <option value="">전체</option>
              {ynOpts.map((opt) => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </SearchSelect>
          </SearchArea>
        )}
      >
        <ResizableSplit
          // 좌 목록 50% · 우 주기 설정 50% — 드래그 범위 약 25~75
          orientation="horizontal"
          // 비율 저장 키 — 화면 고유
          storageKey={SPLIT_KEY}
          defaultPrimaryPct={50}
          minPct={25}
          maxPct={75}
          className="mes-page-split min-h-0 h-full flex-1 gap-0"
          primary={(
            <div className={splitPanelClass}>
              <div className={gridHeadClass}>
                <div className="flex min-w-0 items-center gap-2">
                  <b>사용양식 목록</b>
                </div>
              </div>
              <MesDataGrid
                // 열 설정 저장 키 — 문서주기 좌측 목록
                persistId={PERSIST_ID}
                // 화면 권한·pref 범위
                scrnCd={SCRN_CD}
                // 조회 전용 양식 목록
                rows={forms}
                // 양식코드·양식명·구분·사용여부
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
                // 목록 헤더에 건수를 두지 않으므로 푸터 총 N건도 숨긴다
                showFooter={false}
                sortable
                showRowNum
                // 부모 높이 채움
                height="100%"
                title="사용양식 목록"
              />
            </div>
          )}
          secondary={(
            <div className={splitPanelClass}>
              <div className={gridHeadClass}>
                <div className="flex min-w-0 items-center gap-2">
                  <b>
                    {activeForm ? `${activeForm.tmplNm} 주기설정` : "주기설정"}
                  </b>
                  {activeForm ? (
                    <FormTypeBadge
                      // 주기 대상 구분
                      sysYn={activeForm.formTy}
                    />
                  ) : null}
                  {dirty ? (
                    <span className="text-sm text-amber-600">{MES.unsavedChanges}</span>
                  ) : null}
                </div>
                <div className="ml-auto flex gap-2">
                  <MesButton
                    // 주기 업서트 — 저장 후 예정일이 다시 생성된다
                    variant="save"
                    size="sm"
                    disabled={!canEdit || !activeTmplCd || asyncAct.isBusy("save")}
                    loading={asyncAct.isBusy("save")}
                    onClick={() => void asyncAct.run(handleSave, "save")}
                  >
                    저장
                  </MesButton>
                  <MesButton
                    // 주기 삭제 — 등록된 주기가 있을 때만
                    variant="danger"
                    size="sm"
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
                  왼쪽에서 양식을 선택하세요.
                </div>
              ) : (
                <div className="min-h-0 flex-1 overflow-auto p-4">
                  <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                    <label className={formLabelClass}>
                      {/* 관리 시작일 — 이 날짜 이전 예정일은 만들지 않는다 */}
                      관리 시작일
                      <input
                        type="date"
                        className={formFieldClass}
                        value={form.baseDt}
                        disabled={!canEdit}
                        onChange={(event) => setForm((prev) => ({ ...prev, baseDt: event.target.value }))}
                      />
                    </label>
                    <label className={formLabelClass}>
                      {/* 주기 — 바꾸면 아래 반복설정 영역이 교체된다 */}
                      주기
                      <select
                        className={formFieldClass}
                        value={form.cycleCd}
                        disabled={!canEdit}
                        onChange={(event) => setForm((prev) => ({ ...prev, cycleCd: event.target.value }))}
                      >
                        {cycleOptions.map((opt) => (
                          <option key={opt.value} value={opt.value}>{opt.label}</option>
                        ))}
                      </select>
                    </label>
                    <label className={formLabelClass}>
                      {/* 비영업일 처리 — 토·일에 걸린 예정일 이동 방식 */}
                      비영업일 처리
                      <select
                        className={formFieldClass}
                        value={form.nonworkRule}
                        disabled={!canEdit}
                        onChange={(event) => setForm((prev) => ({ ...prev, nonworkRule: event.target.value }))}
                      >
                        {nonworkOptions.map((opt) => (
                          <option key={opt.value} value={opt.value}>{opt.label}</option>
                        ))}
                      </select>
                    </label>
                    <label className={formLabelClass}>
                      {/* 마감시간 — 알림은 이 시각 기준으로 앞당겨 보낸다 */}
                      마감시간
                      <input
                        type="time"
                        className={formFieldClass}
                        value={form.dueTime}
                        disabled={!canEdit}
                        onChange={(event) => setForm((prev) => ({ ...prev, dueTime: event.target.value }))}
                      />
                    </label>
                    <div className={formLabelClass}>
                      {/* 담당부서 — 담당자를 고르면 소속이 기본값으로 들어온다. 직접 고르지 않는다 */}
                      담당부서
                      <input
                        className={formFieldClass}
                        value={form.deptNm || form.deptCd}
                        readOnly
                        placeholder="담당자 선택 시 자동"
                      />
                    </div>
                    <div className={formLabelClass}>
                      {/* 담당자 — 선택 시 소속 부서까지 함께 채운다 */}
                      담당자
                      <div className="flex gap-2">
                        <input
                          className={formFieldClass}
                          value={form.userNm || form.userId}
                          readOnly
                          placeholder="선택하세요"
                        />
                        <MesButton variant="secondary" disabled={!canEdit} onClick={openUserLookup}>선택</MesButton>
                      </div>
                    </div>
                    <label className={formLabelClass}>
                      {/* 사용유무 — N이면 예정일 생성이 멈추고 미래 미작성분이 정리된다 */}
                      사용유무
                      <select
                        className={formFieldClass}
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
                    <legend className="px-1 text-sm font-medium text-slate-700">반복 설정</legend>

                    {form.cycleCd === "D" ? (
                      <p className="rounded border border-blue-200 bg-blue-50 px-3 py-2 text-sm text-blue-800">
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
                        {[0, 1, 2].map((row) => (
                          <div
                            // 실행일 칩 한 줄 — 10칸 그리드 1~10 / 11~20 / 21~30
                            key={row}
                            className="grid grid-cols-10 gap-1.5"
                          >
                            {Array.from({ length: 10 }, (_, index) => row * 10 + index + 1).map((day) => (
                              <button
                                // 실행일 칩 — 고정 칸이라 1과 11이 같은 크기
                                key={day}
                                type="button"
                                className={monthDayChipClass(form.monthDays.includes(day))}
                                disabled={!canEdit}
                                onClick={() => toggleMonthDay(day)}
                              >
                                {day}
                              </button>
                            ))}
                          </div>
                        ))}
                        <div className="flex w-full flex-wrap items-center gap-1.5">
                          <button
                            // 31일 칩 — 1~30과 같은 고정 칸
                            type="button"
                            className={monthDayChipClass(form.monthDays.includes(31))}
                            disabled={!canEdit}
                            onClick={() => toggleMonthDay(31)}
                          >
                            31
                          </button>
                          <button
                            // 말일 실행 — 문구라 날짜 칩보다 넓다. 지정일과 같은 날이면 1회만 실행
                            type="button"
                            className={monthEndChipClass(form.monthEnd)}
                            disabled={!canEdit}
                            onClick={() => setForm((prev) => ({ ...prev, monthEnd: !prev.monthEnd }))}
                          >
                            말일 실행
                          </button>
                        </div>
                        <div className="space-y-1.5 rounded border border-blue-200 bg-blue-50 px-3 py-2.5 text-sm leading-5 text-blue-900">
                          <p>매달 실행할 날짜를 선택해 주세요.</p>
                          <p>[날짜 선택] 매달 지정한 날짜에 실행 (해당 날짜가 없는 달은 그달의 마지막 날 실행)</p>
                          <p>[매달 말일 실행] 매달 마지막 날에 실행</p>
                          <p>지정일과 말일이 같은 날인 경우, 1회만 실행됩니다.</p>
                        </div>
                      </div>
                    ) : null}

                    {form.cycleCd === "Q" || form.cycleCd === "H" || form.cycleCd === "Y" ? (
                      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                        <label className={formLabelClass}>
                          {/* 분기·반기는 주기 내 월 순번(1=첫 달), 매년은 실제 월 번호 */}
                          {periodMonthLabel}
                          <select
                            className={formFieldClass}
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
                        <label className={formLabelClass}>
                          {/* 실행일 — 그달에 없는 날은 그달의 마지막 날에 실행한다 */}
                          실행일
                          <select
                            className={formFieldClass}
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
