/**
 * LogMapper — 화면 조회 로그·일자 UV/PV 집계 MyBatis 매퍼 인터페이스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 원시 적재(sp_tbl_view_log_c_000)와 일자 집계(sp_tbl_view_stat_daily_c_000)를 담당한다
 *   2) SQL 본문은 mapper/log/LogMapper.xml 에 있다
 *   3) 집계는 ViewStatDailyJob이 일 1회 호출한다 — 통계 화면은 집계 테이블만 읽는다
 *
 * PIPELINE[HB44] MyBatis 매퍼
 */
package com.metis.haccp.log;

// 역할 — @Mapper 등록
import org.apache.ibatis.annotations.Mapper;
// 역할 — 다중 파라미터 이름 지정
import org.apache.ibatis.annotations.Param;

// 역할 — 진입·이탈 일시 타입
import java.time.LocalDateTime;

@Mapper
public interface LogMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 화면 조회 이벤트 1건을 원시 로그 테이블에 적재한다
     *   2) 프론트가 보낸 배치의 각 항목마다 호출한다
     *   3) 성공 시 1행을 적재한다. 체류시간은 SP가 진입·이탈 시각 차이로 계산한다
     */
    int insertViewLog(
            // JWT 회사코드 — 테넌트 범위
            @Param("coCd") String coCd,
            // JWT 로그인 아이디 — UV(순방문자) 집계의 distinct 기준
            @Param("userId") String userId,
            // JWT 세션 UUID — 세션수 집계 기준. 비어 있으면 SP가 NULL로 저장한다
            @Param("sid") String sid,
            // 조회한 화면코드
            @Param("scrnCd") String scrnCd,
            // 화면 진입 일시 — 필수. 체류시간 계산의 시작점이다
            @Param("enterDt") LocalDateTime enterDt,
            // 화면 이탈 일시 — null이면(= 아직 머무는 중) 체류시간도 null로 저장된다
            @Param("leaveDt") LocalDateTime leaveDt,
            // 직전 화면코드 — 이동 경로 분석용. 첫 진입이면 비어 있다
            @Param("refScrnCd") String refScrnCd,
            // 접속 IP
            @Param("ipAddr") String ipAddr,
            // User-Agent 원문
            @Param("userAgent") String userAgent
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) tbl_view_log를 읽어 tbl_view_stat_daily에 UV/PV/세션·체류를 업서트한다
     *   2) ViewStatDailyJob이 전일·당일 일자로 호출한다
     *   3) 같은 일자를 다시 돌려도 ON CONFLICT로 결과가 동일하다
     */
    void aggregateViewStatDaily(
            // 집계 대상 회사코드 — 공백이면(= 전체 업체) SP가 전 테넌트를 한 번에 집계한다
            @Param("coCd") String coCd,
            // 집계 일자 YYYYMMDD — enter_dt가 해당 일자인 원시 이벤트만 대상
            @Param("statDt") String statDt,
            // 배치 실행 주체 — ins_id/upd_id 감사 컬럼
            @Param("userId") String userId
    );
}
