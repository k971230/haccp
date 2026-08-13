/**
 * BizOpsMapper — 시설·재고·공정 DB형 양식 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 6개 화면은 같은 목록·상세·저장·삭제 계약을 쓰며 templateCode만 다르다
 *   2) 상세와 저장 payload는 JSON 문자열로 SP에 넘겨 양식별 DB 컬럼은 PG가 책임진다
 *   3) 삭제 차단은 문서 상태를 IN 단일 조회해 Service 루프 COUNT를 만들지 않는다
 *
 * PIPELINE[HB89] 시설·재고·공정 MyBatis 매퍼
 * PIPELINE[HB88, HB90] 연관 모듈
 */
package com.haccp.ops;

import com.haccp.common.validation.DeleteBlocker;
import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface BizOpsMapper {
    List<Map<String, Object>> selectList(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd,
            @Param("fromDt") String fromDt, @Param("toDt") String toDt,
            @Param("docNo") String docNo, @Param("writer") String writer);

    String selectDetail(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("docIdx") Long docIdx);

    Long save(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("docIdx") Long docIdx,
            @Param("payloadJson") String payloadJson, @Param("userId") String userId);

    DeleteBlocker selectDeleteBlocker(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd,
            @Param("docIdxs") List<Long> docIdxs);

    void delete(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("docIdx") Long docIdx,
            @Param("userId") String userId);
}
