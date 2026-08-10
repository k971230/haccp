/**
 * CcpColdController — CCP 냉장보관 모니터링 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 경로 /api/v1/ccp/cold-monitor — ccp-cold-monitor 화면 전용
 *   2) 목록 GET, 상세 GET, 저장 PUT, 삭제 검증·삭제 POST (HTTP DELETE 금지)
 *   3) 테넌트 키는 JWT만 — 요청 본문의 coCd는 쓰지 않는다
 *
 * PIPELINE[HB72] REST Controller
 * PIPELINE[HB71, HB67, HB68] 연관 모듈
 */
package com.metis.haccp.ccp;

import com.metis.haccp.ccp.dto.ColdMonitorDeleteItem;
import com.metis.haccp.ccp.dto.ColdMonitorDetail;
import com.metis.haccp.ccp.dto.ColdMonitorListRow;
import com.metis.haccp.ccp.dto.ColdMonitorSaveRequest;
import com.metis.haccp.common.response.CommonResponse;
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
@RequestMapping("/api/v1/ccp/cold-monitor")
@RequiredArgsConstructor
public class CcpColdController {

    private final CcpColdService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 작성일 구간으로 일지 목록을 조회한다
     *   2) 화면 조회 버튼·초기 로드에서 호출한다
     *   3) 성공 시 목록 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<ColdMonitorListRow>> list(
            // 작성일 시작 YYYYMMDD
            @RequestParam(required = false) String fromDt,
            // 작성일 종료 YYYYMMDD
            @RequestParam(required = false) String toDt,
            // CCP 코드 필터
            @RequestParam(required = false) String ccpCd,
            // 문서번호 부분검색
            @RequestParam(required = false) String docNo,
            // 작성자 ID·이름 부분검색
            @RequestParam(required = false) String writer
    ) {
        return CommonResponse.ok(service.list(fromDt, toDt, ccpCd, docNo, writer));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서 상세 또는 신규 양식 뼈대를 반환한다
     *   2) docIdx 생략/0이면(= 신규) 보관고·한계기준만 채운다
     *   3) 성공 시 ColdMonitorDetail
     */
    @GetMapping("/detail")
    public CommonResponse<ColdMonitorDetail> detail(
            // 문서 idx — 신규면 생략
            @RequestParam(required = false) Long docIdx
    ) {
        return CommonResponse.ok(service.detail(docIdx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 일지를 저장하고 문서 idx를 반환한다
     *   2) 화면 저장 버튼에서 호출한다
     *   3) 성공 시 { docIdx }
     */
    @PutMapping("/save")
    public CommonResponse<Map<String, Long>> save(
            // 저장 본문 — 행 전체 교체
            @Valid @RequestBody ColdMonitorSaveRequest req
    ) {
        Long docIdx = service.save(req);
        return CommonResponse.ok(Map.of("docIdx", docIdx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) FE가 확인창 전에 호출한다
     *   3) 통과 시 void, 차단 시 400 업무 문구
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 키 배열 [{ docIdx }]
            @RequestBody List<ColdMonitorDeleteItem> keys
    ) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 임시·반려 문서를 삭제한다
     *   2) validate-delete 통과·확인 후 호출한다
     *   3) 성공 시 void (CALL 영향행수 -1을 노출하지 않는다)
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // 삭제 키 배열 [{ docIdx }]
            @RequestBody List<ColdMonitorDeleteItem> keys
    ) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }
}
