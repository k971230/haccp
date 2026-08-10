/**
 * DocumentMapper — 문서 허브 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 문서함·결재함·첨부·버전은 tbl_document 공통 허브를 기준으로 조회한다
 *   2) 문서 상태 변경과 파일 메타 변경은 sp_tbl_document_* 저장프로시저만 호출한다
 *   3) 목록 DTO는 화면마다 요구 필드가 달라 Map으로 받고, CUD 키·파일은 명시 타입을 쓴다
 *
 * PIPELINE[HB83] MyBatis 매퍼
 * PIPELINE[HB84] 연관 모듈
 */
package com.metis.haccp.doc;

// 역할 — 문서 파일 메타 DTO
import com.metis.haccp.doc.dto.DocumentFileRow;
// 역할 — 회사 사용 템플릿·원본 경로 DTO
import com.metis.haccp.doc.dto.DocumentTemplateRow;
// 역할 — 삭제 차단 결과
import com.metis.haccp.common.validation.DeleteBlocker;
// 역할 — 목록·상세의 가변 필드 맵
import java.util.List;
import java.util.Map;
// 역할 — MyBatis 매퍼 등록
import org.apache.ibatis.annotations.Mapper;
// 역할 — XML 이름 바인딩
import org.apache.ibatis.annotations.Param;

/** 문서 허브 SP 호출 인터페이스 */
@Mapper
public interface DocumentMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 로그인 회사가 사용 중인 구현 템플릿과 내부 원본 상대 경로를 조회한다
     *   2) 템플릿 선택 목록 API가 formUrl을 조립하기 전에 호출한다
     *   3) 성공 시 회사 범위 템플릿 목록, 미사용·미구현 양식은 SP에서 제외한다
     */
    List<DocumentTemplateRow> selectTemplates(
            // JWT 회사코드 — tbl_company_template 사용 여부를 SP에서 강제하는 테넌트 범위
            @Param("coCd") String coCd
    );

    // coCd/tmplCd/formPath: 회사 양식 원본 경로 최초·교체 등록
    // userId: JWT 작업자
    void updateCompanyTemplateFormPath(
            @Param("coCd") String coCd,
            @Param("tmplCd") String tmplCd,
            @Param("formPath") String formPath,
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 단일 템플릿의 내부 원본 상대 경로와 표시 파일명을 조회한다
     *   2) form 스트림 API가 물리 파일을 열기 직전에 호출한다
     *   3) 다른 회사·미사용·미구현 코드면 null을 반환해 서비스가 업무 오류로 바꾼다
     */
    DocumentTemplateRow selectTemplate(
            // JWT 회사코드 — 다른 테넌트 템플릿 접근을 차단하는 SP 첫 인자
            @Param("coCd") String coCd,
            // URL 경로 템플릿 코드 — 표준 tbl_template 업무키
            @Param("tmplCd") String tmplCd
    );

    List<Map<String, Object>> selectDocuments(
            @Param("coCd") String coCd,
            @Param("fromDt") String fromDt,
            @Param("toDt") String toDt,
            @Param("tmplCd") String tmplCd,
            @Param("status") String status,
            @Param("keyword") String keyword,
            @Param("writerId") String writerId
    );

    /** 결재함 — 내 차례 대기 문서 */
    List<Map<String, Object>> selectApprovalInbox(
            @Param("coCd") String coCd,
            @Param("userId") String userId,
            @Param("fromDt") String fromDt,
            @Param("toDt") String toDt,
            @Param("keyword") String keyword
    );

    /** 결재 이력 — 내가 승인·반려한 문서 */
    List<Map<String, Object>> selectApprovalHistory(
            @Param("coCd") String coCd,
            @Param("userId") String userId,
            @Param("fromDt") String fromDt,
            @Param("toDt") String toDt,
            @Param("keyword") String keyword
    );

    Map<String, Object> selectDocument(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx
    );

    List<Map<String, Object>> selectApprovals(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx
    );

    List<DocumentFileRow> selectFiles(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx
    );

    DocumentFileRow selectFile(
            @Param("coCd") String coCd,
            @Param("fileIdx") Long fileIdx
    );

    List<Map<String, Object>> selectVersions(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx
    );

    Long insertFile(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx,
            @Param("fileKind") String fileKind,
            @Param("fileNm") String fileNm,
            @Param("filePath") String filePath,
            @Param("fileSize") Long fileSize,
            @Param("mimeType") String mimeType,
            @Param("userId") String userId
    );

    Long saveHwpDocument(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx,
            @Param("tmplCd") String tmplCd,
            @Param("baseDt") String baseDt,
            @Param("baseDtTo") String baseDtTo,
            @Param("title") String title,
            @Param("userId") String userId
    );

    void deleteFile(
            @Param("coCd") String coCd,
            @Param("fileIdx") Long fileIdx,
            @Param("userId") String userId
    );

    /**
     * 문서·파일종류별 메타 일괄 삭제 — HWP_SRC 덮어쓰기 전.
     * 물리 파일은 Service가 경로를 미리 모아 제거한다.
     */
    void deleteFilesByKind(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx,
            @Param("fileKind") String fileKind,
            @Param("userId") String userId
    );

    void processApproval(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx,
            @Param("actionCd") String actionCd,
            @Param("opinion") String opinion,
            @Param("userId") String userId
    );

    DeleteBlocker selectDocumentDeleteBlocker(
            @Param("coCd") String coCd,
            @Param("docIdxs") List<Long> docIdxs
    );

    void deleteDocument(
            @Param("coCd") String coCd,
            @Param("docIdx") Long docIdx,
            @Param("userId") String userId
    );

    void insertAudit(
            @Param("coCd") String coCd,
            @Param("userId") String userId,
            @Param("tblNm") String tblNm,
            @Param("tgtIdx") Long tgtIdx,
            @Param("actionCd") String actionCd,
            @Param("beforeJson") String beforeJson,
            @Param("afterJson") String afterJson,
            @Param("reason") String reason,
            @Param("ipAddr") String ipAddr
    );
}
