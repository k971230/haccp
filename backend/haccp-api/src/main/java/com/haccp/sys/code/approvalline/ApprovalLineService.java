/**
 * ApprovalLineService — 결재선 헤더·단계 업서트와 삭제 Double Check.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 회사코드·작업자는 JWT에서만 읽고 본문의 테넌트 값은 버린다
 *   2) 저장은 헤더+고정 3단계(작성·검토·승인)를 한 번에 보낸다. 검토 기본은 사용안함
 *   3) 삭제는 왼쪽 버튼이 호출하고, validate-delete·delete 양쪽에서 같은 참조 검사를 한다
 *
 * PIPELINE[HB91] 결재선 관리 Service
 */
package com.haccp.sys.code.approvalline;

// 역할 — JSON 변환
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — JWT · 업무 예외 · 삭제 표준
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.sys.code.approvalline.dto.ApprovalLineDeleteItem;
import com.haccp.sys.code.approvalline.dto.ApprovalLineRow;
// 역할 — 변경 감사 이력 적재
import com.haccp.sys.logs.auditlog.AuditWriter;
// 역할 — 목록
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
// 역할 — 생성자 DI · 트랜잭션
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ApprovalLineService {

    /** 삭제 차단 문구에 쓰는 업무명 */
    private static final String LABEL = "결재선";
    /** 감사 이력 대상 테이블명 — 형제 5화면과 같은 규칙(tbl_ 접두 포함) */
    private static final String AUDIT_TBL = "tbl_approval_line";

    private final ApprovalLineMapper mapper;
    private final ObjectMapper objectMapper;
    // 저장·삭제 변경 감사 적재 — 결재선은 누가 결재하는지를 정한다. 조용히 바뀌면 안 된다
    private final AuditWriter auditWriter;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 회사 결재선 목록을 객체로 펼친다
     *   2) 화면 조회·점검항목 결재선 콤보가 호출한다
     *   3) payload가 깨지면 업무 오류
     */
    public List<ApprovalLineRow> list() {
        // coCd: JWT 회사코드 — SP 테넌트 범위
        List<ApprovalLineRow> rows = new ArrayList<>();
        for (String payload : mapper.selectApprovalLines(LoginUserContext.coCd())) {
            rows.add(readJson(payload));
        }
        return rows;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 결재선 1건과 단계 배열을 저장한다
     *   2) 좌측 저장 버튼이 호출한다
     *   3) 코드·명칭이 비면 업무 오류. 단계는 SP가 다시 검사한다
     */
    @Transactional(timeout = 60)
    public void save(
            // row: 화면 폼 1건 — apprLineCd·apprLineNm·useYn·steps[]
            ApprovalLineRow row
    ) {
        if (row == null) {
            throw new BizException("저장할 " + LABEL + " 행이 올바르지 않습니다.");
        }
        if (text(row.getApprLineCd()).isBlank()) {
            throw new BizException("결재선 코드를 입력하세요.");
        }
        if (text(row.getApprLineNm()).isBlank()) {
            throw new BizException("결재선명을 입력하세요.");
        }
        mapper.saveApprovalLine(LoginUserContext.coCd(), writeJson(row), LoginUserContext.userId());
        /*
         * 화면이 신규 여부를 실어 보낸다(newYn) — 형제 화면의 idx 자리와 같은 뜻이다.
         * 그 값으로 감사 행위를 가른다. 예전에는 UPSERT 한 건이라 못 가르고 U 로 통일했다.
         */
        boolean isNew = "Y".equalsIgnoreCase(text(row.getNewYn()));
        auditWriter.record(AUDIT_TBL, null, isNew ? "I" : "U", auditRow(row));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) API 호출 직전 확인용
     *   3) 참조 중이면 BizException
     */
    public void validateDelete(
            // keys: 삭제 대상 복합키 목록 — UI 단건이어도 List
            List<ApprovalLineDeleteItem> keys
    ) {
        assertDeletable(LoginUserContext.coCd(), keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 같은 검사를 한 뒤 삭제 SP를 루프 호출한다
     *   2) 왼쪽 삭제 버튼이 호출한다
     *   3) 한 건이라도 차단이면 트랜잭션 롤백
     */
    @Transactional(timeout = 60)
    public void delete(
            // keys: 삭제 대상 복합키 목록
            List<ApprovalLineDeleteItem> keys
    ) {
        String coCd = LoginUserContext.coCd();
        assertDeletable(coCd, keys);
        for (ApprovalLineDeleteItem key : keys) {
            mapper.deleteApprovalLine(coCd, key.getApprLineCd().trim(), LoginUserContext.userId());
            auditWriter.record(AUDIT_TBL, null, "D", null);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 키 형식과 기본 결재선·사용양식·문서 참조를 검사한다
     *   2) validateDelete·delete 양쪽에서 호출한다
     *   3) keys가 비면 BizException
     */
    private void assertDeletable(
            // coCd: JWT 회사코드
            String coCd,
            // keys: 삭제 대상
            List<ApprovalLineDeleteItem> keys
    ) {
        DeleteValidation.requireItems(keys, "삭제할 결재선을 선택하세요.");
        for (ApprovalLineDeleteItem key : keys) {
            if (key == null || text(key.getApprLineCd()).isBlank()) {
                throw new BizException("삭제할 결재선 코드가 올바르지 않습니다.");
            }
            String apprLineCd = key.getApprLineCd().trim();
            // 회사 온보딩이 넣는 기본 결재선 — 양식 미지정 시에도 DEFAULT 로 상신한다
            if (apprLineCd.equalsIgnoreCase("DEFAULT")) {
                throw new BizException("기본 결재선 'DEFAULT'은(는) 시스템 기본 설정이므로 삭제할 수 없습니다.");
            }
            DeleteValidation.throwIfBlocked(
                    mapper.selectApprovalLineBlocker(coCd, apprLineCd), LABEL);
        }
    }

    private static String text(String value) {
        return value == null ? "" : value.trim();
    }

    private static Map<String, Object> auditRow(ApprovalLineRow row) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("apprLineCd", row.getApprLineCd());
        out.put("apprLineNm", row.getApprLineNm());
        out.put("useYn", row.getUseYn());
        out.put("newYn", row.getNewYn());
        return out;
    }

    private ApprovalLineRow readJson(String payload) {
        try {
            return objectMapper.readValue(payload, ApprovalLineRow.class);
        } catch (JsonProcessingException ex) {
            throw new BizException("결재선 자료를 읽지 못했습니다.");
        }
    }

    private String writeJson(ApprovalLineRow row) {
        try {
            return objectMapper.writeValueAsString(row);
        } catch (JsonProcessingException ex) {
            throw new BizException("결재선 자료를 저장하지 못했습니다.");
        }
    }
}
