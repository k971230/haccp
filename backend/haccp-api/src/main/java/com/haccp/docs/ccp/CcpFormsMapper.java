/**
 * CcpFormsMapper — CCP 금속검출·검증점검표·연간 검증계획서 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 세 DB형 양식의 공통 목록·상세·저장·삭제 SP를 호출한다
 *   2) 양식별 정규화 테이블의 차이는 DB SP가 흡수하고 앱 경계는 JSON 행으로 유지한다
 *   3) 삭제 차단은 단일 IN 쿼리로 조회해 Service Double Check에 사용한다
 *
 * PIPELINE[HB88] CCP 추가 양식 Mapper
 * PIPELINE[HB71, HB72] 연관 모듈
 */
package com.haccp.docs.ccp;

import com.haccp.common.validation.DeleteBlocker;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface CcpFormsMapper {
    List<Map<String, Object>> selectList(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd,
            @Param("fromDt") String fromDt, @Param("toDt") String toDt,
            @Param("docNo") String docNo, @Param("writer") String writer);
    Map<String, Object> selectDetail(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("docIdx") Long docIdx);
    List<Map<String, Object>> selectMetalSensRows(@Param("coCd") String coCd, @Param("hdrIdx") Long hdrIdx);
    List<Map<String, Object>> selectMetalPassRows(@Param("coCd") String coCd, @Param("hdrIdx") Long hdrIdx);
    Long saveMetal(@Param("coCd") String coCd, @Param("docIdx") Long docIdx, @Param("baseDt") String baseDt, @Param("ccpCd") String ccpCd, @Param("feSize") BigDecimal feSize, @Param("stsSize") BigDecimal stsSize, @Param("mngUserId") String mngUserId, @Param("mngNm") String mngNm, @Param("sensRowsJson") String sensRowsJson, @Param("passRowsJson") String passRowsJson, @Param("userId") String userId);
    Long saveForm(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("docIdx") Long docIdx, @Param("baseDt") String baseDt, @Param("checkerId") String checkerId, @Param("checkerNm") String checkerNm, @Param("deptCd") String deptCd, @Param("confirmId") String confirmId, @Param("rowsJson") String rowsJson, @Param("userId") String userId);
    /** 검증점검표 — 모니터링 일지 확인 SPAN 조회 */
    String selectVerifyMonitorRmk(@Param("coCd") String coCd, @Param("docIdx") Long docIdx);
    /** 검증점검표 — 모니터링 일지 확인 SPAN 저장 */
    int updateVerifyMonitorRmk(@Param("coCd") String coCd, @Param("docIdx") Long docIdx, @Param("monitorChkRmk") String monitorChkRmk, @Param("userId") String userId);
    DeleteBlocker selectDeleteBlocker(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("docIdxs") List<Long> docIdxs);
    void deleteMetal(@Param("coCd") String coCd, @Param("docIdx") Long docIdx, @Param("userId") String userId);
    void deleteForm(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("docIdx") Long docIdx, @Param("userId") String userId);
}
