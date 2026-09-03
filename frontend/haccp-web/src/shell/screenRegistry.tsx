/**
 * screenRegistry — 화면코드에서 실제 React 화면을 찾는 표.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 셸은 이 표만 보고 화면을 마운트한다 — 셸이 개별 화면을 직접 import하지 않는다
 *   2) 메뉴 노출과 별개다. use_yn=N 숨김 화면도 deep-link 되면 여기에 둔다
 *   3) HWP 문서만 leaf는 동일 editor에 tmplCd를 고정해 메뉴·권한을 분리한다
 *
 * PIPELINE[HF51] 화면 레지스트리
 * PIPELINE[HF49] 연관 모듈
 */
// 역할 — 화면 컴포넌트 타입
import type { ComponentType } from "react";
// 역할 — 통합 문서함·결재함·결재이력
import DocumentBoxPage from "@/pages/flow/box/documentbox/DocumentBoxPage";
import ApprovalAttachPage from "@/pages/flow/appr/attach/ApprovalAttachPage";
// 역할 — HWP 양식 파일 관리
import HwpTemplateManagementPage from "@/pages/docs/hwp/HwpTemplateManagementPage";
// 역할 — HTML 양식 원본(공정점검 버전)
import HtmlTemplatePage from "@/pages/docs/html-form/htmltemplate/HtmlTemplatePage";
// 역할 — HTML 양식 원본(CCP 검증점검)
import CcpVerifyTemplatePage from "@/pages/docs/html-form/ccpverifytemplate/CcpVerifyTemplatePage";
// 역할 — HTML 양식 원본(CCP-1B 포장 모니터링일지)
import CcpPkgTemplatePage from "@/pages/docs/html-form/ccppkgtemplate/CcpPkgTemplatePage";
// 역할 — HTML 양식 원본(CCP-2B 가열 모니터링일지)
import CcpHtgTemplatePage from "@/pages/docs/html-form/ccphtgtemplate/CcpHtgTemplatePage";
// 역할 — HTML 양식 원본(CCP-3P 금속검출 모니터링일지)
import CcpMtlTemplatePage from "@/pages/docs/html-form/ccpmtltemplate/CcpMtlTemplatePage";
// 역할 — 양식 작성 — HYG 위생공정 (사용여부 예인 자사 양식)
import { HygProcessDraftPage } from "@/pages/draft/html/HygProcessDraftPage";
// 역할 — 양식 작성 — CCP 검증점검 (HYG 와 같은 공통 화면)
import { CcpVerifyDraftPage } from "@/pages/draft/html/CcpVerifyDraftPage";
// 역할 — 양식 작성 — CCP 모니터링일지 3종 (포장·가열·금속검출)
import { CcpPkgDraftPage } from "@/pages/draft/ccp-monitoring/CcpPkgDraftPage";
import { CcpHtgDraftPage } from "@/pages/draft/ccp-monitoring/CcpHtgDraftPage";
import { CcpMtlDraftPage } from "@/pages/draft/ccp-monitoring/CcpMtlDraftPage";
import { HwpDraftPage } from "@/pages/draft/hwp-doc/HwpDraftPage";
// 역할 — 권한그룹 좌 메뉴권한 트리 + 우 마스터 그리드
import RoleManagementPage from "@/pages/sys/code/role/RoleManagementPage";
// 역할 — 부서 좌 트리 + 우 그리드
import DepartmentManagementPage from "@/pages/sys/code/department/DepartmentManagementPage";
// 역할 — 메뉴 좌 트리 + 우 그리드
import MenuManagementPage from "@/pages/sys/code/menu/MenuManagementPage";
// 역할 — 공통코드 대분류·시스템·사용자 3그리드
import CommonCodePage from "@/pages/sys/code/commoncode/CommonCodePage";
// 역할 — 결재선 좌 목록 · 우 단계
import ApprovalLineManagementPage from "@/pages/sys/code/approvalline/ApprovalLineManagementPage";
import ScheduleCycleManagementPage from "@/pages/docs/sch/ScheduleCycleManagementPage";
// 역할 — 오늘 할 일·개선조치
import TodayTasksPage from "@/pages/board/TodayTasksPage";
import { CalendarPage } from "@/pages/board/CalendarPage";
import CorrectiveActionManagementPage from "@/pages/flow/ca/corrective/CorrectiveActionManagementPage";
// 역할 — 사용자 관리 그리드
import UserManagementPage from "@/pages/sys/code/user/UserManagementPage";
// 역할 — 로그 3화면 (각자 LogPageShell + Rule)
import LoginHistoryPage from "@/pages/sys/logs/loginhistory/LoginHistoryPage";
import ScreenUsageStatisticsPage from "@/pages/sys/logs/screenusage/ScreenUsageStatisticsPage";
import AuditLogPage from "@/pages/sys/logs/auditlog/AuditLogPage";

