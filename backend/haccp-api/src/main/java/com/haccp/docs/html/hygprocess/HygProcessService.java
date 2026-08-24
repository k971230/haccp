/**
 * HygProcessService — 일반위생관리 및 공정점검표 작성.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 신규 상세는 apply_yn=Y 버전(없으면 표준) 항목을 빈칸으로 돌려준다
 *   2) 저장은 문서 허브와 tbl_hyg_process를 한 트랜잭션에서 맞춘다
 *   3) validate-delete와 delete 모두 assertDeletable Double Check
 *
 * PIPELINE[HB131] 공정점검 Service
 */
package com.haccp.docs.html.hygprocess;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.flow.ca.DocCorrectiveSupport;
import com.haccp.docs.html.hygprocess.dto.HygProcessDeleteItem;
import com.haccp.docs.html.hygprocess.dto.HygProcessListRow;
import com.haccp.docs.html.hygprocess.dto.HygProcessSaveRequest;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class HygProcessService {
    private static final String TMPL_CD = "html_sys_001";

    private final HygProcessMapper mapper;
    private final ObjectMapper objectMapper;
    private final DocCorrectiveSupport correctiveSupport;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 좌측 문서 목록을 조회한다
     *   2) 조회 버튼·초기 로드에서 호출한다
     *   3) 공백 조건은 SP에서 전체
     */
    public List<HygProcessListRow> list(String fromDt, String toDt, String docNo, String writer) {
        return mapper.selectList(LoginUserContext.coCd(), TMPL_CD, nvl(fromDt), nvl(toDt), nvl(docNo), nvl(writer));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 기존 상세 또는 적용 버전 신규 JSON
     *   2) 신규는 docIdx 생략
     *   3) 저장 문서면 이탈 푸터를 붙인다
     */
    public JsonNode detail(Long docIdx) {
        try {
            ObjectNode root = (ObjectNode) objectMapper.readTree(
                    mapper.selectDetail(LoginUserContext.coCd(), TMPL_CD, docIdx));
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

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 헤더·항목·하단 4칸을 저장한다. 승인자명도 서명 SP에 넘긴다
     *   2) 저장 버튼이 호출한다
     *   3) 아니오가 있으면 이탈을 자동 생성한다. 이름이 사용자와 같고 서명이 있으면 이미지를 복사한다
     */
    @Transactional(timeout = 60)
    public Long save(HygProcessSaveRequest req) {
        if (req == null || nvl(req.getBaseDt()).length() != 8) {
            throw new BizException("점검일자를 입력하세요.");
        }
        try {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("verNo", req.getVerNo() == null ? 0 : req.getVerNo());
            payload.put("items", req.getItems() == null ? List.of() : req.getItems());
            payload.put("specialNote", note(req.getSpecialNote()));
            payload.put("improveNote", note(req.getImproveNote()));
            payload.put("actionNm", note(req.getActionNm()));
            payload.put("confirmNm", note(req.getConfirmNm()));
            Long docIdx = mapper.save(
                    LoginUserContext.coCd(),
                    TMPL_CD,
                    req.getDocIdx(),
                    req.getBaseDt().trim(),
                    nvl(req.getCheckerNm()),
                    objectMapper.writeValueAsString(payload),
                    LoginUserContext.userId()
            );
            if (docIdx == null || docIdx <= 0) {
                throw new BizException("저장에 실패했습니다.");
            }
            // 서명 스냅샷 — 이름=사용자면 blob 복사, 없으면 이름만
            mapper.snapshotSigns(
                    LoginUserContext.coCd(),
                    docIdx,
                    nvl(req.getCheckerNm()),
                    nvl(req.getApproverNm()),
                    nvl(req.getConfirmNm())
            );
            boolean hasNg = req.getItems() != null && req.getItems().stream().anyMatch(row -> {
                Object yn = row.get("yn");
                return yn != null && "N".equalsIgnoreCase(String.valueOf(yn).trim());
            });
            correctiveSupport.saveAutoIfNg(
                    LoginUserContext.coCd(),
                    docIdx,
                    TMPL_CD,
                    req.getBaseDt().trim(),
                    req.getCorrective(),
                    hasNg,
                    LoginUserContext.userId()
            );
            return docIdx;
        } catch (JsonProcessingException e) {
            throw new BizException("점검표 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) 확인창 전에 호출한다
     *   3) 결재 문서는 차단
     */
    public void validateDelete(List<HygProcessDeleteItem> keys) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 재검증 후 문서·하위를 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) 성공 시 건수
     */
    @Transactional(timeout = 60)
    public int delete(List<HygProcessDeleteItem> keys) {
        assertDeletable(keys);
        for (HygProcessDeleteItem key : keys) {
            mapper.delete(LoginUserContext.coCd(), key.getDocIdx(), LoginUserContext.userId());
        }
        return keys.size();
    }

    /** 삭제 키 정규화·결재 차단 Double Check. */
    private void assertDeletable(List<HygProcessDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 문서를 선택하세요.");
        List<Long> docIdxs = new ArrayList<>();
        for (HygProcessDeleteItem key : keys) {
            Long docIdx = DeleteValidation.requirePositive(key.getDocIdx(), "삭제할 문서번호가 올바르지 않습니다.");
            key.setDocIdx(docIdx);
            docIdxs.add(docIdx);
        }
        DeleteValidation.throwIfBlocked(
                mapper.selectDeleteBlocker(LoginUserContext.coCd(), TMPL_CD, docIdxs),
                "문서"
        );
    }

    private static String nvl(String value) {
        return value == null ? "" : value.trim();
    }

    /** 개행 보존 — 끝 공백 trim 금지 */
    private static String note(String value) {
        return value == null ? "" : value;
    }
}
