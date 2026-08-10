/**
 * MasterService — HACCP 기준정보 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 마스터 유형 허용 검증, JSON 행 변환, 저장·삭제 트랜잭션을 담당한다
 *   2) coCd·userId는 LoginUserContext에서만 얻어 요청 본문 테넌트 값을 무시한다
 *   3) 삭제는 validate-delete와 delete에서 같은 참조 검사를 두 번 수행한다
 *
 * PIPELINE[HB74] 기준정보 Service
 * PIPELINE[HB73, HB75, HB77, HB51] 연관 모듈
 */
package com.metis.haccp.bas;

// 역할 — Jackson JSON 역직렬화 타입
import com.fasterxml.jackson.core.type.TypeReference;
// 역할 — Jackson JSON 직렬화·역직렬화
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — 기준정보 삭제 키
import com.metis.haccp.bas.dto.MasterDeleteItem;
// 역할 — 기준정보 저장 행
import com.metis.haccp.bas.dto.MasterSaveItem;
// 역할 — 로그인 테넌트·사용자 조회
import com.metis.haccp.common.context.LoginUserContext;
// 역할 — 업무 예외
import com.metis.haccp.common.exception.BizException;
// 역할 — 배열 삭제 검증 공통
import com.metis.haccp.common.validation.DeleteValidation;
// 역할 — 문서·사진 파일 저장소
import com.metis.haccp.doc.DocumentFileStorage;
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
// 역할 — 업로드 파일
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class MasterService {

    private final MasterMapper mapper;
    private final ObjectMapper objectMapper;
    // 설비 사진 등 테넌트 볼륨 저장
    private final DocumentFileStorage fileStorage;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 요청 유형의 기준정보 전체 또는 사용여부 필터 목록을 조회한다
     *   2) 제품·보관고·CCP 한계기준 화면의 초기 로드에서 호출한다
     *   3) 성공 시 camelCase 속성의 행 목록
     */
    public List<Map<String, Object>> list(
            // URL에서 정규화된 허용 마스터 유형
            MasterType masterType,
            // 사용여부 필터 — null이면 전체
            String useYn
    ) {
        List<Map<String, Object>> rows = new ArrayList<>();
        for (String json : mapper.selectList(LoginUserContext.coCd(), masterType.pathValue(), nvl(useYn))) {
            rows.add(readJsonRow(json));
        }
        return rows;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 유형별 저장 행 배열을 하나의 트랜잭션에서 SP로 저장한다
     *   2) 신규는 idx 없이, 수정은 같은 테넌트의 idx를 포함해 호출한다
     *   3) 성공 시 void, SP 업무 오류 또는 JSON 변환 실패 시 롤백
     */
    @Transactional
    public void save(
            // URL에서 정규화된 허용 마스터 유형
            MasterType masterType,
            // 화면이 전송한 저장 행 배열
            List<MasterSaveItem> rows
    ) {
        DeleteValidation.requireItems(rows, "저장할 기준정보가 없습니다.");
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        for (MasterSaveItem row : rows) {
            if (row == null) {
                throw new BizException("저장할 기준정보 행이 올바르지 않습니다.");
            }
            mapper.save(coCd, masterType.pathValue(), writeJsonRow(row), userId);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 실제 삭제 없이 삭제 대상의 참조 여부만 검사한다
     *   2) FE가 확인창을 띄우기 전에 호출한다
     *   3) 차단 시 표준 참조 문구 BizException, 통과 시 void
     */
    public void validateDelete(
            // URL에서 정규화된 허용 마스터 유형
            MasterType masterType,
            // 삭제 키 객체 배열
            List<MasterDeleteItem> keys
    ) {
        assertDeletable(LoginUserContext.coCd(), masterType, keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 참조 검사를 다시 통과한 기준정보를 SP 루프로 삭제한다
     *   2) validate-delete 이후 데이터가 바뀐 경우도 Double Check로 차단한다
     *   3) 성공 시 void — CALL 영향행수는 API에 노출하지 않는다
     */
    @Transactional
    public void delete(
            // URL에서 정규화된 허용 마스터 유형
            MasterType masterType,
            // 삭제 키 객체 배열
            List<MasterDeleteItem> keys
    ) {
        String coCd = LoginUserContext.coCd();
        assertDeletable(coCd, masterType, keys);
        String userId = LoginUserContext.userId();
        for (MasterDeleteItem key : keys) {
            mapper.delete(coCd, masterType.pathValue(), key.getIdx(), userId);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 설비 마스터 1건에 사진을 올리고 photo_path를 갱신한다
     *   2) 시설·설비 관리 화면 「사진 업로드」가 호출한다
     *   3) 성공 시 photoPath Map — 신규 미저장 행이면 업무 오류
     */
    @Transactional
    public Map<String, Object> uploadEquipmentPhoto(
            // 설비 대리키 — 저장 완료된 행만
            Long idx,
            // 사진 파일
            MultipartFile file
    ) {
        if (idx == null || idx <= 0) {
            throw new BizException("설비를 먼저 저장한 뒤 사진을 등록하세요.");
        }
        if (file == null || file.isEmpty()) {
            throw new BizException("사진 파일을 선택하세요.");
        }
        String coCd = LoginUserContext.coCd();
        Map<String, Object> existing = null;
        for (Map<String, Object> row : list(MasterType.EQUIPMENT, null)) {
            Object rowIdx = row.get("idx");
            if (rowIdx != null && Long.parseLong(String.valueOf(rowIdx)) == idx.longValue()) {
                existing = row;
                break;
            }
        }
        if (existing == null) {
            throw new BizException("설비를 찾을 수 없습니다.");
        }
        String previous = existing.get("photoPath") == null ? "" : String.valueOf(existing.get("photoPath")).trim();
        String path = fileStorage.save(coCd, file);

        MasterSaveItem item = new MasterSaveItem();
        item.setIdx(idx);
        for (Map.Entry<String, Object> e : existing.entrySet()) {
            if ("idx".equals(e.getKey()) || "photoPath".equals(e.getKey())) {
                continue;
            }
            item.putValue(e.getKey(), e.getValue());
        }
        item.putValue("photoPath", path);
        mapper.save(coCd, MasterType.EQUIPMENT.pathValue(), writeJsonRow(item), LoginUserContext.userId());

        if (!previous.isBlank() && !previous.equals(path)) {
            try {
                fileStorage.delete(previous);
            } catch (RuntimeException ignored) {
                // 신규 경로가 정본
            }
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("idx", idx);
        out.put("photoPath", path);
        return out;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 키 배열을 양수 idx로 정규화하고 참조 여부를 한 번에 조회한다
     *   2) validate-delete·delete 양쪽에서 호출해 OPS_DELETE Double Check를 보장한다
     *   3) null·빈 배열·참조 행이 있으면 BizException
     */
    private void assertDeletable(
            // JWT 회사코드
            String coCd,
            // 허용된 마스터 유형
            MasterType masterType,
            // 삭제 키 객체 배열
            List<MasterDeleteItem> keys
    ) {
        DeleteValidation.requireItems(keys, "삭제할 기준정보를 선택하세요.");
        List<Long> idxs = new ArrayList<>();
        for (MasterDeleteItem key : keys) {
            if (key == null) {
                throw new BizException("삭제할 기준정보 키가 올바르지 않습니다.");
            }
            Long idx = DeleteValidation.requirePositive(key.getIdx(), "삭제할 기준정보 키가 올바르지 않습니다.");
            key.setIdx(idx);
            idxs.add(idx);
        }
        DeleteValidation.throwIfBlocked(
                mapper.selectDeleteBlocker(coCd, masterType.pathValue(), idxs),
                "기준정보"
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) SP to_jsonb 테이블 행(snake_case)을 API 계약 camelCase Map으로 변환한다
     *   2) 목록 조회 직후 호출해 그리드 field(productCd 등)와 키를 맞춘다
     *   3) JSON 파싱 실패 시 업무 예외로 안내한다
     */
    private Map<String, Object> readJsonRow(String json) {
        try {
            Map<String, Object> raw = objectMapper.readValue(json, new TypeReference<LinkedHashMap<String, Object>>() {});
            return toCamelMap(raw);
        } catch (Exception e) {
            throw new BizException("기준정보 조회 결과를 변환하지 못했습니다.");
        }
    }

    /** SP JSON 키(storage_cd)를 API 키(storageCd)로 바꾼다. */
    private Map<String, Object> toCamelMap(Map<String, Object> row) {
        Map<String, Object> out = new LinkedHashMap<>();
        if (row == null) {
            return out;
        }
        for (Map.Entry<String, Object> entry : row.entrySet()) {
            out.put(toCamelKey(entry.getKey()), entry.getValue());
        }
        return out;
    }

    /** storage_cd → storageCd, shelf_life_day → shelfLifeDay */
    private String toCamelKey(String key) {
        if (key == null || key.isBlank() || !key.contains("_")) {
            return key;
        }
        StringBuilder sb = new StringBuilder();
        boolean upper = false;
        for (int i = 0; i < key.length(); i++) {
            char ch = key.charAt(i);
            if (ch == '_') {
                upper = true;
                continue;
            }
            sb.append(upper ? Character.toUpperCase(ch) : ch);
            upper = false;
        }
        return sb.toString();
    }

    /** 공통 idx와 화면 필드를 저장 SP용 JSON 행으로 변환한다. */
    private String writeJsonRow(MasterSaveItem row) {
        try {
            Map<String, Object> payload = new LinkedHashMap<>(row.getValues());
            payload.put("idx", row.getIdx());
            return objectMapper.writeValueAsString(payload);
        } catch (Exception e) {
            throw new BizException("기준정보 저장 형식을 변환하지 못했습니다.");
        }
    }

    private static String nvl(String value) {
        return value == null ? "" : value.trim();
    }
}
