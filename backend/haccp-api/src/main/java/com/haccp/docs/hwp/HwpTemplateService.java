/**
 * HwpTemplateService — 사용양식관리(시스템양식 / 자사양식) 업무 서비스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 목록·저장·파일이력·불러오기/초기화만 담당한다 — 파일 볼륨 I/O는 TemplateService 몫이다
 *   2) 신규 저장은 SP가 sys_yn=usr 로 강제하고, 화면이 보낸 sysYn 은 읽지 않는다
 *   3) 삭제는 차단 검사(시스템 제공분·작성된 문서)를 통과한 자사양식만 지운다
 *
 * PIPELINE[HB123] 사용양식 업무 서비스
 * PIPELINE[HB92, HB88] 연관 모듈
 */
package com.haccp.docs.hwp;

// 역할 — JWT 컨텍스트·업무 예외
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
// 역할 — 삭제 대상 검증·참조 차단 공통
import com.haccp.common.validation.DeleteValidation;
// 역할 — 감사 로그 기록 — 형제 화면과 같은 밀도로 남긴다
import com.haccp.sys.logs.auditlog.AuditWriter;
// 역할 — 목록·맵
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
// 역할 — Spring 서비스·트랜잭션
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class HwpTemplateService {

    /** 삭제 차단 문구에 쓰는 업무명 */
    private static final String LABEL = "사용양식";

    /** 감사 로그 대상 표 */
    private static final String AUDIT_TBL = "tbl_company_template";

    private final HwpTemplateMapper mapper;
    private final AuditWriter auditWriter;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 사용양식관리 좌측 목록을 조회한다 — hwp 양식만. 검색을 안 걸면 미사용도 포함한다
     *   2) 화면 진입·조회·저장 후 재조회에서 호출한다
     *   3) 구분·현재 파일명·기본/현재 파일 idx·이력건수까지 한 번에 내려 버튼 판정을 한 곳에서 한다
     */
    public List<Map<String, Object>> hwpTemplates(
            // 헤더 양식코드 검색어 — 공백이면 전체
            String tmplCd,
            // 헤더 양식명 검색어 — 공백이면 전체
            String tmplNm,
            // 헤더 구분 — sys|usr. 공백이면 전체
            String sysYn,
            // 헤더 사용여부 — Y|N. 공백이면 전체(미사용 포함)
            String useYn
    ) {
        return toCamelMaps(mapper.selectHwpTemplates(
                LoginUserContext.coCd(), text(tmplCd), text(tmplNm), text(sysYn), text(useYn)));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 사용양식 1건을 저장한다 — 신규는 SP가 sys_yn=usr(자사양식)로 강제한다
     *   2) 사용양식관리 저장 버튼이 신규·수정 구분 없이 호출한다
     *   3) 화면이 sysYn 을 보내도 읽지 않는다 — 양식 구분은 생성 이후 바꿀 수 없다
     */
    @Transactional(timeout = 60)
    public void saveHwpTemplate(Map<String, Object> row) {
        String tmplCd = requireText(row, "tmplCd", "양식코드를 입력하세요.");
        String tmplNm = requireText(row, "tmplNm", "양식명을 입력하세요.");
        mapper.saveHwpTemplate(
                LoginUserContext.coCd(), tmplCd, tmplNm, defaultYn(row.get("useYn")), LoginUserContext.userId()
        );
        // UPSERT 한 건이라 등록·수정을 못 갈라 U 로 통일한다 — 결재선 저장과 같다
        auditWriter.record(AUDIT_TBL, null, "U", Map.of(
                "tmplCd", tmplCd, "tmplNm", tmplNm, "useYn", defaultYn(row.get("useYn"))));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 선택한 양식의 파일 이력을 조회한다 — 삭제된 이력은 제외한다
     *   2) 사용양식관리 「불러오기」 팝업이 호출한다
     *   3) 현재 적용본(currentYn)·기본 제공본(defaultYn) 표시를 함께 내린다
     */
    public List<Map<String, Object>> hwpTemplateFiles(
            // 선택한 양식코드 — 공백이면 업무 문구로 차단
            String tmplCd
    ) {
        return toCamelMaps(mapper.selectHwpTemplateFiles(
                LoginUserContext.coCd(), requireText(tmplCd, "양식을 선택하세요.")
        ));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 과거 이력 버전을 현재 적용본으로 바꾸거나(불러오기) 기본 제공본으로 되돌린다(초기화)
     *   2) 사용양식관리 「불러오기」 선택 후·「초기화」 버튼이 호출한다
     *   3) fileIdx 가 없을 때(= 초기화) SP가 default_file_idx 를 쓰고, 과거 이력은 지우지 않는다
     */
    @Transactional(timeout = 60)
    public void applyHwpTemplateFile(Map<String, Object> row) {
        String tmplCd = requireText(row, "tmplCd", "양식을 선택하세요.");
        Long fileIdx = longValue(row.get("fileIdx"));
        mapper.applyHwpTemplateFile(
                LoginUserContext.coCd(), tmplCd, fileIdx, LoginUserContext.userId()
        );
        // fileIdx 가 없을 때(= 초기화) 기본 제공본으로 되돌린다
        auditWriter.record(AUDIT_TBL, fileIdx, "U", Map.of("tmplCd", tmplCd, "fileIdx", fileIdx == null ? "" : fileIdx));
    }

    private String requireText(Map<String, Object> row, String key, String message) {
        if (row == null) throw new BizException(message);
        return requireText(text(row.get(key)), message);
    }

    private String requireText(String value, String message) {
        if (text(value).isBlank()) throw new BizException(message);
        return value.trim();
    }

    private Long longValue(Object value) {
        if (value == null || text(value).isBlank()) return null;
        try {
            return Long.valueOf(text(value));
        } catch (NumberFormatException e) {
            throw new BizException("선택한 파일 이력이 올바르지 않습니다.");
        }
    }

    private String defaultYn(Object value) {
        String yn = text(value).toUpperCase();
        return yn.isBlank() ? "Y" : yn;
    }


    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 삭제 가능 여부만 검사하고 자료는 건드리지 않는다
     *   2) 화면이 삭제 확인창을 열기 전에 호출한다
     *   3) 시스템 제공 양식·작성된 문서가 있으면 400, 통과하면 void
     */
    public void validateDelete(
            // 삭제 키 객체 배열 — 단건도 [{ tmplCd }]
            List<Map<String, Object>> keys
    ) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) validate-delete 와 같은 검사를 다시 한 뒤 지운다 (Double Check)
     *   2) 화면 삭제 확인창에서 호출한다
     *   3) HTTP DELETE 를 쓰지 않는다 — 키는 객체 배열로만 받는다
     */
    @Transactional(timeout = 60)
    public void delete(
            // 삭제 키 객체 배열 — 단건도 [{ tmplCd }]
            List<Map<String, Object>> keys
    ) {
        List<String> tmplCds = assertDeletable(keys);
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        for (String tmplCd : tmplCds) {
            mapper.deleteHwpTemplate(coCd, tmplCd, userId);
            // 양식코드는 업무키라 대리키가 없다 — 무엇을 지웠는지는 tgtIdx 대신 사유에 남지 않으므로 null 로 둔다
            auditWriter.record(AUDIT_TBL, null, "D", Map.of("tmplCd", tmplCd));
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 삭제 키를 양식코드 목록으로 정규화하고 참조 차단을 검사한다
     *   2) validate-delete·delete 가 같은 검사를 쓰도록 공유한다
     *   3) 빈 목록·빈 양식코드는 여기서 막는다
     */
    private List<String> assertDeletable(List<Map<String, Object>> keys) {
        DeleteValidation.requireItems(keys, "삭제할 양식을 선택하세요.");
        List<String> tmplCds = new ArrayList<>();
        for (Map<String, Object> key : keys) {
            String tmplCd = DeleteValidation.requireText(
                    key == null ? null : text(key.get("tmplCd")), "삭제할 양식을 선택하세요.");
            if (!tmplCds.contains(tmplCd)) tmplCds.add(tmplCd);
        }
        DeleteValidation.throwIfBlocked(
                mapper.selectDeleteBlocker(LoginUserContext.coCd(), tmplCds), LABEL);
        return tmplCds;
    }

    private String text(Object value) {
        return value == null ? "" : String.valueOf(value).trim();
    }

    private List<Map<String, Object>> toCamelMaps(List<Map<String, Object>> rows) {
        List<Map<String, Object>> out = new ArrayList<>();
        if (rows == null) return out;
        for (Map<String, Object> row : rows) {
            Map<String, Object> camel = new LinkedHashMap<>();
            if (row != null) {
                for (Map.Entry<String, Object> entry : row.entrySet()) {
                    camel.put(toCamelKey(entry.getKey()), entry.getValue());
                }
            }
            out.add(camel);
        }
        return out;
    }

    /** tmpl_cd → tmplCd */
    private String toCamelKey(String key) {
        if (key == null || key.isBlank() || !key.contains("_")) return key;
        StringBuilder sb = new StringBuilder();
        boolean upper = false;
        for (int i = 0; i < key.length(); i++) {
            char ch = key.charAt(i);
            if (ch == '_') {
                upper = true;
                continue;
            }
            sb.append(upper ? Character.toUpperCase(ch) : ch);
            upper = false;
        }
        return sb.toString();
    }
}
