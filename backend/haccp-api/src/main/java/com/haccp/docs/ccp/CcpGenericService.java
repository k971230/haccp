/**
 * CcpGenericService — 가열·세척 등 공통 CCP 모니터링 업무 서비스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 스마트 기준일지 매핑으로 공통 CCP 후보를 제공하고 동적 행·셀을 JSON으로 저장한다
 *   2) 상세 재조회·OPS_DELETE Double Check를 포함해 목록 선택 후 편집이 가능하도록 한다
 *   3) 회사·사용자 식별자는 JWT 컨텍스트에서만 읽고 요청 본문의 테넌트 값은 사용하지 않는다
 *
 * PIPELINE[HB97] 공통 CCP Service
 * PIPELINE[HB95, HB94, HF94] 연관 모듈
 */
package com.haccp.docs.ccp;

// 역할 — JSON 직렬화·역직렬화
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — 공통 CCP 요청 DTO
import com.haccp.docs.ccp.dto.GenericMonitorDeleteItem;
import com.haccp.docs.ccp.dto.GenericMonitorSaveRequest;
// 역할 — JWT 컨텍스트·업무 예외·삭제 검증
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.flow.ca.DocCorrectiveSupport;
// 역할 — 컬렉션
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
// 역할 — Spring 서비스·트랜잭션
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CcpGenericService {
    private final CcpGenericMapper mapper;
    private final ObjectMapper objectMapper;
    private final DocCorrectiveSupport correctiveSupport;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 회사 사용양식·대표 매핑 기준 공통 CCP 템플릿을 조회한다
     *   2) 가열·멸균·여과 leaf 마운트 시 호출한다
     *   3) MyBatis map 키를 camelCase로 바꿔 FE DTO와 맞춘다
     */
    public List<Map<String, Object>> templates() {
        // coCd: JWT LoginUser 회사코드 — 회사양식 use_yn 범위
        List<Map<String, Object>> rows = mapper.selectTemplates(LoginUserContext.coCd());
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            // snake_case → camelCase (tmplCd·limitItemKind 등)
            out.add(camelMap(row));
        }
        return out;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서 idx로 헤더·측정행·셀을 한 번에 조회한다
     *   2) 목록 선택 시 호출한다
     *   3) 없거나 타 테넌트면 업무 오류를 반환한다
     */
    public Map<String, Object> detail(
            // 조회 문서 idx
            Long docIdx
    ) {
        Long required = DeleteValidation.requirePositive(docIdx, "문서번호가 올바르지 않습니다.");
        Map<String, Object> row = mapper.selectDetail(LoginUserContext.coCd(), required);
        if (row == null || row.isEmpty()) {
            throw new BizException("문서를 찾을 수 없습니다.");
        }
        Map<String, Object> out = camelMap(row);
        Object rowsJson = row.get("rowsJson");
        if (rowsJson == null) {
            rowsJson = row.get("rows_json");
        }
        out.put("rows", parseRows(rowsJson));
        out.remove("rowsJson");
        out.remove("rows_json");
        return out;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 공통 CCP 문서·헤더·행·측정 셀을 단일 저장 FUNCTION으로 전달한다
     *   2) 행이 비었을 때(= 기록할 점검행 없음) 저장하지 않고 업무 오류를 반환한다
     *   3) 저장 성공 시 문서 idx를 반환해 화면이 후속 결재·첨부 흐름에 사용할 수 있게 한다
     */
    @Transactional
    public Long save(GenericMonitorSaveRequest req) {
        if (req == null || req.getRows() == null || req.getRows().isEmpty()) {
            throw new BizException("점검 행이 없습니다.");
        }
        if (text(req.getBaseDt()).isBlank() || text(req.getTmplCd()).isBlank()) {
            throw new BizException("작성일과 양식을 입력하세요.");
        }
        String rowsPayload = rowsJson(req.getRows());
        Long docIdx = mapper.save(
                LoginUserContext.coCd(), req.getDocIdx(), text(req.getBaseDt()), text(req.getTmplCd()),
                text(req.getCcpCd()), text(req.getDiaryNo()), text(req.getLimitItemKind()),
                text(req.getMngUserId()), text(req.getMngNm()), rowsPayload, LoginUserContext.userId()
        );
        if (docIdx == null || docIdx <= 0) throw new BizException("공통 CCP 일지 저장에 실패했습니다.");
        boolean hasNg = rowsPayload.contains("\"judgeCd\":\"F\"") || rowsPayload.contains("\"judgeCd\":\"X\"");
        correctiveSupport.saveAutoIfNg(
                LoginUserContext.coCd(),
                docIdx,
                text(req.getTmplCd()),
                text(req.getBaseDt()),
                null,
                hasNg,
                LoginUserContext.userId()
        );
        return docIdx;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) FE confirm 전에 호출한다
     *   3) 결재 진행·완료면 BizException
     */
    public void validateDelete(List<GenericMonitorDeleteItem> keys) {
        assertDeletable(LoginUserContext.coCd(), keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 임시·반려 공통 CCP 문서를 삭제한다
     *   2) validateDelete와 같은 Double Check 뒤 SP를 루프 호출한다
     *   3) 성공 시 void
     */
    @Transactional
    public void delete(List<GenericMonitorDeleteItem> keys) {
        String coCd = LoginUserContext.coCd();
        assertDeletable(coCd, keys);
        for (GenericMonitorDeleteItem key : keys) {
            mapper.deleteMonitor(coCd, key.getDocIdx(), LoginUserContext.userId());
        }
    }

    /** 삭제 키 정규화·차단 검사 */
    private void assertDeletable(String coCd, List<GenericMonitorDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 문서를 선택하세요.");
        List<Long> docIdxs = new ArrayList<>();
        for (GenericMonitorDeleteItem key : keys) {
            Long docIdx = DeleteValidation.requirePositive(key.getDocIdx(), "삭제할 문서번호가 올바르지 않습니다.");
            key.setDocIdx(docIdx);
            docIdxs.add(docIdx);
        }
        DeleteValidation.throwIfBlocked(mapper.selectDeleteBlocker(coCd, docIdxs), "문서");
    }

    /** DTO의 null 값을 고정 키 JSON으로 보정해 PostgreSQL jsonb 저장 계약을 유지한다. */
    private String rowsJson(List<GenericMonitorSaveRequest.GenericMonitorRow> rows) {
        List<Map<String, Object>> payload = new ArrayList<>();
        for (GenericMonitorSaveRequest.GenericMonitorRow row : rows) {
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("rowSeq", row.getRowSeq());
            out.put("checkTime", text(row.getCheckTime()));
            out.put("equipNm", text(row.getEquipNm()));
            out.put("productNm", text(row.getProductNm()));
            out.put("judgeCd", text(row.getJudgeCd()));
            out.put("judgeModYn", text(row.getJudgeModYn()).isBlank() ? "N" : text(row.getJudgeModYn()));
            out.put("checkerId", text(row.getCheckerId()));
            out.put("checkerNm", text(row.getCheckerNm()));
            // 서명은 보유여부만 넘긴다 — 실물은 SP가 tbl_user.sign_img에서 복사한다
            out.put("signYn", text(row.getSignYn()));
            List<Map<String, Object>> cells = new ArrayList<>();
            if (row.getCells() != null) {
                for (GenericMonitorSaveRequest.GenericMonitorCell cell : row.getCells()) {
                    Map<String, Object> value = new LinkedHashMap<>();
                    value.put("itemCd", text(cell.getItemCd()));
                    value.put("numVal", cell.getNumVal());
                    value.put("txtVal", text(cell.getTxtVal()));
                    value.put("judgeCd", text(cell.getJudgeCd()));
                    cells.add(value);
                }
            }
            out.put("cells", cells);
            payload.add(out);
        }
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (Exception e) {
            throw new BizException("공통 CCP 점검행을 저장 형식으로 변환하지 못했습니다.");
        }
    }

    /** SP jsonb/문자열 → 행 목록 */
    private List<Map<String, Object>> parseRows(Object rowsJson) {
        if (rowsJson == null) return List.of();
        try {
            if (rowsJson instanceof String s) {
                return objectMapper.readValue(s, new TypeReference<>() {});
            }
            return objectMapper.convertValue(rowsJson, new TypeReference<>() {});
        } catch (Exception e) {
            throw new BizException("공통 CCP 점검행을 읽지 못했습니다.");
        }
    }

    /** snake_case 키를 camelCase로 바꾼다 */
    private Map<String, Object> camelMap(Map<String, Object> src) {
        Map<String, Object> out = new LinkedHashMap<>();
        for (Map.Entry<String, Object> e : src.entrySet()) {
            out.put(toCamel(e.getKey()), e.getValue());
        }
        return out;
    }

    private String toCamel(String key) {
        if (key == null || !key.contains("_")) return key;
        StringBuilder sb = new StringBuilder();
        boolean up = false;
        for (char c : key.toCharArray()) {
            if (c == '_') {
                up = true;
            } else if (up) {
                sb.append(Character.toUpperCase(c));
                up = false;
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    private String text(String value) {
        return value == null ? "" : value.trim();
    }
}
