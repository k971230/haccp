/**
 * UserService — 사용자 관리와 서명 이미지의 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 회사코드·작업자는 JWT 컨텍스트에서만 읽고, 평문 비밀번호는 여기서 BCrypt 해시로 바꾼 뒤에만 SP로 넘긴다
 *   2) 서명은 파일 저장소를 쓰지 않고 tbl_user.sign_img(bytea)에 바로 넣는다 — 파일 되돌리기 보정도 사라졌다
 *   3) 삭제는 validate-delete·delete 양쪽에서 같은 검사를 돌리는 Double Check다
 *
 * PIPELINE[HB94] 사용자 관리 Service
 */
package com.haccp.sys.user;

// 역할 — JWT 테넌트·작업자
import com.haccp.common.context.LoginUserContext;
// 역할 — 업무 예외
import com.haccp.common.exception.BizException;
// 역할 — 삭제 표준 검증
import com.haccp.common.validation.DeleteValidation;
// 역할 — 행·삭제키 정규화 공용 유틸
import com.haccp.sys.SysPayload;
// 역할 — 변경 감사 이력 적재
import com.haccp.sys.auditlog.AuditWriter;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — BCrypt 비밀번호 해시
import org.springframework.security.crypto.bcrypt.BCrypt;
// 역할 — 서비스 등록·트랜잭션
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
// 역할 — Multipart 업로드
import org.springframework.web.multipart.MultipartFile;

