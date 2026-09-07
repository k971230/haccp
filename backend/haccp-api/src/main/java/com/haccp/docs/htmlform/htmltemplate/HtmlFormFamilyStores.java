/**
 * HtmlFormFamilyStores — tmplCd 접두로 가족 포트를 고른다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) if 사다리를 storeFor 한 곳에만 둔다. Service 여덟 메서드에 복붙하지 않는다
 *   2) 새 가족은 어댑터 하나 + storeFor 분기 한 줄. 화면별 Service 는 만들지 않는다
 *   3) 매퍼 다섯은 그대로 두고 여기 어댑터가 포트에 맞춘다
 *
 * PIPELINE[HB130] HTML양식 가족 레지스트리
 */
package com.haccp.docs.htmlform.htmltemplate;

// 역할 — 삭제 차단 한 줄
import com.haccp.common.validation.DeleteBlocker;
// 역할 — 가열·금속검출·포장·검증점검 매퍼
import com.haccp.docs.htmlform.ccphtgtemplate.CcpHtgTemplateMapper;
import com.haccp.docs.htmlform.ccpmtltemplate.CcpMtlTemplateMapper;
import com.haccp.docs.htmlform.ccppkgtemplate.CcpPkgTemplateMapper;
import com.haccp.docs.htmlform.ccpverifytemplate.CcpVerifyTemplateMapper;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormItemRow;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormVersionRow;
// 역할 — 버전·항목 행
import java.util.List;
// 역할 — 생성자 주입
import org.springframework.stereotype.Component;

/** tmplCd → 표 포트. 검증은 HtmlTemplateService */
@Component
public class HtmlFormFamilyStores {

    // 공정점검 — tbl_html_hyg_prc_ver
    private final HtmlFormFamilyStore hyg;
    // CCP 검증점검 — tbl_html_ccp_chk_ver
    private final HtmlFormFamilyStore ccp;
    // CCP-1B 포장 — tbl_html_ccp_pkg_ver
    private final HtmlFormFamilyStore pkg;
    // CCP-2B 가열 — tbl_html_ccp_htg_ver
    private final HtmlFormFamilyStore htg;
    // CCP-3P 금속검출 — tbl_html_ccp_mtl_ver
    private final HtmlFormFamilyStore mtl;

