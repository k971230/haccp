/**
 * CcpVerifyDraftService — CCP 검증점검 양식 작성 업무.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 양식관리(ccp-verify-template)에서 사용여부 예로 둔 자사 양식만 작성 대상이다
 *   2) 저장은 전송 전이라 필수값을 보지 않는다. 필수값은 전송(REQUEST) 직전에 화면이 검사한다
 *   3) validate-delete 와 delete 모두 assertDeletable Double Check — 전송·결재완료는 차단
 *
 * 업무 규칙은 HYG(draft.hyg)와 같고 테이블·SP 만 CCP 것이다.
 * 전송·전송취소는 이 서비스가 아니라 문서 허브 결재 API(sp_tbl_document_approval_c_000)를 그대로 쓴다.
 *
 * PIPELINE[HB137] CCP 검증점검 작성 Service
 */
package com.haccp.draft.ccp;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.draft.ccp.dto.CcpVerifyDraftDeleteItem;
import com.haccp.draft.ccp.dto.CcpVerifyDraftFormRow;
import com.haccp.draft.ccp.dto.CcpVerifyDraftListRow;
import com.haccp.draft.ccp.dto.CcpVerifyDraftSaveRequest;
import com.haccp.flow.ca.DocCorrectiveSupport;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CcpVerifyDraftService {
    /** 계열 예시 양식코드 — 목록 SP 가 이 값으로 tbl_tml_ccp_chk_ver 를 가른다 */
    private static final String STD_TMPL_CD = "tml_ccp_chk_000";
    /** 자사 양식 접두 — 이 화면이 다루는 범위 */
    private static final String USR_TMPL_PREFIX = "tml_ccp_chk_";

    private final CcpVerifyDraftMapper mapper;
    private final ObjectMapper objectMapper;
    private final DocCorrectiveSupport correctiveSupport;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 작성에 쓸 수 있는 자사 양식(사용여부 예)만 반환한다
     *   2) 화면 진입 시 한 번 호출한다
     *   3) 없으면 빈 목록 — 화면이 양식관리 등록을 안내한다
     */
    public List<CcpVerifyDraftFormRow> forms() {
        return mapper.selectForms(LoginUserContext.coCd(), STD_TMPL_CD);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 좌측 작성 목록을 조회한다 — 상단 검색 6개 중 서버 조건 5개
     *   2) 조회 버튼·초기 로드·저장/삭제/전송 후 호출한다
     *   3) 공백 조건은 SP 가 전체로 본다. 결재 여부는 파생값이라 화면이 거른다
     */
    public List<CcpVerifyDraftListRow> list(
            // tmplCd: 양식코드 부분검색. 빈값이면 자사 양식 전체
            String tmplCd,
            // tmplNm: 양식명 부분검색
            String tmplNm,
            // fromDt: 일자 시작 YYYYMMDD
            String fromDt,
            // toDt: 일자 종료 YYYYMMDD
            String toDt,
            // writerId: 작성자 ID 부분검색
            String writerId,
            // writerNm: 작성자명 부분검색
            String writerNm
    ) {
        return mapper.selectList(
                LoginUserContext.coCd(), nvl(tmplCd), nvl(tmplNm),
                nvl(fromDt), nvl(toDt), nvl(writerId), nvl(writerNm));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 기존 상세 또는 선택 양식의 신규 기본행 JSON 을 반환한다
     *   2) 좌측 행 클릭·양식 선택이 호출한다
     *   3) 저장 문서면 이탈 푸터를 붙인다
     */
    public JsonNode detail(
            // tmplCd: 신규일 때 항목을 깔 양식코드. 필수
            String tmplCd,
            // docIdx: tbl_document.idx. null·0 이면 신규
            Long docIdx
    ) {
        String tmpl = requireUsrTmpl(tmplCd);
        try {
            ObjectNode root = (ObjectNode) objectMapper.readTree(
                    mapper.selectDetail(LoginUserContext.coCd(), tmpl, docIdx));
            // 저장된 문서일 때(= docIdx 있음) 개선조치 푸터를 함께 내린다
            if (docIdx != null && docIdx > 0) {
                root.set("corrective", objectMapper.valueToTree(
                        correctiveSupport.load(LoginUserContext.coCd(), docIdx)));
            } else {
                root.putNull("corrective");
            }
            return root;
        } catch (JsonProcessingException e) {
            throw new BizException("작성 자료를 읽지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 헤더·항목·하단 4칸을 저장한다. 전송 전이라 필수값은 검사하지 않는다
     *   2) 저장 버튼이 호출한다
     *   3) 아니오가 있으면 이탈을 자동 생성한다. 이름이 사용자와 같고 서명이 있으면 이미지를 복사한다
     */
    @Transactional(timeout = 60)
    public Long save(
            // req: 양식코드·일자·점검자·항목·하단 4칸
            CcpVerifyDraftSaveRequest req
    ) {
        if (req == null || nvl(req.getBaseDt()).length() != 8) {
            throw new BizException("일자를 입력하세요.");
        }
        String tmpl = requireUsrTmpl(req.getTmplCd());
        try {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("verNo", req.getVerNo() == null ? 0 : req.getVerNo());
            payload.put("items", req.getItems() == null ? List.of() : req.getItems());
            payload.put("specialNote", note(req.getSpecialNote()));
            payload.put("improveNote", note(req.getImproveNote()));
            payload.put("actionNm", note(req.getActionNm()));
            payload.put("confirmNm", note(req.getConfirmNm()));
            Long docIdx = mapper.save(
                    LoginUserContext.coCd(),
                    tmpl,
                    req.getDocIdx(),
                    req.getBaseDt().trim(),
                    nvl(req.getCheckerNm()),
                    objectMapper.writeValueAsString(payload),
                    LoginUserContext.userId()
            );
            if (docIdx == null || docIdx <= 0) {
                throw new BizException("저장에 실패했습니다.");
            }
            // 서명 스냅샷 — 이름=사용자면 blob 복사, 없으면 이름만
            mapper.snapshotSigns(
                    LoginUserContext.coCd(),
                    docIdx,
                    nvl(req.getCheckerNm()),
                    nvl(req.getApproverNm()),
                    nvl(req.getConfirmNm())
            );
            // 점검행에 아니오가 하나라도 있을 때(= 부적합) 개선조치를 자동 생성한다
            boolean hasNg = req.getItems() != null && req.getItems().stream().anyMatch(row -> {
                Object yn = row.get("yn");
                return yn != null && "N".equalsIgnoreCase(String.valueOf(yn).trim());
            });
            correctiveSupport.saveAutoIfNg(
                    LoginUserContext.coCd(),
                    docIdx,
                    tmpl,
                    req.getBaseDt().trim(),
                    req.getCorrective(),
                    hasNg,
                    LoginUserContext.userId()
            );
            return docIdx;
        } catch (JsonProcessingException e) {
            throw new BizException("작성 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) 확인창 전에 호출한다
     *   3) 전송·결재완료 문서는 차단
     */
    public void validateDelete(
            // keys: [{ docIdx }] 객체 배열
            List<CcpVerifyDraftDeleteItem> keys
    ) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 재검증 후 문서·하위를 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) 성공 시 건수
     */
    @Transactional(timeout = 60)
    public int delete(
            // keys: [{ docIdx }] 객체 배열
            List<CcpVerifyDraftDeleteItem> keys
    ) {
        assertDeletable(keys);
        for (CcpVerifyDraftDeleteItem key : keys) {
            mapper.delete(LoginUserContext.coCd(), key.getDocIdx(), LoginUserContext.userId());
        }
        return keys.size();
    }

    /** 삭제 키 정규화·전송 이후 차단 Double Check. */
    private void assertDeletable(
            // keys: UI 단건이어도 List 로 받아 All-or-Nothing 검증
            List<CcpVerifyDraftDeleteItem> keys
    ) {
        DeleteValidation.requireItems(keys, "삭제할 문서를 선택하세요.");
        List<Long> docIdxs = new ArrayList<>();
        for (CcpVerifyDraftDeleteItem key : keys) {
            Long docIdx = DeleteValidation.requirePositive(key.getDocIdx(), "삭제할 문서번호가 올바르지 않습니다.");
            key.setDocIdx(docIdx);
            docIdxs.add(docIdx);
        }
        DeleteValidation.throwIfBlocked(
                mapper.selectDeleteBlocker(LoginUserContext.coCd(), docIdxs),
                "문서"
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 이 화면이 다루는 자사 양식코드인지 확인한다
     *   2) 상세·저장 진입에서 호출한다
     *   3) 빈값이거나 접두가 다르거나 예시(000)면 BizException
     */
    private static String requireUsrTmpl(
            // tmplCd: 화면이 넘긴 양식코드
            String tmplCd
    ) {
        String tmpl = nvl(tmplCd);
        // 예시 000 이거나 접두가 다를 때(= 이 화면 범위 밖) 거부한다
        if (tmpl.isEmpty() || !tmpl.startsWith(USR_TMPL_PREFIX) || tmpl.equals(STD_TMPL_CD)) {
            throw new BizException("작성할 양식을 선택하세요.");
        }
        return tmpl;
    }

    private static String nvl(String value) {
        return value == null ? "" : value.trim();
    }

    /** 개행 보존 — 끝 공백 trim 금지 */
    private static String note(String value) {
        return value == null ? "" : value;
    }
}
