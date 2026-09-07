/**
 * CommonCodeDeleteItem — 공통코드 삭제 키.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) OPS_DELETE 계약 — UI 단건도 [{ idx }] 배열
 *   2) validate-delete 와 delete 가 같은 타입을 쓴다
 *   3) coCd 는 JWT 에서만 읽는다
 *
 * PIPELINE[HB93] 공통코드 DTO
 */
package com.haccp.sys.code.commoncode.dto;

import lombok.Data;

/** 공통코드 삭제 대상 1건 */
@Data
public class CommonCodeDeleteItem {
    // 삭제할 tbl_code.idx
    private Long idx;
}
