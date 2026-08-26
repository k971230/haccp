/**
 * HwpDocumentSaveRequest — HWP 문서형 헤더 저장 요청.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) rhwp 편집기의 저장 전 문서 메타를 tbl_document에 신규·수정한다
 *   2) HWPX 원본 바이너리는 이 요청에 싣지 않고 파일 업로드 API로 분리한다
 *   3) 회사·작성자는 JWT에서 강제하므로 요청 본문에 두지 않는다
 *
 * PIPELINE[HB88] doc DTO
 * PIPELINE[HB86] 연관 모듈
 */
package com.haccp.docs.documents.dto;

// 역할 — 필수값 Bean Validation
import jakarta.validation.constraints.NotBlank;
// 역할 — Lombok getter/setter
import lombok.Data;

/** HWP 문서형 헤더 입력 */
@Data
public class HwpDocumentSaveRequest {
    // 기존 문서 idx — null/0이면 신규
    private Long docIdx;
    // 표준 HWP 템플릿 코드
    @NotBlank(message = "양식을 선택하세요.")
    private String tmplCd;
    // 기준일 YYYYMMDD
    @NotBlank(message = "기준일자를 입력하세요.")
    private String baseDt;
    // 기간 문서 종료일 YYYYMMDD — 단일 일자 문서는 null
    private String baseDtTo;
    // 사용자 지정 문서 제목 — 비면 양식명·기준일 자동 생성
    private String title;
}
