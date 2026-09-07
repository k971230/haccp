/**
 * HtmlFormItemRow — HTML 양식 항목 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) SP 항목 컬럼과 1:1. 작성 값은 yn·valNm
 *   2) FE HtmlFormItem 과 같은 키다
 *   3) 원본 목록에는 yn·valNm 이 비어 온다
 *
 * PIPELINE[HB130] HTML양식 원본 DTO
 */
package com.haccp.docs.htmlform.htmltemplate.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Data;

/** 양식 항목 1건 — 비어 있는 칸은 JSON 에 안 넣는다 */
@Data
@JsonInclude(JsonInclude.Include.NON_NULL)
public class HtmlFormItemRow {
    // 항목코드
    private String itemCd;
    // 정렬순서
    private Integer sortNo;
    // 주기명
    private String cycleNm;
    // 그룹명
    private String grpNm;
    // 항목명
    private String itemNm;
    // 입력유형 RADIO·NUM 등
    private String inputType;
    // 단위
    private String unitNm;
    // 예/아니오 — 작성만
    private String yn;
    // 기록값 — 작성만
    private String valNm;
}
