/**
 * EquipmentHistService — 설비 이력 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 설비별 이력 목록·저장·삭제 트랜잭션을 담당한다
 *   2) coCd·userId는 LoginUserContext에서만 얻어 요청 본문 테넌트 값을 무시한다
 *   3) 삭제는 validate-delete와 delete에서 같은 키 검사를 두 번 수행한다
 *
 * PIPELINE[HB95] 설비이력 Service
 * PIPELINE[HB94, HB96, HB97, HB51] 연관 모듈
 */
package com.haccp.bas;

// 역할 — Jackson JSON 역직렬화 타입
import com.fasterxml.jackson.core.type.TypeReference;
// 역할 — Jackson JSON 직렬화·역직렬화
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — 설비 이력 삭제 키
import com.haccp.bas.dto.EquipmentHistDeleteItem;
// 역할 — 설비 이력 저장 행
import com.haccp.bas.dto.EquipmentHistSaveItem;
// 역할 — 로그인 테넌트·사용자 조회
import com.haccp.common.context.LoginUserContext;
// 역할 — 업무 예외
import com.haccp.common.exception.BizException;
// 역할 — 배열 삭제 검증 공통
import com.haccp.common.validation.DeleteValidation;
// 역할 — 목록·맵 타입
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
// 역할 — 생성자 DI
import lombok.RequiredArgsConstructor;
// 역할 — Spring 서비스·트랜잭션
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class EquipmentHistService {

    private final EquipmentHistMapper mapper;
    private final ObjectMapper objectMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 선택한 설비의 이력 목록을 조회한다
     *   2) 설비이력 M-D 화면 하단 그리드 초기·재조회에서 호출한다
     *   3) 성공 시 camelCase 속성의 행 목록
     */
    public List<Map<String, Object>> list(
            // 상위 설비 대리키 — 필수
            Long equipIdx
    ) {
        Long idx = DeleteValidation.requirePositive(equipIdx, "설비를 선택하세요.");
        List<Map<String, Object>> rows = new ArrayList<>();
        for (String json : mapper.selectList(LoginUserContext.coCd(), idx)) {
            rows.add(readJsonRow(json));
        }
        return rows;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 이력 행 배열을 하나의 트랜잭션에서 SP로 저장한다
     *   2) 신규는 idx 없이, 수정은 같은 설비의 idx를 포함해 호출한다
     *   3) 성공 시 void, SP 업무 오류 또는 JSON 변환 실패 시 롤백
     */
    @Transactional
    public void save(
            // 화면이 전송한 저장 행 배열
            List<EquipmentHistSaveItem> rows
    ) {
        DeleteValidation.requireItems(rows, "저장할 이력이 없습니다.");
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        for (EquipmentHistSaveItem row : rows) {
            if (row == null) {
                throw new BizException("저장할 이력 행이 올바르지 않습니다.");
            }
            if (row.getEquipIdx() == null || row.getEquipIdx() <= 0) {
                throw new BizException("설비를 선택하세요.");
            }
            if (row.getHistDt() == null || row.getHistDt().isBlank()) {
                throw new BizException("이력일은 필수입니다.");
            }
            mapper.save(coCd, writeJsonRow(row), userId);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 실제 삭제 없이 삭제 키만 정규화·검증한다
     *   2) FE가 확인창을 띄우기 전에 호출한다
     *   3) 키 오류 시 BizException, 통과 시 void
     */
    public void validateDelete(
            // 삭제 키 객체 배열
            List<EquipmentHistDeleteItem> keys
    ) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 키 검사를 다시 통과한 이력을 SP 루프로 삭제한다
     *   2) validate-delete 이후 데이터가 바뀐 경우도 Double Check로 차단한다
     *   3) 성공 시 void — CALL 영향행수는 API에 노출하지 않는다
     */
    @Transactional
    public void delete(
            // 삭제 키 객체 배열
            List<EquipmentHistDeleteItem> keys
    ) {
        assertDeletable(keys);
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        for (EquipmentHistDeleteItem key : keys) {
            mapper.delete(coCd, key.getIdx(), userId);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 키 배열을 양수 idx로 정규화한다
     *   2) validate-delete·delete 양쪽에서 호출해 OPS_DELETE Double Check를 보장한다
     *   3) null·빈 배열·비정상 키가 있으면 BizException
     */
    private void assertDeletable(
            // 삭제 키 객체 배열
            List<EquipmentHistDeleteItem> keys
    ) {
        DeleteValidation.requireItems(keys, "삭제할 이력을 선택하세요.");
        for (EquipmentHistDeleteItem key : keys) {
            if (key == null) {
                throw new BizException("삭제할 이력 키가 올바르지 않습니다.");
            }
            Long idx = DeleteValidation.requirePositive(key.getIdx(), "삭제할 이력 키가 올바르지 않습니다.");
            key.setIdx(idx);
        }
    }

    /** SP JSON 행을 API Map으로 변환한다. SP가 camelCase를 주면 그대로 유지한다. */
    private Map<String, Object> readJsonRow(String json) {
        try {
            return objectMapper.readValue(json, new TypeReference<LinkedHashMap<String, Object>>() {});
        } catch (Exception e) {
            throw new BizException("설비 이력 조회 결과를 변환하지 못했습니다.");
        }
    }

    /** 저장 행을 SP용 camelCase JSON으로 직렬화한다. */
    private String writeJsonRow(EquipmentHistSaveItem row) {
        try {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("idx", row.getIdx());
            payload.put("equipIdx", row.getEquipIdx());
            payload.put("histDt", normalizeYmd(row.getHistDt()));
            payload.put("faultRmk", blankToNull(row.getFaultRmk()));
            payload.put("actionRmk", blankToNull(row.getActionRmk()));
            payload.put("docIdx", row.getDocIdx());
            payload.put("remark", blankToNull(row.getRemark()));
            return objectMapper.writeValueAsString(payload);
        } catch (Exception e) {
            throw new BizException("설비 이력 저장 형식을 변환하지 못했습니다.");
        }
    }

    /** YYYY-MM-DD → YYYYMMDD. 이미 8자리면 그대로 둔다. */
    private static String normalizeYmd(String value) {
        if (value == null) {
            return "";
        }
        return value.trim().replace("-", "");
    }

    private static String blankToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }
}
