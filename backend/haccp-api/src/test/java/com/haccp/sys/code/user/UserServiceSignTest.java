/**
 * UserServiceSignTest — 서명 이미지 업로드.
 *
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 여기는 **밖에서 들어온 바이트가 우리 도메인으로 되돌아 나가는** 유일한 경로다.
 *      올린 쪽이 준 Content-Type 을 그대로 저장했다가 inline 으로 돌려줬다 —
 *      text/html 로 올리면 우리 화면에서 실행되는 문서가 됐다 (2026-08-27 수정)
 *   2) 그래서 **저장되는 MIME 값**을 시험한다. 통과·거절만 봐서는 못 잡는다
 *   3) DB 없이 매퍼를 가짜로 세워 검사와 저장값만 본다
 *
 * PIPELINE[HB96] 사용자 업무 서비스
 */
package com.haccp.sys.code.user;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.haccp.common.exception.BizException;
import com.haccp.sys.logs.auditlog.AuditWriter;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.mock.web.MockMultipartFile;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class UserServiceSignTest {

    @Mock
    private UserMapper userMapper;

    @Mock
    private AuditWriter auditWriter;

    @InjectMocks
    private UserService service;

    private static MockMultipartFile file(String name, String mime, int size) {
        return new MockMultipartFile("file", name, mime, new byte[size]);
    }

    /** 실제로 저장된 MIME 값을 꺼낸다 — updateSign 의 네 번째 인자 */
    private String storedMime() {
        ArgumentCaptor<String> mime = ArgumentCaptor.forClass(String.class);
        verify(userMapper).updateSign(any(), any(), any(), mime.capture(), any(), any());
        return mime.getValue();
    }

    // ---------------------------------------------------------------- 저장되는 MIME

    @Test
    void 올린_쪽이_준_Content_Type_은_믿지_않는다() {
        // 저장된 값이 그대로 응답의 Content-Type 이 되어 inline 으로 되돌아간다.
        // 둘이 어긋날 때 어느 쪽을 쓰는지가 이 시험의 전부다 — 확장자를 쓴다
        service.uploadSign("admin", file("sign.png", "image/jpeg", 10));

        assertEquals("image/png", storedMime());
    }

    @Test
    void 확장자로_MIME_을_정한다() {
        service.uploadSign("admin", file("도장.JPG", "image/jpeg", 10));

        assertEquals("image/jpeg", storedMime());
    }

    @Test
    void Content_Type_이_비어도_확장자로_채운다() {
        // 일부 클라이언트는 Content-Type 을 안 보낸다 — 그래도 저장은 돼야 한다
        service.uploadSign("admin", file("sign.png", "", 10));

        assertEquals("image/png", storedMime());
    }

    // ---------------------------------------------------------------- 거절

    @Test
    void 확장자가_이미지가_아니면_막는다() {
        // 예전에는 Content-Type 이 image/png 이면 확장자를 안 봤다
        assertThrows(
                BizException.class, () -> service.uploadSign("admin", file("evil.html", "image/png", 10)));
        verify(userMapper, never()).updateSign(any(), any(), any(), any(), any(), any());
    }

    @Test
    void 확장자는_맞아도_Content_Type_이_이미지가_아니면_막는다() {
        assertThrows(
                BizException.class, () -> service.uploadSign("admin", file("sign.png", "text/html", 10)));
    }

    @Test
    void 빈_파일은_막는다() {
        assertThrows(BizException.class, () -> service.uploadSign("admin", file("sign.png", "image/png", 0)));
        verify(userMapper, never()).updateSign(any(), any(), any(), any(), any(), any());
    }

    @Test
    void 십메가를_넘으면_막는다() {
        // 넘기면 DB bytea 로 그대로 들어가 조회가 통째로 느려진다
        int overTenMb = 10 * 1024 * 1024 + 1;
        assertThrows(
                BizException.class,
                () -> service.uploadSign("admin", file("sign.png", "image/png", overTenMb)));
    }

    @Test
    void 십메가_정각은_받는다() {
        // 경계 — 「10MB 이하」라고 안내해 놓고 10MB 를 막으면 안내가 거짓이 된다
        assertDoesNotThrow(
                () -> service.uploadSign("admin", file("sign.png", "image/png", 10 * 1024 * 1024)));
    }

    @Test
    void 대상_아이디가_공백이면_막는다() {
        assertThrows(BizException.class, () -> service.uploadSign("   ", file("sign.png", "image/png", 10)));
        verify(userMapper, never()).updateSign(any(), any(), any(), any(), any(), any());
    }

    // ---------------------------------------------------------------- 감사

    @Test
    void 올린_뒤_감사_기록을_남긴다() {
        service.uploadSign("admin", file("sign.png", "image/png", 10));

        verify(auditWriter).record(eq("tbl_user"), any(), eq("U"), any());
    }
}
