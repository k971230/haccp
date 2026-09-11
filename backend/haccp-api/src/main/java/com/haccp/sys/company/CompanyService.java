/**
 * CompanyService — 테넌트 통째 삭제.
 *
 * 개발자: 박승우
 * 일자: 2026-09-11
 * 코멘트:
 *   1) 화면이 없다. 플랫폼(0000) ADMIN·HACCP_MASTER 만 다른 회사를 지운다
 *   2) 0000 과 로그인한 회사는 거절한다. SP 도 0000 을 한 번 더 막는다
 *   3) validate-delete·delete 가 같은 assertDeletable 을 돈다
 *
 * PIPELINE[HB146] 업체 삭제 서비스
 */
package com.haccp.sys.company;

// 역할 — JWT 호출자
import com.haccp.common.context.LoginUser;
import com.haccp.common.context.LoginUserContext;
// 역할 — 업무 예외·삭제 검증
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
// 역할 — 삭제 키
import com.haccp.sys.company.dto.CompanyDeleteItem;
// 역할 — 변경 감사
import com.haccp.sys.logs.auditlog.AuditWriter;
// 역할 — 목록
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
// 역할 — 서비스·트랜잭션
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 테넌트 통째 삭제 — 화면 없이 API+SP */
@Service
@RequiredArgsConstructor
public class CompanyService {

    /** 플랫폼 회사 — 지우면 공통 화면·시드가 사라진다 */
    static final String PLATFORM_CO = "0000";

    /** 감사 대상 표 */
    private static final String AUDIT_TBL = "tbl_company";

    private final CompanyMapper mapper;
    private final AuditWriter auditWriter;

    /**
     * 개발자: 박승우
     * 일자: 2026-09-11
     * 코멘트:
     *   1) 테넌트 삭제 가능 여부만 본다
     *   2) 호출 전에 확인창을 띄울 때 쓴다
     *   3) 통과 시 void. 플랫폼·자기 회사·권한 밖은 업무 오류
     */
    public void validateDelete(
            // 지울 회사 키 배열 — 단건도 1건
            List<CompanyDeleteItem> keys
    ) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-11
     * 코멘트:
     *   1) validate-delete 와 같은 검사 뒤 키별 SP 를 호출한다
     *   2) 운영에서 업체를 거둘 때 쓴다. E2E 는 SP 를 직접 부른다
     *   3) 성공 시 void. 뒤 건이 실패하면 앞 건도 롤백
     */
    @Transactional(timeout = 60)
    public void delete(
            // 지울 회사 키 배열 — 단건도 1건
            List<CompanyDeleteItem> keys
    ) {
        List<String> targets = assertDeletable(keys);
        String userId = LoginUserContext.userId();
        for (String coCd : targets) {
            mapper.purgeCompany(coCd, userId);
            auditWriter.record(AUDIT_TBL, null, "D", Map.of("coCd", coCd));
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-11
     * 코멘트:
     *   1) 호출자·대상·존재 여부를 한곳에서 본다
     *   2) validate-delete 와 delete 가 같이 부른다
     *   3) 정규화한 대상 회사코드 목록을 돌려준다
     */
    private List<String> assertDeletable(
            // 지울 회사 키 배열
            List<CompanyDeleteItem> keys
    ) {
        DeleteValidation.requireItems(keys, "삭제할 업체를 선택하세요.");
        if (!isPlatformMaster()) {
            throw new BizException("플랫폼 관리자만 업체를 삭제할 수 있습니다.");
        }
        String operatorCo = LoginUserContext.requireCoCd();
        ArrayList<String> targets = new ArrayList<>();
        for (CompanyDeleteItem key : keys) {
            String target = DeleteValidation.requireText(key.getCoCd(), "삭제할 회사코드가 올바르지 않습니다.");
            key.setCoCd(target);
            if (PLATFORM_CO.equals(target)) {
                throw new BizException("플랫폼 회사는 삭제할 수 없습니다.");
            }
            if (operatorCo.equals(target)) {
                throw new BizException("로그인한 회사는 삭제할 수 없습니다.");
            }
            if (mapper.countCompany(target) <= 0) {
                throw new BizException("업체를 찾을 수 없습니다.");
            }
            targets.add(target);
        }
        return targets;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-11
     * 코멘트:
     *   1) 플랫폼(0000) ADMIN·HACCP_MASTER 인지 본다
     *   2) 테넌트 관리자(자사 ADMIN)는 다른 회사를 못 지운다
     *   3) isAdmin() 은 ADMIN 만이라 HACCP_MASTER 를 같이 둔다
     */
    static boolean isPlatformMaster() {
        LoginUser user = LoginUserContext.get();
        if (user == null) {
            return false;
        }
        String co = user.getCoCd() == null ? "" : user.getCoCd().trim();
        if (!PLATFORM_CO.equals(co)) {
            return false;
        }
        String grp = user.getUsrgrpCd() == null ? "" : user.getUsrgrpCd().trim().toUpperCase(Locale.ROOT);
        return "ADMIN".equals(grp) || "HACCP_MASTER".equals(grp);
    }
}
