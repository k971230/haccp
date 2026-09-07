/**
 * DocumentRemarkRequest — 문서 결재 첨부 비고.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) PUT /{docIdx}/remark 본문. JSON 키 remark
 *   2) 빈 문자열이면 지운다
 *   3) 제목(title) 과 다른 칸이다
 *
 * PIPELINE[HB86] 문서 DTO
 */
package com.haccp.docs.documents.dto;

import lombok.Data;

/** 결재 첨부 비고 */
@Data
public class DocumentRemarkRequest {
    // tbl_document.remark
    private String remark;
}
