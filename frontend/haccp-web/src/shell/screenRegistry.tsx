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
// 역할 — CCP 냉장·냉동 보관 모니터링 일지
import ColdMonitorPage from "@/pages/docs/ccp/ColdMonitorPage";
// 역할 — 가열·멸균·여과 등 공통 CCP 모니터링
import CcpGenericMonitorPage from "@/pages/docs/ccp/CcpGenericMonitorPage";
// 역할 — CCP 금속검출 모니터링 일지
import MetalMonitorPage from "@/pages/docs/ccp/MetalMonitorPage";
// 역할 — 중요관리점 검증점검표
import VerificationCheckPage from "@/pages/docs/ccp/VerificationCheckPage";
// 역할 — 위생 DB형 (일일·방충)
import HygieneCheckPage from "@/pages/docs/prp/HygieneCheckPage";
// 역할 — 통합 문서함·결재함·결재이력
import DocumentBoxPage from "@/pages/flow/box/documentbox/DocumentBoxPage";
// 역할 — 법적서류 그리드 첨부
import LegalDocumentUploadPage from "@/pages/flow/box/legalupload/LegalDocumentUploadPage";
// 역할 — 건강진단관리기록부 인원 그리드
import HealthCertPage from "@/pages/docs/prp/HealthCertPage";
// 역할 — HWP 양식 파일 관리
import HwpTemplateManagementPage from "@/pages/docs/hwp/HwpTemplateManagementPage";
// 역할 — HWP 문서 작성 leaf. 공용 에디터에 양식코드를 고정한다
import ProcessHwpPage from "@/pages/docs/ccp/process-hwp/ProcessHwpPage";
import VisualInspStandardPage from "@/pages/docs/prp/visual-insp-standard/VisualInspStandardPage";
import CalibSelfHwpPage from "@/pages/docs/prp/calib-self-hwp/CalibSelfHwpPage";
import CalibExtHwpPage from "@/pages/docs/prp/calib-ext-hwp/CalibExtHwpPage";
import WasteHwpPage from "@/pages/docs/prp/waste-hwp/WasteHwpPage";
import VerifyCaHwpPage from "@/pages/docs/prp/verify-ca-hwp/VerifyCaHwpPage";
import PersonalHygHwpPage from "@/pages/docs/prp/personal-hyg-hwp/PersonalHygHwpPage";
import AreaHygHwpPage from "@/pages/docs/prp/area-hyg-hwp/AreaHygHwpPage";
import WaterHwpPage from "@/pages/docs/prp/water-hwp/WaterHwpPage";
import VerifyPlanHwpPage from "@/pages/docs/prp/verify-plan-hwp/VerifyPlanHwpPage";
import VerifyCheckHwpPage from "@/pages/docs/prp/verify-check-hwp/VerifyCheckHwpPage";
import VerifyReportHwpPage from "@/pages/docs/prp/verify-report-hwp/VerifyReportHwpPage";
import ProdTestHwpPage from "@/pages/docs/prp/prod-test-hwp/ProdTestHwpPage";
import SurfaceTestHwpPage from "@/pages/docs/prp/surface-test-hwp/SurfaceTestHwpPage";
import ReceivingInspHwpPage from "@/pages/docs/logis/receiving-insp-hwp/ReceivingInspHwpPage";
import SubmaterialRecvHwpPage from "@/pages/docs/logis/submaterial-recv-hwp/SubmaterialRecvHwpPage";
import ShipmentLogHwpPage from "@/pages/docs/logis/shipment-log-hwp/ShipmentLogHwpPage";
import InventoryHwpPage from "@/pages/docs/logis/inventory-hwp/InventoryHwpPage";
import VehicleHwpPage from "@/pages/docs/logis/vehicle-hwp/VehicleHwpPage";
import VisitorLogPage from "@/pages/docs/admin/visitor-log/VisitorLogPage";
import EduPlanHwpPage from "@/pages/docs/admin/edu-plan-hwp/EduPlanHwpPage";
import EduLogHwpPage from "@/pages/docs/admin/edu-log-hwp/EduLogHwpPage";
import BadProductHwpPage from "@/pages/docs/admin/bad-product-hwp/BadProductHwpPage";
import ClaimHwpPage from "@/pages/docs/admin/claim-hwp/ClaimHwpPage";
import RecallHwpPage from "@/pages/docs/admin/recall-hwp/RecallHwpPage";
import EvalHwpPage from "@/pages/docs/admin/eval-hwp/EvalHwpPage";
import HandoverHwpPage from "@/pages/docs/admin/handover-hwp/HandoverHwpPage";
// 역할 — HTML 양식 원본(공정점검 버전)
import HtmlTemplatePage from "@/pages/docs/html/htmltemplate/HtmlTemplatePage";
// 역할 — HTML 양식 원본(CCP 검증점검)
import CcpVerifyTemplatePage from "@/pages/docs/html/ccpverifytemplate/CcpVerifyTemplatePage";
// 역할 — HTML 양식 원본(CCP-1B 포장 모니터링일지)
import CcpPkgTemplatePage from "@/pages/docs/html/ccppkgtemplate/CcpPkgTemplatePage";
// 역할 — HTML 양식 원본(CCP-2B 가열 모니터링일지)
import CcpHtgTemplatePage from "@/pages/docs/html/ccphtgtemplate/CcpHtgTemplatePage";
// 역할 — HTML 양식 원본(CCP-3P 금속검출 모니터링일지)
import CcpMtlTemplatePage from "@/pages/docs/html/ccpmtltemplate/CcpMtlTemplatePage";
// 역할 — 일반위생관리 및 공정점검표 작성
import HygProcessPage from "@/pages/docs/html/hygprocess/HygProcessPage";
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
// 역할 — 기초정보·한계기준 마스터
import MasterDataPage from "@/pages/bas/master/MasterDataPage";
// 역할 — 설비카드 이력 M-D
import EquipmentHistoryPage from "@/pages/docs/prp/EquipmentHistoryPage";
// 역할 — 방충설비 이력 M-D
import PestDeviceHistoryPage from "@/pages/docs/prp/PestDeviceHistoryPage";
import ScheduleCycleManagementPage from "@/pages/docs/sch/ScheduleCycleManagementPage";
// 역할 — 설비·시설 점검 DB형
import BizOpsFormPage from "@/pages/docs/prp/BizOpsFormPage";
// 역할 — 오늘 할 일·개선조치
import TodayTasksPage from "@/pages/tsk/TodayTasksPage";
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
  "product-management": () => <MasterDataPage screenCode="product-management" />,
  "material-management": () => <MasterDataPage screenCode="material-management" />,
  "partner-management": () => <MasterDataPage screenCode="partner-management" />,
  "storage-management": () => <MasterDataPage screenCode="storage-management" />,
  "measuring-device-management": () => <MasterDataPage screenCode="measuring-device-management" />,
  "vehicle-management": () => <MasterDataPage screenCode="vehicle-management" />,
  "work-area-management": () => <MasterDataPage screenCode="work-area-management" />,

  // 문서 기준관리
  // 일지설정 세트(좌 목록+우 업무): 사용양식·HTML 5·문서주기. 슈퍼 셸로 합치지 않음. pages/docs/README.md
  // 시설·설비 관리 메뉴는 이력 M-D로 통합 — 구 화면코드 진입도 동일 화면
  "equipment-management": EquipmentHistoryPage,
  // 포충등·트랩 관리 메뉴는 방충 이력 M-D로 통합
  "pest-device-management": PestDeviceHistoryPage,
  // approval-line-management 는 시스템 관리로 이동
  "hwp-template-management": HwpTemplateManagementPage,
  "hyg-process-template": HtmlTemplatePage,
  "ccp-verify-template": CcpVerifyTemplatePage,
  "ccp-pkg-template": CcpPkgTemplatePage,
  "ccp-htg-template": CcpHtgTemplatePage,
  "ccp-mtl-template": CcpMtlTemplatePage,
  "schedule-cycle-management": ScheduleCycleManagementPage,

  // 문서 작성 — DB
  "daily-hygiene-check": () => <HygieneCheckPage screenCode="daily-hygiene-check" title="일일위생점검표" kind="daily" />,
  "hygiene-process-check": HygProcessPage,
  "pest-control-check": () => <HygieneCheckPage screenCode="pest-control-check" title="방충방서관리점검표" kind="pest" />,
  "ccp-cold-monitor": ColdMonitorPage,
  "ccp-metal-monitor": MetalMonitorPage,
  "ccp-heat-monitor": () => <CcpGenericMonitorPage screenCode="ccp-heat-monitor" defaultTmplCd="html_sys_003" />,
  "ccp-sanitize-monitor": () => <CcpGenericMonitorPage screenCode="ccp-sanitize-monitor" defaultTmplCd="html_sys_004" />,
  "ccp-filter-monitor": () => <CcpGenericMonitorPage screenCode="ccp-filter-monitor" defaultTmplCd="html_sys_005" />,
  "ccp-verification-check": VerificationCheckPage,
  "facility-equipment-check": () => <BizOpsFormPage screenCode="facility-equipment-check" />,
  // 메뉴 숨김(use_yn=N). 문서함 html_sys_010 deep-link 전용. SQL·Page 삭제 금지
  "calibration-target-management": () => <BizOpsFormPage screenCode="calibration-target-management" />,
  // 건강진단관리기록부 — 인원 그리드·첨부 (HA-HYG-02)
  "health-cert-record": HealthCertPage,

  // 문서 작성 — HWP 문서만 (양식 1:1 고정, pages/docs/{중}/{scrnCd}/)
  "visitor-log": VisitorLogPage,
  // 설비 이력 — DB형 M-D (상단 설비·하단 이력). 옛 HWP 설비카드 leaf 대체
  "equipment-history": EquipmentHistoryPage,
  // 방충설비 이력 — DB형 M-D (상단 포충등·트랩·하단 이력)
  "pest-device-history": PestDeviceHistoryPage,
  "visual-insp-standard": VisualInspStandardPage,
  "receiving-insp-hwp": ReceivingInspHwpPage,
  "submaterial-recv-hwp": SubmaterialRecvHwpPage,
  "calib-self-hwp": CalibSelfHwpPage,
  "calib-ext-hwp": CalibExtHwpPage,
  "shipment-log-hwp": ShipmentLogHwpPage,
  "waste-hwp": WasteHwpPage,
  "inventory-hwp": InventoryHwpPage,
  "edu-plan-hwp": EduPlanHwpPage,
  "edu-log-hwp": EduLogHwpPage,
  "bad-product-hwp": BadProductHwpPage,
  "claim-hwp": ClaimHwpPage,
  "recall-hwp": RecallHwpPage,
  "eval-hwp": EvalHwpPage,
  "verify-ca-hwp": VerifyCaHwpPage,
  "handover-hwp": HandoverHwpPage,
  "process-hwp": ProcessHwpPage,
  "vehicle-hwp": VehicleHwpPage,
  "personal-hyg-hwp": PersonalHygHwpPage,
  "area-hyg-hwp": AreaHygHwpPage,
  "water-hwp": WaterHwpPage,
  "verify-plan-hwp": VerifyPlanHwpPage,
  "verify-check-hwp": VerifyCheckHwpPage,
  "verify-report-hwp": VerifyReportHwpPage,
  "prod-test-hwp": ProdTestHwpPage,
  "surface-test-hwp": SurfaceTestHwpPage,

  // 문서 현황·결재
  "document-inbox": () => <DocumentBoxPage mode="inbox" />,
  "approval-inbox": () => <DocumentBoxPage mode="approval" />,
  "approval-history": () => <DocumentBoxPage mode="history" />,
  "legal-document-upload": LegalDocumentUploadPage,
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
