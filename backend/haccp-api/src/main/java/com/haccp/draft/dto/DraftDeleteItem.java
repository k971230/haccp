/**
 * DraftDeleteItem — 작성 삭제 키 (양식 작성 5화면 공용).
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) Body 는 [{ docIdx }] 객체 배열이다 — UI 단건이어도 1건 배열 (OPS_DELETE)
 *   2) 회사코드는 요청 본문으로 받지 않는다. LoginUserContext(JWT)만 쓴다
 *   3) HTTP DELETE 는 쓰지 않는다 — validate-delete → delete 둘 다 POST 다
 *
 * PIPELINE[HB135] 양식 작성 공용 DTO
 */
package com.haccp.draft.dto;

import lombok.Data;

@Data
public class DraftDeleteItem {
    // 삭제할 tbl_document.idx
    private Long docIdx;
}
