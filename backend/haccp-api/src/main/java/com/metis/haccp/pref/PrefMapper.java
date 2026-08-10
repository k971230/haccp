/**
 * PrefMapper — 그리드 열 설정 MyBatis 매퍼 인터페이스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) sp_tbl_grid_pref_r_000(조회) / sp_tbl_grid_pref_c_000(업서트) 두 개를 호출한다
 *   2) SQL 본문은 mapper/pref/PrefMapper.xml 에 있다
 *   3) 회사코드·사용자 아이디는 항상 JWT에서 채운다 — 파라미터로 열어두면 남의 설정을 덮어쓸 수 있다
 *
 * PIPELINE[HB40] MyBatis 매퍼
 */
package com.metis.haccp.pref;

// 역할 — 그리드 설정 Row DTO
import com.metis.haccp.pref.dto.GridPrefRow;
// 역할 — @Mapper 등록
import org.apache.ibatis.annotations.Mapper;
// 역할 — 다중 파라미터 이름 지정
import org.apache.ibatis.annotations.Param;

// 역할 — 설정 목록
import java.util.List;

@Mapper
public interface PrefMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 사용자의 그리드 열 설정 목록을 조회한다
     *   2) 화면 진입 시 1회 호출해 그 화면의 그리드 전체 설정을 한 번에 받는다
     *   3) 저장한 설정이 없으면 빈 목록이다 — 프론트는 이때 컬럼 정의의 기본값을 쓴다
     */
    List<GridPrefRow> selectGridPrefs(
            // JWT 회사코드 — 테넌트 범위
            @Param("coCd") String coCd,
            // JWT 로그인 아이디 — 설정은 사용자별로 분리 보관된다
            @Param("userId") String userId,
            // 화면코드 — 부분 일치로 비교한다. 공백이면(= 조건 없음) 이 사용자의 전체 화면 설정이 나온다
            @Param("scrnCd") String scrnCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 그리드 열 설정을 업서트하거나, 빈 JSON이면 삭제(초기화)한다
     *   2) 사용자가 열 너비·표시여부를 바꾼 뒤 저장할 때 호출한다
     *   3) 성공 시 영향 행 수를 반환한다. 같은 키로 여러 번 호출해도 결과가 같다
     */
    int saveGridPref(
            // JWT 회사코드 — 테넌트 범위
            @Param("coCd") String coCd,
            // JWT 로그인 아이디 — 저장 대상 사용자. 요청 본문에서 받지 않는다
            @Param("userId") String userId,
            // 화면코드 — (userId, scrnCd, gridId) 조합이 유니크 키다
            @Param("scrnCd") String scrnCd,
            // 그리드 식별자 — 편집 그리드의 persistId
            @Param("gridId") String gridId,
            // 열 설정 JSON 원문 — 공백·null이면(= 초기화 요청) SP가 해당 행을 삭제한다
            @Param("prefJson") String prefJson
    );
}
