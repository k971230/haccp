/**
 * CcpMtlDraftController — CCP 금속검출(CCP-3P) 모니터링일지 작성 REST.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 경로 /api/v1/draft/ccp-monitoring/ccp-mtl — FE SCREEN_PATH 와 같은 칸. 회사코드는 JWT 만
 *   2) 감도표(작업 전·작업 후)와 통과량표 2개를 한 문서로 저장한다
 *   3) 전송·전송취소는 이 컨트롤러가 아니라 문서 허브 /api/v1/docs/documents/approval 을 쓴다
 *
 * 삭제는 SP 가 양식코드로 문서를 찾으므로 tmplCd 를 함께 받는다.
 *
 * PIPELINE[HB143] CCP 금속검출 작성 Controller
 */
package com.haccp.draft.ccpmonitoring;

import com.fasterxml.jackson.databind.JsonNode;
import com.haccp.common.response.CommonResponse;
import com.haccp.draft.ccpmonitoring.dto.CcpLogDraftDeleteItem;
import com.haccp.draft.ccpmonitoring.dto.CcpLogDraftFormRow;
import com.haccp.draft.ccpmonitoring.dto.CcpLogDraftListRow;
import com.haccp.draft.ccpmonitoring.dto.CcpLogDraftSaveRequest;
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
@RequestMapping("/api/v1/draft/ccp-monitoring/ccp-mtl")
@RequiredArgsConstructor
public class CcpMtlDraftController {
    private final CcpMtlDraftService service;

    /** 작성 가능 양식 — 양식관리 사용여부 예 */
    @GetMapping("/forms")
    public CommonResponse<List<CcpLogDraftFormRow>> forms() {
        return CommonResponse.ok(service.forms());
    }

    /** 좌측 작성 목록 — 일자 구간·양식코드·양식명·작성자ID·작성자명 */
    @GetMapping("/list")
    public CommonResponse<List<CcpLogDraftListRow>> list(
            @RequestParam(required = false) String tmplCd,
            @RequestParam(required = false) String tmplNm,
            @RequestParam(required = false) String fromDt,
            @RequestParam(required = false) String toDt,
            @RequestParam(required = false) String writerId,
            @RequestParam(required = false) String writerNm
    ) {
        return CommonResponse.ok(service.list(tmplCd, tmplNm, fromDt, toDt, writerId, writerNm));
    }

    /** 상세 또는 신규 기본행 — header·items·logRows(감도)·passRows(통과량)·corrective */
    @GetMapping("/detail")
    public CommonResponse<JsonNode> detail(
            @RequestParam String tmplCd,
            @RequestParam(required = false) Long docIdx
    ) {
        return CommonResponse.ok(service.detail(tmplCd, docIdx));
    }

    /** 저장 — 전송하지 않는다. 전송대기를 유지한다 */
    @PutMapping("/save")
    public CommonResponse<Map<String, Long>> save(@RequestBody CcpLogDraftSaveRequest req) {
        return CommonResponse.ok(Map.of("docIdx", service.save(req)));
    }

    /** 삭제 검증 — 확인창 전. Body [{ docIdx }] */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(@RequestBody List<CcpLogDraftDeleteItem> keys) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /** 삭제 — HTTP DELETE 금지, POST 만 쓴다. SP 가 양식코드로 문서를 찾는다 */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // tmplCd: 삭제 대상 양식코드
            @RequestParam String tmplCd,
            @RequestBody List<CcpLogDraftDeleteItem> keys
    ) {
        service.delete(keys, tmplCd);
        return CommonResponse.ok(null);
    }
}
