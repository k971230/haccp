/**
 * CcpFormsController — CCP 금속검출·검증점검표·연간 검증계획서 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 세 화면의 URL을 한 컨트롤러에서 받고 Service가 화면별 템플릿을 고정한다
 *   2) 목록·상세 GET, 저장 PUT, 삭제 검증·삭제 POST 규약을 동일하게 적용한다
 *   3) 삭제 본문은 항상 [{ docIdx }] 객체 배열이며 HTTP DELETE는 사용하지 않는다
 *
 * PIPELINE[HB90] CCP 추가 양식 Controller
 * PIPELINE[HB89, HF84] 연관 모듈
 */
package com.metis.haccp.ccp;

import com.metis.haccp.common.response.CommonResponse;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/ccp")
@RequiredArgsConstructor
public class CcpFormsController {
    private final CcpFormsService service;

    @GetMapping("/{form}/list")
    public CommonResponse<List<Map<String, Object>>> list(
            @PathVariable String form,
            @RequestParam(required = false) String fromDt,
            @RequestParam(required = false) String toDt,
            @RequestParam(required = false) String docNo,
            @RequestParam(required = false) String writer
    ) {
        return CommonResponse.ok(service.list(form, fromDt, toDt, docNo, writer));
    }
    @GetMapping("/{form}/detail")
    public CommonResponse<Map<String, Object>> detail(@PathVariable String form, @RequestParam(required = false) Long docIdx) {
        return CommonResponse.ok(service.detail(form, docIdx));
    }
    @PutMapping("/{form}/save")
    public CommonResponse<Map<String, Long>> save(@PathVariable String form, @RequestBody Map<String, Object> request) {
        return CommonResponse.ok(Map.of("docIdx", service.save(form, request)));
    }
    @PostMapping("/{form}/validate-delete")
    public CommonResponse<Void> validateDelete(@PathVariable String form, @RequestBody List<Map<String, Long>> keys) {
        service.validateDelete(form, keys);
        return CommonResponse.ok(null);
    }
    @PostMapping("/{form}/delete")
    public CommonResponse<Void> delete(@PathVariable String form, @RequestBody List<Map<String, Long>> keys) {
        service.delete(form, keys);
        return CommonResponse.ok(null);
    }
}
