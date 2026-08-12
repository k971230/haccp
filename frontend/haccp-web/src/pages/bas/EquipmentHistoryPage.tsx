/**
 * EquipmentHistoryPage — 설비카드 이력 M-D 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) mes-web SoPage와 동일 — PageCardSplit 상·하 + 패널별 GridCrudButtons
 *   2) 셸 단축키만 useSection 활성 그리드로 라우팅한다
 *   3) 설비 사진은 photoPath 셀 버튼으로 고른 뒤 마스터 저장 시 업로드한다
 *
 * PIPELINE[HF125] 설비이력 화면
 * PIPELINE[HF124, HF84, HF29, HF39, HF51] 연관 모듈
 */
// 역할 — 상태·콜백·메모·초기 로드·DOM 참조
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
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
import { mesConfirm, mesToast } from "@/shell/dialog";
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
// 역할 — 설비 마스터 목록·저장·삭제·사진
import {
  deleteMasterRows,
  listMasterRows,
  saveMasterRow,
  uploadEquipmentPhoto,
  validateDeleteMasterRows,
  type MasterRow,
} from "@/api/masterApi";
// 역할 — 설비 이력 CRUD
import {
  deleteEquipmentHist,
  listEquipmentHist,
  saveEquipmentHist,
  validateDeleteEquipmentHist,
  type EquipmentHistRow,
} from "@/api/equipmentHistApi";

const SCREEN_CODE = "equipment-history";

type EquipRow = MasterRow & {
  idx?: number | null;
  equipCd?: string | null;
  equipNm?: string | null;
  equipKind?: string | null;
  purposeNm?: string | null;
  modelNm?: string | null;
  specNm?: string | null;
  makerNm?: string | null;
  madeCountry?: string | null;
  buyDt?: string | null;
  installDt?: string | null;
  useRange?: string | null;
  placeNm?: string | null;
  asMngNm?: string | null;
  photoPath?: string | null;
  useMethod?: string | null;
  useYn?: string | null;
  _key?: string;
  _rowState?: string;
};
type HistRow = EquipmentHistRow & { _key?: string; _rowState?: string };

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

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 설비 마스터 저장 payload를 만든다 — 부분 저장 시 NULL 덮어쓰기 방지
 *   2) 마스터 저장·사진 업로드 직전 호출한다
 *   3) pendingPhoto가 있을 때(= 셀에서만 파일 선택) 표시용 파일명을 photo_path에 넣지 않고 기존 경로를 유지한다
 */
function toEquipSaveRow(
  // 편집 그리드 행
  row: EditableRow<EquipRow>,
  // 셀에서 고른 대기 파일이 있으면 true — photoPath 표시명 제외
  hasPendingPhoto: boolean,
): MasterRow {
  // 대기 사진일 때(= 아직 서버 경로 아님) 원본 photoPath 유지, 없으면 셀 값
  const photoPath = hasPendingPhoto
    ? (String((row._original as EquipRow | undefined)?.photoPath ?? "").trim() || null)
    : (String(row.photoPath ?? "").trim() || null);
  const next: MasterRow = {
    equipCd: String(row.equipCd ?? "").trim() || null,
    equipNm: String(row.equipNm ?? "").trim() || null,
    equipKind: String(row.equipKind ?? "").trim() || null,
    purposeNm: String(row.purposeNm ?? "").trim() || null,
    modelNm: String(row.modelNm ?? "").trim() || null,
    specNm: String(row.specNm ?? "").trim() || null,
    makerNm: String(row.makerNm ?? "").trim() || null,
    madeCountry: String(row.madeCountry ?? "").trim() || null,
    buyDt: fromDateInput(row.buyDt) || null,
    installDt: fromDateInput(row.installDt) || null,
    useRange: String(row.useRange ?? "").trim() || null,
    placeNm: String(row.placeNm ?? "").trim() || null,
    asMngNm: String(row.asMngNm ?? "").trim() || null,
    photoPath,
    useMethod: String(row.useMethod ?? "").trim() || null,
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
 *   1) 설비 마스터와 이력 그리드를 상·하로 렌더링한다
 *   2) screenRegistry equipment-history 키로 마운트한다
 *   3) API·권한 실패는 업무 토스트만 표시한다
 */
