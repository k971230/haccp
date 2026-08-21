/**
 * RoleMgmtController — 권한그룹 관리 REST API (/api/v1/sys/code/role-management).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 좌측 권한그룹 마스터(/list·/save·/delete)와 우측 화면권한(/screens)을 한 화면 경계에서 제공한다
 *   2) 회사코드는 JWT에서만 읽는다
 *   3) 삭제는 validate-delete → delete 두 단계 POST다 (HTTP DELETE 금지)
 *
 * PIPELINE[HB93] 권한그룹 관리 REST Controller
 */
package com.haccp.sys.code.role;

// 역할 — API 성공 응답 래퍼
import com.haccp.common.response.CommonResponse;
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
import java.util.Map;

/** 권한그룹 관리 화면 → /api/v1/sys/code/role-management/* */
@RestController
@RequestMapping("/api/v1/sys/code/role-management")
@RequiredArgsConstructor
public class RoleMgmtController {

    // 권한그룹·화면권한 업무 로직
    private final RoleMgmtService roleMgmtService;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 권한그룹 목록을 반환한다
     *   2) 화면 진입·조회와 사용자 관리 권한그룹 룩업에서 호출한다
     *   3) 조건에 맞는 그룹이 없으면 빈 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<Map<String, Object>>> list(
            // 권한그룹코드 부분검색어 — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String usrgrpCd,
            // 권한그룹명 부분검색어 — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String usrgrpNm,
            // 사용여부 Y|N — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String useYn
    ) {
        return CommonResponse.ok(roleMgmtService.list(usrgrpCd, usrgrpNm, useYn));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 변경된 권한그룹 행을 저장한다
     *   2) 저장 버튼에서 호출한다
     *   3) 한 행이라도 실패하면 전체 롤백된다
     */
    @PutMapping("/save")
    public CommonResponse<Void> save(
            // 변경 행 목록 — idx가 없으면 신규
            @RequestBody List<Map<String, Object>> rows
    ) {
        roleMgmtService.save(rows);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 삭제 전 사용자 참조 여부를 검사한다
     *   2) 확인 대화상자 직전에 호출한다
     *   3) 차단이면 업무 오류 문구가 그대로 토스트된다
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 대상 복합키 배열 — 단건이어도 [{ idx }]
            @RequestBody List<Map<String, Long>> keys
    ) {
        roleMgmtService.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 검증을 통과한 권한그룹을 삭제한다
     *   2) 사용자가 확인을 누른 뒤 호출한다
     *   3) 그룹의 화면권한 설정도 함께 정리된다
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // 삭제 대상 복합키 배열 — 단건이어도 [{ idx }]
            @RequestBody List<Map<String, Long>> keys
    ) {
        roleMgmtService.delete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 권한그룹별 화면 권한 목록을 반환한다
     *   2) 우측 권한 트리를 그릴 때 호출한다
     *   3) usrgrpCd 필수, 미설정 화면도 N으로 내려온다
     */
    @GetMapping("/screens")
    public CommonResponse<List<Map<String, Object>>> screens(
            // 좌측에서 고른 권한그룹코드 — 필수
            @RequestParam String usrgrpCd
    ) {
        return CommonResponse.ok(roleMgmtService.listScreens(usrgrpCd));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 화면 조회권한(readYn) 변경을 저장한다
     *   2) 권한 트리 체크 후 저장 버튼에서 호출한다
     *   3) body: { usrgrpCd, rows: [{ scrnCd, readYn }] }
     */
    @PutMapping("/screens")
    public CommonResponse<Void> saveScreens(
            // 요청 본문 — usrgrpCd(문자열) + rows(화면권한 배열)
            @RequestBody Map<String, Object> body
    ) {
        Object grp = body == null ? null : body.get("usrgrpCd");
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> rows =
                body == null ? null : (List<Map<String, Object>>) body.get("rows");
        roleMgmtService.saveScreens(grp == null ? "" : String.valueOf(grp), rows);
        return CommonResponse.ok(null);
    }
}
