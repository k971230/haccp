/**
 * CompanyMapper — 테넌트 통째 삭제 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-09-11
 * 코멘트:
 *   1) 존재 확인·트리 역순 삭제 SP 만 부른다
 *   2) 화면이 없어 목록·저장 SP 는 없다
 *   3) 대상 coCd 는 서비스가 넘긴다. JWT 회사와 같을 수 없다
 *
 * PIPELINE[HB146] 업체 삭제 매퍼
 */
package com.haccp.sys.company;

// 역할 — MyBatis 매퍼 표식·이름 바인딩
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface CompanyMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-09-11
     * 코멘트:
     *   1) 지울 회사가 있는지 센다
     *   2) validate-delete·delete Double Check 가 호출한다
     *   3) 0 이면 없는 회사
     */
    int countCompany(
            // 지울 회사코드
            @Param("coCd") String coCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-09-11
     * 코멘트:
     *   1) 테넌트 트리를 역순으로 지운다
     *   2) assertDeletable 통과 뒤에만 호출한다
     *   3) 플랫폼 0000 은 SP 가 한 번 더 막는다
     */
    void purgeCompany(
            // 지울 회사코드
            @Param("coCd") String coCd,
            // 행위자 — 감사·SP p_id
            @Param("userId") String userId
    );
}
