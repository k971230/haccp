/**
 * CcpMonitorDraftFacade — 포장·가열 작성 컨트롤러 계약.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 컨트롤러 베이스가 Family 를 몰라도 되게 서비스가 계열을 숨긴다
 *   2) 포장·가열 서비스가 이 계약을 구현한다
 *   3) 금속은 delete 시그니처가 달라 여기 안 넣는다
 *
 * PIPELINE[HB140] CCP 모니터링 작성 Controller
 */
package com.haccp.draft.ccpmonitoring;

import com.haccp.draft.dto.CcpMonitorDraftDetail;
import com.haccp.draft.dto.DraftDeleteItem;
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import com.haccp.draft.dto.DraftSaveRequest;
import java.util.List;

public interface CcpMonitorDraftFacade {

    List<DraftFormRow> forms();

    List<DraftListRow> list(
            String tmplCd, String tmplNm, String fromDt, String toDt,
            String writerId, String writerNm, String title
    );

    CcpMonitorDraftDetail detail(String tmplCd, Long docIdx);

    Long save(DraftSaveRequest req);

    void validateDelete(List<DraftDeleteItem> keys);

    int delete(List<DraftDeleteItem> keys);
}
