/**
 * MenuMapper — 메뉴 조회 MyBatis 매퍼 인터페이스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) sp_menu_nav_r_000 하나만 호출한다 — 메뉴 등록·수정은 플랫폼 관리 기능이라 별도 매퍼로 분리한다
 *   2) SQL 본문은 mapper/menu/MenuMapper.xml 에 있다
 *   3) 권한 결합은 SP가 처리한다. 애플리케이션에서 다시 필터링하지 않는다(판정 지점을 하나로 유지)
 *
 * PIPELINE[HB31] MyBatis 매퍼
 */
package com.haccp.menu;

// 역할 — 메뉴 Row DTO
import com.haccp.menu.dto.MenuRow;
// 역할 — @Mapper 등록
import org.apache.ibatis.annotations.Mapper;
// 역할 — 다중 파라미터 이름 지정
import org.apache.ibatis.annotations.Param;

// 역할 — 메뉴 목록
import java.util.List;

@Mapper
public interface MenuMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 권한이 반영된 메뉴 평면 목록을 조회한다
     *   2) 로그인 직후 사이드 메뉴를 그릴 때 1회 호출한다
     *   3) 조회권한 있는 메뉴만 반환하고, 권한이 하나도 없으면 빈 목록이다
     */
    List<MenuRow> selectMenus(
            // JWT 회사코드 — 테넌트 범위. 업체마다 메뉴 구성이 다를 수 있다
            @Param("coCd") String coCd,
            // JWT 권한그룹코드 — 화면 권한 결합 기준. null이면 SP가 모든 leaf를 걸러 분류 노드만 남는다
            @Param("usrgrpCd") String usrgrpCd
    );
}
