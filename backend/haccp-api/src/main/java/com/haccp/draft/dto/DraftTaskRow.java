/**
 * DraftTaskRow — 오늘 할일 문서주기 1건.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) HWP 작성 화면의 행 추가 팝업이 쓴다 — 오늘 처리해야 할 문서주기 목록이다
 *   2) 양식코드를 함께 내려야 고른 즉시 rhwp 에 그 양식을 열 수 있다
 *   3) docIdx 가 있으면 이미 만들어진 문서다 — 새로 만들지 않고 그 문서를 연다
 *
 * FE 대응 타입은 api/draft/htmlFormDraftTypes.ts 의 HtmlFormDraftTask 다.
 *
 * PIPELINE[HB144] HWP 작성 DTO
 */
package com.haccp.draft.dto;

import lombok.Data;

@Data
public class DraftTaskRow {
    // tbl_schedule_task.idx — 팝업 그리드 행 키
    private Long taskIdx;
    // 양식코드 — 고르면 이 양식을 rhwp 에 연다
    private String tmplCd;
    // 양식명 — 자사 양식명(tmpl_nm_ovr) 우선
    private String tmplNm;
    // 기준일 YYYYMMDD
    private String baseDt;
    // 마감일 YYYYMMDD
    private String dueDt;
    // 마감시각 HH:MM — 없을 수 있다
    private String dueTime;
    // 할일 상태 — TODO 예정 · ING 진행 · LATE 지연
    private String status;
    // 이미 만들어진 문서 idx — 없으면 신규 작성이다
    private Long docIdx;
}
