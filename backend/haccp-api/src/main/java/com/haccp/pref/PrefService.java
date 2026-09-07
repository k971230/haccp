/**
 * PrefService — 그리드 열 설정 저장 경계.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 저장만 맡는다. 조회 list 는 PrefController 가 Mapper 직행이다
 *   2) PUT /save 가 열 너비·표시여부를 올릴 때 호출한다
 *   3) @Transactional 을 컨트롤러에 두지 않는다 — CUD 경계는 Service
 *
 * PIPELINE[HB42] 그리드 설정 저장
 */
package com.haccp.pref;

// 역할 — 요청 스코프 컨텍스트 — coCd·userId
import com.haccp.common.context.LoginUserContext;
// 역할 — 그리드 설정 저장 요청 DTO
import com.haccp.pref.dto.GridPrefSaveRequest;
// 역할 — 생성자 주입·서비스 등록
import lombok.RequiredArgsConstructor;
// 역할 — CUD 트랜잭션 경계
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 사용자별 그리드 열 설정 저장 — 조회는 Controller → Mapper */
@Service
@RequiredArgsConstructor
public class PrefService {

    // 그리드 설정 SP 호출 — 업서트·빈 JSON 이면 행 삭제
    private final PrefMapper prefMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 그리드 열 설정을 저장하거나, 빈 JSON이면 초기화한다
     *   2) 사용자가 열 너비·표시여부를 바꾼 뒤 저장을 누를 때 호출한다
     *   3) PG CALL 영향 행 수는 -1 이라 호출부에 돌려주지 않는다
     */
    @Transactional
    public void save(
            // 저장 요청 본문 — scrnCd·gridId는 필수, prefJson은 비면 초기화 신호
            // 회사코드·사용자 아이디는 JWT에서만 읽는다
            GridPrefSaveRequest req
    ) {
        prefMapper.saveGridPref(
                // coCd: JWT 회사코드 — 테넌트 범위
                LoginUserContext.coCd(),
                // userId: JWT 로그인 아이디 — 요청 본문에서 받지 않는다
                LoginUserContext.userId(),
                // scrnCd: 화면코드 — (userId, scrnCd, gridId) 유니크 키
                req.getScrnCd(),
                // gridId: 편집 그리드 persistId
                req.getGridId(),
                // prefJson: 열 설정 JSON. 공백·null이면(= 초기화) SP가 해당 행을 지운다
                req.getPrefJson());
    }
}
