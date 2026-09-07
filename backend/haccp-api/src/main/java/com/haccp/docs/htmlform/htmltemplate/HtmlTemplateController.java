/**
 * HtmlTemplateController — HTML 양식 원본 REST.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 경로 /api/v1/docs/html-form/{scrnCd} 5화면. 회사코드는 JWT만. 좌 저장은 copy·name
 *   2) 파일 내보내기·업로드 API는 두지 않는다
 *   3) 삭제는 POST validate-delete → delete
 *
 * PIPELINE[HB130] HTML양식 원본 Controller
 */
package com.haccp.docs.htmlform.htmltemplate;

import com.haccp.common.response.CommonResponse;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormApplyRequest;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormCopyRequest;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormCopyResult;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormItemRow;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormItemsSaveRequest;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormNameRequest;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormVerDeleteItem;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormVersionRow;
import java.util.List;
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
        "/api/v1/docs/html-form/hyg-process-template",
        "/api/v1/docs/html-form/ccp-verify-template",
        "/api/v1/docs/html-form/ccp-pkg-template",
        "/api/v1/docs/html-form/ccp-htg-template",
        "/api/v1/docs/html-form/ccp-mtl-template"
})
@RequiredArgsConstructor
public class HtmlTemplateController {
    private final HtmlTemplateService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 예시+자사 양식 목록을 반환한다
     *   2) 좌측 목록·조회가 호출한다
     *   3) 회사는 JWT. tmplCd로 가족 분기. verCd·verNm 빈값이면 전체
     */
    @GetMapping("/versions")
    public CommonResponse<List<HtmlFormVersionRow>> versions(
            // tmplCd: 가족 — html_hyg_prc_000 / html_ccp_chk_000 / html_ccp_pkg_000 / html_ccp_htg_000 / html_ccp_mtl_000
            @RequestParam(required = false) String tmplCd,
            // verCd: 양식코드 부분검색
            @RequestParam(required = false) String verCd,
            // verNm: 양식명 부분검색
            @RequestParam(required = false) String verNm
    ) {
        return CommonResponse.ok(service.listVersions(tmplCd, verCd, verNm));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 양식 항목을 반환한다
     *   2) 우측 A4가 호출한다
     *   3) html_hyg_prc_000·html_ccp_chk_000·html_ccp_pkg_000·html_ccp_htg_000·html_ccp_mtl_000 이면 시드 표준
     */
    @GetMapping("/items")
    public CommonResponse<List<HtmlFormItemRow>> items(
            @RequestParam(required = false) String tmplCd,
            // verNo: 0=표준
            @RequestParam(required = false) Integer verNo
    ) {
        return CommonResponse.ok(service.listItems(tmplCd, verNo));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 표준 시드를 복사해 자사 양식(html_hyg_prc_NNN / html_ccp_chk_NNN / html_ccp_pkg_NNN / html_ccp_htg_NNN / html_ccp_mtl_NNN)을 INSERT한다
     *   2) 좌 저장이 pending을 커밋할 때 호출한다
     *   3) Body: verNm. data.tmplCd 반환
     */
    @PutMapping("/copy")
    public CommonResponse<HtmlFormCopyResult> copy(
            @RequestBody HtmlFormCopyRequest body
    ) {
        HtmlFormCopyRequest req = body == null ? new HtmlFormCopyRequest() : body;
        return CommonResponse.ok(service.copy(
                req.getTmplCd(),
                req.getSrcVerNo(),
                req.getVerCd(),
                req.getVerNm()
        ));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 사용자 버전 항목을 저장한다
     *   2) 저장 버튼이 호출한다
     *   3) 표준이면 거부
     */
    @PutMapping("/items")
    public CommonResponse<Void> saveItems(
            @RequestBody HtmlFormItemsSaveRequest body
    ) {
        HtmlFormItemsSaveRequest req = body == null ? new HtmlFormItemsSaveRequest() : body;
        service.saveItems(req.getTmplCd(), req.getVerNo(), req.getItems());
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 작성 신규 적용 버전을 고른다
     *   2) 좌 저장에서만 호출한다
     *   3) verNo=0 이면 표준
     */
    @PutMapping("/apply")
    public CommonResponse<Void> apply(
            @RequestBody HtmlFormApplyRequest body
    ) {
        HtmlFormApplyRequest req = body == null ? new HtmlFormApplyRequest() : body;
        service.apply(req.getTmplCd(), req.getVerNo());
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 사용자 버전명·회사 양식 사용여부를 고친다
     *   2) 좌 저장이 이름·사용여부가 바뀐 저장행을 커밋할 때 호출한다
     *   3) Body: tmplCd, verNo, verNm, useYn. 표준이면 거부
     */
    @PutMapping("/name")
    public CommonResponse<Void> updateVerNm(
            @RequestBody HtmlFormNameRequest body
    ) {
        HtmlFormNameRequest req = body == null ? new HtmlFormNameRequest() : body;
        service.updateVerNm(
                req.getTmplCd(),
                req.getVerNo(),
                req.getVerNm(),
                req.getUseYn()
        );
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) 확인창 전에 호출한다
     *   3) Body [{ tmplCd, verNo }]
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            @RequestBody List<HtmlFormVerDeleteItem> keys
    ) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 재검증 후 회사 버전을 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) HTTP DELETE 금지
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            @RequestBody List<HtmlFormVerDeleteItem> keys
    ) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }

}
