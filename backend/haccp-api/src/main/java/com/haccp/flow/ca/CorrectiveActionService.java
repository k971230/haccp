/**
 * CorrectiveActionService — 개선조치관리 화면 업무 서비스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 목록·저장·삭제만 담당한다 — 문서에 딸린 개선조치는 DocCorrectiveSupport 몫이다
 *   2) 회사코드·작업자는 JWT 에서만 읽는다 — 본문 값을 쓰면 남의 회사 자료를 만진다
 *   3) 삭제는 validate-delete → delete 두 단계이고 SP 가 완료 상태를 다시 막는다
 *
 * PIPELINE[HB94] 개선조치관리 업무 서비스
 */
package com.haccp.flow.ca;

// 역할 — 화면 행 JSON 직렬화
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — JWT 컨텍스트·업무 예외
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
// 역할 — 삭제 대상 검증 공통
import com.haccp.common.validation.DeleteValidation;
// 역할 — 개선조치 저장·삭제 감사
import com.haccp.flow.ca.dto.CaDeleteItem;
import com.haccp.flow.ca.dto.CorrectiveRow;
import com.haccp.flow.ca.dto.CorrectiveSaveRow;
import com.haccp.sys.logs.auditlog.AuditWriter;
// 역할 — 목록
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
// 역할 — Spring 서비스·트랜잭션
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CorrectiveActionService {

    private final CorrectiveActionMapper mapper;
    private final ObjectMapper objectMapper;
    // 개선조치 쓰기 이력 — 문서에 딸린 자동 생성분은 DocCorrectiveSupport 라 여기 없다
    private final AuditWriter auditWriter;

    /** 감사 로그 대상 표 */
    private static final String AUDIT_TBL = "tbl_corrective_action";

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 기간·양식·작성자 조건으로 개선조치 목록을 조회한다
     *   2) DTO 필드가 그리드 field 와 같다
     *   3) 공백 조건은 SP 가 전체로 본다
     */
    public List<CorrectiveRow> correctiveActions(
            // 시작일 YYYYMMDD — 공백이면 전체
            String fromDt,
            // 종료일 YYYYMMDD — 공백이면 전체
            String toDt,
            // 양식코드 — 공백이면 전체
            String tmplCd,
            // 작성자 — 공백이면 전체
            String writer
    ) {
        List<CorrectiveRow> rows = mapper.selectCorrectiveActions(
                LoginUserContext.coCd(), text(fromDt), text(toDt), text(tmplCd), text(writer));
        return rows == null ? List.of() : rows;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 개선조치를 신규·수정 저장한다 — idx 가 없으면 SP 가 신규로 본다
     *   2) 화면 저장 버튼이 신규·수정 구분 없이 호출한다
     *   3) 행 전체를 jsonb 로 넘긴다 — 칸이 늘어도 SP 만 고치면 된다
     */
    @Transactional
    public void saveCorrectiveAction(
            // 화면 행 — idx 없으면 신규
            CorrectiveSaveRow payload
    ) {
        if (payload == null) throw new BizException("저장할 개선조치 자료가 없습니다.");
        Long idx = payload.getIdx();
        try {
            mapper.saveCorrectiveAction(
                    LoginUserContext.coCd(), idx,
                    objectMapper.writeValueAsString(payload), LoginUserContext.userId());
            // idx가 null일 때(= 신규) I, 값이 있을 때(= 수정) U
            auditWriter.record(AUDIT_TBL, idx, idx == null ? "I" : "U", payload);
        } catch (JsonProcessingException e) {
            throw new BizException("개선조치 저장 자료 형식이 올바르지 않습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 삭제 가능 여부만 검사하고 자료는 건드리지 않는다
     *   2) 화면이 삭제 확인창을 열기 전에 호출한다
     *   3) 완료 상태 검사는 SP 가 다시 한다 (Double Check)
     */
    public void validateCorrectiveActionDelete(
            // 삭제 키 객체 배열 — 단건도 [{ idx }]
            List<CaDeleteItem> keys
    ) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) validate-delete 와 같은 검사를 다시 한 뒤 지운다
     *   2) 화면 삭제 확인창에서 호출한다
     *   3) 완료된 건은 SP 가 막는다
     */
    @Transactional
    public void deleteCorrectiveActions(
            // 삭제 키 객체 배열 — 단건도 [{ idx }]
            List<CaDeleteItem> keys
    ) {
        assertDeletable(keys);
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        for (CaDeleteItem key : keys) {
            Long idx = key.getIdx();
            mapper.deleteCorrectiveAction(coCd, idx, userId);
            auditWriter.record(AUDIT_TBL, idx, "D", null);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-04
     * 코멘트:
     *   1) 키를 검사하고 완료된 건이 섞였는지 본다
     *   2) validate-delete 와 delete **양쪽**에서 부른다 (Double Check)
     *   3) 막히면 어느 개선조치가 왜 막히는지 문구에 실린다
     *
     * 예전에는 키 모양만 봤다. 그래서 완료 건을 고르면 **확인창을 누른 뒤에야** 실패했고,
     * 여러 건을 골랐으면 정상 건까지 같은 트랜잭션에서 롤백됐다.
     * 검사 자리를 둘로 나누는 것이 [OPS_DELETE] 규약이고, 골드는 DocumentService.assertDeletable 이다.
     */
    private void assertDeletable(List<CaDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 개선조치를 선택하세요.");
        List<Long> idxs = new ArrayList<>();
        for (CaDeleteItem key : keys) {
            idxs.add(DeleteValidation.requirePositive(
                    key == null ? null : key.getIdx(), "삭제할 개선조치를 선택하세요."));
        }
        DeleteValidation.throwIfBlocked(
                mapper.selectDeleteBlocker(LoginUserContext.coCd(), idxs), "개선조치");
    }

    private String text(String value) {
        return value == null ? "" : value.trim();
    }
}
