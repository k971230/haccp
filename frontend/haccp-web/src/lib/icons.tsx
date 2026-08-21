/**
 * icons — 버튼 preset 아이콘과 대분류 메뉴 아이콘 매핑.
 *
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) 버튼은 문자열 이름("plus")으로 아이콘을 지정할 수 있게 해 화면마다 lucide를 직접 import하지 않게 한다
 *   2) 대분류 메뉴 아이콘은 URL 슬러그(docs/flow/bas/sys)로 고른다 — 메뉴명 키워드로 추측하지 않는다
 *   3) reset은 사용양식 초기화 버튼이 쓴다
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
  FileCheck2,
  Filter,
  Folder,
  Inbox,
  LayoutGrid,
  Pencil,
  Menu,
  MoreHorizontal,
  Plus,
  RotateCcw,
  Save,
  Search,
  Settings,
  Trash2,
  Upload,
} from "lucide-react";

/** 버튼 preset 아이콘 — MesButton icon prop에 이 키 문자열을 넘긴다 */
export const MES_ICONS = {
  plus: Plus,            // 신규·행 추가
  edit: Pencil,          // 수정
  save: Save,            // 저장
  trash: Trash2,         // 삭제
  search: Search,        // 조회
  filter: Filter,        // 필터
  columns: LayoutGrid,   // 열 설정
  download: Download,    // 다운로드·출력
  upload: Upload,        // 파일·사진 첨부
  reset: RotateCcw,      // 초기화·복원
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

/**
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 대분류 메뉴코드(URL 슬러그)로 아이콘을 고른다
 *   2) 사이드 메뉴가 최상위 노드를 그릴 때 호출한다
 *   3) 매칭이 없으면 폴더 아이콘 — 업체가 메뉴를 추가해도 빈칸이 없다
 */
export function getModuleIcon(
  // 대분류 menu_cd — today-tasks · docs · flow · bas · sys
  menuCd: string
): LucideIcon {
  if (menuCd === "today-tasks") return ClipboardList;
  if (menuCd === "docs") return FileCheck2;
  if (menuCd === "flow") return ClipboardCheck;
  if (menuCd === "bas") return Database;
  if (menuCd === "sys") return Settings;
  return Folder;
}
