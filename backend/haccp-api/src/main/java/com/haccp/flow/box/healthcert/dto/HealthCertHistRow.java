/**
 * HealthCertHistRow — 보건증 이력 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 우측 그리드. 파일 바이너리·경로는 없고 이름만
 *   2) 열람은 별도 GET
 *   3) 날짜는 YYYYMMDD
 *
 * PIPELINE[HB148] 보건증 DTO
 */
package com.haccp.flow.box.healthcert.dto;

import java.time.LocalDateTime;
import lombok.Data;

@Data
public class HealthCertHistRow {
    private Long idx;
    private String userId;
    private String regDt;
    private String expireDt;
    private String fileNm;
    private String fileExt;
    private Long fileSize;
    private String mimeType;
    private String insNm;
    private LocalDateTime insDt;
}
