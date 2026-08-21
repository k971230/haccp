/**
 * ColdMonitorRowDto — 점검시간 행 + 온도 셀.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 상세 조회·저장 요청이 공유하는 행 구조다
 *   2) judgeModYn=Y일 때(= 수동 판정) judgeCd를 SP가 존중한다
 *   3) temps는 사용 중인 보관고 수만큼 온다
 *
 * PIPELINE[HB65] ccp DTO
 */
package com.haccp.docs.ccp.dto;

import java.util.ArrayList;
import java.util.List;
import lombok.Data;

@Data
public class ColdMonitorRowDto {
    // 행 대리키 — 조회 시에만 채워진다
    private Long idx;
    // 행 순번 1부터
    private Integer rowSeq;
    // 점검시간 HHMM
    private String checkTime;
    // 행 판정 P/F
    private String judgeCd;
    // 판정 수동변경 Y/N
    private String judgeModYn;
    // 점검자 ID
    private String checkerId;
    // 점검자명 스냅샷
    private String checkerNm;
    // 작성자 로그인 ID — 행별 (로그인 기본)
    private String writerId;
    // 작성자명 스냅샷 — 행별 편집
    private String writerNm;
    // 행 서명 보유여부 Y/N — 저장 시 Y면 SP가 점검자 서명 원본을 스냅샷으로 복사한다
    private String signYn;
    // 보관고별 온도
    private List<ColdMonitorTempCell> temps = new ArrayList<>();
}
