/**
 * NotificationRow — 알림 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_notification_r_000 컬럼과 1:1
 *   2) linkScrnCd·linkDocIdx 로 화면이 연다
 *   3) 본인 알림만 온다
 *
 * PIPELINE[HB94] 알림 DTO
 */
package com.haccp.board.dto;

import java.time.LocalDateTime;
import lombok.Data;

/** 알림함 1건 */
@Data
public class NotificationRow {
    private Long idx;
    private String notiTypeCd;
    private String title;
    private String content;
    private String linkScrnCd;
    private Long linkDocIdx;
    private String readYn;
    private LocalDateTime insDt;
}
