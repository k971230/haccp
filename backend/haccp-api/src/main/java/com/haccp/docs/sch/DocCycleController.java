/**
 * DocCycleController — 문서주기관리 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 문서주기관리 화면(좌측 양식 목록 50% · 우측 주기 폼 50%)의 조회·저장·삭제 계약을 제공한다
 *   2) coCd·userId는 요청 본문으로 받지 않고 JWT LoginUserContext만 쓴다
 *   3) URL은 /api/v1/docs/sch/schedule-cycle-management 이다. 삭제는 POST validate-delete → POST delete 순서이며 HTTP DELETE를 사용하지 않는다
 *
 * PIPELINE[HB99] 문서주기 REST Controller
 * PIPELINE[HB94, HB98] 연관 모듈
 */
package com.haccp.docs.sch;

// 역할 — 문서주기 삭제 키 DTO
import com.haccp.docs.sch.dto.DocCycleDeleteItem;
import com.haccp.docs.sch.dto.DocCycleFormRow;
import com.haccp.docs.sch.dto.DocCycleRow;
import com.haccp.docs.sch.dto.DocCycleSaveRequest;
// 역할 — 공통 성공 응답
import com.haccp.common.response.CommonResponse;
// 역할 — 요청 본문·쿼리 바인딩
import java.util.List;
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
@RequestMapping("/api/v1/docs/sch/schedule-cycle-management")
@RequiredArgsConstructor
public class DocCycleController {

    private final DocCycleService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 좌측 양식 목록 — 사용여부 검색 + 구분 + 주기 등록여부
     *   2) 화면 진입·조회 버튼에서 호출한다
     *   3) 성공 시 camelCase 행 배열
     */
    @GetMapping("/forms")
    public CommonResponse<List<DocCycleFormRow>> forms(
            // 양식코드 검색어 — 미지정이면 전체
            @RequestParam(required = false) String tmplCd,
            // 양식명 검색어 — 미지정이면 전체
            @RequestParam(required = false) String tmplNm,
            // 사용여부 Y/N — 미지정이면 전체
            @RequestParam(required = false) String useYn
    ) {
        return CommonResponse.ok(service.forms(tmplCd, tmplNm, useYn));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 선택 양식의 주기 1건 + 반복 상세를 조회한다
     *   2) 좌측 행을 고를 때마다 호출해 우측 폼을 채운다
     *   3) 주기 미설정일 때(= 신규 등록 대상) data가 null
     */
    @GetMapping("/get")
    public CommonResponse<DocCycleRow> get(
            // 좌측에서 선택한 양식코드 — 필수
            @RequestParam String tmplCd
    ) {
        return CommonResponse.ok(service.cycle(tmplCd));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 주기 1건을 저장하고 예정일까지 다시 만든다
     *   2) 우측 폼 저장 버튼에서 호출한다
     *   3) 성공 시 data 없음 — FE가 재조회로 화면을 맞춘다
     */
    @PutMapping("/save")
    public CommonResponse<Void> save(
            // 화면 폼 1건 — tmplCd·baseDt·cycleCd·nonworkRule·dueTime·deptCd·userId·useYn·details[]
            @RequestBody DocCycleSaveRequest row
    ) {
        service.save(row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 삭제 전 주기 존재 여부를 검사한다
     *   2) FE 확인창 직전에 호출한다
     *   3) 차단 사유가 있으면 업무 문구로 응답한다
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 대상 복합키 배열 — UI 단건이어도 1건 배열
            @RequestBody List<DocCycleDeleteItem> keys
    ) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 주기·반복 상세를 삭제하고 미래 미작성 예정일을 정리한다
     *   2) 확인창 이후 호출한다
     *   3) 실패 시 전건 롤백
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // 삭제 대상 복합키 배열
            @RequestBody List<DocCycleDeleteItem> keys
    ) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }
}
