/**
 * MasterDataPage — 고정 설정 기반 HACCP 기준정보 MesEditableGrid 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 제품부터 CCP 한계기준까지 8개 마스터를 인라인 편집 그리드로 제공한다
 *   2) 화면별 필드·선택값은 고정 설정에만 정의하며 하단 단건 폼은 사용하지 않는다
 *   3) 삭제는 validate-delete → 확인 → delete → 재조회 순서와 객체 배열 업무키를 지킨다
 *
 * PIPELINE[HF85] 기준정보 화면
 * PIPELINE[HF29, HF39, HF56, HF84, HF96, HF100] 연관 모듈
 */
// 역할 — 상태·콜백·화면 진입 후 목록 조회
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
// 역할 — mes-web형 행추가·저장·삭제 버튼 묶음
import { GridCrudButtons } from "@/components/grid/GridCrudButtons";
// 역할 — SoPage형 그리드 패널 헤더(보이는 그리드명)
import { gridHeadClass } from "@/components/layout/pageClasses";
// 역할 — 표준 버튼·입력
import { MesButton } from "@/components/ui/MesButton";
import { Input } from "@/components/ui/Input";
// 역할 — 확인창·성공 및 오류 토스트
import { mesConfirm, mesToast } from "@/shell/dialog";
// 역할 — 서버 예외를 업무 문구로 변환
import { mesError } from "@/shell/errors";
// 역할 — 공통 저장·삭제·필수 안내 문구
import { MES } from "@/shell/messages";
// 역할 — 셸 상단·단축키 CRUD 명령 등록
import { usePageCommands } from "@/shell/pageCommands";
// 역할 — 저장 가드
import { guardSaveWithKey } from "@/shell/gridRules";
// 역할 — 선택행 우선 삭제 대상
import { resolveRowsForDelete } from "@/shell/resolveDelete";
// 역할 — 그리드·편집 행 타입
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";
// 역할 — 기준정보 API·고정 리소스 타입
import {
  deleteMasterRows,
  listMasterRows,
  saveMasterRow,
  validateDeleteMasterRows,
  type MasterRow,
  type MasterType,
} from "@/api/masterApi";
// 역할 — 화면별 업무키 newOnly 규칙
import { MASTER_GRID_RULES } from "./MasterDataPage.rules";

/** 선택형 필드의 값과 화면 표시명 */
interface MasterOption {
  value: string;
  label: string;
}

/** 화면에 고정으로 허용한 기준정보 필드 정의 */
interface MasterField {
  key: string;
  label: string;
  input?: "text" | "number" | "date" | "textarea" | "select";
  required?: boolean;
  options?: readonly MasterOption[];
  width?: number;
}

/** 역할 기반 화면 식별자별 고정 열·업무키 설정 */
interface MasterScreenConfig {
  screenCode: string;
  title: string;
  type: MasterType;
  keyField: string;
  /** CCP 문서별 기준관리 — 허용 ccpCd 목록 (있으면 조회 후 필터) */
  ccpCdAllowList?: readonly string[];
  nameField: string;
  editFields: readonly MasterField[];
}

const YES_NO_OPTIONS = [
  { value: "Y", label: "사용" },
  { value: "N", label: "미사용" },
] as const;

/** Y/N 플래그 — 사용여부가 아닌 협력업체리스트 등 */
const FLAG_YN_OPTIONS = [
  { value: "Y", label: "Y" },
  { value: "N", label: "N" },
] as const;

const STORAGE_TYPE_OPTIONS = [
  { value: "COLD", label: "냉장" },
  { value: "FROZEN", label: "냉동" },
  { value: "ROOM", label: "상온" },
] as const;

/**
 * 기준정보 화면 고정 명세.
 * API에 전달하는 camelCase 키는 DDL 컬럼과 1:1 대응하며, 런타임 폼 생성 API는 사용하지 않는다.
 *
 * equipment-management / pest-device-management 는 여기에 두지 않는다(= 되살리지 말 것).
 * screenRegistry가 두 화면코드를 EquipmentHistoryPage / PestDeviceHistoryPage 로 직접 매핑해
 * 이 페이지에 도달하지 않으므로, 09 G-13 근거로 2026-08-10 STEP 01 에서 제거했다.
 */
