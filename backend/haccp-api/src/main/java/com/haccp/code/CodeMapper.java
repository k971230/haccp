/**
 * CodeMapper — 공통코드 조회 MyBatis 매퍼 인터페이스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) sp_common_code_management_r_001 을 호출한다 — 로그인 회사코드에 속한 코드만 받는다(표준코드 '0000' 병합 없음)
 *   2) SQL 본문은 mapper/code/CodeMapper.xml 에 있다
 *   3) 코드 등록·수정은 공통코드 관리 화면(sp_common_code_management_c_000)이 담당하므로 여기 선언하지 않았다
 *
 * PIPELINE[HB35] MyBatis 매퍼
 */
package com.haccp.code;

// 역할 — 공통코드 Row DTO
import com.haccp.code.dto.CodeRow;
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
     *   3) 회사코드 고유 목록을 반환하고, 해당 대분류가 없으면 빈 목록이다
     *      표준코드는 업체 생성 시 복제되므로 조회에서 '0000'을 함께 읽지 않는다
     */
    List<CodeRow> selectCodes(
            // JWT 회사코드 — SP가 이 회사코드 범위만 읽는다(완전 격리)
            @Param("coCd") String coCd,
            // 대분류 코드 — 부분 일치로 비교한다. null이나 공백이면(= 조건 없음) 전체 그룹이 나온다
            @Param("mainCd") String mainCd,
            // 사용여부 필터 — 'Y'면 사용중만. 공백이면(= 조건 없음) Y·N 모두
            @Param("useYn") String useYn
    );
}
