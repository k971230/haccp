/**
 * DraftLogRow — 기록 표 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) CCP 포장·가열·금속검출 작성 3화면이 같은 DTO 를 쓴다. 화면마다 복제하지 않는다
 *   2) phaseCd 로 작업 전/작업 종료를 가른다 — 화면 DOM 위치가 아니라 이 값이 정본이다.
 *      재조회 때도 이 값으로 같은 영역에 복원된다
 *   3) 양식마다 다른 칸은 cells(item_cd → 값) 한 곳에 담는다. 서비스가 계열별 컬럼으로 편다
 *      PKG temp·min·sec / HTG temp·time / MTL hdr-fe·hdr-sus·hdr-prod·hdr-fe-prod·hdr-sus-prod
 *
 * FE 대응 타입은 components/form/htmlFormPaperShared.tsx 의 HtmlFormLogRow 다.
 *
 * PIPELINE[HB139] CCP 모니터링 작성 DTO
 */
package com.haccp.draft.dto;

import java.util.Map;
import lombok.Data;

@Data
public class DraftLogRow {
    // 저장 순번 — 영역 안 정렬. 영역이 달라도 유일하다
    private Integer rowSeq;
    // 작업 전 BEFORE / 작업 종료 AFTER — DB phase_cd
    private String phaseCd;
    // 품명
    private String productNm;
    // 측정시각·통과시간
    private String checkTime;
    // 판정 P=적합 F=부적합. 금속은 서버가 자동 판정하고 사용자가 고치면 judgeModYn=Y
    private String judgeCd;
    // 판정 수동수정 여부 Y/N
    private String judgeModYn;
    // 행 서명 사용자 ID
    private String checkerId;
    // 행 서명 이름
    private String checkerNm;
    // 서명 이미지 스냅샷 여부 Y/N
    private String signYn;
    // 양식별 입력칸 — PKG temp·min·sec / HTG temp·time / MTL fe-only·sts-only·prod-only·fe-prod·sts-prod
    private Map<String, String> cells;
}
