/**
 * screenRegistry — 화면코드에서 실제 React 화면을 찾는 표.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 셸은 이 표만 보고 화면을 마운트한다 — 셸이 개별 화면을 직접 import하지 않는다
 *   2) IA 메뉴(문서작성·현황·기준·기초·시스템)에 노출되는 화면만 등록한다
 *   3) HWP 문서만 leaf는 동일 editor에 tmplCd를 고정해 메뉴·권한을 분리한다
 *
 * PIPELINE[HF51] 화면 레지스트리
 * PIPELINE[HF49] 연관 모듈
 */
// 역할 — 화면 컴포넌트 타입
import type { ComponentType } from "react";
// 역할 — CCP 냉장·냉동 보관 모니터링 일지
import ColdMonitorPage from "@/pages/ccp/ColdMonitorPage";
// 역할 — 가열·멸균·여과 등 공통 CCP 모니터링
import CcpGenericMonitorPage from "@/pages/ccp/CcpGenericMonitorPage";
// 역할 — CCP 금속검출 모니터링 일지
import MetalMonitorPage from "@/pages/ccp/MetalMonitorPage";
// 역할 — 중요관리점 검증점검표
import VerificationCheckPage from "@/pages/ccp/VerificationCheckPage";
// 역할 — 위생 DB형 (일일·방충)
import HygieneCheckPage from "@/pages/hyg/HygieneCheckPage";
// 역할 — 통합 문서함·결재함·결재이력
import DocumentBoxPage from "@/pages/doc/DocumentBoxPage";
// 역할 — 법적서류 그리드 첨부
import LegalDocumentUploadPage from "@/pages/doc/LegalDocumentUploadPage";
// 역할 — 건강진단관리기록부 인원 그리드
import HealthCertPage from "@/pages/hyg/HealthCertPage";
// 역할 — rhwp HWP 문서형 작성·일자별 업로드
import HwpDocumentEditorPage from "@/pages/doc/HwpDocumentEditorPage";
// 역할 — HWP 양식 파일 관리
import HwpTemplateManagementPage from "@/pages/bas/HwpTemplateManagementPage";
// 역할 — 기초정보·한계기준 마스터
import MasterDataPage from "@/pages/bas/MasterDataPage";
// 역할 — 설비카드 이력 M-D
import EquipmentHistoryPage from "@/pages/bas/EquipmentHistoryPage";
// 역할 — 방충설비 이력 M-D
import PestDeviceHistoryPage from "@/pages/bas/PestDeviceHistoryPage";
// 역할 — 결재선·점검항목·작성주기
import ApprovalLineManagementPage from "@/pages/bas/ApprovalLineManagementPage";
import TemplateCheckItemManagementPage from "@/pages/bas/TemplateCheckItemManagementPage";
import ScheduleCycleManagementPage from "@/pages/bas/ScheduleCycleManagementPage";
// 역할 — 설비·시설 점검 DB형
import BizOpsFormPage from "@/pages/ops/BizOpsFormPage";
// 역할 — 오늘 할 일·개선조치
import TodayTasksPage from "@/pages/tsk/TodayTasksPage";
import CorrectiveActionManagementPage from "@/pages/doc/CorrectiveActionManagementPage";
// 역할 — 시스템 관리
import SystemManagementPage from "@/pages/sys/SystemManagementPage";

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) HWP 문서만 leaf용 래퍼 — 양식코드 1개를 고정한다
 *   2) screenRegistry 각 HWP 메뉴에서 호출한다
 *   3) 권한은 PageScrnContext의 scrn_cd로 판정한다
 */
function hwpLeaf(
  // 고정할 표준 양식코드 — tbl_template.tmpl_cd
  tmplCd: string
): ComponentType {
  return function HwpLeafScreen() {
    return <HwpDocumentEditorPage fixedTmplCd={tmplCd} />;
  };
}

/**
 * 화면코드 → 화면 컴포넌트.
 * DB tbl_screen.scrn_cd와 키가 문자 그대로 같아야 한다.
 */
