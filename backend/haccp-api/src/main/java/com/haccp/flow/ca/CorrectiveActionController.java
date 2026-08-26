/**
 * CorrectiveActionController — 개선조치관리 화면 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) URL 은 /api/v1/flow/ca/corrective-action-management/* — 형제 화면과 같은 형태다
 *   2) 회사코드·작업자는 JWT 에서만 읽는다
 *   3) tsk/TaskController 에서 옮겼다 — URL 은 /flow/ca 인데 패키지가 tsk 였다
 *
 * PIPELINE[HB94] 개선조치관리 REST Controller
 */
package com.haccp.flow.ca;

// 역할 — API 성공 응답 래퍼
import com.haccp.common.response.CommonResponse;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — REST 매핑
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

// 역할 — 화면 행·삭제키 목록
import java.util.List;
import java.util.Map;

/** 개선조치관리 → /api/v1/flow/ca/corrective-action-management/* */
@RestController
@RequestMapping("/api/v1/flow/ca/corrective-action-management")
@RequiredArgsConstructor
public class CorrectiveActionController {

    // 개선조치 업무 로직
    private final CorrectiveActionService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 기간·양식·작성자 조건으로 목록을 반환한다
     *   2) 화면 진입·조회·저장/삭제 후 호출한다
     *   3) 조건에 맞는 자료가 없으면 빈 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<Map<String, Object>>> list(
            // 시작일 YYYYMMDD — 비면 전체
            @RequestParam(required = false) String fromDt,
            // 종료일 YYYYMMDD — 비면 전체
            @RequestParam(required = false) String toDt,
            // 양식코드 — 비면 전체
            @RequestParam(required = false) String tmplCd,
            // 작성자 — 비면 전체
            @RequestParam(required = false) String writer
    ) {
        return CommonResponse.ok(service.correctiveActions(fromDt, toDt, tmplCd, writer));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 개선조치 1건을 저장한다 — idx 가 없으면 신규
     *   2) 화면 저장 버튼이 호출한다
     *   3) 성공 시 void — 화면이 목록을 재조회한다
     */
    @PutMapping("/save")
    public CommonResponse<Void> save(
            // 화면 행 — idx 가 있으면 수정
            @RequestBody Map<String, Object> row
    ) {
        Object idx = row == null ? null : row.get("idx");
        service.saveCorrectiveAction(idx instanceof Number n ? n.longValue() : null, row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 삭제 가능 여부만 검사하고 자료는 변경하지 않는다
     *   2) 화면이 삭제 확인창을 열기 전에 호출한다
     *   3) 통과하면 void
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 키 객체 배열 — 단건도 [{ idx }]
            @RequestBody List<Map<String, Long>> keys
    ) {
        service.validateCorrectiveActionDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) validate-delete 와 같은 검사를 다시 한 뒤 삭제한다
     *   2) 화면 삭제 확인창에서 호출한다
     *   3) HTTP DELETE 를 쓰지 않는다
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // 삭제 키 객체 배열 — 단건도 [{ idx }]
            @RequestBody List<Map<String, Long>> keys
    ) {
        service.deleteCorrectiveActions(keys);
        return CommonResponse.ok(null);
    }
}
