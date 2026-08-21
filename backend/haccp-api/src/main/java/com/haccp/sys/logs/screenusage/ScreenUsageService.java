/**
 * ScreenUsageService — 화면 이용 통계 조회 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 회사코드는 JWT 컨텍스트에서만 읽는다
 *   2) 기간은 Controller가 정규화한 YYYYMMDD를 그대로 SP로 넘긴다
 *   3) 원시 로그가 아니라 일자 집계를 읽으므로 당일 값은 배치 이후에 보인다
 *
 * PIPELINE[HB94] 화면 이용 통계 Service
 */
package com.haccp.sys.logs.screenusage;

// 역할 — JWT 테넌트
import com.haccp.common.context.LoginUserContext;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — 서비스 등록
import org.springframework.stereotype.Service;

// 역할 — 통계 행 목록
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ScreenUsageService {

    // 화면 이용 통계 SP 호출
    private final ScreenUsageMapper screenUsageMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 기간 내 화면별 PV/UV/세션/IP 집계를 최신순으로 조회한다
     *   2) 화면 진입·조회와 좌측 메뉴 트리 선택 시 호출한다
     *   3) 집계가 아직 없으면 빈 목록
     */
    public List<Map<String, Object>> list(
            // 집계 시작일 YYYYMMDD — Controller가 정규화한 값
            String fromDt,
            // 집계 종료일 YYYYMMDD
            String toDt,
            // 좌측 메뉴 트리에서 고른 화면코드. 공백이면 전체
            String scrnCd
    ) {
        return screenUsageMapper.selectRows(
                LoginUserContext.coCd(), fromDt, toDt, text(scrnCd));
    }

    private static String text(String value) {
        return value == null ? "" : value.trim();
    }
}
