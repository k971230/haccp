/**
 * GridPrefSaveRequest.java — 그리드 열 설정 저장 요청 DTO.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 화면코드·그리드 식별자·설정 JSON을 받아 업서트한다
 *   2) prefJson이 빈 문자열이면 초기화 요청으로 보고 저장 행을 삭제한다 — 별도 삭제 API를 두지 않은 이유다
 *   3) 회사코드·사용자 아이디는 받지 않는다. JWT에서만 읽어 남의 설정을 덮어쓰지 못하게 한다
 *
 * PIPELINE[HB39] pref DTO
 */
package com.metis.haccp.pref.dto;

// 역할 — 공백 입력 차단
import jakarta.validation.constraints.NotBlank;
// 역할 — @Getter/@Setter 접근자 (Jackson 역직렬화 대상)
import lombok.Getter;
import lombok.Setter;

/** 그리드 열 설정 저장 요청 — { scrnCd, gridId, prefJson } */
@Getter
@Setter
public class GridPrefSaveRequest {

    /** 화면코드 — 프론트 screenRegistry 키 */
    @NotBlank(message = "화면코드가 필요합니다.")
    private String scrnCd;

    /** 그리드 식별자 — 편집 그리드의 persistId */
    @NotBlank(message = "그리드 식별자가 필요합니다.")
    private String gridId;

    /**
     * 열 설정 JSON 원문.
     * 빈 문자열·null이면(= 설정 초기화 요청) SP가 저장 행을 삭제한다. 그래서 @NotBlank를 걸지 않는다.
     */
    private String prefJson;
}
