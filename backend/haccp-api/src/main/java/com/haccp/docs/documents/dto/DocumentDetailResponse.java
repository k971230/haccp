/**
 * DocumentDetailResponse — 문서 상세 조립.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 헤더·결재·파일·버전을 한 응답으로 묶는다
 *   2) JSON 키 header·approvals·files·versions 는 그대로다
 *   3) 파일 물리 경로는 서비스가 뺀다
 *
 * PIPELINE[HB86] 문서 DTO
 */
package com.haccp.docs.documents.dto;

import java.util.List;
import lombok.Data;

/** 문서함 상세 */
@Data
public class DocumentDetailResponse {
    private DocumentHeaderRow header;
    private List<DocumentApprovalRow> approvals;
    private List<DocumentFileRow> files;
    private List<DocumentVersionRow> versions;
    // 상세에서 받은 문서 스탬프 — 저장 때 seenUpdDt 로 되돌린다
    private String updDt;
}
