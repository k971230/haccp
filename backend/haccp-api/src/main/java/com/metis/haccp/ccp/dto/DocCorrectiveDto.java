/**
 * DocCorrectiveDto — 문서형 일지 이탈 푸터 값.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) tbl_corrective_action 문서 단위 1건과 대응한다
 *   2) Cold·Metal·위생·시설 저장·상세에서 공통으로 쓴다
 *   3) 네 칸이 모두 비면 SP가 CA 행을 삭제한다
 *
 * PIPELINE[HB62] ccp DTO
 */
package com.metis.haccp.ccp.dto;

import lombok.Data;

@Data
public class DocCorrectiveDto {
    private Long idx;
    private String deviationDesc;
    private String actionDesc;
    private String actionUserNm;
    private String confirmUserNm;
    private String status;
}
