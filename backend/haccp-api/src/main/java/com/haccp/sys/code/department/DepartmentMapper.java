/**
 * DepartmentMapper — 부서 관리 화면(department-management) SP 호출 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) sp_department_management_* 만 호출한다 — 네이티브 SQL 금지
 *   2) 조회는 상위부서명(h_dept_nm)까지 SP가 붙여 내려주므로 앱에서 다시 매핑하지 않는다
 *   3) coCd는 Service가 JWT 컨텍스트에서만 채운다
 *
 * PIPELINE[HB92] 부서 관리 MyBatis 매퍼
 */
package com.haccp.sys.code.department;

// 역할 — 삭제 참조 차단 DTO
import com.haccp.common.validation.DeleteBlocker;
// 역할 — MyBatis 매퍼 등록
import org.apache.ibatis.annotations.Mapper;
// 역할 — 다중 파라미터 이름 바인딩
import org.apache.ibatis.annotations.Param;

// 역할 — 화면 행 목록
import java.util.List;
import java.util.Map;

@Mapper
public interface DepartmentMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 부서 목록을 조회한다 — 최상위 우선 트리 정렬
     *   2) 화면 진입·조회와 사용자 관리 부서 룩업·트리에서 호출한다
     *   3) 조건에 맞는 부서가 없으면 빈 목록
     */
    List<Map<String, Object>> selectRows(
            // JWT 회사코드 — 테넌트 범위. 필수 등가 조건
            @Param("coCd") String coCd,
            // 헤더 부서코드 검색어. 공백이면 전체
            @Param("deptCd") String deptCd,
            // 헤더 부서명 검색어. 공백이면 전체
            @Param("deptNm") String deptNm,
            // 헤더 사용여부. 공백이면 Y·N 모두
            @Param("useYn") String useYn
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 부서 1건을 저장한다 — idx가 null이면 등록, 값이면 수정
     *   2) 저장 버튼이 변경 행 수만큼 반복 호출한다
     *   3) 코드 중복·자기참조면 SP가 45000으로 올린다
     */
    void save(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 수정 대상 대리키. 신규면 null
            @Param("idx") Long idx,
            // 업체 내 유일 부서코드
            @Param("deptCd") String deptCd,
            // 부서명
            @Param("deptNm") String deptNm,
            // 상위 부서코드. 공백이면 최상위
            @Param("hDeptCd") String hDeptCd,
            // 같은 상위 안에서의 표시 순서
            @Param("sortNo") Integer sortNo,
            // 사용여부
            @Param("useYn") String useYn,
            // JWT 작업자 ID — 감사 컬럼
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 삭제 대상 전부를 배열 하나로 넘겨 차단 사유 첫 건을 받는다
     *   2) validate-delete·delete 양쪽에서 호출한다
     *   3) 사유 우선순위는 사용자 > 하위 부서 사용자 > 하위 부서
     */
    DeleteBlocker selectDeleteBlocker(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대상 대리키 목록
            @Param("idxs") List<Long> idxs
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 부서 1건을 삭제한다
     *   2) Double Check 통과 뒤 반복 호출한다
     *   3) 미존재·사용자·하위 부서 참조면 SP가 45000으로 올린다
     */
    void delete(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대상 tbl_dept.idx
            @Param("idx") Long idx
    );
}