/**
 * 화면코드 → 화면 컴포넌트.
 * DB tbl_screen.scrn_cd와 키가 문자 그대로 같아야 한다.
 */
export const SCREEN_REGISTRY: Record<string, ComponentType> = {
  // 오늘 할 일 — 랜딩
  "today-tasks": TodayTasksPage,
  // 일정 캘린더 — 회사 전체
  "calendar": CalendarPage,

  // 시스템 관리 — company-management 제거(온보딩 외 미노출)
  "user-management": UserManagementPage,
  "department-management": DepartmentManagementPage,
  "role-management": RoleManagementPage,
  "menu-management": MenuManagementPage,
  "common-code-management": CommonCodePage,
  "approval-line-management": ApprovalLineManagementPage,
  "login-history": LoginHistoryPage,
  "screen-usage-statistics": ScreenUsageStatisticsPage,
  "audit-log": AuditLogPage,

  // 기초정보 관리

  // 문서 기준관리
  // 일지설정 세트(좌 목록+우 업무): 사용양식·HTML 5·문서주기. 슈퍼 셸로 합치지 않음. pages/docs/README.md
  // 시설·설비 관리 메뉴는 이력 M-D로 통합 — 구 화면코드 진입도 동일 화면
  // 포충등·트랩 관리 메뉴는 방충 이력 M-D로 통합
  // approval-line-management 는 시스템 관리로 이동
  "hwp-template-management": HwpTemplateManagementPage,
  "hyg-process-template": HtmlTemplatePage,
  "ccp-verify-template": CcpVerifyTemplatePage,
  "ccp-pkg-template": CcpPkgTemplatePage,
  "ccp-htg-template": CcpHtgTemplatePage,
  "ccp-mtl-template": CcpMtlTemplatePage,
  "schedule-cycle-management": ScheduleCycleManagementPage,

  // 문서 작성 — DB

  // 양식 작성 — draft 대분류. 양식관리 사용여부 예인 자사 양식만 쓴다
  "hyg-process": HygProcessDraftPage,
  "ccp-verify": CcpVerifyDraftPage,
  "ccp-pkg": CcpPkgDraftPage,
  "ccp-htg": CcpHtgDraftPage,
  "ccp-mtl": CcpMtlDraftPage,
  "hwp-write": HwpDraftPage,
  // 메뉴 숨김(use_yn=N). 문서함 html_sys_010 deep-link 전용. SQL·Page 삭제 금지
  // 건강진단관리기록부 — 인원 그리드·첨부 (HA-HYG-02)

  // 문서 작성 — HWP 문서만 (양식 1:1 고정, pages/docs/{중}/{scrnCd}/)
  // 설비 이력 — DB형 M-D (상단 설비·하단 이력). 옛 HWP 설비카드 leaf 대체
  // 방충설비 이력 — DB형 M-D (상단 포충등·트랩·하단 이력)

  // 문서 현황·결재
  "document-inbox": () => <DocumentBoxPage mode="inbox" />,
  "sign-ready": () => <DocumentBoxPage mode="approval" />,
  "sign-ok": () => <DocumentBoxPage mode="history" />,
  "attach": ApprovalAttachPage,
  "corrective-action-management": CorrectiveActionManagementPage,
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 메뉴·탭에 표시할 제목을 다듬는다
 *   2) 사이드 메뉴가 메뉴명을 그릴 때와 셸이 탭 제목을 정할 때 호출한다
 *   3) 값이 없으면 빈 문자열을 반환한다
 */
export function cleanTitle(
  // DB에 저장된 화면명
  scrnNm: string | null | undefined
): string {
  return (scrnNm ?? "").trim();
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 해당 화면이 웹에 구현되어 열 수 있는 상태인지 판정한다
 *   2) 사이드 메뉴·셸 탭 오픈 시 호출한다
 *   3) 레지스트리에 키가 있으면 true
 */
export function isImplemented(
  // 판정할 화면코드
  scrnCd: string
): boolean {
  return !!SCREEN_REGISTRY[scrnCd];
}
