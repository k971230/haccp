/**
 * DocCycleDeleteItem — 문서주기 삭제 업무키.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 양식당 주기 1건이므로 tmplCd만으로 삭제 대상이 확정된다
 *   2) HTTP DELETE와 스칼라 배열을 쓰지 않아 복합 업무키 확장에 대비한다
 *   3) coCd·작업자는 이 DTO에 두지 않고 LoginUserContext에서만 읽는다
 *
 * PIPELINE[HB99] 문서주기 삭제 DTO
 * PIPELINE[HB94, HB98] 연관 모듈
 */
package com.haccp.docs.doccycle.dto;

// 역할 — Lombok 접근자
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class DocCycleDeleteItem {
    // 삭제할 주기의 양식코드 — 공백이면 Service가 업무 예외를 던진다
    private String tmplCd;
}
