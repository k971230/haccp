/**
 * AuthService — 로그인·로그아웃 비즈니스 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 아이디 조회 → 계정상태(잠금·정지·구독) 판정 → BCrypt 비교 → 세션 발급(sid+JWT) → 이력 적재 순서로 처리한다
 *   2) 의도적으로 @Transactional을 걸지 않는다 — 실패 시 BizException을 던지는데 트랜잭션이 있으면
 *      실패횟수 증가와 시도 이력이 함께 롤백되어 브루트포스 잠금이 영원히 동작하지 않는다
 *   3) 사용자에게 보이는 실패 문구는 원인을 구분하지 않는다(아이디 없음/비밀번호 틀림 동일).
 *      구분 가능한 기술 사유는 tbl_login_log.fail_reason 에만 남긴다
 *
 * PIPELINE[HB20] Service
 * PIPELINE[HB4, HB19, HB27] 연관 모듈
 */
package com.haccp.auth;

// 역할 — 로그인 요청 DTO
import com.haccp.auth.dto.LoginRequest;
// 역할 — 로그인 응답 DTO
import com.haccp.auth.dto.LoginResponse;
// 역할 — 화면권한 Row DTO
import com.haccp.auth.dto.ScreenAuthRow;
// 역할 — 로그인 검증용 사용자 Row DTO
import com.haccp.auth.dto.UserLoginRow;
// 역할 — JWT 발급
import com.haccp.common.config.JwtProvider;
// 역할 — 로그인 사용자 DTO
import com.haccp.common.context.LoginUser;
// 역할 — 접속 메타(IP·UA·기기)
import com.haccp.common.context.RequestMeta;
// 역할 — 업무 예외
import com.haccp.common.exception.BizException;
// 역할 — @RequiredArgsConstructor 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — 로그 적재 실패 경고 기록
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
// 역할 — @Value 설정 주입
import org.springframework.beans.factory.annotation.Value;
// 역할 — BCrypt 해시 비교
import org.springframework.security.crypto.bcrypt.BCrypt;
// 역할 — @Service 등록
import org.springframework.stereotype.Service;

