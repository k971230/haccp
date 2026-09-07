/**
 * HwpTemplateFileRow — 사용양식 파일 이력 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_hwp_template_management_file_r_000 컬럼과 1:1
 *   2) 현재적용·기본제공 표시를 함께 내린다
 *   3) 삭제된 이력은 SP 가 빼 둔다
 *
 * PIPELINE[HB123] 사용양식 DTO
 */
package com.haccp.docs.hwp.dto;

import java.time.LocalDateTime;
import lombok.Data;

/** 양식 파일 이력 1건 */
@Data
public class HwpTemplateFileRow {
    private Long idx;
    private Integer fileSeq;
    private String fileNm;
    private Long fileSize;
    private String srcTy;
    private String currentYn;
    private String defaultYn;
    private String insId;
    private LocalDateTime insDt;
}
