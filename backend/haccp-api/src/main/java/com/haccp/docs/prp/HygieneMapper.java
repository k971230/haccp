/**
 * HygieneMapper — 위생 DB형 양식 5종 MyBatis 경계.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 모든 읽기·저장·삭제는 sp_tbl_hygiene_document_*를 통해 수행한다
 *   2) 상세의 가변 행은 JSON 문자열로 받아 API에서 JsonNode로 반환한다
 *   3) 삭제 차단은 IN 단일 쿼리로 검사하여 Service별 COUNT 반복을 피한다
 *
 * PIPELINE[HB84] 위생 Mapper
 * PIPELINE[HB83, HB85] 연관 모듈
 */
package com.haccp.docs.prp;

import com.haccp.common.validation.DeleteBlocker;
import com.haccp.docs.prp.dto.HygieneListRow;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface HygieneMapper {
    List<HygieneListRow> selectList(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd,
                                    @Param("fromDt") String fromDt, @Param("toDt") String toDt,
                                    @Param("docNo") String docNo, @Param("writer") String writer);
    String selectDetail(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("docIdx") Long docIdx);
    Long save(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("docIdx") Long docIdx,
              @Param("baseDt") String baseDt, @Param("baseDtTo") String baseDtTo,
              @Param("checkerNm") String checkerNm, @Param("payload") String payload, @Param("userId") String userId);
    DeleteBlocker selectDeleteBlocker(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd,
                                      @Param("docIdxs") List<Long> docIdxs);
    void delete(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd,
                @Param("docIdx") Long docIdx, @Param("userId") String userId);
}