const MASTER_SCREEN_CONFIGS: Record<string, MasterScreenConfig> = {
  "product-management": {
    screenCode: "product-management", title: "제품 관리", type: "product", keyField: "productCd", nameField: "productNm",
    editFields: [
      { key: "productCd", label: "제품코드", required: true, width: 110 }, { key: "productNm", label: "제품명", required: true, width: 160 },
      { key: "specNm", label: "규격", width: 120 }, { key: "unitNm", label: "단위", width: 70 }, { key: "pkgType", label: "포장형태", width: 100 },
      { key: "storageType", label: "보관유형", input: "select", options: STORAGE_TYPE_OPTIONS, width: 90 },
      { key: "shelfLifeDay", label: "소비기한(일)", input: "number", width: 100 }, { key: "reportNo", label: "품목제조보고번호", width: 140 },
      { key: "haccpYn", label: "HACCP 적용", input: "select", options: YES_NO_OPTIONS, width: 90 },
      { key: "useYn", label: "사용여부", input: "select", options: YES_NO_OPTIONS, width: 80 },
    ],
  },
  "material-management": {
    screenCode: "material-management", title: "원·부재료 관리", type: "material", keyField: "materialCd", nameField: "materialNm",
    editFields: [
      { key: "materialCd", label: "원부재료 코드", required: true, width: 120 }, { key: "materialNm", label: "원·부재료명", required: true, width: 160 },
      { key: "materialGbn", label: "구분", input: "select", required: true, width: 90, options: [{ value: "MEAT", label: "원료육" }, { value: "SUB", label: "부재료" }, { value: "PACK", label: "포장재" }] },
      { key: "specNm", label: "규격", width: 120 }, { key: "unitNm", label: "단위", width: 70 },
      { key: "storageType", label: "보관유형", input: "select", options: STORAGE_TYPE_OPTIONS, width: 90 }, { key: "partnerCd", label: "주 공급처 코드", width: 110 },
      { key: "shelfLifeDay", label: "소비기한(일)", input: "number", width: 100 }, { key: "haccpYn", label: "HACCP 적용", input: "select", options: YES_NO_OPTIONS, width: 90 },
      { key: "inspStd", label: "입고검사 기준", input: "textarea", width: 180 }, { key: "useYn", label: "사용여부", input: "select", options: YES_NO_OPTIONS, width: 80 },
    ],
  },
  "partner-management": {
    screenCode: "partner-management", title: "거래처 관리", type: "partner", keyField: "partnerCd", nameField: "partnerNm",
    editFields: [
      { key: "partnerCd", label: "거래처 코드", required: true, width: 110 }, { key: "partnerNm", label: "거래처명", required: true, width: 150 },
      { key: "partnerGbn", label: "구분", input: "select", required: true, width: 110, options: [{ value: "SUPPLY", label: "공급처" }, { value: "SALES", label: "판매처" }, { value: "tmpl_prp-waste-check", label: "폐기물 수거업체" }, { value: "LAB", label: "검사기관" }] },
      { key: "bizNo", label: "사업자등록번호", width: 120 }, { key: "ceoNm", label: "대표자명", width: 90 }, { key: "telNo", label: "전화번호", width: 110 }, { key: "faxNo", label: "팩스번호", width: 100 },
      { key: "mngNm", label: "담당자명", width: 90 }, { key: "mobile", label: "담당자 휴대폰", width: 120 }, { key: "email", label: "이메일", width: 150 },
      { key: "zipNo", label: "우편번호", width: 80 }, { key: "addrH", label: "주소", width: 160 }, { key: "addrD", label: "상세주소", width: 120 },
      { key: "haccpYn", label: "HACCP 인증", input: "select", options: YES_NO_OPTIONS, width: 90 },
      { key: "coopListYn", label: "협력업체리스트", input: "select", options: FLAG_YN_OPTIONS, width: 110 },
      { key: "useYn", label: "사용여부", input: "select", options: YES_NO_OPTIONS, width: 80 },
    ],
  },
  "storage-management": {
    screenCode: "storage-management", title: "보관고 관리", type: "storage", keyField: "storageCd", nameField: "storageNm",
    editFields: [
      { key: "storageCd", label: "보관고 코드", required: true, width: 110 }, { key: "storageNm", label: "보관고명", required: true, width: 140 },
      { key: "storageType", label: "보관유형", input: "select", required: true, options: STORAGE_TYPE_OPTIONS, width: 90 }, { key: "ccpCd", label: "연결 CCP 코드", width: 110 },
      { key: "tempMin", label: "개별 하한온도", input: "number", width: 100 }, { key: "tempMax", label: "개별 상한온도", input: "number", width: 100 },
      { key: "sensorYn", label: "자동온도기록장치", input: "select", options: YES_NO_OPTIONS, width: 120 }, { key: "placeNm", label: "설치 위치", width: 120 },
      { key: "sortNo", label: "정렬순서", input: "number", width: 80 }, { key: "useYn", label: "사용여부", input: "select", options: YES_NO_OPTIONS, width: 80 },
    ],
  },
  "measuring-device-management": {
    screenCode: "measuring-device-management", title: "계측기 관리", type: "measuring-device", keyField: "deviceCd", nameField: "deviceNm",
    editFields: [
      { key: "deviceCd", label: "계측기 코드", required: true, width: 110 }, { key: "deviceNm", label: "계측기명", required: true, width: 140 },
      { key: "deviceType", label: "유형", input: "select", required: true, width: 120, options: [{ value: "SCALE", label: "저울" }, { value: "THERMO", label: "온도계" }, { value: "TIMER", label: "타이머" }, { value: "LUX", label: "조도계" }, { value: "RECORDER", label: "자동온도기록장치" }, { value: "STANDARD", label: "표준기" }] },
      { key: "modelNm", label: "모델명", width: 110 }, { key: "makerNm", label: "제조사", width: 100 }, { key: "specNm", label: "규격", width: 100 },
      { key: "toleranceVal", label: "허용오차", input: "number", width: 90 },
      { key: "toleranceUnit", label: "허용오차 단위", input: "select", width: 100, options: [{ value: "PCT", label: "퍼센트" }, { value: "DEG", label: "섭씨도" }, { value: "SEC", label: "초" }] },
      { key: "calibCycleMonth", label: "검·교정 주기(개월)", input: "number", width: 120 }, { key: "placeNm", label: "설치 위치", width: 120 },
      { key: "sortNo", label: "정렬순서", input: "number", width: 80 }, { key: "useYn", label: "사용여부", input: "select", options: YES_NO_OPTIONS, width: 80 },
    ],
  },
  "vehicle-management": {
    screenCode: "vehicle-management", title: "차량 관리", type: "vehicle", keyField: "vehicleCd", nameField: "carNo",
    editFields: [
      { key: "vehicleCd", label: "차량 코드", required: true, width: 110 }, { key: "carNo", label: "차량번호", required: true, width: 120 }, { key: "carType", label: "차종", width: 90 },
      { key: "ownerNm", label: "소유자", width: 90 }, { key: "driverNm", label: "주 운전자", width: 100 }, { key: "coolerYn", label: "적재함 냉각기", input: "select", options: YES_NO_OPTIONS, width: 110 },
      { key: "tempRecorderYn", label: "자동온도기록장치", input: "select", options: YES_NO_OPTIONS, width: 120 }, { key: "useYn", label: "사용여부", input: "select", options: YES_NO_OPTIONS, width: 80 },
    ],
  },
  "work-area-management": {
    screenCode: "work-area-management", title: "작업장·구역 관리", type: "work-area", keyField: "areaCd", nameField: "areaNm",
    editFields: [
      { key: "areaCd", label: "구역 코드", required: true, width: 100 }, { key: "areaNm", label: "구역명", required: true, width: 140 },
      { key: "areaGbn", label: "위생구분", input: "select", width: 110, options: [{ value: "CLEAN", label: "청결구역" }, { value: "SEMI", label: "준청결구역" }, { value: "GENERAL", label: "일반구역" }] },
      { key: "luxStd", label: "조도 기준(LUX)", input: "number", width: 110 }, { key: "tempStdMin", label: "온도 하한", input: "number", width: 90 }, { key: "tempStdMax", label: "온도 상한", input: "number", width: 90 },
      { key: "humidStdMin", label: "습도 하한", input: "number", width: 90 }, { key: "humidStdMax", label: "습도 상한", input: "number", width: 90 },
      { key: "sortNo", label: "정렬순서", input: "number", width: 80 }, { key: "useYn", label: "사용여부", input: "select", options: YES_NO_OPTIONS, width: 80 },
    ],
  },
  "ccp-limit-management": {
    screenCode: "ccp-limit-management", title: "CCP 한계기준 관리", type: "ccp-limit", keyField: "ccpCd", nameField: "ccpNm",
    editFields: [
      { key: "ccpCd", label: "CCP 코드", required: true, width: 100 }, { key: "ccpNm", label: "CCP 명칭", required: true, width: 140 }, { key: "procNm", label: "공정명", width: 120 },
      { key: "limitType", label: "기준유형", input: "select", required: true, width: 110, options: [{ value: "TEMP_RANGE", label: "온도 범위" }, { value: "TEMP_MAX", label: "온도 이하" }, { value: "TEMP_MIN", label: "온도 이상" }, { value: "METAL", label: "금속검출" }] },
      { key: "minVal", label: "하한값", input: "number", width: 80 }, { key: "maxVal", label: "상한값", input: "number", width: 80 }, { key: "unitNm", label: "단위", width: 70 },
      { key: "feSize", label: "Fe 시편 규격", input: "number", width: 100 }, { key: "stsSize", label: "STS 시편 규격", input: "number", width: 100 },
      { key: "cycleMin", label: "모니터링 주기(분)", input: "number", width: 120 },
      { key: "formTitle", label: "일지 제목", input: "textarea", width: 160 },
      { key: "cycleRmk", label: "주기 문구", input: "textarea", width: 140 },
      { key: "limitRmk", label: "한계기준 문구", input: "textarea", width: 160 },
      { key: "methodRmk", label: "모니터링 방법", input: "textarea", width: 160 },
      { key: "improveRmk", label: "개선조치방법", input: "textarea", width: 180 },
      { key: "useYn", label: "사용여부", input: "select", options: YES_NO_OPTIONS, width: 80 },
    ],
  },
};

