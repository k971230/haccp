/**
 * CcpLogDraftMapper — CCP 포장·가열 작성 SP 호출 (공통 CCP 계열).
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 데이터는 기존 tbl_ccp_generic_monitor(+_row·_cell)다. 신규 테이블을 만들지 않았다
 *   2) 저장·상세는 기존 sp_tbl_ccp_generic_monitor_c_000/_r_000 을 그대로 쓴다 (124에서 phase_cd 보강)
 *   3) 목록은 화면 전용 sp_ccp_log_r_000 — 양식군 접두로 PKG·HTG 를 가른다
 *
 * PIPELINE[HB139] CCP 모니터링 작성 Mapper
 */
package com.haccp.draft.ccpmonitoring;

import com.haccp.common.validation.DeleteBlocker;
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface CcpLogDraftMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 작성에 쓸 수 있는 자사 양식(사용여부 Y)만 반환한다
     *   2) 화면 진입 시 한 번, 양식 선택 팝업이 쓴다
     *   3) family 로 포장(pkg)·가열(htg) SP 를 가른다
     */
    List<DraftFormRow> selectForms(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // family: pkg | htg — XML choose 가 계열 SP 를 고른다
            @Param("family") String family,
            // stdTmplCd: 계열 예시코드 tml_ccp_pkg_000 · tml_ccp_htg_000
            @Param("stdTmplCd") String stdTmplCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 양식 항목(한계기준·주기·방법·개선조치)을 반환한다 — 지면 상단이 쓴다
     *   2) 상세 조회가 헤더·기록행과 함께 조립한다
     *   3) verNo 0 이면 표준 시드
     */
    List<Map<String, Object>> selectFormItems(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // family: pkg | htg
            @Param("family") String family,
            // tmplCd: 양식코드
            @Param("tmplCd") String tmplCd,
            // verNo: 회사 버전 순번. 0=표준
            @Param("verNo") int verNo
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 상단 검색 6개 중 서버 조건 5개로 작성 목록을 조회한다
     *   2) 좌측 그리드가 호출한다
     *   3) 결재 여부는 DOC_STATUS 파생이라 화면이 거른다
     */
    List<DraftListRow> selectList(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // tmplPfx: 양식군 접두 tml_ccp_pkg_ · tml_ccp_htg_
            @Param("tmplPfx") String tmplPfx,
            // tmplCd: 양식코드 부분검색
            @Param("tmplCd") String tmplCd,
            // tmplNm: 양식명 부분검색
            @Param("tmplNm") String tmplNm,
            // fromDt: 일자 시작 YYYYMMDD
            @Param("fromDt") String fromDt,
            // toDt: 일자 종료 YYYYMMDD
            @Param("toDt") String toDt,
            // writerId: 작성자 ID 부분검색
            @Param("writerId") String writerId,
            // writerNm: 작성자명 부분검색
            @Param("writerNm") String writerNm,
            // remark: 문서 비고 부분검색
            @Param("remark") String remark
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 저장된 문서의 헤더·기록행(rows_json)을 반환한다
     *   2) 좌측 행 클릭이 호출한다
     *   3) 없으면 null — 신규는 화면이 빈 지면을 연다
     */
    Map<String, Object> selectDetail(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdx: tbl_document.idx
            @Param("docIdx") Long docIdx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 문서·헤더·기록행·셀을 한 트랜잭션에서 저장한다
     *   2) 저장 버튼이 호출한다
     *   3) 반환은 tbl_document.idx. 전송 이후 상태면 SP 가 막는다
     */
    Long save(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdx: 기존 문서 idx. null 이면 INSERT
            @Param("docIdx") Long docIdx,
            // baseDt: 일자 YYYYMMDD
            @Param("baseDt") String baseDt,
            // tmplCd: 작성 양식코드
            @Param("tmplCd") String tmplCd,
            // mngNm: 관리자·점검자명
            @Param("mngNm") String mngNm,
            // rowsJson: 기록 행 배열 JSON — rowSeq·phaseCd·checkTime·productNm·judgeCd·checkerNm·signYn·cells
            @Param("rowsJson") String rowsJson,
            // userId: JWT 작업자 ID
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 전송·결재완료 문서의 첫 차단 행을 반환한다
     *   2) validate-delete·delete 양쪽에서 호출한다 (Double Check)
     *   3) 없으면 null
     */
    DeleteBlocker selectDeleteBlocker(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdxs: 삭제 후보 문서 idx 목록
            @Param("docIdxs") List<Long> docIdxs
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 기록행·셀·문서 허브를 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) 전송대기(WRK·RJT)가 아니면 SP 가 막는다
     */
    void delete(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdx: 삭제할 tbl_document.idx
            @Param("docIdx") Long docIdx,
            // userId: JWT 작업자 ID
            @Param("userId") String userId
    );
}
