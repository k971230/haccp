/**
 * HygieneService — 위생관리 DB형 양식(일일·방충) 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) HTML 화면코드와 html_sys 양식코드는 1:1이다. 옛 tmpl_* 별칭·HWP 코드는 넣지 않는다
 *   2) 저장은 JSON 전체 교체이며 문서 상태 잠금은 SP와 Service 삭제검증이 함께 지킨다
 *   3) validate-delete와 delete 모두 assertDeletable을 실행하는 Double Check 구조다
 *
 * PIPELINE[HB86] 위생 Service
 * PIPELINE[HB83, HB84, HB85] 연관 모듈
 */
package com.haccp.hyg;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.doc.DocCorrectiveSupport;
import com.haccp.hyg.dto.HygieneDeleteItem;
import com.haccp.hyg.dto.HygieneListRow;
import com.haccp.hyg.dto.HygieneSaveRequest;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class HygieneService {
    private final HygieneMapper mapper;
    private final ObjectMapper objectMapper;
    private final DocCorrectiveSupport correctiveSupport;

    /** HTML 화면코드 → html_sys 양식코드. 등록되지 않은 화면은 막는다. */
    private static final Map<String, String> SCREEN_TMPL = Map.of(
            "daily-hygiene-check", "html_sys_007",
            "pest-control-check", "html_sys_008"
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 목록을 양식·기간·문서번호·작성자로 조회한다
     *   2) 공백 조건은 SP에서 전체로 본다
     *   3) 실패는 업무 예외로 반환한다
     */
    public List<HygieneListRow> list(String screenCode, String fromDt, String toDt, String docNo, String writer) {
        return mapper.selectList(
                LoginUserContext.coCd(),
                templateOf(screenCode),
                nvl(fromDt),
                nvl(toDt),
                nvl(docNo),
                nvl(writer)
        );
    }

    /** 개발자: 박승우 | 일자: 2026-08-06 | 코멘트: 기존 상세 또는 신규 기본행을 반환하고, 상세 JSON 파싱 실패는 서버 저장 형식 오류로 처리한다. */
    public JsonNode detail(String screenCode, Long docIdx) {
        try {
            ObjectNode root = (ObjectNode) objectMapper.readTree(
                    mapper.selectDetail(LoginUserContext.coCd(), templateOf(screenCode), docIdx));
            if (docIdx != null && docIdx > 0) {
                root.set("corrective", objectMapper.valueToTree(
                        correctiveSupport.load(LoginUserContext.coCd(), docIdx)));
            } else {
                root.putNull("corrective");
            }
            return root;
        } catch (JsonProcessingException e) {
            throw new BizException("점검표 자료를 읽지 못했습니다.");
        }
    }

    /** 개발자: 박승우 | 일자: 2026-08-06 | 코멘트: 행 전체를 저장하고 문서 idx를 반환하며, 기준일·행은 SP에서 재검증하고, 성공 시 새 문서번호가 유지된다. */
    @Transactional
    public Long save(String screenCode, HygieneSaveRequest req) {
        try {
            String tmplCd = templateOf(screenCode);
            String payloadJson = objectMapper.writeValueAsString(req.getPayload());
            Long docIdx = mapper.save(LoginUserContext.coCd(), tmplCd, req.getDocIdx(),
                    req.getBaseDt().trim(), nvl(req.getBaseDtTo()), nvl(req.getCheckerNm()),
                    payloadJson, LoginUserContext.userId());
            if (docIdx == null || docIdx <= 0) throw new BizException("저장에 실패했습니다.");
            boolean hasNg = payloadJson.contains("\"judgeCd\":\"X\"")
                    || payloadJson.contains("\"judgeCd\":\"F\"")
                    || payloadJson.contains("\"judge_cd\":\"X\"")
                    || payloadJson.contains("\"judge_cd\":\"F\"");
            correctiveSupport.saveAutoIfNg(
                    LoginUserContext.coCd(), docIdx, tmplCd, req.getBaseDt().trim(),
                    req.getCorrective(), hasNg, LoginUserContext.userId());
            return docIdx;
        } catch (JsonProcessingException e) {
            throw new BizException("점검표 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    /** 개발자: 박승우 | 일자: 2026-08-06 | 코멘트: 삭제 확인창 전 차단 여부만 검사하며, 결재 문서는 업무 문구로 막고, 통과 시 반환값은 없다. */
    public void validateDelete(String screenCode, List<HygieneDeleteItem> keys) {
        assertDeletable(templateOf(screenCode), keys);
    }

    /** 개발자: 박승우 | 일자: 2026-08-06 | 코멘트: 삭제 직전에 다시 차단을 확인하고 SP로 문서·하위를 삭제하며, 성공 시 요청 건수를 반환한다. */
    @Transactional
    public int delete(String screenCode, List<HygieneDeleteItem> keys) {
        String tmplCd = templateOf(screenCode);
        assertDeletable(tmplCd, keys);
        for (HygieneDeleteItem key : keys) mapper.delete(LoginUserContext.coCd(), tmplCd, key.getDocIdx(), LoginUserContext.userId());
        return keys.size();
    }

    /** 삭제 키 정규화·결재 차단 Double Check. */
    private void assertDeletable(String tmplCd, List<HygieneDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 문서를 선택하세요.");
        List<Long> docIdxs = new ArrayList<>();
        for (HygieneDeleteItem key : keys) {
            Long docIdx = DeleteValidation.requirePositive(key.getDocIdx(), "삭제할 문서번호가 올바르지 않습니다.");
            key.setDocIdx(docIdx);
            docIdxs.add(docIdx);
        }
        DeleteValidation.throwIfBlocked(mapper.selectDeleteBlocker(LoginUserContext.coCd(), tmplCd, docIdxs), "문서");
    }

    private static String templateOf(String screenCode) {
        String tmplCd = SCREEN_TMPL.get(screenCode);
        if (tmplCd == null) {
            throw new BizException("지원하지 않는 위생 점검표입니다.");
        }
        return tmplCd;
    }

    private static String nvl(String value) {
        return value == null ? "" : value.trim();
    }
}
