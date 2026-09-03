/**
 * CalendarMapper — 일정 캘린더 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 월 범위 과제·영업일 전환 SP만 호출한다
 *   2) 회사코드는 Service JWT에서만 넘긴다
 *   3) 쓰기는 PROCEDURE, 조회는 FUNCTION
 *
 * PIPELINE[HB210] 일정 캘린더 매퍼
 */
package com.haccp.board;

// 역할 — 목록
import java.util.List;
import java.util.Map;
// 역할 — MyBatis
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface CalendarMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 월 범위 회사 전체 작성과제를 조회한다
     *   2) 캘린더 화면 진입·월 이동에서 호출한다
     *   3) 담당 여부는 Service가 JWT로 붙인다
     */
    List<Map<String, Object>> selectTasks(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 조회 시작일 YYYYMMDD
            @Param("fromYmd") String fromYmd,
            // 조회 종료일 YYYYMMDD
            @Param("toYmd") String toYmd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 월 범위 영업일 전환 목록을 조회한다
     *   2) 캘린더가 체크박스 초기값을 채울 때 호출한다
     *   3) ymd YYYYMMDD 목록
     */
    List<String> selectWorkdays(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 조회 시작일 YYYYMMDD
            @Param("fromYmd") String fromYmd,
            // 조회 종료일 YYYYMMDD
            @Param("toYmd") String toYmd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 하루를 영업일로 넣거나 비영업일로 되돌린다
     *   2) 저장 버튼이 변경분만큼 호출한다
     *   3) Y INSERT, N DELETE
     */
    void upsertWorkday(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 대상일 YYYYMMDD
            @Param("ymd") String ymd,
            // Y 영업일 / N 해제
            @Param("workYn") String workYn,
            // JWT 작업자
            @Param("userId") String userId
    );
}
