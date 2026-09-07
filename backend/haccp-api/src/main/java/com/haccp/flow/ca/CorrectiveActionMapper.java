/**
 * CorrectiveActionMapper — 개선조치관리 화면 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) sp_tbl_corrective_action_* 만 호출한다
 *   2) coCd·userId 는 Service 가 JWT 에서만 채워 넘긴다
 *   3) 문서에 딸린 개선조치(DocCorrectiveMapper)와 다르다 — 여기는 목록 화면이다
 *
 * PIPELINE[HB94] 개선조치관리 MyBatis 매퍼
 */
package com.haccp.flow.ca;

// 역할 — 삭제 차단 첫 행
import com.haccp.common.validation.DeleteBlocker;
// 역할 — 목록 타입
import com.haccp.flow.ca.dto.CorrectiveRow;
import java.util.List;
// 역할 — MyBatis 매퍼 표식·이름 바인딩
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface CorrectiveActionMapper {

    /** 기간·양식·작성자 조건 목록 — 공백이면 전체 */
    List<CorrectiveRow> selectCorrectiveActions(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 시작일 YYYYMMDD — 공백이면 전체
            @Param("fromDt") String fromDt,
            // 종료일 YYYYMMDD — 공백이면 전체
            @Param("toDt") String toDt,
            // 양식코드 — 공백이면 전체
            @Param("tmplCd") String tmplCd,
            // 작성자 — 공백이면 전체
            @Param("writer") String writer
    );

    /** 신규·수정 저장 — payload 는 jsonb 로 넘긴다 */
    void saveCorrectiveAction(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 대리키 — null 이면 신규
            @Param("idx") Long idx,
            // 화면 행 JSON
            @Param("payloadJson") String payloadJson,
            // JWT 작업자
            @Param("userId") String userId
    );

    /**
     * 삭제 사전 차단 검사 — 완료(DONE) 건의 첫 하나만 돌아온다. 없으면 null 이라 삭제를 진행한다.
     *
     * 삭제 SP 와 같은 기준이다. 검사 자리가 하나면 확인창을 누른 뒤에야 실패하고,
     * 여러 건을 고르면 정상 건까지 함께 롤백된다.
     */
    DeleteBlocker selectDeleteBlocker(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대상 대리키 배열
            @Param("idxs") List<Long> idxs
    );

    /** 미완료 개선조치 1건 삭제 — SP 가 완료 상태를 다시 막는다 */
    void deleteCorrectiveAction(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대상 대리키
            @Param("idx") Long idx,
            // JWT 작업자
            @Param("userId") String userId
    );
}
