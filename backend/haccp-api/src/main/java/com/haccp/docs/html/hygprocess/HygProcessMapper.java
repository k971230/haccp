/**
 * HygProcessMapper — 일반위생·공정점검 작성 SP 호출.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) tmpl_cd는 html_sys_001 고정이다
 *   2) 상세는 JSON 한 줄, 저장은 doc_idx를 반환한다. 저장 직후 sign_u_000
 *   3) 삭제는 blocker IN 쿼리 후 d_000
 *
 * PIPELINE[HB131] 공정점검 Mapper
 */
package com.haccp.docs.html.hygprocess;

import com.haccp.common.validation.DeleteBlocker;
import com.haccp.docs.html.hygprocess.dto.HygProcessListRow;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface HygProcessMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 기간·문서번호·작성자로 목록을 조회한다
     *   2) 좌측 문서 목록이 호출한다
     *   3) 없으면 빈 목록
     */
    List<HygProcessListRow> selectList(
            @Param("coCd") String coCd,
            @Param("fromDt") String fromDt,
            @Param("toDt") String toDt,
            @Param("docNo") String docNo,
            @Param("writer") String writer
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 기존 상세 또는 적용 버전 신규 기본행 JSON
     *   2) docIdx 없거나 0이면 신규
     *   3) 실패는 SP 45000
     */
    String selectDetail(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 문서·헤더·항목을 한 트랜잭션에서 저장한다
     *   2) 저장 버튼이 호출한다
     *   3) 반환은 tbl_document.idx
     */
    Long save(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx,
            @Param("baseDt") String baseDt,
            @Param("checkerNm") String checkerNm,
            @Param("payload") String payload,
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 점검자·승인자·확인 이름이 사용자와 같으면 서명을 문서에 복사한다
     *   2) 저장 SP 직후에 호출한다
     *   3) 서명이 없으면 이름만 남긴다
     */
    void snapshotSigns(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx,
            @Param("checkerNm") String checkerNm,
            @Param("approverNm") String approverNm,
            @Param("confirmNm") String confirmNm
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 결재 진행·완료 문서의 첫 차단 행
     *   2) validate-delete·delete Double Check
     *   3) 없으면 null
     */
    DeleteBlocker selectDeleteBlocker(
            @Param("coCd") String coCd,
            @Param("docIdxs") List<Long> docIdxs
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 하위 항목·문서 허브를 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) 잠금 문서는 SP가 막는다
     */
    void delete(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx,
            @Param("userId") String userId
    );
}
