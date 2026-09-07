/**
 * HtmlTemplateMapper — HTML 양식 버전 SP 호출.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 예시는 html_hyg_prc_000 가상행이다. 시드는 html_sys_001. 저장은 tbl_html_hyg_prc_ver
 *   2) 회사코드는 JWT coCd만 넘긴다
 *   3) 삭제는 blocker 후 d_000
 *
 * PIPELINE[HB130] HTML양식 원본 Mapper
 */
package com.haccp.docs.htmlform.htmltemplate;

import com.haccp.common.validation.DeleteBlocker;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormItemRow;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormVersionRow;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface HtmlTemplateMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 예시+자사 양식 목록을 반환한다
     *   2) 기준관리 좌측이 호출한다
     *   3) verCd·verNm 빈값이면 전체. 저장 테이블 tbl_html_hyg_prc_ver
     */
    List<HtmlFormVersionRow> selectVersions(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // tmplCd: 양식코드
            @Param("tmplCd") String tmplCd,
            // verCd: 버전코드 부분검색. 빈값이면 전체
            @Param("verCd") String verCd,
            // verNm: 버전명 부분검색. 빈값이면 전체
            @Param("verNm") String verNm
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 양식 항목을 반환한다. 예시·시드이면 tbl_check_item
     *   2) 우측 A4가 호출한다
     *   3) 없으면 빈 목록
     */
    List<HtmlFormItemRow> selectItems(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // tmplCd: 양식코드
            @Param("tmplCd") String tmplCd,
            // verNo: 0=표준
            @Param("verNo") int verNo
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 표준 시드를 복사해 html_hyg_prc_NNN 자사 양식 1건을 만든다
     *   2) 좌 저장이 pending 행을 커밋할 때 호출한다
     *   3) 새 양식코드를 돌려 화면이 그 행을 선택한다
     */
    String copyVersion(
            @Param("coCd") String coCd,
            @Param("tmplCd") String tmplCd,
            @Param("srcVerNo") int srcVerNo,
            // verCd: 호환. 번호는 SP가 채번
            @Param("verCd") String verCd,
            // verNm: 양식명 — 일간·주간 등
            @Param("verNm") String verNm,
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 사용자 버전 항목을 전체 교체한다
     *   2) 저장 버튼이 호출한다
     *   3) 표준(verNo=0)은 SP가 거부한다
     */
    void saveItems(
            @Param("coCd") String coCd,
            @Param("tmplCd") String tmplCd,
            @Param("verNo") int verNo,
            @Param("items") String items,
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 작성 신규가 쓸 적용 버전을 고른다. verNo=0 이면 표준
     *   2) 좌 저장에서만 호출한다
     *   3) 업체+양식당 apply_yn=Y 1건
     */
    void applyVersion(
            @Param("coCd") String coCd,
            @Param("tmplCd") String tmplCd,
            @Param("verNo") int verNo,
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 사용자 버전명·회사 양식 사용여부를 고친다
     *   2) 좌 저장이 이름·사용여부가 바뀐 저장행을 커밋할 때 호출한다
     *   3) 표준(verNo<=0)은 SP가 거부한다. 버전 소프트삭제는 건드리지 않는다
     */
    void updateVerNm(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // tmplCd: 양식코드
            @Param("tmplCd") String tmplCd,
            // verNo: 회사 버전 순번. 0이면 표준
            @Param("verNo") int verNo,
            // verNm: 바꿀 버전명
            @Param("verNm") String verNm,
            // useYn: 회사 양식 사용여부 Y/N. 문서주기가 이 값을 본다
            @Param("useYn") String useYn,
            // userId: 수정자
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 표준·적용 중·없는 버전을 차단한다
     *   2) validate-delete·delete Double Check
     *   3) 없으면 null
     */
    DeleteBlocker selectDeleteBlocker(
            @Param("coCd") String coCd,
            @Param("tmplCd") String tmplCd,
            @Param("verNo") int verNo
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 회사 버전을 use_yn=N 으로 숨긴다
     *   2) 삭제 버튼이 호출한다
     *   3) 표준·적용 중은 SP가 막는다
     */
    void deleteVersion(
            @Param("coCd") String coCd,
            @Param("tmplCd") String tmplCd,
            @Param("verNo") int verNo,
            @Param("userId") String userId
    );
}
