/**
 * ApprovalLineController — 결재선 REST (/api/v1/sys/code/approval-line-management).
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 패키지는 sys.approvalline. URL은 화면 SCREEN_PATH 와 같다
 *   2) 회사코드는 JWT에서만 읽는다
 *   3) 화면은 왼쪽에서 validate-delete → delete POST 를 쓴다
 *
 * PIPELINE[HB92] 결재선 관리 REST Controller
 */
package com.haccp.sys.code.approvalline;

// 역할 — API 성공 응답
import com.haccp.common.response.CommonResponse;
import com.haccp.sys.code.approvalline.dto.ApprovalLineDeleteItem;
import com.haccp.sys.code.approvalline.dto.ApprovalLineRow;
// 역할 — 목록
import java.util.List;
// 역할 — 생성자 DI · REST
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/sys/code/approval-line-management")
@RequiredArgsConstructor
public class ApprovalLineController {

    private final ApprovalLineService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 회사 결재선 목록을 반환한다
     *   2) 화면 조회·점검항목 콤보가 호출한다
     *   3) 없으면 빈 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<ApprovalLineRow>> list() {
        return CommonResponse.ok(service.list());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 결재선 1건을 저장한다
     *   2) 좌측 저장에서 호출한다
     *   3) 성공 시 void
     */
    @PutMapping("/save")
    public CommonResponse<Void> save(
            // row: 화면 폼 1건
            @RequestBody ApprovalLineRow row
    ) {
        service.save(row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) 확인창 직전에 호출한다
     *   3) Body는 [{ apprLineCd }] — HTTP DELETE 금지
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // keys: 삭제 대상 복합키 배열
            @RequestBody List<ApprovalLineDeleteItem> keys
    ) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 검증을 통과한 결재선을 삭제한다
     *   2) 왼쪽 삭제 버튼이 호출한다
     *   3) Double Check 후 SP 루프
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // keys: 삭제 대상 복합키 배열
            @RequestBody List<ApprovalLineDeleteItem> keys
    ) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }
}
