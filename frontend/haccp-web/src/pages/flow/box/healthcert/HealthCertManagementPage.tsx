/**
 * HealthCertManagementPage — 보건증 좌 사원 · 우 이력.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 레이아웃은 결재선과 같은 ResizableSplit. 행 권한은 서버가 가른다
 *   2) 임박 필터 라벨은 설정 MAX 일수. 알림은 이 화면 상단에 보인다
 *   3) 캘린더는 담당자만
 *
 * PIPELINE[HF216] 보건증 화면
 */
import { useCallback, useEffect, useMemo, useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { useAuthStore } from "@/stores/authStore";
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { useGridAccess } from "@/hooks/useGridAccess";
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
import { PageCard } from "@/components/layout/PageCard";
import { ResizableSplit } from "@/components/layout/ResizableSplit";
import { SearchArea, SearchButton, SearchCheckbox } from "@/components/layout/SearchArea";
import { gridHeadClass, pageRootClass, splitPanelClass } from "@/components/layout/pageClasses";
import { MesButton } from "@/components/ui/MesButton";
import { useModalStore } from "@/stores/modalStore";
import { mesConfirm, mesToast } from "@/shell/dialog";
import { MES } from "@/shell/messages";
import { usePageCommands } from "@/shell/pageCommands";
import { useSection } from "@/shell/useSection";
import { listUsers } from "@/api/sys/userApi";
import { listNotifications, readNotification } from "@/api/board/taskWorkflowApi";
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
  type HealthCertCan,
  type HealthCertEmp,
  type HealthCertHist,
  type HealthCertMgr,
} from "@/api/flow/healthCertApi";
import { fromInputDate } from "@/lib/docDateTime";
import {
  buildMonthCells,
  parseYearMonth,
  shiftYearMonth,
  thisYearMonth,
  WEEKDAY_LABELS,
} from "@/pages/board/CalendarRule";
import type { EditableRow } from "@/types/editable";
import {
  EMP_PERSIST_ID,
  EMP_RULES,
  HIST_PERSIST_ID,
  HIST_RULES,
  SCRN_CD,
  SPLIT_KEY,
  buildEmpColumns,
  buildHistColumns,
  empKey,
  expiringLabel,
  histKey,
} from "./HealthCertManagementRule";

