/**
 * HwpTemplateController — 사용양식관리 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 사용양식관리 화면의 목록·저장·파일이력·불러오기/초기화 계약을 제공한다
 *   2) coCd·userId는 요청 본문으로 받지 않고 JWT LoginUserContext만 쓴다
 *   3) URL은 /api/v1/docs/hwp/hwp-template-management/* 이다 — 삭제도 형제 화면처럼 자기 경로에 둔다
 *
 * PIPELINE[HB123] 사용양식 REST Controller
 * PIPELINE[HB92, HB88] 연관 모듈
 */
package com.haccp.docs.hwp;

// 역할 — 공통 성공 응답
import com.haccp.common.response.CommonResponse;
// 역할 — 요청 본문·쿼리 바인딩
import java.util.List;
import java.util.Map;
// 역할 — 생성자 DI
import lombok.RequiredArgsConstructor;
// 역할 — Spring REST 매핑
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/docs/hwp/hwp-template-management")
@RequiredArgsConstructor
public class HwpTemplateController {

    private final HwpTemplateService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 사용양식관리 좌측 목록(hwp 양식·미사용 포함)을 조회한다
     *   2) 화면 진입·조회·저장/삭제 후 재조회가 호출한다
     *   3) 검색어는 빈 문자열 허용 — 공백이면 전체 목록
     */
    @GetMapping("/list")
    public CommonResponse<List<Map<String, Object>>> hwpTemplates(
            // 양식코드 검색어 — 공백이면 전체
            @RequestParam(required = false, defaultValue = "") String tmplCd,
            // 양식명 검색어 — 공백이면 전체
            @RequestParam(required = false, defaultValue = "") String tmplNm
    ) {
        return CommonResponse.ok(service.hwpTemplates(tmplCd, tmplNm));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 사용양식 1건을 저장한다 — 신규는 서버가 자사양식으로 강제한다
     *   2) 사용양식관리 저장 버튼이 호출한다
     *   3) 본문 {tmplCd, tmplNm, useYn} — sysYn 은 받아도 무시한다
     */
    @PutMapping("/save")
    public CommonResponse<Void> saveHwpTemplate(@RequestBody Map<String, Object> row) {
        service.saveHwpTemplate(row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 선택 양식의 파일 이력을 조회한다
     *   2) 「불러오기」 팝업이 호출한다
     *   3) 삭제된 이력은 제외하고 최근 업로드가 먼저 온다
     */
    @GetMapping("/files")
    public CommonResponse<List<Map<String, Object>>> hwpTemplateFiles(@RequestParam String tmplCd) {
        return CommonResponse.ok(service.hwpTemplateFiles(tmplCd));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 이력 버전을 현재 적용본으로 바꾸거나(불러오기) 기본 제공본으로 되돌린다(초기화)
     *   2) 「불러오기」 선택 확정·「초기화」 버튼이 호출한다
     *   3) 본문 {tmplCd, fileIdx?} — fileIdx 가 없으면 초기화다
     */
    @PostMapping("/apply-file")
    public CommonResponse<Void> applyHwpTemplateFile(@RequestBody Map<String, Object> row) {
        service.applyHwpTemplateFile(row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 삭제 가능 여부만 검사하고 자료는 변경하지 않는다
     *   2) 화면이 삭제 확인창을 열기 전에 호출한다
     *   3) 시스템 제공 양식·작성된 문서가 있으면 400, 통과하면 void
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 키 객체 배열 — 단건도 [{ tmplCd }]
            @RequestBody List<Map<String, Object>> keys
    ) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) validate-delete 와 같은 검사를 다시 한 뒤 삭제한다
     *   2) 화면 삭제 확인창에서 호출한다
     *   3) HTTP DELETE 를 쓰지 않는다 — 성공 시 void
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // 삭제 키 객체 배열 — 단건도 [{ tmplCd }]
            @RequestBody List<Map<String, Object>> keys
    ) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }
}
