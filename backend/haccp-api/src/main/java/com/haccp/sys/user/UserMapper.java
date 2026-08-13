/**
 * UserMapper — 사용자 관리 화면(user-management) SP 호출 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) sp_user_management_* 만 호출한다 — 서명 조회·갱신도 SP로 옮겨 네이티브 SQL을 없앴다
 *   2) 목록에는 비밀번호 해시가 들어오지 않는다 — 해시는 로그인 SP만 읽는다
 *   3) coCd는 Service가 JWT 컨텍스트에서만 채운다
 *
 * PIPELINE[HB92] 사용자 관리 MyBatis 매퍼
 */
package com.haccp.sys.user;

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
public interface UserMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 사용자 목록을 조회한다 — 권한그룹명·부서명 포함
     *   2) 화면 진입·조회와 로그인 이력 화면의 사용자 트리에서 호출한다
     *   3) 조건에 맞는 사용자가 없으면 빈 목록
     */
    List<Map<String, Object>> selectRows(
            // JWT 회사코드 — 테넌트 범위. 필수 등가 조건
            @Param("coCd") String coCd,
            // 헤더 아이디 검색어. 공백이면 전체
            @Param("userId") String userId,
            // 헤더 이름 검색어. 공백이면 전체
            @Param("userNm") String userNm,
            // 좌측 부서 트리 선택값. 공백이면 전체 부서
            @Param("deptCd") String deptCd,
            // 헤더 사용여부. 공백이면 Y·N 모두
            @Param("useYn") String useYn
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 사용자 1건을 저장한다 — idx가 null이면 등록, 값이면 수정
     *   2) 저장 버튼이 변경 행 수만큼 반복 호출한다
     *   3) 아이디 중복이면 SP가 45000으로 올린다
     */
    void save(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 수정 대상 대리키. 신규면 null
            @Param("idx") Long idx,
            // 로그인 아이디 — 전 업체 통틀어 중복 불가
            @Param("userId") String userId,
            // 사번. 미입력 허용
            @Param("empCd") String empCd,
            // 사용자명
            @Param("userNm") String userNm,
            // BCrypt 비밀번호 해시. 공백이면 SP가 기존 값을 유지한다
            @Param("userPw") String userPw,
            // 권한그룹코드
            @Param("usrgrpCd") String usrgrpCd,
            // 부서코드
            @Param("deptCd") String deptCd,
            // 알림 발송 주소
            @Param("email") String email,
            // 휴대전화번호
            @Param("mobile") String mobile,
            // 계정 잠금여부. N이면 실패횟수도 0으로 되돌린다
            @Param("lockYn") String lockYn,
            // 사용여부
            @Param("useYn") String useYn,
            // JWT 작업자 ID — 감사 컬럼
            @Param("actorId") String actorId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 삭제 대상 전부를 배열 하나로 넘겨 차단 사유 첫 건을 받는다
     *   2) validate-delete·delete 양쪽에서 호출한다
     *   3) 사용자는 문서 이력 보존 정책상 차단 사유가 없어 항상 null이다
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
     *   1) 사용자 1건을 삭제한다 — 개인 설정(알림·그리드)도 SP가 함께 정리한다
     *   2) Double Check 통과 뒤 반복 호출한다
     *   3) 미존재면 SP가 45000으로 올린다
     */
    void delete(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대상 tbl_user.idx
            @Param("idx") Long idx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 서명 보유여부·파일명·MIME만 읽는다 — sign_yn·sign_nm·sign_mime 3개 키
     *   2) 서명 유무만 알면 되는 경로(CCP 행 서명, 삭제 전 검사)가 쓴다. 바이너리를 내리지 않아 가볍다
     *   3) 다른 회사·없는 아이디면 null, 미등록이면 sign_yn='N'이고 이름·MIME은 빈 문자열
     */
    Map<String, Object> selectSignInfo(
            // JWT 회사코드 — 테넌트 범위
            @Param("coCd") String coCd,
            // 서명 보유여부를 볼 대상 로그인 아이디
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 테넌트 내 사용자 서명 바이너리를 읽는다 — sign_img·sign_mime·sign_nm 3개 키
     *   2) 이미지 실물이 필요할 때만 쓴다(미리보기·클립보드 복사). 유무 판정에는 selectSignInfo를 쓴다
     *   3) 다른 회사·없는 아이디면 null, 미등록이면 sign_img가 null인 맵
     */
    Map<String, Object> selectSign(
            // JWT 회사코드 — 테넌트 범위
            @Param("coCd") String coCd,
            // 서명을 볼 대상 로그인 아이디
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 서명 이미지 바이너리를 tbl_user에 반영한다 — null이면 서명을 지운다
     *   2) 업로드 직후·서명 삭제에서 호출한다
     *   3) 대상 사용자가 없으면 SP가 45000으로 올린다
     */
    void updateSign(
            // JWT 회사코드 — 테넌트 안전장치
            @Param("coCd") String coCd,
            // 대상 로그인 아이디
            @Param("userId") String userId,
            // 저장할 서명 바이너리. null이면 서명 삭제
            @Param("signImg") byte[] signImg,
            // 이미지 MIME — image/png 또는 image/jpeg
            @Param("signMime") String signMime,
            // 원본 파일명 — 다운로드 파일명으로 쓴다
            @Param("signNm") String signNm,
            // JWT 작업자 ID — 감사 컬럼
            @Param("actorId") String actorId
    );
}
