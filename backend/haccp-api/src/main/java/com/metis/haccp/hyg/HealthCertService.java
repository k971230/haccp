/**
 * HealthCertService — 건강진단관리기록부 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 목록·저장·삭제·첨부 업로드를 담당하며 coCd·userId는 JWT에서만 읽는다
 *   2) 첨부는 APP_FILE_ROOT/health-cert/{coCd}/ 아래에 저장하고 save SP로 경로를 갱신한다
 *   3) 삭제는 validate-delete와 delete에서 같은 키 검사를 두 번 수행한다
 *
 * PIPELINE[HB96] 건강진단 Service
 * PIPELINE[HB94, HB95, HB97] 연관 모듈
 */
package com.metis.haccp.hyg;

// 역할 — Jackson JSON 역직렬화 타입
import com.fasterxml.jackson.core.type.TypeReference;
// 역할 — Jackson JSON 직렬화·역직렬화
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — 로그인 테넌트·사용자 조회
import com.metis.haccp.common.context.LoginUserContext;
// 역할 — 업무 예외
import com.metis.haccp.common.exception.BizException;
// 역할 — 배열 삭제 검증 공통
import com.metis.haccp.common.validation.DeleteValidation;
// 역할 — 삭제 키 DTO
import com.metis.haccp.hyg.dto.HealthCertDeleteItem;
// 역할 — 입출력·경로
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
// 역할 — 생성자 DI
import lombok.RequiredArgsConstructor;
// 역할 — 설정값 주입
import org.springframework.beans.factory.annotation.Value;
// 역할 — Spring 서비스·트랜잭션
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
// 역할 — 업로드 파일
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class HealthCertService {

    private final HealthCertMapper mapper;
    private final ObjectMapper objectMapper;

    // 파일 저장 루트 — .env APP_FILE_ROOT에서만 받는다
    @Value("${app.file.root}")
    private String fileRoot;

    // 업로드 1건 최대 크기 — application.yml/.env에서만 받는다
    @Value("${app.file.max-bytes}")
    private long maxBytes;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 성명·사용여부 조건으로 건강진단 목록을 조회한다
     *   2) 화면 초기 로드·조회·저장·삭제·첨부 후 재조회에서 호출한다
     *   3) 성공 시 camelCase 행 목록
     */
    public List<Map<String, Object>> list(
            // 성명 부분검색 — null/공백이면 전체
            String personNm,
            // 사용여부 필터 — null/공백이면 전체
            String useYn
    ) {
        List<Map<String, Object>> rows = new ArrayList<>();
        for (String json : mapper.selectList(LoginUserContext.coCd(), nvl(personNm), nvl(useYn))) {
            rows.add(readJsonRow(json));
        }
        return rows;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 건강진단 행 배열을 하나의 트랜잭션에서 SP로 저장한다
     *   2) 신규는 idx 없이, 수정은 같은 테넌트의 idx를 포함해 호출한다
     *   3) 성공 시 void, SP 업무 오류 또는 JSON 변환 실패 시 롤백
     */
    @Transactional
    public void save(
            // 화면이 전송한 저장 행 배열 — camelCase Map
            List<Map<String, Object>> rows
    ) {
        DeleteValidation.requireItems(rows, "저장할 건강진단 기록이 없습니다.");
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        for (Map<String, Object> row : rows) {
            if (row == null || row.isEmpty()) {
                throw new BizException("저장할 건강진단 행이 올바르지 않습니다.");
            }
            mapper.save(coCd, writeJsonRow(row), userId);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 실제 삭제 없이 삭제 키만 검사한다
     *   2) FE가 확인창을 띄우기 전에 호출한다
     *   3) 키가 비정상일 때 BizException, 통과 시 void
     */
    public void validateDelete(
            // 삭제 키 객체 배열
            List<HealthCertDeleteItem> keys
    ) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 키 검사를 다시 통과한 건강진단 행을 SP 루프로 삭제한다
     *   2) validate-delete 이후 데이터가 바뀐 경우도 Double Check로 차단한다
     *   3) 성공 시 void — CALL 영향행수는 API에 노출하지 않는다
     */
    @Transactional
    public void delete(
            // 삭제 키 객체 배열
            List<HealthCertDeleteItem> keys
    ) {
        assertDeletable(keys);
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        for (HealthCertDeleteItem key : keys) {
            mapper.delete(coCd, key.getIdx(), userId);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 첨부를 health-cert/{coCd}/ 아래에 저장하고 save SP로 filePath·fileNm을 갱신한다
     *   2) 그리드 활성 행의 첨부 버튼에서 호출한다 — 저장되지 않은 신규 행은 거부한다
     *   3) 성공 시 갱신된 filePath·fileNm Map, 실패 시 BizException
     */
    @Transactional
    public Map<String, Object> uploadFile(
            // 첨부 대상 대리키
            Long idx,
            // 브라우저가 올린 파일
            MultipartFile file
    ) {
        Long targetIdx = DeleteValidation.requirePositive(idx, "첨부할 건강진단 기록을 선택하세요.");
        if (file == null || file.isEmpty()) {
            throw new BizException("업로드할 파일을 선택하세요.");
        }
        // maxBytes보다 클 때(= 운영 한도 초과) 디스크 쓰기 전 차단
        if (file.getSize() > maxBytes) {
            throw new BizException("파일 크기가 허용 한도를 초과했습니다.");
        }

        String coCd = LoginUserContext.coCd();
        String existingJson = mapper.selectByIdx(coCd, targetIdx);
        if (existingJson == null || existingJson.isBlank()) {
            throw new BizException("첨부할 건강진단 기록을 찾을 수 없습니다.");
        }
        Map<String, Object> existing = readJsonRow(existingJson);

        String original = safeName(file.getOriginalFilename());
        // DB·디스크 공통 상대 경로 — APP_FILE_ROOT 기준 health-cert/{coCd}/...
        String relative = "health-cert/" + coCd + "/" + UUID.randomUUID() + "_" + original;
        Path root = Path.of(fileRoot).toAbsolutePath().normalize();
        Path target = root.resolve(relative).normalize();
        // target이 root 밖일 때(= ../ 경로 조작) 즉시 차단
        if (!target.startsWith(root)) {
            throw new BizException("허용되지 않은 파일 경로입니다.");
        }

        try {
            Files.createDirectories(target.getParent());
            try (InputStream input = file.getInputStream()) {
                Files.copy(input, target, StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (IOException e) {
            throw new BizException("파일을 저장하지 못했습니다.");
        }

        String storedPath = relative.replace('\\', '/');
        String previousPath = text(existing.get("filePath"));

        Map<String, Object> payload = new LinkedHashMap<>(existing);
        payload.put("idx", targetIdx);
        payload.put("filePath", storedPath);
        payload.put("fileNm", original);
        mapper.save(coCd, writeJsonRow(payload), LoginUserContext.userId());

        // 이전 첨부 파일이 있을 때(= 교체) 고아 파일을 정리한다
        if (!previousPath.isBlank() && !previousPath.equals(storedPath)) {
            try {
                Path old = root.resolve(previousPath).normalize();
                if (old.startsWith(root)) {
                    Files.deleteIfExists(old);
                }
            } catch (IOException ignored) {
                // 신규 경로가 정본이므로 이전 파일 정리 실패는 무시
            }
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("idx", targetIdx);
        result.put("filePath", storedPath);
        result.put("fileNm", original);
        return result;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 키 배열을 양수 idx로 정규화한다
     *   2) validate-delete·delete 양쪽에서 호출해 OPS_DELETE Double Check를 보장한다
     *   3) null·빈 배열·비정상 idx면 BizException
     */
    private void assertDeletable(
            // 삭제 키 객체 배열
            List<HealthCertDeleteItem> keys
    ) {
        DeleteValidation.requireItems(keys, "삭제할 건강진단 기록을 선택하세요.");
        for (HealthCertDeleteItem key : keys) {
            if (key == null) {
                throw new BizException("삭제할 건강진단 키가 올바르지 않습니다.");
            }
            Long idx = DeleteValidation.requirePositive(key.getIdx(), "삭제할 건강진단 키가 올바르지 않습니다.");
            key.setIdx(idx);
        }
    }

    /** SP JSON 행을 API 계약 camelCase Map으로 변환한다. */
    private Map<String, Object> readJsonRow(String json) {
        try {
            Map<String, Object> raw = objectMapper.readValue(json, new TypeReference<LinkedHashMap<String, Object>>() {});
            return toCamelMap(raw);
        } catch (Exception e) {
            throw new BizException("건강진단 조회 결과를 변환하지 못했습니다.");
        }
    }

    /** SP JSON 키(person_nm)를 API 키(personNm)로 바꾼다. */
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

    /** person_nm → personNm */
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

    /** 화면 Map을 저장 SP용 JSON 행으로 변환한다. */
    private String writeJsonRow(Map<String, Object> row) {
        try {
            return objectMapper.writeValueAsString(row);
        } catch (Exception e) {
            throw new BizException("건강진단 저장 형식을 변환하지 못했습니다.");
        }
    }

    /** 경로 조작 문자·빈 파일명을 제거한다. */
    private String safeName(String original) {
        String name = original == null ? "" : Path.of(original).getFileName().toString();
        name = name.replaceAll("[^0-9A-Za-z가-힣._() -]", "_").trim();
        if (name.isBlank()) {
            throw new BizException("파일명이 올바르지 않습니다.");
        }
        return name;
    }

    private static String nvl(String value) {
        return value == null ? "" : value.trim();
    }

    private static String text(Object value) {
        return value == null ? "" : String.valueOf(value).trim();
    }
}
