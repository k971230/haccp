/**
 * HwpDraftMapper — HWP 양식 작성 조회 SP 바인딩.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 이 화면 고유 조회 2개(작성 목록·오늘 할일)와 양식 목록만 여기서 다룬다
 *   2) 저장·삭제·상세는 문서 허브(DocumentService)를 그대로 쓴다 — 기존 HWP 편집 화면과 같은 경로다
 *   3) 회사코드는 서비스가 JWT 에서 넣는다. 화면이 넘기지 않는다
 *
 * PIPELINE[HB144] HWP 작성 Mapper
 */
package com.haccp.draft.hwpdoc;

import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import com.haccp.draft.dto.DraftTaskRow;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface HwpDraftMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 작성에 쓸 수 있는 HWP 양식(사용여부 예)만 반환한다
     *   2) 화면 진입 시 한 번, 양식 선택 팝업이 쓴다
     *   3) 없으면 빈 목록 — 화면이 사용양식 관리로 안내한다
     */
    List<DraftFormRow> selectForms(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 상단 검색 6개 중 서버 조건 5개(일자 구간·양식코드·양식명·작성자ID·작성자명)로 조회한다
     *   2) 좌측 그리드가 호출한다
     *   3) 결재 여부는 화면이 DOC_STATUS 를 3단계로 묶어 거른다
     */
    List<DraftListRow> selectList(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // tmplCd: 양식코드 부분검색. 빈값이면 전체
            @Param("tmplCd") String tmplCd,
            // tmplNm: 양식명 부분검색. 빈값이면 전체
            @Param("tmplNm") String tmplNm,
            // fromDt: 일자 시작 YYYYMMDD. 빈값이면 하한 없음
            @Param("fromDt") String fromDt,
            // toDt: 일자 종료 YYYYMMDD. 빈값이면 상한 없음
            @Param("toDt") String toDt,
            // writerId: 작성자 ID 부분검색. 빈값이면 전체
            @Param("writerId") String writerId,
            // writerNm: 작성자명 부분검색. 빈값이면 전체
            @Param("writerNm") String writerNm
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 기준일의 오늘 할일 중 HWP 문서주기만 반환한다
     *   2) 행 추가 팝업이 호출한다
     *   3) 담당자 미지정 할일도 함께 준다 — 누구나 처리할 수 있는 주기다
     */
    List<DraftTaskRow> selectTasks(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // userId: JWT 사용자 ID
            @Param("userId") String userId,
            // baseDt: 기준일 YYYYMMDD
            @Param("baseDt") String baseDt
    );
}
