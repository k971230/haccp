/**
 * MenuMgmtController — 메뉴 관리 REST API (/api/v1/sys/code/menu-management).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 화면코드를 경로에 고정해 임의 화면코드로 다른 SP를 부르는 경로를 없앤다
 *   2) 회사코드는 JWT에서만 읽는다
 *   3) 삭제는 validate-delete → delete 두 단계 POST다 (HTTP DELETE 금지)
 *
 * PIPELINE[HB93] 메뉴 관리 REST Controller
 */
package com.haccp.sys.code.menu;

// 역할 — API 성공 응답 래퍼
import com.haccp.common.response.CommonResponse;
import com.haccp.sys.code.menu.dto.MenuDeleteItem;
import com.haccp.sys.code.menu.dto.MenuMgmtRow;
import com.haccp.sys.code.menu.dto.MenuSaveRow;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — REST 매핑
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

// 역할 — 화면 행·삭제키 목록
import java.util.List;

/** 메뉴 관리 화면 → /api/v1/sys/code/menu-management/* */
@RestController
@RequestMapping("/api/v1/sys/code/menu-management")
@RequiredArgsConstructor
public class MenuMgmtController {

    // 메뉴 관리 조회·저장·삭제 업무 로직
    private final MenuMgmtService menuMgmtService;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 관리용 메뉴 전체 목록을 반환한다
     *   2) 화면 진입·조회와 권한 관리 트리 조립에서 호출한다
     *   3) 좌측 트리가 전체 집합을 요구하므로 화면은 검색어 없이 부르고 결과를 화면에서 다시 거른다
     */
    @GetMapping("/list")
    public CommonResponse<List<MenuMgmtRow>> list(
            // 메뉴코드 부분검색어 — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String menuCd,
            // 메뉴명 부분검색어 — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String menuNm,
            // 사용여부 Y|N — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String useYn
    ) {
        return CommonResponse.ok(menuMgmtService.list(menuCd, menuNm, useYn));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 변경된 메뉴 행을 저장한다
     *   2) 저장 버튼에서 호출한다
     *   3) 사용여부를 N으로 내리면 하위 메뉴까지 함께 N이 된다
     */
    @PutMapping("/save")
    public CommonResponse<Void> save(
            // 변경 행 목록 — 화면에서 행추가는 막혀 있어 대부분 수정이다
            @RequestBody List<MenuSaveRow> rows
    ) {
        menuMgmtService.save(rows);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 삭제 전 하위 메뉴 참조 여부를 검사한다
     *   2) 확인 대화상자 직전에 호출한다
     *   3) 차단이면 업무 오류 문구가 그대로 토스트된다
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 대상 복합키 배열 — 단건이어도 [{ idx }]
            @RequestBody List<MenuDeleteItem> keys
    ) {
        menuMgmtService.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 검증을 통과한 메뉴를 삭제한다
     *   2) 사용자가 확인을 누른 뒤 호출한다
     *   3) 삭제 직전 참조 검사를 한 번 더 수행한다
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // 삭제 대상 복합키 배열 — 단건이어도 [{ idx }]
            @RequestBody List<MenuDeleteItem> keys
    ) {
        menuMgmtService.delete(keys);
        return CommonResponse.ok(null);
    }
}
