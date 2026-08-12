/**
 * SystemController — HACCP 시스템 관리·이력 조회 REST API (/api/v1/sys).
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 기존 인증·코드·메뉴·로그 SP를 관리 화면에서 안전하게 읽을 수 있는 단일 조회 경계로 제공한다
 *   2) 회사코드는 JWT에서만 읽고, 화면 유형은 허용 목록으로 제한해 임의 SQL 경로를 만들지 않는다
 *   3) 변경 기능은 기존 업무 SP별 저장 계약이 완성된 뒤 별도 API로 추가해야 하며 이 조회 API가 데이터를 바꾸지 않는다
 *
 * PIPELINE[HB93] 시스템 관리 REST Controller
 * PIPELINE[HB92, HF92] 연관 모듈
 */
package com.metis.haccp.sys;

// 역할 — JWT 로그인 회사코드 조회
import com.metis.haccp.common.context.LoginUserContext;
// 역할 — API 성공 응답 래퍼
import com.metis.haccp.common.response.CommonResponse;
// 역할 — 업무 예외
import com.metis.haccp.common.exception.BizException;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — 파일 응답·REST 매핑
import org.springframework.core.io.FileSystemResource;
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

// 역할 — 파일·화면 행 목록
import java.nio.file.Files;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** 시스템 관리 화면 → /api/v1/sys/* */
@RestController
@RequestMapping("/api/v1/sys")
@RequiredArgsConstructor
public class SystemController {

    // 공개 화면코드와 실제 조회 SP 분기값의 고정 대응표
    private static final Set<String> ALLOWED_TYPES = Set.of(
            "user-management", "department-management",
            "role-management", "menu-management", "common-code-management",
            "login-history", "screen-usage-statistics", "audit-log"
    );

