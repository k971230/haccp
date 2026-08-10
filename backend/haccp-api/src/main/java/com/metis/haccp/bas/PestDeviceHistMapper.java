/**
 * PestDeviceHistMapper — 방충설비 이력 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 39_sp_spec_screens.sql의 sp_tbl_equipment_hist_* 만 호출한다
 *   2) 목록은 JSON 문자열, 저장·삭제는 PROCEDURE CALL이다
 *   3) coCd·userId는 Service가 JWT에서만 채워 전달한다
 *
 * PIPELINE[HB100] 설비이력 MyBatis 매퍼
 * PIPELINE[HB95, HB96, HB97] 연관 모듈
 */
package com.metis.haccp.bas;

// 역할 — 목록 타입
import java.util.List;
// 역할 — MyBatis 매퍼 표식·이름 바인딩
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface PestDeviceHistMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 선택한 설비의 이력 행을 JSON 문자열로 조회한다
     *   2) Service가 Map 목록으로 변환해 API에 반환한다
     *   3) 성공 시 테넌트·설비 범위 JSON 행 목록
     */
    List<String> selectList(
            // JWT 회사코드 — SP 테넌트 필터
            @Param("coCd") String coCd,
            // 상위 설비 대리키
            @Param("pestIdx") Long pestIdx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) JSON 행 1건을 신규 또는 수정으로 저장한다
     *   2) Service가 요청 배열을 @Transactional 안에서 순차 호출한다
     *   3) 성공 시 void — PG CALL 영향행수는 사용하지 않는다
     */
    void save(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // camelCase JSON 행 — idx·pestIdx·histDt 등
            @Param("payload") String payload,
            // JWT 작업자 ID
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 방충설비 이력 1건을 삭제한다
     *   2) Service Double Check 뒤 SP가 idx + co_cd로 테넌트 경계를 강제한다
     *   3) 성공 시 void
     */
    void delete(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제할 대리키
            @Param("idx") Long idx,
            // JWT 작업자 ID
            @Param("userId") String userId
    );
}
