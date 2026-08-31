/**
 * HtmlTemplateService — HTML 양식 원본(자사 양식) 업무.
 *
 * 개발자: 박승우
 * 일자: 2026-08-31
 * 코멘트:
 *   1) 공정점검은 tbl_html_hyg_prc_ver, 검증점검은 tbl_tml_ccp_chk_ver, 포장·가열·금속검출일지는 tbl_tml_ccp_pkg_ver · tbl_tml_ccp_htg_ver · tbl_tml_ccp_mtl_ver
 *   2) 복사 시 사용양식만 만든다. 주기 행은 문서주기 화면에서 시작일과 함께 저장한다
 *   3) validate-delete와 delete 모두 assertDeletable Double Check
 *
 * PIPELINE[HB130] HTML양식 원본 Service
 */
package com.haccp.docs.htmlform.htmltemplate;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteBlocker;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.docs.htmlform.ccphtgtemplate.CcpHtgTemplateMapper;
import com.haccp.docs.htmlform.ccpmtltemplate.CcpMtlTemplateMapper;
import com.haccp.docs.htmlform.ccppkgtemplate.CcpPkgTemplateMapper;
import com.haccp.docs.htmlform.ccpverifytemplate.CcpVerifyTemplateMapper;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormVerDeleteItem;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class HtmlTemplateService {
    // 공정점검 화면 예시 — 시드 항목은 html_sys_001
    public static final String STD_TMPL_CD = "html_hyg_prc_000";
    // 옛 예시 코드 — 북마크 호환
    public static final String STD_TMPL_CD_LEGACY = "html_hyg_000";
    // 공정점검 점검항목 시드 — 작성 화면이 아직 이 코드를 쓴다
    public static final String SEED_TMPL_CD = "html_sys_001";
    // CCP 검증점검 화면 예시 — 시드 항목 18건
    public static final String CCP_STD_TMPL_CD = "tml_ccp_chk_000";
    // CCP 검증점검 카탈로그 — 작성 화면이 아직 이 코드를 쓴다
    public static final String CCP_SEED_TMPL_CD = "html_sys_006";
    // CCP-1B 포장 모니터링일지 화면 예시 — 시드 항목 5건
    public static final String PKG_STD_TMPL_CD = "tml_ccp_pkg_000";
    // CCP-2B 가열 모니터링일지 화면 예시 — 시드 항목 5건
    public static final String HTG_STD_TMPL_CD = "tml_ccp_htg_000";
    // CCP-3P 금속검출 모니터링일지 화면 예시 — 시드 항목 10건
    public static final String MTL_STD_TMPL_CD = "tml_ccp_mtl_000";

    private final HtmlTemplateMapper mapper;
    private final CcpVerifyTemplateMapper ccpMapper;
    private final CcpPkgTemplateMapper pkgMapper;
    private final CcpHtgTemplateMapper htgMapper;
    private final CcpMtlTemplateMapper mtlMapper;
    private final ObjectMapper objectMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 예시+자사 양식 목록을 반환한다
     *   2) 화면 진입·좌 저장·조회 후 호출한다
     *   3) tmplCd로 공정점검/검증점검/포장·가열·금속검출일지 테이블을 가른다
     */
    public List<Map<String, Object>> listVersions(
            // tmplCd: 가족. html_hyg_prc_000 / tml_ccp_chk_000 / tml_ccp_pkg_000 / tml_ccp_htg_000 / tml_ccp_mtl_000
            String tmplCd,
            // verCd: 양식코드 부분검색. 빈값이면 전체
            String verCd,
            // verNm: 양식명 부분검색. 빈값이면 전체
            String verNm
    ) {
        String tmpl = tmplCd == null ? "" : tmplCd.trim();
        String cd = verCd == null ? "" : verCd.trim();
        String nm = verNm == null ? "" : verNm.trim();
        String co = LoginUserContext.coCd();
        if (isMtl(tmpl)) {
            return mtlMapper.selectVersions(co, tmpl, cd, nm);
        }
        if (isHtg(tmpl)) {
            return htgMapper.selectVersions(co, tmpl, cd, nm);
        }
        if (isPkg(tmpl)) {
            return pkgMapper.selectVersions(co, tmpl, cd, nm);
        }
        if (isCcp(tmpl)) {
            return ccpMapper.selectVersions(co, tmpl, cd, nm);
        }
        return mapper.selectVersions(co, tmpl, cd, nm);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 우측 A4 항목을 반환한다
     *   2) 양식 선택 시 호출한다
     *   3) *_000 이면 시드
     */
    public List<Map<String, Object>> listItems(String tmplCd, Integer verNo) {
        String tmpl = tmplOf(tmplCd);
        int ver = isStdTmpl(tmpl) ? 0 : (verNo == null ? 1 : verNo);
        String co = LoginUserContext.coCd();
        if (isMtl(tmpl)) {
            return mtlMapper.selectItems(co, tmpl, ver);
        }
        if (isHtg(tmpl)) {
            return htgMapper.selectItems(co, tmpl, ver);
        }
        if (isPkg(tmpl)) {
            return pkgMapper.selectItems(co, tmpl, ver);
        }
        if (isCcp(tmpl)) {
            return ccpMapper.selectItems(co, tmpl, ver);
        }
        return mapper.selectItems(co, tmpl, ver);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-31
     * 코멘트:
     *   1) 표준 시드를 복사해 자사 양식·사용양식만 INSERT한다. 주기는 문서주기 화면에서 만든다
     *   2) 좌 저장이 pending 행을 커밋할 때 호출한다
     *   3) 새 tmplCd를 돌려 화면이 그 행을 유지한다
     */
    @Transactional(timeout = 60)
    public Map<String, Object> copy(
            // tmplCd: 가족. SP가 시드·채번 접두를 고른다
            String tmplCd,
            // srcVerNo: 호환. 행추가는 표준만
            Integer srcVerNo,
            // verCd: 호환. 번호는 SP가 채번
            String verCd,
            // verNm: 양식명 필수
            String verNm
    ) {
        String name = verNm == null ? "" : verNm.trim();
        if (name.isEmpty()) {
            throw new BizException("양식명은 필수입니다.");
        }
        String tmpl = tmplCd == null ? "" : tmplCd.trim();
        int src = srcVerNo == null ? 0 : srcVerNo;
        String code = verCd == null ? "" : verCd.trim();
        String newCd;
        if (isMtl(tmpl)) {
            newCd = mtlMapper.copyVersion(LoginUserContext.coCd(), tmpl, src, code, name, LoginUserContext.userId());
        } else if (isHtg(tmpl)) {
            newCd = htgMapper.copyVersion(LoginUserContext.coCd(), tmpl, src, code, name, LoginUserContext.userId());
        } else if (isPkg(tmpl)) {
            newCd = pkgMapper.copyVersion(LoginUserContext.coCd(), tmpl, src, code, name, LoginUserContext.userId());
        } else if (isCcp(tmpl)) {
            newCd = ccpMapper.copyVersion(LoginUserContext.coCd(), tmpl, src, code, name, LoginUserContext.userId());
        } else {
            newCd = mapper.copyVersion(LoginUserContext.coCd(), tmpl, src, code, name, LoginUserContext.userId());
        }
        if (newCd == null || newCd.isBlank()) {
            throw new BizException("복사한 양식을 찾을 수 없습니다.");
        }
        return Map.of("tmplCd", newCd.trim());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 자사 양식 항목만 저장한다. 테이블은 가족별
     *   2) 저장 버튼이 호출한다
     *   3) 표준이면 SP가 거부한다
     */
    @Transactional(timeout = 60)
    public void saveItems(String tmplCd, Integer verNo, List<Map<String, Object>> items) {
        String tmpl = tmplOf(tmplCd);
        if (isStdTmpl(tmpl) || verNo == null || verNo <= 0) {
            throw new BizException("표준 항목은 수정할 수 없습니다.");
        }
        try {
            String json = objectMapper.writeValueAsString(items == null ? List.of() : items);
            if (isMtl(tmpl)) {
                mtlMapper.saveItems(LoginUserContext.coCd(), tmpl, verNo, json, LoginUserContext.userId());
            } else if (isHtg(tmpl)) {
                htgMapper.saveItems(LoginUserContext.coCd(), tmpl, verNo, json, LoginUserContext.userId());
            } else if (isPkg(tmpl)) {
                pkgMapper.saveItems(LoginUserContext.coCd(), tmpl, verNo, json, LoginUserContext.userId());
            } else if (isCcp(tmpl)) {
                ccpMapper.saveItems(LoginUserContext.coCd(), tmpl, verNo, json, LoginUserContext.userId());
            } else {
                mapper.saveItems(LoginUserContext.coCd(), tmpl, verNo, json, LoginUserContext.userId());
            }
        } catch (JsonProcessingException e) {
            throw new BizException("점검항목 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 작성 신규 적용은 후속. 호환용으로 남긴다
     *   2) 기준관리 좌 저장은 호출하지 않는다
     *   3) 0이면 표준
     */
    @Transactional(timeout = 60)
    public void apply(String tmplCd, Integer verNo) {
        String tmpl = tmplOf(tmplCd);
        int ver = verNo == null ? 0 : verNo;
        if (isMtl(tmpl)) {
            mtlMapper.applyVersion(LoginUserContext.coCd(), tmpl, ver, LoginUserContext.userId());
        } else if (isHtg(tmpl)) {
            htgMapper.applyVersion(LoginUserContext.coCd(), tmpl, ver, LoginUserContext.userId());
        } else if (isPkg(tmpl)) {
            pkgMapper.applyVersion(LoginUserContext.coCd(), tmpl, ver, LoginUserContext.userId());
        } else if (isCcp(tmpl)) {
            ccpMapper.applyVersion(LoginUserContext.coCd(), tmpl, ver, LoginUserContext.userId());
        } else {
            mapper.applyVersion(LoginUserContext.coCd(), tmpl, ver, LoginUserContext.userId());
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 자사 양식명·회사 양식 사용여부를 고친다. 카탈로그 이름은 SP가 맞춘다
     *   2) 좌 저장이 이름·사용여부가 바뀐 저장행을 커밋할 때 호출한다
     *   3) 표준이면 거부. 공백 이름 거부. 사용여부는 Y/N
     */
    @Transactional(timeout = 60)
    public void updateVerNm(
            // tmplCd: 자사 양식코드
            String tmplCd,
            // verNo: 회사 순번. 0이면 표준
            Integer verNo,
            // verNm: 바꿀 양식명
            String verNm,
            // useYn: 회사 양식 사용여부. 문서주기가 이 값을 본다
            String useYn
    ) {
        String tmpl = tmplOf(tmplCd);
        if (isStdTmpl(tmpl) || verNo == null || verNo <= 0) {
            throw new BizException("표준 양식명은 수정할 수 없습니다.");
        }
        String name = verNm == null ? "" : verNm.trim();
        if (name.isEmpty()) {
            throw new BizException("양식명은 필수입니다.");
        }
        // 공통코드 use-yn(y/n) 또는 그리드 Y/N → 저장은 Y/N
        String yn = (useYn == null || useYn.isBlank() || !useYn.trim().toUpperCase().startsWith("N"))
                ? "Y" : "N";
        if (isMtl(tmpl)) {
            mtlMapper.updateVerNm(LoginUserContext.coCd(), tmpl, verNo, name, yn, LoginUserContext.userId());
        } else if (isHtg(tmpl)) {
            htgMapper.updateVerNm(LoginUserContext.coCd(), tmpl, verNo, name, yn, LoginUserContext.userId());
        } else if (isPkg(tmpl)) {
            pkgMapper.updateVerNm(LoginUserContext.coCd(), tmpl, verNo, name, yn, LoginUserContext.userId());
        } else if (isCcp(tmpl)) {
            ccpMapper.updateVerNm(LoginUserContext.coCd(), tmpl, verNo, name, yn, LoginUserContext.userId());
        } else {
            mapper.updateVerNm(LoginUserContext.coCd(), tmpl, verNo, name, yn, LoginUserContext.userId());
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) 확인창 전에 호출한다
     *   3) 표준은 차단
     */
    public void validateDelete(List<HtmlFormVerDeleteItem> keys) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-20
     * 코멘트:
     *   1) 재검증 후 자사 양식을 소프트 삭제하고 주기 행을 지운다
     *   2) 삭제 버튼이 호출한다
     *   3) 표준·작성 문서·오늘 할 일은 차단. 성공 시 건수
     */
    @Transactional(timeout = 60)
    public int delete(List<HtmlFormVerDeleteItem> keys) {
        assertDeletable(keys);
        for (HtmlFormVerDeleteItem key : keys) {
            if (isMtl(key.getTmplCd())) {
                mtlMapper.deleteVersion(
                        LoginUserContext.coCd(), key.getTmplCd(), key.getVerNo(), LoginUserContext.userId()
                );
            } else if (isHtg(key.getTmplCd())) {
                htgMapper.deleteVersion(
                        LoginUserContext.coCd(), key.getTmplCd(), key.getVerNo(), LoginUserContext.userId()
                );
            } else if (isPkg(key.getTmplCd())) {
                pkgMapper.deleteVersion(
                        LoginUserContext.coCd(), key.getTmplCd(), key.getVerNo(), LoginUserContext.userId()
                );
            } else if (isCcp(key.getTmplCd())) {
                ccpMapper.deleteVersion(
                        LoginUserContext.coCd(), key.getTmplCd(), key.getVerNo(), LoginUserContext.userId()
                );
            } else {
                mapper.deleteVersion(
                        LoginUserContext.coCd(), key.getTmplCd(), key.getVerNo(), LoginUserContext.userId()
                );
            }
        }
        return keys.size();
    }

    /** 삭제 키 정규화·표준 차단 Double Check. */
    private void assertDeletable(List<HtmlFormVerDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 양식을 선택하세요.");
        for (HtmlFormVerDeleteItem key : keys) {
            String tmplCd = tmplOf(key.getTmplCd());
            key.setTmplCd(tmplCd);
            int verNo = key.getVerNo() == null ? 0 : key.getVerNo();
            key.setVerNo(verNo);
            DeleteBlocker blocker = isMtl(tmplCd)
                    ? mtlMapper.selectDeleteBlocker(LoginUserContext.coCd(), tmplCd, verNo)
                    : isHtg(tmplCd)
                    ? htgMapper.selectDeleteBlocker(LoginUserContext.coCd(), tmplCd, verNo)
                    : isPkg(tmplCd)
                    ? pkgMapper.selectDeleteBlocker(LoginUserContext.coCd(), tmplCd, verNo)
                    : isCcp(tmplCd)
                    ? ccpMapper.selectDeleteBlocker(LoginUserContext.coCd(), tmplCd, verNo)
                    : mapper.selectDeleteBlocker(LoginUserContext.coCd(), tmplCd, verNo);
            DeleteValidation.throwIfBlocked(blocker, "양식");
        }
    }

    /** CCP-3P 금속검출일지 가족이면 true — 저장 테이블 tbl_tml_ccp_mtl_ver */
    private static boolean isMtl(String tmplCd) {
        String t = tmplCd == null ? "" : tmplCd.trim();
        return t.startsWith("tml_ccp_mtl");
    }

    /** CCP-2B 가열일지 가족이면 true — 저장 테이블 tbl_tml_ccp_htg_ver */
    private static boolean isHtg(String tmplCd) {
        String t = tmplCd == null ? "" : tmplCd.trim();
        return t.startsWith("tml_ccp_htg");
    }

    /** CCP-1B 포장일지 가족이면 true — 저장 테이블 tbl_tml_ccp_pkg_ver */
    private static boolean isPkg(String tmplCd) {
        String t = tmplCd == null ? "" : tmplCd.trim();
        return t.startsWith("tml_ccp_pkg");
    }

    /** CCP 검증점검 가족이면 true — 저장 테이블 tbl_tml_ccp_chk_ver */
    private static boolean isCcp(String tmplCd) {
        String t = tmplCd == null ? "" : tmplCd.trim();
        return t.startsWith("tml_ccp_chk") || CCP_SEED_TMPL_CD.equals(t);
    }

    private static boolean isStdTmpl(String tmplCd) {
        return STD_TMPL_CD.equals(tmplCd)
                || STD_TMPL_CD_LEGACY.equals(tmplCd)
                || SEED_TMPL_CD.equals(tmplCd)
                || CCP_STD_TMPL_CD.equals(tmplCd)
                || CCP_SEED_TMPL_CD.equals(tmplCd)
                || PKG_STD_TMPL_CD.equals(tmplCd)
                || HTG_STD_TMPL_CD.equals(tmplCd)
                || MTL_STD_TMPL_CD.equals(tmplCd);
    }

    private static String tmplOf(String tmplCd) {
        String value = tmplCd == null ? "" : tmplCd.trim();
        if (value.isEmpty()) {
            return STD_TMPL_CD;
        }
        if (STD_TMPL_CD_LEGACY.equals(value)) {
            return STD_TMPL_CD;
        }
        return value;
    }
}
