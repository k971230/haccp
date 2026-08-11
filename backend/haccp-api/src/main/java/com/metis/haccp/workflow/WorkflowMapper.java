/**
 * WorkflowMapper — HACCP 관리 범위 저장프로시저 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 결재선·양식/점검항목·작성주기·내보내기이력·스마트일지매핑 고정 SP 계약만 노출한다
 *   2) payload는 화면 고정 DTO를 JSON으로 변환한 값이며 SQL 식별자를 동적으로 만들지 않는다
 *   3) 삭제는 사전 검증·업무키 객체 배열 또는 단건 복합키로 Service가 호출한다
 *
 * PIPELINE[HB88] 워크플로 관리 MyBatis 매퍼
 * PIPELINE[HB74, HB87] 연관 모듈
 */
package com.metis.haccp.workflow;

// 역할 — 목록·가변 JSON 응답 타입
import java.util.List;
import java.util.Map;
// 역할 — MyBatis 등록·이름 바인딩
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface WorkflowMapper {

    List<String> selectApprovalLines(@Param("coCd") String coCd);

    void saveApprovalLine(@Param("coCd") String coCd, @Param("payload") String payload, @Param("userId") String userId);

    Map<String, Object> selectApprovalLineBlocker(@Param("coCd") String coCd, @Param("apprLineCd") String apprLineCd);

    void deleteApprovalLine(@Param("coCd") String coCd, @Param("apprLineCd") String apprLineCd, @Param("userId") String userId);

    List<Map<String, Object>> selectTemplates(@Param("coCd") String coCd);

    void saveCompanyTemplate(
            @Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("tmplNmOvr") String tmplNmOvr,
            @Param("apprLineCd") String apprLineCd, @Param("cycleCd") String cycleCd,
            @Param("retentionMonth") Integer retentionMonth, @Param("useYn") String useYn, @Param("userId") String userId
    );

    // tmplCd: 전역 카탈로그 존재 여부 — 법적서류 신규 유형 분기
    int countTemplateCatalog(@Param("tmplCd") String tmplCd);

    // coCd/tmplCd/tmplNm: 회사 전용 LAW 유형 신규 — sys_yn=N
    // userId: JWT 작업자
    void createLegalType(
            @Param("coCd") String coCd,
            @Param("tmplCd") String tmplCd,
            @Param("tmplNm") String tmplNm,
            @Param("userId") String userId
    );

    // coCd/tmplCd: JWT 테넌트 회사 양식 — 없으면 null
    // 성공 시 sys_yn (Y=시스템 배포분)
    String selectCompanyTemplateSysYn(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd);

    // coCd/tmplCd/tmplNmOvr/formPath: 자사 업로드 원본 등록 — sys_yn=N
    // userId: JWT 작업자
    void createCompanyTemplateCustom(
            @Param("coCd") String coCd,
            @Param("tmplCd") String tmplCd,
            @Param("tmplNmOvr") String tmplNmOvr,
            @Param("formPath") String formPath,
            @Param("userId") String userId
    );

    // coCd: JWT 회사 — 타사 양식 참조가 섞이지 않도록 제한
    // keysJson: [{tmplCd}] JSON 배열 — UI 단건이어도 1건 배열
    // 성공 시 문서 참조로 삭제 불가한 첫 차단 행들
    List<Map<String, Object>> selectCompanyTemplateDeleteBlockers(
            @Param("coCd") String coCd, @Param("keysJson") String keysJson
    );

    // coCd/tmplCd: JWT 테넌트의 회사 양식 행 — sys_yn=Y면 SP가 거부
    // userId: JWT 작업자 — 삭제 감사
    void deleteCompanyTemplate(
            @Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("userId") String userId
    );

    List<Map<String, Object>> selectCheckItems(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd);

    void saveCheckItem(
            @Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("itemCd") String itemCd,
            @Param("itemNmOvr") String itemNmOvr, @Param("sortNo") Integer sortNo,
            @Param("useYn") String useYn, @Param("userId") String userId
    );

    // coCd/tmplCd/itemCd: 회사 전용(CUST*) 점검항목 존재 여부 — assertDeletable Double Check
    // 성공 시 1건 이상이면 삭제 가능
    int countCompanyCheckItem(
            @Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("itemCd") String itemCd
    );

    // coCd/tmplCd/itemCd: JWT 테넌트와 삭제 복합키 — SP가 CUST*만 허용
    // userId: JWT 작업자 — SP 감사 자리
    void deleteCheckItem(
            @Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("itemCd") String itemCd,
            @Param("userId") String userId
    );

    // coCd: JWT 회사코드 — 자사 양식 복제본을 해당 테넌트 범위로 제한
    // tmplCd: 원본 표준 양식 코드 — 공백이 아닐 때(= 특정 기본 양식 선택) 해당 파생본만 조회
    // 성공 시 자사 양식 헤더·작성 활성 여부 목록
    List<Map<String, Object>> selectCompanyForms(@Param("coCd") String coCd, @Param("tmplCd") String tmplCd);

    // coCd: JWT 회사코드 — 타사 자사 양식 항목이 노출되지 않도록 SP가 다시 검증
    // coFormIdx: 자사 양식 대리키 — 0 이하일 때(= 자사 양식 미선택) Service에서 차단
    // 성공 시 복제 후 독립 편집 가능한 점검항목 목록
    List<Map<String, Object>> selectCompanyFormItems(@Param("coCd") String coCd, @Param("coFormIdx") Long coFormIdx);

    // coCd: JWT 회사코드 — 새 복제본 소유회사
    // tmplCd/formNm: 플랫폼 원본 양식과 자사 표시명 — formNm 공백이면 SP가 표준명 기반으로 생성
    // userId: JWT 작업자 — 복제 헤더·항목 감사컬럼
    void cloneCompanyForm(
            @Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("formNm") String formNm,
            @Param("userId") String userId
    );

    // coCd/coFormIdx: JWT 테넌트와 선택 자사 양식 — 기본 양식 행은 이 경로로 수정할 수 없다
    // payload: 자사 항목 camelCase JSON — idx가 없을 때(= 신규) 추가, 있으면 수정
    // userId: JWT 작업자 — 감사컬럼
    void saveCompanyFormItem(
            @Param("coCd") String coCd, @Param("coFormIdx") Long coFormIdx, @Param("payload") String payload,
            @Param("userId") String userId
    );

    // coCd/tmplCd: JWT 회사의 기본 양식 설정 행
    // coFormIdx: 활성 자사 양식 — null일 때(= 기본 양식 사용) 자사 복제본은 삭제하지 않는다
    // userId: JWT 작업자 — 활성 전환 감사컬럼
    void activateCompanyForm(
            @Param("coCd") String coCd, @Param("tmplCd") String tmplCd, @Param("coFormIdx") Long coFormIdx,
            @Param("userId") String userId
    );

    // STEP 20 / G-14: select/save/deleteSmartDiary* Mapper 제거 (XML·SP 호출 경로 폐기)

    // coCd: JWT 회사코드 — 타사 내보내기 이력이 섞이지 않도록 제한
    // docKind: DB/HWP 필터 — 공백이면 전체 이력
    // 성공 시 패키지명·종류·비고·등록일시 목록(payload 제외)
    List<Map<String, Object>> selectTemplateExportHist(@Param("coCd") String coCd, @Param("docKind") String docKind);

    // coCd/idx: JWT 회사의 이력 대리키 — 없으면 빈 결과
    // 성공 시 payload(json text) 포함 단건
    Map<String, Object> selectTemplateExportHistOne(@Param("coCd") String coCd, @Param("idx") Long idx);

    // coCd/packNm/docKind/payload: 내보내기 패키지 헤더와 설정 JSON
    // fileRef/remk: 선택 파일참조·비고 — 공백이면 SP가 NULL 저장
    // userId: JWT 작업자 — 등록자
    // 성공 시 신규 이력 idx
    Long insertTemplateExportHist(
            @Param("coCd") String coCd, @Param("packNm") String packNm, @Param("docKind") String docKind,
            @Param("payload") String payload, @Param("fileRef") String fileRef, @Param("remk") String remk,
            @Param("userId") String userId
    );

    List<Map<String, Object>> selectScheduleRules(@Param("coCd") String coCd);

    void saveScheduleRule(@Param("coCd") String coCd, @Param("payload") String payload, @Param("userId") String userId);

    void deleteScheduleRule(@Param("coCd") String coCd, @Param("idx") Long idx, @Param("userId") String userId);
}
