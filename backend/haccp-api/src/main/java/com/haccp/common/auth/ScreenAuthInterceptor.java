/**
 * ScreenAuthInterceptor — tbl_role_screen 으로 API 쓰기·삭제를 서버에서 막는다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) JwtFilter 다음에 돈다. 로그인은 됐고 화면 권한이 N 인 호출만 본다
 *   2) ADMIN 은 프론트와 같이 전권. enforce=false 면 거부 로그만 남기고 통과(shadow)
 *   3) 계정·URL·부족한 권한 칸·시각을 warn 으로 남긴다 — 프론트 설정 오류와 오남용을 가른다
 *
 * PIPELINE[HB145] 화면 권한 인터셉터
 */
package com.haccp.common.auth;

import com.haccp.auth.AuthMapper;
import com.haccp.auth.dto.ScreenAuthRow;
import com.haccp.common.context.LoginUser;
import com.haccp.common.context.LoginUserContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/** 화면 권한 MVC 인터셉터 — 경로 맵은 ScreenAuthResolver */
@Component
public class ScreenAuthInterceptor implements HandlerInterceptor {

    private static final Logger log = LoggerFactory.getLogger(ScreenAuthInterceptor.class);

    private final AuthMapper authMapper;

    /** true 이면 403, false 이면 로그만 (운영 shadow 1일) */
    @Value("${app.screen-auth.enforce:true}")
    private boolean enforce;

    public ScreenAuthInterceptor(AuthMapper authMapper) {
        this.authMapper = authMapper;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 매핑된 API 의 화면 권한을 tbl_role_screen(SP)과 대조한다
     *   2) 컨트롤러 진입 전에 호출한다
     *   3) 통과 true, 거부 시 403 JSON 후 false. shadow 면 true
     */
    @Override
    public boolean preHandle(
            // 현재 요청 — method·URI
            HttpServletRequest request,
            // 거부 시 403 본문을 직접 쓴다
            HttpServletResponse response,
            // 매핑된 핸들러 — 사용하지 않는다
            Object handler
    ) throws IOException {
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            return true;
        }
        LoginUser user = LoginUserContext.get();
        if (user == null) {
            return true;
        }
        Optional<ScreenAuthMatch> match = ScreenAuthResolver.resolve(
                request.getMethod(),
                request.getRequestURI()
        );
        // 감사 로그 화면코드 — ADMIN 전권이어도 적재기는 어느 화면인지 알아야 한다
        ScreenAuthResolver.bindRequestScreen(request, match);
        if (user.isAdmin()) {
            return true;
        }
        if (match.isEmpty()) {
            return true;
        }
        List<ScreenAuthRow> rows = authMapper.selectScreenAuths(user.getCoCd(), user.getUsrgrpCd());
        ScreenAuthMatch m = match.get();
        boolean ok;
        if (m.hubKind() == ScreenAuthMatch.HubKind.DOC) {
            ok = grantedAny(rows, ScreenAuthResolver.DOC_HUB_SCREENS, m.action());
        } else if (m.hubKind() == ScreenAuthMatch.HubKind.HWP) {
            ok = grantedAny(rows, ScreenAuthResolver.HWP_HUB_SCREENS, m.action());
        } else {
            ok = granted(find(rows, m.scrnCd()), m.action());
        }
        if (ok) {
            return true;
        }
        String perm = m.action().name();
        String scrn;
        if (m.hubKind() == ScreenAuthMatch.HubKind.DOC) {
            scrn = "docs-documents-hub";
        } else if (m.hubKind() == ScreenAuthMatch.HubKind.HWP) {
            scrn = "docs-documents-hwp-hub";
        } else {
            scrn = m.scrnCd();
        }
        log.warn(
                "screen-auth deny userId={} usrgrpCd={} url={} scrnCd={} perm={} enforce={}",
                user.getUserId(),
                user.getUsrgrpCd(),
                request.getRequestURI(),
                scrn,
                perm,
                enforce
        );
        if (!enforce) {
            return true;
        }
        response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write(
                "{\"success\":false,\"code\":\"FORBIDDEN\",\"message\":\"이 화면에서 해당 작업을 할 권한이 없습니다.\"}"
        );
        return false;
    }

    /** 테스트·기동 후 enforce 값을 맞출 때 쓴다 */
    void setEnforce(boolean enforce) {
        this.enforce = enforce;
    }

    private static ScreenAuthRow find(List<ScreenAuthRow> rows, String scrnCd) {
        if (rows == null || scrnCd == null) {
            return null;
        }
        for (ScreenAuthRow row : rows) {
            if (scrnCd.equals(row.getScrnCd())) {
                return row;
            }
        }
        return null;
    }

    private static boolean grantedAny(
            List<ScreenAuthRow> rows,
            Set<String> allowed,
            ScreenAuthAction action
    ) {
        if (rows == null) {
            return false;
        }
        for (ScreenAuthRow row : rows) {
            if (row.getScrnCd() != null
                    && allowed.contains(row.getScrnCd())
                    && granted(row, action)) {
                return true;
            }
        }
        return false;
    }

    static boolean granted(ScreenAuthRow row, ScreenAuthAction action) {
        if (row == null || action == null) {
            return false;
        }
        return switch (action) {
            case READ -> yn(row.getReadYn());
            case WRITE -> yn(row.getWriteYn());
            case MODIFY -> yn(row.getModifyYn());
            case SAVE -> yn(row.getWriteYn()) || yn(row.getModifyYn());
            case DELETE -> yn(row.getDeleteYn());
            case PRINT -> yn(row.getPrintYn());
        };
    }

    private static boolean yn(String v) {
        return "Y".equalsIgnoreCase(v);
    }
}
