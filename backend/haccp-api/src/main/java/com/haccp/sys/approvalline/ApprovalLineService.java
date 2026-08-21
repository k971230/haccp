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
package com.haccp.sys.approvalline;

// 역할 — JSON 변환
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — JWT · 업무 예외 · 삭제 표준
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.sys.approvalline.dto.ApprovalLineDeleteItem;
// 역할 — 목록
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
// 역할 — 생성자 DI · 트랜잭션
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ApprovalLineService {

    private final ApprovalLineMapper mapper;
    private final ObjectMapper objectMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 회사 결재선 목록을 객체로 펼친다
     *   2) 화면 조회·점검항목 결재선 콤보가 호출한다
     *   3) payload가 깨지면 업무 오류
     */
    public List<Map<String, Object>> list() {
        // coCd: JWT 회사코드 — SP 테넌트 범위
        List<Map<String, Object>> rows = new ArrayList<>();
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
            Map<String, Object> row
    ) {
        requireText(row, "apprLineCd", "결재선 코드를 입력하세요.");
        requireText(row, "apprLineNm", "결재선명을 입력하세요.");
        mapper.saveApprovalLine(LoginUserContext.coCd(), writeJson(row), LoginUserContext.userId());
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
            Map<String, Object> blocker = mapper.selectApprovalLineBlocker(coCd, apprLineCd);
            if (blocker != null) {
                throw new BizException(
                        "선택한 결재선 '" + apprLineCd
                                + "'이(가) 사용양식 또는 문서에서 참조 중이므로 삭제할 수 없습니다.");
            }
        }
    }

    private static String text(Object value) {
        return value == null ? "" : String.valueOf(value).trim();
    }

    private static void requireText(Map<String, Object> row, String field, String message) {
        if (text(row.get(field)).isBlank()) {
            throw new BizException(message);
        }
    }

    private Map<String, Object> readJson(String payload) {
        try {
            return objectMapper.readValue(payload, new TypeReference<Map<String, Object>>() { });
        } catch (JsonProcessingException ex) {
            throw new BizException("결재선 자료를 읽지 못했습니다.");
        }
    }

    private String writeJson(Map<String, Object> row) {
        try {
            return objectMapper.writeValueAsString(row);
        } catch (JsonProcessingException ex) {
            throw new BizException("결재선 자료를 저장하지 못했습니다.");
        }
    }
}
