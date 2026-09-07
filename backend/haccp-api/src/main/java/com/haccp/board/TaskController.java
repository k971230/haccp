/**
 * TaskController — 오늘 할 일·알림 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 오늘 할 일·알림 API를 전용 경로로 제공한다
 *   2) 회사·작업자 정보는 요청값이 아니라 JWT 컨텍스트에서 결정한다
 *   3) 감사자료 API는 화면이 없어 지웠다
 *
 * PIPELINE[HB95] 워크플로 작업 Controller
 * PIPELINE[HB93, HB94, HF87] 연관 모듈
 */
package com.haccp.board;

// 역할 — 공통 응답
import com.haccp.common.response.CommonResponse;
// 역할 — 목록
import java.util.List;
import java.util.Map;
// 역할 — Spring REST 매핑
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
public class TaskController {
    private final TaskService service;

    @GetMapping("/api/v1/board/today-tasks/list")
    public CommonResponse<List<com.haccp.board.dto.TodayTaskRow>> todayTasks() { return CommonResponse.ok(service.todayTasks()); }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 오늘 할 일 최근 문서를 기간 + OFFSET/LIMIT 으로 조회한다
     *   2) 랜딩 최근 문서 패널이 호출한다. 문서함 /docs/documents/list 는 그대로 둔다
     *   3) 성공 시 { rows, total }. total 은 기간 전체 건수
     */
    @GetMapping("/api/v1/board/today-tasks/recent-docs")
    public CommonResponse<com.haccp.board.dto.TodayTaskDocsResponse> todayTaskDocs(
            // 기준일 시작 YYYYMMDD
            @RequestParam(required = false) String fromDt,
            // 기준일 종료 YYYYMMDD
            @RequestParam(required = false) String toDt,
            // 건너뛸 행 수 — 첫 페이지는 0
            @RequestParam(required = false) Integer offset,
            // 가져올 행 수 — 화면 기본 20
            @RequestParam(required = false) Integer limit
    ) {
        return CommonResponse.ok(service.todayTaskDocs(fromDt, toDt, offset, limit));
    }

    /** 안 읽은 알림 목록 — 셸 종 아이콘이 호출한다 */
    @GetMapping("/api/v1/board/notifications/list")
    public CommonResponse<List<com.haccp.board.dto.NotificationRow>> notifications() { return CommonResponse.ok(service.notifications()); }

    /** 알림 1건을 읽음 처리한다 */
    @PutMapping("/api/v1/board/notifications/{idx}/read")
    public CommonResponse<Void> readNotification(@PathVariable Long idx) { service.readNotification(idx); return CommonResponse.ok(null); }
}
