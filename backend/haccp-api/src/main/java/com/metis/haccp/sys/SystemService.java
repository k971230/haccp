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

    private void hashNewUserPassword(String type, Map<String, Object> payload) {
        if (!"user-management".equals(type)) return;
        boolean isNew = payload.get("idx") == null;
        String password = String.valueOf(payload.getOrDefault("userPw", "")).trim();
        if (isNew && password.isEmpty()) throw new BizException("신규 사용자의 비밀번호를 입력하세요.");
        if (!password.isEmpty()) payload.put("userPw", BCrypt.hashpw(password, BCrypt.gensalt()));
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
