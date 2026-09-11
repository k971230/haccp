/**
 * CompanyController — 테넌트 통째 삭제 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-09-11
 * 코멘트:
 *   1) 화면이 없다. 경로를 화면에 묶지 않고 화이트리스트 + 서비스 권한으로 연다
 *   2) 회사코드 대상은 본문 배열, 호출자는 JWT 만
 *   3) 삭제는 validate-delete → delete 두 단계 POST 다 (HTTP DELETE 금지)
 *
 * PIPELINE[HB146] 업체 삭제 REST Controller
 */
package com.haccp.sys.company;

// 역할 — API 성공 응답 래퍼
import com.haccp.common.response.CommonResponse;
import com.haccp.sys.company.dto.CompanyDeleteItem;
// 역할 — 삭제 키 목록
import java.util.List;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — REST 매핑
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 테넌트 삭제 — /api/v1/sys/company/* */
@RestController
@RequestMapping("/api/v1/sys/company")
@RequiredArgsConstructor
public class CompanyController {

    private final CompanyService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-09-11
     * 코멘트:
     *   1) 테넌트 삭제 가능 여부만 검사하고 자료는 변경하지 않는다
     *   2) 호출 전에 확인창을 열 때 쓴다
     *   3) 플랫폼·자기 회사·권한 밖이면 400, 통과하면 void
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 키 객체 배열 — 단건도 [{ coCd }]
            @RequestBody List<CompanyDeleteItem> keys
    ) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-11
     * 코멘트:
     *   1) validate-delete 와 같은 검사를 다시 한 뒤 테넌트 트리를 지운다
     *   2) 운영에서 업체를 거둘 때 호출한다
     *   3) HTTP DELETE 를 쓰지 않는다 — 성공 시 void
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // 삭제 키 객체 배열 — 단건도 [{ coCd }]
            @RequestBody List<CompanyDeleteItem> keys
    ) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }
}
