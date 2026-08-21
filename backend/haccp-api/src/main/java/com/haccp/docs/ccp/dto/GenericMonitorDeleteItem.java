/**
 * GenericMonitorDeleteItem — 공통 CCP 일지 삭제 키.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) OPS_DELETE — Body는 객체 배열 [{ docIdx }]. 스칼라 배열 금지
 *   2) UI 단건 삭제도 1건 배열로 보낸다
 *   3) validate-delete·delete가 같은 타입을 받는다
 *
 * PIPELINE[HB98] ccp DTO
 */
package com.haccp.docs.ccp.dto;

import lombok.Data;

@Data
public class GenericMonitorDeleteItem {
    // 삭제 대상 문서 idx
    private Long docIdx;
}
