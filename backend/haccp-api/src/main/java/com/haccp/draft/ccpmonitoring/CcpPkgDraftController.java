/**
 * CcpPkgDraftController — CCP 포장(CCP-1B) 모니터링일지 작성 REST.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 경로 /api/v1/draft/ccp-monitoring/ccp-pkg — FE SCREEN_PATH 와 같은 칸. 회사코드는 JWT 만
 *   2) 업무는 CcpLogDraftService 가 갖고 여기는 양식군(PKG)만 고정한다. 가열(HTG)과 같은 서비스다
 *   3) 전송·전송취소는 이 컨트롤러가 아니라 문서 허브 /api/v1/docs/documents/approval 을 쓴다
 *
 * PIPELINE[HB141] CCP 포장 작성 Controller
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
@RequestMapping("/api/v1/draft/ccp-monitoring/ccp-pkg")
@RequiredArgsConstructor
public class CcpPkgDraftController {
    /** 이 화면이 다루는 양식군 — 포장 */
    private static final CcpLogDraftService.Family FAMILY = CcpLogDraftService.Family.PKG;

    private final CcpLogDraftService service;

    /** 작성 가능 양식 — 양식관리 사용여부 예 */
    @GetMapping("/forms")
    public CommonResponse<List<CcpLogDraftFormRow>> forms() {
        return CommonResponse.ok(service.forms(FAMILY));
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
        return CommonResponse.ok(service.list(FAMILY, tmplCd, tmplNm, fromDt, toDt, writerId, writerNm));
    }

    /** 상세 또는 신규 기본행 — header·items·logRows·passRows·corrective */
    @GetMapping("/detail")
    public CommonResponse<JsonNode> detail(
            @RequestParam String tmplCd,
            @RequestParam(required = false) Long docIdx
    ) {
        return CommonResponse.ok(service.detail(FAMILY, tmplCd, docIdx));
    }

    /** 저장 — 전송하지 않는다. 전송대기를 유지한다 */
    @PutMapping("/save")
    public CommonResponse<Map<String, Long>> save(@RequestBody CcpLogDraftSaveRequest req) {
        return CommonResponse.ok(Map.of("docIdx", service.save(FAMILY, req)));
    }

    /** 삭제 검증 — 확인창 전. Body [{ docIdx }] */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(@RequestBody List<CcpLogDraftDeleteItem> keys) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /** 삭제 — HTTP DELETE 금지, POST 만 쓴다 */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(@RequestBody List<CcpLogDraftDeleteItem> keys) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }
}
