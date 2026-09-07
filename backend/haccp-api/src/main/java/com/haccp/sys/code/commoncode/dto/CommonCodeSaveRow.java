/**
 * CommonCodeSaveRow — 공통코드 저장 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 화면 그리드가 보내는 camelCase 키를 그대로 받는다 — idx·mainCd·subCd
 *   2) Map 대신 타입을 고정해 오타가 컴파일에서 난다
 *   3) coCd·작업자는 이 DTO 에 두지 않는다. JWT 만 쓴다
 *
 * PIPELINE[HB93] 공통코드 DTO
 */
package com.haccp.sys.code.commoncode.dto;

import lombok.Data;

/** 공통코드 저장 행 — 신규면 idx 없음 */
@Data
public class CommonCodeSaveRow {
    // tbl_code.idx — 없으면 신규
    private Long idx;
    // 대분류 코드
    private String mainCd;
    // 세부 코드
    private String subCd;
    // 코드명
    private String codeNm;
    // 정렬순서. 없으면 SP 가 기존 값을 유지한다
    private Integer sortNo;
    // 참조값1
    private String ref1;
    // 참조값2
    private String ref2;
    // 사용여부 Y/N
    private String useYn;
}
