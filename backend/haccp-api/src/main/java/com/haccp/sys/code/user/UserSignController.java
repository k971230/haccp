/**
 * UserSignController — 사용자 서명 이미지 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 서명은 화면 하나가 아니라 결재·문서 여러 화면이 함께 쓴다 — 그래서 화면 경로가 아니다
 *   2) 회사코드·본인 아이디는 JWT 에서만 읽는다
 *   3) UserController 에서 갈라냈다. 한 클래스에 base 가 다른 두 갈래를 담고 있어
 *      형제 화면처럼 @GetMapping("/list") 를 적으면 엉뚱한 URL 이 되던 것을 막는다
 *
 * PIPELINE[HB93] 사용자 서명 REST Controller
 */
package com.haccp.sys.code.user;

// 역할 — JWT 로그인 아이디
import com.haccp.common.context.LoginUserContext;
// 역할 — API 성공 응답 래퍼
import com.haccp.common.response.CommonResponse;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — 이미지 응답·REST 매핑
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

// 역할 — 파일명 인코딩·응답 맵
import java.nio.charset.StandardCharsets;
import java.util.Map;

/** 사용자 서명 → /api/v1/sys/users/* — 화면 API 가 아니라 여러 화면 공용이다 */
@RestController
@RequestMapping("/api/v1/sys/users")
@RequiredArgsConstructor
public class UserSignController {

    // 사용자·서명 업무 로직 — 화면 쪽과 같은 서비스를 쓴다
    private final UserService userService;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 로그인 사용자 서명 보유여부·파일명을 내려준다 — 이미지 바이너리는 싣지 않는다
     *   2) 냉장·CCP 일지가 행 서명 버튼을 누를 때 "등록됐는지"만 확인하려고 호출한다
     *   3) 미등록이어도 200이며 signYn='N'이다 — 화면은 이 값으로 업로드 유도를 결정한다
     */
    @GetMapping("/me/sign-info")
    public CommonResponse<Map<String, Object>> mySignInfo() {
        return CommonResponse.ok(userService.mySignInfo());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 로그인 사용자 서명 이미지를 내려준다
     *   2) 문서작성 「서명 복사」와 서명 팝업 미리보기가 httpFile로 호출한다
     *   3) 미등록이면 업무 오류
     */
    @GetMapping("/me/sign")
    public ResponseEntity<byte[]> mySign() {
        return signResponse(userService.loadMySign());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 지정 사용자 서명 이미지를 내려준다
     *   2) 사용자 관리 서명 팝업 미리보기에서 호출한다
     *   3) 미등록이면 업무 오류
     */
    @GetMapping("/{userId}/sign")
    public ResponseEntity<byte[]> userSign(
            // 대상 로그인 아이디
            @PathVariable String userId
    ) {
        return signResponse(userService.loadSign(userId));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 로그인 사용자 서명 이미지를 업로드한다 — tbl_user.sign_img에 바이너리로 들어간다
     *   2) 시스템관리·문서작성에서 본인 서명을 등록할 때 호출한다
     *   3) 성공 시 본문 없음 — 화면은 필요할 때 /users/me/sign으로 실물을 다시 받는다
     */
    @PostMapping(value = "/me/sign", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CommonResponse<Void> uploadMySign(
            // 업로드한 서명 이미지 — form field name=file
            @RequestPart("file") MultipartFile file
    ) {
        userService.uploadSign(LoginUserContext.userId(), file);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 지정 사용자 서명 이미지를 업로드한다
     *   2) 사용자 관리 화면의 서명 업로드 버튼이 호출한다
     *   3) 성공 시 본문 없음
     */
    @PostMapping(value = "/{userId}/sign", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CommonResponse<Void> uploadUserSign(
            // 대상 로그인 아이디
            @PathVariable String userId,
            // 업로드한 서명 이미지 — form field name=file
            @RequestPart("file") MultipartFile file
    ) {
        userService.uploadSign(userId, file);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 지정 사용자 서명을 삭제한다 — tbl_user.sign_img를 NULL로 비운다
     *   2) 사용자관리 서명 팝업 「삭제」가 호출한다 (HTTP DELETE 금지 → POST)
     *   3) 미등록이면 업무 오류
     */
    @PostMapping("/{userId}/sign/delete")
    public CommonResponse<Void> deleteUserSign(
            // 대상 로그인 아이디
            @PathVariable String userId
    ) {
        userService.deleteSign(userId);
        return CommonResponse.ok(null);
    }

    /** 서명 바이너리를 inline 이미지 응답으로 감싼다 — 파일명은 UTF-8로 인코딩한다 */
    private ResponseEntity<byte[]> signResponse(UserService.SignFile file) {
        MediaType mediaType;
        try {
            mediaType = MediaType.parseMediaType(file.mimeType());
        } catch (Exception e) {
            // MIME 값이 깨졌을 때(= 구 데이터) 다운로드로 떨어뜨려 화면 오류로 번지지 않게 한다
            mediaType = MediaType.APPLICATION_OCTET_STREAM;
        }
        return ResponseEntity.ok()
                .contentType(mediaType)
                .contentLength(file.content().length)
                .header(
                        HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.inline()
                                .filename(file.fileNm(), StandardCharsets.UTF_8)
                                .build()
                                .toString()
                )
                .body(file.content());
    }
}