    // 시스템 관리 조회 SP 호출
    private final SystemMapper systemMapper;
    // 시스템 관리 저장·삭제 Double Check 업무 로직
    private final SystemService systemService;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 시스템 관리 화면별 목록 또는 이력 행을 반환한다
     *   2) 각 화면의 최초 진입과 사용자가 조회를 누를 때 호출한다
     *   3) 허용되지 않은 화면코드는 업무 오류로 끝나고, 다른 회사 데이터는 반환하지 않는다
     */
    @GetMapping("/{screenCode}/list")
    public CommonResponse<List<Map<String, Object>>> list(
            // 역할 기반 kebab-case 화면코드 — 허용 목록으로 검증한다
            @PathVariable String screenCode,
            // 목록 내 부분검색어 — 미입력 시 전체 조회
            @RequestParam(required = false, defaultValue = "") String keyword,
            // 로그·통계 시작일 — YYYYMMDD, 없으면 오늘
            @RequestParam(required = false) String fromDt,
            // 로그·통계 종료일 — YYYYMMDD, 없으면 오늘
            @RequestParam(required = false) String toDt
    ) {
        if (!ALLOWED_TYPES.contains(screenCode)) {
            throw new BizException("지원하지 않는 시스템 관리 화면입니다.");
        }
        String today = java.time.LocalDate.now().format(java.time.format.DateTimeFormatter.BASIC_ISO_DATE);
        return CommonResponse.ok(systemMapper.selectRows(LoginUserContext.coCd(), screenCode, keyword.trim(),
                normalizeDate(fromDt, today), normalizeDate(toDt, today)));
    }

    @PutMapping("/{screenCode}/save")
    public CommonResponse<Void> save(
            @PathVariable String screenCode,
            @RequestBody List<Map<String, Object>> rows
    ) {
        requireManageType(screenCode);
        systemService.save(screenCode, rows);
        return CommonResponse.ok(null);
    }

    @PostMapping("/{screenCode}/validate-delete")
    public CommonResponse<Void> validateDelete(
            @PathVariable String screenCode,
            @RequestBody List<Map<String, Long>> keys
    ) {
        requireManageType(screenCode);
        systemService.validateDelete(screenCode, keys);
        return CommonResponse.ok(null);
    }

    @PostMapping("/{screenCode}/delete")
    public CommonResponse<Void> delete(
            @PathVariable String screenCode,
            @RequestBody List<Map<String, Long>> keys
    ) {
        requireManageType(screenCode);
        systemService.delete(screenCode, keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 로그인 사용자 서명 이미지를 내려준다
     *   2) 문서작성 「서명 복사」가 httpFile로 호출한다
     *   3) 미등록이면 업무 오류
     */
    @GetMapping("/users/me/sign")
    public ResponseEntity<FileSystemResource> mySign() {
        return signResponse(systemService.loadMySign());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 지정 사용자 서명 이미지를 내려준다
     *   2) 사용자 관리 서명 팝업 미리보기에서 호출한다
     *   3) 미등록이면 업무 오류
     */
    @GetMapping("/users/{userId}/sign")
    public ResponseEntity<FileSystemResource> userSign(@PathVariable String userId) {
        return signResponse(systemService.loadSign(userId));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 로그인 사용자 서명 상대경로만 JSON으로 반환한다
     *   2) 냉장 모니터링 행 「서명」 버튼이 경로를 행에 붙일 때 호출한다
     *   3) 미등록이면 signPath 빈 문자열
     */
    @GetMapping("/users/me/sign-path")
    public CommonResponse<Map<String, String>> mySignPath() {
        return CommonResponse.ok(Map.of("signPath", systemService.mySignPath()));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 로그인 사용자 서명 이미지를 업로드한다
     *   2) 시스템관리·문서작성에서 본인 서명을 등록할 때 호출한다
     *   3) 성공 시 상대경로 맵
     */
    @PostMapping(value = "/users/me/sign", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CommonResponse<Map<String, String>> uploadMySign(
            @RequestPart("file") MultipartFile file
    ) {
        String path = systemService.uploadSign(LoginUserContext.userId(), file);
        return CommonResponse.ok(Map.of("signPath", path));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 지정 사용자 서명 이미지를 업로드한다
     *   2) 사용자 관리 화면의 서명 업로드 버튼이 호출한다
     *   3) 성공 시 상대경로 맵
     */
    @PostMapping(value = "/users/{userId}/sign", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CommonResponse<Map<String, String>> uploadUserSign(
            @PathVariable String userId,
            @RequestPart("file") MultipartFile file
    ) {
        String path = systemService.uploadSign(userId, file);
        return CommonResponse.ok(Map.of("signPath", path));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 지정 사용자 서명을 삭제한다 — sign_path 비움 + 파일 삭제
     *   2) 사용자관리 서명 팝업 「삭제」가 호출한다 (HTTP DELETE 금지 → POST)
     *   3) 미등록이면 업무 오류
     */
    @PostMapping("/users/{userId}/sign/delete")
    public CommonResponse<Void> deleteUserSign(@PathVariable String userId) {
        systemService.deleteSign(userId);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 권한그룹별 화면 권한 목록을 반환한다
     *   2) 권한그룹 관리 우측 트리 로드 시 호출한다
     *   3) usrgrpCd 필수
     */
    @GetMapping("/role-management/screens")
    public CommonResponse<List<Map<String, Object>>> roleScreens(
            @RequestParam String usrgrpCd
    ) {
        return CommonResponse.ok(systemService.listRoleScreens(usrgrpCd));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 화면 조회권한(readYn) 변경을 저장한다
     *   2) 권한그룹 관리 트리 체크 저장 시 호출한다
     *   3) body: { usrgrpCd, rows:[{ scrnCd, readYn }] }
     */
    @PutMapping("/role-management/screens")
    public CommonResponse<Void> saveRoleScreens(@RequestBody Map<String, Object> body) {
        Object grp = body == null ? null : body.get("usrgrpCd");
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> rows = body == null ? null : (List<Map<String, Object>>) body.get("rows");
        systemService.saveRoleScreens(grp == null ? "" : String.valueOf(grp), rows);
        return CommonResponse.ok(null);
    }

    /** 권한 트리용 메뉴 평면 목록 */
    @GetMapping("/role-management/menus")
    public CommonResponse<List<Map<String, Object>>> roleMenus() {
        return CommonResponse.ok(systemService.listMenusAdmin());
    }

    /** 공통코드 대분류 헤더 */
    @GetMapping("/common-code-management/groups")
    public CommonResponse<List<Map<String, Object>>> codeGroups() {
        return CommonResponse.ok(systemService.listCodeGroups());
    }

    /** 공통코드 세부 — mainCd + sysYn */
    @GetMapping("/common-code-management/details")
    public CommonResponse<List<Map<String, Object>>> codeDetails(
            @RequestParam String mainCd,
            @RequestParam(required = false, defaultValue = "") String sysYn
    ) {
        return CommonResponse.ok(systemService.listCodeDetails(mainCd, sysYn));
    }

    private ResponseEntity<FileSystemResource> signResponse(SystemService.SignFile file) {
        MediaType mediaType;
        try {
            mediaType = MediaType.parseMediaType(file.mimeType());
        } catch (Exception e) {
            mediaType = MediaType.APPLICATION_OCTET_STREAM;
        }
        try {
            return ResponseEntity.ok()
                    .contentType(mediaType)
                    .contentLength(Files.size(file.path()))
                    .header(
                            HttpHeaders.CONTENT_DISPOSITION,
                            ContentDisposition.inline()
                                    .filename(file.fileNm(), java.nio.charset.StandardCharsets.UTF_8)
                                    .build()
                                    .toString()
                    )
                    .body(new FileSystemResource(file.path()));
        } catch (java.io.IOException e) {
            throw new BizException("서명 파일을 읽지 못했습니다.");
        }
    }

    private void requireManageType(String screenCode) {
        if (!ALLOWED_TYPES.contains(screenCode)
                || screenCode.equals("login-history")
                || screenCode.equals("screen-usage-statistics")
                || screenCode.equals("audit-log")) {
            throw new BizException("변경할 수 없는 시스템 관리 화면입니다.");
        }
    }

    private String normalizeDate(String value, String fallback) {
        if (value == null || value.isBlank()) return fallback;
        String normalized = value.replace("-", "");
        if (!normalized.matches("\\d{8}")) throw new BizException("조회 기간은 YYYYMMDD 형식이어야 합니다.");
        return normalized;
    }
}
