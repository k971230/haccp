/**
 * HealthCertManagementPage — 보건증 좌 사원 · 우 이력.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 골격은 결재선과 같다. SearchArea 1행 + 분할. 법조문은 등록 팝업에만 둔다
 *   2) 이력 추가는 행추가 팝업. 삭제 버튼은 canDelete 로 두고, 실행은 담당자만
 *   3) 파일 셀 열람은 새 탭 PDF. 이력 그리드는 access 를 넘기지 않는다. 업로드 오류는 mesError 토스트
 *
 * PIPELINE[HF216] 보건증 화면
 */
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Calendar, CalendarCheck, ChevronLeft, ChevronRight, Users } from "lucide-react";
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useGridAccess } from "@/hooks/useGridAccess";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
import { PageCard } from "@/components/layout/PageCard";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import {
  SearchArea,
  SearchButton,
  SearchField,
  SearchSelect,
} from "@/components/layout/SearchArea";
import { useCommonCodes } from "@/hooks/useCommonCodes";
import { gridHeadClass, pageRootClass, splitPanelClass } from "@/components/layout/pageClasses";
import { searchInputClass } from "@/components/ui/Input";
import { MesButton } from "@/components/ui/MesButton";
import { cn } from "@/lib/cn";
import { useModalStore } from "@/stores/modalStore";
import { mesConfirm, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { MES } from "@/shell/messages";
import { resolveRowsForDelete } from "@/shell/resolveDelete";
import { usePageCommands } from "@/shell/pageCommands";
import { useSection } from "@/shell/useSection";
import { listUsers } from "@/api/sys/userApi";
import { listNotifications } from "@/api/board/taskWorkflowApi";
import {
  deleteHealthCert,
  fetchHealthCertCan,
  listHealthCertCalendar,
  listHealthCertEmps,
  listHealthCertHist,
  listHealthCertMgrs,
  saveHealthCertMgrs,
  uploadHealthCert,
  validateDeleteHealthCert,
  viewHealthCert,
  type HealthCertCal,
  type HealthCertCalHoliday,
  type HealthCertCan,
  type HealthCertEmp,
  type HealthCertHist,
  type HealthCertMgr,
} from "@/api/flow/healthCertApi";
import { fromInputDate } from "@/lib/docDateTime";
import { FILE_MAX_BYTES } from "@/config/envConfig";
import {
  buildMonthCells,
  calendarCellSurfaceClass,
  calendarDayNumClass,
  calendarWeekdayHeadClass,
  parseYearMonth,
  shiftYearMonth,
  thisYearMonth,
  todayYmd,
  WEEKDAY_LABELS,
} from "@/pages/board/CalendarRule";
import type { EditableRow } from "@/types/editable";
import {
  EMP_PERSIST_ID,
  EMP_RULES,
  EMP_STATUS_ALL,
  HC_STATUS_MAIN_CD,
  HIST_PERSIST_ID,
  SCRN_CD,
  SPLIT_KEY,
  buildEmpColumns,
  buildHistColumns,
  empKey,
  histKey,
  matchEmp,
} from "./HealthCertManagementRule";

export function HealthCertManagementPage() {
  const canWrite = useAuthStore((s) => s.can(SCRN_CD, "write"));
  const canDelete = useAuthStore((s) => s.can(SCRN_CD, "delete"));
  const asyncAct = useAsyncAction();
  const empGrid = useGridAccess(EMP_RULES, { scrnCd: SCRN_CD, gridRole: "master", readOnly: true });
  const sec = useSection();
  const openModal = useModalStore((s) => s.openModal);

  const [can, setCan] = useState<HealthCertCan | null>(null);
  const [status, setStatus] = useState(EMP_STATUS_ALL);
  const hcStatus = useCommonCodes(HC_STATUS_MAIN_CD);
  const [q, setQ] = useState("");
  const [emps, setEmps] = useState<HealthCertEmp[]>([]);
  const [activeUserId, setActiveUserId] = useState("");
  const [hists, setHists] = useState<HealthCertHist[]>([]);
  const [activeHistKey, setActiveHistKey] = useState("");
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  const [uploadOpen, setUploadOpen] = useState(false);
  const [regDt, setRegDt] = useState("");
  const [expireDt, setExpireDt] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  // 직전에 연 PDF blob URL — 다음 열람 때 revoke 해서 힙을 비운다
  const blobUrlRef = useRef("");
  const [maskedYn, setMaskedYn] = useState(false);
  const [mgrOpen, setMgrOpen] = useState(false);
  const [mgrs, setMgrs] = useState<HealthCertMgr[]>([]);
  const [alarm1, setAlarm1] = useState(30);
  const [alarm2, setAlarm2] = useState(7);
  const [alarm3, setAlarm3] = useState(1);
  const [calOn, setCalOn] = useState(false);
  const [month, setMonth] = useState(thisYearMonth);
  const [calRows, setCalRows] = useState<HealthCertCal[]>([]);
  const [holidays, setHolidays] = useState<HealthCertCalHoliday[]>([]);
  const [workdays, setWorkdays] = useState<Set<string>>(new Set());

  const isMgr = can?.mgrYn === "Y";
  const canAssign = can?.adminYn === "Y";

  const loadNotis = useCallback(async () => {
    try {
      const rows = await listNotifications();
      const due = rows.filter((r) => String(r.notiTypeCd ?? "") === "HEALTH_CERT_DUE" && String(r.readYn ?? "") !== "Y");
      if (due.length) {
        mesToast(due[0]?.title || "보건증 만료가 임박한 대상이 있습니다.", "warn");
      }
    } catch {
      // 알림 API 는 today-tasks 권한. 없어도 보건증 조회는 연다
    }
  }, []);

  const loadEmps = useCallback(async () => {
    // 전체 대상. 임박·만료는 상태 콤보가 FE 에서 거른다
    const rows = await listHealthCertEmps("N");
    const keyed = rows.map((r) => ({ ...r, _key: empKey(r) }));
    setEmps(keyed);
    return keyed;
  }, []);

  const loadHist = useCallback(async (userId: string) => {
    if (!userId) {
      setHists([]);
      return;
    }
    try {
      const rows = await listHealthCertHist(userId);
      setHists(rows.map((r) => ({ ...r, _key: histKey(r) })));
      setActiveHistKey("");
      setSelKeys([]);
      setSelReset((n) => n + 1);
    } catch (e) {
      mesError(e);
    }
  }, []);

  const refresh = useCallback(async () => {
    try {
      const [c, rows] = await Promise.all([fetchHealthCertCan(), loadEmps(), loadNotis()]);
      setCan(c ?? null);
      if (activeUserId && !rows.some((r) => r.userId === activeUserId)) {
        setActiveUserId("");
        setHists([]);
      }
    } catch (e) {
      mesError(e);
    }
  }, [activeUserId, loadEmps, loadNotis]);

  useEffect(() => {
    void asyncAct.run(refresh, "search");
    // 첫 진입만. 상태는 SearchArea 가 다시 조회한다
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!isMgr) setCalOn(false);
  }, [isMgr]);

  const shownEmps = useMemo(
    () => emps.filter((row) => matchEmp(row, q, status, can?.expireWindowDays)),
    [can?.expireWindowDays, emps, q, status],
  );

  const handleSelect = useCallback((row: HealthCertEmp) => {
    setActiveUserId(row.userId);
    void asyncAct.run(() => loadHist(row.userId), "search");
  }, [asyncAct, loadHist]);

  /**
   * 개발자: 박승우
   * 일자: 2026-09-15
   * 코멘트:
   *   1) 파일 셀 버튼 클릭으로 보건증 PDF 를 새 탭에서 연다
   *   2) await 뒤에 window.open 하면 팝업 차단되므로 빈 탭을 먼저 연다
   *   3) 권한 없음·네트워크 실패는 mesError 토스트
   */
  const handleView = useCallback(async (row: HealthCertHist) => {
    if (!row.idx) return;
    // 사용자 제스처 안에서 탭을 연다 — 다운로드 뒤에 열면 브라우저가 막는다
    const tab = window.open("about:blank", "_blank");
    try {
      const blob = await viewHealthCert(row.idx);
      const pdf = blob.type.includes("pdf") ? blob : new Blob([blob], { type: "application/pdf" });
      // 이전 blob 은 탭이 이미 연 뒤라 revoke 해도 그 탭은 유지된다
      if (blobUrlRef.current) URL.revokeObjectURL(blobUrlRef.current);
      const url = URL.createObjectURL(pdf);
      blobUrlRef.current = url;
      if (tab) {
        tab.location.href = url;
      } else {
        window.open(url, "_blank", "noopener");
      }
    } catch (e) {
      tab?.close();
      mesError(e);
    }
  }, []);

  const resetUpload = useCallback(() => {
    setRegDt("");
    setExpireDt("");
    setFile(null);
    setMaskedYn(false);
  }, []);

  const handleAdd = useCallback(() => {
    if (!activeUserId) {
      mesToast(MES.selectFirst("사원"), "warn");
      return;
    }
    resetUpload();
    setUploadOpen(true);
  }, [activeUserId, resetUpload]);

  const closeUpload = useCallback(() => {
    if (asyncAct.isBusy("save")) return;
    setUploadOpen(false);
    resetUpload();
  }, [asyncAct, resetUpload]);

  const closeMgr = useCallback(() => {
    if (asyncAct.isBusy("save")) return;
    setMgrOpen(false);
  }, [asyncAct]);

  useEffect(() => {
    if (!uploadOpen && !mgrOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape") return;
      e.preventDefault();
      if (uploadOpen) closeUpload();
      else closeMgr();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [closeMgr, closeUpload, mgrOpen, uploadOpen]);

  const handleUpload = useCallback(async () => {
    if (!activeUserId) {
      mesToast(MES.selectFirst("사원"), "warn");
      return;
    }
    if (!file) {
      mesToast("보건증 파일을 선택하세요.", "warn");
      return;
    }
    if (!file.name.toLowerCase().endsWith(".pdf")) {
      mesToast("PDF 파일만 업로드할 수 있습니다.", "warn");
      return;
    }
    if (file.size > FILE_MAX_BYTES) {
      mesToast(MES.fileTooLarge, "warn");
      return;
    }
    if (fromInputDate(regDt).length !== 8 || fromInputDate(expireDt).length !== 8) {
      mesToast("등록일과 만료일을 입력하세요.", "warn");
      return;
    }
    if (!maskedYn) {
      mesToast("주민번호 뒷자리를 가린 사본만 업로드할 수 있습니다.", "warn");
      return;
    }
    try {
      await uploadHealthCert({
        userId: activeUserId,
        regDt: fromInputDate(regDt),
        expireDt: fromInputDate(expireDt),
        file,
        maskedYn: "Y",
      });
      mesToast(MES.saveDone, "success");
      setUploadOpen(false);
      resetUpload();
      await Promise.all([loadHist(activeUserId), loadEmps(), loadNotis()]);
    } catch (e) {
      mesError(e);
    }
  }, [activeUserId, expireDt, file, loadEmps, loadHist, loadNotis, maskedYn, regDt, resetUpload]);

  const handleDelete = useCallback(async () => {
    // 버튼은 canDelete 로 보인다. 담당자가 아니면 API 전에 거절
    if (!isMgr) {
      mesToast("보건증 이력은 담당자만 삭제할 수 있습니다.", "warn");
      return;
    }
    const targets = resolveRowsForDelete(
      hists as EditableRow<HealthCertHist>[],
      activeHistKey || null,
      () => undefined,
      selKeys,
    );
    const keys = targets.map((r) => r.idx).filter((idx): idx is number => Number(idx) > 0).map((idx) => ({ idx }));
    if (!keys.length) {
      mesToast(MES.selectRow, "warn");
      return;
    }
    try {
      await validateDeleteHealthCert(keys);
      const ok = await mesConfirm(MES.deleteConfirm("보건증 이력"));
      if (!ok) return;
      await deleteHealthCert(keys);
      mesToast(MES.deleteDone, "success");
      await Promise.all([loadHist(activeUserId), loadEmps()]);
    } catch (e) {
      mesError(e);
    }
  }, [activeHistKey, activeUserId, hists, isMgr, loadEmps, loadHist, selKeys]);

  const openMgr = useCallback(async () => {
    try {
      const [list, c] = await Promise.all([listHealthCertMgrs(), fetchHealthCertCan()]);
      setMgrs(list);
      setAlarm1(c?.alarmDay1 ?? 30);
      setAlarm2(c?.alarmDay2 ?? 7);
      setAlarm3(c?.alarmDay3 ?? 1);
      setMgrOpen(true);
    } catch (e) {
      mesError(e);
    }
  }, []);

  const addMgr = useCallback(async () => {
    try {
      const users = await listUsers({ useYn: "Y" });
      openModal("CodeLookup", {
        title: "담당자 선택",
        scrnCd: SCRN_CD,
        options: users.map((u) => ({
          value: String(u.userId ?? ""),
          label: u.deptNm ? `${u.userNm} (${u.deptNm})` : String(u.userNm ?? ""),
        })),
        value: "",
        allowEmpty: true,
        onSelect: (code: string) => {
          if (!code) return;
          const u = users.find((x) => String(x.userId) === code);
          setMgrs((prev) => prev.some((m) => m.userId === code)
            ? prev
            : [...prev, { userId: code, userNm: String(u?.userNm ?? code), deptNm: String(u?.deptNm ?? "") }]);
        },
      });
    } catch (e) {
      mesError(e);
    }
  }, [openModal]);

  const saveMgr = useCallback(async () => {
    try {
      await saveHealthCertMgrs({
        userIds: mgrs.map((m) => m.userId),
        alarmDay1: alarm1,
        alarmDay2: alarm2,
        alarmDay3: alarm3,
      });
      mesToast(MES.saveDone, "success");
      setMgrOpen(false);
      await refresh();
    } catch (e) {
      mesError(e);
    }
  }, [alarm1, alarm2, alarm3, mgrs, refresh]);

  const loadCal = useCallback(async (ym: string) => {
    try {
      const parsed = parseYearMonth(ym);
      const range = buildMonthCells(parsed.year, parsed.month);
      const from = range[0]?.ymd ?? `${ym}01`;
      const to = range[range.length - 1]?.ymd ?? `${ym}31`;
      const data = await listHealthCertCalendar(from, to);
      setCalRows(data.days);
      setHolidays(data.holidays);
      setWorkdays(new Set(data.workdays));
    } catch (e) {
      mesError(e);
    }
  }, []);

  useEffect(() => {
    if (calOn && isMgr) void asyncAct.run(() => loadCal(month), "search");
  }, [calOn, isMgr, month]);

  const histCols = useMemo(() => buildHistColumns((row) => { void handleView(row); }), [handleView]);
  const empCols = useMemo(() => buildEmpColumns(), []);
  const ym = useMemo(() => parseYearMonth(month), [month]);
  const cells = useMemo(() => buildMonthCells(ym.year, ym.month), [ym]);
  const today = todayYmd();
  const holidayName = useMemo(() => {
    const map = new Map<string, string>();
    for (const h of holidays) map.set(h.ymd, h.name);
    return map;
  }, [holidays]);
  const byDay = useMemo(() => {
    const map = new Map<string, HealthCertCal[]>();
    for (const r of calRows) {
      const k = r.expireDt;
      map.set(k, [...(map.get(k) ?? []), r]);
    }
    return map;
  }, [calRows]);

  usePageCommands({
    search: () => asyncAct.run(refresh, "search"),
    del: canDelete ? () => asyncAct.run(handleDelete, "del") : undefined,
  });

  return (
    <div className={pageRootClass}>
      <PageCard
        search={(
          <SearchArea
            // 조회 — 대상은 서버 전체. 상태·사원명은 FE
            onSearch={() => { void asyncAct.run(refresh, "search"); }}
            actions={(
              <div className="flex items-end gap-1.5">
                <SearchButton
                  // 조회 busy 스피너
                  loading={asyncAct.isBusy("search")}
                />
                {canAssign ? (
                  <MesButton
                    // 담당자 지정 — 보라 pass 틴트. ADMIN 만
                    variant="pass"
                    type="button"
                    icon={Users}
                    onClick={() => void asyncAct.run(openMgr, "search")}
                  >
                    담당자
                  </MesButton>
                ) : null}
                {isMgr ? (
                  <MesButton
                    // 만료 캘린더 토글 — 일정 이번 달과 같은 초록 틴트
                    variant="excel"
                    type="button"
                    icon={Calendar}
                    onClick={() => setCalOn((v) => !v)}
                  >
                    {calOn ? "목록 보기" : "캘린더"}
                  </MesButton>
                ) : null}
              </div>
            )}
          >
            <SearchSelect
              // HC_STATUS. 빈값=전체. 만료일 FE 거름
              label="상태"
              value={status}
              onChange={setStatus}
            >
              <option value={EMP_STATUS_ALL}>전체</option>
              {hcStatus.codes.map((code) => (
                <option key={code.subCd} value={String(code.subCd).toUpperCase()}>{code.codeNm}</option>
              ))}
            </SearchSelect>
            <SearchField label="사원명">
              <input
                // 사원명 부분검색 — 조회 때 FE 거름
                className={searchInputClass}
                value={q}
                onChange={(e) => setQ(e.target.value)}
                placeholder="사원명"
              />
            </SearchField>
          </SearchArea>
        )}
      >
        {calOn && isMgr ? (
          <div className="flex min-h-0 flex-1 flex-col">
            <div
              // 날짜 · 이전 · 다음 · 오늘. 영업일 저장·과제 범례는 두지 않는다
              className="flex flex-wrap items-center gap-2 border-b border-slate-200 bg-slate-50/70 px-3 py-2"
            >
              <span
                // 현재 조회 월
                className="min-w-[7.5rem] text-base font-bold text-slate-800"
              >
                {ym.year}년 {ym.month}월
              </span>
              <MesButton
                // 이전 달
                variant="search"
                size="sm"
                icon={ChevronLeft}
                onClick={() => setMonth(shiftYearMonth(month, -1))}
              >
                이전
              </MesButton>
              <MesButton
                // 다음 달
                variant="search"
                size="sm"
                icon={ChevronRight}
                onClick={() => setMonth(shiftYearMonth(month, 1))}
              >
                다음
              </MesButton>
              <MesButton
                // 이번 달
                variant="excel"
                size="sm"
                icon={CalendarCheck}
                onClick={() => setMonth(thisYearMonth())}
              >
                오늘
              </MesButton>
            </div>
            <div
              // 요일 머리 + 6주 칸 — 일정 캘린더와 같은 격자
              className="grid min-h-0 flex-1 cursor-default select-none grid-cols-7 grid-rows-[auto_repeat(6,minmax(0,1fr))]"
            >
              {WEEKDAY_LABELS.map((label, i) => (
                <div
                  // 요일 머리 — 일·토 강조
                  key={label}
                  className={calendarWeekdayHeadClass(i)}
                >
                  {label}
                </div>
              ))}
              {cells.map((cell) => {
                const holiday = holidayName.get(cell.ymd);
                const checked = workdays.has(cell.ymd);
                const isToday = cell.inMonth && cell.ymd === today;
                const people = byDay.get(cell.ymd) ?? [];
                return (
                  <div
                    // 하루 칸 — 주말 rose · 공휴일 orange · 오늘 파란 링. 영업일 전환은 색만
                    key={cell.ymd}
                    className={calendarCellSurfaceClass(cell, {
                      todayYmd: today,
                      holiday,
                      workday: checked,
                    })}
                  >
                    <div className="flex items-center gap-1">
                      <span
                        // 일자 — 오늘은 파란 원. 주말·공휴일은 붉게
                        className={calendarDayNumClass(cell, { todayYmd: today, holiday })}
                      >
                        {cell.day}
                      </span>
                      {isToday ? (
                        <span
                          // 오늘 배지
                          className="text-[10px] font-bold text-blue-700"
                        >
                          오늘
                        </span>
                      ) : null}
                    </div>
                    {holiday ? (
                      <div
                        // 공휴일 명칭
                        className="truncate text-xs font-bold text-rose-700"
                        title={holiday}
                      >
                        {holiday}
                      </div>
                    ) : null}
                    <div className="mt-0.5 flex min-h-0 flex-1 flex-col gap-0.5 overflow-hidden">
                      {people.map((r) => (
                        <div
                          // 만료 사원 칩 — 일정 과제 알약과 달리 이름만
                          key={r.userId}
                          className="truncate rounded bg-sky-100 px-1"
                        >
                          {r.userNm}
                        </div>
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        ) : (
          <ResizableSplit
            orientation="horizontal"
            storageKey={SPLIT_KEY}
            defaultPrimaryPct={30}
            minPct={20}
            maxPct={80}
            className="mes-page-split min-h-0 h-full flex-1 gap-0"
            primary={(
              <div {...sec.bind("h", splitPanelClass)}>
                <div className={gridHeadClass}><b>대상 사원</b></div>
                <MesEditableGrid
                  // 열 너비 저장 키 — 폴더를 옮겨도 바꾸지 않는다
                  persistId={EMP_PERSIST_ID}
                  title="대상 사원"
                  rows={shownEmps as EditableRow<HealthCertEmp>[]}
                  columns={empCols}
                  editable={false}
                  height="100%"
                  loading={asyncAct.isBusy("search")}
                  activeKey={activeUserId}
                  onActivate={(row) => handleSelect(row)}
                  access={empGrid.access}
                  onLockedAttempt={empGrid.onLockedAttempt}
                  onSetActive={() => sec.setSec("h")}
                  showRowNum
                />
              </div>
            )}
            secondary={(
              <div {...sec.bind("d", splitPanelClass)}>
                <div className={gridHeadClass}>
                  <b>보건증 이력</b>
                  <GridCrudButtons
                    run={asyncAct.run}
                    onAdd={canWrite ? handleAdd : undefined}
                    onDel={canDelete ? handleDelete : undefined}
                    busy={{ del: asyncAct.isBusy("del") }}
                  />
                </div>
                <MesEditableGrid
                  // 열 너비 저장 키 — 폴더를 옮겨도 바꾸지 않는다
                  persistId={HIST_PERSIST_ID}
                  // 우측 이력 그리드 제목
                  title="보건증 이력"
                  // 선택 사원의 이력. filePath·wrappedDek 은 API 가 안 내린다
                  rows={hists as EditableRow<HealthCertHist>[]}
                  // 등록일·만료일·파일명·열람
                  columns={histCols}
                  // 이력은 첨부로만 쌓인다. 셀 편집 없음
                  editable={false}
                  height="100%"
                  loading={asyncAct.isBusy("search") || asyncAct.isBusy("del")}
                  emptyHint={
                    activeUserId
                      ? "등록된 보건증이 없습니다."
                      : "대상 사원을 선택하면 보건증 이력이 나타납니다."
                  }
                  activeKey={activeHistKey}
                  onActivate={(row) => setActiveHistKey(String(row._key ?? ""))}
                  onSetActive={() => sec.setSec("d")}
                  selectable
                  onSelectionChange={(rows) => setSelKeys(rows.map((row) => row._key))}
                  selectionResetKey={selReset}
                  showRowNum
                />
              </div>
            )}
          />
        )}
      </PageCard>

      {uploadOpen ? (
        <div
          // 등록 팝업 오버레이 — 비밀번호 변경과 같은 셸
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
          role="dialog"
          aria-modal="true"
          aria-label="보건증 이력 등록"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget) closeUpload();
          }}
        >
          <form
            className="flex w-full max-w-md flex-col overflow-hidden rounded border border-slate-200 bg-white shadow-lg"
            onMouseDown={(e) => e.stopPropagation()}
            onSubmit={(e) => {
              e.preventDefault();
              void asyncAct.run(handleUpload, "save", mesError);
            }}
          >
            <div
              // 모달 헤더 — gridHead h-9
              className={cn(gridHeadClass, "mes-modal-grid-head")}
            >
              <b>보건증 이력 등록</b>
            </div>
            <div className="flex flex-col gap-2 px-3 py-2.5">
              <div className="border-l-2 border-rose-500 pl-2 text-xs leading-relaxed text-slate-600">
                <p className="m-0 font-semibold">[건강진단결과서(보건증) 등록 안내]</p>
                <p className="mt-1.5 m-0">
                  개인정보 보호: 주민등록번호 뒷자리를 마스킹(가림 처리)한 PDF 파일만 등록해 주세요.
                  시스템에는 주민등록번호를 별도 저장하지 않습니다.
                </p>
                <p className="mt-1.5 m-0">
                  보안 및 열람: 등록된 문서는 권한을 가진 담당자만 열람 및 파기할 수 있습니다.
                </p>
                <p className="mt-1.5 m-0">
                  보관 및 파기: 식품위생법 제40조에 따른 이력 관리 후, 신규 서류로 대체된 이전 이력은
                  유효기간 만료일로부터 2년 경과 시 자동 영구 삭제됩니다.
                </p>
              </div>
              <div className="grid grid-cols-2 gap-2">
                <label className="flex flex-col gap-1 text-xs text-slate-600">
                  <span>등록일<span className="ml-0.5 text-rose-500">*</span></span>
                  <input
                    type="date"
                    // DB varchar(8) YYYYMMDD. type=date 는 10자, 저장 때 fromInputDate
                    className={cn(searchInputClass, "w-full")}
                    value={regDt}
                    onChange={(e) => setRegDt(e.target.value)}
                  />
                </label>
                <label className="flex flex-col gap-1 text-xs text-slate-600">
                  <span>만료일<span className="ml-0.5 text-rose-500">*</span></span>
                  <input
                    type="date"
                    // 만료일 8자리. 알림·파기 기준. 화면 10자를 그대로 보내면 22001
                    className={cn(searchInputClass, "w-full")}
                    value={expireDt}
                    onChange={(e) => setExpireDt(e.target.value)}
                  />
                </label>
              </div>
              <div className="flex flex-col gap-1">
                <span className="text-xs text-slate-600">
                  파일 첨부<span className="ml-0.5 text-rose-500">*</span>
                </span>
                <div className="flex items-center gap-2">
                  <input
                    // 고른 파일은 상태에만 둔다. 저장은 푸터. PDF 만
                    ref={fileInputRef}
                    type="file"
                    accept=".pdf,application/pdf"
                    className="sr-only"
                    onChange={(e) => {
                      const picked = e.target.files?.[0] ?? null;
                      e.target.value = "";
                      setFile(picked);
                    }}
                  />
                  <MesButton
                    // 문서 첨부와 같은 파일 추가. 숨긴 input 을 연다
                    variant="add"
                    size="sm"
                    icon="plus"
                    type="button"
                    disabled={asyncAct.isBusy("save")}
                    onClick={() => fileInputRef.current?.click()}
                  >
                    파일 추가
                  </MesButton>
                  <span className="min-w-0 truncate text-xs text-slate-500">
                    {file?.name ?? "선택된 파일 없음"}
                  </span>
                </div>
              </div>
              <label className="flex items-center gap-1.5 text-xs text-slate-700">
                <input
                  type="checkbox"
                  // 미체크면 저장 거절. OCR 없이 업로드 책임을 남긴다
                  checked={maskedYn}
                  onChange={(e) => setMaskedYn(e.target.checked)}
                />
                <span>
                  주민번호 뒷자리를 가린 뒤 올렸습니다
                  <span className="ml-0.5 text-rose-500">*</span>
                </span>
              </label>
            </div>
            <div
              // 푸터 — 저장·취소. 헤더 h-9 를 넘기지 않는다
              className="flex shrink-0 items-center justify-end gap-1.5 border-t border-slate-200 bg-slate-50/70 px-3 py-2"
            >
              <MesButton
                // 저장 — 비밀번호 변경과 같은 조회 파란 틴트. 파일 없으면 비활성
                variant="search"
                size="sm"
                type="submit"
                loading={asyncAct.isBusy("save")}
                disabled={!file || asyncAct.isBusy("save")}
              >
                저장
              </MesButton>
              <MesButton
                // 취소 — 비밀번호 변경과 같은 빨간 틴트
                variant="danger"
                size="sm"
                type="button"
                disabled={asyncAct.isBusy("save")}
                onClick={closeUpload}
              >
                취소
              </MesButton>
            </div>
          </form>
        </div>
      ) : null}

      {mgrOpen ? (
        <div
          // 담당자 팝업 오버레이 — 등록 팝업과 같은 셸
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
          role="dialog"
          aria-modal="true"
          aria-label="보건증 담당자"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget) closeMgr();
          }}
        >
          <form
            className="flex w-full max-w-md flex-col overflow-hidden rounded border border-slate-200 bg-white shadow-lg"
            onMouseDown={(e) => e.stopPropagation()}
            onSubmit={(e) => {
              e.preventDefault();
              void asyncAct.run(saveMgr, "save", mesError);
            }}
          >
            <div
              // 모달 헤더 — gridHead h-9
              className={cn(gridHeadClass, "mes-modal-grid-head")}
            >
              <b>보건증 담당자</b>
            </div>
            <div className="flex flex-col gap-2 px-3 py-2.5">
              <div className="max-h-48 overflow-auto rounded border border-slate-200">
                {mgrs.length ? mgrs.map((m) => (
                  <div
                    key={m.userId}
                    className="flex items-center justify-between gap-2 border-b border-slate-100 px-2 py-1 last:border-b-0"
                  >
                    <span className="min-w-0 truncate text-xs text-slate-700">
                      {m.userNm} ({m.deptNm || m.userId})
                    </span>
                    <MesButton
                      // 목록에서만 뺀다. 저장 때 서버에 반영
                      variant="danger"
                      size="sm"
                      type="button"
                      disabled={asyncAct.isBusy("save")}
                      onClick={() => setMgrs((p) => p.filter((x) => x.userId !== m.userId))}
                    >
                      제외
                    </MesButton>
                  </div>
                )) : (
                  <p className="m-0 px-2 py-2 text-xs text-slate-500">담당자가 없습니다</p>
                )}
              </div>
              <MesButton
                // 사용자 조회 팝업. 등록의 파일 추가와 같은 노란 틴트
                variant="add"
                size="sm"
                icon="plus"
                type="button"
                className="self-start"
                disabled={asyncAct.isBusy("save")}
                onClick={() => void addMgr()}
              >
                직원 추가
              </MesButton>
              <div className="grid grid-cols-3 gap-2">
                <label className="flex flex-col gap-1 text-xs text-slate-600">
                  <span>1차(일 전)</span>
                  <input
                    type="number"
                    min={1}
                    className={cn(searchInputClass, "w-full")}
                    value={alarm1}
                    onChange={(e) => setAlarm1(Number(e.target.value))}
                  />
                </label>
                <label className="flex flex-col gap-1 text-xs text-slate-600">
                  <span>2차(일 전)</span>
                  <input
                    type="number"
                    min={1}
                    className={cn(searchInputClass, "w-full")}
                    value={alarm2}
                    onChange={(e) => setAlarm2(Number(e.target.value))}
                  />
                </label>
                <label className="flex flex-col gap-1 text-xs text-slate-600">
                  <span>3차(일 전)</span>
                  <input
                    type="number"
                    min={1}
                    className={cn(searchInputClass, "w-full")}
                    value={alarm3}
                    onChange={(e) => setAlarm3(Number(e.target.value))}
                  />
                </label>
              </div>
            </div>
            <div
              // 푸터 — 저장·취소. 등록 팝업과 같다
              className="flex shrink-0 items-center justify-end gap-1.5 border-t border-slate-200 bg-slate-50/70 px-3 py-2"
            >
              <MesButton
                // 저장 — 등록과 같은 조회 파란 틴트
                variant="search"
                size="sm"
                type="submit"
                loading={asyncAct.isBusy("save")}
              >
                저장
              </MesButton>
              <MesButton
                // 취소 — 등록과 같은 빨간 틴트
                variant="danger"
                size="sm"
                type="button"
                disabled={asyncAct.isBusy("save")}
                onClick={closeMgr}
              >
                취소
              </MesButton>
            </div>
          </form>
        </div>
      ) : null}
    </div>
  );
}
