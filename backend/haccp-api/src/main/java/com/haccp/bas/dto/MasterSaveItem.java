/**
 * MasterSaveItem — 유형별 기준정보 저장 행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 공통 idx와 유형별 camelCase 필드를 JSON 행 그대로 수집한다
 *   2) 제품·보관고 등 서로 다른 컬럼을 하나의 저장 API로 전달한다
 *   3) 알 수 없는 화면 전용 필드는 SP가 사용하지 않아 저장 대상이 되지 않는다
 *
 * PIPELINE[HB77] 기준정보 DTO
 * PIPELINE[HB74, HB75, HB76] 연관 모듈
 */
package com.haccp.bas.dto;

// 역할 — Jackson JSON 동적 필드 수집
import com.fasterxml.jackson.annotation.JsonAnySetter;
// 역할 — Jackson 직렬화 제외
import com.fasterxml.jackson.annotation.JsonIgnore;
// 역할 — 동적 필드 맵
import java.util.LinkedHashMap;
import java.util.Map;
// 역할 — getter/setter
import lombok.Data;

/** 유형별 컬럼을 JSON payload로 전달하는 기준정보 저장 행이다. */
@Data
public class MasterSaveItem {
    // 수정 대상 대리키 — null이면 신규 행
    private Long idx;

    // SP에 전달할 유형별 camelCase 컬럼 — coCd·감사 컬럼은 Service가 넣지 않는다
    @JsonIgnore
    private final Map<String, Object> values = new LinkedHashMap<>();

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) idx 외의 JSON 속성을 유형별 payload에 보관한다
     *   2) 편집 그리드의 _rowState 같은 추가 속성도 역직렬화 오류 없이 받는다
     *   3) Service가 JSON으로 재직렬화하고 SP가 허용 컬럼만 읽는다
     */
    @JsonAnySetter
    public void putValue(
            // JSON 속성명 — productCd, storageNm 등
            String name,
            // JSON 속성값 — 문자열·숫자·null 모두 허용
            Object value
    ) {
        values.put(name, value);
    }
}