export const SCREEN_REGISTRY: Record<string, ComponentType> = {
  // 오늘 할 일 — 랜딩
  "today-tasks": TodayTasksPage,

  // 시스템 관리
  "company-management": () => <SystemManagementPage screenCode="company-management" />,
  "user-management": () => <SystemManagementPage screenCode="user-management" />,
  "department-management": () => <SystemManagementPage screenCode="department-management" />,
  "role-management": () => <SystemManagementPage screenCode="role-management" />,
  "menu-management": () => <SystemManagementPage screenCode="menu-management" />,
  "login-history": () => <SystemManagementPage screenCode="login-history" />,
  "screen-usage-statistics": () => <SystemManagementPage screenCode="screen-usage-statistics" />,
  "audit-log": () => <SystemManagementPage screenCode="audit-log" />,

  // 기초정보 관리
  "common-code-management": () => <SystemManagementPage screenCode="common-code-management" />,
  "product-management": () => <MasterDataPage screenCode="product-management" />,
  "material-management": () => <MasterDataPage screenCode="material-management" />,
  "partner-management": () => <MasterDataPage screenCode="partner-management" />,
  "storage-management": () => <MasterDataPage screenCode="storage-management" />,
  "measuring-device-management": () => <MasterDataPage screenCode="measuring-device-management" />,
  "vehicle-management": () => <MasterDataPage screenCode="vehicle-management" />,
  "work-area-management": () => <MasterDataPage screenCode="work-area-management" />,

  // 문서 기준관리
  "ccp-limit-management": () => <MasterDataPage screenCode="ccp-limit-management" />,
  // 시설·설비 관리 메뉴는 이력 M-D로 통합 — 구 화면코드 진입도 동일 화면
  "equipment-management": EquipmentHistoryPage,
  // 포충등·트랩 관리 메뉴는 방충 이력 M-D로 통합
  "pest-device-management": PestDeviceHistoryPage,
  "approval-line-management": ApprovalLineManagementPage,
  // template-check-item-management — 문서별 admin으로 분할 완료, 레지스트리·메뉴 제거(migrate 47)
  "hwp-template-management": HwpTemplateManagementPage,
  "schedule-cycle-management": ScheduleCycleManagementPage,
  // 문서별 기준관리 (C3)
  "daily-hyg-item-admin": () => (
    <TemplateCheckItemManagementPage screenCode="daily-hyg-item-admin" fixedTmplCd="DAILY_HYG" />
  ),
  "ccp-cold-limit-admin": () => <MasterDataPage screenCode="ccp-cold-limit-admin" />,
  "ccp-heat-limit-admin": () => <MasterDataPage screenCode="ccp-heat-limit-admin" />,
  "ccp-sanitize-limit-admin": () => <MasterDataPage screenCode="ccp-sanitize-limit-admin" />,
  "ccp-filter-limit-admin": () => <MasterDataPage screenCode="ccp-filter-limit-admin" />,
  "ccp-metal-limit-admin": () => <MasterDataPage screenCode="ccp-metal-limit-admin" />,
  "ccp-verify-standard-admin": () => (
    <TemplateCheckItemManagementPage screenCode="ccp-verify-standard-admin" fixedTmplCd="CCP_VERIFY" />
  ),
  "facility-check-item-admin": () => (
    <TemplateCheckItemManagementPage screenCode="facility-check-item-admin" fixedTmplCd="FACILITY" />
  ),

  // 문서 작성 — DB
  "daily-hygiene-check": () => <HygieneCheckPage screenCode="daily-hygiene-check" title="일일위생점검표" kind="daily" />,
  "pest-control-check": () => <HygieneCheckPage screenCode="pest-control-check" title="방충방서관리점검표" kind="pest" />,
  "ccp-cold-monitor": ColdMonitorPage,
  "ccp-metal-monitor": MetalMonitorPage,
  "ccp-heat-monitor": () => <CcpGenericMonitorPage screenCode="ccp-heat-monitor" defaultTmplCd="CCP_HEAT" />,
  "ccp-sanitize-monitor": () => <CcpGenericMonitorPage screenCode="ccp-sanitize-monitor" defaultTmplCd="CCP_SANITIZE" />,
  "ccp-filter-monitor": () => <CcpGenericMonitorPage screenCode="ccp-filter-monitor" defaultTmplCd="CCP_FILTER" />,
  "ccp-verification-check": VerificationCheckPage,
  "facility-equipment-check": () => <BizOpsFormPage screenCode="facility-equipment-check" />,
  // 건강진단관리기록부 — 인원 그리드·첨부 (HA-HYG-02)
  "health-cert-record": HealthCertPage,

  // 문서 작성 — HWP 문서만 (양식 1:1 고정)
  "visitor-log": hwpLeaf("VISITOR_LOG"),
  // 설비 이력 — DB형 M-D (상단 설비·하단 이력). HWP EQUIP_CARD leaf 대체
  "equipment-history": EquipmentHistoryPage,
  // 방충설비 이력 — DB형 M-D (상단 포충등·트랩·하단 이력)
  "pest-device-history": PestDeviceHistoryPage,
  "visual-insp-standard": hwpLeaf("VISUAL_INSP"),
  "receiving-insp-hwp": hwpLeaf("RECV_INSP"),
  "submaterial-recv-hwp": hwpLeaf("SUBMAT_RECV"),
  "calib-self-hwp": hwpLeaf("CALIB_LOG_TEMP"),
  "calib-ext-hwp": hwpLeaf("CALIB_EXT"),
  "shipment-log-hwp": hwpLeaf("SHIPMENT"),
  "waste-hwp": hwpLeaf("WASTE"),
  "inventory-hwp": hwpLeaf("INV_CHECK"),
  "edu-plan-hwp": hwpLeaf("EDU_PLAN"),
  "edu-log-hwp": hwpLeaf("EDU_LOG"),
  "bad-product-hwp": hwpLeaf("BAD_PRODUCT"),
  "claim-hwp": hwpLeaf("CLAIM"),
  "recall-hwp": hwpLeaf("RECALL"),
  "eval-hwp": hwpLeaf("EVAL"),
  "verify-ca-hwp": hwpLeaf("VERIFY_CA"),
  "handover-hwp": hwpLeaf("HANDOVER"),
  "process-hwp": hwpLeaf("PROCESS"),
  "vehicle-hwp": hwpLeaf("VEHICLE_LOG"),
  "personal-hyg-hwp": hwpLeaf("PERSONAL_HYG"),
  "area-hyg-hwp": hwpLeaf("AREA_HYG"),
  "water-hwp": hwpLeaf("WATER"),
  "verify-plan-hwp": hwpLeaf("VERIFY_PLAN"),
  "verify-check-hwp": hwpLeaf("VERIFY_CHECK"),
  "verify-report-hwp": hwpLeaf("VERIFY_REPORT"),
  "prod-test-hwp": hwpLeaf("PROD_TEST"),
  "surface-test-hwp": hwpLeaf("SURFACE_TEST"),

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
