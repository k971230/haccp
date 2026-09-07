/**
 * UserController — 사용자관리 화면 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 목록·저장·삭제만 맡는다. 서명 /api/v1/sys/users/* 는 UserSignController 로 나눴다
 *   2) 회사코드는 JWT에서만 읽는다
 *   3) 삭제는 validate-delete → delete 두 단계 POST이고 서명 삭제도 POST다 (HTTP DELETE 금지)
 *
 * PIPELINE[HB93] 사용자 관리 REST Controller
 */
package com.haccp.sys.code.user;

// 역할 — API 성공 응답 래퍼
import com.haccp.common.response.CommonResponse;
import com.haccp.sys.code.user.dto.UserDeleteItem;
import com.haccp.sys.code.user.dto.UserRow;
import com.haccp.sys.code.user.dto.UserSaveRow;
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

/** 사용자관리 → /api/v1/sys/code/user-management/* — 형제 5화면과 같은 형태로 base 에 화면 경로를 둔다 */
@RestController
@RequestMapping("/api/v1/sys/code/user-management")
@RequiredArgsConstructor
public class UserController {

    // 사용자·서명 업무 로직
    private final UserService userService;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 사용자 목록을 반환한다
     *   2) 화면 진입·조회와 로그인 이력 화면의 사용자 트리에서 호출한다
     *   3) 조건에 맞는 사용자가 없으면 빈 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<UserRow>> list(
            // 아이디 부분검색어 — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String userId,
            // 이름 부분검색어 — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String userNm,
            // 좌측 부서 트리 선택값 — 미입력이면 전체 부서
            @RequestParam(required = false, defaultValue = "") String deptCd,
            // 사용여부 Y|N — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String useYn
    ) {
        return CommonResponse.ok(userService.list(userId, userNm, deptCd, useYn));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 변경된 사용자 행을 저장한다
     *   2) 저장 버튼에서 호출한다
     *   3) 비밀번호는 서버가 BCrypt로 해시한 뒤에만 DB로 간다
     */
    @PutMapping("/save")
    public CommonResponse<Void> save(
            // 변경 행 목록 — idx가 없으면 신규
            @RequestBody List<UserSaveRow> rows
    ) {
        userService.save(rows);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 삭제 전 참조 차단 여부를 검사한다
     *   2) 확인 대화상자 직전에 호출한다
     *   3) 사용자는 차단 사유가 없어 키 형식만 검증된다
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 대상 복합키 배열 — 단건이어도 [{ idx }]
            @RequestBody List<UserDeleteItem> keys
    ) {
        userService.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 검증을 통과한 사용자를 삭제한다
     *   2) 사용자가 확인을 누른 뒤 호출한다
     *   3) 개인 설정은 함께 지워지고 작성 문서는 남는다
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // 삭제 대상 복합키 배열 — 단건이어도 [{ idx }]
            @RequestBody List<UserDeleteItem> keys
    ) {
        userService.delete(keys);
        return CommonResponse.ok(null);
    }
}
