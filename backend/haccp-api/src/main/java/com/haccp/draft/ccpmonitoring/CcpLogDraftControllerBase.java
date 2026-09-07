/**
 * CcpLogDraftControllerBase — CCP 모니터링일지 작성 2화면(포장·가열) 공통 REST.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 두 화면은 엔드포인트 6개가 글자까지 같다. 계열은 서비스가 숨긴다
 *   2) 각 화면은 URL 과 서비스 주입만 선언한다
 *   3) 금속은 delete 시그니처가 달라 여기 안 넣는다
 *
 * PIPELINE[HB140] CCP 모니터링 작성 공통 Controller
 */
package com.haccp.draft.ccpmonitoring;

// 역할 — 공통 응답 포장
import com.haccp.common.response.CommonResponse;
// 역할 — 작성 화면 공용 계약
import com.haccp.draft.dto.CcpMonitorDraftDetail;
import com.haccp.draft.dto.DraftDeleteItem;
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import com.haccp.draft.dto.DraftSaveRequest;
// 역할 — 목록·본문
import java.util.List;
import java.util.Map;
// 역할 — 매핑
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;

public abstract class CcpLogDraftControllerBase {

    /** 이 화면의 계열 서비스 — 하위 클래스가 주입받은 것을 넘긴다 */
    protected abstract CcpMonitorDraftFacade service();

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 작성에 쓸 수 있는 자사 양식(사용여부 예)만 조회한다
     *   2) 화면 진입 시 한 번 호출한다
     *   3) 성공 시 양식 배열. 없으면 빈 배열
     */
    @GetMapping("/forms")
    public CommonResponse<List<DraftFormRow>> forms() {
        return CommonResponse.ok(service().forms());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 일자 구간·양식코드·양식명·작성자ID·작성자명으로 작성 목록을 조회한다
     *   2) 조회 버튼이 호출한다
     *   3) 성공 시 목록 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<DraftListRow>> list(
            // tmplCd: 양식코드 부분검색. 없으면 이 화면 자사 양식 전체
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
        return CommonResponse.ok(
                service().list(tmplCd, tmplNm, fromDt, toDt, writerId, writerNm, title));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 문서 1건의 지면 값을 내린다. docIdx 가 없으면 신규 기본행을 만든다
     *   2) 좌측 목록에서 행을 고르거나 행을 추가·저장한 뒤 호출한다
     *   3) 성공 시 header·items·logRows·passRows·corrective
     */
    @GetMapping("/detail")
    public CommonResponse<CcpMonitorDraftDetail> detail(
            // tmplCd: 조회할 양식코드 — 이 화면 자사 양식만 통과한다
            @RequestParam String tmplCd,
            // docIdx: 조회할 문서 idx. 없으면 신규 기본행을 만든다
            @RequestParam(required = false) Long docIdx
    ) {
        return CommonResponse.ok(service().detail(tmplCd, docIdx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 우측 지면 값을 저장한다. 전송하지 않고 전송대기를 유지한다
     *   2) 우측 저장 버튼이 호출한다
     *   3) 성공 시 { docIdx }
     */
    @PutMapping("/save")
    public CommonResponse<Map<String, Long>> save(@RequestBody DraftSaveRequest req) {
        return CommonResponse.ok(Map.of("docIdx", service().save(req)));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 삭제해도 되는 문서인지 먼저 본다 (OPS_DELETE Double Check)
     *   2) 삭제 확인창을 띄우기 전에 호출한다
     *   3) 전송 이후 문서가 섞이면 참조 차단 문구로 실패한다
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(@RequestBody List<DraftDeleteItem> keys) {
        service().validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 문서와 딸린 지면 값을 지운다
     *   2) 삭제 확인창에서 예를 고르면 호출한다
     *   3) validate-delete 와 같은 검사를 서버에서 한 번 더 한다
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(@RequestBody List<DraftDeleteItem> keys) {
        service().delete(keys);
        return CommonResponse.ok(null);
    }
}
