/**
 * BizOpsService — 시설·재고·공정 DB형 양식 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 각 URL의 고정 양식 코드를 SP에 전달해 6개 양식의 목록·상세·저장·삭제를 처리한다
 *   2) 저장과 삭제는 Spring 트랜잭션에서 실행하며 저장프로시저 안에는 자율 COMMIT이 없다
 *   3) 삭제는 validate-delete와 delete에서 같은 assertDeletable을 다시 호출한다
 *
 * PIPELINE[HB90] 시설·재고·공정 Service
 * PIPELINE[HB50, HB88, HB89, HB91] 연관 모듈
 */
package com.haccp.docs.prp;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.flow.ca.DocCorrectiveSupport;
import com.haccp.docs.prp.dto.BizOpsDeleteItem;
import com.haccp.docs.prp.dto.BizOpsSaveRequest;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class BizOpsService {
    private final BizOpsMapper mapper;
    private final ObjectMapper objectMapper;
    private final DocCorrectiveSupport correctiveSupport;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 목록을 양식·기간·문서번호·작성자로 조회한다
     *   2) 공백 조건은 SP에서 전체로 본다
     *   3) 실패는 업무 예외로 반환한다
     */
    public List<Map<String, Object>> list(String tmplCd, String fromDt, String toDt, String docNo, String writer) {
        return mapper.selectList(LoginUserContext.coCd(), tmplCd, nvl(fromDt), nvl(toDt), nvl(docNo), nvl(writer));
    }

    /** 기존 상세 또는 신규 기본 행을 JSON 객체로 반환한다. */
    public Map<String, Object> detail(String tmplCd, Long docIdx) {
        try {
            Map<String, Object> out = objectMapper.readValue(
                    mapper.selectDetail(LoginUserContext.coCd(), tmplCd, docIdx),
                    new TypeReference<>() { }
            );
            if (docIdx != null && docIdx > 0) {
                out.put("corrective", correctiveSupport.load(LoginUserContext.coCd(), docIdx));
            } else {
                out.put("corrective", null);
            }
            return out;
        } catch (JsonProcessingException e) {
            throw new BizException("양식 상세 자료를 읽지 못했습니다.");
        }
    }

    /** 양식 전체를 저장하고 문서 idx를 반환한다. */
    @Transactional
    public Long save(String tmplCd, BizOpsSaveRequest req) {
        try {
            String payloadJson = objectMapper.writeValueAsString(req.getPayload());
            Long docIdx = mapper.save(
                    LoginUserContext.coCd(), tmplCd, req.getDocIdx(),
                    payloadJson, LoginUserContext.userId()
            );
            if (docIdx == null || docIdx <= 0) {
                throw new BizException("저장에 실패했습니다.");
            }
            Object baseDt = req.getPayload() == null ? null : req.getPayload().get("baseDt");
            boolean hasNg = payloadJson.contains("\"judgeCd\":\"X\"")
                    || payloadJson.contains("\"judgeCd\":\"F\"")
                    || payloadJson.contains("\"resultCd\":\"NG\"");
            correctiveSupport.saveAutoIfNg(
                    LoginUserContext.coCd(),
                    docIdx,
                    tmplCd,
                    baseDt == null ? "" : String.valueOf(baseDt).trim(),
                    req.getCorrective(),
                    hasNg,
                    LoginUserContext.userId()
            );
            return docIdx;
        } catch (JsonProcessingException e) {
            throw new BizException("저장 자료 형식이 올바르지 않습니다.");
        }
    }

    /** 삭제 전 잠금·존재 여부를 검증한다. */
    public void validateDelete(String tmplCd, List<BizOpsDeleteItem> keys) {
        assertDeletable(tmplCd, LoginUserContext.coCd(), keys);
    }

    /** 양식 문서를 삭제한다. 삭제 직전에도 잠금 상태를 다시 검사한다. */
    @Transactional
    public void delete(String tmplCd, List<BizOpsDeleteItem> keys) {
        String coCd = LoginUserContext.coCd();
        assertDeletable(tmplCd, coCd, keys);
        for (BizOpsDeleteItem key : keys) {
            mapper.delete(coCd, tmplCd, key.getDocIdx(), LoginUserContext.userId());
        }
    }

    /** 삭제 키와 결재 잠금을 공통 검증한다. */
    private void assertDeletable(String tmplCd, String coCd, List<BizOpsDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 문서를 선택하세요.");
        List<Long> docIdxs = new ArrayList<>();
        for (BizOpsDeleteItem key : keys) {
            key.setDocIdx(DeleteValidation.requirePositive(key.getDocIdx(), "삭제할 문서번호가 올바르지 않습니다."));
            docIdxs.add(key.getDocIdx());
        }
        DeleteValidation.throwIfBlocked(mapper.selectDeleteBlocker(coCd, tmplCd, docIdxs), "문서");
    }

    /** null 값을 SP의 공백 필터로 정규화한다. */
    private static String nvl(String value) {
        return value == null ? "" : value.trim();
    }
}
