/**
 * CcpChkPaper — 중요관리점(CCP) 검증점검표 지면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 표 HTML은 공정점검 HygPrcPaper 와 같다. 복사본을 두지 않는다
 *   2) 라디오 전용은 값 칸이 비고, 값 입력이 있으면 빨간 테두리
 *   3) 제목·항목은 이 화면 데이터(html_ccp_chk_*)다
 *
 * PIPELINE[HF131] CCP 검증점검 지면
 */
export { HygPrcPaper as CcpChkPaper } from "../htmltemplate/HygPrcPaper";
