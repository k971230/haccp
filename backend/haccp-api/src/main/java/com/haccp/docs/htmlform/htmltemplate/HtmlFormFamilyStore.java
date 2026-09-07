/**
 * HtmlFormFamilyStore — HTML 양식 가족(표) 포트.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 다섯 표의 select/copy/save/apply/update/delete/blocker 시그니처가 같다
 *   2) HtmlTemplateService 가 storeFor(tmpl) 뒤에 이 포트만 부른다
 *   3) 검증(이름 필수·표준 수정 금지·화면 일치·Double Check)은 Service 한 곳
 *
 * PIPELINE[HB130] HTML양식 가족 포트
 */
package com.haccp.docs.htmlform.htmltemplate;

// 역할 — 삭제 차단 한 줄
import com.haccp.common.validation.DeleteBlocker;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormItemRow;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormVersionRow;
// 역할 — 버전·항목 행
import java.util.List;

/** 공정점검·검증점검·포장·가열·금속검출 표에 같은 호출 */
public interface HtmlFormFamilyStore {

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 예시+자사 양식 목록을 반환한다
     *   2) 기준관리 좌측이 호출한다
     *   3) verCd·verNm 빈값이면 전체
     */
    List<HtmlFormVersionRow> selectVersions(
            // coCd: JWT 회사코드
            String coCd,
            // tmplCd: 양식코드
            String tmplCd,
            // verCd: 버전코드 부분검색. 빈값이면 전체
            String verCd,
            // verNm: 버전명 부분검색. 빈값이면 전체
            String verNm
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 우측 A4 항목을 반환한다
     *   2) 양식 선택 시 호출한다
     *   3) 없으면 빈 목록
     */
    List<HtmlFormItemRow> selectItems(
            // coCd: JWT 회사코드
            String coCd,
            // tmplCd: 양식코드
            String tmplCd,
            // verNo: 0=표준
            int verNo
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 표준 시드를 복사해 자사 양식 1건을 만든다
     *   2) 좌 저장이 pending 행을 커밋할 때 호출한다
     *   3) 새 양식코드를 돌려 화면이 그 행을 선택한다
     */
    String copyVersion(
            // coCd: JWT 회사코드
            String coCd,
            // tmplCd: 가족. SP가 시드·채번 접두를 고른다
            String tmplCd,
            // srcVerNo: 호환. 행추가는 표준만
            int srcVerNo,
            // verCd: 호환. 번호는 SP가 채번
            String verCd,
            // verNm: 양식명
            String verNm,
            // userId: 등록자
            String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 자사 양식 항목을 전체 교체한다
     *   2) 저장 버튼이 호출한다
     *   3) 표준은 SP가 거부한다
     */
    void saveItems(
            // coCd: JWT 회사코드
            String coCd,
            // tmplCd: 양식코드
            String tmplCd,
            // verNo: 회사 순번
            int verNo,
            // items: 항목 JSON 배열 문자열
            String items,
            // userId: 수정자
            String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 작성 신규가 쓸 적용 버전을 고른다
     *   2) 기준관리 좌 저장은 호출하지 않는다
     *   3) verNo=0 이면 표준
     */
    void applyVersion(
            // coCd: JWT 회사코드
            String coCd,
            // tmplCd: 양식코드
            String tmplCd,
            // verNo: 적용 순번
            int verNo,
            // userId: 수정자
            String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 자사 양식명·회사 양식 사용여부를 고친다
     *   2) 좌 저장이 이름·사용여부가 바뀐 저장행을 커밋할 때 호출한다
     *   3) 표준은 SP가 거부한다
     */
    void updateVerNm(
            // coCd: JWT 회사코드
            String coCd,
            // tmplCd: 양식코드
            String tmplCd,
            // verNo: 회사 순번. 0이면 표준
            int verNo,
            // verNm: 바꿀 양식명
            String verNm,
            // useYn: 회사 양식 사용여부 Y/N
            String useYn,
            // userId: 수정자
            String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 표준·작성 문서·오늘 할 일을 차단한다
     *   2) validate-delete·delete Double Check
     *   3) 없으면 null
     */
    DeleteBlocker selectDeleteBlocker(
            // coCd: JWT 회사코드
            String coCd,
            // tmplCd: 양식코드
            String tmplCd,
            // verNo: 회사 순번
            int verNo
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 회사 버전을 use_yn=N 으로 숨긴다
     *   2) 삭제 버튼이 호출한다
     *   3) 표준은 SP가 막는다
     */
    void deleteVersion(
            // coCd: JWT 회사코드
            String coCd,
            // tmplCd: 양식코드
            String tmplCd,
            // verNo: 회사 순번
            int verNo,
            // userId: 삭제자
            String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 감사 한 줄의 tbl_nm 을 돌려준다
     *   2) 저장·적용·이름·삭제 이력이 부른다
     *   3) 가족마다 버전 표가 다르다
     */
    String auditVerTbl();
}
