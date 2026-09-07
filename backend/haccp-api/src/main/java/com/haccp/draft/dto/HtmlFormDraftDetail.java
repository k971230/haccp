/**
 * HtmlFormDraftDetail — HTML 작성 상세.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) FE htmlFormDraftTypes.ts HtmlFormDraftDetail 과 1:1
 *   2) 키 header·items·logRows·passRows·corrective·updDt
 *   3) HYG·CCP검증은 logRows·passRows 가 비어 온다
 *
 * PIPELINE[HB135] 양식 작성 공용 DTO
 */
package com.haccp.draft.dto;

import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormItemRow;
import com.haccp.flow.ca.dto.DocCorrectiveDto;
import java.util.List;
import lombok.Data;

/** HTML 작성 상세 */
@Data
public class HtmlFormDraftDetail {
    private HtmlFormDraftHeader header;
    private List<HtmlFormItemRow> items;
    private List<DraftLogRow> logRows;
    private List<DraftPassRow> passRows;
    private DocCorrectiveDto corrective;
    // 상세에서 받은 문서 스탬프 — 저장 때 seenUpdDt 로 되돌린다
    private String updDt;
}
