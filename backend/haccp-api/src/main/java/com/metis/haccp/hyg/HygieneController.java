/**
 * HygieneController — 위생관리 DB형 양식 5종 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 의미 화면 ID를 URL로 사용하며 frm 코드·요청 coCd를 받지 않는다
 *   2) 목록·상세 GET, 저장 PUT, 삭제 검증·삭제 POST 계약을 양식마다 동일하게 제공한다
 *   3) 삭제 Body는 단건도 [{ docIdx }] 객체 배열이며 HTTP DELETE는 사용하지 않는다
 *
 * PIPELINE[HB87] 위생 Controller
 * PIPELINE[HB86, HB83] 연관 모듈
 */
package com.metis.haccp.hyg;

import com.fasterxml.jackson.databind.JsonNode;
import com.metis.haccp.common.response.CommonResponse;
import com.metis.haccp.hyg.dto.HygieneDeleteItem;
import com.metis.haccp.hyg.dto.HygieneListRow;
import com.metis.haccp.hyg.dto.HygieneSaveRequest;
import jakarta.validation.Valid;
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
@RequestMapping("/api/v1/hyg")
@RequiredArgsConstructor
public class HygieneController {
    private final HygieneService service;

    /** 개발자: 박승우 | 일자: 2026-08-06 | 코멘트: 양식별 기준일 구간 목록을 조회하고, 조회 버튼·초기 로드에서 호출하며, 성공 시 목록 배열을 반환한다. */
    @GetMapping("/{screenCode}/list")
    public CommonResponse<List<HygieneListRow>> list(
            // 의미 화면 ID — daily-hygiene-check 등 5종만 허용
            @PathVariable String screenCode,
            // 기준일 시작 YYYYMMDD — 생략 시 하한 없음
            @RequestParam(required = false) String fromDt,
            // 기준일 종료 YYYYMMDD — 생략 시 상한 없음
            @RequestParam(required = false) String toDt,
            // 문서번호 부분검색
            @RequestParam(required = false) String docNo,
            // 작성자 ID·이름 부분검색
            @RequestParam(required = false) String writer
    ) {
        return CommonResponse.ok(service.list(screenCode, fromDt, toDt, docNo, writer));
    }

    /** 개발자: 박승우 | 일자: 2026-08-06 | 코멘트: 기존 상세 또는 신규 기본행을 반환하고, 신규는 docIdx를 생략하며, 성공 시 header·entries JSON을 반환한다. */
    @GetMapping("/{screenCode}/detail")
    public CommonResponse<JsonNode> detail(
            // 의미 화면 ID
            @PathVariable String screenCode,
            // 문서 idx — 생략/0이면 신규
            @RequestParam(required = false) Long docIdx
    ) {
        return CommonResponse.ok(service.detail(screenCode, docIdx));
    }

    /** 개발자: 박승우 | 일자: 2026-08-06 | 코멘트: 양식 전체 행을 저장하고, 신규는 문서를 생성하며, 성공 시 문서 idx를 반환한다. */
    @PutMapping("/{screenCode}/save")
    public CommonResponse<Map<String, Long>> save(
            // 의미 화면 ID
            @PathVariable String screenCode,
            // 헤더·전체 행 저장 본문
            @Valid @RequestBody HygieneSaveRequest req
    ) {
        return CommonResponse.ok(Map.of("docIdx", service.save(screenCode, req)));
    }

    /** 개발자: 박승우 | 일자: 2026-08-06 | 코멘트: 확인창 전에 삭제 가능 여부만 검사하고, 결재 잠금은 차단하며, 성공 시 반환 자료는 없다. */
    @PostMapping("/{screenCode}/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 의미 화면 ID
            @PathVariable String screenCode,
            // 삭제 키 객체 배열 — UI 단건도 배열
            @RequestBody List<HygieneDeleteItem> keys
    ) {
        service.validateDelete(screenCode, keys);
        return CommonResponse.ok(null);
    }

    /** 개발자: 박승우 | 일자: 2026-08-06 | 코멘트: 재검증 후 양식 하위·문서를 삭제하고, POST 계약을 지키며, 성공 시 반환 자료는 없다. */
    @PostMapping("/{screenCode}/delete")
    public CommonResponse<Void> delete(
            // 의미 화면 ID
            @PathVariable String screenCode,
            // 삭제 키 객체 배열 — UI 단건도 배열
            @RequestBody List<HygieneDeleteItem> keys
    ) {
        service.delete(screenCode, keys);
        return CommonResponse.ok(null);
    }
}
