/**
 * HtmlDraftMapper — HTML 작성 2화면(일반위생·공정점검 · CCP 검증점검) 공통 SP 호출.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 두 화면은 계약이 글자까지 같고 **부르는 SP 이름만** 다르다.
 *      매퍼를 둘로 두면 한쪽 SQL 만 고쳐 놓고 다른 하나가 조용히 어긋난다 —
 *      실제로 제목(title) 인자를 넣을 때 두 파일을 따로 고쳐야 했다
 *   2) 그래서 인터페이스는 하나로 두고 XML 이 family 로 SP 를 고른다.
 *      `CcpPkgDraftMapper`·`CcpHtgDraftMapper` 가 이미 같은 모양이다
 *   3) family 는 `HtmlDraftService.Family.key()` — "hyg" · "chk" 뿐이다
 *
 * **목록 SP 만 인자 형태가 다르다** — `sp_tbl_hyg_process_r_000` 은 10개,
 * `sp_ccp_verify_r_000` 은 8개다. XML 의 `<choose>` 가 그 차이를 흡수한다.
 *
 * PIPELINE[HB135] HTML 작성 공통 Mapper
 * PIPELINE[HB137] 연관 모듈
 */
package com.haccp.draft.html;

// 역할 — 삭제 차단 사유
import com.haccp.common.validation.DeleteBlocker;
// 역할 — 작성 목록·양식 목록 행
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import java.util.List;
// 역할 — MyBatis 매퍼 등록·이름 바인딩
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface HtmlDraftMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 작성에 쓸 수 있는 자사 양식(사용여부 Y)만 반환한다
     *   2) 화면 진입 시 한 번, 양식 선택 팝업이 쓴다
     *   3) 없으면 빈 목록 — 화면이 양식관리로 안내한다
     */
    List<DraftFormRow> selectForms(
            // family: 양식군 — XML 이 이 값으로 버전 SP 를 고른다
            @Param("family") String family,
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // stdTmplCd: 계열 예시코드 — SP 가 이 값으로 테이블을 가른다
            @Param("stdTmplCd") String stdTmplCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 상단 검색 조건으로 좌측 작성 목록을 조회한다
     *   2) 좌측 그리드가 호출한다
     *   3) 빈 조건은 SP 가 전체로 본다. 결재 여부는 파생값이라 화면이 거른다
     */
    List<DraftListRow> selectList(
            // family: 양식군 — 목록 SP 는 계열마다 인자 형태까지 다르다
            @Param("family") String family,
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
            @Param("writerNm") String writerNm,
            // title: 제목 부분검색 — tbl_document.title. 첨부 remark 가 아니다
            @Param("title") String title
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 기존 상세 또는 신규 기본행을 JSON 문자열로 받는다
     *   2) 좌측 행 클릭·양식 선택이 호출한다
     *   3) 신규(docIdx 없음)면 양식 항목만 깔아서 준다
     */
    String selectDetail(
            // family: 양식군
            @Param("family") String family,
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // tmplCd: 자사 양식코드
            @Param("tmplCd") String tmplCd,
            // docIdx: tbl_document.idx. null 이면 신규
            @Param("docIdx") Long docIdx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 문서·헤더·항목을 전체 교체로 저장하고 문서 idx 를 돌려준다
     *   2) 저장 버튼이 호출한다
     *   3) 신규는 SP 가 사용여부 Y·채번 규칙을 확인한다
     */
    Long save(
            // family: 양식군
            @Param("family") String family,
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // tmplCd: 자사 양식코드
            @Param("tmplCd") String tmplCd,
            // docIdx: 없으면 신규
            @Param("docIdx") Long docIdx,
            // baseDt: 일자 YYYYMMDD
            @Param("baseDt") String baseDt,
            // checkerNm: 점검자명
            @Param("checkerNm") String checkerNm,
            // payload: 항목·하단 4칸·제목 JSON
            @Param("payload") String payload,
            // userId: JWT 작업자 — 감사 컬럼
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 점검자·승인자·확인자 서명을 이름으로 맞춰 스냅샷한다
     *   2) 저장 직후 호출한다
     *   3) 이름이 사용자와 같고 서명이 있으면 이미지를 복사한다
     */
    void snapshotSigns(
            // family: 양식군
            @Param("family") String family,
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdx: 방금 저장한 문서
            @Param("docIdx") Long docIdx,
            // checkerNm: 점검자명
            @Param("checkerNm") String checkerNm,
            // approverNm: 승인자명
            @Param("approverNm") String approverNm,
            // confirmNm: 확인자명
            @Param("confirmNm") String confirmNm
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 삭제 차단 사유 첫 건을 받는다 — 전송(REQ)·결재완료(APV)
     *   2) validate-delete 와 delete 가 각각 호출한다 (Double Check)
     *   3) family 를 안 받는다 — 문서 허브 공통 SP 라 계열과 무관하다
     */
    DeleteBlocker selectDeleteBlocker(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdxs: 삭제 대상 문서 idx 목록
            @Param("docIdxs") List<Long> docIdxs
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 문서와 하위(항목·결재·첨부)를 지운다
     *   2) 삭제 버튼이 재검증 뒤 호출한다
     *   3) 차단 대상은 SP 가 한 번 더 막는다
     */
    void delete(
            // family: 양식군
            @Param("family") String family,
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdx: 지울 문서
            @Param("docIdx") Long docIdx,
            // userId: JWT 작업자 — 감사 컬럼
            @Param("userId") String userId
    );
}
