/**
 * CcpVerifyDraftController — CCP 검증점검 양식 작성 REST.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 경로 /api/v1/draft/ccp-chk/ccp-verify — FE SCREEN_PATH 와 같은 칸. 회사코드는 JWT 만
 *   2) 양식·목록·상세 GET, 저장 PUT, 삭제 POST 2단계 — HYG(hyg-process)와 같은 계약이다
 *   3) 전송·전송취소는 이 컨트롤러가 아니라 문서 허브 /api/v1/docs/documents/approval 을 쓴다
 *
 * 중분류 슬러그는 ccp-chk 다(docs 아래 ccp 와 tbl_menu menu_cd 가 겹칠 수 없다).
 * 자바 패키지는 하이픈을 쓸 수 없어 com.haccp.draft.ccp 로 둔다.
 *
 * PIPELINE[HB138] CCP 검증점검 작성 Controller
 */
package com.haccp.draft.ccp;

import com.fasterxml.jackson.databind.JsonNode;
import com.haccp.common.response.CommonResponse;
import com.haccp.draft.ccp.dto.CcpVerifyDraftDeleteItem;
import com.haccp.draft.ccp.dto.CcpVerifyDraftFormRow;
import com.haccp.draft.ccp.dto.CcpVerifyDraftListRow;
import com.haccp.draft.ccp.dto.CcpVerifyDraftSaveRequest;
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
@RequestMapping("/api/v1/draft/ccp-chk/ccp-verify")
@RequiredArgsConstructor
public class CcpVerifyDraftController {
    private final CcpVerifyDraftService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 작성에 쓸 수 있는 자사 양식(사용여부 예)만 조회한다
     *   2) 화면 진입 시 한 번 호출한다
     *   3) 성공 시 양식 배열. 없으면 빈 배열
     */
    @GetMapping("/forms")
    public CommonResponse<List<CcpVerifyDraftFormRow>> forms() {
        return CommonResponse.ok(service.forms());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 일자 구간·양식코드·양식명·작성자ID·작성자명으로 작성 목록을 조회한다
     *   2) 조회 버튼이 호출한다
     *   3) 성공 시 목록 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<CcpVerifyDraftListRow>> list(
            // tmplCd: 양식코드 부분검색. 없으면 자사 양식 전체
            @RequestParam(required = false) String tmplCd,
            // tmplNm: 양식명 부분검색
            @RequestParam(required = false) String tmplNm,
            // fromDt: 일자 시작 YYYYMMDD
            @RequestParam(required = false) String fromDt,
            // toDt: 일자 종료 YYYYMMDD
            @RequestParam(required = false) String toDt,
            // writerId: 작성자 ID 부분검색
            @RequestParam(required = false) String writerId,
            // writerNm: 작성자명 부분검색
            @RequestParam(required = false) String writerNm
    ) {
        return CommonResponse.ok(service.list(tmplCd, tmplNm, fromDt, toDt, writerId, writerNm));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 기존 상세 또는 선택 양식의 신규 기본행을 조회한다
     *   2) 좌측 행 클릭·양식 선택이 호출한다
     *   3) header·items·corrective JSON
     */
    @GetMapping("/detail")
    public CommonResponse<JsonNode> detail(
            // tmplCd: 신규일 때 항목을 깔 양식코드. 필수
            @RequestParam String tmplCd,
            // docIdx: 없으면 신규
            @RequestParam(required = false) Long docIdx
    ) {
        return CommonResponse.ok(service.detail(tmplCd, docIdx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 작성 내용 전체를 저장한다. 전송 전이라 필수값은 검사하지 않는다
     *   2) 저장 버튼이 호출한다
     *   3) 성공 시 문서 idx
     */
    @PutMapping("/save")
    public CommonResponse<Map<String, Long>> save(
            // req: 양식코드·일자·점검자·항목·하단 4칸
            @RequestBody CcpVerifyDraftSaveRequest req
    ) {
        return CommonResponse.ok(Map.of("docIdx", service.save(req)));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) 확인창 전에 호출한다
     *   3) Body [{ docIdx }]
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // keys: 복합키 객체 배열. UI 단건이어도 1건 배열
            @RequestBody List<CcpVerifyDraftDeleteItem> keys
    ) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 재검증 후 문서를 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) HTTP DELETE 금지 — POST 만 쓴다
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // keys: 복합키 객체 배열
            @RequestBody List<CcpVerifyDraftDeleteItem> keys
    ) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }
}
