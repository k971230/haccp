/**
 * TaskMapper — 오늘 과제·알림 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 화면마다 다른 업무 SP를 명시 메서드로 연결해 범용 빌더를 만들지 않는다
 *   2) 회사·사용자는 Service의 JWT 컨텍스트에서만 전달한다
 *   3) 삭제는 SP가 문서·테넌트 조건을 다시 검증한다
 *
 * PIPELINE[HB93] 워크플로 작업 매퍼
 * PIPELINE[HB86, HB91, HF87] 연관 모듈
 */
package com.haccp.board;

// 역할 — 목록·가변 입력 자료
import java.util.List;
import java.util.Map;
// 역할 — MyBatis 등록·파라미터 이름
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface TaskMapper {
    List<String> selectCompanyCodes();
    void generateTasks(@Param("coCd") String coCd, @Param("baseDt") String baseDt, @Param("userId") String userId);
    List<Map<String, Object>> selectTodayTasks(@Param("coCd") String coCd, @Param("userId") String userId, @Param("baseDt") String baseDt);

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 오늘 할 일 최근 문서를 기간 + OFFSET/LIMIT 으로 조회한다 — 본인 작성분만
     *   2) 랜딩 최근 문서 패널이 호출한다. 문서함 목록 SP 는 건드리지 않는다
     *   3) 각 행 total_cnt 는 기간 전체 건수다. 0건이면 빈 목록
     */
    List<Map<String, Object>> selectTodayTaskDocs(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // JWT 본인 아이디 — writer_id 필터
            @Param("userId") String userId,
            // 기준일 시작 YYYYMMDD
            @Param("fromDt") String fromDt,
            // 기준일 종료 YYYYMMDD
            @Param("toDt") String toDt,
            // 건너뛸 행 수 — 0이면 첫 페이지
            @Param("offset") int offset,
            // 가져올 행 수 — 화면이 20을 넘긴다
            @Param("limit") int limit
    );
    List<Map<String, Object>> selectNotifications(@Param("coCd") String coCd, @Param("userId") String userId);
    void readNotification(@Param("coCd") String coCd, @Param("idx") Long idx, @Param("userId") String userId);
}
