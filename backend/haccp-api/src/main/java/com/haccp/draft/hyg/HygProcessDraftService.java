/**
 * HygProcessDraftService — 위생공정 양식 작성 업무.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 양식관리(hyg-process-template)에서 사용여부 예로 둔 자사 양식만 작성 대상이다
 *   2) 저장은 전송 전이라 필수값을 보지 않는다. 필수값은 전송(REQUEST) 직전에 화면이 검사한다
 *   3) validate-delete 와 delete 모두 assertDeletable Double Check — 전송·결재완료는 차단
 *
 * 전송·전송취소는 이 서비스가 아니라 문서 허브 결재 API(sp_tbl_document_approval_c_000)를 그대로 쓴다.
 *
 * PIPELINE[HB135] 위생공정 작성 Service
 */
package com.haccp.draft.hyg;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.draft.DraftSupport;
import com.haccp.draft.dto.DraftDeleteItem;
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import com.haccp.draft.dto.DraftSaveRequest;
import com.haccp.flow.ca.DocCorrectiveSupport;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class HygProcessDraftService {
    /** 계열 예시 양식코드 — 목록 SP 가 이 값으로 tbl_html_hyg_prc_ver 를 가른다 */
    private static final String STD_TMPL_CD = "html_hyg_prc_000";
    /** 자사 양식 접두 — 이 화면이 다루는 범위 */
    private static final String USR_TMPL_PREFIX = "html_hyg_prc_";

    private final HygProcessDraftMapper mapper;
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
    public List<DraftFormRow> forms() {
        return mapper.selectForms(LoginUserContext.coCd(), STD_TMPL_CD);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 좌측 작성 목록을 조회한다 — 상단 검색 6개 중 서버 조건 5개
     *   2) 조회 버튼·초기 로드·저장/삭제/전송 후 호출한다
     *   3) 공백 조건은 SP 가 전체로 본다. 결재여부는 파생값이라 화면이 거른다
     */
    public List<DraftListRow> list(
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
                LoginUserContext.coCd(), DraftSupport.nvl(tmplCd), DraftSupport.nvl(tmplNm),
                DraftSupport.nvl(fromDt), DraftSupport.nvl(toDt), DraftSupport.nvl(writerId), DraftSupport.nvl(writerNm));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 기존 상세 또는 선택 양식의 신규 기본행 JSON 을 반환한다
     *   2) 좌측 행 클릭·신규 버튼이 호출한다
     *   3) 저장 문서면 이탈 푸터를 붙인다
     */
    public JsonNode detail(
            // tmplCd: 신규일 때 항목을 깔 양식코드. 필수
            String tmplCd,
            // docIdx: tbl_document.idx. null·0 이면 신규
            Long docIdx
    ) {
        String tmpl = DraftSupport.requireUsrTmpl(tmplCd, USR_TMPL_PREFIX, STD_TMPL_CD);
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
            DraftSaveRequest req
    ) {
        if (req == null || DraftSupport.nvl(req.getBaseDt()).length() != 8) {
            throw new BizException("일자를 입력하세요.");
        }
        String tmpl = DraftSupport.requireUsrTmpl(req.getTmplCd(), USR_TMPL_PREFIX, STD_TMPL_CD);
        try {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("verNo", req.getVerNo() == null ? 0 : req.getVerNo());
            payload.put("items", req.getItems() == null ? List.of() : req.getItems());
            payload.put("specialNote", DraftSupport.note(req.getSpecialNote()));
            payload.put("improveNote", DraftSupport.note(req.getImproveNote()));
            payload.put("actionNm", DraftSupport.note(req.getActionNm()));
            payload.put("confirmNm", DraftSupport.note(req.getConfirmNm()));
            Long docIdx = mapper.save(
                    LoginUserContext.coCd(),
                    tmpl,
                    req.getDocIdx(),
                    req.getBaseDt().trim(),
                    DraftSupport.nvl(req.getCheckerNm()),
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
                    DraftSupport.nvl(req.getCheckerNm()),
                    DraftSupport.nvl(req.getApproverNm()),
                    DraftSupport.nvl(req.getConfirmNm())
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
            List<DraftDeleteItem> keys
    ) {
        DraftSupport.assertDeletable(keys, (ids) -> mapper.selectDeleteBlocker(LoginUserContext.coCd(), ids));
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
            List<DraftDeleteItem> keys
    ) {
        DraftSupport.assertDeletable(keys, (ids) -> mapper.selectDeleteBlocker(LoginUserContext.coCd(), ids));
        for (DraftDeleteItem key : keys) {
            mapper.delete(LoginUserContext.coCd(), key.getDocIdx(), LoginUserContext.userId());
        }
        return keys.size();
    }

}
