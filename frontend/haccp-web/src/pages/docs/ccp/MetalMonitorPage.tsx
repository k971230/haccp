// 역할 — PDF 금속검출 감도·통과량 양식을 CCP 공통 편집 화면에 연결
import { CcpFormPage } from "./CcpFormPage";

export default function MetalMonitorPage() {
  return <CcpFormPage form="metal-monitor" screenCode="ccp-metal-monitor" title="CCP 금속검출 모니터링 일지" />;
}
