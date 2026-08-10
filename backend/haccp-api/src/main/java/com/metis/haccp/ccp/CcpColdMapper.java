/**
 * CcpColdMapper — CCP 냉장보관 모니터링 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 목록·상세·저장·삭제와 보관고·한계기준 조회를 sp_tbl_* 로만 수행한다
 *   2) 삭제 차단은 IN 단일 쿼리 — Service 루프 COUNT 금지
 *   3) 저장은 FUNCTION이 doc_idx를 반환한다
 *
 * PIPELINE[HB69] MyBatis 매퍼
 * PIPELINE[HB70] 연관 모듈
 */
package com.metis.haccp.ccp;

import com.metis.haccp.ccp.dto.CcpLimitRow;
import com.metis.haccp.ccp.dto.ColdMonitorHeader;
import com.metis.haccp.ccp.dto.ColdMonitorListRow;
import com.metis.haccp.ccp.dto.ColdMonitorRowDto;
import com.metis.haccp.ccp.dto.ColdMonitorTempJoinRow;
import com.metis.haccp.ccp.dto.StorageRow;
import com.metis.haccp.common.validation.DeleteBlocker;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface CcpColdMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 사용 중인 보관고를 정렬순으로 조회한다
     *   2) 일지 화면 열 머리글·신규 양식 기본열에 쓴다
     *   3) 성공 시 StorageRow 목록
     */
    List<StorageRow> selectStorages(
            @Param("coCd") String coCd,
            @Param("ccpCd") String ccpCd,
            @Param("useYn") String useYn
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 회사 CCP 한계기준을 조회한다
     *   2) 화면 상단 한계기준·방법란과 판정 안내에 쓴다
     *   3) 성공 시 CcpLimitRow 목록
     */
    List<CcpLimitRow> selectLimits(
            @Param("coCd") String coCd,
            @Param("ccpCd") String ccpCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 작성일 구간으로 일지 목록을 조회한다
     *   2) 화면 목록에 쓴다
     *   3) 성공 시 ColdMonitorListRow 목록
     */
    List<ColdMonitorListRow> selectList(
            @Param("coCd") String coCd,
            @Param("fromDt") String fromDt,
            @Param("toDt") String toDt,
            @Param("ccpCd") String ccpCd,
            @Param("docNo") String docNo,
            @Param("writer") String writer
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서 idx로 헤더 1건을 조회한다
     *   2) 상세 열기·삭제 검증에 쓴다
     *   3) 없으면 null
     */
    ColdMonitorHeader selectHeader(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 헤더 하위 점검행을 조회한다
     *   2) 상세 조립 시 온도와 합친다
     *   3) 성공 시 행 목록(temps는 Service가 채움)
     */
    List<ColdMonitorRowDto> selectRows(
            @Param("coCd") String coCd,
            @Param("hdrIdx") Long hdrIdx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 헤더 하위 온도 셀을 일괄 조회한다
     *   2) rowIdx로 점검행에 붙인다
     *   3) 성공 시 TempJoinRow 목록
     */
    List<ColdMonitorTempJoinRow> selectTempJoins(
            @Param("coCd") String coCd,
            @Param("hdrIdx") Long hdrIdx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서+헤더+행+온도를 저장하고 doc_idx를 반환한다
     *   2) rowsJson은 점검행 배열 JSON 문자열
     *   3) 성공 시 문서 idx
     */
    Long saveColdMonitor(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx,
            @Param("baseDt") String baseDt,
            @Param("ccpCd") String ccpCd,
            @Param("mngUserId") String mngUserId,
            @Param("mngNm") String mngNm,
            @Param("rowsJson") String rowsJson,
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 삭제 불가 문서(결재 진행·완료)의 첫 건을 찾는다
     *   2) assertDeletable Double Check에서 호출한다
     *   3) 차단 없으면 null
     */
    DeleteBlocker selectDeleteBlocker(
            @Param("coCd") String coCd,
            @Param("docIdxs") List<Long> docIdxs
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 임시·반려 문서를 물리 삭제한다
     *   2) Service가 키별 루프로 호출한다(@Transactional)
     *   3) 잠금 문서는 SP가 45000을 올린다
     */
    void deleteColdMonitor(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx,
            @Param("userId") String userId
    );
}
