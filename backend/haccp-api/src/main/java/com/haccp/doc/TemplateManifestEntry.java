/**
 * TemplateManifestEntry — 표준 양식 배포 매니페스트 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) templates/manifest.tsv의 tmpl_cd·source·target·required를 담는다
 *   2) Import·form_path 갱신이 코드 하드코딩 목록 대신 이 행을 읽는다
 *   3) 양식 추가 시 TSV만 수정하면 된다 (Java 재컴파일 최소화)
 *
 * PIPELINE[HB92] 템플릿 매니페스트
 * PIPELINE[HB89] 연관 모듈
 */
package com.haccp.doc;

/** 매니페스트 행 — 불변 값 객체 */
public record TemplateManifestEntry(
        // 표준 템플릿 업무키
        String tmplCd,
        // docs/ 또는 import-root의 원본 파일명 (실존명 그대로)
        String sourceName,
        // HaccpTemplates/{tmpl_cd} 아래 저장 파일명 (번호 접두 제거 한글명)
        String targetName,
        // true면 원본 누락 시 기동 실패, false면 스킵(LAW 등 선택)
        boolean required
) {}
