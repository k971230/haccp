/**
 * PestDeviceHistSaveItem — 방충설비 이력 저장 행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) idx·pestIdx와 이력 필드를 camelCase JSON 행으로 수집한다
 *   2) 신규는 idx 없이, 수정은 같은 설비의 idx를 포함해 저장 SP에 전달한다
 *   3) coCd·감사 컬럼은 본문에 두지 않고 Service가 JWT에서만 채운다
 *
 * PIPELINE[HB97] 설비이력 DTO
 * PIPELINE[HB94, HB95, HB96] 연관 모듈
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

/** 방충설비 이력 저장 행 — SP camelCase payload와 1:1이다. */
@Data
public class PestDeviceHistSaveItem {
    // 수정 대상 대리키 — null이면 신규 행
    private Long idx;
    // 상위 방충설비 대리키 — 저장 SP 필수
    private Long pestIdx;
    // 이력일 YYYYMMDD — 저장 SP 필수
    private String histDt;
    // 고장·이상 내용
    private String faultRmk;
    // 조치 내용
    private String actionRmk;
    // 연결 문서 idx — 없으면 null
    private Long docIdx;
    // 비고
    private String remark;

    // SP에 그대로 넘길 추가 camelCase 속성 — 그리드 _rowState 등은 무시된다
    @JsonIgnore
    private final Map<String, Object> extras = new LinkedHashMap<>();

    /**
     * 개발자: 박승우
     * 일자: 2026-08-07
     * 코멘트:
     *   1) 선언 필드 외 JSON 속성을 extras에 보관한다
     *   2) 편집 그리드의 _rowState 같은 추가 속성도 역직렬화 오류 없이 받는다
     *   3) Service가 허용 컬럼만 JSON으로 재직렬화한다
     */
    @JsonAnySetter
    public void putExtra(
            // JSON 속성명
            String name,
            // JSON 속성값
            Object value
    ) {
        extras.put(name, value);
    }
}
