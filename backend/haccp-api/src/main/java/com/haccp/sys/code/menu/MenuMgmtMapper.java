/**
 * MenuMgmtMapper — 메뉴 관리 화면(menu-management) SP 호출 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) sp_menu_management_* 만 호출한다 — 사이드바용 sp_menu_nav_r_000은 com.haccp.menu가 쓴다
 *   2) coCd는 Service가 JWT 컨텍스트에서만 채운다
 *   3) 관리 화면이라 조회권한으로 필터하지 않는다 — 전체 메뉴가 내려온다
 *
 * PIPELINE[HB92] 메뉴 관리 MyBatis 매퍼
 */
package com.haccp.sys.code.menu;

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
public interface MenuMgmtMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 관리용 메뉴 전체 목록을 조회한다
     *   2) 메뉴 관리 화면과 권한 관리 좌측 트리가 함께 호출한다
     *   3) 트리 조립에 전체 집합이 필요하므로 화면은 검색어를 공백으로 넘긴다
     */
    List<Map<String, Object>> selectRows(
            // JWT 회사코드 — 테넌트 범위. 필수 등가 조건
            @Param("coCd") String coCd,
            // 헤더 메뉴코드 검색어. 공백이면 전체
            @Param("menuCd") String menuCd,
            // 헤더 메뉴명 검색어. 공백이면 전체
            @Param("menuNm") String menuNm,
            // 헤더 사용여부. 공백이면 Y·N 모두
            @Param("useYn") String useYn
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 메뉴 1건을 저장한다 — idx가 null이면 등록, 값이면 수정
     *   2) 저장 버튼이 변경 행 수만큼 반복 호출한다
     *   3) 사용여부를 N으로 내리면 SP가 자손 메뉴까지 N으로 전파한다
     */
    void save(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 수정 대상 대리키. 신규면 null
            @Param("idx") Long idx,
            // 업체 내 유일 메뉴코드 — 화면에서는 편집 불가
            @Param("menuCd") String menuCd,
            // 메뉴 표시명
            @Param("menuNm") String menuNm,
            // 상위 메뉴코드. 공백이면 루트
            @Param("hMenuCd") String hMenuCd,
            // 화면 leaf 코드. 공백이면 분류 노드
            @Param("scrnCd") String scrnCd,
            // 대중소 인코딩 정렬값
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
     *   3) 하위 메뉴가 없으면 null
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
     *   1) 메뉴 1건을 삭제한다
     *   2) Double Check 통과 뒤 반복 호출한다
     *   3) 미존재·하위 메뉴 보유면 SP가 45000으로 올린다
     */
    void delete(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대상 tbl_menu.idx
            @Param("idx") Long idx
    );
}
