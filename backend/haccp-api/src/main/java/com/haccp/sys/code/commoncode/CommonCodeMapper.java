/**
 * CommonCodeMapper — 공통코드 관리 화면(common-code-management) SP 호출 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) sp_common_code_management_* 만 호출한다 — 네이티브 SQL은 이 매퍼에 두지 않는다
 *   2) coCd는 Service가 JWT 컨텍스트에서만 채워 요청 파라미터의 테넌트 위조를 막는다
 *   3) 조회는 SELECT * FROM sp_...(), 저장·삭제는 CALL sp_...()로 호출한다
 *
 * PIPELINE[HB92] 공통코드 MyBatis 매퍼
 */
package com.haccp.sys.code.commoncode;

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
public interface CommonCodeMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 대분류(sub_cd='*') 목록을 조회한다 — 좌측 그리드
     *   2) 화면 진입·조회 버튼에서 호출한다
     *   3) 조건에 맞는 행이 없으면 빈 목록
     */
    List<com.haccp.sys.code.commoncode.dto.CommonCodeGroupRow> selectGroups(
            // JWT 회사코드 — 테넌트 범위. SP의 필수 등가 조건
            @Param("coCd") String coCd,
            // 페이지 헤더 대분류코드 검색어. 공백이면 전체
            @Param("mainCd") String mainCd,
            // 페이지 헤더 대분류명 검색어. 공백이면 전체
            @Param("codeNm") String codeNm
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 선택 대분류의 세부코드 목록을 조회한다 — 시스템·사용자 그리드
     *   2) 대분류 행을 고를 때마다 sysYn을 바꿔 두 번 호출한다
     *   3) 조건에 맞는 행이 없으면 빈 목록
     */
    List<com.haccp.sys.code.commoncode.dto.CommonCodeDetailRow> selectDetails(
            // JWT 회사코드 — 테넌트 범위
            @Param("coCd") String coCd,
            // 대분류코드 — 정확 일치. 공백이면 전체 그룹
            @Param("mainCd") String mainCd,
            // 시스템/사용자 구분 Y·sys | N·usr. 공백이면 둘 다
            @Param("sysYn") String sysYn,
            // 사용여부 필터. 공백이면 Y·N 모두
            @Param("useYn") String useYn
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 세부코드 1건을 저장한다 — idx가 null이면 등록, 값이면 수정
     *   2) 저장 버튼이 변경 행 수만큼 반복 호출한다
     *   3) 업무키 중복·시스템코드 위반은 SP가 45000으로 올린다
     */
    void save(
            // JWT 회사코드 — 항상 업체 코드로만 저장된다
            @Param("coCd") String coCd,
            // 수정 대상 대리키. 신규면 null
            @Param("idx") Long idx,
            // 대분류 코드
            @Param("mainCd") String mainCd,
            // 세부 코드
            @Param("subCd") String subCd,
            // 코드명
            @Param("codeNm") String codeNm,
            // 정렬순서. null이면 SP가 기존 값 유지
            @Param("sortNo") Integer sortNo,
            // 참조값1
            @Param("ref1") String ref1,
            // 참조값2
            @Param("ref2") String ref2,
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
     *   2) validate-delete·delete 양쪽 assertDeletable에서 호출한다
     *   3) 차단 사유가 없으면 null
     */
    DeleteBlocker selectDeleteBlocker(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대상 대리키 목록 — bigint[] 한 번에 검사
            @Param("idxs") List<Long> idxs
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 세부코드 1건을 삭제한다
     *   2) Double Check 통과 뒤 idx 수만큼 반복 호출한다
     *   3) 미존재·시스템코드면 SP가 45000으로 올린다
     */
    void delete(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대상 tbl_code.idx
            @Param("idx") Long idx
    );
}
