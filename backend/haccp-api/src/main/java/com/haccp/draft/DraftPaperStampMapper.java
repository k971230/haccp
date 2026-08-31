/**
 * DraftPaperStampMapper — 지면 도장칸(작성자·승인자) SP.
 *
 * 개발자: 박승우
 * 일자: 2026-08-31
 * 코멘트:
 *   1) CCP 모니터 detail 이 문서함 도장을 채울 때 한 곳에서 읽는다
 *   2) MyBatis 가 sp_tbl_document_paper_stamp_r_000 만 부른다
 *   3) 문서가 없으면 null
 *
 * PIPELINE[HB135] 양식 작성 공용 유틸
 */
package com.haccp.draft;

import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface DraftPaperStampMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-31
     * 코멘트:
     *   1) 작성자·승인 완료 결재자 이름·서명여부를 1행으로 돌려준다
     *   2) CCP detail 조립이 호출한다
     *   3) 문서가 없거나 삭제면 null
     */
    Map<String, Object> selectPaperStamp(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdx: tbl_document.idx
            @Param("docIdx") Long docIdx
    );
}
