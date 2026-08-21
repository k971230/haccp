/**
 * HealthCertController — 건강진단관리기록부 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 성명·검진일·만료·첨부 그리드 CRUD와 첨부 업로드를 제공한다
 *   2) coCd·userId는 요청 본문으로 받지 않고 JWT LoginUserContext만 쓴다
 *   3) 삭제는 POST validate-delete → POST delete 순서이며 HTTP DELETE를 사용하지 않는다
 *
 * PIPELINE[HB97] 건강진단 Controller
 * PIPELINE[HB94, HB95, HB96] 연관 모듈
 */
package com.haccp.docs.prp;

// 역할 — 공통 성공 응답
import com.haccp.common.response.CommonResponse;
// 역할 — 삭제 키 DTO
import com.haccp.docs.prp.dto.HealthCertDeleteItem;
// 역할 — 목록·맵 타입
import java.util.List;
import java.util.Map;
// 역할 — 생성자 DI
import lombok.RequiredArgsConstructor;
// 역할 — Spring REST 매핑
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
// 역할 — 업로드 파일
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/docs/prp/health-cert-record")
@RequiredArgsConstructor
public class HealthCertController {

    private final HealthCertService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 건강진단 목록을 성명·사용여부로 조회한다
     *   2) 화면 조회 버튼·초기 로드에서 호출한다
     *   3) 성공 시 camelCase 행 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<Map<String, Object>>> list(
            // 성명 부분검색 — 생략 시 전체
            @RequestParam(required = false) String personNm,
            // 사용여부 Y/N — 생략 시 전체
            @RequestParam(required = false) String useYn
    ) {
        return CommonResponse.ok(service.list(personNm, useYn));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 건강진단 행 배열을 신규 또는 수정으로 저장한다
     *   2) 요청 본문의 coCd·insId·updId는 받지 않고 JWT 사용자만 쓴다
     *   3) 성공 시 void
     */
    @PutMapping("/save")
    public CommonResponse<Void> save(
            // 신규·수정 건강진단 행 배열 — camelCase Map
            @RequestBody List<Map<String, Object>> rows
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
     *   3) 키가 비정상이면 400, 통과 시 void
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 키 객체 배열 — UI 단건도 [{ idx }]
            @RequestBody List<HealthCertDeleteItem> keys
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
            @RequestBody List<HealthCertDeleteItem> keys
    ) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 건강진단 1건에 첨부 파일을 올리고 DB 경로를 갱신한다
     *   2) 그리드 활성(저장) 행의 첨부 버튼이 httpFile로 호출한다
     *   3) 성공 시 filePath·fileNm Map
     */
    @PostMapping("/{idx}/file")
    public CommonResponse<Map<String, Object>> uploadFile(
            // 첨부 대상 대리키
            @PathVariable Long idx,
            // multipart 파일 — part name=file
            @RequestPart("file") MultipartFile file
    ) {
        return CommonResponse.ok(service.uploadFile(idx, file));
    }
}
