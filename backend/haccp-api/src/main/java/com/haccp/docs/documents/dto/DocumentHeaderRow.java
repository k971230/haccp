/**
 * DocumentHeaderRow — 문서 공통 헤더 단건.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_document_r_001 컬럼과 1:1
 *   2) 상세 조립의 header 키와 같다
 *   3) 조인 컬럼 writerNm·tmplNm·approverNm 도 필드다
 *
 * PIPELINE[HB84] 문서 DTO
 */
package com.haccp.docs.documents.dto;

import java.time.LocalDateTime;
import lombok.Data;

/** 문서 헤더 */
@Data
public class DocumentHeaderRow {
    private Long docIdx;
    private String coCd;
    private String tmplCd;
    private String tmplNm;
    private String docKind;
    private String docNo;
    private String baseDt;
    private String baseDtTo;
    private String title;
    private String status;
    private String apprLineCd;
    private String writerId;
    private String writerNm;
    private LocalDateTime writeDt;
    private String approverId;
    private String approverNm;
    private LocalDateTime approveDt;
    private String rejectReason;
    private Integer verNo;
    private String retentionUntil;
    private String remark;
    private String cancelReason;
}
