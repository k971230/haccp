/**
 * CcpVerifyTemplateMapper — CCP 검증점검 양식 SP.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 저장은 tbl_html_ccp_chk_ver. 공정점검은 HtmlTemplateMapper
 *   2) 회사코드는 JWT coCd만 넘긴다
 *   3) 삭제는 blocker 후 d_000
 *
 * PIPELINE[HB131] CCP 검증점검 양식 Mapper
 */
package com.haccp.docs.htmlform.ccpverifytemplate;

import com.haccp.common.validation.DeleteBlocker;
import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface CcpVerifyTemplateMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 예시+자사 양식 목록을 반환한다
     *   2) 기준관리 좌측이 호출한다
     *   3) verCd·verNm 빈값이면 전체
     */
    List<Map<String, Object>> selectVersions(
            @Param("coCd") String coCd,
            @Param("tmplCd") String tmplCd,
            @Param("verCd") String verCd,
            @Param("verNm") String verNm
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 양식 항목을 반환한다. html_ccp_chk_000 이면 시드
     *   2) 우측 A4가 호출한다
     *   3) 없으면 빈 목록
     */
    List<Map<String, Object>> selectItems(
            @Param("coCd") String coCd,
            @Param("tmplCd") String tmplCd,
            @Param("verNo") int verNo
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 표준 시드를 복사해 html_ccp_chk_NNN 1건을 만든다
     *   2) 좌 저장이 pending 행을 커밋할 때 호출한다
     *   3) 새 양식코드를 돌려 화면이 그 행을 선택한다
     */
    String copyVersion(
            @Param("coCd") String coCd,
            @Param("tmplCd") String tmplCd,
            @Param("srcVerNo") int srcVerNo,
            @Param("verCd") String verCd,
            @Param("verNm") String verNm,
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 사용자 버전 항목을 전체 교체한다
     *   2) 저장 버튼이 호출한다
     *   3) 표준은 SP가 거부한다
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
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 적용 버전을 고른다. 기준관리 좌 저장은 호출하지 않는다
     *   2) 호환용
     *   3) verNo=0 이면 표준
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
     *   3) 표준은 SP가 거부한다. 버전 소프트삭제는 건드리지 않는다
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
            // useYn: 회사 양식 사용여부 Y/N
            @Param("useYn") String useYn,
            // userId: 수정자
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 표준·없는 버전을 차단한다
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
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 회사 버전을 use_yn=N 으로 숨긴다
     *   2) 삭제 버튼이 호출한다
     *   3) 표준은 SP가 막는다
     */
    void deleteVersion(
            @Param("coCd") String coCd,
            @Param("tmplCd") String tmplCd,
            @Param("verNo") int verNo,
            @Param("userId") String userId
    );
}
