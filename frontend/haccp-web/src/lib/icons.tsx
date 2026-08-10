/**
 * icons — 버튼 preset 아이콘과 대분류 메뉴 아이콘 매핑.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 버튼은 문자열 이름("plus")으로 아이콘을 지정할 수 있게 해 화면마다 lucide를 직접 import하지 않게 한다
 *   2) 대분류 메뉴 아이콘은 모듈코드로 고른다 — mes-web처럼 메뉴명 키워드로 추측하지 않는다
 *   3) 없는 이름을 넘기면 null이라 아이콘만 빠지고 화면은 정상 동작한다
 *
 * PIPELINE[HF38] 공통 모듈
 */
// 역할 — 아이콘 컴포넌트 타입
import type { LucideIcon } from "lucide-react";
// 역할 — 버튼 preset·메뉴 대분류 아이콘
import {
  AlertCircle,
  AlertTriangle,
  CheckCircle,
  ChevronDown,
  ChevronUp,
  ClipboardCheck,
  ClipboardList,
  Database,
  Download,
  Droplets,
  FileCheck2,
  Filter,
  Folder,
  Inbox,
  LayoutGrid,
  Menu,
  MoreHorizontal,
  Plus,
  Save,
  Search,
  Settings,
  Thermometer,
  Trash2,
  Truck,
  Upload,
} from "lucide-react";

/** 버튼 preset 아이콘 — MesButton icon prop에 이 키 문자열을 넘긴다 */
export const MES_ICONS = {
  plus: Plus,            // 신규·행 추가
  save: Save,            // 저장
  trash: Trash2,         // 삭제
  search: Search,        // 조회
  filter: Filter,        // 필터
  columns: LayoutGrid,   // 열 설정
  download: Download,    // 다운로드·출력
  upload: Upload,        // 파일·사진 첨부
  menu: Menu,            // 메뉴 열기
  more: MoreHorizontal,  // 더보기
  inbox: Inbox,          // 결재 수신함
  approve: FileCheck2,   // 결재 요청·승인
  chevronDown: ChevronDown,
  chevronUp: ChevronUp,
  check: CheckCircle,    // 적합·완료
  warn: AlertTriangle,   // 주의
  error: AlertCircle,    // 부적합·오류
} as const;

export type MesIconName = keyof typeof MES_ICONS;

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) preset 이름을 lucide 컴포넌트로 바꾼다
 *   2) MesButton이 icon prop을 해석할 때 호출한다
 *   3) 등록되지 않은 이름이거나 값이 없으면 null이다 — 아이콘 없이 라벨만 표시된다
 */
export function resolveMesIcon(
  // preset 키 — MesIconName이 아닌 임의 문자열이 들어와도 안전하게 null이 된다
  name?: string
): LucideIcon | null {
  if (!name) return null;
  if (name in MES_ICONS) return MES_ICONS[name as MesIconName];
  return null;
}

/** 모듈코드별 대분류 메뉴 아이콘 — 모듈은 09_seed_platform의 tbl_screen.module_cd와 같다 */
const MODULE_ICON: Readonly<Record<string, LucideIcon>> = {
  TSK: ClipboardList,   // 오늘 할 일
  WRK: FileCheck2,      // 문서 작성
  APR: ClipboardCheck,  // 문서 현황·결재
  FRM: Settings,        // 문서 기준관리
  COD: Database,        // 기초정보 관리
  SYS: Settings,        // 시스템 관리
  // 구 모듈(하위 호환)
  CCP: Thermometer,
  HYG: Droplets,
  PRC: ClipboardCheck,
  FAC: Settings,
  INV: Truck,
  DOC: FileCheck2,
  BAS: Database,
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 대분류 메뉴코드에서 모듈을 읽어 아이콘을 고른다
 *   2) 사이드 메뉴가 최상위 노드를 그릴 때 호출한다
 *   3) 매칭되는 모듈이 없으면 폴더 아이콘을 쓴다 — 업체가 메뉴를 추가해도 빈칸이 생기지 않는다
 */
export function getModuleIcon(
  // 대분류 메뉴코드 — 'M' + 모듈코드 형태다(예: MCCP). 접두 M을 떼어 모듈을 얻는다
  menuCd: string
): LucideIcon {
  // 오늘 할 일 최상위 leaf 그룹
  if (menuCd === "today-tasks") return MODULE_ICON.TSK ?? Folder;
  const moduleCd = menuCd.startsWith("M") ? menuCd.slice(1) : menuCd;
  return MODULE_ICON[moduleCd] ?? Folder;
}
