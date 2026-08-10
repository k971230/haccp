/**
 * CodeController — 공통코드 REST API (/api/v1/code).
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) GET /list — 대분류(mainCd) 기준 공통코드 목록을 반환한다. 콤보 상자의 유일한 공급원이다
 *   2) 회사코드는 JWT에서만 읽는다 — 요청 파라미터로 받으면 타사 코드를 조회할 수 있게 된다
 *   3) 사용여부 기본값은 'Y'다. 코드 관리 화면처럼 사용중지 코드까지 봐야 할 때만 빈 값으로 호출한다
 *
 * PIPELINE[HB37] REST Controller
 * PIPELINE[HB35, HB36] 연관 모듈
 */
package com.metis.haccp.code;

// 역할 — 공통코드 Row DTO
import com.metis.haccp.code.dto.CodeRow;
// 역할 — 요청 스코프 컨텍스트 — coCd
import com.metis.haccp.common.context.LoginUserContext;
// 역할 — API 공통 응답 래퍼
import com.metis.haccp.common.response.CommonResponse;
// 역할 — @RequiredArgsConstructor 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — REST 매핑 어노테이션
import org.springframework.web.bind.annotation.*;

// 역할 — 코드 목록
import java.util.List;

/** 공통코드 조회 → /api/v1/code/* */
@RestController
@RequestMapping("/api/v1/code")
@RequiredArgsConstructor
public class CodeController {

    // 공통코드 조회 SP 호출
    private final CodeMapper codeMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 대분류 기준 공통코드 목록을 조회해 반환한다
     *   2) 화면 진입 시 콤보를 채우거나 코드 관리 화면이 목록을 조회할 때 호출한다
     *   3) 성공 시 병합된 코드 목록을 반환하고, 해당 대분류가 없으면 빈 목록이다
     */
    @GetMapping("/list")
    public CommonResponse<List<CodeRow>> list(
            // 대분류 코드 — 콤보 그룹 식별자(예: DOC_STAT). SP가 부분 일치로 비교하므로
            // 빈 문자열을 넘기면 전체 그룹이 나온다. 콤보 용도에서는 정확한 대분류를 넘긴다
            @RequestParam String mainCd,
            // 사용여부 필터 — 기본 'Y'(사용중만). 빈 문자열을 넘기면 사용중지 코드까지 포함한다
            // 콤보에는 기본값을 쓰고, 코드 관리 화면에서만 빈 값으로 호출한다
            @RequestParam(required = false, defaultValue = "Y") String useYn
    ) {
        return CommonResponse.ok(codeMapper.selectCodes(LoginUserContext.coCd(), mainCd, useYn));
    }
}
