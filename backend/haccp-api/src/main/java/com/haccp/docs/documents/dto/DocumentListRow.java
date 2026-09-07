/**
 * DocumentListRow — 문서함·결재대기·결재완료 목록 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_document_r_000 · sign-ready · sign-ok 컬럼과 1:1
 *   2) 조인 컬럼 writerNm·tmplNm·fileCnt 도 필드다
 *   3) sign-ok 만 myResultCd·myActDt 가 온다
 *
 * PIPELINE[HB84] 문서 DTO
 */
package com.haccp.docs.documents.dto;

import java.time.LocalDateTime;
import lombok.Data;

/** 문서 목록 행 */
@Data
public class DocumentListRow {
    private Long docIdx;
    private String coCd;
    private String tmplCd;
    private String tmplNm;
    private String docKind;
    private String docNo;
    private String baseDt;
    private String title;
    private String status;
    private String apprLineCd;
    private String writerId;
    private String writerNm;
    private LocalDateTime writeDt;
    private Integer verNo;
    private String retentionUntil;
    private Integer fileCnt;
    private Integer openCaCnt;
    // 결재완료만 — 내 처리 결과
    private String myResultCd;
    private LocalDateTime myActDt;
}