// 역할 — 토큰 만료 일시 계산
import java.time.LocalDateTime;
// 역할 — 구독 종료일 비교용 오늘 날짜
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
// 역할 — 관리자 전권 시 빈 권한 목록
import java.util.Collections;
// 역할 — 화면권한 목록
import java.util.List;
// 역할 — 세션 식별자 생성
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {

    // 로그 적재 실패는 경고만 남기고 로그인은 진행시킨다
    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    /** 구독 종료일(svc_fn_dt) 비교용 — DB가 YYYYMMDD 문자열로 보관하므로 같은 형식으로 맞춘다 */
    private static final DateTimeFormatter YMD = DateTimeFormatter.ofPattern("yyyyMMdd");

    /** 사용자에게 보여줄 공통 실패 문구 — 아이디 없음과 비밀번호 불일치를 구분하지 않는다 */
    private static final String MSG_LOGIN_FAIL = "로그인에 실패했습니다. 아이디와 비밀번호를 확인해 주세요.";

    // 사용자·권한·로그인 이력 SP 호출
    private final AuthMapper authMapper;
    // JWT 발급 담당
    private final JwtProvider jwtProvider;

    /** 계정 잠금 임계 실패횟수 — .env LOGIN_MAX_FAIL_COUNT. 0 이하이면 잠금 미사용 */
    @Value("${app.login.max-fail-count:5}")
    private int maxFailCount;

    /** 토큰 만료(분) — 로그인 이력의 token_exp_dt 계산에 쓴다. JwtProvider와 같은 설정값을 읽는다 */
    @Value("${app.jwt.expire-minutes:480}")
    private long expireMinutes;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 아이디·비밀번호를 검증하고 토큰·사용자정보·화면권한을 담은 로그인 응답을 만든다
     *   2) 로그인 화면의 확인 버튼에서 호출한다
     *   3) 성공 시 LoginResponse를 반환하고, 실패 시 BizException으로 업무 문구를 전달한다.
     *      어느 경로로 실패해도 tbl_login_log에 시도 기록이 남는다
     */
    public LoginResponse login(
            // 로그인 요청 — 아이디·비밀번호. 회사코드는 받지 않는다(아이디가 전역 유일)
            // @Valid가 공백을 이미 걸렀으므로 여기서는 값 존재를 다시 확인하지 않는다
            LoginRequest req,
            // 접속 메타 — IP·User-Agent·기기구분. 이력에만 쓰고 인증 판정에는 쓰지 않는다
            RequestMeta meta
    ) {
        // 입력 아이디로 사용자 1건 조회 — 전역 유일이라 회사코드가 필요 없다
        UserLoginRow row = authMapper.selectUserForLogin(req.getUserId());

        // row가 null일 때(= 존재하지 않는 아이디) 회사코드를 알 수 없으므로 null로 이력만 남기고 거절한다
        if (row == null) {
            writeLoginLog(null, req.getUserId(), null, "F", "USER_NOT_FOUND", meta, null);
            throw new BizException("LOGIN_FAIL", MSG_LOGIN_FAIL);
        }

        // 잠금·정지·구독 판정 — 비밀번호가 맞아도 통과시키지 않는다
        assertAccountUsable(row, meta);

        // BCrypt 해시 비교 — 저장된 해시가 비었으면(= 초기화 미완 계정) 비교 없이 실패 처리한다
        boolean pwMatched = row.getUserPw() != null && !row.getUserPw().isBlank()
                && BCrypt.checkpw(req.getPassword(), row.getUserPw());

        // 비밀번호가 틀렸을 때(= 실패) 카운터를 올리고, 이번 시도로 임계에 도달했는지 계산해 문구를 나눈다
        if (!pwMatched) {
            authMapper.updateLoginResult(row.getUserId(), "F", maxFailCount);
            // 조회 시점 실패횟수 + 이번 실패 1회 — SP가 방금 올린 값과 같다
            int failed = (row.getLoginFailCnt() == null ? 0 : row.getLoginFailCnt()) + 1;
            // 임계에 도달했을 때(= 이번 시도로 계정이 잠긴 상태) 결과코드를 L로 남기고 잠금 문구를 낸다
            if (maxFailCount > 0 && failed >= maxFailCount) {
                writeLoginLog(row.getCoCd(), row.getUserId(), null, "L", "PASSWORD_MISMATCH_LOCKED", meta, null);
                throw new BizException("LOGIN_LOCKED",
                        "비밀번호를 " + maxFailCount + "회 이상 틀려 계정이 잠겼습니다. 관리자에게 잠금 해제를 요청해 주세요.");
            }
            writeLoginLog(row.getCoCd(), row.getUserId(), null, "F", "PASSWORD_MISMATCH", meta, null);
            throw new BizException("LOGIN_FAIL", MSG_LOGIN_FAIL);
        }

        // 세션 식별자 — 로그인 1회당 1개. 화면조회 로그(UV 집계)와 로그아웃 시각을 잇는 키다
        String sid = UUID.randomUUID().toString();
        // 응답·JWT에 실을 사용자 정보 조립 — 비밀번호 해시는 담지 않는다
        LoginUser user = LoginUser.builder()
                .coCd(row.getCoCd())
                .coNm(row.getCoNm())
                .userId(row.getUserId())
                .userNm(row.getUserNm())
                .usrgrpCd(row.getUsrgrpCd())
                .deptCd(row.getDeptCd())
                .deptNm(row.getDeptNm())
                .sid(sid)
                .build();

        // 실패횟수 초기화·최종 로그인 일시 갱신 — 성공 경로에서 반드시 호출해야 카운터가 리셋된다
        authMapper.updateLoginResult(row.getUserId(), "S", maxFailCount);

        String token = jwtProvider.createToken(user);
        // 토큰 만료 예정일시 — 세션 만료 분석·강제 로그아웃 판단 근거로 이력에 남긴다
        LocalDateTime tokenExpDt = LocalDateTime.now().plusMinutes(expireMinutes);
        writeLoginLog(row.getCoCd(), row.getUserId(), sid, "S", null, meta, tokenExpDt);

        // 관리자(usrgrpCd=ADMIN)일 때(= 전권) 권한 목록을 조회하지 않고 빈 목록을 보낸다.
        // 프론트는 (isAdmin && screens 비어있음)을 전권으로 해석한다
        List<ScreenAuthRow> screens = user.isAdmin()
                ? Collections.emptyList()
                : authMapper.selectScreenAuths(row.getCoCd(), row.getUsrgrpCd());

        return new LoginResponse(token, user, screens);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 계정 잠금·사용중지·업체 정지·구독 만료를 판정해 사용 가능한 계정인지 확인한다
     *   2) 비밀번호 비교 직전에 호출한다 — 비밀번호가 맞아도 이 관문을 통과하지 못하면 로그인은 실패다
     *   3) 통과 시 아무 것도 하지 않고, 위반 시 사유별 이력을 남긴 뒤 BizException을 던진다
     */
    private void assertAccountUsable(
            // 조회된 사용자 1건 — 잠금여부·사용여부·회사 사용여부·서비스 종료일을 판정에 사용한다
            UserLoginRow row,
            // 접속 메타 — 거절 이력에 함께 남긴다
            RequestMeta meta
    ) {
        // lockYn이 Y일 때(= 실패횟수 초과로 잠긴 계정) 관리자 해제 전까지 거절한다
        if ("Y".equalsIgnoreCase(row.getLockYn())) {
            writeLoginLog(row.getCoCd(), row.getUserId(), null, "L", "ACCOUNT_LOCKED", meta, null);
            throw new BizException("LOGIN_LOCKED", "계정이 잠겨 있습니다. 관리자에게 잠금 해제를 요청해 주세요.");
        }
        // userUseYn이 Y가 아닐 때(= 퇴사·사용중지 계정) 거절한다
        if (!"Y".equalsIgnoreCase(row.getUserUseYn())) {
            writeLoginLog(row.getCoCd(), row.getUserId(), null, "F", "USER_DISABLED", meta, null);
            throw new BizException("USER_DISABLED", "사용이 중지된 계정입니다. 관리자에게 문의해 주세요.");
        }
        // coUseYn이 Y가 아닐 때(= 업체 자체가 정지) 소속 사용자 전원을 거절한다
        if (!"Y".equalsIgnoreCase(row.getCoUseYn())) {
            writeLoginLog(row.getCoCd(), row.getUserId(), null, "F", "COMPANY_DISABLED", meta, null);
            throw new BizException("COMPANY_DISABLED", "업체 서비스가 중지되었습니다. 관리자에게 문의해 주세요.");
        }
        // 구독 종료일 — YYYYMMDD 문자열이라 사전순 비교가 날짜 비교와 같다
        String svcFnDt = row.getSvcFnDt();
        // 종료일이 있고 오늘보다 이전일 때(= 구독 만료) 거절한다. 값이 없으면(= 무기한) 통과시킨다
        if (svcFnDt != null && !svcFnDt.isBlank() && svcFnDt.compareTo(LocalDate.now().format(YMD)) < 0) {
            writeLoginLog(row.getCoCd(), row.getUserId(), null, "F", "SERVICE_EXPIRED", meta, null);
            throw new BizException("SERVICE_EXPIRED", "서비스 이용 기간이 만료되었습니다. 관리자에게 문의해 주세요.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 해당 세션의 로그아웃 시각을 이력에 기록한다
     *   2) 프론트 로그아웃 버튼에서 호출한다 (토큰 폐기는 클라이언트가 세션을 지우는 것으로 완료된다)
     *   3) 기록 실패는 경고만 남기고 성공으로 응답한다 — 로그 문제로 로그아웃을 막지 않는다
     */
    public void logout(
            // 종료할 세션 UUID — JWT sid 클레임. null·공백이면 기록할 대상이 없어 조용히 종료한다
            String sid
    ) {
        // sid가 비었을 때(= sid 클레임 없는 구버전 토큰) 기록 없이 종료한다
        if (sid == null || sid.isBlank()) return;
        try {
            authMapper.updateLogout(sid);
        } catch (Exception e) {
            log.warn("logout log failed (sid={})", sid, e);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 로그인 시도 이력 1건을 적재한다
     *   2) 성공·실패·잠금 모든 경로에서 응답 또는 예외를 만들기 직전에 호출한다
     *   3) 적재 실패는 경고 로그만 남기고 삼킨다 — 로그 문제로 로그인 자체를 막지 않는다
     */
    private void writeLoginLog(
            // 소속 회사코드 — 아이디를 찾지 못했으면 null (SP가 NULL로 저장한다)
            String coCd,
            // 시도한 아이디 원문 — 존재하지 않는 아이디도 그대로 남겨 공격 패턴을 추적한다
            String userId,
            // 세션 UUID — 성공일 때만 값이 있다
            String sid,
            // 결과 코드 — S:성공, F:실패, L:잠금
            String resultCd,
            // 실패 사유 기술 문구 — USER_NOT_FOUND 등. 사용자 응답에는 절대 쓰지 않는다
            String failReason,
            // 접속 메타 — IP·User-Agent·기기구분
            RequestMeta meta,
            // 발급 토큰 만료 예정일시 — 실패면 null
            LocalDateTime tokenExpDt
    ) {
        try {
            authMapper.insertLoginLog(coCd, userId, sid, resultCd, failReason,
                    meta.ipAddr(), meta.userAgent(), meta.deviceGbn(), tokenExpDt);
        } catch (Exception e) {
            log.warn("login log failed (userId={}, result={})", userId, resultCd, e);
        }
    }
}
