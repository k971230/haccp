/**
 * HygProcessController — 일반위생관리 및 공정점검표 REST.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 경로 /api/v1/docs/prp/hygiene-process-check. 회사코드는 JWT만
 *   2) 목록·상세 GET, 저장 PUT, 삭제 POST
 *   3) 삭제 Body는 [{ docIdx }]
 *
 * PIPELINE[HB131] 공정점검 Controller
 */
package com.haccp.docs.html.hygprocess;

import com.fasterxml.jackson.databind.JsonNode;
import com.haccp.common.response.CommonResponse;
import com.haccp.docs.html.hygprocess.dto.HygProcessDeleteItem;
import com.haccp.docs.html.hygprocess.dto.HygProcessListRow;
import com.haccp.docs.html.hygprocess.dto.HygProcessSaveRequest;
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
@RequestMapping("/api/v1/docs/prp/hygiene-process-check")
@RequiredArgsConstructor
public class HygProcessController {
    private final HygProcessService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 기준일 구간 목록을 조회한다
     *   2) 조회 버튼이 호출한다
     *   3) 성공 시 목록 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<HygProcessListRow>> list(
            @RequestParam(required = false) String fromDt,
            @RequestParam(required = false) String toDt,
            @RequestParam(required = false) String docNo,
            @RequestParam(required = false) String writer
    ) {
        return CommonResponse.ok(service.list(fromDt, toDt, docNo, writer));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 기존 상세 또는 적용 버전 신규 기본행
     *   2) 신규는 docIdx 생략
     *   3) header·items JSON
     */
    @GetMapping("/detail")
    public CommonResponse<JsonNode> detail(
            @RequestParam(required = false) Long docIdx
    ) {
        return CommonResponse.ok(service.detail(docIdx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 점검표 전체를 저장한다
     *   2) 저장 버튼이 호출한다
     *   3) 성공 시 문서 idx
     */
    @PutMapping("/save")
    public CommonResponse<Map<String, Long>> save(
            @RequestBody HygProcessSaveRequest req
    ) {
        return CommonResponse.ok(Map.of("docIdx", service.save(req)));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) 확인창 전에 호출한다
     *   3) Body [{ docIdx }]
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            @RequestBody List<HygProcessDeleteItem> keys
    ) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 재검증 후 문서를 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) HTTP DELETE 금지
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            @RequestBody List<HygProcessDeleteItem> keys
    ) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }
}
