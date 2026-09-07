/**
 * RoleMgmtService — 권한그룹·화면권한의 조회·저장·삭제 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 회사코드·작업자는 JWT 컨텍스트에서만 읽는다
 *   2) 화면권한 저장은 조회권한(readYn) 하나로 5개 권한을 함께 여닫는다 — 1차 정책
 *   3) 삭제는 validate-delete·delete 양쪽에서 사용자 참조를 검사하는 Double Check다
 *
 * PIPELINE[HB94] 권한그룹 관리 Service
 */
package com.haccp.sys.code.role;

// 역할 — JWT 테넌트·작업자
import com.haccp.common.context.LoginUserContext;
// 역할 — 업무 예외
import com.haccp.common.exception.BizException;
// 역할 — 삭제 표준 검증
import com.haccp.common.validation.DeleteValidation;
import com.haccp.sys.code.role.dto.RoleDeleteItem;
import com.haccp.sys.code.role.dto.RoleRow;
import com.haccp.sys.code.role.dto.RoleSaveRow;
import com.haccp.sys.code.role.dto.RoleScreenRow;
import com.haccp.sys.code.role.dto.RoleScreenSaveRow;
// 역할 — 변경 감사 이력 적재
import com.haccp.sys.logs.auditlog.AuditWriter;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — 서비스 등록·트랜잭션
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

