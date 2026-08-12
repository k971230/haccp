/**
 * SystemMapper — HACCP 시스템 관리 화면의 기존 SP 조회 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 회사·사용자·부서·권한·메뉴·공통코드와 로그 통계의 이미 존재하는 SP를 한 경계에서 호출한다
 *   2) coCd는 Controller가 JWT 컨텍스트에서만 넣어 요청 파라미터의 테넌트 위조를 차단한다
 *   3) 화면별 목록 SQL은 XML의 고정 statement로 분리해 리소스명을 SQL 식별자로 조합하지 않는다
 *
 * PIPELINE[HB92] 시스템 관리 MyBatis 매퍼
 * PIPELINE[HB93, HF92] 연관 모듈
 */
package com.metis.haccp.sys;

// 역할 — 삭제 참조 차단 DTO
import com.metis.haccp.common.validation.DeleteBlocker;
// 역할 — MyBatis 매퍼 등록
import org.apache.ibatis.annotations.Mapper;
// 역할 — 다중 파라미터 이름 바인딩
import org.apache.ibatis.annotations.Param;

// 역할 — 유연한 관리·로그 행 목록
import java.util.List;
import java.util.Map;

@Mapper
public interface SystemMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 고정된 시스템 화면 유형의 행 목록을 조회한다
     *   2) 조회 버튼과 화면 최초 진입에서 호출한다
     *   3) 허용되지 않은 유형은 Controller가 차단하므로 XML에서 동적 테이블명을 만들지 않는다
     */
    List<Map<String, Object>> selectRows(
            // JWT 회사코드 — 모든 SP의 첫 테넌트 파라미터
            @Param("coCd") String coCd,
            // 허용된 시스템 화면 유형 — XML choose 분기값
            @Param("type") String type,
            // 사용자·코드·로그 검색에 쓰는 선택 검색어
            @Param("keyword") String keyword,
            // 이력·통계 조회 시작일 YYYYMMDD
            @Param("fromDt") String fromDt,
            // 이력·통계 조회 종료일 YYYYMMDD
            @Param("toDt") String toDt
    );

    void save(
            @Param("coCd") String coCd,
            @Param("type") String type,
            @Param("payload") String payload,
            @Param("userId") String userId
    );

    DeleteBlocker selectDeleteBlocker(
            @Param("coCd") String coCd,
            @Param("type") String type,
            @Param("idxs") List<Long> idxs
    );

    void delete(
            @Param("coCd") String coCd,
            @Param("type") String type,
            @Param("idx") Long idx,
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 테넌트 내 사용자 서명 상대경로를 읽는다
     *   2) 서명 다운로드·업로드 전 조회에 쓴다
     *   3) 없거나 다른 회사이면 null
     */
    String selectSignPath(
            @Param("coCd") String coCd,
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 서명 이미지 상대경로를 tbl_user에 반영한다
     *   2) 업로드 성공 직후 호출한다
     *   3) 갱신 행 수를 반환한다
     */
    int updateSignPath(
            @Param("coCd") String coCd,
            @Param("userId") String userId,
            @Param("signPath") String signPath,
            @Param("actorId") String actorId
    );

    /** 권한그룹별 화면 권한 목록 — sp_tbl_role_screen_r_000 */
    List<Map<String, Object>> selectRoleScreens(
            @Param("coCd") String coCd,
            @Param("usrgrpCd") String usrgrpCd
    );

    /** 화면 권한 1건 업서트 — sp_tbl_role_screen_c_000 */
    void upsertRoleScreen(
            @Param("coCd") String coCd,
            @Param("usrgrpCd") String usrgrpCd,
            @Param("scrnCd") String scrnCd,
            @Param("readYn") String readYn,
            @Param("writeYn") String writeYn,
            @Param("modifyYn") String modifyYn,
            @Param("deleteYn") String deleteYn,
            @Param("printYn") String printYn,
            @Param("userId") String userId
    );

    /** 공통코드 대분류 헤더 — sp_tbl_code_group_r_000 */
    List<Map<String, Object>> selectCodeGroups(@Param("coCd") String coCd);

    /** 공통코드 세부 — sp_tbl_code_detail_r_000 */
    List<Map<String, Object>> selectCodeDetails(
            @Param("coCd") String coCd,
            @Param("mainCd") String mainCd,
            @Param("sysYn") String sysYn
    );

    /** 관리용 메뉴 평면 목록 — 권한 트리 조립 */
    List<Map<String, Object>> selectMenusAdmin(@Param("coCd") String coCd);
}
