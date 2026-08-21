/**
 * CcpFormsService — CCP 금속검출·검증점검표·연간 검증계획서 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 화면 경로를 템플릿 코드로 고정해 임의 양식 접근을 막는다
 *   2) 저장 행은 JSON으로 직렬화해 각 양식 SP가 원자적으로 전개한다
 *   3) 삭제 검증과 삭제 실행 모두 동일 차단 쿼리를 호출한다
 *
 * PIPELINE[HB89] CCP 추가 양식 Service
 * PIPELINE[HB88, HB90] 연관 모듈
 */
package com.haccp.docs.ccp;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.haccp.docs.ccp.dto.DocCorrectiveDto;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.flow.ca.DocCorrectiveSupport;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CcpFormsService {
    private final CcpFormsMapper mapper;
    private final CcpColdMapper coldMapper;
    private final ObjectMapper objectMapper;
    private final DocCorrectiveSupport correctiveSupport;

    public List<Map<String, Object>> list(String form, String fromDt, String toDt, String docNo, String writer) {
        return mapper.selectList(
                LoginUserContext.coCd(),
                template(form),
                text(fromDt),
                text(toDt),
                text(docNo),
                text(writer)
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서 상세를 조회한다. docIdx가 없거나 0일 때(= 신규) header=null과 빈 행을 돌려 화면이 기본 표를 그린다
     *   2) Map.of는 null 값을 허용하지 않아 신규 조회에서 NPE가 나므로 LinkedHashMap으로 조립한다
     *   3) 금속검출은 감도·통과량 표를 분리하고 검증·연간계획은 rowsJson을 펼친다
     */
    public Map<String, Object> detail(String form, Long docIdx) {
        String coCd = LoginUserContext.coCd();
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("limits", coldMapper.selectLimits(coCd, ""));
        // 신규일 때(= docIdx 없음) null header를 허용해 화면이 기본 행을 채운다
        if (docIdx == null || docIdx <= 0) {
            out.put("header", null);
            out.put("rows", List.of());
            out.put("sensRows", List.of());
            out.put("passRows", List.of());
            out.put("corrective", null);
            return out;
        }
        Map<String, Object> header = mapper.selectDetail(coCd, template(form), docIdx);
        if (header == null) throw new BizException("문서를 찾을 수 없습니다.");
        // 검증점검표일 때(= html_sys_006) 모니터링 일지 확인 SPAN을 헤더에 붙인다
        if ("verification-check".equals(form)) {
            String monitorRmk = mapper.selectVerifyMonitorRmk(coCd, docIdx);
            if (monitorRmk != null) {
                header.put("monitorChkRmk", monitorRmk);
            }
        }
        out.put("header", header);
        out.put("corrective", correctiveSupport.load(coCd, docIdx));
        if ("metal-monitor".equals(form)) {
            Long hdrIdx = ((Number) header.get("hdrIdx")).longValue();
            out.put("rows", List.of());
            out.put("sensRows", mapper.selectMetalSensRows(coCd, hdrIdx));
            out.put("passRows", mapper.selectMetalPassRows(coCd, hdrIdx));
            return out;
        }
        out.put("rows", readRows(header.get("rowsJson")));
        out.put("sensRows", List.of());
        out.put("passRows", List.of());
        return out;
    }

    @Transactional
    public Long save(String form, Map<String, Object> request) {
        String baseDt = text(request.get("baseDt"));
        List<?> rows = listValue(request.get("rows"));
        try {
            Long result;
            if ("metal-monitor".equals(form)) {
                result = mapper.saveMetal(LoginUserContext.coCd(), number(request.get("docIdx")), baseDt, text(request.get("ccpCd")),
                        decimal(request.get("feSize")), decimal(request.get("stsSize")), text(request.get("mngUserId")), text(request.get("mngNm")),
                        objectMapper.writeValueAsString(listValue(request.get("sensRows"))), objectMapper.writeValueAsString(listValue(request.get("passRows"))), LoginUserContext.userId());
            } else {
                result = mapper.saveForm(LoginUserContext.coCd(), template(form), number(request.get("docIdx")), baseDt,
                        text(request.get("checkerId")), text(request.get("checkerNm")), text(request.get("deptCd")), text(request.get("confirmId")),
                        objectMapper.writeValueAsString(rows), LoginUserContext.userId());
            }
            Long docIdx = requiredResult(result);
            // 검증점검표일 때(= html_sys_006) 모니터링 일지 확인 SPAN을 헤더에 저장
            if ("verification-check".equals(form)) {
                mapper.updateVerifyMonitorRmk(
                        LoginUserContext.coCd(),
                        docIdx,
                        text(request.get("monitorChkRmk")),
                        LoginUserContext.userId()
                );
            }
            // metal은 sens/pass 행, 그 외는 rows — 부적합 판정 문자열 탐지
            String probeJson = "metal-monitor".equals(form)
                    ? objectMapper.writeValueAsString(listValue(request.get("sensRows")))
                            + objectMapper.writeValueAsString(listValue(request.get("passRows")))
                    : objectMapper.writeValueAsString(rows);
            boolean hasNg = probeJson.contains("\"judgeCd\":\"F\"") || probeJson.contains("\"judgeCd\":\"X\"")
                    || probeJson.contains("\"answerCd\":\"N\"");
            correctiveSupport.saveAutoIfNg(
                    LoginUserContext.coCd(),
                    docIdx,
                    template(form),
                    baseDt,
                    toCorrective(request.get("corrective")),
                    hasNg,
                    LoginUserContext.userId()
            );
            return docIdx;
        } catch (JsonProcessingException exception) {
            throw new BizException("점검 행 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    @SuppressWarnings("unchecked")
    private DocCorrectiveDto toCorrective(Object raw) {
        if (!(raw instanceof Map<?, ?> map)) return null;
        DocCorrectiveDto dto = new DocCorrectiveDto();
        dto.setDeviationDesc(text(map.get("deviationDesc")));
        dto.setActionDesc(text(map.get("actionDesc")));
        dto.setActionUserNm(text(map.get("actionUserNm")));
        dto.setConfirmUserNm(text(map.get("confirmUserNm")));
        return dto;
    }

    public void validateDelete(String form, List<Map<String, Long>> keys) {
        assertDeletable(form, keys);
    }

    @Transactional
    public void delete(String form, List<Map<String, Long>> keys) {
        assertDeletable(form, keys);
        String coCd = LoginUserContext.coCd();
        for (Map<String, Long> key : keys) {
            Long docIdx = key.get("docIdx");
            if ("metal-monitor".equals(form)) mapper.deleteMetal(coCd, docIdx, LoginUserContext.userId());
            else mapper.deleteForm(coCd, template(form), docIdx, LoginUserContext.userId());
        }
    }

    private void assertDeletable(String form, List<Map<String, Long>> keys) {
        DeleteValidation.requireItems(keys, "삭제할 문서를 선택하세요.");
        List<Long> ids = new ArrayList<>();
        for (Map<String, Long> key : keys) ids.add(DeleteValidation.requirePositive(key.get("docIdx"), "삭제할 문서번호가 올바르지 않습니다."));
        DeleteValidation.throwIfBlocked(mapper.selectDeleteBlocker(LoginUserContext.coCd(), template(form), ids), "문서");
    }

    private String template(String form) {
        return switch (form) {
            case "metal-monitor" -> "html_sys_002";
            case "verification-check" -> "html_sys_006";
            default -> throw new BizException("지원하지 않는 CCP 양식입니다.");
        };
    }
    private List<?> readRows(Object json) {
        try { return json == null ? List.of() : objectMapper.readValue(String.valueOf(json), List.class); }
        catch (JsonProcessingException exception) { throw new BizException("저장된 점검 행을 읽지 못했습니다."); }
    }
    private static List<?> listValue(Object value) { return value instanceof List<?> items ? items : List.of(); }
    private static String text(Object value) { return value == null ? "" : String.valueOf(value).trim(); }
    private static Long number(Object value) { return value instanceof Number n ? n.longValue() : null; }
    private static BigDecimal decimal(Object value) { return value instanceof Number n ? BigDecimal.valueOf(n.doubleValue()) : null; }
    private static Long requiredResult(Long value) { if (value == null || value <= 0) throw new BizException("저장에 실패했습니다."); return value; }
}
