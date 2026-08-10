/**
 * WorkflowController — HACCP 관리 범위 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 결재선·사용양식/점검항목·작성주기·내보내기이력·스마트일지매핑 API를 역할별 고정 경로로 제공한다
 *   2) 신규·내보내기·불러오기는 PUT, 삭제는 POST validate-delete→delete 또는 POST delete만 사용한다
 *   3) 화면코드·회사코드·작업자는 URL이나 본문이 아닌 서버 고정 계약과 JWT로 분리한다
 *
 * PIPELINE[HB92] 워크플로 관리 REST Controller
 * PIPELINE[HB91, HB88, HF86] 연관 모듈
 */
package com.metis.haccp.workflow;

// 역할 — 공통 성공 응답
import com.metis.haccp.common.response.CommonResponse;
// 역할 — 워크플로 삭제 키 DTO
import com.metis.haccp.workflow.dto.WorkflowDeleteItem;
// 역할 — 목록·입력 맵
import java.util.List;
import java.util.Map;
// 역할 — 생성자 DI·Spring REST 매핑
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/bas")
@RequiredArgsConstructor
public class WorkflowController {
    private final WorkflowService service;

    @GetMapping("/approval-lines/list")
    public CommonResponse<List<Map<String, Object>>> approvalLines() {
        return CommonResponse.ok(service.approvalLines());
    }

    @PutMapping("/approval-lines/save")
    public CommonResponse<Void> saveApprovalLine(@RequestBody Map<String, Object> row) {
        service.saveApprovalLine(row);
        return CommonResponse.ok(null);
    }

    @PostMapping("/approval-lines/validate-delete")
    public CommonResponse<Void> validateApprovalLineDelete(@RequestBody List<WorkflowDeleteItem> keys) {
        service.validateApprovalLineDelete(keys);
        return CommonResponse.ok(null);
    }

    @PostMapping("/approval-lines/delete")
    public CommonResponse<Void> deleteApprovalLines(@RequestBody List<WorkflowDeleteItem> keys) {
        service.deleteApprovalLines(keys);
        return CommonResponse.ok(null);
    }

    @GetMapping("/company-templates/list")
    public CommonResponse<List<Map<String, Object>>> templates() {
        return CommonResponse.ok(service.templates());
    }

