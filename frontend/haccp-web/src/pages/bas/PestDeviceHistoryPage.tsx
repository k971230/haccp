/**
 * PestDeviceHistoryPage — 방충설비(포충등·트랩) 이력 M-D 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) mes-web SoPage와 동일 — PageCardSplit 상·하 + 패널별 GridCrudButtons
 *   2) 셸 단축키만 useSection 활성 그리드로 라우팅한다
 *   3) 이력 삭제는 validate-delete → 확인 → delete → 재조회 순서를 지킨다
 *
 * PIPELINE[HF126] 방충설비이력 화면
 * PIPELINE[HF125, HF84, HF29, HF39, HF51] 연관 모듈
 */
// 역할 — 상태·콜백·메모·초기 로드
import { useCallback, useEffect, useMemo, useState } from "react";
// 역할 — 화면별 조회·등록·수정·삭제 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 중복 클릭 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — 그리드 잠금 훅
import { useGridAccess } from "@/hooks/useGridAccess";
// 역할 — 편집 행 상태
import { useEditableRows } from "@/hooks/useEditableRows";
// 역할 — 편집 그리드
import { MesEditableGrid } from "@/components/grid/MesEditableGrid";
// 역할 — 패널 헤더 행추가·저장·삭제 (SoPage와 동일)
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
// 역할 — mes-web 페이지 카드·상하 분할
import { PageCard, PageCardSplit } from "@/components/layout/PageCard";
import { PageHead, SearchArea, SearchButton } from "@/components/layout/SearchArea";
import { gridHeadClass, gridPanelClass, pageRootClass } from "@/components/layout/pageClasses";
// 역할 — 확인창·성공 및 오류 토스트
import { mesConfirm, mesConfirmDanger, mesToast } from "@/shell/dialog";
// 역할 — 서버 예외를 업무 문구로 변환
import { mesError } from "@/shell/errors";
// 역할 — 공통 저장·삭제·필수 안내 문구
import { MES } from "@/shell/messages";
// 역할 — 셸 상단·단축키 CRUD 명령 등록
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — M-D 활성 섹션(h/d) — 셸 CRUD 라우팅
import { useSection } from "@/shell/useSection";
// 역할 — 선택행 우선 삭제 대상
import { resolveRowsForDelete } from "@/shell/resolveDelete";
// 역할 — 그리드·편집 행 타입
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
// 역할 — 방충설비 마스터 목록·저장·삭제
import {
  deleteMasterRows,
  listMasterRows,
  saveMasterRow,
  validateDeleteMasterRows,
  type MasterRow,
} from "@/api/masterApi";
// 역할 — 방충설비 이력 CRUD
import {
  deletePestDeviceHist,
  listPestDeviceHist,
  savePestDeviceHist,
  validateDeletePestDeviceHist,
  type PestDeviceHistRow,
} from "@/api/pestDeviceHistApi";

const SCREEN_CODE = "pest-device-history";

type PestRow = MasterRow & {
  idx?: number | null;
  pestCd?: string | null;
  pestNm?: string | null;
  pestType?: string | null;
  placeNm?: string | null;
  sortNo?: number | null;
  useYn?: string | null;
  _key?: string;
  _rowState?: string;
};
type HistRow = PestDeviceHistRow & { _key?: string; _rowState?: string };

/** 오늘 YYYYMMDD */
function todayYmd(): string {
  return new Date().toISOString().slice(0, 10).replace(/-/g, "");
}

/** YYYYMMDD → input date(YYYY-MM-DD) */
function toDateInput(ymd: unknown): string {
  const s = String(ymd ?? "").replace(/-/g, "");
  return s.length === 8 ? `${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6)}` : String(ymd ?? "");
}

/** input date → YYYYMMDD */
function fromDateInput(value: unknown): string {
  return String(value ?? "").replace(/-/g, "");
}

/** 방충설비 저장 payload — 마스터 전 필드 */
function toPestSaveRow(row: EditableRow<PestRow>): MasterRow {
  const sortNum = row.sortNo == null || String(row.sortNo).trim() === ""
    ? null
    : Number(row.sortNo);
  const next: MasterRow = {
    pestCd: String(row.pestCd ?? "").trim() || null,
    pestNm: String(row.pestNm ?? "").trim() || null,
    pestType: String(row.pestType ?? "").trim() || null,
    placeNm: String(row.placeNm ?? "").trim() || null,
    sortNo: sortNum != null && Number.isFinite(sortNum) ? sortNum : null,
    useYn: String(row.useYn ?? "Y").trim() || "Y",
  };
  // 수정 행일 때(= 대리키 있음) SP UPDATE 대상
  if (row.idx != null && Number(row.idx) > 0 && row._rowState !== "C") {
    next.idx = Number(row.idx);
  }
  return next;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 방충설비 마스터와 이력 그리드를 상·하로 렌더링한다
 *   2) screenRegistry pest-device-history 키로 마운트한다
 *   3) API·권한 실패는 업무 토스트만 표시한다
 */