// 역할 — 업로드 바이너리 읽기 실패 처리
import java.io.IOException;
// 역할 — 화면 행·삭제키 목록
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class UserService {

    /** 삭제 차단 문구에 쓰는 업무명 */
    private static final String LABEL = "사용자";
    /** 신규 사용자 기본 비밀번호 — 화면에서 비밀번호 컬럼을 받지 않을 때 서버가 채운다 */
    private static final String DEFAULT_NEW_USER_PW = "1234";
    /** 서명 이미지 최대 크기 — 10MB */
    private static final long SIGN_MAX_BYTES = 10L * 1024 * 1024;
    /** 감사 이력 대상 테이블명 — audit-target 공통코드 sub_cd와 같아야 화면에 표시명이 붙는다 */
    private static final String AUDIT_TBL = "tbl_user";

    // 사용자 관리 SP 호출
    private final UserMapper userMapper;
    // 저장·삭제·서명 변경 감사 적재
    private final AuditWriter auditWriter;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 사용자 목록을 조회한다
     *   2) 화면 진입·조회와 로그인 이력 화면의 사용자 트리에서 호출한다
     *   3) 조건에 맞는 사용자가 없으면 빈 목록
     */
    public List<Map<String, Object>> list(
            // 헤더 아이디 검색어. 공백이면 전체
            String userId,
            // 헤더 이름 검색어. 공백이면 전체
            String userNm,
            // 좌측 부서 트리 선택값. 공백이면 전체 부서
            String deptCd,
            // 헤더 사용여부. 공백이면 Y·N 모두
            String useYn
    ) {
        return userMapper.selectRows(LoginUserContext.coCd(),
                text(userId), text(userNm), text(deptCd), text(useYn));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 변경된 사용자 행을 순서대로 저장한다 — 비밀번호는 여기서만 해시된다
     *   2) 저장 버튼에서 호출한다
     *   3) 한 행이라도 실패하면 전체 롤백된다 — 감사 이력도 함께 되돌아간다
     *   4) 감사 이력의 비밀번호 값은 AuditWriter가 가린다 — 변경 사실만 남는다
     */
    @Transactional
    public void save(
            // 화면이 보낸 변경 행 목록 — idx가 없으면 신규
            List<Map<String, Object>> rows
    ) {
        SysPayload.requireRows(rows, LABEL);
        String coCd = LoginUserContext.coCd();
        String actor = LoginUserContext.userId();
        for (Map<String, Object> row : rows) {
            Long idx = SysPayload.idxOrNull(row);
            userMapper.save(
                    coCd,
                    idx,
                    SysPayload.text(row, "userId"),
                    SysPayload.text(row, "empCd"),
                    SysPayload.text(row, "userNm"),
                    hashPassword(idx, SysPayload.text(row, "userPw")),
                    SysPayload.text(row, "usrgrpCd"),
                    SysPayload.text(row, "deptCd"),
                    SysPayload.text(row, "email"),
                    SysPayload.text(row, "mobile"),
                    SysPayload.text(row, "lockYn"),
                    SysPayload.text(row, "useYn"),
                    actor);
            // idx가 null일 때(= 신규 등록) I, 값이 있을 때(= 기존 행 수정) U
            auditWriter.record(AUDIT_TBL, idx, idx == null ? "I" : "U", row);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 삭제 전 참조 차단 여부를 검사한다 (Double Check 1단계)
     *   2) 확인 대화상자 직전에 호출한다
     *   3) 사용자는 차단 사유가 없어 키 형식만 검증된다
     */
    public void validateDelete(
            // 삭제 대상 복합키 배열 — [{ idx }]
            List<Map<String, Long>> keys
    ) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 검증을 다시 수행하고 사용자를 삭제한다 (Double Check 2단계)
     *   2) 사용자가 확인을 누른 뒤 호출한다
     *   3) 개인 설정은 함께 지워지고 작성 문서는 남는다
     */
    @Transactional
    public void delete(
            // 삭제 대상 복합키 배열 — [{ idx }]
            List<Map<String, Long>> keys
    ) {
        List<Long> idxs = assertDeletable(keys);
        String coCd = LoginUserContext.coCd();
        for (Long idx : idxs) {
            userMapper.delete(coCd, idx);
            // 삭제는 남길 변경 후 값이 없으므로 대상 idx만 기록한다
            auditWriter.record(AUDIT_TBL, idx, "D", null);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 로그인 사용자 서명 이미지 바이너리를 반환한다
     *   2) 문서작성 「서명 복사」가 호출한다
     *   3) 미등록이면 업무 오류
     */
    public SignFile loadMySign() {
        return loadSign(LoginUserContext.userId());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 로그인 사용자 서명 보유여부·파일명을 읽는다 — 이미지 바이너리는 읽지 않는다
     *   2) CCP 행 서명처럼 "등록돼 있는지"만 알면 되는 화면이 호출한다
     *   3) 미등록·타 테넌트면 signYn='N', 파일명은 빈 문자열 (예외를 던지지 않는다)
     */
    public Map<String, Object> mySignInfo() {
        Map<String, Object> row = userMapper.selectSignInfo(
                LoginUserContext.coCd(), LoginUserContext.userId());
        // row가 null일 때(= 없는 아이디) 도 화면은 미등록과 똑같이 다루면 되므로 기본값으로 채운다
        String signYn = row == null ? "N" : text((String) row.get("sign_yn"));
        return Map.of(
                "signYn", "Y".equals(signYn) ? "Y" : "N",
                "signNm", row == null ? "" : text((String) row.get("sign_nm")),
                "signMime", row == null ? "" : text((String) row.get("sign_mime"))
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 지정 사용자 서명 바이너리를 DB에서 읽는다 — 파일 시스템을 거치지 않는다
     *   2) 사용자관리 미리보기·서명 복사에서 호출한다
     *   3) 타 테넌트·미등록이면 업무 오류
     */
    public SignFile loadSign(
            // 대상 로그인 아이디
            String userId
    ) {
        String target = text(userId);
        if (target.isEmpty()) throw new BizException("사용자 ID가 올바르지 않습니다.");
        Map<String, Object> row = userMapper.selectSign(LoginUserContext.coCd(), target);
        // row가 null일 때(= 타 테넌트·없는 아이디) 와 sign_img가 null일 때(= 미등록)를 같은 문구로 처리한다
        byte[] content = row == null ? null : (byte[]) row.get("sign_img");
        if (content == null || content.length == 0) {
            throw new BizException("등록된 서명이 없습니다. 시스템관리에서 서명 이미지를 업로드하세요.");
        }
        String name = text((String) row.get("sign_nm"));
        if (name.isEmpty()) name = "sign.png";
        String mime = text((String) row.get("sign_mime"));
        if (mime.isEmpty()) mime = guessImageMime(name);
        return new SignFile(name, mime, content);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 업로드한 서명 이미지를 tbl_user.sign_img에 그대로 넣는다
     *   2) 본인 또는 사용자관리 화면에서 호출한다
     *   3) 대상 사용자가 없으면 SP가 올린 업무 오류가 그대로 나간다
     */
    @Transactional
    public void uploadSign(
            // 대상 로그인 아이디 — 본인이면 JWT userId와 같다
            String userId,
            // 업로드한 서명 이미지 — PNG/JPG 10MB 이하
            MultipartFile file
    ) {
        String target = text(userId);
        if (target.isEmpty()) throw new BizException("사용자 ID가 올바르지 않습니다.");
        assertSignImage(file);

        byte[] content;
        try {
            content = file.getBytes();
        } catch (IOException e) {
            throw new BizException("서명 이미지를 읽을 수 없습니다.");
        }
        String name = text(file.getOriginalFilename());
        if (name.isEmpty()) name = "sign.png";
        String mime = text(file.getContentType());
        if (mime.isEmpty()) mime = guessImageMime(name);

        userMapper.updateSign(LoginUserContext.coCd(), target,
                content, mime, name, LoginUserContext.userId());
        // 서명은 대상 사용자 아이디로만 지정되므로 tgtIdx 없이 아이디·파일명만 남긴다
        auditWriter.record(AUDIT_TBL, null, "U",
                Map.of("userId", target, "sign", "upload", "signNm", name));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 사용자 서명 바이너리를 비운다
     *   2) 사용자관리 서명 팝업 「삭제」에서 호출한다
     *   3) 미등록이면 업무 오류
     */
    @Transactional
    public void deleteSign(
            // 대상 로그인 아이디
            String userId
    ) {
        String target = text(userId);
        if (target.isEmpty()) throw new BizException("사용자 ID가 올바르지 않습니다.");
        String coCd = LoginUserContext.coCd();
        // 유무만 보면 되므로 메타데이터로 확인한다 — 지우려는 이미지를 굳이 읽어 올리지 않는다
        Map<String, Object> row = userMapper.selectSignInfo(coCd, target);
        if (row == null || !"Y".equals(text((String) row.get("sign_yn")))) {
            throw new BizException("등록된 서명이 없습니다.");
        }
        userMapper.updateSign(coCd, target, null, null, null, LoginUserContext.userId());
        // 서명 삭제도 사용자 행 변경이라 U로 남긴다 — 사용자 자체가 지워진 것은 아니다
        auditWriter.record(AUDIT_TBL, null, "U", Map.of("userId", target, "sign", "delete"));
    }

    /** 삭제 대상 idx 정규화 + 참조 검사 — validate·delete가 공유한다 */
    private List<Long> assertDeletable(List<Map<String, Long>> keys) {
        List<Long> idxs = SysPayload.idxList(keys, LABEL);
        DeleteValidation.throwIfBlocked(
                userMapper.selectDeleteBlocker(LoginUserContext.coCd(), idxs), LABEL);
        return idxs;
    }

    /**
     * 신규 행이고 비밀번호가 비었으면 기본값을 쓰고, 값이 있으면 BCrypt 해시로 바꾼다.
     * 수정 행에서 비었을 때(= 변경 안 함) 빈 문자열 그대로 넘겨 SP가 기존 해시를 유지하게 한다.
     */
    private String hashPassword(Long idx, String rawPassword) {
        String password = rawPassword;
        if (idx == null && password.isEmpty()) password = DEFAULT_NEW_USER_PW;
        return password.isEmpty() ? "" : BCrypt.hashpw(password, BCrypt.gensalt());
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

    /** 서명 다운로드 응답용 — 파일명·MIME·이미지 바이너리 */
    public record SignFile(String fileNm, String mimeType, byte[] content) {}
}
