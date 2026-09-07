/**
 * DraftSeenMapper — 문서 초안 동시 저장 스탬프.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) tbl_document.upd_dt(없으면 ins_dt)를 조회·대조한다
 *   2) 작성 저장 직전에 호출한다 — 다른 탭이 먼저 저장했으면 45000
 *   3) 회사코드는 호출부가 JWT 에서만 넣는다
 *
 * PIPELINE[HB135] 양식 작성 공용 유틸
 */
package com.haccp.draft;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

/** 초안 seen_upd_dt SP */
@Mapper
public interface DraftSeenMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 문서의 현재 스탬프를 읽는다
     *   2) 상세 조회가 화면에 내려줄 때 호출한다
     *   3) 없거나 삭제면 null
     */
    String selectSeen(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // tbl_document.idx
            @Param("docIdx") Long docIdx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 화면이 본 스탬프와 DB 가 같아야 저장을 이어간다
     *   2) 수정 저장 직전에 호출한다
     *   3) 어긋나면 SP 가 45000 을 낸다. 신규·빈 스탬프는 통과
     */
    void assertSeen(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // tbl_document.idx — 0 이하면 검사 생략
            @Param("docIdx") Long docIdx,
            // 화면이 상세에서 받은 스탬프
            @Param("seenUpdDt") String seenUpdDt
    );
}
