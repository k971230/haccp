/**
 * HealthCertFileMeta — 열람·삭제용 경로 행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) RLS 를 통과한 이력만 내려준다
 *   2) 커밋 뒤 디스크 삭제에 쓴다
 *   3) userId 는 감사
 *
 * PIPELINE[HB148] 보건증 DTO
 */
package com.haccp.flow.box.healthcert.dto;

import lombok.Data;

@Data
public class HealthCertFileMeta {
    private Long idx;
    private String filePath;
    private String userId;
    // 마스터 키로 감싼 파일 DEK(hex). 목록 API 에는 안 내린다
    private String wrappedDek;
    // 내려받기 표시명 — 디스크는 UUID
    private String fileNm;
    private String fileExt;
    // UPDATE wrapped_dek 때 테넌트 범위. 목록 API 에는 안 내린다
    private String coCd;
    private Integer keyVersion;
}
