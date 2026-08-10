/**
 * CodeRow.java — 공통코드 1건 Row DTO.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) sp_tbl_code_r_000 결과 1행 — 콤보 상자·상태 배지 문구의 원천이다
 *   2) 플랫폼 표준코드(co_cd='0000')와 업체 코드가 합쳐져 오고, 같은 코드가 양쪽에 있으면 업체 값만 남는다
 *   3) sysYn='Y'는 플랫폼 표준이라 업체가 수정·삭제할 수 없다 — 프론트는 이 값으로 편집 가능 여부를 판정한다
 *
 * PIPELINE[HB34] code DTO
 */
package com.metis.haccp.code.dto;

// 역할 — @Getter/@Setter 접근자 (MyBatis 매핑 대상)
import lombok.Getter;
import lombok.Setter;

/** 공통코드 1건 — 콤보는 subCd(값) + codeNm(표시) 조합으로 쓴다 */
@Getter
@Setter
public class CodeRow {

    /** tbl_code.idx — 대리키 */
    private Long idx;
    /** 소유 회사코드 — '0000'이면 플랫폼 표준코드, 그 외는 업체 고유 코드 */
    private String coCd;
    /** 대분류 코드 — 코드 그룹 식별자 (예: DOC_STAT) */
    private String mainCd;
    /** 세부 코드 — 콤보의 실제 값 */
    private String subCd;
    /** 코드명 — 콤보에 보이는 문구 */
    private String codeNm;
    /** 같은 대분류 내 정렬 순서 */
    private Integer sortNo;
    /** 참조값1 — 코드별 부가 속성(색상·단위 등 그룹마다 의미가 다르다) */
    private String ref1;
    /** 참조값2 — 참조값1과 같은 용도의 두 번째 슬롯 */
    private String ref2;
    /** 플랫폼 표준여부 Y/N — Y이면 업체가 수정·삭제할 수 없다 */
    private String sysYn;
    /** 사용여부 Y/N */
    private String useYn;
}