    @PutMapping("/company-templates/save")
    public CommonResponse<Void> saveTemplate(@RequestBody Map<String, Object> row) {
        service.saveTemplate(row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 법적서류 업로드 유형(회사 전용 또는 기존 LAW 명칭)을 저장한다
     *   2) legal-document-upload 좌측 그리드 저장이 호출한다
     *   3) 본문 {tmplCd,tmplNm} — 삭제·검증은 company-templates API 재사용
     */
    @PutMapping("/legal-types/save")
    public CommonResponse<Void> saveLegalType(@RequestBody Map<String, Object> row) {
        service.saveLegalType(row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 회사 사용양식 삭제 가능 여부만 검사한다
     *   2) 사용양식관리 삭제 확인 직전에 호출한다
     *   3) 본문은 [{tmplCd}] 배열 — HTTP DELETE 금지
     */
    @PostMapping("/company-templates/validate-delete")
    public CommonResponse<Void> validateCompanyTemplateDelete(@RequestBody List<WorkflowDeleteItem> keys) {
        service.validateCompanyTemplateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 검증을 통과한 회사 사용양식(sys_yn=N)을 삭제한다
     *   2) validate-delete와 같은 키 배열을 받는다
     *   3) 성공 시 void
     */
    @PostMapping("/company-templates/delete")
    public CommonResponse<Void> deleteCompanyTemplates(@RequestBody List<WorkflowDeleteItem> keys) {
        service.deleteCompanyTemplates(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 자사 HWP를 템플릿 볼륨(_template/{coCd}/한글명)에 올리고 sys_yn=N으로 등록한다
     *   2) 사용양식관리 신규 업로드가 multipart로 호출한다
     *   3) 성공 시 tmplCd·formPath·formFileNm — 바이너리는 DB에 넣지 않는다
     */
    @PostMapping(value = "/company-templates/create-custom", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CommonResponse<Map<String, Object>> createCompanyTemplateCustom(
            // 기준 표준 양식 코드
            @RequestParam String tmplCd,
            // 표시명 오버라이드 — 선택
            @RequestParam(required = false) String tmplNm,
            // HWP/HWPX 원본 — 파일명은 한글 원본 유지(번호 접두만 제거)
            @RequestParam("file") MultipartFile file
    ) {
        return CommonResponse.ok(service.createCompanyTemplateCustom(tmplCd, tmplNm, file));
    }

    @GetMapping("/company-check-items/list")
    public CommonResponse<List<Map<String, Object>>> checkItems(@RequestParam String tmplCd) {
        return CommonResponse.ok(service.checkItems(tmplCd));
    }

    @PutMapping("/company-check-items/save")
    public CommonResponse<Void> saveCheckItem(@RequestBody Map<String, Object> row) {
        service.saveCheckItem(row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 회사 전용(CUST*) 점검항목 삭제 키만 먼저 검사한다
     *   2) 문서별 admin 삭제 확인창 직전에 호출한다
     *   3) Body는 [{ tmplCd, itemCd }] 배열 — HTTP DELETE·스칼라 배열 금지
     */
    @PostMapping("/company-check-items/validate-delete")
    public CommonResponse<Void> validateCheckItemDelete(@RequestBody List<WorkflowDeleteItem> keys) {
        service.validateCheckItemDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 검증을 통과한 회사 전용 점검항목을 삭제한다
     *   2) validate-delete와 같은 [{ tmplCd, itemCd }] 배열을 전달한다
     *   3) Double Check 후 SP 루프 — 표준 항목은 차단
     */
    @PostMapping("/company-check-items/delete")
    public CommonResponse<Void> deleteCheckItems(@RequestBody List<WorkflowDeleteItem> keys) {
        service.deleteCheckItems(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 기본 양식에서 파생된 자사 양식 목록을 조회한다
     *   2) 사용양식 관리 하단 자사 양식 선택 그리드가 tmplCd별로 호출한다
     *   3) 회사 범위는 JWT 서비스 계층이 고정하므로 요청에는 양식 코드만 받는다
     */
    @GetMapping("/company-forms/list")
    public CommonResponse<List<Map<String, Object>>> companyForms(@RequestParam String tmplCd) {
        return CommonResponse.ok(service.companyForms(tmplCd));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 선택 자사 양식의 독립 점검항목을 조회한다
     *   2) 기본 양식 표준항목과 분리해 수정 가능 행만 하단 편집 그리드에 전달한다
     *   3) 선택 키가 없거나 타사 키일 때 서비스·SP가 업무 오류로 차단한다
     */
    @GetMapping("/company-form-items/list")
    public CommonResponse<List<Map<String, Object>>> companyFormItems(@RequestParam Long coFormIdx) {
        return CommonResponse.ok(service.companyFormItems(coFormIdx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 공통 기본 양식을 자사 양식으로 스냅샷 복제한다
     *   2) 사용양식 관리의 자사 양식 추가 버튼만 이 경로를 호출한다
     *   3) 플랫폼 기본 테이블은 수정하지 않고 새 업체 전용 행만 만든다
     */
    @PutMapping("/company-forms/clone")
    public CommonResponse<Void> cloneCompanyForm(@RequestBody Map<String, Object> row) {
        service.cloneCompanyForm(row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 자사 양식 점검항목을 저장한다
     *   2) 기본 양식 상단 그리드는 읽기 전용이므로 이 경로로 저장되지 않는다
     *   3) 항목의 추가·수정은 선택된 자사 양식 복제본 안에서만 발생한다
     */
    @PutMapping("/company-form-items/save")
    public CommonResponse<Void> saveCompanyFormItem(@RequestBody Map<String, Object> row) {
        service.saveCompanyFormItem(row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 신규 문서에 기본 양식 또는 자사 양식을 사용할지 전환한다
     *   2) coFormIdx가 null일 때(= 기본 양식 사용) 기존 자사 양식 데이터는 삭제하지 않는다
     *   3) 활성 전환은 요청 회사가 아닌 JWT 회사 범위에서만 저장한다
     */
    @PutMapping("/company-forms/activate")
    public CommonResponse<Void> activateCompanyForm(@RequestBody Map<String, Object> row) {
        service.activateCompanyForm(row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 스마트 HACCP 기준일지 유형 플랫폼 카탈로그를 조회한다
     *   2) 기준정보 관리 화면에서 유형·사용여부 조건으로 목록을 좁힌다
     *   3) 공공 표준은 읽기 전용이므로 저장·삭제 경로를 제공하지 않는다
     */
    @GetMapping("/smart-diary-types/list")
    public CommonResponse<List<Map<String, Object>>> smartDiaryTypes(
            @RequestParam(required = false, defaultValue = "") String diaryType,
            @RequestParam(required = false, defaultValue = "") String useYn
    ) {
        return CommonResponse.ok(service.smartDiaryTypes(diaryType, useYn));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 공공 기준일지와 우리 표준 양식의 매핑 상태를 조회한다
     *   2) 기준일지 유형 관리의 상세 패널이 선택된 행 기준으로 호출한다
     *   3) 조회 조건이 비어 있을 때(= 전체) 플랫폼 매핑을 반환한다
     */
    @GetMapping("/smart-diary-maps/list")
    public CommonResponse<List<Map<String, Object>>> smartDiaryMaps(
            @RequestParam(required = false, defaultValue = "") String diaryNo,
            @RequestParam(required = false, defaultValue = "") String tmplCd
    ) {
        return CommonResponse.ok(service.smartDiaryMaps(diaryNo, tmplCd));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 기준일지·내부 양식 매핑 1건을 저장한다
     *   2) 스마트일지 유형 관리의 매핑 그리드 저장이 호출한다
     *   3) 회사코드는 JWT로 고정하고 본문에는 매핑 필드만 받는다
     */
    @PutMapping("/smart-diary-map/save")
    public CommonResponse<Void> saveSmartDiaryMap(@RequestBody Map<String, Object> row) {
        service.saveSmartDiaryMap(row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 기준일지·양식 복합키로 매핑을 삭제한다
     *   2) 매핑 그리드 삭제 확인 후 호출한다
     *   3) HTTP DELETE 금지 규약에 따라 POST만 사용한다
     */
    @PostMapping("/smart-diary-map/delete")
    public CommonResponse<Void> deleteSmartDiaryMap(@RequestBody Map<String, Object> row) {
        service.deleteSmartDiaryMap(row);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 양식 설정 내보내기 이력 목록을 조회한다
     *   2) 불러오기 팝업이 docKind로 이력을 좁힐 때 호출한다
     *   3) payload 본문은 제외하고 메타만 반환한다
     */
    @GetMapping("/template-export-hist/list")
    public CommonResponse<List<Map<String, Object>>> templateExportHist(
            @RequestParam(required = false, defaultValue = "") String docKind
    ) {
        return CommonResponse.ok(service.templateExportHist(docKind));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 내보내기 이력 단건과 설정 payload를 조회한다
     *   2) 불러오기 직전 확인·디버깅용으로 사용한다
     *   3) 없는 idx일 때(= 타사·미존재) 서비스가 업무 예외를 던진다
     */
    @GetMapping("/template-export-hist/{idx}")
    public CommonResponse<Map<String, Object>> templateExportHistOne(@PathVariable Long idx) {
        return CommonResponse.ok(service.templateExportHistOne(idx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 현재 회사 양식·점검항목 오버라이드를 패키지로 내보낸다
     *   2) DB/HWP 설정 화면의 내보내기 버튼이 packNm·docKind로 호출한다
     *   3) 생성된 이력 idx를 반환해 화면이 성공 안내를 표시한다
     */
    @PutMapping("/template-export-hist/export")
    public CommonResponse<Long> exportTemplateHist(@RequestBody Map<String, Object> body) {
        return CommonResponse.ok(service.exportTemplateHist(body));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 서버 표준 또는 이력 payload로 오버라이드를 All-or-Nothing 복원한다
     *   2) 불러오기 팝업에서 source=SERVER 또는 histIdx를 선택해 호출한다
     *   3) 부분 적용을 막기 위해 서비스 트랜잭션에서 일괄 처리한다
     */
    @PutMapping("/template-export-hist/import")
    public CommonResponse<Void> importTemplateHist(@RequestBody Map<String, Object> body) {
        service.importTemplateHist(body);
        return CommonResponse.ok(null);
    }

    @GetMapping("/schedule-rules/list")
    public CommonResponse<List<Map<String, Object>>> scheduleRules() {
        return CommonResponse.ok(service.scheduleRules());
    }

    @PutMapping("/schedule-rules/save")
    public CommonResponse<Void> saveScheduleRule(@RequestBody Map<String, Object> row) {
        service.saveScheduleRule(row);
        return CommonResponse.ok(null);
    }

    @PostMapping("/schedule-rules/validate-delete")
    public CommonResponse<Void> validateScheduleRuleDelete(@RequestBody List<WorkflowDeleteItem> keys) {
        service.validateScheduleRuleDelete(keys);
        return CommonResponse.ok(null);
    }

    @PostMapping("/schedule-rules/delete")
    public CommonResponse<Void> deleteScheduleRules(@RequestBody List<WorkflowDeleteItem> keys) {
        service.deleteScheduleRules(keys);
        return CommonResponse.ok(null);
    }
}
