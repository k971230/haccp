/**
 * UserSaveRow — 사용자 저장 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 화면 그리드가 보내는 camelCase 키를 그대로 받는다
 *   2) Map 대신 타입을 고정해 오타가 컴파일에서 난다
 *   3) coCd·작업자는 JWT 만
 *
 * PIPELINE[HB93] 사용자 관리 DTO
 */
package com.haccp.sys.code.user.dto;

import lombok.Data;

@Data
public class UserSaveRow {
    // tbl_user.idx — 없으면 신규
    private Long idx;
    // 로그인 아이디
    private String userId;
    // 사원코드
    private String empCd;
    // 사용자명
    private String userNm;
    // 비밀번호 평문 — 서버가 해시한 뒤에만 SP 로 간다. 수정에서 공백이면 유지
    private String userPw;
    // 권한그룹코드
    private String usrgrpCd;
    // 부서코드
    private String deptCd;
    // 이메일
    private String email;
    // 휴대전화
    private String mobile;
    // 잠금여부 Y/N
    private String lockYn;
    // 사용여부 Y/N
    private String useYn;
}
