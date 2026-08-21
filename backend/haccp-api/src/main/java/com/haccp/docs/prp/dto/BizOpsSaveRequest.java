/**
 * BizOpsSaveRequest — 시설·재고·공정 DB형 양식 공통 저장 요청.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 6개 양식의 헤더 필드와 행 배열을 payload에 보관해 API 경로의 양식 코드와 함께 SP로 전달한다
 *   2) docIdx가 null 또는 0일 때 신규 문서를 만들고, 기존 번호면 임시·반려 문서만 전체 교체한다
 *   3) coCd·작업자 ID는 요청 본문이 아닌 JWT에서만 읽어 테넌트 변경을 차단한다
 *
 * PIPELINE[HB88] 시설·재고·공정 DTO
 * PIPELINE[HB89, HB90, HB91] 연관 모듈
 */
package com.haccp.docs.prp.dto;

import com.haccp.docs.ccp.dto.DocCorrectiveDto;
import jakarta.validation.constraints.NotNull;
import java.util.LinkedHashMap;
import java.util.Map;
import lombok.Data;

@Data
public class BizOpsSaveRequest {
    // 기존 문서 idx — 신규 작성이면 null 또는 0
    private Long docIdx;
    // 양식별 헤더·rows 배열 — SP가 양식 코드에 맞는 필수 필드를 검증
    @NotNull
    private Map<String, Object> payload = new LinkedHashMap<>();
    // 이탈 푸터 — 비면 CA 삭제
    private DocCorrectiveDto corrective;
}
