/**
 * CodeMapper — 공통코드 조회 MyBatis 매퍼 인터페이스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) sp_tbl_code_r_000 을 호출한다 — 플랫폼 표준코드와 업체 코드를 병합한 결과를 받는다
 *   2) SQL 본문은 mapper/code/CodeMapper.xml 에 있다
 *   3) 코드 등록·수정(sp_tbl_code_c_000)은 공통코드 관리 화면에서 다룰 예정이라 아직 선언하지 않았다
 *
 * PIPELINE[HB35] MyBatis 매퍼
 */
package com.metis.haccp.code;

// 역할 — 공통코드 Row DTO
import com.metis.haccp.code.dto.CodeRow;
// 역할 — @Mapper 등록
import org.apache.ibatis.annotations.Mapper;
// 역할 — 다중 파라미터 이름 지정
import org.apache.ibatis.annotations.Param;

// 역할 — 코드 목록
import java.util.List;

@Mapper
public interface CodeMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 대분류 기준으로 공통코드 목록을 조회한다
     *   2) 화면 진입 시 콤보를 채우거나 코드 관리 화면에서 목록을 조회할 때 호출한다
     *   3) 플랫폼 표준 + 업체 코드를 병합한 목록을 반환하고, 해당 대분류가 없으면 빈 목록이다
     */
    List<CodeRow> selectCodes(
            // JWT 회사코드 — SP가 (p_co_cd, '0000') 두 범위를 함께 읽는다
            @Param("coCd") String coCd,
            // 대분류 코드 — 부분 일치로 비교한다. null이나 공백이면(= 조건 없음) 전체 그룹이 나온다
            @Param("mainCd") String mainCd,
            // 사용여부 필터 — 'Y'면 사용중만. 공백이면(= 조건 없음) Y·N 모두
            @Param("useYn") String useYn
    );
}
