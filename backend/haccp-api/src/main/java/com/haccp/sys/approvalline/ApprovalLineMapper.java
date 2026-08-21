/**
 * ApprovalLineMapper — 결재선 관리 SP 호출.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) sp_tbl_approval_line_* 만 호출한다
 *   2) 목록은 JSON payload 한 줄이 결재선 1건이다
 *   3) 삭제는 blocker 조회 후 d_000. 왼쪽 삭제 버튼이 호출한다
 *
 * PIPELINE[HB92] 결재선 관리 MyBatis 매퍼
 */
package com.haccp.sys.approvalline;

// 역할 — 목록·차단 행 타입
import java.util.List;
import java.util.Map;
// 역할 — MyBatis 등록·이름 바인딩
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface ApprovalLineMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 회사 결재선·단계를 JSON 목록으로 받는다
     *   2) 결재선 관리 조회가 호출한다
     *   3) 없으면 빈 목록
     */
    List<String> selectApprovalLines(
            // coCd: JWT 회사코드 — 테넌트 범위
            @Param("coCd") String coCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 헤더와 단계 전체를 같은 트랜잭션에서 교체한다
     *   2) 저장 버튼이 호출한다
     *   3) 코드·명칭·단계 누락은 SP가 업무 오류로 막는다
     */
    void saveApprovalLine(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // payload: apprLineCd·apprLineNm·useYn·steps[]
            @Param("payload") String payload,
            // userId: JWT 작업자
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 사용양식·문서 참조 여부를 한 줄로 받는다
     *   2) validate-delete·delete Double Check가 호출한다
     *   3) 참조가 없으면 null
     */
    Map<String, Object> selectApprovalLineBlocker(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // apprLineCd: 삭제 대상 결재선 코드
            @Param("apprLineCd") String apprLineCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 참조가 없을 때만 헤더와 단계를 지운다
     *   2) 화면 삭제 버튼은 없지만 API는 남긴다
     *   3) 참조 중이면 SP가 업무 오류
     */
    void deleteApprovalLine(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // apprLineCd: 삭제 대상 결재선 코드
            @Param("apprLineCd") String apprLineCd,
            // userId: JWT 작업자
            @Param("userId") String userId
    );
}
