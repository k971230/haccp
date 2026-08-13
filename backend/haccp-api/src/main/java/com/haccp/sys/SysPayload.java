/**
 * SysPayload — 시스템 관리 화면이 보내는 느슨한 행·삭제키를 정규화하는 공용 유틸.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 편집 그리드는 _key·_rowState 같은 화면 전용 필드를 섞어 보내므로 서비스가 필요한 값만 꺼내 쓴다
 *   2) 공통코드·메뉴·권한그룹·부서·사용자 5개 서비스가 같은 규칙으로 값을 읽도록 한곳에 모았다
 *   3) 값이 없거나 형식이 어긋나면 빈 문자열·null로 되돌려 SP의 COALESCE·NULLIF 규칙에 맡긴다
 *
 * PIPELINE[HB92] 시스템 관리 공용 유틸
 */
package com.haccp.sys;

// 역할 — 업무 예외
import com.haccp.common.exception.BizException;
// 역할 — 삭제 대상 공통 검증
import com.haccp.common.validation.DeleteValidation;

// 역할 — 날짜 기본값·행/키 목록
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** 시스템 관리 행·삭제키 정규화 유틸 — 인스턴스를 만들지 않는다 */
public final class SysPayload {

    private SysPayload() {}

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 그리드 행에서 문자열 값을 꺼내 trim한다
     *   2) 저장 시 코드·명칭 컬럼을 SP로 넘기기 전에 호출한다
     *   3) 키가 없거나 null이면 빈 문자열 — SP가 NULLIF로 처리한다
     */
    public static String text(
            // 그리드 행 — camelCase 키
            Map<String, Object> row,
            // 꺼낼 필드명
            String key
    ) {
        Object value = row == null ? null : row.get(key);
        if (value == null) return "";
        String normalized = String.valueOf(value).trim();
        // 문자열로 직렬화된 null·undefined는 미입력으로 본다
        return normalized.equals("null") || normalized.equals("undefined") ? "" : normalized;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 그리드 행에서 정수 값을 꺼낸다 (정렬순서 등)
     *   2) 저장 시 sort_no 계열 컬럼에 쓴다
     *   3) 비었거나 숫자가 아니면 null — SP가 COALESCE로 기존 값을 유지한다
     */
    public static Integer intOrNull(Map<String, Object> row, String key) {
        String raw = text(row, key);
        if (raw.isEmpty()) return null;
        try {
            return Integer.valueOf(Integer.parseInt(raw.replace(",", "")));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 그리드 행에서 대리키(idx)를 꺼낸다
     *   2) 저장 시 신규(NULL)와 수정(값)을 가르는 유일한 판정 기준이다
     *   3) 비었거나 0 이하이면 null — SP가 INSERT 분기를 탄다
     */
    public static Long idxOrNull(Map<String, Object> row) {
        String raw = text(row, "idx");
        if (raw.isEmpty()) return null;
        try {
            long parsed = Long.parseLong(raw);
            return parsed > 0 ? Long.valueOf(parsed) : null;
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 저장 요청 목록이 비어 있지 않고 각 행이 null이 아닌지 검사한다
     *   2) 각 도메인 Service.save 진입 시 첫 줄에서 호출한다
     *   3) 위반이면 BizException — 화면은 mesError로 문구를 띄운다
     */
    public static void requireRows(
            // 저장 대상 행 목록
            List<Map<String, Object>> rows,
            // 업무명 라벨 — "공통코드" 등
            String label
    ) {
        DeleteValidation.requireItems(rows, "저장할 " + label + " 행이 없습니다.");
        for (Map<String, Object> row : rows) {
            if (row == null) throw new BizException("저장할 " + label + " 행이 올바르지 않습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 삭제 복합키 배열에서 idx 목록을 뽑아 검증한다
     *   2) validate-delete·delete 양쪽 assertDeletable에서 호출한다
     *   3) 비었거나 idx가 양수가 아니면 BizException
     */
    public static List<Long> idxList(
            // 삭제 대상 복합키 배열 — UI 단건이어도 1건 배열
            List<Map<String, Long>> keys,
            // 업무명 라벨 — "공통코드" 등
            String label
    ) {
        DeleteValidation.requireItems(keys, "삭제할 " + label + " 행을 선택하세요.");
        List<Long> idxs = new ArrayList<>();
        for (Map<String, Long> key : keys) {
            if (key == null) throw new BizException("삭제할 " + label + " 키가 올바르지 않습니다.");
            idxs.add(DeleteValidation.requirePositive(
                    key.get("idx"), "삭제할 " + label + " 키가 올바르지 않습니다."));
        }
        return idxs;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 화면이 보낸 기간 문자열을 YYYYMMDD로 정규화한다
     *   2) 로그 3화면 Controller가 fromDt·toDt에 쓴다
     *   3) 비면 오늘, 8자리가 아니면 BizException
     */
    public static String normalizeDate(
            // 화면이 보낸 값 — YYYY-MM-DD 또는 YYYYMMDD
            String value
    ) {
        if (value == null || value.isBlank()) {
            return LocalDate.now().format(DateTimeFormatter.BASIC_ISO_DATE);
        }
        String normalized = value.replace("-", "").trim();
        if (!normalized.matches("\\d{8}")) {
            throw new BizException("조회 기간은 YYYYMMDD 형식이어야 합니다.");
        }
        return normalized;
    }
}
