/**
 * DocumentTitleRequest — 작성 목록 제목.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) PUT /{docIdx}/title 본문. JSON 키 title
 *   2) 빈 문자열이면 지운다
 *   3) 결재 첨부 remark 와 다르다
 *
 * PIPELINE[HB86] 문서 DTO
 */
package com.haccp.docs.documents.dto;

import lombok.Data;

/** 작성 목록 제목 */
@Data
public class DocumentTitleRequest {
    // tbl_document.title
    private String title;
}
