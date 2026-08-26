/**
 * AuthServiceGuardTest — 로그인 관문.
 *
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 잠금·사용중지·업체정지·구독만료를 **비밀번호가 맞아도** 막는지 본다 —
 *      순서가 뒤집히면 정지된 계정이 들어온다
 *   2) 아이디 없음과 비밀번호 틀림을 **같은 문구**로 돌려주는지 고정한다.
 *      다르면 어느 아이디가 존재하는지 밖에서 알아낼 수 있다
 *   3) DB·Spring 없이 매퍼를 가짜로 세워 판정만 본다
 *
 * PIPELINE[HB20] 인증 업무 서비스
 */
package com.haccp.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.haccp.auth.dto.LoginRequest;

import com.haccp.auth.dto.UserLoginRow;
import com.haccp.common.config.JwtProvider;
import com.haccp.common.context.RequestMeta;
import com.haccp.common.exception.BizException;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AuthServiceGuardTest {

    /** '1234' 의 BCrypt 해시 — 시드와 같은 값 */
    private static final String PW_1234 =
            "$2a$10$omCFk.XMhqOp5dAmMQ7Me.Rp9c0f87cCPZS3IRg1avF5PVWRzjw4O";

    @Mock
    private AuthMapper authMapper;

    @Mock
    private JwtProvider jwtProvider;

    @InjectMocks
    private AuthService service;

    /** 아무 문제 없는 계정 — 시험마다 필요한 칸만 흐트러뜨린다 */
    private static UserLoginRow healthy() {
        UserLoginRow r = new UserLoginRow();
        r.setUserId("admin");
        r.setCoCd("0000");
        r.setUserPw(PW_1234);
        r.setLockYn("N");
        r.setUserUseYn("Y");
        r.setCoUseYn("Y");
        r.setUsrgrpCd("ADMIN");
        return r;
    }

    /** 접속 메타 — 이력에만 쓴다. null 을 넣으면 이력 경로가 통째로 안 돌아간다 */
    private static final RequestMeta META = new RequestMeta("127.0.0.1", "junit", "PC");

    private static LoginRequest req(String id, String pw) {
        LoginRequest q = new LoginRequest();
        q.setUserId(id);
        q.setPassword(pw);
        return q;
    }

    private void given(UserLoginRow row) {
        ReflectionTestUtils.setField(service, "maxFailCount", 5);
        ReflectionTestUtils.setField(service, "expireMinutes", 480L);
        when(authMapper.selectUserForLogin(any())).thenReturn(row);
    }

    // ---------------------------------------------------------------- 아이디 노출

    @Test
    void 없는_아이디와_틀린_비밀번호는_같은_문구다() {
        // 다르면 어느 아이디가 존재하는지 밖에서 알아낼 수 있다
        ReflectionTestUtils.setField(service, "maxFailCount", 5);

        when(authMapper.selectUserForLogin(any())).thenReturn(null);
        BizException noId = assertThrows(
                BizException.class, () -> service.login(req("없는아이디", "1234"), META));

        when(authMapper.selectUserForLogin(any())).thenReturn(healthy());
        BizException badPw = assertThrows(
                BizException.class, () -> service.login(req("admin", "틀린비번"), META));

        assertEquals(noId.getMessage(), badPw.getMessage());
        assertEquals("LOGIN_FAIL", noId.getCode());
        assertEquals("LOGIN_FAIL", badPw.getCode());
    }

    // ---------------------------------------------------------------- 관문 넷

    @Test
    void 잠긴_계정은_비밀번호가_맞아도_막는다() {
        // 순서가 뒤집혀 비밀번호부터 보면 잠금이 뜻을 잃는다
        UserLoginRow row = healthy();
        row.setLockYn("Y");
        given(row);

        BizException e = assertThrows(BizException.class, () -> service.login(req("admin", "1234"), META));
        assertEquals("LOGIN_LOCKED", e.getCode());
        verify(jwtProvider, never()).createToken(any());
    }

    @Test
    void 사용중지_계정은_막는다() {
        UserLoginRow row = healthy();
        row.setUserUseYn("N");
        given(row);

        BizException e = assertThrows(BizException.class, () -> service.login(req("admin", "1234"), META));
        assertEquals("USER_DISABLED", e.getCode());
    }

    @Test
    void 업체가_정지되면_그_업체_사람은_전부_막힌다() {
        UserLoginRow row = healthy();
        row.setCoUseYn("N");
        given(row);

        BizException e = assertThrows(BizException.class, () -> service.login(req("admin", "1234"), META));
        assertEquals("COMPANY_DISABLED", e.getCode());
    }

    @Test
    void 구독이_끝난_업체는_막는다() {
        // 어제로 끝난 계약 — 오늘은 못 들어온다
        UserLoginRow row = healthy();
        row.setSvcFnDt(LocalDate.now().minusDays(1).format(DateTimeFormatter.ofPattern("yyyyMMdd")));
        given(row);

        BizException e = assertThrows(BizException.class, () -> service.login(req("admin", "1234"), META));
        assertEquals("SERVICE_EXPIRED", e.getCode());
    }

    @Test
    void 구독_종료일이_오늘이면_아직_쓸_수_있다() {
        // 경계 — 마지막 날에 못 들어오면 계약보다 하루 짧다
        UserLoginRow row = healthy();
        row.setSvcFnDt(LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd")));
        given(row);

        service.login(req("admin", "1234"), META);

        // 성공 갱신까지 왔으면 관문 넷을 다 지난 것이다
        verify(authMapper, times(1)).updateLoginResult(eq("admin"), eq("S"), anyInt());
    }

    @Test
    void 구독_종료일이_비면_무기한으로_본다() {
        // 종료일을 안 정한 업체가 만료로 막히면 안 된다
        UserLoginRow row = healthy();
        row.setSvcFnDt("   ");
        given(row);

        service.login(req("admin", "1234"), META);

        verify(authMapper, times(1)).updateLoginResult(eq("admin"), eq("S"), anyInt());
    }

    // ---------------------------------------------------------------- 실패 누적

    @Test
    void 비밀번호를_틀리면_실패로_기록한다() {
        given(healthy());

        assertThrows(BizException.class, () -> service.login(req("admin", "틀린비번"), META));

        verify(authMapper, times(1)).updateLoginResult(eq("admin"), eq("F"), anyInt());
    }

    @Test
    void 임계에_닿으면_잠김_문구로_바꾼다() {
        // 실패 5회째에는 「틀렸다」가 아니라 「잠겼다」를 보여줘야 다음 행동을 안다
        UserLoginRow row = healthy();
        row.setLoginFailCnt(4);
        given(row);

        BizException e = assertThrows(BizException.class, () -> service.login(req("admin", "틀린비번"), META));
        assertEquals("LOGIN_LOCKED", e.getCode());
        assertTrue(e.getMessage().contains("5"), e.getMessage());
    }
}
