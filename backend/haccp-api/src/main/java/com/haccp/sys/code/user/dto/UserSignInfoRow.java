/**
 * UserSignInfoRow — 서명 보유여부 메타.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 이미지 없이 signYn·signNm·signMime 만 담는다
 *   2) 행 서명 버튼이 등록 여부만 확인할 때 쓴다
 *   3) 미등록이면 signYn=N, 이름·MIME 은 빈 문자열
 *
 * PIPELINE[HB93] 사용자 관리 DTO
 */
package com.haccp.sys.code.user.dto;

import lombok.Data;

@Data
public class UserSignInfoRow {
    // 서명 보유여부 Y/N
    private String signYn;
    // 원본 파일명 — 미등록이면 빈 문자열
    private String signNm;
    // 이미지 MIME — 미등록이면 빈 문자열
    private String signMime;
}
