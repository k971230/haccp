/**
 * HealthCertController — 보건증 REST (/api/v1/flow/box/health-cert-management).
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 회사·작업자는 JWT 만
 *   2) 파일 열람은 inline. 삭제는 validate-delete → delete
 *   3) 담당자 지정과 이력 API 의 행 권한은 Service 가 가른다
 *
 * PIPELINE[HB147] 보건증 Controller
 */
package com.haccp.flow.box.healthcert;

import com.haccp.common.response.CommonResponse;
import com.haccp.flow.box.healthcert.dto.HealthCertAlarmRow;
import com.haccp.flow.box.healthcert.dto.HealthCertCalMonth;
import com.haccp.flow.box.healthcert.dto.HealthCertCanRow;
import com.haccp.flow.box.healthcert.dto.HealthCertDeleteItem;
import com.haccp.flow.box.healthcert.dto.HealthCertEmpRow;
import com.haccp.flow.box.healthcert.dto.HealthCertHistRow;
import com.haccp.flow.box.healthcert.dto.HealthCertMgrRow;
import com.haccp.flow.box.healthcert.dto.HealthCertMgrSaveRequest;
import java.nio.charset.StandardCharsets;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/flow/box/health-cert-management")
@RequiredArgsConstructor
public class HealthCertController {

    private final HealthCertService service;

    @GetMapping("/can")
    public CommonResponse<HealthCertCanRow> can() {
        return CommonResponse.ok(service.can());
    }

    @GetMapping("/emp/list")
    public CommonResponse<List<HealthCertEmpRow>> emps(
            // 임박 대상만 — "Y"면 오늘~창 끝. 그 외는 전체. FE 가 상태 콤보로 다시 거른다
            @RequestParam(required = false) String expiringYn
    ) {
        return CommonResponse.ok(service.listEmps(expiringYn));
    }

    @GetMapping("/hist/list")
    public CommonResponse<List<HealthCertHistRow>> hist(
            // 조회 대상 사원 ID — JWT co_cd 회사의 tbl_user.user_id. SP 가 본인·담당자 가른다
            @RequestParam String userId
    ) {
        return CommonResponse.ok(service.listHist(userId));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-15
     * 코멘트:
     *   1) 회사·작업자는 JWT
     *   2) maskedYn 이 Y 가 아니면 거절
     *   3) PDF 만
     */
    @PostMapping("/hist/upload")
    public CommonResponse<Void> upload(
            // 등록 대상 사원 ID — JWT co_cd 회사의 tbl_user.user_id
            @RequestParam String userId,
            // 보건증 등록일 YYYYMMDD — varchar(8) DB 저장, 10자 화면 입력은 fromInputDate 변환
            @RequestParam String regDt,
            // 보건증 만료일 YYYYMMDD — 알림·파기 기준일. 화면 10자를 그대로 보내면 22001
            @RequestParam String expireDt,
            // 주민번호 마스킹 여부 — Y 아니면 거절. 업로드 책임을 남긴다
            @RequestParam String maskedYn,
            // PDF 파일 — 확장자·크기 검증 후 마스터 키로 DEK 감싸 암호화 저장
            @RequestPart("file") MultipartFile file
    ) {
        service.upload(userId, regDt, expireDt, file, maskedYn);
        return CommonResponse.ok(null);
    }

    @GetMapping("/hist/{idx}/view")
    public ResponseEntity<byte[]> view(
            // 열람할 이력 PK — tbl_health_cert_hist.idx. SP 가 본인·담당자 가른다
            @PathVariable Long idx
    ) {
        HealthCertService.HealthCertFile file = service.view(idx);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType(file.mimeType()));
        headers.setContentDisposition(ContentDisposition.inline()
                .filename(file.fileNm(), StandardCharsets.UTF_8)
                .build());
        return ResponseEntity.ok().headers(headers).body(file.content());
    }

    @PostMapping("/hist/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 대상 복합키 목록 — UI 단건이어도 1건 배열. [{ idx }]
            @RequestBody List<HealthCertDeleteItem> keys
    ) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    @PostMapping("/hist/delete")
    public CommonResponse<Void> delete(
            // 삭제 대상 복합키 목록 — Double Check 후 SP 루프 삭제. [{ idx }]
            @RequestBody List<HealthCertDeleteItem> keys
    ) {
        service.delete(keys);
        return CommonResponse.ok(null);
    }

    @GetMapping("/mgr/list")
    public CommonResponse<List<HealthCertMgrRow>> mgrs() {
        return CommonResponse.ok(service.listMgrs());
    }

    @GetMapping("/alarm")
    public CommonResponse<HealthCertAlarmRow> alarm() {
        return CommonResponse.ok(service.alarm());
    }

    @PutMapping("/mgr/save")
    public CommonResponse<Void> saveMgrs(
            // 담당자 user_id 배열 + 알림 일수 3개 — ADMIN 만 저장 가능
            @RequestBody HealthCertMgrSaveRequest req
    ) {
        service.saveMgrs(req);
        return CommonResponse.ok(null);
    }

    @GetMapping("/calendar")
    public CommonResponse<HealthCertCalMonth> calendar(
            // 조회 시작일 YYYYMMDD — 6주 칸 첫날. parseYearMonth 로 만든 range[0].ymd
            @RequestParam String fromYmd,
            // 조회 종료일 YYYYMMDD — 6주 칸 마지막. range[41].ymd
            @RequestParam String toYmd
    ) {
        return CommonResponse.ok(service.calendar(fromYmd, toYmd));
    }
}
