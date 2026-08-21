/**
 * DocumentTemplateResponse — 템플릿 선택 목록의 공개 API 응답.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 표준 템플릿의 업무 메타와 인증된 원본 form URL만 브라우저로 보낸다
 *   2) formPath는 서버 파일 경로이므로 이 DTO에 의도적으로 포함하지 않는다
 *   3) formFileNm은 rhwp가 파일 형식을 판별할 때 사용할 안전한 표시 파일명이다
 *
 * PIPELINE[HB88] 템플릿 DTO
 * PIPELINE[HB90] 연관 모듈
 */
package com.haccp.docs.document.dto;

// 역할 — Lombok getter/setter
import lombok.Data;

/** 템플릿 목록 공개 행 */
@Data
public class DocumentTemplateResponse {
    // 표준 템플릿 업무키 — form API 경로와 문서 저장에 사용
    private String tmplCd;
    // 회사별 표시명이 반영된 템플릿명
    private String tmplNm;
    // DB/HWP 양식 구분 — HWP 편집 화면은 HWP형만 선택한다
    private String docKind;
    // HACCP 카테고리 코드
    private String categoryCd;
    // 표준 일지관리 번호
    private String mngNo;
    // JWT 인증이 필요한 동일 API 서버의 템플릿 원본 URL
    private String formUrl;
    // 다운로드 Content-Disposition·rhwp loadFile에 사용할 파일명
    private String formFileNm;
    // 시스템 배포분 Y — Y면 삭제 불가, 회사 전용 N만 삭제 가능
    private String sysYn;
}
