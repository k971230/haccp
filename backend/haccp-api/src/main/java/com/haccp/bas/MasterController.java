/**
 * MasterController — HACCP 기준정보 CRUD REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 제품·원부재료·거래처·보관고 등 9개 마스터와 CCP 한계기준을 같은 계약으로 제공한다
 *   2) URL masterType은 MasterType 허용 목록으로만 해석해 임의 테이블 접근을 막는다
 *   3) 삭제는 POST validate-delete → POST delete 순서이며 HTTP DELETE를 사용하지 않는다
 *
 * PIPELINE[HB76] 기준정보 REST Controller
 * PIPELINE[HB73, HB74, HB77] 연관 모듈
 */
package com.haccp.bas;

// 역할 — 기준정보 삭제 키 DTO
import com.haccp.bas.dto.MasterDeleteItem;
// 역할 — 기준정보 저장 행 DTO
import com.haccp.bas.dto.MasterSaveItem;
// 역할 — 공통 성공 응답
import com.haccp.common.response.CommonResponse;
// 역할 — 요청 본문·경로·쿼리 바인딩
import java.util.List;
import java.util.Map;
// 역할 — 생성자 DI
import lombok.RequiredArgsConstructor;
// 역할 — Spring REST 매핑
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/bas")
@RequiredArgsConstructor
public class MasterController {

    private final MasterService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 지정 기준정보의 목록을 조회한다
     *   2) useYn을 생략하면 사용·미사용 행을 모두 반환한다
     *   3) 성공 시 유형별 camelCase 행 배열
     */
    @GetMapping("/{masterType}/list")
    public CommonResponse<List<Map<String, Object>>> list(
            // 제품·보관고 등 허용된 기준정보 경로값
            @PathVariable String masterType,
            // 사용여부 필터 — 공백 또는 미전달이면 전체
            @RequestParam(required = false) String useYn
    ) {
        MasterType type = MasterType.from(masterType);
        return CommonResponse.ok(service.list(type, useYn));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 기준정보 행 배열을 신규 또는 수정으로 저장한다
     *   2) 요청 본문의 coCd·insId·updId는 받지 않고 JWT 사용자만 쓴다
     *   3) 성공 시 void
     */
    @PutMapping("/{masterType}/save")
    public CommonResponse<Void> save(
            // 제품·보관고 등 허용된 기준정보 경로값
            @PathVariable String masterType,
            // 신규·수정 기준정보 행 배열
            @RequestBody List<MasterSaveItem> rows
    ) {
        service.save(MasterType.from(masterType), rows);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 삭제 가능 여부만 검사하고 실제 데이터는 변경하지 않는다
     *   2) FE는 확인 모달을 열기 전에 이 API를 호출한다
     *   3) 참조 중이면 표준 업무 문구 400, 통과 시 void
     */
    @PostMapping("/{masterType}/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 제품·보관고 등 허용된 기준정보 경로값
            @PathVariable String masterType,
            // 삭제 키 객체 배열 — UI 단건도 [{ idx }]
            @RequestBody List<MasterDeleteItem> keys
    ) {
        service.validateDelete(MasterType.from(masterType), keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) validate-delete와 같은 참조 검사를 다시 수행한 뒤 삭제한다
     *   2) HTTP DELETE 대신 POST를 사용하고 키는 객체 배열로만 받는다
     *   3) 성공 시 void — 삭제 SP 영향행수는 노출하지 않는다
     */
    @PostMapping("/{masterType}/delete")
    public CommonResponse<Void> delete(
            // 제품·보관고 등 허용된 기준정보 경로값
            @PathVariable String masterType,
            // 삭제 키 객체 배열 — UI 단건도 [{ idx }]
            @RequestBody List<MasterDeleteItem> keys
    ) {
        service.delete(MasterType.from(masterType), keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 설비 마스터 사진만 업로드하고 photo_path를 갱신한다
     *   2) masterType은 equipment 만 허용한다
     *   3) 성공 시 photoPath Map
     */
    @PostMapping(value = "/equipment/{idx}/photo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CommonResponse<Map<String, Object>> uploadEquipmentPhoto(
            // 설비 대리키
            @PathVariable Long idx,
            // 사진 파일 — name=file
            @RequestPart("file") MultipartFile file
    ) {
        return CommonResponse.ok(service.uploadEquipmentPhoto(idx, file));
    }
}
