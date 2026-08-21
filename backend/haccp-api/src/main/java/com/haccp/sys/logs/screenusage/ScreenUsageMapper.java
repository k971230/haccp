/**
 * ScreenUsageMapper — 화면 이용 통계 화면(screen-usage-statistics) SP 호출 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) sp_screen_usage_statistics_r_000 조회 1건만 담당한다 — 집계 적재는 log 배치가 한다
 *   2) coCd는 Service가 JWT 컨텍스트에서만 채운다
 *   3) 원시 로그가 아니라 일자 집계 테이블을 읽으므로 전일까지의 값만 나온다
 *
 * PIPELINE[HB92] 화면 이용 통계 MyBatis 매퍼
 */
package com.haccp.sys.logs.screenusage;

// 역할 — MyBatis 매퍼 등록
import org.apache.ibatis.annotations.Mapper;
// 역할 — 다중 파라미터 이름 바인딩
import org.apache.ibatis.annotations.Param;

// 역할 — 통계 행 목록
import java.util.List;
import java.util.Map;

@Mapper
public interface ScreenUsageMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 기간 내 화면별 PV/UV/세션/IP 집계를 최신순으로 조회한다
     *   2) 화면 진입·조회와 좌측 메뉴 트리 선택 시 호출한다
     *   3) 집계가 아직 없으면 빈 목록
     */
    List<Map<String, Object>> selectRows(
            // JWT 회사코드 — 테넌트 범위. 필수 등가 조건
            @Param("coCd") String coCd,
            // 집계 시작일 YYYYMMDD
            @Param("fromDt") String fromDt,
            // 집계 종료일 YYYYMMDD
            @Param("toDt") String toDt,
            // 좌측 메뉴 트리에서 고른 화면코드. 공백이면 전체 화면
            @Param("scrnCd") String scrnCd
    );
}
