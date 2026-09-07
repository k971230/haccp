/**
 * HtmlFormItemsSaveRequest — HTML 양식 항목 저장 본문.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 저장 버튼이 자사 양식 항목을 통째로 보낸다
 *   2) 표준이면 서버가 거부한다
 *   3) coCd·작업자는 JWT 만 쓴다
 *
 * PIPELINE[HB130] HTML양식 원본 DTO
 */
package com.haccp.docs.htmlform.htmltemplate.dto;

import java.util.List;
import lombok.Data;

/** 항목 전체 교체 */
@Data
public class HtmlFormItemsSaveRequest {
    // 양식코드
    private String tmplCd;
    // 회사 순번
    private Integer verNo;
    // 지면 항목
    private List<HtmlFormItemRow> items;
}
