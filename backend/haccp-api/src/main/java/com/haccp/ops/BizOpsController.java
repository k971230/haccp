/**
 * BizOpsController — 시설·재고·공정 DB형 양식 6종 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 각 양식은 역할 기반 URL을 독립적으로 제공하고 공통 계약만 Service에서 재사용한다
 *   2) 목록 GET, 상세 GET, 저장 PUT, 삭제검증·삭제 POST로 HTTP DELETE를 쓰지 않는다
 *   3) URL과 템플릿 코드의 대응은 서버 고정값이라 요청 본문으로 양식을 바꿀 수 없다
 *
 * PIPELINE[HB91] 시설·재고·공정 REST Controller
 * PIPELINE[HB88, HB90] 연관 모듈
 */
package com.haccp.ops;

import com.haccp.common.response.CommonResponse;
import com.haccp.ops.dto.BizOpsDeleteItem;
import com.haccp.ops.dto.BizOpsSaveRequest;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping({
        "/api/v1/fac/facility-equipment-check",
        "/api/v1/fac/calibration-target-management",
        "/api/v1/fac/waste-disposal-check",
        "/api/v1/inv/inventory-check",
        "/api/v1/inv/receiving-inspection",
        "/api/v1/prc/process-control-check"
})
@RequiredArgsConstructor
public class BizOpsController {
    private final BizOpsService service;

    /** 기준일 구간의 양식 문서 목록을 반환한다. */
    @GetMapping("/list")
    public CommonResponse<List<Map<String, Object>>> list(
            HttpServletRequest request,
            // 기준일 시작 YYYYMMDD
            @RequestParam(required = false) String fromDt,
            // 기준일 종료 YYYYMMDD
            @RequestParam(required = false) String toDt,
            // 문서번호 부분검색
            @RequestParam(required = false) String docNo,
            // 작성자 ID·이름 부분검색
            @RequestParam(required = false) String writer
    ) {
        return CommonResponse.ok(service.list(templateCode(request), fromDt, toDt, docNo, writer));
    }

    /** 기존 문서 상세 또는 신규 양식 기본행을 반환한다. */
    @GetMapping("/detail")
    public CommonResponse<Map<String, Object>> detail(
            HttpServletRequest request,
            @RequestParam(required = false) Long docIdx
    ) {
        return CommonResponse.ok(service.detail(templateCode(request), docIdx));
    }

    /** 양식의 헤더·행 전체를 저장하고 문서 idx를 반환한다. */
    @PutMapping("/save")
    public CommonResponse<Map<String, Long>> save(
            HttpServletRequest request,
            @Valid @RequestBody BizOpsSaveRequest req
    ) {
        return CommonResponse.ok(Map.of("docIdx", service.save(templateCode(request), req)));
    }

    /** 삭제 확인창 전에 양식 문서의 삭제 가능 여부를 검사한다. */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            HttpServletRequest request,
            @RequestBody List<BizOpsDeleteItem> keys
    ) {
        service.validateDelete(templateCode(request), keys);
        return CommonResponse.ok(null);
    }

    /** 임시·반려 문서만 삭제한다. Service와 SP가 결재 잠금을 이중으로 검사한다. */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            HttpServletRequest request,
            @RequestBody List<BizOpsDeleteItem> keys
    ) {
        service.delete(templateCode(request), keys);
        return CommonResponse.ok(null);
    }

    /** URL의 역할 기반 식별자를 DB templateCode로 고정 변환한다. */
    private static String templateCode(HttpServletRequest request) {
        String uri = request.getRequestURI();
        if (uri.contains("facility-equipment-check")) return "tmpl_prp-facility-check";
        if (uri.contains("calibration-target-management")) return "tmpl_prp-calib-target";
        if (uri.contains("waste-disposal-check")) return "tmpl_prp-waste-check";
        if (uri.contains("inventory-check")) return "tmpl_logis-inventory-check";
        if (uri.contains("receiving-inspection")) return "tmpl_logis-receive-inspect";
        if (uri.contains("process-control-check")) return "tmpl_ccp-process-check";
        throw new IllegalArgumentException("지원하지 않는 양식 경로입니다.");
    }
}
