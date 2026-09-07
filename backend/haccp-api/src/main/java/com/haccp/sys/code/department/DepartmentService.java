/**
 * DepartmentService — 부서 관리 화면의 조회·저장·삭제 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 회사코드·작업자는 JWT 컨텍스트에서만 읽는다
 *   2) 부서는 트리라 삭제 차단 사유가 사용자 > 하위 부서 사용자 > 하위 부서 순으로 정해진다
 *   3) 삭제는 validate-delete·delete 양쪽에서 같은 검사를 돌리는 Double Check다
 *
 * PIPELINE[HB94] 부서 관리 Service
 */
package com.haccp.sys.code.department;

// 역할 — JWT 테넌트·작업자
import com.haccp.common.context.LoginUserContext;
// 역할 — 업무 예외
import com.haccp.common.exception.BizException;
// 역할 — 삭제 표준 검증
import com.haccp.common.validation.DeleteValidation;
import com.haccp.sys.code.department.dto.DeptDeleteItem;
import com.haccp.sys.code.department.dto.DeptRow;
import com.haccp.sys.code.department.dto.DeptSaveRow;
// 역할 — 변경 감사 이력 적재
import com.haccp.sys.logs.auditlog.AuditWriter;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — 서비스 등록·트랜잭션
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

// 역할 — 화면 행·삭제키·감사 요약
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class DepartmentService {

    /** 삭제 차단 문구에 쓰는 업무명 */
    private static final String LABEL = "부서";
    /** 감사 이력 대상 테이블명 */
    private static final String AUDIT_TBL = "tbl_dept";

    // 부서 관리 SP 호출
    private final DepartmentMapper departmentMapper;
    // 저장·삭제 변경 감사 적재
    private final AuditWriter auditWriter;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 부서 목록을 조회한다 — 상위부서명 포함
     *   2) 화면 진입·조회와 사용자 관리 부서 트리·룩업에서 호출한다
     *   3) 조건에 맞는 부서가 없으면 빈 목록
     */
    public List<DeptRow> list(
            // 헤더 부서코드 검색어. 공백이면 전체
            String deptCd,
            // 헤더 부서명 검색어. 공백이면 전체
            String deptNm,
            // 헤더 사용여부. 공백이면 Y·N 모두
            String useYn
    ) {
        return departmentMapper.selectRows(
                LoginUserContext.coCd(), text(deptCd), text(deptNm), text(useYn));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 변경된 부서 행을 순서대로 저장한다
     *   2) 저장 버튼에서 호출한다
     *   3) 한 행이라도 실패하면 전체 롤백된다 — 감사 이력도 함께 되돌아간다
     */
    @Transactional
    public void save(
            // 화면이 보낸 변경 행 목록 — idx가 없으면 신규
            List<DeptSaveRow> rows
    ) {
        DeleteValidation.requireItems(rows, "저장할 " + LABEL + " 행이 없습니다.");
        String coCd = LoginUserContext.coCd();
        String actor = LoginUserContext.userId();
        for (DeptSaveRow row : rows) {
            if (row == null) {
                throw new BizException("저장할 " + LABEL + " 행이 올바르지 않습니다.");
            }
            Long idx = idxOrNull(row.getIdx());
            departmentMapper.save(
                    coCd,
                    idx,
                    text(row.getDeptCd()),
                    text(row.getDeptNm()),
                    text(row.getHDeptCd()),
                    row.getSortNo(),
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
     *   1) 삭제 전 사용자·하위 부서 참조 여부만 검사한다 (Double Check 1단계)
     *   2) 확인 대화상자 직전에 호출한다
     *   3) 차단 사유가 있으면 BizException
     */
    public void validateDelete(
            // 삭제 대상 복합키 배열 — [{ idx }]
            List<DeptDeleteItem> keys
    ) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-12
     * 코멘트:
     *   1) 참조를 다시 확인하고 통과한 부서만 삭제한다 (Double Check 2단계)
     *   2) 사용자가 확인을 누른 뒤 호출한다
     *   3) 한 행이라도 실패하면 전체 롤백된다
     */
    @Transactional
    public void delete(
            // 삭제 대상 복합키 배열 — [{ idx }]
            List<DeptDeleteItem> keys
    ) {
        List<Long> idxs = assertDeletable(keys);
        String coCd = LoginUserContext.coCd();
        for (Long idx : idxs) {
            departmentMapper.delete(coCd, idx);
            // 삭제는 남길 변경 후 값이 없으므로 대상 idx만 기록한다
            auditWriter.record(AUDIT_TBL, idx, "D", null);
        }
    }

    /** 삭제 대상 idx 정규화 + 참조 검사 — validate·delete가 공유한다 */
    private List<Long> assertDeletable(List<DeptDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 " + LABEL + " 행을 선택하세요.");
        List<Long> idxs = new ArrayList<>();
        for (DeptDeleteItem key : keys) {
            if (key == null) {
                throw new BizException("삭제할 " + LABEL + " 키가 올바르지 않습니다.");
            }
            idxs.add(DeleteValidation.requirePositive(
                    key.getIdx(), "삭제할 " + LABEL + " 키가 올바르지 않습니다."));
        }
        DeleteValidation.throwIfBlocked(
                departmentMapper.selectDeleteBlocker(LoginUserContext.coCd(), idxs), LABEL);
        return idxs;
    }

    private static Long idxOrNull(Long idx) {
        return idx != null && idx > 0 ? idx : null;
    }

    private static Map<String, Object> auditRow(DeptSaveRow row, Long idx) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("idx", idx);
        out.put("deptCd", row.getDeptCd());
        out.put("deptNm", row.getDeptNm());
        out.put("hDeptCd", row.getHDeptCd());
        out.put("sortNo", row.getSortNo());
        out.put("useYn", row.getUseYn());
        return out;
    }

    private static String text(String value) {
        return value == null ? "" : value.trim();
    }
}