export function HealthCertManagementPage() {
  const canWrite = useAuthStore((s) => s.can(SCRN_CD, "write"));
  const canDelete = useAuthStore((s) => s.can(SCRN_CD, "delete"));
  const asyncAct = useAsyncAction();
  const empGrid = useGridAccess(EMP_RULES, { scrnCd: SCRN_CD, gridRole: "master", readOnly: true });
  const histGrid = useGridAccess(HIST_RULES, { scrnCd: SCRN_CD, gridRole: "detail", readOnly: true });
  const sec = useSection();
  const openModal = useModalStore((s) => s.openModal);

  const [can, setCan] = useState<HealthCertCan | null>(null);
  const [expiring, setExpiring] = useState(false);
  const [emps, setEmps] = useState<HealthCertEmp[]>([]);
  const [activeUserId, setActiveUserId] = useState("");
  const [hists, setHists] = useState<HealthCertHist[]>([]);
  const [activeHistKey, setActiveHistKey] = useState("");
  const [regDt, setRegDt] = useState("");
  const [expireDt, setExpireDt] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [maskedYn, setMaskedYn] = useState(false);
  const [notis, setNotis] = useState<{ idx?: number; title?: string; content?: string }[]>([]);
  const [mgrOpen, setMgrOpen] = useState(false);
  const [mgrs, setMgrs] = useState<HealthCertMgr[]>([]);
  const [alarm1, setAlarm1] = useState(30);
  const [alarm2, setAlarm2] = useState(7);
  const [alarm3, setAlarm3] = useState(1);
  const [calOn, setCalOn] = useState(false);
  const [month, setMonth] = useState(thisYearMonth);
  const [calRows, setCalRows] = useState<HealthCertCal[]>([]);

  const isMgr = can?.mgrYn === "Y";
  const canAssign = can?.adminYn === "Y";

  const loadNotis = useCallback(async () => {
    const rows = await listNotifications();
    setNotis(rows.filter((r) => String(r.notiTypeCd ?? "") === "HEALTH_CERT_DUE" && String(r.readYn ?? "") !== "Y"));
  }, []);

  const loadEmps = useCallback(async () => {
    const rows = await listHealthCertEmps(expiring ? "Y" : "N");
    const keyed = rows.map((r) => ({ ...r, _key: empKey(r) }));
    setEmps(keyed);
    return keyed;
  }, [expiring]);

  const loadHist = useCallback(async (userId: string) => {
    if (!userId) {
      setHists([]);
      return;
    }
    const rows = await listHealthCertHist(userId);
    setHists(rows.map((r) => ({ ...r, _key: histKey(r) })));
    setActiveHistKey("");
  }, []);

  const refresh = useCallback(async () => {
    const [c, rows] = await Promise.all([fetchHealthCertCan(), loadEmps(), loadNotis()]);
    setCan(c ?? null);
    if (activeUserId && !rows.some((r) => r.userId === activeUserId)) {
      setActiveUserId("");
      setHists([]);
    }
  }, [activeUserId, loadEmps, loadNotis]);

  useEffect(() => {
    void asyncAct.run(refresh, "search");
    // 첫 진입만. 임박 체크는 SearchCheckbox 가 다시 조회한다
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!isMgr) setCalOn(false);
  }, [isMgr]);

  const handleSelect = useCallback((row: HealthCertEmp) => {
    setActiveUserId(row.userId);
    void asyncAct.run(() => loadHist(row.userId), "search");
  }, [asyncAct, loadHist]);

  const handleView = useCallback(async (row: HealthCertHist) => {
    if (!row.idx) return;
    const blob = await viewHealthCert(row.idx);
    const url = URL.createObjectURL(blob);
    window.open(url, "_blank", "noopener");
  }, []);

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
    if (!maskedYn) {
      mesToast("주민번호 뒷자리를 가린 사본만 업로드할 수 있습니다.", "warn");
      return;
    }
    await uploadHealthCert({
      userId: activeUserId,
      regDt: fromInputDate(regDt),
      expireDt: fromInputDate(expireDt),
      file,
      maskedYn: "Y",
    });
    setFile(null);
    setMaskedYn(false);
    mesToast(MES.saveDone, "success");
    await Promise.all([loadHist(activeUserId), loadEmps(), loadNotis()]);
  }, [activeUserId, expireDt, file, loadEmps, loadHist, loadNotis, maskedYn, regDt]);

  const handleDelete = useCallback(async () => {
    const row = hists.find((h) => h._key === activeHistKey);
    const idx = row?.idx;
    if (!idx) {
      mesToast(MES.selectRow, "warn");
      return;
    }
    await validateDeleteHealthCert([{ idx }]);
    const ok = await mesConfirm(MES.deleteConfirm("보건증 이력"));
    if (!ok) return;
    await deleteHealthCert([{ idx }]);
    mesToast(MES.deleteDone, "success");
    await Promise.all([loadHist(activeUserId), loadEmps()]);
  }, [activeHistKey, activeUserId, hists, loadEmps, loadHist]);

  const openMgr = useCallback(async () => {
    const [list, c] = await Promise.all([listHealthCertMgrs(), fetchHealthCertCan()]);
    setMgrs(list);
    setAlarm1(c?.alarmDay1 ?? 30);
    setAlarm2(c?.alarmDay2 ?? 7);
    setAlarm3(c?.alarmDay3 ?? 1);
    setMgrOpen(true);
  }, []);

  const addMgr = useCallback(async () => {
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
  }, [openModal]);

  const saveMgr = useCallback(async () => {
    await saveHealthCertMgrs({
      userIds: mgrs.map((m) => m.userId),
      alarmDay1: alarm1,
      alarmDay2: alarm2,
      alarmDay3: alarm3,
    });
    mesToast(MES.saveDone, "success");
    setMgrOpen(false);
    await refresh();
  }, [alarm1, alarm2, alarm3, mgrs, refresh]);

  const loadCal = useCallback(async (ym: string) => {
    const y = Number(ym.slice(0, 4));
    const m = Number(ym.slice(4, 6));
    const from = `${ym}01`;
    const last = new Date(Date.UTC(y, m, 0)).getUTCDate();
    const to = `${ym}${String(last).padStart(2, "0")}`;
    setCalRows(await listHealthCertCalendar(from, to));
  }, []);

  useEffect(() => {
    if (calOn && isMgr) void asyncAct.run(() => loadCal(month), "search");
  }, [calOn, isMgr, month]);

  const histCols = useMemo(() => buildHistColumns((row) => { void handleView(row); }), [handleView]);
  const empCols = useMemo(() => buildEmpColumns(), []);
  const ym = useMemo(() => parseYearMonth(month), [month]);
  const cells = useMemo(() => buildMonthCells(ym.year, ym.month), [ym]);
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
    save: canWrite ? () => asyncAct.run(handleUpload, "save") : undefined,
    del: canDelete && isMgr ? () => asyncAct.run(handleDelete, "del") : undefined,
  });

  return (
    <div className={pageRootClass}>
      <PageCard
        search={(
          <SearchArea
            // 조회·임박 체크 — flushSync 뒤 최신 expiring 으로 다시 읽는다
            onSearch={() => { void asyncAct.run(refresh, "search"); }}
            actions={(
              <>
                <SearchButton
                  // 조회 busy 스피너
                  loading={asyncAct.isBusy("search")}
                />
                {canAssign ? (
                  <MesButton
                    variant="secondary"
                    onClick={() => void asyncAct.run(openMgr, "search")}
                  >
                    담당자 추가
                  </MesButton>
                ) : null}
                {isMgr ? (
                  <MesButton variant="secondary" onClick={() => setCalOn((v) => !v)}>
                    {calOn ? "목록 보기" : "캘린더 뷰"}
                  </MesButton>
                ) : null}
              </>
            )}
          >
            <SearchCheckbox
              // 임박 창은 설정 3값의 최댓값. 7일 고정이 아니다
              label={expiringLabel(can?.expireWindowDays)}
              checked={expiring}
              onChange={setExpiring}
            />
          </SearchArea>
        )}
      >
        <p className="mb-2 text-xs text-slate-500">
          식품위생법 제40조 건강진단 이행 관리. 주민번호는 저장하지 않습니다.
          뒷자리가 보이게 올리지 마세요. 가린 PDF 사본만 등록합니다. 담당자만 열람·삭제합니다.
          새 보건증으로 대체된 이전 이력은 만료일로부터 2년 후 삭제됩니다.
        </p>
        {notis.length > 0 ? (
          <div className="mb-2 rounded border border-amber-300 bg-amber-50 px-3 py-2 text-sm">
            {notis.map((n) => (
              <button
                key={n.idx}
                type="button"
                className="block w-full text-left"
                onClick={() => {
                  if (n.idx) void readNotification(n.idx).then(loadNotis);
                }}
              >
                {n.title}
              </button>
            ))}
          </div>
        ) : null}

        {calOn && isMgr ? (
          <div className="min-h-0 flex-1">
            <div className="mb-2 flex items-center gap-2">
              <MesButton onClick={() => setMonth(shiftYearMonth(month, -1))}><ChevronLeft size={16} /></MesButton>
              <b>{month.slice(0, 4)}-{month.slice(4)}</b>
              <MesButton onClick={() => setMonth(shiftYearMonth(month, 1))}><ChevronRight size={16} /></MesButton>
            </div>
            <div className="grid grid-cols-7 gap-1 text-xs">
              {WEEKDAY_LABELS.map((w) => <div key={w} className="text-center font-semibold">{w}</div>)}
              {cells.map((c) => (
                <div key={c.ymd} className={`min-h-20 rounded border p-1 ${c.inMonth ? "" : "opacity-40"}`}>
                  <div>{c.day}</div>
                  {(byDay.get(c.ymd) ?? []).map((r) => (
                    <div key={r.userId} className="truncate rounded bg-sky-100 px-1">{r.userNm}</div>
                  ))}
                </div>
              ))}
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
                  rows={emps as EditableRow<HealthCertEmp>[]}
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
                    onSave={canWrite && activeUserId ? handleUpload : undefined}
                    onDel={canDelete && isMgr && activeUserId ? handleDelete : undefined}
                    busy={{ save: asyncAct.isBusy("save"), del: asyncAct.isBusy("del") }}
                  />
                </div>
                {activeUserId ? (
                  <div className="flex flex-wrap items-end gap-2 px-2 py-1 text-sm">
                    <label>등록일
                      <input
                        type="date"
                        // DB varchar(8) YYYYMMDD. type=date 는 10자, 저장 때 fromInputDate
                        className="ml-1 border px-1"
                        value={regDt}
                        onChange={(e) => setRegDt(e.target.value)}
                      />
                    </label>
                    <label>만료일
                      <input
                        type="date"
                        // 만료일 8자리. 알림·파기 기준. 화면 10자를 그대로 보내면 22001
                        className="ml-1 border px-1"
                        value={expireDt}
                        onChange={(e) => setExpireDt(e.target.value)}
                      />
                    </label>
                    <input
                      type="file"
                      // PDF 만 — 원본 서명을 깨지 않으려고 이미지를 받지 않는다
                      accept=".pdf,application/pdf"
                      onChange={(e) => setFile(e.target.files?.[0] ?? null)}
                    />
                    <label className="flex items-center gap-1">
                      <input
                        type="checkbox"
                        // 미체크면 저장 거절. OCR 없이 업로드 책임을 남긴다
                        checked={maskedYn}
                        onChange={(e) => setMaskedYn(e.target.checked)}
                      />
                      주민번호 뒷자리를 가린 뒤 올렸습니다
                    </label>
                  </div>
                ) : (
                  <div className="px-2 py-1 text-sm text-neutral-500">왼쪽에서 사원을 선택하세요.</div>
                )}
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
                  loading={asyncAct.isBusy("search")}
                  emptyHint="왼쪽에서 사원을 선택하세요."
                  activeKey={activeHistKey}
                  onActivate={(row) => setActiveHistKey(String(row._key ?? ""))}
                  access={histGrid.access}
                  onLockedAttempt={histGrid.onLockedAttempt}
                  onSetActive={() => sec.setSec("d")}
                  showRowNum
                />
              </div>
            )}
          />
        )}
      </PageCard>

      {mgrOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30">
          <div className="w-[480px] rounded bg-white p-4 shadow">
            <b>보건증 담당자</b>
            <div className="mt-2 max-h-48 overflow-auto border">
              {mgrs.map((m) => (
                <div key={m.userId} className="flex items-center justify-between px-2 py-1 text-sm">
                  <span>{m.userNm} ({m.deptNm || m.userId})</span>
                  <button type="button" onClick={() => setMgrs((p) => p.filter((x) => x.userId !== m.userId))}>제외</button>
                </div>
              ))}
            </div>
            <MesButton className="mt-2" onClick={() => void addMgr()}>직원 추가</MesButton>
            <div className="mt-3 flex flex-wrap gap-2 text-sm">
              <label>일 전 <input type="number" min={1} className="w-16 border px-1" value={alarm1} onChange={(e) => setAlarm1(Number(e.target.value))} /></label>
              <label>일 전 <input type="number" min={1} className="w-16 border px-1" value={alarm2} onChange={(e) => setAlarm2(Number(e.target.value))} /></label>
              <label>일 전 <input type="number" min={1} className="w-16 border px-1" value={alarm3} onChange={(e) => setAlarm3(Number(e.target.value))} /></label>
            </div>
            <div className="mt-3 flex justify-end gap-2">
              <MesButton onClick={() => setMgrOpen(false)}>취소</MesButton>
              <MesButton onClick={() => void asyncAct.run(saveMgr, "save")}>저장</MesButton>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
