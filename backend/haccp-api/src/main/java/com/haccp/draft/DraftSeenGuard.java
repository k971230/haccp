/**
 * DraftSeenGuard — 문서 초안 동시 저장 스탬프.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 상세 응답에 updDt 를 붙이고, 저장 직전에 화면이 본 값과 대조한다
 *   2) 작성 4서비스가 같은 가드를 쓴다 — 전 표 version 락은 두지 않는다
 *   3) 신규(docIdx 없음)·빈 스탬프는 통과. 어긋나면 SP 가 45000
 *
 * PIPELINE[HB135] 양식 작성 공용 유틸
 */
package com.haccp.draft;

import com.fasterxml.jackson.databind.node.ObjectNode;
import com.haccp.common.context.LoginUserContext;
import com.haccp.docs.documents.dto.DocumentDetailResponse;
import com.haccp.draft.dto.CcpMonitorDraftDetail;
import com.haccp.draft.dto.DraftSaveRequest;
import com.haccp.draft.dto.HtmlFormDraftDetail;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/** 초안 seen_upd_dt 조회·대조 */
@Component
@RequiredArgsConstructor
public class DraftSeenGuard {

    // 스탬프 SP
    private final DraftSeenMapper mapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 상세 JSON 루트에 updDt 를 붙인다
     *   2) HTML·CCP 작성 상세가 호출한다
     *   3) 신규면 null. 저장된 문서면 현재 스탬프
     */
    public void attach(
            // 상세 루트 — header·items 와 같은 레벨
            ObjectNode root,
            // tbl_document.idx. null·0 이면 신규
            Long docIdx
    ) {
        if (root == null) {
            return;
        }
        String seen = read(docIdx);
        if (seen == null || seen.isBlank()) {
            root.putNull("updDt");
        } else {
            root.put("updDt", seen);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 상세 Map 루트에 updDt 를 붙인다
     *   2) HWP 작성 상세가 호출한다
     *   3) 신규면 null. 저장된 문서면 현재 스탬프
     */
    public void attach(
            // 문서 허브 상세 Map
            Map<String, Object> out,
            // tbl_document.idx
            Long docIdx
    ) {
        if (out == null) {
            return;
        }
        out.put("updDt", read(docIdx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 상세 DTO 루트에 updDt 를 붙인다
     *   2) HTML·CCP 작성 상세가 호출한다
     *   3) 신규면 null. 저장된 문서면 현재 스탬프
     */
    public void attach(
            // 상세 루트 — header·items 와 같은 레벨
            HtmlFormDraftDetail root,
            // tbl_document.idx. null·0 이면 신규
            Long docIdx
    ) {
        if (root == null) {
            return;
        }
        String seen = read(docIdx);
        root.setUpdDt(seen == null || seen.isBlank() ? null : seen);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) CCP 상세 루트에 updDt 를 붙인다
     *   2) 포장·가열·금속 작성이 호출한다
     *   3) 신규면 null. 저장된 문서면 현재 스탬프
     */
    public void attach(
            // CCP 상세 루트
            CcpMonitorDraftDetail root,
            // tbl_document.idx. null·0 이면 신규
            Long docIdx
    ) {
        if (root == null) {
            return;
        }
        String seen = read(docIdx);
        root.setUpdDt(seen == null || seen.isBlank() ? null : seen);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 문서 허브 상세에 updDt 를 붙인다
     *   2) HWP 작성 상세가 호출한다
     *   3) 신규면 null. 저장된 문서면 현재 스탬프
     */
    public void attach(
            // 문서 허브 상세
            DocumentDetailResponse out,
            // tbl_document.idx
            Long docIdx
    ) {
        if (out == null) {
            return;
        }
        String seen = read(docIdx);
        out.setUpdDt(seen == null || seen.isBlank() ? null : seen);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 화면이 본 스탬프와 DB 가 같아야 저장을 이어간다
     *   2) 작성 저장 직전에 호출한다
     *   3) 신규·빈 스탬프는 통과. 어긋나면 SP 45000
     */
    public void assertSeen(
            // 저장 본문 — docIdx·seenUpdDt
            DraftSaveRequest req
    ) {
        if (req == null) {
            return;
        }
        Long docIdx = req.getDocIdx();
        if (docIdx == null || docIdx <= 0) {
            return;
        }
        mapper.assertSeen(LoginUserContext.coCd(), docIdx, DraftSupport.nvl(req.getSeenUpdDt()));
    }

    private String read(Long docIdx) {
        if (docIdx == null || docIdx <= 0) {
            return null;
        }
        return mapper.selectSeen(LoginUserContext.coCd(), docIdx);
    }
}
