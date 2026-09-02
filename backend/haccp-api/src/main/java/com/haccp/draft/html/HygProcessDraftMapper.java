/**
 * HygProcessDraftMapper — 위생공정 작성 SP 호출.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 작성 SP 는 공정점검 테이블 SP(sp_tbl_hyg_process_*)를 양식코드와 함께 그대로 쓴다
 *   2) 양식 목록은 양식관리와 같은 sp_tbl_html_hyg_prc_ver_r_000. 사용여부 Y 만 SQL 이 좁힌다
 *   3) 삭제 차단은 foreach IN 단일 쿼리 (OPS_DELETE)
 *
 * PIPELINE[HB135] 위생공정 작성 Mapper
 */
package com.haccp.draft.html;

import com.haccp.common.validation.DeleteBlocker;
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface HygProcessDraftMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 작성에 쓸 수 있는 자사 양식(사용여부 Y)만 반환한다
     *   2) 화면 진입 시 한 번, 신규 작성 콤보가 쓴다
     *   3) 없으면 빈 목록 — 화면이 양식관리로 안내한다
     */
    List<DraftFormRow> selectForms(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // stdTmplCd: 계열 예시코드 html_hyg_prc_000 — SP 가 이 값으로 테이블을 가른다
            @Param("stdTmplCd") String stdTmplCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 상단 검색 6개 중 서버 조건 5개(일자 구간·양식코드·양식명·작성자ID·작성자명)로 조회한다
     *   2) 좌측 그리드가 호출한다
     *   3) tmplCd 빈값이면 공정점검 계열 전체. 결재여부는 화면이 거른다
     */
    List<DraftListRow> selectList(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // tmplCd: 양식코드 부분검색. 빈값이면 전체
            @Param("tmplCd") String tmplCd,
            // tmplNm: 양식명 부분검색. 빈값이면 전체
            @Param("tmplNm") String tmplNm,
            // fromDt: 일자 시작 YYYYMMDD. 빈값이면 하한 없음
            @Param("fromDt") String fromDt,
            // toDt: 일자 종료 YYYYMMDD. 빈값이면 상한 없음
            @Param("toDt") String toDt,
            // writerId: 작성자 ID 부분검색. 빈값이면 전체
            @Param("writerId") String writerId,
            // writerNm: 작성자명 부분검색. 빈값이면 전체
            @Param("writerNm") String writerNm,
            // remark: 문서 비고 부분검색. 빈값이면 전체
            @Param("remark") String remark
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 기존 상세 또는 선택 양식의 신규 기본행 JSON 을 반환한다
     *   2) 좌측 행 클릭·신규 버튼이 호출한다
     *   3) docIdx 가 null·0 이면 신규. 실패는 SP 45000
     */
    String selectDetail(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // tmplCd: 신규일 때 항목을 깔 양식코드
            @Param("tmplCd") String tmplCd,
            // docIdx: tbl_document.idx. null 이면 신규
            @Param("docIdx") Long docIdx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 문서·헤더·항목을 한 트랜잭션에서 저장한다
     *   2) 저장 버튼이 호출한다
     *   3) 반환은 tbl_document.idx. 전송 이후 상태면 SP 가 막는다
     */
    Long save(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // tmplCd: 작성 양식코드
            @Param("tmplCd") String tmplCd,
            // docIdx: 기존 문서 idx. null 이면 INSERT
            @Param("docIdx") Long docIdx,
            // baseDt: 일자 YYYYMMDD
            @Param("baseDt") String baseDt,
            // checkerNm: 점검자명. 빈값 허용
            @Param("checkerNm") String checkerNm,
            // payload: verNo·items·하단 4칸 JSON 문자열
            @Param("payload") String payload,
            // userId: JWT 작업자 ID
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 점검자·승인자·확인 이름이 사용자와 같으면 서명을 문서에 복사한다
     *   2) 저장 SP 직후에 호출한다
     *   3) 서명이 없으면 이름만 남는다
     */
    void snapshotSigns(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdx: 저장된 tbl_document.idx
            @Param("docIdx") Long docIdx,
            // checkerNm: 점검자명
            @Param("checkerNm") String checkerNm,
            // approverNm: 승인자명
            @Param("approverNm") String approverNm,
            // confirmNm: 확인란 이름
            @Param("confirmNm") String confirmNm
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 전송·결재완료 문서의 첫 차단 행을 반환한다
     *   2) validate-delete·delete 양쪽에서 호출한다 (Double Check)
     *   3) 없으면 null
     */
    DeleteBlocker selectDeleteBlocker(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdxs: 삭제 후보 문서 idx 목록
            @Param("docIdxs") List<Long> docIdxs
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 하위 항목·결재·첨부·문서 허브를 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) 전송대기(WRK·RJT)가 아니면 SP 가 막는다
     */
    void delete(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdx: 삭제할 tbl_document.idx
            @Param("docIdx") Long docIdx,
            // userId: JWT 작업자 ID
            @Param("userId") String userId
    );
}