    public HtmlFormFamilyStores(
            // hygMapper: 공정점검 SP
            HtmlTemplateMapper hygMapper,
            // ccpMapper: 검증점검 SP
            CcpVerifyTemplateMapper ccpMapper,
            // pkgMapper: 포장일지 SP
            CcpPkgTemplateMapper pkgMapper,
            // htgMapper: 가열일지 SP
            CcpHtgTemplateMapper htgMapper,
            // mtlMapper: 금속검출일지 SP
            CcpMtlTemplateMapper mtlMapper
    ) {
        this.hyg = new HygStore(hygMapper);
        this.ccp = new CcpStore(ccpMapper);
        this.pkg = new PkgStore(pkgMapper);
        this.htg = new HtgStore(htgMapper);
        this.mtl = new MtlStore(mtlMapper);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 양식코드 접두로 가족 포트를 고른다
     *   2) Service 의 목록·복사·저장·삭제·blocker 가 부른다
     *   3) 어느 접두도 아니면 공정점검 — 예전 if 사다리와 같다
     */
    public HtmlFormFamilyStore storeFor(
            // tmplCd: 양식코드. html_ccp_mtl_007 등
            String tmplCd
    ) {
        if (isMtl(tmplCd)) {
            return mtl;
        }
        if (isHtg(tmplCd)) {
            return htg;
        }
        if (isPkg(tmplCd)) {
            return pkg;
        }
        if (isCcp(tmplCd)) {
            return ccp;
        }
        return hyg;
    }

    /** 일반위생·공정점검 가족이면 true — 저장 테이블 tbl_html_hyg_prc_ver */
    static boolean isHyg(String tmplCd) {
        String t = tmplCd == null ? "" : tmplCd.trim();
        return t.startsWith("html_hyg") || HtmlTemplateService.SEED_TMPL_CD.equals(t);
    }

    /** CCP-3P 금속검출일지 가족이면 true — 저장 테이블 tbl_html_ccp_mtl_ver */
    static boolean isMtl(String tmplCd) {
        String t = tmplCd == null ? "" : tmplCd.trim();
        return t.startsWith("html_ccp_mtl");
    }

    /** CCP-2B 가열일지 가족이면 true — 저장 테이블 tbl_html_ccp_htg_ver */
    static boolean isHtg(String tmplCd) {
        String t = tmplCd == null ? "" : tmplCd.trim();
        return t.startsWith("html_ccp_htg");
    }

    /** CCP-1B 포장일지 가족이면 true — 저장 테이블 tbl_html_ccp_pkg_ver */
    static boolean isPkg(String tmplCd) {
        String t = tmplCd == null ? "" : tmplCd.trim();
        return t.startsWith("html_ccp_pkg");
    }

    /** CCP 검증점검 가족이면 true — 저장 테이블 tbl_html_ccp_chk_ver */
    static boolean isCcp(String tmplCd) {
        String t = tmplCd == null ? "" : tmplCd.trim();
        return t.startsWith("html_ccp_chk") || HtmlTemplateService.CCP_SEED_TMPL_CD.equals(t);
    }

    /** 공정점검 매퍼 → 포트 */
    private static final class HygStore implements HtmlFormFamilyStore {
        private final HtmlTemplateMapper mapper;

        private HygStore(HtmlTemplateMapper mapper) {
            this.mapper = mapper;
        }

        @Override
        public List<HtmlFormVersionRow> selectVersions(String coCd, String tmplCd, String verCd, String verNm) {
            return mapper.selectVersions(coCd, tmplCd, verCd, verNm);
        }

        @Override
        public List<HtmlFormItemRow> selectItems(String coCd, String tmplCd, int verNo) {
            return mapper.selectItems(coCd, tmplCd, verNo);
        }

        @Override
        public String copyVersion(String coCd, String tmplCd, int srcVerNo, String verCd, String verNm, String userId) {
            return mapper.copyVersion(coCd, tmplCd, srcVerNo, verCd, verNm, userId);
        }

        @Override
        public void saveItems(String coCd, String tmplCd, int verNo, String items, String userId) {
            mapper.saveItems(coCd, tmplCd, verNo, items, userId);
        }

        @Override
        public void applyVersion(String coCd, String tmplCd, int verNo, String userId) {
            mapper.applyVersion(coCd, tmplCd, verNo, userId);
        }

        @Override
        public void updateVerNm(String coCd, String tmplCd, int verNo, String verNm, String useYn, String userId) {
            mapper.updateVerNm(coCd, tmplCd, verNo, verNm, useYn, userId);
        }

        @Override
        public DeleteBlocker selectDeleteBlocker(String coCd, String tmplCd, int verNo) {
            return mapper.selectDeleteBlocker(coCd, tmplCd, verNo);
        }

        @Override
        public void deleteVersion(String coCd, String tmplCd, int verNo, String userId) {
            mapper.deleteVersion(coCd, tmplCd, verNo, userId);
        }

        @Override
        public String auditVerTbl() {
            return "tbl_html_hyg_prc_ver";
        }
    }

    /** 검증점검 매퍼 → 포트 */
    private static final class CcpStore implements HtmlFormFamilyStore {
        private final CcpVerifyTemplateMapper mapper;

        private CcpStore(CcpVerifyTemplateMapper mapper) {
            this.mapper = mapper;
        }

        @Override
        public List<HtmlFormVersionRow> selectVersions(String coCd, String tmplCd, String verCd, String verNm) {
            return mapper.selectVersions(coCd, tmplCd, verCd, verNm);
        }

        @Override
        public List<HtmlFormItemRow> selectItems(String coCd, String tmplCd, int verNo) {
            return mapper.selectItems(coCd, tmplCd, verNo);
        }

        @Override
        public String copyVersion(String coCd, String tmplCd, int srcVerNo, String verCd, String verNm, String userId) {
            return mapper.copyVersion(coCd, tmplCd, srcVerNo, verCd, verNm, userId);
        }

        @Override
        public void saveItems(String coCd, String tmplCd, int verNo, String items, String userId) {
            mapper.saveItems(coCd, tmplCd, verNo, items, userId);
        }

        @Override
        public void applyVersion(String coCd, String tmplCd, int verNo, String userId) {
            mapper.applyVersion(coCd, tmplCd, verNo, userId);
        }

        @Override
        public void updateVerNm(String coCd, String tmplCd, int verNo, String verNm, String useYn, String userId) {
            mapper.updateVerNm(coCd, tmplCd, verNo, verNm, useYn, userId);
        }

        @Override
        public DeleteBlocker selectDeleteBlocker(String coCd, String tmplCd, int verNo) {
            return mapper.selectDeleteBlocker(coCd, tmplCd, verNo);
        }

        @Override
        public void deleteVersion(String coCd, String tmplCd, int verNo, String userId) {
            mapper.deleteVersion(coCd, tmplCd, verNo, userId);
        }

        @Override
        public String auditVerTbl() {
            return "tbl_html_ccp_chk_ver";
        }
    }

    /** 포장일지 매퍼 → 포트 */
    private static final class PkgStore implements HtmlFormFamilyStore {
        private final CcpPkgTemplateMapper mapper;

        private PkgStore(CcpPkgTemplateMapper mapper) {
            this.mapper = mapper;
        }

        @Override
        public List<HtmlFormVersionRow> selectVersions(String coCd, String tmplCd, String verCd, String verNm) {
            return mapper.selectVersions(coCd, tmplCd, verCd, verNm);
        }

        @Override
        public List<HtmlFormItemRow> selectItems(String coCd, String tmplCd, int verNo) {
            return mapper.selectItems(coCd, tmplCd, verNo);
        }

        @Override
        public String copyVersion(String coCd, String tmplCd, int srcVerNo, String verCd, String verNm, String userId) {
            return mapper.copyVersion(coCd, tmplCd, srcVerNo, verCd, verNm, userId);
        }

        @Override
        public void saveItems(String coCd, String tmplCd, int verNo, String items, String userId) {
            mapper.saveItems(coCd, tmplCd, verNo, items, userId);
        }

        @Override
        public void applyVersion(String coCd, String tmplCd, int verNo, String userId) {
            mapper.applyVersion(coCd, tmplCd, verNo, userId);
        }

        @Override
        public void updateVerNm(String coCd, String tmplCd, int verNo, String verNm, String useYn, String userId) {
            mapper.updateVerNm(coCd, tmplCd, verNo, verNm, useYn, userId);
        }

        @Override
        public DeleteBlocker selectDeleteBlocker(String coCd, String tmplCd, int verNo) {
            return mapper.selectDeleteBlocker(coCd, tmplCd, verNo);
        }

        @Override
        public void deleteVersion(String coCd, String tmplCd, int verNo, String userId) {
            mapper.deleteVersion(coCd, tmplCd, verNo, userId);
        }

        @Override
        public String auditVerTbl() {
            return "tbl_html_ccp_pkg_ver";
        }
    }

    /** 가열일지 매퍼 → 포트 */
    private static final class HtgStore implements HtmlFormFamilyStore {
        private final CcpHtgTemplateMapper mapper;

        private HtgStore(CcpHtgTemplateMapper mapper) {
            this.mapper = mapper;
        }

        @Override
        public List<HtmlFormVersionRow> selectVersions(String coCd, String tmplCd, String verCd, String verNm) {
            return mapper.selectVersions(coCd, tmplCd, verCd, verNm);
        }

        @Override
        public List<HtmlFormItemRow> selectItems(String coCd, String tmplCd, int verNo) {
            return mapper.selectItems(coCd, tmplCd, verNo);
        }

        @Override
        public String copyVersion(String coCd, String tmplCd, int srcVerNo, String verCd, String verNm, String userId) {
            return mapper.copyVersion(coCd, tmplCd, srcVerNo, verCd, verNm, userId);
        }

        @Override
        public void saveItems(String coCd, String tmplCd, int verNo, String items, String userId) {
            mapper.saveItems(coCd, tmplCd, verNo, items, userId);
        }

        @Override
        public void applyVersion(String coCd, String tmplCd, int verNo, String userId) {
            mapper.applyVersion(coCd, tmplCd, verNo, userId);
        }

        @Override
        public void updateVerNm(String coCd, String tmplCd, int verNo, String verNm, String useYn, String userId) {
            mapper.updateVerNm(coCd, tmplCd, verNo, verNm, useYn, userId);
        }

        @Override
        public DeleteBlocker selectDeleteBlocker(String coCd, String tmplCd, int verNo) {
            return mapper.selectDeleteBlocker(coCd, tmplCd, verNo);
        }

        @Override
        public void deleteVersion(String coCd, String tmplCd, int verNo, String userId) {
            mapper.deleteVersion(coCd, tmplCd, verNo, userId);
        }

        @Override
        public String auditVerTbl() {
            return "tbl_html_ccp_htg_ver";
        }
    }

    /** 금속검출일지 매퍼 → 포트 */
    private static final class MtlStore implements HtmlFormFamilyStore {
        private final CcpMtlTemplateMapper mapper;

        private MtlStore(CcpMtlTemplateMapper mapper) {
            this.mapper = mapper;
        }

        @Override
        public List<HtmlFormVersionRow> selectVersions(String coCd, String tmplCd, String verCd, String verNm) {
            return mapper.selectVersions(coCd, tmplCd, verCd, verNm);
        }

        @Override
        public List<HtmlFormItemRow> selectItems(String coCd, String tmplCd, int verNo) {
            return mapper.selectItems(coCd, tmplCd, verNo);
        }

        @Override
        public String copyVersion(String coCd, String tmplCd, int srcVerNo, String verCd, String verNm, String userId) {
            return mapper.copyVersion(coCd, tmplCd, srcVerNo, verCd, verNm, userId);
        }

        @Override
        public void saveItems(String coCd, String tmplCd, int verNo, String items, String userId) {
            mapper.saveItems(coCd, tmplCd, verNo, items, userId);
        }

        @Override
        public void applyVersion(String coCd, String tmplCd, int verNo, String userId) {
            mapper.applyVersion(coCd, tmplCd, verNo, userId);
        }

        @Override
        public void updateVerNm(String coCd, String tmplCd, int verNo, String verNm, String useYn, String userId) {
            mapper.updateVerNm(coCd, tmplCd, verNo, verNm, useYn, userId);
        }

        @Override
        public DeleteBlocker selectDeleteBlocker(String coCd, String tmplCd, int verNo) {
            return mapper.selectDeleteBlocker(coCd, tmplCd, verNo);
        }

        @Override
        public void deleteVersion(String coCd, String tmplCd, int verNo, String userId) {
            mapper.deleteVersion(coCd, tmplCd, verNo, userId);
        }

        @Override
        public String auditVerTbl() {
            return "tbl_html_ccp_mtl_ver";
        }
    }
}
