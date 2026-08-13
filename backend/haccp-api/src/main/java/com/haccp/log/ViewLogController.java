/**
 * ViewLogController — 화면 조회 로그 수집 REST API (/api/v1/log/view).
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) POST /collect — 프론트가 버퍼링한 화면 진입·이탈 이벤트를 배치로 받아 적재한다
 *   2) 이벤트마다 API를 부르지 않는 이유는 탭 전환이 빈번해 요청 폭증을 유발하기 때문이다
 *      (프론트가 일정 간격 또는 페이지 이탈 시점에 모아 보낸다)
 *   3) 적재 실패는 응답 성공으로 처리한다 — 통계 수집이 업무 화면 동작을 막아서는 안 된다
 *
 * PIPELINE[HB46] REST Controller
 * PIPELINE[HB44, HB45] 연관 모듈
 */
package com.haccp.log;

// 역할 — 요청 스코프 컨텍스트 — coCd·userId·sid
import com.haccp.common.context.LoginUserContext;
// 역할 — 접속 메타(IP·UA·기기)
import com.haccp.common.context.RequestMeta;
// 역할 — API 공통 응답 래퍼
import com.haccp.common.response.CommonResponse;
// 역할 — 화면 조회 이벤트 DTO
import com.haccp.log.dto.ViewLogItem;
// 역할 — 접속 메타 원천
import jakarta.servlet.http.HttpServletRequest;
// 역할 — @NotBlank 등 Bean Validation 실행
import jakarta.validation.Valid;
// 역할 — @RequiredArgsConstructor 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — 적재 실패 경고 기록
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
// 역할 — REST 매핑 어노테이션
import org.springframework.web.bind.annotation.*;

// 역할 — 이벤트 배치 목록
import java.util.List;

/** 화면 조회 통계(UV/PV) 수집 → /api/v1/log/view/* */
@RestController
@RequestMapping("/api/v1/log/view")
@RequiredArgsConstructor
public class ViewLogController {

    // 적재 실패는 경고만 남기고 성공으로 응답한다
    private static final Logger log = LoggerFactory.getLogger(ViewLogController.class);

    // 화면 조회 로그 SP 호출
    private final LogMapper logMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 화면 진입·이탈 이벤트 배치를 원시 로그 테이블에 적재한다
     *   2) 프론트가 버퍼를 비울 때(주기 도달·페이지 이탈) 호출한다
     *   3) 적재한 건수를 반환한다. 개별 건 실패는 경고만 남기고 나머지 건을 계속 처리한다
     */
    @PostMapping("/collect")
    public CommonResponse<Integer> collect(
            // 화면 조회 이벤트 배치 — 화면코드·진입시각이 필수이고, 이탈시각은 없을 수 있다
            // 회사코드·아이디·세션은 본문에 두지 않는다. 서버가 JWT에서 채워 통계 조작을 막는다
            @Valid @RequestBody List<ViewLogItem> items,
            // 현재 HTTP 요청 — IP·User-Agent를 뽑아 로그에 남기기 위해서만 사용한다
            HttpServletRequest http
    ) {
        // 배치가 비었을 때(= 보낼 이벤트가 없음) 즉시 0건으로 응답한다
        if (items == null || items.isEmpty()) return CommonResponse.ok(0);

        // 테넌트·사용자·세션은 JWT에서 한 번만 읽어 전 건에 같은 값을 쓴다
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        String sid = LoginUserContext.sid();
        RequestMeta meta = RequestMeta.of(http);

        int saved = 0;
        for (ViewLogItem it : items) {
            try {
                logMapper.insertViewLog(coCd, userId, sid, it.getScrnCd(),
                        it.getEnterDt(), it.getLeaveDt(), it.getRefScrnCd(),
                        meta.ipAddr(), meta.userAgent());
                saved++;
            } catch (Exception e) {
                // 한 건이 실패해도 배치 전체를 버리지 않는다 — 통계는 손실을 허용하고 업무를 막지 않는다
                log.warn("view log failed (userId={}, scrnCd={})", userId, it.getScrnCd(), e);
            }
        }
        return CommonResponse.ok(saved);
    }
}
