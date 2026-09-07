/**
 * RoleMgmtMapper — 권한그룹 관리 화면(role-management) SP 호출 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) sp_role_management_* 만 호출한다 — 좌측 권한그룹과 우측 화면권한이 같은 접두를 쓴다
 *   2) 화면권한 조회(selectScreens)는 로그인 직후 버튼 권한 판정에서도 같은 SP를 쓴다
 *   3) coCd는 Service가 JWT 컨텍스트에서만 채운다
 *
 * PIPELINE[HB92] 권한그룹 관리 MyBatis 매퍼
 */
package com.haccp.sys.code.role;

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
public interface RoleMgmtMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 권한그룹 목록을 조회한다 — 좌측 마스터 그리드
     *   2) 화면 진입·조회와 사용자 관리 룩업에서 호출한다
     *   3) 조건에 맞는 그룹이 없으면 빈 목록
     */
    List<com.haccp.sys.code.role.dto.RoleRow> selectRows(
            // JWT 회사코드 — 테넌트 범위. 필수 등가 조건
            @Param("coCd") String coCd,
            // 헤더 권한그룹코드 검색어. 공백이면 전체
            @Param("usrgrpCd") String usrgrpCd,
            // 헤더 권한그룹명 검색어. 공백이면 전체
            @Param("usrgrpNm") String usrgrpNm,
            // 헤더 사용여부. 공백이면 Y·N 모두
            @Param("useYn") String useYn
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 권한그룹 1건을 저장한다 — idx가 null이면 등록, 값이면 수정
     *   2) 저장 버튼이 변경 행 수만큼 반복 호출한다
     *   3) 코드 중복이면 SP가 45000으로 올린다
     */
    void save(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 수정 대상 대리키. 신규면 null
            @Param("idx") Long idx,
            // 업체 내 유일 권한그룹코드
            @Param("usrgrpCd") String usrgrpCd,
            // 권한그룹명
            @Param("usrgrpNm") String usrgrpNm,
            // 권한그룹 설명
            @Param("descRmk") String descRmk,
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
     *   3) 사용 중인 사용자가 없으면 null
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
     *   1) 권한그룹 1건을 삭제한다 — 딸린 화면권한 행도 SP가 함께 정리한다
     *   2) Double Check 통과 뒤 반복 호출한다
     *   3) 미존재·사용자 참조면 SP가 45000으로 올린다
     */
    void delete(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대상 tbl_role.idx
            @Param("idx") Long idx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 권한그룹별 화면 권한 목록을 조회한다
     *   2) 권한 관리 우측 트리와 로그인 직후 버튼 권한 판정이 호출한다
     *   3) 미설정 화면도 N으로 채워져 전체 화면이 내려온다
     */
    List<com.haccp.sys.code.role.dto.RoleScreenRow> selectScreens(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 조회할 권한그룹코드
            @Param("usrgrpCd") String usrgrpCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 화면 권한 1건을 업서트한다
     *   2) 권한 트리 체크 저장 시 변경 행 수만큼 반복 호출한다
     *   3) 같은 (회사, 그룹, 화면)이면 갱신, 없으면 등록
     */
    void upsertScreen(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 권한그룹코드
            @Param("usrgrpCd") String usrgrpCd,
            // 화면코드 — tbl_screen.scrn_cd
            @Param("scrnCd") String scrnCd,
            // 조회 권한 Y/N — N이면 사이드바에서 메뉴가 사라진다
            @Param("readYn") String readYn,
            // 등록 권한 Y/N
            @Param("writeYn") String writeYn,
            // 수정 권한 Y/N
            @Param("modifyYn") String modifyYn,
            // 삭제 권한 Y/N
            @Param("deleteYn") String deleteYn,
            // 출력 권한 Y/N
            @Param("printYn") String printYn,
            // JWT 작업자 ID — 감사 컬럼
            @Param("userId") String userId
    );
}
