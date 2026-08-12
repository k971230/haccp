/**
 * SystemService — 시스템 관리 CUD와 삭제 Double Check 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 요청 본문에서 회사·감사 주체를 제거하고 JWT 컨텍스트의 테넌트·사용자만 SP에 전달한다
 *   2) 사용자 신규 비밀번호만 BCrypt로 해시하며 수정 시 빈 비밀번호는 SP가 기존 해시를 유지한다
 *   3) 삭제는 validate-delete와 delete 양쪽에서 배열 단일 조회 참조 검사를 수행한다
 *
 * PIPELINE[HB94] 시스템 관리 Service
 * PIPELINE[HB92, HB93, HF92] 연관 모듈
 */
package com.metis.haccp.sys;

// 역할 — JSON payload 안전 변환
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — JWT 테넌트·작업자
import com.metis.haccp.common.context.LoginUserContext;
// 역할 — 업무 예외
import com.metis.haccp.common.exception.BizException;
// 역할 — 삭제 표준 검증
import com.metis.haccp.common.validation.DeleteValidation;
// 역할 — 서명 이미지 물리 저장
import com.metis.haccp.doc.DocumentFileStorage;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — BCrypt 비밀번호 해시
import org.springframework.security.crypto.bcrypt.BCrypt;
// 역할 — 저장·삭제 트랜잭션
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
// 역할 — Multipart 업로드
import org.springframework.web.multipart.MultipartFile;

