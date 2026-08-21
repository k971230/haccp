/**
 * CcpGenericController — 가열·세척 등 공통 CCP 모니터링 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) /api/v1/docs/ccp/{scrnCd} 가열·살균·여과 3경로에서 템플릿·상세·저장·삭제를 제공한다
 *   2) 수기·자동 기준일지는 템플릿 매핑으로 선택하되 설비 실연동은 이 API 범위에 넣지 않는다
 *   3) 회사·사용자 값은 요청 본문이 아닌 JWT Service 계층에서만 결정한다
 *
 * PIPELINE[HB98] 공통 CCP REST Controller
 * PIPELINE[HB97, HB95, HF94] 연관 모듈
 */
package com.haccp.docs.ccp;

// 역할 — 공통 CCP 저장·삭제 DTO·응답
import com.haccp.docs.ccp.dto.GenericMonitorDeleteItem;
import com.haccp.docs.ccp.dto.GenericMonitorSaveRequest;
import com.haccp.common.response.CommonResponse;
// 역할 — 컬렉션
import java.util.List;
import java.util.Map;
// 역할 — 생성자 DI·REST 매핑
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping({
        "/api/v1/docs/ccp/ccp-heat-monitor",
        "/api/v1/docs/ccp/ccp-sanitize-monitor",
        "/api/v1/docs/ccp/ccp-filter-monitor"
})
@RequiredArgsConstructor
public class CcpGenericController {
    private final CcpGenericService service;

    /** 공통 CCP 작성 화면의 템플릿·기준일지·한계문구 후보를 조회한다. */
    @GetMapping("/templates")
    public CommonResponse<List<Map<String, Object>>> templates() {
        return CommonResponse.ok(service.templates());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서 idx로 헤더·측정행을 조회한다
     *   2) 목록 선택 시 호출한다
     *   3) 없거나 타사 문서면 업무 오류
     */
    @GetMapping("/{docIdx}")
    public CommonResponse<Map<String, Object>> detail(
            // 조회 문서 idx
            @PathVariable Long docIdx
    ) {
        return CommonResponse.ok(service.detail(docIdx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 선택 공정의 공통 CCP 측정행을 저장한다
     *   2) 신규일 때 docIdx가 없고 수정일 때 기존 docIdx를 전달한다
     *   3) 성공 시 문서 idx를 반환하며 행이 없거나 양식이 없으면 업무 오류를 반환한다
     */
    @PutMapping("/save")
    public CommonResponse<Map<String, Long>> save(@RequestBody GenericMonitorSaveRequest req) {
        return CommonResponse.ok(Map.of("docIdx", service.save(req)));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) FE confirm 전에 호출한다
     *   3) 통과 시 void
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(@RequestBody List<GenericMonitorDeleteItem> keys) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 임시·반려 공통 CCP 문서를 삭제한다
     *   2) validate-delete 후 호출한다
     *   3) 성공 시 void
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(@RequestBody List<GenericMonitorDeleteItem> keys) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }
}
