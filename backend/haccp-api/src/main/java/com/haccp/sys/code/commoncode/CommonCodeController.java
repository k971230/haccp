/**
 * CommonCodeController — 공통코드 관리 REST API (/api/v1/sys/code/common-code-management).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 화면코드를 경로에 고정해 임의 화면코드로 다른 SP를 부르는 경로를 없앤다
 *   2) 회사코드는 JWT에서만 읽는다 — 요청 파라미터로 받으면 타사 코드가 열린다
 *   3) 삭제는 OPS_DELETE 표준대로 validate-delete → delete 두 단계 POST다 (HTTP DELETE 금지)
 *
 * PIPELINE[HB93] 공통코드 REST Controller
 */
package com.haccp.sys.code.commoncode;

// 역할 — API 성공 응답 래퍼
import com.haccp.common.response.CommonResponse;
// 역할 — 저장 행·삭제 키 DTO
import com.haccp.sys.code.commoncode.dto.CommonCodeDeleteItem;
import com.haccp.sys.code.commoncode.dto.CommonCodeDetailRow;
import com.haccp.sys.code.commoncode.dto.CommonCodeGroupRow;
import com.haccp.sys.code.commoncode.dto.CommonCodeSaveRow;
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

/** 공통코드 관리 화면 → /api/v1/sys/code/common-code-management/* */
@RestController
@RequestMapping("/api/v1/sys/code/common-code-management")
@RequiredArgsConstructor
public class CommonCodeController {

    // 공통코드 조회·저장·삭제 업무 로직
    private final CommonCodeService commonCodeService;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 대분류(좌측 그리드) 목록을 반환한다
     *   2) 화면 진입과 조회 버튼에서 호출한다
     *   3) 조건에 맞는 대분류가 없으면 빈 배열
     */
    @GetMapping("/groups")
    public CommonResponse<List<CommonCodeGroupRow>> groups(
            // 대분류코드 부분검색어 — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String mainCd,
            // 대분류명 부분검색어 — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String codeNm
    ) {
        return CommonResponse.ok(commonCodeService.listGroups(mainCd, codeNm));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 선택 대분류의 세부코드 목록을 반환한다
     *   2) 대분류 행을 고를 때 시스템·사용자 그리드가 각각 호출한다
     *   3) 대분류가 비면 업무 오류
     */
    @GetMapping("/details")
    public CommonResponse<List<CommonCodeDetailRow>> details(
            // 좌측에서 고른 대분류코드 — 필수
            @RequestParam String mainCd,
            // 시스템/사용자 구분 Y|N|sys|usr — 미입력이면 둘 다
            @RequestParam(required = false, defaultValue = "") String sysYn
    ) {
        return CommonResponse.ok(commonCodeService.listDetails(mainCd, sysYn));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 변경된 세부코드 행을 저장한다
     *   2) 저장 버튼에서 호출한다
     *   3) 한 행이라도 실패하면 전체 롤백된다
     */
    @PutMapping("/save")
    public CommonResponse<Void> save(
            // 변경 행 목록 — idx가 없으면 신규
            @RequestBody List<CommonCodeSaveRow> rows
    ) {
        commonCodeService.save(rows);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 삭제 전 참조 차단 여부를 검사한다
     *   2) 삭제 확인 대화상자를 띄우기 직전에 호출한다
     *   3) 차단이면 업무 오류 문구가 그대로 토스트된다
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 대상 복합키 배열 — 단건이어도 [{ idx }]
            @RequestBody List<CommonCodeDeleteItem> keys
    ) {
        commonCodeService.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 검증을 통과한 세부코드를 삭제한다
     *   2) 사용자가 확인을 누른 뒤 호출한다
     *   3) 삭제 직전 참조 검사를 한 번 더 수행한다
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // 삭제 대상 복합키 배열 — 단건이어도 [{ idx }]
            @RequestBody List<CommonCodeDeleteItem> keys
    ) {
        commonCodeService.delete(keys);
        return CommonResponse.ok(null);
    }
}
