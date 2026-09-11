/**
 * CompanyDeleteItem — 테넌트 통째 삭제 키.
 *
 * 개발자: 박승우
 * 일자: 2026-09-11
 * 코멘트:
 *   1) OPS_DELETE 계약 — UI 단건도 [{ coCd }] 배열
 *   2) 여기 coCd 는 지울 대상이다. 호출자 회사는 JWT 만 본다
 *   3) 화면이 없다. 플랫폼(0000) 관리자 API 전용
 *
 * PIPELINE[HB146] 업체 삭제 DTO
 */
package com.haccp.sys.company.dto;

import lombok.Data;

/** 테넌트 삭제 대상 1건 */
@Data
public class CompanyDeleteItem {
    // 지울 회사코드 — 호출자 JWT coCd 와 다르다
    private String coCd;
}
