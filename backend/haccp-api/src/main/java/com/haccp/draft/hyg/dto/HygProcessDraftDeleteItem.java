/**
 * HygProcessDraftDeleteItem — 위생공정 작성 삭제 키.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) Body 는 [{ docIdx }] 객체 배열이다 (OPS_DELETE)
 *   2) 회사코드는 JWT 로만 정한다
 *   3) HTTP DELETE 는 쓰지 않는다
 *
 * PIPELINE[HB135] 위생공정 작성 DTO
 */
package com.haccp.draft.hyg.dto;

import lombok.Data;

@Data
public class HygProcessDraftDeleteItem {
    // 삭제할 tbl_document.idx
    private Long docIdx;
}
