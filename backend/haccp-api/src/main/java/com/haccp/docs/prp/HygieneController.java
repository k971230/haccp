/**
 * HygieneController — 위생관리 DB형 양식(일일·방충) REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 화면 SCREEN_PATH 두 경로를 URL로 사용하며 frm 코드·요청 coCd를 받지 않는다
 *   2) 목록·상세 GET, 저장 PUT, 삭제 검증·삭제 POST 계약을 양식마다 동일하게 제공한다
 *   3) 삭제 Body는 단건도 [{ docIdx }] 객체 배열이며 HTTP DELETE는 사용하지 않는다
 *
 * PIPELINE[HB87] 위생 Controller
 * PIPELINE[HB86, HB83] 연관 모듈
 */
package com.haccp.docs.prp;

import com.fasterxml.jackson.databind.JsonNode;
import com.haccp.common.exception.BizException;
import com.haccp.common.response.CommonResponse;
import com.haccp.docs.prp.dto.HygieneDeleteItem;
import com.haccp.docs.prp.dto.HygieneListRow;
import com.haccp.docs.prp.dto.HygieneSaveRequest;
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
        "/api/v1/docs/prp/daily-hygiene-check",
        "/api/v1/docs/prp/pest-control-check"
})
@RequiredArgsConstructor
public class HygieneController {
    private final HygieneService service;

    /** 개발자: 박승우 | 일자: 2026-08-21 | 코멘트: 양식별 기준일 구간 목록을 조회하고, 조회 버튼·초기 로드에서 호출하며, 성공 시 목록 배열을 반환한다. */
    @GetMapping("/list")
    public CommonResponse<List<HygieneListRow>> list(
            HttpServletRequest request,
            // 기준일 시작 YYYYMMDD — 생략 시 하한 없음
            @RequestParam(required = false) String fromDt,
            // 기준일 종료 YYYYMMDD — 생략 시 상한 없음
            @RequestParam(required = false) String toDt,
            // 문서번호 부분검색
            @RequestParam(required = false) String docNo,
            // 작성자 ID·이름 부분검색
            @RequestParam(required = false) String writer
    ) {
        return CommonResponse.ok(service.list(screenCode(request), fromDt, toDt, docNo, writer));
    }

    /** 개발자: 박승우 | 일자: 2026-08-21 | 코멘트: 기존 상세 또는 신규 기본행을 반환하고, 신규는 docIdx를 생략하며, 성공 시 header·entries JSON을 반환한다. */
    @GetMapping("/detail")
    public CommonResponse<JsonNode> detail(
            HttpServletRequest request,
            // 문서 idx — 생략/0이면 신규
            @RequestParam(required = false) Long docIdx
    ) {
        return CommonResponse.ok(service.detail(screenCode(request), docIdx));
    }

    /** 개발자: 박승우 | 일자: 2026-08-21 | 코멘트: 양식 전체 행을 저장하고, 신규는 문서를 생성하며, 성공 시 문서 idx를 반환한다. */
    @PutMapping("/save")
    public CommonResponse<Map<String, Long>> save(
            HttpServletRequest request,
            // 헤더·전체 행 저장 본문
            @Valid @RequestBody HygieneSaveRequest req
    ) {
        return CommonResponse.ok(Map.of("docIdx", service.save(screenCode(request), req)));
    }

    /** 개발자: 박승우 | 일자: 2026-08-21 | 코멘트: 확인창 전에 삭제 가능 여부만 검사하고, 결재 잠금은 차단하며, 성공 시 반환 자료는 없다. */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            HttpServletRequest request,
            // 삭제 키 객체 배열 — UI 단건도 배열
            @RequestBody List<HygieneDeleteItem> keys
    ) {
        service.validateDelete(screenCode(request), keys);
        return CommonResponse.ok(null);
    }

    /** 개발자: 박승우 | 일자: 2026-08-21 | 코멘트: 재검증 후 양식 하위·문서를 삭제하고, POST 계약을 지키며, 성공 시 반환 자료는 없다. */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            HttpServletRequest request,
            // 삭제 키 객체 배열 — UI 단건도 배열
            @RequestBody List<HygieneDeleteItem> keys
    ) {
        service.delete(screenCode(request), keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-21
     * 코멘트:
     *   1) URL에서 일일·방충 화면코드를 고른다
     *   2) 목록·저장·삭제에서 호출한다
     *   3) 허용 경로가 아니면 업무 오류
     */
    private static String screenCode(
            // 현재 요청 — URI에 daily-hygiene-check 또는 pest-control-check
            HttpServletRequest request
    ) {
        String uri = request.getRequestURI();
        if (uri.contains("daily-hygiene-check")) return "daily-hygiene-check";
        if (uri.contains("pest-control-check")) return "pest-control-check";
        throw new BizException("지원하지 않는 양식 경로입니다.");
    }
}
