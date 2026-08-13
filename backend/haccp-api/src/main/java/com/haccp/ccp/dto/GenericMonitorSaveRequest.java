/**
 * GenericMonitorSaveRequest — 공통 CCP 모니터링 저장 요청.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 냉장·금속 외 CCP 공정의 문서 헤더와 동적 측정 셀을 한 요청으로 전달한다
 *   2) cells는 limitItemKind 프리셋에 따라 숫자 또는 텍스트 값을 담는 EAV 배열이다
 *   3) 회사·사용자 키는 포함하지 않고 Service가 JWT 컨텍스트에서만 채운다
 *
 * PIPELINE[HB94] 공통 CCP 저장 DTO
 * PIPELINE[HB71, HF94] 연관 모듈
 */
package com.haccp.ccp.dto;

// 역할 — 요청 목록
import java.util.List;
// 역할 — Lombok 접근자
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class GenericMonitorSaveRequest {
    // 기존 문서 idx — null/0이면 신규 문서
    private Long docIdx;
    // 기준일 YYYYMMDD
    private String baseDt;
    // 내부 공통 CCP 템플릿 코드 — tmpl_ccp-heat-log 등
    private String tmplCd;
    // 회사별 CCP 코드 — 미지정 허용
    private String ccpCd;
    // 스마트 HACCP 기준일지 외부 코드
    private String diaryNo;
    // 동적 측정 셀 프리셋 코드
    private String limitItemKind;
    // 담당자 ID·이름
    private String mngUserId;
    private String mngNm;
    // 시간별 점검 행
    private List<GenericMonitorRow> rows;

    @Getter
    @Setter
    public static class GenericMonitorRow {
        // 화면 행 순번
        private Integer rowSeq;
        // 점검 시각
        private String checkTime;
        // 설비명 — 측정 셀 앞
        private String equipNm;
        // 품명 — 측정 셀 앞
        private String productNm;
        // 행 판정 P/F 또는 O/X
        private String judgeCd;
        // 사용자가 직접 판정했는지 여부
        private String judgeModYn;
        // 점검자 ID·이름
        private String checkerId;
        private String checkerNm;
        // 행 서명 보유여부 Y/N — 저장 시 Y면 SP가 점검자 서명 원본을 스냅샷으로 복사한다
        private String signYn;
        // 항목별 동적 측정 셀
        private List<GenericMonitorCell> cells;
    }

    @Getter
    @Setter
    public static class GenericMonitorCell {
        // 프리셋 항목 코드 — TEMP, TIME 등
        private String itemCd;
        // 수치형 측정값
        private java.math.BigDecimal numVal;
        // 텍스트형 측정값
        private String txtVal;
        // 셀 판정
        private String judgeCd;
    }
}
