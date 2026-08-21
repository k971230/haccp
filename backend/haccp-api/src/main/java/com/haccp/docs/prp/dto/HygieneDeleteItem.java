/**
 * HygieneDeleteItem — 위생 양식 삭제 키.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) DELETE API Body는 UI 단건이어도 객체 배열만 허용한다
 *   2) 문서 idx는 Service에서 양수 여부를 다시 검증한다
 *   3) 회사코드·양식코드는 경로와 JWT에서만 정한다
 *
 * PIPELINE[HB83] 위생 DTO
 * PIPELINE[HB84] 연관 모듈
 */
package com.haccp.docs.prp.dto;

import lombok.Data;

@Data
public class HygieneDeleteItem {
    // 삭제할 tbl_document.idx
    private Long docIdx;
}
