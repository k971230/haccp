/**
 * AuthMapper — 인증·로그인 이력 MyBatis 매퍼 인터페이스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) sp_tbl_user_login_r_000 / _u_000, sp_tbl_role_screen_r_000, sp_tbl_login_log_c_000 / _u_000 을 호출한다
 *   2) SQL 본문은 mapper/auth/AuthMapper.xml 에 있다 — 이 인터페이스는 시그니처만 선언한다
 *   3) 직접 SQL을 쓰지 않는다. 조회는 FUNCTION, 쓰기는 PROCEDURE 규약(07-haccp-db)을 그대로 따른다
 *
 * PIPELINE[HB27] MyBatis 매퍼
 */
package com.metis.haccp.auth;

// 역할 — 화면권한 Row DTO
import com.metis.haccp.auth.dto.ScreenAuthRow;
// 역할 — 로그인 사용자 Row DTO
import com.metis.haccp.auth.dto.UserLoginRow;
// 역할 — @Mapper 등록
import org.apache.ibatis.annotations.Mapper;
// 역할 — 다중 파라미터 이름 지정
import org.apache.ibatis.annotations.Param;

// 역할 — 토큰 만료 일시 타입
import java.time.LocalDateTime;
// 역할 — 화면권한 목록
import java.util.List;

@Mapper
public interface AuthMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 아이디로 로그인 검증용 사용자 1건을 조회한다
     *   2) 비밀번호 비교 전, 계정 존재·잠금·사용여부·구독기간을 판정하기 위해 호출한다
     *   3) 아이디가 있으면 UserLoginRow, 없으면 null을 반환한다
     */
    UserLoginRow selectUserForLogin(
            // 로그인 화면에서 입력한 아이디 — 전 업체 통틀어 유일하므로 회사코드 없이 단건 조회가 된다
            // 대소문자를 구분한다. 존재하지 않아도 예외가 아니라 null이며, 호출부가 실패로 처리한다
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 로그인 결과를 사용자 마스터에 반영한다 (성공: 실패횟수 초기화, 실패: 증가·임계 초과 시 잠금)
     *   2) 자격 검증이 끝난 직후 성공·실패 양쪽 경로에서 호출한다
     *   3) 성공 시 갱신 행 수를 반환하고, 아이디가 없으면 0행이며 예외는 아니다
     */
    int updateLoginResult(
            // 대상 아이디 — 존재하지 않는 아이디면 갱신 대상이 없어 0행이 된다
            @Param("userId") String userId,
            // 로그인 결과 — 'S'일 때(= 성공) 실패횟수 0·최종로그인 갱신, 그 외(= 실패)면 실패횟수 +1
            @Param("resultCd") String resultCd,
            // 잠금 임계 실패횟수 — app.login.max-fail-count. 0 이하이면(= 잠금 미사용) 잠그지 않는다
            @Param("maxFail") int maxFail
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 권한그룹에 부여된 화면 권한 전체 목록을 조회한다
     *   2) 로그인 성공 후 프론트에 버튼 활성 기준을 내려주기 위해 호출한다
     *   3) 미설정 화면도 'N'으로 채워진 전체 목록을 반환하고, 사용중 화면이 없으면 빈 목록이다
     */
    List<ScreenAuthRow> selectScreenAuths(
            // JWT 회사코드 — 테넌트 범위. 같은 권한그룹코드가 업체마다 따로 존재한다
            @Param("coCd") String coCd,
            // 권한그룹코드 — tbl_user.usrgrp_cd
            @Param("usrgrpCd") String usrgrpCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 로그인 시도 1건을 이력 테이블에 적재한다 (성공·실패·잠금 전수)
     *   2) 자격 검증 결과가 확정된 직후, 응답을 만들기 전에 호출한다
     *   3) 성공 시 1행을 적재한다. 존재하지 않는 아이디도 그대로 남겨 공격 시도를 추적할 수 있게 한다
     */
    int insertLoginLog(
            // 소속 회사코드 — 아이디를 찾지 못해 회사를 알 수 없으면 null (SP가 NULLIF로 처리한다)
            @Param("coCd") String coCd,
            // 시도한 아이디 — 존재하지 않는 아이디도 원문 그대로 남긴다
            @Param("userId") String userId,
            // 세션 UUID — 성공일 때만 값이 있고 실패면 null
            @Param("sid") String sid,
            // 결과 코드 — S:성공, F:실패, L:잠금
            @Param("resultCd") String resultCd,
            // 실패 사유(기술 문구) — 서버 분석용이며 사용자 응답에는 쓰지 않는다
            @Param("failReason") String failReason,
            // 접속 IP — 프록시 뒤에서는 X-Forwarded-For 첫 값
            @Param("ipAddr") String ipAddr,
            // User-Agent 원문 — 길이 초과는 호출부에서 잘라 넣는다
            @Param("userAgent") String userAgent,
            // 기기 구분 — PC / MOBILE / TABLET (User-Agent로 추정)
            @Param("deviceGbn") String deviceGbn,
            // 발급 토큰 만료 예정일시 — 실패면 null
            @Param("tokenExpDt") LocalDateTime tokenExpDt
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 해당 세션의 로그아웃 시각을 기록한다
     *   2) 프론트가 로그아웃 버튼을 눌렀을 때 호출한다
     *   3) 미종료 최신 1행만 갱신하므로, 중복 호출해도 이전 세션 기록을 덮어쓰지 않는다
     */
    int updateLogout(
            // 종료할 세션 UUID — JWT sid 클레임. 값이 없으면 갱신 대상이 없어 0행이다
            @Param("sid") String sid
    );
}
