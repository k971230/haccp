// 역할 — CCP 공정별 예·아니오 검증점검표를 공통 편집 화면에 연결
import { CcpFormPage } from "./CcpFormPage";

export default function VerificationCheckPage() {
  return <CcpFormPage form="verification-check" screenCode="ccp-verification-check" title="중요관리점(CCP) 검증점검표" />;
}
