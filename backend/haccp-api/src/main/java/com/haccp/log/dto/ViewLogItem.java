/**
 * ViewLogItem.java — 화면 조회 이벤트 1건 DTO.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 프론트가 탭 진입·이탈 시각을 모아 배치로 보내는 이벤트 한 건이다
 *   2) 체류시간(stay_sec)은 서버 SP가 두 시각의 차이로 계산한다 — 프론트가 보낸 초 값을 믿지 않는다
 *   3) 회사코드·아이디·세션은 담지 않는다. JWT에서 채우므로 프론트가 조작할 수 없다
 *
 * PIPELINE[HB43] log DTO
 */
package com.haccp.log.dto;

// 역할 — 공백 입력 차단
import jakarta.validation.constraints.NotBlank;
// 역할 — 진입 일시 필수 검증
import jakarta.validation.constraints.NotNull;
// 역할 — @Getter/@Setter 접근자 (Jackson 역직렬화 대상)
import lombok.Getter;
import lombok.Setter;

// 역할 — 진입·이탈 일시 타입
import java.time.LocalDateTime;

/** 화면 조회 이벤트 1건 — { scrnCd, enterDt, leaveDt, refScrnCd } */
@Getter
@Setter
public class ViewLogItem {

    /** 조회한 화면코드 — tbl_screen.scrn_cd */
    @NotBlank(message = "화면코드가 필요합니다.")
    private String scrnCd;

    /** 화면 진입 일시 — 탭이 활성으로 바뀐 시각 (클라이언트 시각) */
    @NotNull(message = "화면 진입 일시가 필요합니다.")
    private LocalDateTime enterDt;

    /**
     * 화면 이탈 일시.
     * null이면(= 아직 그 화면에 머무는 중) 체류시간도 null로 저장된다.
     */
    private LocalDateTime leaveDt;

    /** 직전 화면코드 — 이동 경로 분석용. 첫 진입이면 비어 있다 */
    private String refScrnCd;
}
