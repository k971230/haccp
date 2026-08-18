/**
 * ScreenUsageController — 화면 이용 통계 REST API (/api/v1/sys/screen-usage-statistics).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 조회 전용 화면이라 list 하나만 연다 — 집계 적재는 log 배치가 담당한다
 *   2) 회사코드는 JWT에서만 읽는다
 *   3) 기간이 비면 오늘로 채우고, 8자리가 아니면 업무 오류로 끝낸다
 *
 * PIPELINE[HB93] 화면 이용 통계 REST Controller
 */
package com.haccp.sys.screenusage;

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

// 역할 — 통계 행 목록
import java.util.List;
import java.util.Map;

/** 화면 이용 통계 화면 → /api/v1/sys/screen-usage-statistics/* */
@RestController
@RequestMapping("/api/v1/sys/screen-usage-statistics")
@RequiredArgsConstructor
public class ScreenUsageController {

    // 화면 이용 통계 조회 업무 로직
    private final ScreenUsageService screenUsageService;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 기간 내 화면별 이용 통계를 반환한다
     *   2) 화면 진입·조회와 좌측 메뉴 트리 선택 시 호출한다
     *   3) 집계가 아직 없으면 빈 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<Map<String, Object>>> list(
            // 집계 시작일 — YYYY-MM-DD 또는 YYYYMMDD. 미입력이면 오늘
            @RequestParam(required = false) String fromDt,
            // 집계 종료일 — YYYY-MM-DD 또는 YYYYMMDD. 미입력이면 오늘
            @RequestParam(required = false) String toDt,
            // 좌측 메뉴 트리에서 고른 화면코드 — 미입력이면 전체 화면
            @RequestParam(required = false, defaultValue = "") String scrnCd
    ) {
        return CommonResponse.ok(screenUsageService.list(
                SysPayload.normalizeDate(fromDt), SysPayload.normalizeDate(toDt), scrnCd));
    }
}
