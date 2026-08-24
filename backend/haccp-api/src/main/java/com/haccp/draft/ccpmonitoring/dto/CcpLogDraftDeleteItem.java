/**
 * CcpLogDraftDeleteItem — 작성 삭제 키.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) CCP 포장·가열·금속검출 작성 3화면이 같은 DTO 를 쓴다. 화면마다 복제하지 않는다
 *   2) 모양은 HYG(draft.hyg)·CCP검증(draft.ccp)과 같다. 서버 테이블·SP 만 계열별로 다르다
 *   3) Body 는 [{ docIdx }] 객체 배열이다 (OPS_DELETE). HTTP DELETE 는 쓰지 않는다
 *
 * PIPELINE[HB139] CCP 모니터링 작성 DTO
 */
package com.haccp.draft.ccpmonitoring.dto;

import lombok.Data;

@Data
public class CcpLogDraftDeleteItem {
    // 삭제할 tbl_document.idx
    private Long docIdx;
}
