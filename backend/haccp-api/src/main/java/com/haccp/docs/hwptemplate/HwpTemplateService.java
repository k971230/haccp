/**
 * HwpTemplateService — 사용양식관리(시스템양식 / 자사양식) 업무 서비스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 목록·저장·파일이력·불러오기/초기화만 담당한다 — 파일 볼륨 I/O는 TemplateService 몫이다
 *   2) 신규 저장은 SP가 sys_yn=usr 로 강제하고, 화면이 보낸 sysYn 은 읽지 않는다
 *   3) 삭제는 법적서류 화면도 같은 URL을 쓰므로 WorkflowService에 남긴다 (그 메뉴 분할 때 이전)
 *
 * PIPELINE[HB123] 사용양식 업무 서비스
 * PIPELINE[HB92, HB88] 연관 모듈
 */
package com.haccp.docs.hwptemplate;

// 역할 — JWT 컨텍스트·업무 예외
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
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

    private final HwpTemplateMapper mapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 사용양식관리 좌측 목록을 조회한다 — hwp 양식만, 미사용도 포함한다
     *   2) 화면 진입·조회·저장 후 재조회에서 호출한다
     *   3) 구분·현재 파일명·기본/현재 파일 idx·이력건수까지 한 번에 내려 버튼 판정을 한 곳에서 한다
     */
    public List<Map<String, Object>> hwpTemplates(
            // 헤더 양식코드 검색어 — 공백이면 전체
            String tmplCd,
            // 헤더 양식명 검색어 — 공백이면 전체
            String tmplNm
    ) {
        return toCamelMaps(mapper.selectHwpTemplates(LoginUserContext.coCd(), text(tmplCd), text(tmplNm)));
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
        mapper.applyHwpTemplateFile(
                LoginUserContext.coCd(), tmplCd, longValue(row.get("fileIdx")), LoginUserContext.userId()
        );
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
