/**
 * CcpHtgDraftService — CCP 가열 모니터링일지 작성 업무.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 표는 tbl_ccp_htg_monitor(+_row·_cell). 포장·금속과 섞지 않는다
 *   2) cells 는 HtgLogCells(temp·time)
 *   3) 조립은 CcpMonitorDraftSupport
 *
 * PIPELINE[HB142] CCP 가열 작성 Service
 */
package com.haccp.draft.ccpmonitoring;

import com.haccp.draft.dto.CcpMonitorDraftDetail;
import com.haccp.draft.dto.DraftDeleteItem;
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import com.haccp.draft.dto.DraftSaveRequest;
import com.haccp.draft.dto.HtgLogCells;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class CcpHtgDraftService implements CcpMonitorDraftFacade {

    /** 가열 자사 양식 접두 */
    public static final String PREFIX = "html_ccp_htg_";
    /** 가열 표준 예시 양식 — 작성에 쓰지 않는다 */
    public static final String STD = "html_ccp_htg_000";

    private final CcpHtgDraftMapper mapper;
    private final CcpMonitorDraftSupport support;

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 작성에 쓸 수 있는 가열 자사 양식만 반환한다
     *   2) 화면 진입 시 한 번 호출한다
     *   3) 없으면 빈 목록
     */
    @Override
    public List<DraftFormRow> forms() {
        return support.forms(mapper, STD);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 가열 작성 목록을 조회한다
     *   2) 조회 버튼·저장 후 호출한다
     *   3) 결재 여부는 화면이 거른다
     */
    @Override
    public List<DraftListRow> list(
            String tmplCd, String tmplNm, String fromDt, String toDt,
            String writerId, String writerNm, String title
    ) {
        return support.list(mapper, tmplCd, tmplNm, fromDt, toDt, writerId, writerNm, title);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 가열 문서 1건의 지면 값을 내린다
     *   2) 좌측 행 클릭·양식 선택이 호출한다
     *   3) 신규면 작업 전/종료 시드 행
     */
    @Override
    public CcpMonitorDraftDetail detail(String tmplCd, Long docIdx) {
        return support.detail(mapper, PREFIX, STD, tmplCd, docIdx);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 가열 헤더·기록행을 저장한다
     *   2) 저장 버튼이 호출한다
     *   3) cells 는 HtgLogCells
     */
    @Override
    public Long save(DraftSaveRequest req) {
        return support.save(mapper, PREFIX, STD, req, HtgLogCells.class);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) 확인창 전에 호출한다
     *   3) 전송·결재완료 문서는 차단
     */
    @Override
    public void validateDelete(List<DraftDeleteItem> keys) {
        support.validateDelete(mapper, keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 재검증 후 문서·기록행을 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) 성공 시 건수
     */
    @Override
    public int delete(List<DraftDeleteItem> keys) {
        return support.delete(mapper, keys);
    }
}
