/**
 * LoginHistoryMapper — 로그인 이력 화면(login-history) SP 호출 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) sp_login_history_r_000 조회 1건만 담당한다 — 적재는 auth 도메인이 한다
 *   2) coCd는 Service가 JWT 컨텍스트에서만 채운다
 *   3) 이력 화면이라 저장·삭제 계약이 없다
 *
 * PIPELINE[HB92] 로그인 이력 MyBatis 매퍼
 */
package com.haccp.sys.log;

// 역할 — MyBatis 매퍼 등록
import org.apache.ibatis.annotations.Mapper;
// 역할 — 다중 파라미터 이름 바인딩
import org.apache.ibatis.annotations.Param;

// 역할 — 이력 행 목록
import java.util.List;
import java.util.Map;

@Mapper
public interface LoginHistoryMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 기간 내 로그인 시도 이력을 최신순으로 조회한다
     *   2) 화면 진입·조회와 좌측 사용자 트리 선택 시 호출한다
     *   3) 해당 기간에 이력이 없으면 빈 목록
     */
    List<Map<String, Object>> selectRows(
            // JWT 회사코드 — 테넌트 범위. 필수 등가 조건
            @Param("coCd") String coCd,
            // 조회 시작일 YYYYMMDD
            @Param("fromDt") String fromDt,
            // 조회 종료일 YYYYMMDD — 그날 24시 직전까지 포함
            @Param("toDt") String toDt,
            // 좌측 트리에서 고른 아이디 검색어. 공백이면 전체
            @Param("userId") String userId,
            // 결과 필터 S:성공 F:실패 L:잠금. 공백이면 전체
            @Param("resultCd") String resultCd
    );
}
