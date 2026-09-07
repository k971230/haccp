/**
 * DocumentApprovalRow — 문서 결재 단계 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_document_approval_r_000 컬럼과 1:1
 *   2) WRITE·APPROVE 순. 검토 단계는 없다
 *   3) signYn 은 서명 스냅샷 여부
 *
 * PIPELINE[HB84] 문서 DTO
 */
package com.haccp.docs.documents.dto;

import java.time.LocalDateTime;
import lombok.Data;

/** 결재 단계 1건 */
@Data
public class DocumentApprovalRow {
    private Long idx;
    private Long docIdx;
    private Integer stepNo;
    private String roleCd;
    private String approverId;
    private String approverNm;
    private String resultCd;
    private String opinion;
    private LocalDateTime actDt;
    private String signYn;
}
