/**
 * TaskMapper — 오늘 과제·알림·개선조치·문서관계·감사자료 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 화면마다 다른 업무 SP를 명시 메서드로 연결해 범용 빌더를 만들지 않는다
 *   2) 회사·사용자는 Service의 JWT 컨텍스트에서만 전달한다
 *   3) 삭제와 관계 저장은 SP가 문서·테넌트 조건을 다시 검증한다
 *
 * PIPELINE[HB93] 워크플로 작업 매퍼
 * PIPELINE[HB86, HB91, HF87] 연관 모듈
 */
package com.haccp.tsk;

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
    List<Map<String, Object>> selectNotifications(@Param("coCd") String coCd, @Param("userId") String userId);
    void readNotification(@Param("coCd") String coCd, @Param("idx") Long idx, @Param("userId") String userId);
    List<Map<String, Object>> selectCorrectiveActions(@Param("coCd") String coCd, @Param("status") String status, @Param("fromDt") String fromDt, @Param("toDt") String toDt);
    void saveCorrectiveAction(@Param("coCd") String coCd, @Param("idx") Long idx, @Param("payloadJson") String payloadJson, @Param("userId") String userId);
    void deleteCorrectiveAction(@Param("coCd") String coCd, @Param("idx") Long idx, @Param("userId") String userId);
    List<Map<String, Object>> selectRelations(@Param("coCd") String coCd, @Param("docIdx") Long docIdx);
    void saveRelation(@Param("coCd") String coCd, @Param("srcDocIdx") Long srcDocIdx, @Param("relType") String relType, @Param("tgtDocIdx") Long tgtDocIdx, @Param("userId") String userId);
    List<Map<String, Object>> selectAuditExport(@Param("coCd") String coCd, @Param("fromDt") String fromDt, @Param("toDt") String toDt, @Param("status") String status);
}
