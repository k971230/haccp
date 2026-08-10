/**
 * HygieneSaveRequest — 위생관리 DB형 양식 공통 저장 요청.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 양식별 entries·signers·checkers를 JSON으로 받아 SP가 정규화 테이블에 저장한다
 *   2) docIdx가 null/0이면 신규 문서이며, coCd·작성자는 JWT에서만 읽는다
 *   3) payload는 부분 패치가 아닌 해당 양식의 전체 행 교체 단위다
 *
 * PIPELINE[HB83] 위생 DTO
 * PIPELINE[HB84, HB85] 연관 모듈
 */
package com.metis.haccp.hyg.dto;

import com.fasterxml.jackson.databind.JsonNode;
import com.metis.haccp.ccp.dto.DocCorrectiveDto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class HygieneSaveRequest {
    // 기존 문서 idx — 신규면 null
    private Long docIdx;
    // 기준일 YYYYMMDD — 문서·헤더의 작성일
    @NotBlank
    private String baseDt;
    // 기간형 양식의 종료일 YYYYMMDD — 일일 양식이면 공백 허용
    private String baseDtTo;
    // 점검자명 스냅샷 — 개인·일일·작업장·방충방서 양식에 사용
    private String checkerNm;
    // 양식별 entries·signers·checkers 전체 자료
    @NotNull
    private JsonNode payload;
    // 이탈 푸터 — 비면 CA 삭제
    private DocCorrectiveDto corrective;
}
