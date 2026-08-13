/**
 * PestDeviceHistController — 방충설비 이력 CRUD REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 방충설비 M-D 하단 이력 그리드의 목록·저장·삭제 계약을 제공한다
 *   2) coCd·userId는 요청 본문으로 받지 않고 JWT LoginUserContext만 쓴다
 *   3) 삭제는 POST validate-delete → POST delete 순서이며 HTTP DELETE를 사용하지 않는다
 *
 * PIPELINE[HB98] 설비이력 REST Controller
 * PIPELINE[HB94, HB95, HB97] 연관 모듈
 */
package com.haccp.bas;

// 역할 — 방충설비 이력 삭제 키 DTO
import com.haccp.bas.dto.PestDeviceHistDeleteItem;
// 역할 — 방충설비 이력 저장 행 DTO
import com.haccp.bas.dto.PestDeviceHistSaveItem;
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
@RequestMapping("/api/v1/bas/pest-device-hist")
@RequiredArgsConstructor
public class PestDeviceHistController {

    private final PestDeviceHistService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 선택한 설비의 이력 목록을 조회한다
     *   2) 설비이력 화면에서 상단 설비 행을 고른 뒤 호출한다
     *   3) 성공 시 camelCase 행 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<Map<String, Object>>> list(
            // 상위 설비 대리키 — 필수
            @RequestParam Long pestIdx
    ) {
        return CommonResponse.ok(service.list(pestIdx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 이력 행 배열을 신규 또는 수정으로 저장한다
     *   2) 요청 본문의 coCd·insId·updId는 받지 않고 JWT 사용자만 쓴다
     *   3) 성공 시 void
     */
    @PutMapping("/save")
    public CommonResponse<Void> save(
            // 신규·수정 이력 행 배열
            @RequestBody List<PestDeviceHistSaveItem> rows
    ) {
        service.save(rows);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 삭제 가능 여부만 검사하고 실제 데이터는 변경하지 않는다
     *   2) FE는 확인 모달을 열기 전에 이 API를 호출한다
     *   3) 키 오류면 업무 문구 400, 통과 시 void
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 키 객체 배열 — UI 단건도 [{ idx }]
            @RequestBody List<PestDeviceHistDeleteItem> keys
    ) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) validate-delete와 같은 키 검사를 다시 수행한 뒤 삭제한다
     *   2) HTTP DELETE 대신 POST를 사용하고 키는 객체 배열로만 받는다
     *   3) 성공 시 void — 삭제 SP 영향행수는 노출하지 않는다
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // 삭제 키 객체 배열 — UI 단건도 [{ idx }]
            @RequestBody List<PestDeviceHistDeleteItem> keys
    ) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }
}
