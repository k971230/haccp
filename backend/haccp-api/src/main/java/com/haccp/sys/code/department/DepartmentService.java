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
// 역할 — 삭제 표준 검증
import com.haccp.common.validation.DeleteValidation;
// 역할 — 행·삭제키 정규화 공용 유틸
import com.haccp.sys.SysPayload;
// 역할 — 변경 감사 이력 적재
import com.haccp.sys.logs.auditlog.AuditWriter;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — 서비스 등록·트랜잭션
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

// 역할 — 화면 행·삭제키 목록
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class DepartmentService {

    /** 삭제 차단 문구에 쓰는 업무명 */
    private static final String LABEL = "부서";
    /** 감사 이력 대상 테이블명 — AUDIT_TARGET 공통코드 sub_cd와 같아야 화면에 표시명이 붙는다 */
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
    public List<Map<String, Object>> list(
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
            List<Map<String, Object>> rows
    ) {
        SysPayload.requireRows(rows, LABEL);
        String coCd = LoginUserContext.coCd();
        String actor = LoginUserContext.userId();
        for (Map<String, Object> row : rows) {
            Long idx = SysPayload.idxOrNull(row);
            departmentMapper.save(
                    coCd,
                    idx,
                    SysPayload.text(row, "deptCd"),
                    SysPayload.text(row, "deptNm"),
                    SysPayload.text(row, "hDeptCd"),
                    SysPayload.intOrNull(row, "sortNo"),
                    SysPayload.text(row, "useYn"),
                    actor);
            // idx가 null일 때(= 신규 등록) I, 값이 있을 때(= 기존 행 수정) U
            auditWriter.record(AUDIT_TBL, idx, idx == null ? "I" : "U", row);
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
            List<Map<String, Long>> keys
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
            List<Map<String, Long>> keys
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
    private List<Long> assertDeletable(List<Map<String, Long>> keys) {
        List<Long> idxs = SysPayload.idxList(keys, LABEL);
        DeleteValidation.throwIfBlocked(
                departmentMapper.selectDeleteBlocker(LoginUserContext.coCd(), idxs), LABEL);
        return idxs;
    }

    private static String text(String value) {
        return value == null ? "" : value.trim();
    }
}
