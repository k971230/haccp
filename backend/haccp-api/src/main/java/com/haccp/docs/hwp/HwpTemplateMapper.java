/**
 * HwpTemplateMapper — 사용양식관리 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 84 마이그레이션의 sp_hwp_template_management_* 만 호출한다
 *   2) 조회는 FUNCTION(map), 저장·적용은 PROCEDURE CALL이다
 *   3) coCd·userId는 Service가 JWT에서만 채워 전달한다
 *
 * PIPELINE[HB123] 사용양식 MyBatis 매퍼
 * PIPELINE[HB92, HB88] 연관 모듈
 */
package com.haccp.docs.hwp;

// 역할 — 삭제 차단 첫 행
import com.haccp.common.validation.DeleteBlocker;
// 역할 — 목록 타입
import java.util.List;
import java.util.Map;
// 역할 — MyBatis 매퍼 표식·이름 바인딩
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface HwpTemplateMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 사용양식관리 좌측 목록 — hwp 양식·미사용 포함, 구분·파일명·이력건수
     *   2) 화면 진입·조회·저장/삭제 후 호출한다
     *   3) 검색어가 비면 회사 전체
     */
    List<Map<String, Object>> selectHwpTemplates(
            // JWT 회사 — 사용양식 범위
            @Param("coCd") String coCd,
            // 양식코드 검색어 — 공백이면 전체
            @Param("tmplCd") String tmplCd,
            // 양식명 검색어 — 공백이면 전체
            @Param("tmplNm") String tmplNm,
            // 구분 — sys(시스템제공)|usr(자사). 공백이면 전체
            @Param("sysYn") String sysYn,
            // 사용여부 — Y|N. 공백이면 전체(미사용 포함)
            @Param("useYn") String useYn
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 사용양식 1건을 저장한다 — 신규는 SP가 sys_yn=usr 로 강제한다
     *   2) 화면 저장 버튼에서 호출한다
     *   3) 성공 시 void
     */
    void saveHwpTemplate(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 양식코드 — 신규만 입력, 이후 잠금
            @Param("tmplCd") String tmplCd,
            // 표시명
            @Param("tmplNm") String tmplNm,
            // 사용유무 Y/N
            @Param("useYn") String useYn,
            // JWT 작업자
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 선택 양식의 파일 이력을 조회한다 — del_yn=N 만
     *   2) 「불러오기」 팝업에서 호출한다
     *   3) 최근 업로드가 먼저 오고 현재적용·기본제공 표시를 포함한다
     */
    List<Map<String, Object>> selectHwpTemplateFiles(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 선택한 양식코드
            @Param("tmplCd") String tmplCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 이력 버전을 현재 적용본으로 바꾸거나(불러오기) 기본 제공본으로 되돌린다(초기화)
     *   2) 「불러오기」 확정·「초기화」에서 호출한다
     *   3) fileIdx 가 null일 때(= 초기화) SP가 default_file_idx 를 쓴다
     */
    void applyHwpTemplateFile(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 적용 대상 양식코드
            @Param("tmplCd") String tmplCd,
            // 적용할 이력 idx — null이면 초기화
            @Param("fileIdx") Long fileIdx,
            // JWT 작업자
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 삭제하면 안 되는 첫 양식 1건을 돌려준다 — 시스템 제공분·작성된 문서
     *   2) validate-delete·delete 양쪽이 같은 검사를 다시 부른다
     *   3) 지울 수 있으면 null
     */
    DeleteBlocker selectDeleteBlocker(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대상 양식코드 배열
            @Param("tmplCds") List<String> tmplCds
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 사용양식 1건을 지운다 — 파일 이력은 논리삭제, 자사 카탈로그 행은 함께 정리
     *   2) 차단 검사를 통과한 뒤에만 부른다
     *   3) SP 가 시스템 제공분을 한 번 더 막는다
     */
    void deleteHwpTemplate(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대상 양식코드
            @Param("tmplCd") String tmplCd,
            // JWT 작업자
            @Param("userId") String userId
    );
}
