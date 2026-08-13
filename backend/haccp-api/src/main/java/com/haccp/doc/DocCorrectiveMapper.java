/**
 * DocCorrectiveMapper — 문서형 일지 이탈 푸터 SP 호출.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) sp_tbl_doc_corrective_r_000 / _u_000 을 호출한다
 *   2) Cold·Metal·위생·시설 저장·상세가 공통으로 사용한다
 *   3) coCd는 서비스가 JWT에서만 채운다
 *
 * PIPELINE[HB63] Mapper
 */
package com.haccp.doc;

import com.haccp.ccp.dto.DocCorrectiveDto;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface DocCorrectiveMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서 idx로 푸터 1건을 조회한다
     *   2) 상세 조립 시 호출한다
     *   3) 없으면 null
     */
    DocCorrectiveDto selectByDoc(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 푸터를 upsert하거나 빈 값이면 삭제한다
     *   2) 문서 저장 직후 호출한다
     *   3) 성공 시 void
     */
    void upsertByDoc(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx,
            @Param("tmplCd") String tmplCd,
            @Param("baseDt") String baseDt,
            @Param("payloadJson") String payloadJson,
            @Param("userId") String userId
    );
}
