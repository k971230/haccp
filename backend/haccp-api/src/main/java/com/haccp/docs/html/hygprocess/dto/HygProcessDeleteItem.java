/**
 * HygProcessDeleteItem — 공정점검표 삭제 키.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) Body는 [{ docIdx }] 객체 배열이다
 *   2) 회사·양식은 JWT와 고정 tmpl_cd로만 정한다
 *   3) HTTP DELETE는 쓰지 않는다
 *
 * PIPELINE[HB131] 공정점검 DTO
 */
package com.haccp.docs.html.hygprocess.dto;

import lombok.Data;

@Data
public class HygProcessDeleteItem {
    // 삭제할 tbl_document.idx
    private Long docIdx;
}