// 역할 — 경로·요청 행·삭제키 배열
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class SystemService {
    private final SystemMapper systemMapper;
    private final ObjectMapper objectMapper;
    private final DocumentFileStorage fileStorage;

    @Transactional
    public void save(String type, List<Map<String, Object>> rows) {
        DeleteValidation.requireItems(rows, "저장할 시스템 관리 행이 없습니다.");
        for (Map<String, Object> row : rows) {
            if (row == null) throw new BizException("저장할 시스템 관리 행이 올바르지 않습니다.");
            Map<String, Object> payload = new java.util.LinkedHashMap<>(row);
            payload.remove("coCd");
            payload.remove("insId");
            payload.remove("updId");
            hashNewUserPassword(type, payload);
            systemMapper.save(LoginUserContext.coCd(), type, writeJson(payload), LoginUserContext.userId());
        }
    }

    public void validateDelete(String type, List<Map<String, Long>> keys) {
        assertDeletable(type, keys);
    }

    @Transactional
    public void delete(String type, List<Map<String, Long>> keys) {
        List<Long> idxs = assertDeletable(type, keys);
        for (Long idx : idxs) {
            systemMapper.delete(LoginUserContext.coCd(), type, idx, LoginUserContext.userId());
        }
    }

    private List<Long> assertDeletable(String type, List<Map<String, Long>> keys) {
        DeleteValidation.requireItems(keys, "삭제할 시스템 관리 행을 선택하세요.");
        List<Long> idxs = new ArrayList<>();
        for (Map<String, Long> key : keys) {
            if (key == null) throw new BizException("삭제할 시스템 관리 키가 올바르지 않습니다.");
            idxs.add(DeleteValidation.requirePositive(key.get("idx"), "삭제할 시스템 관리 키가 올바르지 않습니다."));
        }
        DeleteValidation.throwIfBlocked(systemMapper.selectDeleteBlocker(LoginUserContext.coCd(), type, idxs), "시스템 관리 항목");
        return idxs;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 로그인 사용자 서명 이미지 Path를 반환한다
     *   2) 문서작성 「서명 복사」가 호출한다
     *   3) 경로 없거나 파일이 없으면 BizException
     */
    public SignFile loadMySign() {
        return loadSign(LoginUserContext.userId());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 로그인 사용자 서명 상대경로만 반환한다(파일 바이너리 없음)
     *   2) 냉장 모니터링 행 서명 적용 등 DB 경로만 필요한 화면이 호출한다
     *   3) 미등록이면 빈 문자열 — 호출측이 업로드를 유도한다
     */
    public String mySignPath() {
        String relative = systemMapper.selectSignPath(LoginUserContext.coCd(), LoginUserContext.userId());
        return relative == null ? "" : relative.trim();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 지정 사용자 서명 경로의 물리 파일을 읽는다
     *   2) 시스템관리 미리보기·서명 복사에서 호출한다
     *   3) 타 테넌트·미등록이면 업무 오류
     */
    public SignFile loadSign(String userId) {
        String target = text(userId);
        if (target.isEmpty()) throw new BizException("사용자 ID가 올바르지 않습니다.");
        String relative = systemMapper.selectSignPath(LoginUserContext.coCd(), target);
        if (relative == null || relative.isBlank()) {
            throw new BizException("등록된 서명이 없습니다. 시스템관리에서 서명 이미지를 업로드하세요.");
        }
        Path path = fileStorage.read(relative);
        String name = Path.of(relative).getFileName().toString();
        String mime = guessImageMime(name);
        return new SignFile(name, mime, path);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 서명 이미지를 저장하고 tbl_user.sign_path를 갱신한다
     *   2) 본인 또는 사용자관리 화면에서 호출한다
     *   3) 성공 시 상대경로, 실패 시 BizException
     */
    @Transactional
    public String uploadSign(String userId, MultipartFile file) {
        String target = text(userId);
        if (target.isEmpty()) throw new BizException("사용자 ID가 올바르지 않습니다.");
        assertSignImage(file);
        String existing = systemMapper.selectSignPath(LoginUserContext.coCd(), target);
        // 대상 사용자가 회사에 없을 때(= select null이면서 실제 미존재) 갱신 0건으로 판별
        String path = fileStorage.save(LoginUserContext.coCd(), file);
        int updated = systemMapper.updateSignPath(
                LoginUserContext.coCd(), target, path, LoginUserContext.userId());
        if (updated <= 0) {
            try {
                fileStorage.delete(path);
            } catch (RuntimeException ignored) {
                // 원래 업무 오류 우선
            }
            throw new BizException("사용자를 찾을 수 없습니다.");
        }
        // 이전 서명 파일이 있을 때(= 교체) 고아 파일을 정리한다
        if (existing != null && !existing.isBlank() && !existing.equals(path)) {
            try {
                fileStorage.delete(existing);
            } catch (RuntimeException ignored) {
                // 신규 경로가 정본이므로 이전 파일 정리 실패는 무시
            }
        }
        return path;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 사용자 서명 경로를 비우고 물리 파일을 삭제한다
     *   2) 사용자관리 서명 팝업 「삭제」에서 호출한다
     *   3) 미등록이면 업무 오류, 파일 정리 실패는 DB 클리어를 우선한다
     */
    @Transactional
    public void deleteSign(String userId) {
        String target = text(userId);
        if (target.isEmpty()) throw new BizException("사용자 ID가 올바르지 않습니다.");
        String existing = systemMapper.selectSignPath(LoginUserContext.coCd(), target);
        if (existing == null || existing.isBlank()) {
            throw new BizException("등록된 서명이 없습니다.");
        }
        int updated = systemMapper.updateSignPath(
                LoginUserContext.coCd(), target, "", LoginUserContext.userId());
        if (updated <= 0) {
            throw new BizException("사용자를 찾을 수 없습니다.");
        }
        try {
            fileStorage.delete(existing);
        } catch (RuntimeException ignored) {
            // DB 경로가 정본이므로 파일 정리 실패는 무시
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 권한그룹의 화면별 권한 목록을 반환한다
     *   2) 권한그룹 관리 우측 트리 로드 시 호출한다
     *   3) 미설정 화면도 N으로 채워진다
     */
    public List<Map<String, Object>> listRoleScreens(String usrgrpCd) {
        String grp = text(usrgrpCd);
        if (grp.isEmpty()) throw new BizException("권한그룹코드를 선택하세요.");
        return systemMapper.selectRoleScreens(LoginUserContext.coCd(), grp);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 화면 조회권한(read_yn) 변경을 저장한다 — 열림이면 5권한 Y, 닫힘이면 전부 N
     *   2) 권한그룹 관리 트리 체크 저장 시 호출한다
     *   3) 빈 목록이면 업무 오류
     */
    @Transactional(timeout = 60)
    public void saveRoleScreens(String usrgrpCd, List<Map<String, Object>> rows) {
        String grp = text(usrgrpCd);
        if (grp.isEmpty()) throw new BizException("권한그룹코드를 선택하세요.");
        DeleteValidation.requireItems(rows, "저장할 화면 권한이 없습니다.");
        String actor = LoginUserContext.userId();
        String co = LoginUserContext.coCd();
        for (Map<String, Object> row : rows) {
            if (row == null) throw new BizException("화면 권한 행이 올바르지 않습니다.");
            String scrn = text(String.valueOf(row.getOrDefault("scrnCd", "")));
            if (scrn.isEmpty()) throw new BizException("화면코드가 없습니다.");
            String read = text(String.valueOf(row.getOrDefault("readYn", "N"))).toUpperCase();
            if (!read.equals("Y")) read = "N";
            // 열림(Y)이면 업무 사용 가능하도록 등록·수정·출력도 Y, 삭제는 N 유지 가능하나 1차는 전부 Y
            String yn = read;
            systemMapper.upsertRoleScreen(co, grp, scrn, yn, yn, yn, yn, yn, actor);
        }
    }

    /** 공통코드 대분류 헤더 목록 */
    public List<Map<String, Object>> listCodeGroups() {
        return systemMapper.selectCodeGroups(LoginUserContext.coCd());
    }

    /** 공통코드 세부 — mainCd + sysYn(Y|N|sys|usr) */
    public List<Map<String, Object>> listCodeDetails(String mainCd, String sysYn) {
        String main = text(mainCd);
        if (main.isEmpty()) throw new BizException("대분류 코드를 선택하세요.");
        return systemMapper.selectCodeDetails(LoginUserContext.coCd(), main, text(sysYn));
    }

    /** 메뉴 관리 평면 목록 — 권한 트리 조립용 */
    public List<Map<String, Object>> listMenusAdmin() {
        return systemMapper.selectMenusAdmin(LoginUserContext.coCd());
    }

    /** 신규 사용자 기본 비밀번호 — 화면에서 비번 컬럼을 받지 않을 때 서버가 채운다 */
    private static final String DEFAULT_NEW_USER_PW = "1234";
    /** 서명 이미지 최대 크기 — 10MB */
    private static final long SIGN_MAX_BYTES = 10L * 1024 * 1024;

    private void hashNewUserPassword(String type, Map<String, Object> payload) {
        if (!"user-management".equals(type)) return;
        boolean isNew = payload.get("idx") == null
                || "".equals(String.valueOf(payload.get("idx")).trim())
                || "null".equalsIgnoreCase(String.valueOf(payload.get("idx")));
        String password = String.valueOf(payload.getOrDefault("userPw", "")).trim();
        // 신규이고 비번 미입력 시(= 화면에서 비번 컬럼 제거) 기본값 1234
        if (isNew && password.isEmpty()) password = DEFAULT_NEW_USER_PW;
        if (!password.isEmpty()) payload.put("userPw", BCrypt.hashpw(password, BCrypt.gensalt()));
    }

    private void assertSignImage(MultipartFile file) {
        if (file == null || file.isEmpty()) throw new BizException("서명 파일을 선택하세요.");
        if (file.getSize() > SIGN_MAX_BYTES) {
            throw new BizException("서명 이미지는 10MB 이하만 업로드할 수 있습니다.");
        }
        String contentType = text(file.getContentType()).toLowerCase();
        String name = text(file.getOriginalFilename()).toLowerCase();
        boolean okType = contentType.equals("image/png") || contentType.equals("image/jpeg");
        boolean okExt = name.endsWith(".png") || name.endsWith(".jpg") || name.endsWith(".jpeg");
        if (!okType && !okExt) {
            throw new BizException("PNG 또는 JPG 파일만 업로드할 수 있습니다.");
        }
    }

    private String writeJson(Map<String, Object> payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (Exception e) {
            throw new BizException("시스템 관리 저장 형식을 변환하지 못했습니다.");
        }
    }

    private static String text(String value) {
        return value == null ? "" : value.trim();
    }

    private static String guessImageMime(String fileName) {
        String lower = fileName == null ? "" : fileName.toLowerCase();
        if (lower.endsWith(".png")) return "image/png";
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
        if (lower.endsWith(".gif")) return "image/gif";
        if (lower.endsWith(".webp")) return "image/webp";
        return "application/octet-stream";
    }

    /** 서명 다운로드 응답용 */
    public record SignFile(String fileNm, String mimeType, Path path) {}
}