// 역할 — 화면 행·삭제키 목록
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class RoleMgmtService {

    /** 삭제 차단 문구에 쓰는 업무명 */
    private static final String LABEL = "권한그룹";
    /** 감사 이력 대상 테이블명 — 권한그룹 행 */
    private static final String AUDIT_TBL = "tbl_role";
    /** 감사 이력 대상 테이블명 — 화면권한 행 */
    private static final String AUDIT_TBL_SCREEN = "tbl_role_screen";

    // 권한그룹·화면권한 SP 호출
    private final RoleMgmtMapper roleMgmtMapper;
    // 저장·삭제 변경 감사 적재
    private final AuditWriter auditWriter;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 권한그룹 목록을 조회한다
     *   2) 화면 진입·조회와 사용자 관리 권한그룹 룩업에서 호출한다
     *   3) 조건에 맞는 그룹이 없으면 빈 목록
     */
    public List<RoleRow> list(
            // 헤더 권한그룹코드 검색어. 공백이면 전체
            String usrgrpCd,
            // 헤더 권한그룹명 검색어. 공백이면 전체
            String usrgrpNm,
            // 헤더 사용여부. 공백이면 Y·N 모두
            String useYn
    ) {
        return roleMgmtMapper.selectRows(
                LoginUserContext.coCd(), text(usrgrpCd), text(usrgrpNm), text(useYn));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 변경된 권한그룹 행을 순서대로 저장한다
     *   2) 저장 버튼에서 호출한다
     *   3) 한 행이라도 실패하면 전체 롤백된다 — 감사 이력도 함께 되돌아간다
     */
    @Transactional
    public void save(
            // 화면이 보낸 변경 행 목록 — idx가 없으면 신규
            List<RoleSaveRow> rows
    ) {
        DeleteValidation.requireItems(rows, "저장할 " + LABEL + " 행이 없습니다.");
        String coCd = LoginUserContext.coCd();
        String actor = LoginUserContext.userId();
        for (RoleSaveRow row : rows) {
            if (row == null) {
                throw new BizException("저장할 " + LABEL + " 행이 올바르지 않습니다.");
            }
            Long idx = idxOrNull(row.getIdx());
            roleMgmtMapper.save(
                    coCd,
                    idx,
                    text(row.getUsrgrpCd()),
                    text(row.getUsrgrpNm()),
                    text(row.getDescRmk()),
                    text(row.getUseYn()),
                    actor);
            // idx가 null일 때(= 신규 등록) I, 값이 있을 때(= 기존 행 수정) U
            auditWriter.record(AUDIT_TBL, idx, idx == null ? "I" : "U", auditRow(row, idx));
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 삭제 전 사용자 참조 여부만 검사한다 (Double Check 1단계)
     *   2) 확인 대화상자 직전에 호출한다
     *   3) 사용 중인 사용자가 있으면 BizException
     */
    public void validateDelete(
            // 삭제 대상 복합키 배열 — [{ idx }]
            List<RoleDeleteItem> keys
    ) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 참조를 다시 확인하고 통과한 그룹만 삭제한다 (Double Check 2단계)
     *   2) 사용자가 확인을 누른 뒤 호출한다
     *   3) 그룹에 딸린 화면권한 행도 SP가 함께 정리한다
     */
    @Transactional
    public void delete(
            // 삭제 대상 복합키 배열 — [{ idx }]
            List<RoleDeleteItem> keys
    ) {
        List<Long> idxs = assertDeletable(keys);
        String coCd = LoginUserContext.coCd();
        for (Long idx : idxs) {
            roleMgmtMapper.delete(coCd, idx);
            // 삭제는 남길 변경 후 값이 없으므로 대상 idx만 기록한다
            auditWriter.record(AUDIT_TBL, idx, "D", null);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 권한그룹의 화면별 권한 목록을 반환한다
     *   2) 권한 관리 우측 트리를 그릴 때 호출한다
     *   3) 그룹코드가 비면 업무 오류, 미설정 화면은 N으로 채워진다
     */
    public List<RoleScreenRow> listScreens(
            // 좌측에서 고른 권한그룹코드 — 필수
            String usrgrpCd
    ) {
        String grp = text(usrgrpCd);
        if (grp.isEmpty()) throw new BizException("권한그룹코드를 선택하세요.");
        return roleMgmtMapper.selectScreens(LoginUserContext.coCd(), grp);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 화면 조회권한(readYn) 변경을 저장한다 — 열림이면 5권한 Y, 닫힘이면 전부 N
     *   2) 권한 트리 체크 후 저장 버튼에서 호출한다
     *   3) 그룹코드가 비었거나 행이 없으면 업무 오류
     *   4) 감사 이력은 화면마다가 아니라 저장 한 번을 한 건으로 남긴다 — 한 번에 수십 화면이 바뀐다
     */
    @Transactional(timeout = 60)
    public void saveScreens(
            // 대상 권한그룹코드 — 필수
            String usrgrpCd,
            // 변경 행 목록 — [{ scrnCd, readYn }]
            List<RoleScreenSaveRow> rows
    ) {
        String grp = text(usrgrpCd);
        if (grp.isEmpty()) throw new BizException("권한그룹코드를 선택하세요.");
        DeleteValidation.requireItems(rows, "저장할 화면 권한이 없습니다.");
        String coCd = LoginUserContext.coCd();
        String actor = LoginUserContext.userId();
        // 감사 이력에 남길 화면·권한 요약 — 저장한 순서 그대로 담는다
        List<Map<String, Object>> changed = new ArrayList<>();
        for (RoleScreenSaveRow row : rows) {
            if (row == null) throw new BizException("화면 권한 행이 올바르지 않습니다.");
            String scrn = row.getScrnCd() == null ? "" : row.getScrnCd().trim();
            if (scrn.isEmpty()) throw new BizException("화면코드가 없습니다.");
            // 조회권한이 Y가 아니면 전부 닫는다 — 트리 체크 하나로 5권한을 함께 움직인다
            String yn = "Y".equalsIgnoreCase(text(row.getReadYn())) ? "Y" : "N";
            roleMgmtMapper.upsertScreen(coCd, grp, scrn, yn, yn, yn, yn, yn, actor);
            changed.add(Map.of("scrnCd", scrn, "readYn", yn));
        }
        // 화면권한은 그룹코드로만 식별되므로 tgtIdx는 남기지 않는다
        auditWriter.record(AUDIT_TBL_SCREEN, null, "U", Map.of("usrgrpCd", grp, "screens", changed));
    }

    /** 삭제 대상 idx 정규화 + 사용자 참조 검사 — validate·delete가 공유한다 */
    private List<Long> assertDeletable(List<RoleDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 " + LABEL + " 행을 선택하세요.");
        List<Long> idxs = new ArrayList<>();
        for (RoleDeleteItem key : keys) {
            if (key == null) {
                throw new BizException("삭제할 " + LABEL + " 키가 올바르지 않습니다.");
            }
            idxs.add(DeleteValidation.requirePositive(
                    key.getIdx(), "삭제할 " + LABEL + " 키가 올바르지 않습니다."));
        }
        DeleteValidation.throwIfBlocked(
                roleMgmtMapper.selectDeleteBlocker(LoginUserContext.coCd(), idxs), LABEL);
        return idxs;
    }

    private static Long idxOrNull(Long idx) {
        return idx != null && idx > 0 ? idx : null;
    }

    private static Map<String, Object> auditRow(RoleSaveRow row, Long idx) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("idx", idx);
        out.put("usrgrpCd", row.getUsrgrpCd());
        out.put("usrgrpNm", row.getUsrgrpNm());
        out.put("descRmk", row.getDescRmk());
        out.put("useYn", row.getUseYn());
        return out;
    }

    private static String text(String value) {
        return value == null ? "" : value.trim();
    }
}
