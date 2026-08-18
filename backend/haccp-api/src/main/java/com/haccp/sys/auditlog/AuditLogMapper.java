/**
 * AuditLogMapper — 변경 감사 이력 화면(audit-log) SP 호출 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 화면 조회 sp_audit_log_r_000 과 적재 sp_tbl_audit_log_c_000 두 계약을 갖는다
 *   2) coCd는 Service·AuditWriter가 JWT 컨텍스트에서만 채운다
 *   3) 적재는 감사 대상 도메인이 AuditWriter를 통해서만 호출한다 — 화면에 저장 엔드포인트는 없다
 *
 * PIPELINE[HB92] 감사 이력 MyBatis 매퍼
 */
package com.haccp.sys.auditlog;

// 역할 — MyBatis 매퍼 등록
import org.apache.ibatis.annotations.Mapper;
// 역할 — 다중 파라미터 이름 바인딩
import org.apache.ibatis.annotations.Param;

// 역할 — 이력 행 목록
import java.util.List;
import java.util.Map;

@Mapper
public interface AuditLogMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 기간 내 변경 감사 이력을 최신순으로 조회한다
     *   2) 화면 진입·조회와 좌측 메뉴 트리 선택 시 호출한다
     *   3) 해당 기간에 이력이 없으면 빈 목록
     */
    List<Map<String, Object>> selectRows(
            // JWT 회사코드 — 테넌트 범위. 필수 등가 조건
            @Param("coCd") String coCd,
            // 조회 시작일 YYYYMMDD
            @Param("fromDt") String fromDt,
            // 조회 종료일 YYYYMMDD — 그날 24시 직전까지 포함
            @Param("toDt") String toDt,
            // 좌측 메뉴 트리 선택값(테이블명·화면코드·메뉴명). 공백이면 전체
            @Param("menuKey") String menuKey,
            // 행위자 아이디 검색어. 공백이면 전체
            @Param("userId") String userId,
            // 행위 필터 I/U/D/APV/RJT 등. 공백이면 전체
            @Param("actionCd") String actionCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-13
     * 코멘트:
     *   1) 변경 감사 이력 한 건을 적재한다
     *   2) 시스템 관리 5화면의 저장·삭제가 원 업무와 같은 트랜잭션에서 호출한다
     *   3) 원 업무가 롤백되면 이력도 함께 사라져 "실패한 변경"이 남지 않는다
     */
    void insertAudit(
            // JWT 회사코드 — 테넌트 범위
            @Param("coCd") String coCd,
            // 행위자 로그인 아이디 — JWT에서만 읽는다
            @Param("userId") String userId,
            // 대상 테이블명 — tbl_ 접두 포함. audit-target 공통코드의 sub_cd와 같아야 표시명이 붙는다
            @Param("tblNm") String tblNm,
            // 대상 행 idx — 신규 등록처럼 아직 idx를 모르면 null
            @Param("tgtIdx") Long tgtIdx,
            // 행위 — I:등록, U:수정, D:삭제
            @Param("actionCd") String actionCd,
            // 변경 전 값 JSON 문자열. 빈 문자열이면 SP가 NULL로 넣는다
            @Param("beforeJson") String beforeJson,
            // 변경 후 값 JSON 문자열. 삭제면 빈 문자열
            @Param("afterJson") String afterJson,
            // 사유 — 시스템 관리 저장·삭제는 사유를 받지 않으므로 빈 문자열
            @Param("reason") String reason,
            // 행위자 IP — 요청 컨텍스트가 없으면 null
            @Param("ipAddr") String ipAddr
    );
}
