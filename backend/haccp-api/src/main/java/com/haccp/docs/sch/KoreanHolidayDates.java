/**
 * KoreanHolidayDates — holidays-kr JSON을 날짜 집합으로만 펼친다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 공휴일 규칙을 계산하지 않는다. hyunbinseo/holidays-kr basic.json 의 날짜 키만 Set으로 읽는다
 *   2) CycleScheduleGenerator.isNonWorkingDay가 토·일과 이 집합을 같이 본다
 *   3) 월력요항이 반영된 새 JSON으로 파일을 덮어쓰면 된다. 연도 하드코딩은 없다
 *
 * PIPELINE[HB97] 한국 공휴일 날짜 집합
 * PIPELINE[HB98] 연관 모듈
 */
package com.haccp.docs.sch;

// 역할 — JSON 트리 바인딩
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — 공휴일 날짜
import java.io.IOException;
import java.io.InputStream;
import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class KoreanHolidayDates {

    /** classpath JSON을 한 번만 펼친 공휴일 날짜 — 파일이 없으면 기동·시험이 바로 실패한다 */
    public static final Set<LocalDate> ALL = Set.copyOf(load());

    private KoreanHolidayDates() {}

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) /holidays/holidays-kr.json 의 연도 → {날짜: 명칭[]} 맵에서 날짜 키만 모은다
     *   2) CycleScheduleGenerator 생성·시험이 클래스 로드 시 이 집합을 쓴다
     *   3) 성공 시 불변 Set. 파일이 없거나 날짜 키가 깨지면 IllegalStateException
     */
    static Set<LocalDate> load() {
        // 경로: src/main/resources/holidays/holidays-kr.json — 런타임 HTTP를 치지 않는다
        try (InputStream in = KoreanHolidayDates.class.getResourceAsStream("/holidays/holidays-kr.json")) {
            if (in == null) {
                throw new IllegalStateException("공휴일 JSON이 없습니다: /holidays/holidays-kr.json");
            }
            Map<String, Map<String, List<String>>> years = new ObjectMapper().readValue(
                    in, new TypeReference<Map<String, Map<String, List<String>>>>() {});
            Set<LocalDate> out = new HashSet<>();
            if (years == null) return Set.of();
            for (Map<String, List<String>> days : years.values()) {
                if (days == null) continue;
                for (String key : days.keySet()) {
                    // key: YYYY-MM-DD — holidays-kr 정본. 파싱 실패 시 파일을 교체한 쪽이 틀린 것이다
                    out.add(LocalDate.parse(key));
                }
            }
            return out;
        } catch (IOException e) {
            throw new IllegalStateException("공휴일 JSON을 읽지 못했습니다: /holidays/holidays-kr.json", e);
        }
    }
}
