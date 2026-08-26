/**
 * DocumentDeleteItem — 문서 삭제 키.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) OPS_DELETE 계약에 따라 UI 단건도 객체 배열 [{ docIdx }]로 받는다
 *   2) validate-delete와 delete가 같은 타입을 공유해 사전·실제 검증을 일치시킨다
 *   3) 문서 상태 검증은 Service와 SP에서 이중으로 수행한다. 보존기간은 삭제 차단에 쓰지 않는다
 *
 * PIPELINE[HB81] doc DTO
 * PIPELINE[HB51] 연관 모듈
 */
package com.haccp.docs.documents.dto;

// 역할 — Lombok getter/setter
import lombok.Data;

/** 문서 삭제 대상 1건 */
@Data
public class DocumentDeleteItem {
    // 삭제할 tbl_document.idx
    private Long docIdx;
}
