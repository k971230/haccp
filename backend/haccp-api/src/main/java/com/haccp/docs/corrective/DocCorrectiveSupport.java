/**
 * DocCorrectiveSupport — 이탈 푸터 JSON 직렬화·저장 헬퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 각 양식 Service가 저장 직후 동일 계약으로 CA를 갱신하게 한다
 *   2) null corrective도 빈 payload로 넘겨 SP가 삭제하게 한다
 *   3) Jackson 직렬화 실패는 BizException으로 올린다
 *
 * PIPELINE[HB64] 문서 푸터 지원
 */
package com.haccp.docs.corrective;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.haccp.ccp.dto.DocCorrectiveDto;
import com.haccp.common.exception.BizException;
import java.util.LinkedHashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class DocCorrectiveSupport {

    private final DocCorrectiveMapper mapper;
    private final ObjectMapper objectMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서 푸터를 조회한다
     *   2) 상세 API에서 호출한다
     *   3) 없으면 null
     */
    public DocCorrectiveDto load(String coCd, Long docIdx) {
        if (docIdx == null || docIdx <= 0) return null;
        return mapper.selectByDoc(coCd, docIdx);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서 푸터를 저장한다
     *   2) 양식 저장 직후 호출한다
     *   3) 빈 값이면 SP가 CA를 삭제한다
     */
    public void save(
            String coCd,
            Long docIdx,
            String tmplCd,
            String baseDt,
            DocCorrectiveDto corrective,
            String userId
    ) {
        if (docIdx == null || docIdx <= 0) return;
        mapper.upsertByDoc(coCd, docIdx, nvl(tmplCd), nvl(baseDt), toJson(corrective), userId);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) DB형 저장 시 부적합(hasNg)이 있으면 CA를 자동 upsert한다
     *   2) 사용자가 이미 이탈내용을 적었으면 그대로 저장한다
     *   3) 부적합이 없고 푸터도 비면 기존 save와 동일하게 비워 SP가 삭제한다
     */
    public void saveAutoIfNg(
            String coCd,
            Long docIdx,
            String tmplCd,
            String baseDt,
            DocCorrectiveDto corrective,
            boolean hasNg,
            String userId
    ) {
        if (docIdx == null || docIdx <= 0) return;
        DocCorrectiveDto toSave = corrective;
        if (hasNg) {
            boolean userEmpty = toSave == null || nvl(toSave.getDeviationDesc()).isEmpty();
            if (userEmpty) {
                DocCorrectiveDto existing = load(coCd, docIdx);
                if (existing != null && !nvl(existing.getDeviationDesc()).isEmpty()) {
                    toSave = existing;
                } else {
                    toSave = new DocCorrectiveDto();
                    toSave.setDeviationDesc("자동생성: 부적합이 감지되었습니다. 조치 내용을 입력·보완하세요.");
                    toSave.setStatus("OPEN");
                }
            }
        }
        save(coCd, docIdx, tmplCd, baseDt, toSave, userId);
    }

    private String toJson(DocCorrectiveDto c) {
        Map<String, Object> m = new LinkedHashMap<>();
        if (c != null) {
            m.put("deviationDesc", nvl(c.getDeviationDesc()));
            m.put("actionDesc", nvl(c.getActionDesc()));
            m.put("actionUserNm", nvl(c.getActionUserNm()));
            m.put("confirmUserNm", nvl(c.getConfirmUserNm()));
        } else {
            m.put("deviationDesc", "");
            m.put("actionDesc", "");
            m.put("actionUserNm", "");
            m.put("confirmUserNm", "");
        }
        try {
            return objectMapper.writeValueAsString(m);
        } catch (JsonProcessingException e) {
            throw new BizException("이탈 조치 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    private static String nvl(String s) {
        return s == null ? "" : s.trim();
    }
}
