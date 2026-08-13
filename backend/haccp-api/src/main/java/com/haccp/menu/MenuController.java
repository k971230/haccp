/**
 * MenuController — 메뉴 REST API (/api/v1/menu).
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) GET /list — 로그인 사용자의 권한이 반영된 메뉴 평면 목록을 반환한다
 *   2) 회사코드·권한그룹은 요청 파라미터로 받지 않고 JWT 컨텍스트에서만 읽는다 — 타사 메뉴 조회를 원천 차단
 *   3) 트리 조립은 프론트 SideMenu가 담당한다. 서버는 정렬된 평면 목록만 보낸다
 *
 * PIPELINE[HB33] REST Controller
 * PIPELINE[HB31, HB32] 연관 모듈
 */
package com.haccp.menu;

// 역할 — 요청 스코프 컨텍스트 — coCd·usrgrpCd
import com.haccp.common.context.LoginUserContext;
// 역할 — API 공통 응답 래퍼
import com.haccp.common.response.CommonResponse;
// 역할 — 메뉴 Row DTO
import com.haccp.menu.dto.MenuRow;
// 역할 — @RequiredArgsConstructor 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — GET 매핑
import org.springframework.web.bind.annotation.GetMapping;
// 역할 — 공통 경로 지정
import org.springframework.web.bind.annotation.RequestMapping;
// 역할 — REST 컨트롤러 등록
import org.springframework.web.bind.annotation.RestController;

// 역할 — 메뉴 목록
import java.util.List;

/** 사이드 메뉴 → /api/v1/menu/* */
@RestController
@RequestMapping("/api/v1/menu")
@RequiredArgsConstructor
public class MenuController {

    // 메뉴 조회 SP 호출
    private final MenuMapper menuMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 권한이 반영된 메뉴 평면 목록을 조회해 반환한다
     *   2) 로그인 직후와 새로고침 후 셸이 초기화될 때 호출한다
     *   3) 성공 시 메뉴 목록을 반환하고, 권한이 없으면 빈 목록이다
     */
    @GetMapping("/list")
    public CommonResponse<List<MenuRow>> list() {
        // 테넌트·권한그룹은 JWT에서만 읽는다 — 요청 파라미터를 받으면 타사 메뉴를 볼 수 있게 된다
        return CommonResponse.ok(menuMapper.selectMenus(LoginUserContext.coCd(), LoginUserContext.usrgrpCd()));
    }
}
