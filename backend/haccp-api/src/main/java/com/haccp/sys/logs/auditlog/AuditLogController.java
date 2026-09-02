/**
 * AuditLogController — 변경 감사 이력 REST API (/api/v1/sys/logs/audit-log).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 조회 전용 화면이라 list 하나만 연다 — 이력은 수정·삭제할 수 없다
 *   2) 회사코드는 JWT에서만 읽는다
 *   3) 기간이 비면 오늘로 채우고, 8자리가 아니면 업무 오류로 끝낸다
 *
 * PIPELINE[HB93] 감사 이력 REST Controller
 */
package com.haccp.sys.logs.auditlog;

// 역할 — API 성공 응답 래퍼
import com.haccp.common.response.CommonResponse;
// 역할 — 기간 정규화 공용 유틸
import com.haccp.sys.SysPayload;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — REST 매핑
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

// 역할 — 이력 행 목록
import java.util.List;
import java.util.Map;

/** 변경 감사 이력 화면 → /api/v1/sys/logs/audit-log/* */
@RestController
@RequestMapping("/api/v1/sys/logs/audit-log")
@RequiredArgsConstructor
public class AuditLogController {

    // 감사 이력 조회 업무 로직
    private final AuditLogService auditLogService;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 기간 내 변경 감사 이력을 반환한다
     *   2) 화면 진입·조회와 좌측 메뉴 트리 선택 시 호출한다
     *   3) 해당 기간에 이력이 없으면 빈 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<Map<String, Object>>> list(
            // 조회 시작일 — YYYY-MM-DD 또는 YYYYMMDD. 미입력이면 오늘
            @RequestParam(required = false) String fromDt,
            // 조회 종료일 — YYYY-MM-DD 또는 YYYYMMDD. 미입력이면 오늘
            @RequestParam(required = false) String toDt,
            // 좌측 메뉴 트리 선택값(화면코드) — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String menuKey,
            // 행위자 아이디 검색어 — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String userId,
            // 행위 필터 I|U|D|APV|RJT 등 — 미입력이면 전체
            @RequestParam(required = false, defaultValue = "") String actionCd
    ) {
        return CommonResponse.ok(auditLogService.list(
                SysPayload.normalizeDate(fromDt), SysPayload.normalizeDate(toDt),
                menuKey, userId, actionCd));
    }
}
