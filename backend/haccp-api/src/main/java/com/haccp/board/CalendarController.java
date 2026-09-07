/**
 * CalendarController — 일정 캘린더 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 월 조회·영업일 전환 저장만 제공한다
 *   2) 회사·작업자는 JWT에서만 읽는다
 *   3) /save 는 화면 write/modify 권한으로 막힌다
 *
 * PIPELINE[HB212] 일정 캘린더 Controller
 */
package com.haccp.board;

// 역할 — 공통 응답
import com.haccp.board.dto.CalendarMonthResponse;
import com.haccp.board.dto.CalendarSaveItem;
import com.haccp.common.response.CommonResponse;
// 역할 — 목록
import java.util.List;
// 역할 — Spring REST
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/board/calendar")
@RequiredArgsConstructor
public class CalendarController {

    private final CalendarService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 한 달치 과제·공휴일·영업일 전환을 조회한다
     *   2) 캘린더 화면이 month=YYYYMM 으로 호출한다
     *   3) 성공 시 { month, tasks, holidays, workdays }
     */
    @GetMapping("/list")
    public CommonResponse<CalendarMonthResponse> list(
            // 조회 월 YYYYMM — 비면 이번 달
            @RequestParam(required = false) String month
    ) {
        return CommonResponse.ok(service.list(month));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 영업일 전환 변경분을 저장한다
     *   2) 캘린더 저장 버튼에서 호출한다
     *   3) 본문은 [{ ymd, workYn }]
     */
    @PutMapping("/save")
    public CommonResponse<Void> save(
            // 변경분 — ymd YYYYMMDD, workYn Y/N
            @RequestBody List<CalendarSaveItem> items
    ) {
        service.save(items);
        service.regenerateAfterSave();
        return CommonResponse.ok(null);
    }
}