/** 문서별 CCP 기준관리 — 통합 ccp-limit 설정 + 허용 ccpCd 필터 */
function ccpLimitAdmin(
  screenCode: string,
  title: string,
  ccpCdAllowList: readonly string[],
): MasterScreenConfig {
  const base = MASTER_SCREEN_CONFIGS["ccp-limit-management"];
  return { ...base, screenCode, title, ccpCdAllowList };
}
// 냉장·냉동 모니터 — 원료육·완제품 보관 CCP
MASTER_SCREEN_CONFIGS["ccp-cold-limit-admin"] = ccpLimitAdmin(
  "ccp-cold-limit-admin", "냉장냉동 CCP 기준관리", ["CCP-1B", "CCP-3B"],
);
// 가열 모니터
MASTER_SCREEN_CONFIGS["ccp-heat-limit-admin"] = ccpLimitAdmin(
  "ccp-heat-limit-admin", "가열 CCP 기준관리", ["CCP-HEAT"],
);
// 멸균 모니터
MASTER_SCREEN_CONFIGS["ccp-sanitize-limit-admin"] = ccpLimitAdmin(
  "ccp-sanitize-limit-admin", "멸균 CCP 기준관리", ["CCP-STER"],
);
// 여과 모니터
MASTER_SCREEN_CONFIGS["ccp-filter-limit-admin"] = ccpLimitAdmin(
  "ccp-filter-limit-admin", "여과 CCP 기준관리", ["CCP-FILT"],
);
// 금속검출 모니터
MASTER_SCREEN_CONFIGS["ccp-metal-limit-admin"] = ccpLimitAdmin(
  "ccp-metal-limit-admin", "금속검출 CCP 기준관리", ["CCP-2P"],
);

