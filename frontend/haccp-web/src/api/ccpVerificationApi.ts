// 역할 — CCP 검증점검표 화면 전용 공통 API 별칭
export {
  deleteCcpForm as deleteVerificationCheck,
  detailCcpForm as getVerificationCheckDetail,
  listCcpForms as listVerificationChecks,
  saveCcpForm as saveVerificationCheck,
  validateDeleteCcpForm as validateDeleteVerificationCheck,
} from "./ccpFormsApi";
