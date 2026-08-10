/**
 * MasterMapper — HACCP 기준정보 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 9개 기준정보와 CCP 한계기준을 16_sp_master.sql의 고정 SP로만 처리한다
 *   2) 삭제 참조 검사는 idx 배열 하나로 조회해 Service별 COUNT 반복을 막는다
 *   3) coCd와 userId는 Service가 JWT에서만 채워 전달한다
 *
 * PIPELINE[HB75] 기준정보 MyBatis 매퍼
 * PIPELINE[HB76, HB74, HB77] 연관 모듈
 */
package com.metis.haccp.bas;

// 역할 — 삭제 참조 차단 결과
import com.metis.haccp.common.validation.DeleteBlocker;
// 역할 — 목록 타입
import java.util.List;
// 역할 — MyBatis 매퍼 표식·이름 바인딩
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface MasterMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 유형별 기준정보 행을 JSON 문자열로 조회한다
     *   2) Service가 camelCase Map 목록으로 변환해 API에 반환한다
     *   3) 성공 시 테넌트 범위 JSON 행 목록
     */
    List<String> selectList(
            // JWT 회사코드 — SP 테넌트 필터
            @Param("coCd") String coCd,
            // 허용된 마스터 유형
            @Param("masterType") String masterType,
            // 사용여부 필터 — 공백이면 전체
            @Param("useYn") String useYn
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) JSON 행 1건을 신규 또는 수정으로 저장한다
     *   2) Service가 요청 배열을 @Transactional 안에서 순차 호출한다
     *   3) 성공 시 void — PG CALL 영향행수는 사용하지 않는다
     */
    void save(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 허용된 마스터 유형
            @Param("masterType") String masterType,
            // 유형별 camelCase JSON 행
            @Param("payload") String payload,
            // JWT 작업자 ID
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 삭제 대상 idx 배열의 첫 참조 행을 단일 조회한다
     *   2) validate-delete와 delete Double Check에서 재사용한다
     *   3) 참조가 없으면 null
     */
    DeleteBlocker selectDeleteBlocker(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 허용된 마스터 유형
            @Param("masterType") String masterType,
            // 삭제 대상 대리키 배열
            @Param("idxs") List<Long> idxs
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 기준정보 1건을 삭제한다
     *   2) Service 검증 뒤에도 SP가 참조 여부를 다시 확인한다
     *   3) 성공 시 void
     */
    void delete(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 허용된 마스터 유형
            @Param("masterType") String masterType,
            // 삭제할 대리키
            @Param("idx") Long idx,
            // JWT 작업자 ID
            @Param("userId") String userId
    );
}
