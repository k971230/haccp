/**
 * DocumentTemplateRow — 회사 사용 템플릿과 HWP 원본 메타데이터.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 템플릿 목록과 원본 스트림이 공유하는 SP 조회 결과다
 *   2) formPath는 서버 내부 저장소 전용이며 JSON 목록 응답에는 포함하지 않는다
 *   3) formFileNm은 Content-Disposition과 rhwp loadFile 표시명에 사용한다
 *
 * PIPELINE[HB88] 템플릿 DTO
 * PIPELINE[HB83, HB89] 연관 모듈
 */
package com.haccp.docs.documents.dto;

// 역할 — Lombok getter/setter
import lombok.Data;

/** 템플릿 SP 조회 행 */
@Data
public class DocumentTemplateRow {
    // 표준 템플릿 업무키 — URL 경로·문서 저장의 tmplCd
    private String tmplCd;
    // 회사별 오버라이드가 반영된 사용자 표시명
    private String tmplNm;
    // DB 또는 HWP — 편집 화면은 HWP형만 선택 가능하게 구분한다
    private String docKind;
    // HACCP 카테고리 코드
    private String categoryCd;
    // 표준 관리번호
    private String mngNo;
    // APP_FILE_ROOT/HaccpTemplates·CustomTemplates 하위의 서버 전용 상대 경로
    private String formPath;
    // 다운로드 헤더·rhwp 적재에 쓸 원본 파일명
    private String formFileNm;
    // 시스템 배포분 Y — Y면 삭제 불가, 회사 전용 N만 삭제 가능
    private String sysYn;
}
