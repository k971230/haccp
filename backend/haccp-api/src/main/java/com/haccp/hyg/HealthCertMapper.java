/**
 * HealthCertMapper — 건강진단관리기록부 MyBatis 경계.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 목록·저장·삭제는 sp_tbl_health_cert_* 만 호출한다
 *   2) 단건 조회는 첨부 업로드 시 기존 행을 읽어 filePath를 합칠 때 쓴다
 *   3) coCd·userId는 Service가 JWT에서만 넘긴다
 *
 * PIPELINE[HB95] 건강진단 Mapper
 * PIPELINE[HB94, HB96, HB97] 연관 모듈
 */
package com.haccp.hyg;

// 역할 — MyBatis 매퍼 등록
import org.apache.ibatis.annotations.Mapper;
// 역할 — XML 파라미터 이름 고정
import org.apache.ibatis.annotations.Param;
// 역할 — 목록 결과
import java.util.List;

@Mapper
public interface HealthCertMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 건강진단 목록을 JSON 문자열 행으로 조회한다
     *   2) 성명·사용여부 필터가 비면 SP가 전체로 본다
     *   3) 성공 시 jsonb text 목록
     */
    List<String> selectList(
            // JWT 회사코드 — 테넌트 범위
            @Param("coCd") String coCd,
            // 성명 부분검색 — 공백이면 전체
            @Param("personNm") String personNm,
            // 사용여부 Y/N — 공백이면 전체
            @Param("useYn") String useYn
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 첨부 업로드 전에 기존 행 JSON을 읽는다
     *   2) 저장 SP가 성명·검진일을 필수로 받으므로 병합에 쓴다
     *   3) 없으면 null
     */
    String selectByIdx(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 대상 대리키
            @Param("idx") Long idx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 건강진단 행을 신규 또는 수정으로 저장한다
     *   2) payload는 camelCase JSON(personNm·examDt·filePath 등)
     *   3) CALL 영향행수는 쓰지 않는다
     */
    void save(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 저장 행 JSON 문자열
            @Param("payload") String payload,
            // JWT 사용자 ID — 감사 컬럼
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 건강진단 1건을 SP로 삭제한다
     *   2) Service Double Check 뒤에서만 호출한다
     *   3) 없으면 SP가 업무 예외를 던진다
     */
    void delete(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대리키
            @Param("idx") Long idx,
            // JWT 사용자 ID
            @Param("userId") String userId
    );
}