export default function EquipmentHistoryPage() {
  const canWrite = useAuthStore((state) => state.can(SCREEN_CODE, "write"));
  const canModify = useAuthStore((state) => state.can(SCREEN_CODE, "modify"));
  const canDelete = useAuthStore((state) => state.can(SCREEN_CODE, "delete"));
  const asyncAct = useAsyncAction();
  // M-D 활성 섹션 — 패널 bind·셸 CRUD (SoPage sec)
  const sec = useSection();

  const [equipActiveKey, setEquipActiveKey] = useState<string | null>(null);
  const [selectedEquipIdx, setSelectedEquipIdx] = useState<number | null>(null);
  const [selectedEquipLabel, setSelectedEquipLabel] = useState("");

  const [histActiveKey, setHistActiveKey] = useState<string | null>(null);
  const [equipSelKeys, setEquipSelKeys] = useState<string[]>([]);
  const [histSelKeys, setHistSelKeys] = useState<string[]>([]);
  const [equipSelReset, setEquipSelReset] = useState(0);
  const [histSelReset, setHistSelReset] = useState(0);
  const clearEquipSel = () => { setEquipSelKeys([]); setEquipSelReset((n) => n + 1); };
  const clearHistSel = () => { setHistSelKeys([]); setHistSelReset((n) => n + 1); };

  // 행 _key → 셀에서 고른 File — 저장 시 idx 확보 후 업로드
  const pendingPhotosRef = useRef<Map<string, File>>(new Map());
  // 사진 선택 대상 행 키 — 숨김 file input onChange에서 사용
  const photoPickKeyRef = useRef<string | null>(null);
  // 설비 사진 선택 — 숨김 input (셀 버튼이 연다)
  const photoInputRef = useRef<HTMLInputElement | null>(null);

  const equip = useEditableRows<EquipRow>("idx");
  const hist = useEditableRows<HistRow>("idx");

  const equipGrid = useGridAccess({ newOnly: ["equipCd"] }, {
    scrnCd: SCREEN_CODE,
    gridRole: "master",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });
  const histGrid = useGridAccess({ newOnly: [] }, {
    scrnCd: SCREEN_CODE,
    // 하단 이력 — 선택 설비가 parentRow
    gridRole: "detail",
    readOnly: !canModify && !canWrite,
    // 저장된 설비가 있을 때(= 이력 편집 가능) parent 잠금 해제
    parentRow: selectedEquipIdx != null ? { idx: selectedEquipIdx } : null,
    extra: { canWrite, canModify, canDelete },
  });

  const equipEditable = canWrite || canModify;

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) photoPath 셀 버튼으로 파일을 고르고 행에 File·표시명을 보관한다
   *   2) 사진경로 열 … 버튼에서 호출한다
   *   3) 권한 없으면 토스트만 — 실제 업로드는 마스터 저장 때
   */
  const pickEquipPhoto = useCallback((row: EquipRow) => {
    if (!canWrite && !canModify) {
      mesToast("수정 권한이 없습니다.", "warn");
      return;
    }
    const key = String(row._key ?? "");
    if (!key) return;
    photoPickKeyRef.current = key;
    photoInputRef.current?.click();
  }, [canModify, canWrite]);

  const equipColumns = useMemo<GridColumn<EquipRow>[]>(() => [
    { field: "equipCd", header: "설비번호", width: 110, required: true, editable: equipEditable },
    { field: "equipNm", header: "설비명", width: 140, required: true, editable: equipEditable },
    { field: "equipKind", header: "종류", width: 100, editable: equipEditable },
    { field: "purposeNm", header: "용도", width: 120, editable: equipEditable },
    { field: "modelNm", header: "모델명", width: 110, editable: equipEditable },
    { field: "specNm", header: "규격", width: 110, editable: equipEditable },
    { field: "makerNm", header: "제조사", width: 100, editable: equipEditable },
    { field: "madeCountry", header: "제조국", width: 80, editable: equipEditable },
    { field: "buyDt", header: "구입일자", width: 110, type: "date", editable: equipEditable },
    { field: "installDt", header: "설치일자", width: 110, type: "date", editable: equipEditable },
    { field: "useRange", header: "사용범위", width: 100, editable: equipEditable },
    { field: "placeNm", header: "설치 위치", width: 120, editable: equipEditable },
    { field: "asMngNm", header: "A/S 담당", width: 100, editable: equipEditable },
    {
      // 표시용 경로·선택 파일명 — 수기 편집 금지, 셀 버튼으로만 선택
      field: "photoPath",
      header: "사진경로",
      width: 160,
      editable: false,
      // 셀 … 버튼 — 파일 선택 후 저장 시 업로드
      cellButton: equipEditable
        ? {
          title: "사진 선택",
          onClick: (row) => pickEquipPhoto(row),
        }
        : undefined,
    },
    { field: "useMethod", header: "사용방법", width: 180, editable: equipEditable },
    {
      field: "useYn",
      header: "사용",
      width: 70,
      editable: equipEditable,
      type: "code",
      codeOptions: [{ value: "Y", label: "사용" }, { value: "N", label: "미사용" }],
      codeMap: { Y: "사용", N: "미사용" },
    },
  ], [equipEditable, pickEquipPhoto]);

  const histColumns = useMemo<GridColumn<HistRow>[]>(() => {
    const editable = canWrite || canModify;
    return [
      { field: "histDt", header: "이력일", width: 120, type: "date", required: true, editable },
      { field: "faultRmk", header: "고장·이상", width: 220, editable },
      { field: "actionRmk", header: "조치내용", width: 220, editable },
      { field: "remark", header: "비고", width: 180, editable },
    ];
  }, [canModify, canWrite]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 설비 마스터 전체(사용/미사용)를 다시 읽는다
   *   2) 최초 진입·조회·설비 저장·삭제·사진 업로드 뒤 호출한다
   *   3) 실패하면 기존 행을 유지하고 오류 토스트만 표시한다
   */
  const loadEquip = useCallback(async () => {
    try {
      // useYn 미지정 — 미사용 설비도 이력 화면에서 관리
      const rows = await listMasterRows("equipment", {});
      const next = rows.map((row) => ({
        ...row,
        idx: row.idx != null ? Number(row.idx) : null,
        buyDt: toDateInput(row.buyDt),
        installDt: toDateInput(row.installDt),
      }));
      // 재조회 시 미저장 선택 파일은 버린다
      pendingPhotosRef.current.clear();
      equip.load(next);
      if (selectedEquipIdx != null) {
        const hit = next.find((row) => Number(row.idx) === selectedEquipIdx);
        setEquipActiveKey(hit ? String(hit.idx) : null);
        if (!hit) {
          setSelectedEquipIdx(null);
          setSelectedEquipLabel("");
          hist.load([]);
        }
      }
    } catch (error) {
      mesError(error);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- equip.load·hist.load 안정 참조
  }, [selectedEquipIdx]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 선택 설비의 이력 목록을 다시 읽는다
   *   2) 설비 선택·이력 저장·삭제 성공 뒤에 호출한다
   *   3) 설비가 없으면 빈 그리드로 비운다
   */
  const loadHist = useCallback(async (equipIdx: number | null) => {
    if (equipIdx == null || equipIdx <= 0) {
      hist.load([]);
      setHistActiveKey(null);
      clearHistSel();
      return;
    }
    try {
      const rows = await listEquipmentHist(equipIdx);
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
    void loadEquip();
  }, [loadEquip]);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 상단 설비 행을 고르고 하단 이력을 불러온다
   *   2) 미저장 이력이 있으면 확인 후 전환한다
   *   3) 미저장 신규 설비면 이력 영역을 비운다
   */
  const handleSelectEquip = async (row: EquipRow) => {
    sec.setSec("h");
    sec.reset();
    setEquipActiveKey(row._key ?? null);
    // 신규 draft 일 때(= 아직 idx 없음) 이력 로드 불가
    const nextIdx = Number(row.idx);
    if (row._rowState === "C" || !Number.isFinite(nextIdx) || nextIdx <= 0) {
      if (hist.getSaveRows().length > 0) {
        if (!(await mesConfirm("저장하지 않은 이력이 있습니다. 설비를 바꾸시겠습니까?"))) return;
      }
      setSelectedEquipIdx(null);
      setSelectedEquipLabel(`${String(row.equipCd ?? "")} ${String(row.equipNm ?? "")}`.trim() || "신규 설비");
      hist.load([]);
      setHistActiveKey(null);
      clearHistSel();
      return;
    }
    if (nextIdx === selectedEquipIdx) return;
    if (hist.getSaveRows().length > 0) {
      if (!(await mesConfirm("저장하지 않은 이력이 있습니다. 설비를 바꾸시겠습니까?"))) return;
    }
    setSelectedEquipIdx(nextIdx);
    setSelectedEquipLabel(`${String(row.equipCd ?? "")} ${String(row.equipNm ?? "")}`.trim());
    await loadHist(nextIdx);
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 상단 설비 마스터 행을 추가한다
   *   2) 「설비 추가」버튼·셸 추가(마스터 포커스)에서 호출한다
   *   3) 등록 권한 없으면 토스트만
   */
  const handleAddEquip = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    sec.setSec("h");
    const key = equip.addRow({
      equipCd: "",
      equipNm: "",
      equipKind: "",
      purposeNm: "",
      modelNm: "",
      specNm: "",
      makerNm: "",
      madeCountry: "",
      buyDt: "",
      installDt: "",
      useRange: "",
      placeNm: "",
      asMngNm: "",
      photoPath: "",
      useMethod: "",
      useYn: "Y",
    });
    setEquipActiveKey(key);
    setSelectedEquipIdx(null);
    setSelectedEquipLabel("신규 설비");
    hist.load([]);
    setHistActiveKey(null);
    clearHistSel();
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 선택 설비의 이력 행을 추가한다
   *   2) 「이력 추가」버튼·셸 추가(이력 포커스)에서 호출한다
   *   3) 저장된 설비 선택이 없으면 안내만
   */
  const handleAddHist = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    if (selectedEquipIdx == null) return mesToast("이력을 추가할 설비를 먼저 저장·선택하세요.", "warn");
    sec.setSec("d");
    setHistActiveKey(hist.addRow({
      equipIdx: selectedEquipIdx,
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
   *   1) 셀에서 고른 파일을 pending에 넣고 photoPath에 선택 파일명을 표시한다
   *   2) 숨김 file input onChange에서 호출한다
   *   3) 실제 업로드는 saveEquip에서 idx 확보 후 수행한다
   */
  const onPhotoFilePicked = (file: File | null) => {
    const key = photoPickKeyRef.current;
    photoPickKeyRef.current = null;
    if (!file || !key) return;
    if (!canWrite && !canModify) {
      mesToast("수정 권한이 없습니다.", "warn");
      return;
    }
    const row = equip.rows.find((r) => r._key === key);
    if (!row) {
      mesToast("사진을 등록할 설비를 선택하세요.", "warn");
      return;
    }
    pendingPhotosRef.current.set(key, file);
    // 표시용 — 저장 전까지 서버 경로가 아님을 구분
    equip.updateCell(key, "photoPath", `선택: ${file.name}`);
    setEquipActiveKey(key);
    mesToast("사진이 선택되었습니다. 저장 시 업로드됩니다.", "success");
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 상단 설비 변경행·사진 선택행을 저장하고 pending 사진은 idx 확보 후 업로드한다
   *   2) 마스터 패널 저장·셸(sec=h)에서 호출한다
   *   3) 신규 미저장 행도 저장 한 번에 사진까지 처리한다
   */
  const saveEquip = async () => {
    if (!canWrite && !canModify) return mesToast("수정 권한이 없습니다.", "warn");
    const dirtyMap = new Map(equip.getSaveRows().map((row) => [row._key, row]));
    // pending만 있는 행도 저장 대상에 포함
    for (const key of pendingPhotosRef.current.keys()) {
      if (!dirtyMap.has(key)) {
        const row = equip.rows.find((r) => r._key === key);
        if (row) dirtyMap.set(key, row);
      }
    }
    const dirty = [...dirtyMap.values()];
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    for (const row of dirty) {
      if (!String(row.equipCd ?? "").trim()) {
        mesToast(MES.required("설비번호"), "warn");
        setEquipActiveKey(row._key);
        return;
      }
      if (!String(row.equipNm ?? "").trim()) {
        mesToast(MES.required("설비명"), "warn");
        setEquipActiveKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      let lastIdx: number | null = selectedEquipIdx;
      let lastLabel = selectedEquipLabel;
      for (const row of dirty) {
        const key = String(row._key ?? "");
        const pending = key ? pendingPhotosRef.current.get(key) : undefined;
        const payload = toEquipSaveRow(row, Boolean(pending));
        const saved = await saveMasterRow("equipment", payload);
        // save API는 void 본문 — 신규면 업무키(equipCd)로 idx를 다시 찾는다
        let idx = saved.idx != null ? Number(saved.idx) : null;
        if ((!Number.isFinite(idx) || idx == null || idx <= 0) && row.idx != null) {
          idx = Number(row.idx);
        }
        if ((!Number.isFinite(idx) || idx == null || idx <= 0) && pending) {
          const list = await listMasterRows("equipment", {});
          const hit = list.find(
            (r) => String(r.equipCd ?? "").trim() === String(row.equipCd ?? "").trim(),
          );
          idx = hit?.idx != null ? Number(hit.idx) : null;
        }
        if (idx != null && Number.isFinite(idx) && idx > 0) {
          if (pending) {
            await uploadEquipmentPhoto(idx, pending);
            pendingPhotosRef.current.delete(key);
          }
          lastIdx = idx;
          lastLabel = `${String(saved.equipCd ?? row.equipCd ?? "")} ${String(saved.equipNm ?? row.equipNm ?? "")}`.trim();
        } else if (pending) {
          throw new Error("설비를 저장한 뒤 사진을 올릴 키를 찾지 못했습니다.");
        }
      }
      mesToast(MES.saveDone, "success");
      await loadEquip();
      if (lastIdx != null) {
        setSelectedEquipIdx(lastIdx);
        setSelectedEquipLabel(lastLabel);
        setEquipActiveKey(String(lastIdx));
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
    if (selectedEquipIdx == null) return mesToast("설비를 선택하세요.", "warn");
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
      const payload: EquipmentHistRow[] = dirty.map((row) => ({
        idx: row._rowState === "C" ? null : (row.idx != null ? Number(row.idx) : null),
        equipIdx: selectedEquipIdx,
        histDt: fromDateInput(row.histDt),
        faultRmk: String(row.faultRmk ?? "").trim() || null,
        actionRmk: String(row.actionRmk ?? "").trim() || null,
        remark: String(row.remark ?? "").trim() || null,
      }));
      await saveEquipmentHist(payload);
      mesToast(MES.saveDone, "success");
      await loadHist(selectedEquipIdx);
    } catch (error) {
      mesError(error);
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-10
   * 코멘트:
   *   1) 상단 설비 선택행 삭제 — validate-delete·확인·delete
   *   2) 마스터 패널 삭제·셸(sec=h)에서 호출한다
   *   3) 참조 차단은 업무 토스트만
   */
  const delEquip = async () => {
    if (!canDelete) return mesToast("삭제 권한이 없습니다.", "warn");
    const targets = resolveRowsForDelete(equip.rows, equipActiveKey, setEquipActiveKey, equipSelKeys);
    if (targets.length === 0) return mesToast(MES.selectRow, "warn");
    const newRows = targets.filter((row) => row._rowState === "C");
    const persisted = targets.filter((row) => row._rowState !== "C");
    let lastFocus = equipActiveKey;
    for (const row of newRows) {
      pendingPhotosRef.current.delete(String(row._key ?? ""));
      const { focusKey } = equip.removeNewRow(row._key);
      lastFocus = focusKey;
    }
    if (newRows.length > 0) {
      setEquipActiveKey(lastFocus);
      clearEquipSel();
      if (selectedEquipIdx == null) {
        setSelectedEquipLabel("");
        hist.load([]);
      }
    }
    if (persisted.length === 0) return;
    const keys = persisted
      .map((row) => Number(row.idx))
      .filter((idx) => Number.isFinite(idx) && idx > 0)
      .map((idx) => ({ idx }));
    if (keys.length === 0) return mesToast("삭제할 행의 키가 올바르지 않습니다.", "warn");
    const label = String(persisted[0].equipNm ?? persisted[0].equipCd ?? "설비");
    try {
      await validateDeleteMasterRows("equipment", keys);
      if (!(await mesConfirm(MES.deleteConfirm(label)))) return;
      await deleteMasterRows("equipment", keys);
      clearEquipSel();
      mesToast(MES.deleteDone, "success");
      const removedSelected = keys.some((k) => Number(k.idx) === selectedEquipIdx);
      if (removedSelected) {
        setSelectedEquipIdx(null);
        setSelectedEquipLabel("");
        hist.load([]);
      }
      await loadEquip();
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
      await validateDeleteEquipmentHist(keys);
      if (!(await mesConfirm(MES.deleteConfirm(selectedEquipLabel || "이력")))) return;
      await deleteEquipmentHist(keys);
      clearHistSel();
      mesToast(MES.deleteDone, "success");
      await loadHist(selectedEquipIdx);
    } catch (error) {
      mesError(error);
    }
  };

  const doSearch = () => asyncAct.run(async () => {
    sec.reset();
    await loadEquip();
    await loadHist(selectedEquipIdx);
  }, "search");

  // 셸 단축키 — 활성 섹션으로만 라우팅 (패널 버튼은 고정 타겟)
  usePageCommands({
    search: () => { void doSearch(); },
    add: () => { if (sec.is("d")) handleAddHist(); else handleAddEquip(); },
    save: () => { void asyncAct.run(sec.is("d") ? saveHist : saveEquip, "save"); },
    del: () => { void asyncAct.run(sec.is("d") ? delHist : delEquip, "del"); },
  });

  return (
    <div className={pageRootClass}>
      <PageHead
        // 화면 제목 — mes-web SoPage와 동일 슬롯
        title="설비 이력(설비카드)"
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
        <PageCardSplit storageKey="haccp-split-equipment-hist">
          <div {...sec.bind("h", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>설비</b>
              <GridCrudButtons
                // useAsyncAction.run — busy 키 래핑
                run={asyncAct.run}
                // 상단 마스터 전용 행추가
                onAdd={canWrite ? handleAddEquip : undefined}
                // 상단 마스터 전용 저장(사진 pending 포함)
                onSave={canWrite || canModify ? saveEquip : undefined}
                // 상단 마스터 전용 삭제
                onDel={canDelete ? delEquip : undefined}
                busy={{
                  save: asyncAct.isBusy("save"),
                  del: asyncAct.isBusy("del"),
                }}
              />
              <input
                // 설비 사진 선택 — photoPath 셀 버튼이 연다, 화면에는 보이지 않음
                ref={photoInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => {
                  const file = e.target.files?.[0] ?? null;
                  e.target.value = "";
                  onPhotoFilePicked(file);
                }}
              />
            </div>
            <MesEditableGrid
              // 열 설정 저장 키 — 설비 마스터(상단)
              persistId="bas-equipment-history-master"
              // CSV·오류경계 라벨 — 패널 제목과 동일
              title="설비"
              rows={equip.rows as EditableRow<EquipRow>[]}
              columns={equipColumns}
              editable={equipEditable}
              height="100%"
              loading={asyncAct.isBusy("search")}
              activeKey={equipActiveKey}
              onActivate={(row) => { void handleSelectEquip(row); }}
              onCellChange={(key, field, value) => equip.updateCell(key, field as keyof EquipRow, value)}
              access={equipGrid.access}
              onLockedAttempt={equipGrid.onLockedAttempt}
              onSetActive={() => sec.setSec("h")}
              selectable
              onSelectionChange={(rows) => setEquipSelKeys(rows.map((row) => row._key))}
              selectionResetKey={equipSelReset}
              showRowNum
            />
          </div>

          <div {...sec.bind("d", gridPanelClass)}>
            <div className={gridHeadClass}>
              <b>
                설비 이력
                {selectedEquipLabel ? ` (${selectedEquipLabel})` : ""}
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
              persistId="bas-equipment-history-detail"
              // CSV·오류경계 라벨 — 패널 제목과 동일
              title="설비 이력"
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
