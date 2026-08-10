/**
 * ColdMonitorSaveRequest — 냉장보관 일지 저장 요청.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) docIdx가 null/0이면(= 신규) 문서번호를 채번하고 헤더를 만든다
 *   2) rows는 점검시간·온도 전체 교체 단위다 — 부분 패치가 아니다
 *   3) coCd·작성자는 JWT에서만 읽는다. 본문에 넣어도 쓰지 않는다
 *
 * PIPELINE[HB67] ccp DTO
 */
package com.metis.haccp.ccp.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import java.util.ArrayList;
import java.util.List;
import lombok.Data;

@Data
public class ColdMonitorSaveRequest {
    // 기존 문서 idx — 신규면 null
    private Long docIdx;
    // 작성일 YYYYMMDD
    @NotBlank
    private String baseDt;
    // 적용 CCP 코드 — 기본 CCP-1B
    @NotBlank
    private String ccpCd;
    // 담당자 ID
    private String mngUserId;
    // 담당자명
    private String mngNm;
    // 점검행 전체
    @NotEmpty
    private List<ColdMonitorRowDto> rows = new ArrayList<>();
    // 이탈 푸터 — 비어 있으면 CA 삭제
    private DocCorrectiveDto corrective;
}
