/**
 * UserLoginRow.java — sp_tbl_user_login_r_000 조회 결과 Row DTO.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 검증에 필요한 사용자·회사·권한그룹·부서 정보를 한 행으로 받는다
 *   2) 아이디 1건 조회 결과이며, 아이디가 없으면 매퍼가 null을 돌려준다
 *   3) userPw(BCrypt 해시)를 담고 있으므로 이 DTO는 절대 응답 본문으로 나가지 않는다
 *      — 응답용 사용자 정보는 LoginUser로 다시 조립한다
 *
 * PIPELINE[HB24] auth DTO
 */
package com.haccp.auth.dto;

// 역할 — @Getter/@Setter 접근자 (MyBatis 매핑 대상)
import lombok.Getter;
import lombok.Setter;

/** 로그인 인증용 사용자 1건 — DB lower_snake → camelCase 자동 매핑(map-underscore-to-camel-case) */
@Getter
@Setter
public class UserLoginRow {

    /** tbl_user.idx — 대리키 */
    private Long userIdx;
    /** 로그인 아이디 */
    private String userId;
    /** 사용자명 */
    private String userNm;
    /** BCrypt 해시 비밀번호 — 검증 후 폐기하며 외부로 노출하지 않는다 */
    private String userPw;
    /** 소속 회사코드 — 테넌트 */
    private String coCd;
    /** 회사명 */
    private String coNm;
    /** 권한 그룹코드 — ADMIN / USER 등 */
    private String usrgrpCd;
    /** 권한 그룹명 */
    private String usrgrpNm;
    /** 부서코드 */
    private String deptCd;
    /** 부서명 */
    private String deptNm;
    /** 이메일 — 알림 발송 대상 */
    private String email;
    /** 서명 등록여부 Y/N — 실물 바이너리는 /users/me/sign으로만 내려간다 */
    private String signYn;
    /** 그리드 열 설정 저장 사용여부 Y/N */
    private String gridsaveYn;
    /** 연속 로그인 실패 횟수 — 임계 도달 시 lockYn이 Y가 된다 */
    private Integer loginFailCnt;
    /** 계정 잠금여부 Y/N — Y이면 비밀번호가 맞아도 거절한다 */
    private String lockYn;
    /** 사용자 사용여부 Y/N — 퇴사·정지 계정은 N */
    private String userUseYn;
    /** 회사 사용여부 Y/N — 업체 자체가 정지되면 N */
    private String coUseYn;
    /** 서비스 종료일 YYYYMMDD — 오늘보다 이전이면 구독 만료 */
    private String svcFnDt;
}
