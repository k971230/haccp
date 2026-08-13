/**
 * AuditLogService — 변경 감사 이력 조회 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 회사코드는 JWT 컨텍스트에서만 읽는다
 *   2) 기간은 Controller가 정규화한 YYYYMMDD를 그대로 SP로 넘긴다
 *   3) 이력 화면이라 저장·삭제가 없다
 *
 * PIPELINE[HB94] 감사 이력 Service
 */
package com.haccp.sys.log;

// 역할 — JWT 테넌트
import com.haccp.common.context.LoginUserContext;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — 서비스 등록
import org.springframework.stereotype.Service;

// 역할 — 이력 행 목록
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AuditLogService {

    // 감사 이력 SP 호출
    private final AuditLogMapper auditLogMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 기간 내 변경 감사 이력을 최신순으로 조회한다
     *   2) 화면 진입·조회와 좌측 메뉴 트리 선택 시 호출한다
     *   3) 해당 기간에 이력이 없으면 빈 목록
     */
    public List<Map<String, Object>> list(
            // 조회 시작일 YYYYMMDD — Controller가 정규화한 값
            String fromDt,
            // 조회 종료일 YYYYMMDD
            String toDt,
            // 좌측 메뉴 트리 선택값. 공백이면 전체
            String menuKey,
            // 행위자 아이디 검색어. 공백이면 전체
            String userId,
            // 행위 필터. 공백이면 전체
            String actionCd
    ) {
        return auditLogMapper.selectRows(LoginUserContext.coCd(), fromDt, toDt,
                text(menuKey), text(userId), text(actionCd));
    }

    private static String text(String value) {
        return value == null ? "" : value.trim();
    }
}
