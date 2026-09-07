/**
 * UserSignBlobRow — 서명 이미지 실물.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 미리보기·클립보드 복사만 이 행을 읽는다
 *   2) 유무 판정은 UserSignInfoRow 를 쓴다
 *   3) 미등록이면 signImg 가 null
 *
 * PIPELINE[HB93] 사용자 관리 DTO
 */
package com.haccp.sys.code.user.dto;

import lombok.Data;

@Data
public class UserSignBlobRow {
    // 서명 이미지 바이너리
    private byte[] signImg;
    // 이미지 MIME
    private String signMime;
    // 원본 파일명
    private String signNm;
}
