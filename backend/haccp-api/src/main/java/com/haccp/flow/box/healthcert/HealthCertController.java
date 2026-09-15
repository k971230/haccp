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
            @RequestParam(required = false) String expiringYn
    ) {
        return CommonResponse.ok(service.listEmps(expiringYn));
    }

    @GetMapping("/hist/list")
    public CommonResponse<List<HealthCertHistRow>> hist(
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
            @RequestParam String userId,
            @RequestParam String regDt,
            @RequestParam String expireDt,
            @RequestParam String maskedYn,
            @RequestPart("file") MultipartFile file
    ) {
        service.upload(userId, regDt, expireDt, file, maskedYn);
        return CommonResponse.ok(null);
    }

    @GetMapping("/hist/{idx}/view")
    public ResponseEntity<byte[]> view(@PathVariable Long idx) {
        HealthCertService.HealthCertFile file = service.view(idx);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType(file.mimeType()));
        headers.setContentDisposition(ContentDisposition.inline()
                .filename(file.fileNm(), StandardCharsets.UTF_8)
                .build());
        return ResponseEntity.ok().headers(headers).body(file.content());
    }

    @PostMapping("/hist/validate-delete")
    public CommonResponse<Void> validateDelete(@RequestBody List<HealthCertDeleteItem> keys) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    @PostMapping("/hist/delete")
    public CommonResponse<Void> delete(@RequestBody List<HealthCertDeleteItem> keys) {
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
    public CommonResponse<Void> saveMgrs(@RequestBody HealthCertMgrSaveRequest req) {
        service.saveMgrs(req);
        return CommonResponse.ok(null);
    }

    @GetMapping("/calendar")
    public CommonResponse<HealthCertCalMonth> calendar(
            // 조회 시작일 YYYYMMDD
            @RequestParam String fromYmd,
            // 조회 종료일 YYYYMMDD
            @RequestParam String toYmd
    ) {
        return CommonResponse.ok(service.calendar(fromYmd, toYmd));
    }
}
