/**
 * CcpLogDraftSaveRequest — 작성 저장 본문.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) CCP 포장·가열·금속검출 작성 3화면이 같은 DTO 를 쓴다. 화면마다 복제하지 않는다
 *   2) 모양은 HYG(draft.hyg)·CCP검증(draft.ccp)과 같다. 서버 테이블·SP 만 계열별로 다르다
 *   3) 전송 전이라 필수값은 검사하지 않는다. 필수값은 전송 직전에 화면이 본다
 *
 * PIPELINE[HB139] CCP 모니터링 작성 DTO
 */
package com.haccp.draft.ccpmonitoring.dto;

import com.haccp.docs.ccp.dto.DocCorrectiveDto;
import java.util.List;
import lombok.Data;

@Data
public class CcpLogDraftSaveRequest {
    // 작성 양식코드 — tml_ccp_pkg_NNN / tml_ccp_htg_NNN / tml_ccp_mtl_NNN. 필수
    private String tmplCd;
    // 기존 문서 idx — 신규면 null/0
    private Long docIdx;
    // 일자(작성일) YYYYMMDD
    private String baseDt;
    // 관리자·점검자명 — 헤더
    private String checkerNm;
    // 승인자명 — 헤더
    private String approverNm;
    // 적용 버전 — 자사 양식은 1
    private Integer verNo;
    // 기록 표 행 — 작업 전/작업 종료가 phaseCd 로 섞여 온다
    private List<CcpLogDraftRow> logRows;
    // 금속 통과량 표 행 — MTL 만
    private List<CcpLogDraftPassRow> passRows;
    // 지면 하단 4칸 — 신규 컬럼 없이 tbl_corrective_action 에 저장한다
    private String specialNote;
    private String improveNote;
    private String actionNm;
    private String confirmNm;
    // 이탈·개선조치 푸터 — 화면이 따로 넘기면 우선
    private DocCorrectiveDto corrective;
}
