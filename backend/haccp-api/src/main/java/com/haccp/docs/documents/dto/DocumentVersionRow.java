/**
 * DocumentVersionRow — 문서 버전 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_document_version_r_000 컬럼과 1:1
 *   2) filePath 는 내부 다운로드에서만 쓴다
 *   3) API 응답에서 경로는 서비스가 뺀다
 *
 * PIPELINE[HB84] 문서 DTO
 */
package com.haccp.docs.documents.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import java.time.LocalDateTime;
import lombok.Data;

/** 문서 버전 1건 */
@Data
public class DocumentVersionRow {
    private Long idx;
    private Long docIdx;
    private Integer verNo;
    // 내부 다운로드 경로 — API 응답에는 안 실는다
    @JsonIgnore
    private String filePath;
    private String changeReason;
    private String insId;
    private LocalDateTime insDt;
}