type Row = MasterRow & { idx?: number | null; _key?: string };

/** YYYYMMDD → input date(YYYY-MM-DD) — 그리드 date 셀 표시용 */
function toDateInput(ymd: unknown): string {
  const s = String(ymd ?? "").replace(/-/g, "");
  return s.length === 8 ? `${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6)}` : String(ymd ?? "");
}

/** 신규 행 — 선택 필드는 첫 선택값, 사용여부는 사용·플래그는 N으로 시작 */
function createEmptyRow(config: MasterScreenConfig): Row {
  return config.editFields.reduce<Row>((row, field) => {
    if (field.key === "useYn") row[field.key] = "Y";
    else if (field.key === "coopListYn") row[field.key] = "N";
    else if (field.input === "select") row[field.key] = field.options?.[0]?.value ?? "";
    else row[field.key] = "";
    return row;
  }, {});
}

/** 숫자·일자 정규화 후 API 전달. 수정행은 idx를 포함한다. */
function normalizeRow(config: MasterScreenConfig, row: Row): MasterRow {
  const next = config.editFields.reduce<MasterRow>((acc, field) => {
    const value = row[field.key];
    if (field.input === "number" && value !== "" && value != null) {
      acc[field.key] = Number(value);
    } else if (field.input === "date") {
      // date 입력은 YYYY-MM-DD — SP varchar(8)용 YYYYMMDD로 정규화
      const ymd = String(value ?? "").replace(/-/g, "");
      acc[field.key] = ymd || null;
    } else {
      acc[field.key] = value === "" ? null : value;
    }
    return acc;
  }, {});
  // 수정 행일 때(= 대리키 있음) SP가 같은 회사 행을 UPDATE하도록 idx를 넣는다
  if (row.idx != null && Number(row.idx) > 0) {
    next.idx = Number(row.idx);
  }
  return next;
}

