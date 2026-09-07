/**
 * HwpTemplateSaveRow — 사용양식 저장 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 화면이 보내는 camelCase 키를 그대로 받는다 — tmplCd·tmplNm·useYn
 *   2) Map 대신 타입을 고정해 오타가 컴파일에서 난다
 *   3) coCd·작업자는 이 DTO 에 두지 않는다. JWT 만 쓴다
 *
 * PIPELINE[HB123] 사용양식 DTO
 */
package com.haccp.docs.hwp.dto;

import lombok.Data;

/** 사용양식 저장 행 — 신규는 SP 가 자사양식으로 강제한다 */
@Data
public class HwpTemplateSaveRow {
    // 양식코드 — 신규만 입력, 이후 잠금
    private String tmplCd;
    // 양식명
    private String tmplNm;
    // 사용여부 Y/N. 없으면 서버가 Y
    private String useYn;
}
