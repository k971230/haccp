/**
 * DocumentFileRow — 문서 첨부 메타데이터.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 파일 목록·다운로드·물리 파일 정리에 필요한 DB 조회 결과다
 *   2) filePath는 서버 내부 상대 경로이며 Controller 응답에는 노출하지 않는다
 *   3) 파일 식별은 전역 idx가 아닌 coCd를 함께 검증해 테넌트 파일 누출을 막는다
 *
 * PIPELINE[HB82] doc DTO
 * PIPELINE[HB83] 연관 모듈
 */
package com.metis.haccp.doc.dto;

// 역할 — 날짜 시각 타입
import java.time.LocalDateTime;
// 역할 — Lombok getter/setter
import lombok.Data;

/** 문서 파일 DB 행 */
@Data
public class DocumentFileRow {
    // 파일 대리키 — 다운로드·삭제 API 식별자
    private Long idx;
    // 연결 문서 대리키
    private Long docIdx;
    // HWP_SRC/PDF/ATTACH/PHOTO
    private String fileKind;
    // 사용자 표시·다운로드 파일명
    private String fileNm;
    // 서버 저장 상대 경로 — 내부 전용
    private String filePath;
    // 파일 크기 byte
    private Long fileSize;
    // MIME 타입
    private String mimeType;
    // 문서 내 표시 순서
    private Integer sortNo;
    // 업로더 ID
    private String insId;
    // 업로드 일시
    private LocalDateTime insDt;
}
