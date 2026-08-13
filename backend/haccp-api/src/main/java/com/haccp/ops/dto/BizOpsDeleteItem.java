/**
 * BizOpsDeleteItem — DB형 양식 삭제 복합키 항목.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 삭제 요청은 UI 단건이어도 [{ docIdx }] 객체 배열로 받는다
 *   2) templateCode는 URL에서만 결정하므로 본문으로 받지 않아 다른 양식 문서 삭제를 막는다
 *   3) validate-delete와 delete가 같은 키 목록으로 이 DTO를 사용한다
 *
 * PIPELINE[HB88] 시설·재고·공정 DTO
 * PIPELINE[HB89, HB90, HB91] 연관 모듈
 */
package com.haccp.ops.dto;

import lombok.Data;

@Data
public class BizOpsDeleteItem {
    // 삭제 대상 문서 idx — 양수 검증은 Service에서 수행
    private Long docIdx;
}
