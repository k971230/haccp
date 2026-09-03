/**
 * CcpMtlDraftMapper — CCP 금속검출 작성 SP 호출.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 데이터는 기존 tbl_ccp_metal_monitor(+_sens_row·_pass_row)다. 신규 테이블을 만들지 않았다
 *   2) 저장·헤더·삭제는 기존 sp_tbl_ccp_metal_monitor_* 를 쓴다 (124에서 p_tmpl_cd 개방)
 *   3) 감도표는 phase_cd(BEFORE·AFTER), 통과량표는 별도 행 — 두 영역이 섞이지 않는다
 *
 * PIPELINE[HB140] CCP 금속검출 작성 Mapper
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
public interface CcpMtlDraftMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 작성에 쓸 수 있는 자사 양식(사용여부 Y)만 반환한다
     *   2) 화면 진입 시 한 번, 양식 선택 팝업이 쓴다
     *   3) 없으면 빈 목록 — 화면이 양식관리 등록을 안내한다
     */
    List<DraftFormRow> selectForms(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // stdTmplCd: 계열 예시코드 html_ccp_mtl_000
            @Param("stdTmplCd") String stdTmplCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 양식 항목(한계기준·주기·방법·감도열·개선조치)을 반환한다
     *   2) 상세 조회가 헤더·기록행과 함께 조립한다
     *   3) verNo 0 이면 표준 시드
     */
    List<Map<String, Object>> selectFormItems(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
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
     *   3) 자사 양식(html_ccp_mtl_NNN)만 — 기존 금속검출 일지는 대상이 아니다
     */
    List<DraftListRow> selectList(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
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
            // title: 제목 부분검색 — tbl_document.title
            @Param("title") String title
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 헤더 한 건 — doc_idx·hdr_idx·문서번호·일자·상태·관리자
     *   2) 상세 조회가 감도행·통과량행 앞에 호출한다
     *   3) 없으면 null
     */
    Map<String, Object> selectHeader(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdx: tbl_document.idx
            @Param("docIdx") Long docIdx,
            // tmplCd: 124에서 연 양식코드 인자
            @Param("tmplCd") String tmplCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 감도 표 행을 순번대로 반환한다
     *   2) 상세 조회가 호출한다
     *   3) phase_cd 로 작업 전/작업 후가 갈린다 — 화면이 그 값으로 영역을 나눈다
     */
    List<Map<String, Object>> selectSensRows(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // hdrIdx: tbl_ccp_metal_monitor.idx
            @Param("hdrIdx") Long hdrIdx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 통과량 표 행을 순번대로 반환한다 — 품명·통과량·검출량·특이사항
     *   2) 상세 조회가 호출한다
     *   3) 없으면 빈 목록
     */
    List<Map<String, Object>> selectPassRows(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // hdrIdx: tbl_ccp_metal_monitor.idx
            @Param("hdrIdx") Long hdrIdx
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 문서·헤더·감도행·통과량행을 한 트랜잭션에서 교체 저장한다
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
            // ccpCd: CCP 구분 — 자사 양식은 양식코드를 그대로 넣는다
            @Param("ccpCd") String ccpCd,
            // mngNm: 관리자·점검자명
            @Param("mngNm") String mngNm,
            // sensRowsJson: 감도 표 행 배열 JSON
            @Param("sensRowsJson") String sensRowsJson,
            // passRowsJson: 통과량 표 행 배열 JSON
            @Param("passRowsJson") String passRowsJson,
            // userId: JWT 작업자 ID
            @Param("userId") String userId,
            // tmplCd: 작성 양식코드 — 124에서 연 인자
            @Param("tmplCd") String tmplCd,
            // title: 목록 제목. 빈값이면 SP 가 신규는 양식명(일자)·수정은 기존값을 쓴다
            @Param("title") String title
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
     *   1) 감도행·통과량행·문서 허브를 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) 전송대기(WRK·RJT)가 아니면 SP 가 막는다
     */
    void delete(
            // coCd: JWT 회사코드
            @Param("coCd") String coCd,
            // docIdx: 삭제할 tbl_document.idx
            @Param("docIdx") Long docIdx,
            // userId: JWT 작업자 ID
            @Param("userId") String userId,
            // tmplCd: 양식코드 — 124에서 연 인자
            @Param("tmplCd") String tmplCd
    );
}