/** 조회 행의 date 필드를 그리드 input 형식으로 맞춘다 */
function mapLoadedRow(config: MasterScreenConfig, row: MasterRow): Row {
  const next: Row = { ...row };
  for (const field of config.editFields) {
    if (field.input === "date") next[field.key] = toDateInput(row[field.key]);
  }
  return next;
}

/** 고정 필드 정의를 MesEditableGrid 컬럼으로 변환한다 */
function buildColumns(config: MasterScreenConfig, editable: boolean): GridColumn<Row>[] {
  return config.editFields.map((field) => {
    const isKey = field.key === config.keyField;
    const base: GridColumn<Row> = {
      field: field.key,
      header: field.label,
      width: field.width ?? 120,
      required: field.required,
      editable: isKey ? undefined : editable,
      editableOnNew: isKey ? true : undefined,
    };
    if (field.input === "select") {
      const opts = [...(field.options ?? [])];
      return {
        ...base,
        type: "code",
        codeOptions: opts,
        codeMap: Object.fromEntries(opts.map((opt) => [opt.value, opt.label])),
      };
    }
    if (field.input === "number") return { ...base, type: "number" };
    if (field.input === "date") return { ...base, type: "date" };
    return base;
  });
}

/** 기준정보 공통 화면 props — 등록 화면코드만 받아 고정 설정을 선택한다 */
interface MasterDataPageProps {
  screenCode: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 화면코드에 맞는 고정 기준정보 설정으로 인라인 편집 그리드를 렌더링한다
 *   2) 등록된 frmBAS 화면만 screenRegistry에서 이 컴포넌트로 진입한다
 *   3) API 오류·삭제 참조 차단·권한 부족은 업무 문구로만 안내한다
 */
