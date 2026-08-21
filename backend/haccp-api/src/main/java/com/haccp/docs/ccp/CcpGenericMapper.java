/**
 * CcpGenericMapper — 공통 CCP 모니터링 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 공공 기준일지·내부 템플릿 목록과 상세·저장·삭제 SP를 노출한다
 *   2) 냉장·금속처럼 구조가 특화된 기존 화면은 이 매퍼를 사용하지 않는다
 *   3) 저장 JSON은 Service가 고정 DTO에서 만들고 동적 SQL을 조립하지 않는다
 *
 * PIPELINE[HB95] 공통 CCP MyBatis 매퍼
 * PIPELINE[HB94, HB91, HF94] 연관 모듈
 */
package com.haccp.docs.ccp;

// 역할 — 삭제 차단 행
import com.haccp.common.validation.DeleteBlocker;
// 역할 — 목록 결과
import java.util.List;
import java.util.Map;
// 역할 — MyBatis 매퍼·파라미터 이름
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface CcpGenericMapper {
    // 공통 CCP에 연결된 내부 템플릿·공공 기준일지 메타 목록
    List<Map<String, Object>> selectTemplates(@Param("coCd") String coCd);

    // 문서 상세 — 헤더 + rows_json
    Map<String, Object> selectDetail(@Param("coCd") String coCd, @Param("docIdx") Long docIdx);

    // 문서·헤더·점검행·EAV 셀을 저장하고 문서 idx 반환
    Long save(
            @Param("coCd") String coCd, @Param("docIdx") Long docIdx, @Param("baseDt") String baseDt,
            @Param("tmplCd") String tmplCd, @Param("ccpCd") String ccpCd, @Param("diaryNo") String diaryNo,
            @Param("limitItemKind") String limitItemKind, @Param("mngUserId") String mngUserId,
            @Param("mngNm") String mngNm, @Param("rowsJson") String rowsJson, @Param("userId") String userId
    );

    // 결재 진행·완료 문서가 삭제 목록에 있으면 첫 차단 행
    DeleteBlocker selectDeleteBlocker(@Param("coCd") String coCd, @Param("docIdxs") List<Long> docIdxs);

    // 임시·반려 문서와 하위 행·셀 삭제
    void deleteMonitor(@Param("coCd") String coCd, @Param("docIdx") Long docIdx, @Param("userId") String userId);
}