export default function PestDeviceHistoryPage() {
  const canWrite = useAuthStore((state) => state.can(SCREEN_CODE, "write"));
  const canModify = useAuthStore((state) => state.can(SCREEN_CODE, "modify"));
  const canDelete = useAuthStore((state) => state.can(SCREEN_CODE, "delete"));
  const asyncAct = useAsyncAction();
  // M-D 활성 섹션 — 패널 bind·셸 CRUD (SoPage sec)
  const sec = useSection();

  const [pestActiveKey, setPestActiveKey] = useState<string | null>(null);
  const [selectedPestIdx, setSelectedPestIdx] = useState<number | null>(null);
  const [selectedPestLabel, setSelectedPestLabel] = useState("");

  const [histActiveKey, setHistActiveKey] = useState<string | null>(null);
  const [pestSelKeys, setPestSelKeys] = useState<string[]>([]);
  const [histSelKeys, setHistSelKeys] = useState<string[]>([]);
  const [pestSelReset, setPestSelReset] = useState(0);
  const [histSelReset, setHistSelReset] = useState(0);
  const clearPestSel = () => { setPestSelKeys([]); setPestSelReset((n) => n + 1); };
  const clearHistSel = () => { setHistSelKeys([]); setHistSelReset((n) => n + 1); };

  const pest = useEditableRows<PestRow>("idx");
  const hist = useEditableRows<HistRow>("idx");

  const pestGrid = useGridAccess({ newOnly: ["pestCd"] }, {
    scrnCd: SCREEN_CODE,
    gridRole: "master",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });
  const histGrid = useGridAccess({ newOnly: [] }, {
    scrnCd: SCREEN_CODE,
    gridRole: "detail",
    readOnly: !canModify && !canWrite,
    parentRow: selectedPestIdx != null ? { idx: selectedPestIdx } : null,
    extra: { canWrite, canModify, canDelete },
  });

  const pestEditable = canWrite || canModify;

  const pestColumns = useMemo<GridColumn<PestRow>[]>(() => {
    const pestTypeMap: Record<string, string> = { LAMP: "포충등", ROACH: "바퀴트랩", RAT: "쥐트랩" };
    const useYnMap: Record<string, string> = { Y: "사용", N: "미사용" };
    return [
      { field: "pestCd", header: "설비코드", width: 110, required: true, editable: pestEditable },
      { field: "pestNm", header: "설비명", width: 140, required: true, editable: pestEditable },
      {
        field: "pestType",
        header: "유형",
        width: 100,
        required: true,
        editable: pestEditable,
        type: "code",
        codeOptions: [
          { value: "LAMP", label: "포충등" },
          { value: "ROACH", label: "바퀴트랩" },
          { value: "RAT", label: "쥐트랩" },
        ],
        codeMap: pestTypeMap,
      },
      { field: "placeNm", header: "설치 위치", width: 140, editable: pestEditable },
      { field: "sortNo", header: "정렬", width: 80, type: "number", editable: pestEditable },
      {
        field: "useYn",
        header: "사용",
        width: 70,
        editable: pestEditable,
        type: "code",
        codeOptions: [{ value: "Y", label: "사용" }, { value: "N", label: "미사용" }],
        codeMap: useYnMap,
      },
    ];
  }, [pestEditable]);

  const histColumns = useMemo<GridColumn<HistRow>[]>(() => {
    const editable = canWrite || canModify;
    return [
      { field: "histDt", header: "이력일", width: 120, type: "date", required: true, editable },
      { field: "faultRmk", header: "이상·포획", width: 220, editable },
      { field: "actionRmk", header: "조치내용", width: 220, editable },
      { field: "remark", header: "비고", width: 180, editable },
    ];
  }, [canModify, canWrite]);

  const loadPest = useCallback(async () => {
    try {
      const rows = await listMasterRows("pest-device", {});
      const next = rows.map((row) => ({
        ...row,
        idx: row.idx != null ? Number(row.idx) : null,
      }));
      pest.load(next);
      if (selectedPestIdx != null) {
        const hit = next.find((row) => Number(row.idx) === selectedPestIdx);
        setPestActiveKey(hit ? String(hit.idx) : null);
        if (!hit) {
          setSelectedPestIdx(null);
          setSelectedPestLabel("");
          hist.load([]);
        }
      }
    } catch (error) {
      mesError(error);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- pest.load·hist.load 안정 참조
  }, [selectedPestIdx]);

  const loadHist = useCallback(async (pestIdx: number | null) => {
    if (pestIdx == null || pestIdx <= 0) {
      hist.load([]);
      setHistActiveKey(null);
      clearHistSel();
      return;
    }
    try {
      const rows = await listPestDeviceHist(pestIdx);
      hist.load(rows.map((row) => ({
        ...row,
        histDt: toDateInput(row.histDt),
      })));
      setHistActiveKey(null);
      clearHistSel();
    } catch (error) {
      mesError(error);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- hist.load 안정 참조
  }, []);

  useEffect(() => {
    void loadPest();
  }, [loadPest]);

  const handleSelectPest = async (row: PestRow) => {
    sec.setSec("h");
    sec.reset();
    setPestActiveKey(row._key ?? null);
    const nextIdx = Number(row.idx);
    if (row._rowState === "C" || !Number.isFinite(nextIdx) || nextIdx <= 0) {
      if (hist.getSaveRows().length > 0) {
        if (!(await mesConfirm("저장하지 않은 이력이 있습니다. 설비를 바꾸시겠습니까?"))) return;
      }
      setSelectedPestIdx(null);
      setSelectedPestLabel(`${String(row.pestCd ?? "")} ${String(row.pestNm ?? "")}`.trim() || "신규 방충설비");
      hist.load([]);
      setHistActiveKey(null);
      clearHistSel();
      return;
    }
    if (nextIdx === selectedPestIdx) return;
    if (hist.getSaveRows().length > 0) {
      if (!(await mesConfirm("저장하지 않은 이력이 있습니다. 설비를 바꾸시겠습니까?"))) return;
    }
    setSelectedPestIdx(nextIdx);
    setSelectedPestLabel(`${String(row.pestCd ?? "")} ${String(row.pestNm ?? "")}`.trim());
    await loadHist(nextIdx);
  };

  const handleAddPest = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    sec.setSec("h");
    const key = pest.addRow({
      pestCd: "",
      pestNm: "",
      pestType: "LAMP",
      placeNm: "",
      sortNo: null,
      useYn: "Y",
    });
    setPestActiveKey(key);
    setSelectedPestIdx(null);
    setSelectedPestLabel("신규 방충설비");
    hist.load([]);
    setHistActiveKey(null);
    clearHistSel();
  };

  const handleAddHist = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    if (selectedPestIdx == null) return mesToast("이력을 추가할 방충설비를 먼저 저장·선택하세요.", "warn");
    sec.setSec("d");
    setHistActiveKey(hist.addRow({
      pestIdx: selectedPestIdx,
      histDt: toDateInput(todayYmd()),
      faultRmk: "",
      actionRmk: "",
      remark: "",
    }));
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 상단 방충설비 변경행만 저장한다 — 패널 GridCrudButtons 고정 타겟
   *   2) 마스터 패널 저장·셸(sec=h)에서 호출한다
   *   3) 권한·필수값 실패는 토스트만
   */
  const savePest = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    const dirty = pest.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    for (const row of dirty) {
      if (!String(row.pestCd ?? "").trim()) {
        mesToast(MES.required("설비코드"), "warn");
        setPestActiveKey(row._key);
        return;
      }
      if (!String(row.pestNm ?? "").trim()) {
        mesToast(MES.required("설비명"), "warn");
        setPestActiveKey(row._key);
        return;
      }
      if (!String(row.pestType ?? "").trim()) {
        mesToast(MES.required("유형"), "warn");
        setPestActiveKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      let lastIdx: number | null = selectedPestIdx;
      let lastLabel = selectedPestLabel;
      for (const row of dirty) {
        const saved = await saveMasterRow("pest-device", toPestSaveRow(row));
        const idx = saved.idx != null ? Number(saved.idx) : null;
        if (idx != null && Number.isFinite(idx) && idx > 0) {
          lastIdx = idx;
          lastLabel = `${String(saved.pestCd ?? row.pestCd ?? "")} ${String(saved.pestNm ?? row.pestNm ?? "")}`.trim();
        }
      }
      mesToast(MES.saveDone, "success");
      await loadPest();
      if (lastIdx != null) {
        setSelectedPestIdx(lastIdx);
        setSelectedPestLabel(lastLabel);
        setPestActiveKey(String(lastIdx));
        await loadHist(lastIdx);
      }
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 하단 이력 변경행만 저장한다 — 패널 GridCrudButtons 고정 타겟
   *   2) 상세 패널 저장·셸(sec=d)에서 호출한다
   *   3) 설비 미선택·필수값 실패는 토스트만
   */
  const saveHist = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    if (selectedPestIdx == null) return mesToast("방충설비를 선택하세요.", "warn");
    const dirty = hist.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    for (const row of dirty) {
      if (!fromDateInput(row.histDt)) {
        mesToast(MES.required("이력일"), "warn");
        setHistActiveKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      const payload: PestDeviceHistRow[] = dirty.map((row) => ({
        idx: row._rowState === "C" ? null : (row.idx != null ? Number(row.idx) : null),
        pestIdx: selectedPestIdx,
        histDt: fromDateInput(row.histDt),
        faultRmk: String(row.faultRmk ?? "").trim() || null,
        actionRmk: String(row.actionRmk ?? "").trim() || null,
        remark: String(row.remark ?? "").trim() || null,
      }));
      await savePestDeviceHist(payload);
      mesToast(MES.saveDone, "success");
      await loadHist(selectedPestIdx);
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 상단 방충설비 선택행 삭제 — validate-delete·확인·delete
   *   2) 마스터 패널 삭제·셸(sec=h)에서 호출한다
   *   3) 참조 차단은 업무 토스트만
   */
  const delPest = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(pest.rows, pestActiveKey, setPestActiveKey, pestSelKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");
    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    let lastFocus = pestActiveKey;
    for (const row of newRows) {
      const { focusKey } = pest.removeNewRow(row._key);
      lastFocus = focusKey;
    }
    if (newRows.length > 0) {
      setPestActiveKey(lastFocus);
      clearPestSel();
      if (selectedPestIdx == null) {
        setSelectedPestLabel("");
        hist.load([]);
      }
    }
    if (persisted.length === 0) return;
    const keys = persisted
      .map((row) => Number(row.idx))
      .filter((idx) => Number.isFinite(idx) && idx > 0)
      .map((idx) => ({ idx }));
    if (keys.length === 0) return mesToast("삭제할 행의 키가 올바르지 않습니다.", "warn");
    const label = String(persisted[0].pestNm ?? persisted[0].pestCd ?? "방충설비");
    try {
      await validateDeleteMasterRows("pest-device", keys);
      if (!(await mesConfirmDanger(MES.deleteConfirm(label)))) return;
      await deleteMasterRows("pest-device", keys);
      clearPestSel();
      mesToast(MES.deleteDone, "success");
      const removedSelected = keys.some((k) => Number(k.idx) === selectedPestIdx);
      if (removedSelected) {
        setSelectedPestIdx(null);
        setSelectedPestLabel("");
        hist.load([]);
      }
      await loadPest();
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 하단 이력 선택행 삭제 — validate-delete·확인·delete·재조회
   *   2) 상세 패널 삭제·셸(sec=d)에서 호출한다
   *   3) 참조 차단은 업무 토스트만
   */
  const delHist = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(hist.rows, histActiveKey, setHistActiveKey, histSelKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");
    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    let lastFocus = histActiveKey;
    for (const row of newRows) {
      const { focusKey } = hist.removeNewRow(row._key);
      lastFocus = focusKey;
    }
    if (newRows.length > 0) {
      setHistActiveKey(lastFocus);
      clearHistSel();
    }
    if (persisted.length === 0) return;
    const keys = persisted
      .map((row) => Number(row.idx))
      .filter((idx) => Number.isFinite(idx) && idx > 0)
      .map((idx) => ({ idx }));
    if (keys.length === 0) return mesToast("삭제할 행의 키가 올바르지 않습니다.", "warn");
    try {
      await validateDeletePestDeviceHist(keys);
      if (!(await mesConfirmDanger(MES.deleteConfirm(selectedPestLabel || "이력")))) return;
      await deletePestDeviceHist(keys);
      clearHistSel();
      mesToast(MES.deleteDone, "success");
      await loadHist(selectedPestIdx);
    } catch (error) {
      mesError(error);
    }
  };

  const doSearch = () => asyncAct.run(async () => {
    sec.reset();
    await loadPest();
    await loadHist(selectedPestIdx);
  }, "search");

  // 셸 단축키 — 활성 섹션으로만 라우팅 (패널 버튼은 고정 타겟)
  usePageCommands({
    search: () => { void doSearch(); },
    add: () => { if (sec.is("d")) handleAddHist(); else handleAddPest(); },
    save: () => { void asyncAct.run(sec.is("d") ? saveHist : savePest, "save"); },
    del: () => { void asyncAct.run(sec.is("d") ? delHist : delPest, "del"); },
  });

  return (
    <div className={pageRootClass}>
      <PageHead
        // 화면 제목 — mes-web SoPage와 동일 슬롯
        title="방충설비 이력"
      />
      <PageCard
        // 조회만 검색 카드 — CRUD는 각 그리드 헤더
        search={(
          <SearchArea
            onSearch={() => { void doSearch(); }}
            actions={(
              <SearchButton
                // 조회 busy 스피너
                loading={asyncAct.isBusy("search")}
              />
            )}
          />
        )}
      >
        <PageCardSplit storageKey="haccp-split-pest-device-hist">
          <div {...sec.bind("h", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>방충설비</b>
              <GridCrudButtons
                // useAsyncAction.run — busy 키 래핑
                run={asyncAct.run}
                // 상단 마스터 전용 행추가
                onAdd={canWrite ? handleAddPest : undefined}
                // 상단 마스터 전용 저장
                onSave={canWrite || canModify ? savePest : undefined}
                // 상단 마스터 전용 삭제
                onDel={canDelete ? delPest : undefined}
                busy={{
                  save: asyncAct.isBusy("save"),
                  del: asyncAct.isBusy("del"),
                }}
              />
            </div>
            <MesEditableGrid
              // 열 설정 저장 키 — 방충설비 마스터(상단)
              persistId="bas-pest-device-history-master"
              // CSV·오류경계 라벨 — 패널 제목과 동일
              title="방충설비"
              // 방충설비 행
              rows={pest.rows as EditableRow<PestRow>[]}
              // 코드·명칭·유형·위치
              columns={pestColumns}
              // 등록·수정 권한일 때 편집
              editable={pestEditable}
              // 패널 높이 채움 — 제목은 gridHeadClass
              height="100%"
              loading={asyncAct.isBusy("search")}
              activeKey={pestActiveKey}
              onActivate={(row) => { void handleSelectPest(row); }}
              onCellChange={(key, field, value) => pest.updateCell(key, field as keyof PestRow, value)}
              access={pestGrid.access}
              onLockedAttempt={pestGrid.onLockedAttempt}
              // 셸 CRUD 타겟을 마스터로
              onSetActive={() => sec.setSec("h")}
              selectable
              onSelectionChange={(rows) => setPestSelKeys(rows.map((row) => row._key))}
              selectionResetKey={pestSelReset}
              showRowNum
            />
          </div>

          <div {...sec.bind("d", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>
                방충 이력
                {selectedPestLabel ? ` (${selectedPestLabel})` : ""}
              </b>
              <GridCrudButtons
                run={asyncAct.run}
                onAdd={canWrite ? handleAddHist : undefined}
                onSave={canWrite || canModify ? saveHist : undefined}
                onDel={canDelete ? delHist : undefined}
                busy={{
                  save: asyncAct.isBusy("save"),
                  del: asyncAct.isBusy("del"),
                }}
              />
            </div>
            <MesEditableGrid
              // 열 설정 저장 키 — 이력(하단)
              persistId="bas-pest-device-history-detail"
              // CSV·오류경계 라벨 — 패널 제목과 동일
              title="방충 이력"
              rows={hist.rows as EditableRow<HistRow>[]}
              columns={histColumns}
              editable={canWrite || canModify}
              height="100%"
              loading={asyncAct.isBusy("search") || asyncAct.isBusy("save") || asyncAct.isBusy("del")}
              activeKey={histActiveKey}
              onActivate={(row) => {
                sec.setSec("d");
                setHistActiveKey(row._key);
              }}
              onCellChange={(key, field, value) => hist.updateCell(key, field as keyof HistRow, value)}
              access={histGrid.access}
              onLockedAttempt={histGrid.onLockedAttempt}
              onSetActive={() => sec.setSec("d")}
              selectable
              onSelectionChange={(rows) => setHistSelKeys(rows.map((row) => row._key))}
              selectionResetKey={histSelReset}
              showRowNum
            />
          </div>
        </PageCardSplit>
      </PageCard>
    </div>
  );
}