export default function MasterDataPage({ screenCode }: MasterDataPageProps) {
  // 미등록 화면코드면 제품 설정을 훅 기본값으로만 쓰고, 렌더에서 오류를 표시한다
  const config = MASTER_SCREEN_CONFIGS[screenCode] ?? MASTER_SCREEN_CONFIGS["product-management"];
  const hasConfig = Boolean(MASTER_SCREEN_CONFIGS[screenCode]);
  const canWrite = useAuthStore((state) => state.can(screenCode, "write"));
  const canModify = useAuthStore((state) => state.can(screenCode, "modify"));
  const canDelete = useAuthStore((state) => state.can(screenCode, "delete"));
  const asyncAct = useAsyncAction();
  const [keyword, setKeyword] = useState("");
  const [useYn, setUseYn] = useState("");
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [selKeys, setSelKeys] = useState<string[]>([]);
  const [selReset, setSelReset] = useState(0);
  const clearSel = () => { setSelKeys([]); setSelReset((n) => n + 1); };

  // 행 식별은 대리키 idx — 업무키(storageCd 등)는 newOnly 편집용으로만 쓴다
  const g = useEditableRows<Row>("idx");
  const rules = MASTER_GRID_RULES[screenCode] ?? { newOnly: [config.keyField] };
  const grid = useGridAccess(rules, {
    scrnCd: screenCode,
    gridRole: "single",
    readOnly: !canModify && !canWrite,
    extra: { canWrite, canModify, canDelete },
  });
  const columns = useMemo(
    () => buildColumns(config, canWrite || canModify),
    [canModify, canWrite, config],
  );

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 검색 조건으로 현재 기준정보 유형 목록을 다시 읽는다
   *   2) 최초 진입·조회·저장·삭제 성공 뒤에 호출한다
   *   3) 실패하면 기존 행을 유지하고 오류 토스트만 표시한다
   */
  const loadRows = useCallback(async () => {
    try {
      const rows = await listMasterRows(config.type, { keyword, useYn });
      // 문서별 CCP 기준관리일 때(= allowList 있음) 해당 ccpCd만 표시
      const filtered = config.ccpCdAllowList
        ? rows.filter((row) => config.ccpCdAllowList!.includes(String(row.ccpCd ?? "")))
        : rows;
      g.load(filtered.map((row) => mapLoadedRow(config, row)));
      setActiveKey(null);
      clearSel();
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps -- g.load 안정 참조
  }, [config, keyword, useYn]);

  useEffect(() => {
    void loadRows();
  }, [loadRows]);

  const handleAdd = () => {
    if (!canWrite) return mesToast("등록 권한이 없습니다.", "warn");
    setActiveKey(g.addRow(createEmptyRow(config)));
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 변경행만 단건 save API로 순차 저장하고 목록을 다시 읽는다
   *   2) GridCrudButtons·셸 Ctrl+S·저장 버튼에서 호출한다
   *   3) 권한·가드·확인 실패는 토스트만, 성공 시 재조회한다
   */
  const handleSave = async () => {
    if (!canWrite && !canModify) {
      mesToast("수정 권한이 없습니다.", "warn");
      return;
    }
    const dirty = g.getSaveRows();
    if (dirty.length === 0) return mesToast(MES.noChange, "warn");
    const guard = guardSaveWithKey(grid.rules, grid.ctx, dirty, columns);
    if (guard) {
      mesToast(guard.message, "warn");
      if (guard.rowKey) setActiveKey(guard.rowKey);
      return;
    }
    for (const row of dirty) {
      const required = config.editFields.find((field) => field.required && !String(row[field.key] ?? "").trim());
      if (required) {
        mesToast(MES.required(required.label), "warn");
        setActiveKey(row._key);
        return;
      }
    }
    if (!(await mesConfirm(MES.saveConfirm))) return;
    try {
      for (const row of dirty) {
        await saveMasterRow(config.type, normalizeRow(config, row));
      }
      mesToast(MES.saveDone, "success");
      await loadRows();
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-08-06
   * 코멘트:
   *   1) 선택행 우선 삭제 — 신규는 로컬 제거, 저장행은 validate-delete·확인·delete
   *   2) GridCrudButtons·셸 삭제 단축키에서 호출한다
   *   3) 참조 차단·권한 실패는 업무 토스트로만 안내한다
   */
  const handleDelete = async () => {
    if (!canDelete) {
      mesToast("삭제 권한이 없습니다.", "warn");
      return;
    }
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

    // 삭제 계약은 [{ idx }] — 업무키 객체가 아니다
    const keys = persisted
      .map((row) => Number(row.idx))
      .filter((idx) => Number.isFinite(idx) && idx > 0)
      .map((idx) => ({ idx }));
    if (keys.length === 0) return mesToast("삭제할 행의 키가 올바르지 않습니다.", "warn");
    const label = String(persisted[0][config.nameField] ?? persisted[0][config.keyField] ?? "");
    try {
      await validateDeleteMasterRows(config.type, keys);
      if (!(await mesConfirm(MES.deleteConfirm(label)))) return;
      await deleteMasterRows(config.type, keys);
      clearSel();
      mesToast(MES.deleteDone, "success");
      await loadRows();
    } catch (error) {
      mesToast(mesError(error), "error");
    }
  };

  // mes-web CommonCode와 동일 — 셸 툴바·단축키에 조회/추가/저장/삭제 등록
  usePageCommands({
    search: () => { void asyncAct.run(loadRows, "search"); },
    add: handleAdd,
    save: () => { void asyncAct.run(handleSave, "save"); },
    del: () => { void asyncAct.run(handleDelete, "del"); },
  });

  if (!hasConfig) {
    return <div className="p-4 text-sm text-rose-600">등록되지 않은 기준정보 화면입니다: {screenCode}</div>;
  }

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 p-3">
      <section className="flex flex-wrap items-end gap-2 rounded border border-slate-200 bg-white p-3">
        <label className="flex flex-col gap-1 text-xs text-slate-600">
          검색어
          <Input
            // 코드·명칭을 함께 검색하는 서버 조회 조건
            value={keyword}
            // 조회 전까지 입력값만 보관한다
            onChange={(event) => setKeyword(event.target.value)}
            placeholder="코드 또는 명칭"
            className="w-52"
          />
        </label>
        <label className="flex flex-col gap-1 text-xs text-slate-600">
          사용여부
          <select
            // 전체·사용·미사용 행을 서버 목록 조건으로 전달한다
            value={useYn}
            // 선택한 사용여부 조건을 상태에 보관한다
            onChange={(event) => setUseYn(event.target.value)}
            className="h-mes-input rounded border border-slate-300 bg-white px-2 text-sm"
          >
            <option value="">전체</option>
            <option value="Y">사용</option>
            <option value="N">미사용</option>
          </select>
        </label>
        <MesButton
          // 현재 검색 조건으로 목록을 다시 읽는다
          variant="search"
          // 조회 처리 중 중복 요청을 막는다
          disabled={asyncAct.isBusy("search")}
          // 조회는 독립 key로 실행한다
          onClick={() => void asyncAct.run(loadRows, "search")}
        >
          조회
        </MesButton>
      </section>

      <section className="flex min-h-0 flex-1 flex-col overflow-hidden rounded border border-slate-200 bg-white p-2">
        <div className={gridHeadClass}>
          {/* 보이는 그리드명 — config.title과 title prop 동일 */}
          <b>{config.title}</b>
          <GridCrudButtons
            // useAsyncAction.run — save/del busy 키 래핑
            run={asyncAct.run}
            // 신규 기준정보 행 추가 — 등록 권한 있을 때만
            onAdd={canWrite ? handleAdd : undefined}
            // 변경행 단건 저장
            onSave={canWrite || canModify ? handleSave : undefined}
            // validate-delete 후 삭제
            onDel={canDelete ? handleDelete : undefined}
            // 버튼별 busy — 중복 클릭 방지
            busy={{
              save: asyncAct.isBusy("save"),
              del: asyncAct.isBusy("del"),
            }}
            // mes-web과 동일 라벨 — 신규 대신 행추가
            addLabel="행추가"
          />
        </div>
        <MesEditableGrid
          // 열 설정 저장 키 — 화면코드별 분리
          persistId={`bas-${screenCode}`}
          // 조회·편집 행 목록
          rows={g.rows as EditableRow<Row>[]}
          // 화면별 고정 컬럼 정의
          columns={columns}
          // 등록·수정 권한이 있을 때만 편집
          editable={canWrite || canModify}
          // 그리드 제목 — 패널 헤더·CSV와 동일
          title={config.title}
          // 패널 높이를 채운다
          height="100%"
          // 조회·저장·삭제 busy 오버레이
          loading={asyncAct.isBusy("search") || asyncAct.isBusy("save") || asyncAct.isBusy("del")}
          // 활성 행 키
          activeKey={activeKey}
          // 행 활성화
          onActivate={(row) => setActiveKey(row._key)}
          // 셀 변경 추적
          onCellChange={(key, field, value) => g.updateCell(key, field as keyof Row, value)}
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
      </section>
    </div>
  );
}
