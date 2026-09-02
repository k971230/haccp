/**
 * HwpDraftController — HWP 양식 작성 REST.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 경로 /api/v1/draft/hwp-doc/hwp-write — FE SCREEN_PATH 와 같은 칸. 회사코드는 JWT 만
 *   2) HTML 작성 5화면과 같은 계약이다. 오늘 할일 팝업용 tasks 하나만 더 있다
 *   3) 전송·전송취소는 이 컨트롤러가 아니라 문서 허브 /api/v1/docs/documents/approval 을 쓴다
 *
 * 본문 HWP·HWPX 파일은 문서 파일 업로드 API(/api/v1/docs/documents/{docIdx}/files)가 받는다.
 *
 * PIPELINE[HB144] HWP 작성 Controller
 */
package com.haccp.draft.hwpdoc;

import com.haccp.common.response.CommonResponse;
import com.haccp.common.context.RequestMeta;
import com.haccp.draft.dto.DraftDeleteItem;
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import com.haccp.draft.dto.DraftSaveRequest;
import com.haccp.draft.dto.DraftTaskRow;
import jakarta.servlet.http.HttpServletRequest;
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
@RequestMapping("/api/v1/draft/hwp-doc/hwp-write")
@RequiredArgsConstructor
public class HwpDraftController {
    private final HwpDraftService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 작성에 쓸 수 있는 HWP 양식(사용여부 예)만 조회한다
     *   2) 화면 진입 시 한 번 호출한다
     *   3) 성공 시 양식 배열. 없으면 빈 배열
     */
    @GetMapping("/forms")
    public CommonResponse<List<DraftFormRow>> forms() {
        return CommonResponse.ok(service.forms());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 일자 구간·양식코드·양식명·작성자ID·작성자명으로 작성 목록을 조회한다
     *   2) 조회 버튼이 호출한다
     *   3) 성공 시 목록 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<DraftListRow>> list(
            // tmplCd: 양식코드 부분검색. 없으면 HWP 문서 전체
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
            @RequestParam(required = false) String writerNm,
            // title: 제목 부분검색 — tbl_document.title
            @RequestParam(required = false) String title
    ) {
        return CommonResponse.ok(service.list(tmplCd, tmplNm, fromDt, toDt, writerId, writerNm, title));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 기준일의 오늘 할일 중 HWP 문서주기를 조회한다
     *   2) 행 추가 버튼이 팝업을 열기 전에 호출한다
     *   3) 비어 있으면 화면은 팝업 없이 빈 행만 추가한다
     */
    @GetMapping("/tasks")
    public CommonResponse<List<DraftTaskRow>> tasks(
            // baseDt: 기준일 YYYYMMDD. 없으면 오늘
            @RequestParam(required = false) String baseDt
    ) {
        return CommonResponse.ok(service.tasks(baseDt));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 문서 1건의 헤더·첨부·결재 이력을 내린다 — rhwp 가 첨부에서 본문을 연다
     *   2) 좌측 목록에서 행을 고르면 호출한다
     *   3) 성공 시 header·approvals·files·versions
     */
    @GetMapping("/detail")
    public CommonResponse<Map<String, Object>> detail(
            // docIdx: 조회할 문서 idx
            @RequestParam Long docIdx
    ) {
        return CommonResponse.ok(service.detail(docIdx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 일자·양식코드로 문서 헤더를 저장한다. 전송하지 않고 전송대기를 유지한다
     *   2) 좌측 저장·우측 저장이 호출한다
     *   3) 성공 시 { docIdx }. 본문 파일은 이 뒤에 업로드 API 로 올린다
     */
    @PutMapping("/save")
    public CommonResponse<Map<String, Long>> save(
            @RequestBody DraftSaveRequest req,
            HttpServletRequest http
    ) {
        return CommonResponse.ok(Map.of("docIdx", service.save(req, RequestMeta.of(http))));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 삭제해도 되는 문서인지 먼저 본다 (OPS_DELETE Double Check)
     *   2) 삭제 확인창을 띄우기 전에 호출한다
     *   3) 전송 이후 문서가 섞이면 참조 차단 문구로 실패한다
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(@RequestBody List<DraftDeleteItem> keys) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 문서와 딸린 첨부·본문 파일을 지운다
     *   2) 삭제 확인창에서 예를 고르면 호출한다
     *   3) HTTP DELETE 는 쓰지 않는다. validate-delete 와 같은 검사를 서버에서 한 번 더 한다
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            @RequestBody List<DraftDeleteItem> keys,
            HttpServletRequest http
    ) {
        service.delete(keys, RequestMeta.of(http));
        return CommonResponse.ok(null);
    }
}
