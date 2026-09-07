/**
 * CcpMonitorDraftDetail — CCP 모니터링 작성 상세.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) FE HtmlFormDraftDetail 과 같은 키다
 *   2) 포장·가열·금속이 이 타입을 쓴다
 *   3) 금속만 passRows 를 채운다
 *
 * PIPELINE[HB139] CCP 모니터링 작성 DTO
 */
package com.haccp.draft.dto;

import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormItemRow;
import com.haccp.flow.ca.dto.DocCorrectiveDto;
import java.util.List;
import lombok.Data;

/** CCP 모니터 작성 상세 */
@Data
public class CcpMonitorDraftDetail {
    private HtmlFormDraftHeader header;
    private List<HtmlFormItemRow> items;
    private List<DraftLogRow> logRows;
    private List<DraftPassRow> passRows;
    private DocCorrectiveDto corrective;
    // 상세에서 받은 문서 스탬프 — 저장 때 seenUpdDt 로 되돌린다
    private String updDt;
}
