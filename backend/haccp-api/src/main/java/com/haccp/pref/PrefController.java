/**
 * PrefController — 그리드 열 설정 REST API (/api/v1/pref/grid).
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) GET /list — 화면 진입 시 그 화면의 그리드 설정 전체를 목록으로 받는다
 *   2) PUT /save — 열 너비·표시여부 변경을 업서트한다. prefJson이 비면 초기화(행 삭제)로 동작한다
 *   3) 회사코드·사용자 아이디는 요청에서 받지 않고 JWT에서만 읽는다 — 남의 설정을 덮어쓰는 경로를 없앤다
 *
 * PIPELINE[HB42] REST Controller
 * PIPELINE[HB40, HB41] 연관 모듈
 */
package com.haccp.pref;

// 역할 — 요청 스코프 컨텍스트 — coCd·userId
import com.haccp.common.context.LoginUserContext;
// 역할 — API 공통 응답 래퍼
import com.haccp.common.response.CommonResponse;
// 역할 — 그리드 설정 Row DTO
import com.haccp.pref.dto.GridPrefRow;
// 역할 — 그리드 설정 저장 요청 DTO
import com.haccp.pref.dto.GridPrefSaveRequest;
// 역할 — @NotBlank 등 Bean Validation 실행
import jakarta.validation.Valid;
// 역할 — @RequiredArgsConstructor 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — CUD 트랜잭션 경계
import org.springframework.transaction.annotation.Transactional;
// 역할 — REST 매핑 어노테이션
import org.springframework.web.bind.annotation.*;

// 역할 — 설정 목록
import java.util.List;

/** 사용자별 그리드 열 설정 → /api/v1/pref/grid/* */
@RestController
@RequestMapping("/api/v1/pref/grid")
@RequiredArgsConstructor
public class PrefController {

    // 그리드 설정 SP 호출
    private final PrefMapper prefMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 사용자의 그리드 열 설정 목록을 조회해 반환한다
     *   2) 업무 화면이 마운트될 때 1회 호출한다
     *   3) 저장 이력이 없으면 빈 목록을 반환한다 — 프론트는 컬럼 정의 기본값을 쓴다
     */
    @GetMapping("/list")
    public CommonResponse<List<GridPrefRow>> list(
            // 화면코드 — 이 화면에 속한 그리드 설정만 받는다. SP가 부분 일치로 비교하므로
            // 빈 문자열이면 이 사용자의 전체 화면 설정이 나온다(설정 이관·진단 용도)
            @RequestParam(required = false, defaultValue = "") String scrnCd
    ) {
        return CommonResponse.ok(
                prefMapper.selectGridPrefs(LoginUserContext.coCd(), LoginUserContext.userId(), scrnCd));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 그리드 열 설정을 저장하거나, 빈 JSON이면 초기화한다
     *   2) 사용자가 열 너비·표시여부를 바꾼 뒤 저장을 누를 때 호출한다
     *   3) 성공 시 data가 없는 성공 응답을 반환하고, DB 실패 시 트랜잭션을 롤백한다
     */
    @PutMapping("/save")
    @Transactional
    public CommonResponse<Void> save(
            // 저장 요청 본문 — scrnCd·gridId는 필수, prefJson은 비면 초기화 신호로 쓰인다
            // 회사코드·사용자 아이디 필드는 일부러 두지 않았다. 서버가 JWT에서 채운다
            @Valid @RequestBody GridPrefSaveRequest req
    ) {
        // PG CALL은 영향 행 수를 돌려주지 않아 JDBC가 -1을 반환한다.
        // 그 값을 그대로 응답에 실으면 "1건 저장"으로 오해할 여지가 있어 반환하지 않는다
        prefMapper.saveGridPref(
                LoginUserContext.coCd(), LoginUserContext.userId(),
                req.getScrnCd(), req.getGridId(), req.getPrefJson());
        return CommonResponse.ok(null);
    }
}
