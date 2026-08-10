/**
 * MasterType — 허용된 HACCP 기준정보 API 종류.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) URL·SP에 전달할 기준정보 식별자를 한곳에서 제한한다
 *   2) 경로 문자열을 임의 SQL 식별자로 쓰지 않아 허용되지 않은 테이블 접근을 막는다
 *   3) ColdMonitor가 사용하는 ccp-limit도 명시 목록에 포함한다
 *
 * PIPELINE[HB73] 기준정보 API 타입
 * PIPELINE[HB74, HB75, HB76, HB77] 연관 모듈
 */
package com.metis.haccp.bas;

// 역할 — 업무 예외
import com.metis.haccp.common.exception.BizException;
// 역할 — 허용 문자열 비교
import java.util.Arrays;

/** URL masterType과 허용 DB 마스터를 1:1로 연결한다. */
public enum MasterType {
    PRODUCT("product"),
    MATERIAL("material"),
    PARTNER("partner"),
    STORAGE("storage"),
    EQUIPMENT("equipment"),
    MEASURING_DEVICE("measuring-device"),
    PEST_DEVICE("pest-device"),
    VEHICLE("vehicle"),
    WORK_AREA("work-area"),
    CCP_LIMIT("ccp-limit");

    private final String pathValue;

    MasterType(String pathValue) {
        this.pathValue = pathValue;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 경로 문자열을 허용 열거값으로 정규화한다
     *   2) 모든 목록·저장·삭제 API 진입점에서 먼저 호출한다
     *   3) 미등록 값일 때 BizException
     */
    public static MasterType from(
            // URL의 기준정보 식별자
            String pathValue
    ) {
        return Arrays.stream(values())
                .filter(type -> type.pathValue.equals(pathValue))
                .findFirst()
                .orElseThrow(() -> new BizException("지원하지 않는 기준정보입니다."));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) SP가 분기할 고정 문자열을 반환한다
     *   2) Mapper 파라미터에만 사용한다
     *   3) 항상 허용 목록의 값만 반환한다
     */
    public String pathValue() {
        return pathValue;
    }
}
