/**
 * DraftItemRow — 작성 점검 항목 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) FE HtmlFormItem 과 1:1. HYG·CCP검증 저장 items 가 이 타입이다
 *   2) yn·valNm 은 작성값. 원본 항목에는 비어 온다
 *   3) HtmlFormItemRow 와 키가 같다. 작성 저장만 여기를 쓴다
 *
 * PIPELINE[HB135] 양식 작성 공용 DTO
 */
package com.haccp.draft.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Data;

/** 점검 항목 작성 행 — 비어 있는 칸은 JSON 에 안 넣는다 */
@Data
@JsonInclude(JsonInclude.Include.NON_NULL)
public class DraftItemRow {
    private String itemCd;
    private Integer sortNo;
    private String cycleNm;
    private String grpNm;
    private String itemNm;
    private String inputType;
    private String unitNm;
    private String yn;
    private String valNm;
}
