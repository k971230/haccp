/**
 * HwpDraftService — HWP 양식 작성 업무.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 이 화면 고유 조회(작성 목록·오늘 할일·양식 목록)만 직접 다룬다
 *   2) 저장·상세·삭제는 문서 허브 DocumentService 에 그대로 넘긴다 —
 *      기존 HWP 편집 화면과 같은 경로를 타야 두 화면의 결과가 어긋나지 않는다
 *   3) 전송·전송취소도 여기 없다. 문서 허브 processDocumentApproval 공용이다
 *
 * HWPX·HWP 원본 파일은 이 서비스를 거치지 않는다 — 문서 파일 업로드 API 가 받는다.
 *
 * PIPELINE[HB144] HWP 작성 Service
 */
package com.haccp.draft.hwp;

import com.haccp.common.exception.BizException;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.context.RequestMeta;
import com.haccp.docs.document.DocumentService;
import com.haccp.docs.document.dto.DocumentDeleteItem;
import com.haccp.docs.document.dto.HwpDocumentSaveRequest;
import com.haccp.draft.DraftSupport;
import com.haccp.draft.dto.DraftDeleteItem;
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import com.haccp.draft.dto.DraftSaveRequest;
import com.haccp.draft.dto.DraftTaskRow;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class HwpDraftService {

    // 기준일 기본값 형식 — 화면이 일자를 안 넘겼을 때 오늘로 본다
    private static final DateTimeFormatter YMD = DateTimeFormatter.ofPattern("yyyyMMdd");

    private final HwpDraftMapper mapper;
    private final DocumentService documentService;

    /** 작성 가능 양식 — 사용양식 관리에서 사용여부 예로 둔 HWP 양식 */
    public List<DraftFormRow> forms() {
        return mapper.selectForms(LoginUserContext.coCd());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 일자 구간·양식코드·양식명·작성자ID·작성자명으로 작성 목록을 조회한다
     *   2) 조회 버튼이 호출한다
     *   3) 빈 조건은 전체로 본다
     */
    public List<DraftListRow> list(
            // tmplCd: 양식코드 부분검색
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
                LoginUserContext.coCd(),
                DraftSupport.nvl(tmplCd),
                DraftSupport.nvl(tmplNm),
                DraftSupport.nvl(fromDt),
                DraftSupport.nvl(toDt),
                DraftSupport.nvl(writerId),
                DraftSupport.nvl(writerNm)
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 기준일의 오늘 할일 중 HWP 문서주기를 준다
     *   2) 행 추가 팝업이 호출한다
     *   3) 일자를 안 넘기면 오늘로 본다. 할일이 없으면 빈 목록 — 화면은 취소와 같게 다룬다
     */
    public List<DraftTaskRow> tasks(
            // baseDt: 기준일 YYYYMMDD. 빈값이면 오늘
            String baseDt
    ) {
        String dt = DraftSupport.nvl(baseDt);
        return mapper.selectTasks(
                LoginUserContext.coCd(),
                LoginUserContext.userId(),
                dt.length() == 8 ? dt : LocalDate.now().format(YMD)
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 문서 1건의 헤더·첨부·결재 이력을 준다 — rhwp 가 첨부에서 본문을 연다
     *   2) 좌측 행을 고르면 호출한다
     *   3) 신규(docIdx 없음)는 서버를 부르지 않고 화면이 빈 지면을 연다
     */
    public Map<String, Object> detail(
            // docIdx: tbl_document.idx
            Long docIdx
    ) {
        return documentService.detail(docIdx);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 일자·양식코드로 문서 헤더를 만들거나 고친다. 전송하지 않는다
     *   2) 좌측 저장·우측 저장이 모두 호출한다 — 본문 파일은 저장 뒤 업로드 API 가 올린다
     *   3) 일자가 8자리가 아니면 BizException
     */
    public Long save(
            // req: 작성 화면 공통 저장 요청 — HWP 는 양식코드·일자·제목만 쓴다
            DraftSaveRequest req,
            // requestMeta: 감사 로그용 요청 IP
            RequestMeta requestMeta
    ) {
        if (req == null) {
            throw new BizException("저장할 내용이 없습니다.");
        }
        HwpDocumentSaveRequest hwp = new HwpDocumentSaveRequest();
        hwp.setDocIdx(req.getDocIdx());
        hwp.setTmplCd(DraftSupport.nvl(req.getTmplCd()));
        hwp.setBaseDt(DraftSupport.requireBaseDt(req.getBaseDt()));
        // 제목은 비워 보낸다 — 문서 허브가 양식명과 기준일로 만든다
        hwp.setTitle(null);
        if (hwp.getTmplCd().isEmpty()) {
            throw new BizException("작성할 양식을 선택하세요.");
        }
        return documentService.saveHwpDocument(hwp, requestMeta);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다 (OPS_DELETE Double Check)
     *   2) 삭제 확인창 전에 호출한다
     *   3) 전송·결재완료 문서가 섞이면 BizException
     */
    public void validateDelete(
            // keys: [{ docIdx }] 객체 배열
            List<DraftDeleteItem> keys
    ) {
        documentService.validateDelete(toDocumentKeys(keys));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 문서와 딸린 첨부·원본 파일을 지운다
     *   2) 삭제 확인창에서 예를 고르면 호출한다
     *   3) 문서 허브가 같은 검사를 한 번 더 한다
     */
    public int delete(
            // keys: [{ docIdx }] 객체 배열
            List<DraftDeleteItem> keys,
            // requestMeta: 감사 로그용 요청 IP
            RequestMeta requestMeta
    ) {
        List<DocumentDeleteItem> docKeys = toDocumentKeys(keys);
        documentService.delete(docKeys, requestMeta);
        return docKeys.size();
    }

    /** 작성 화면 삭제 키 → 문서 허브 삭제 키. 두 화면이 같은 SP 로 지우게 한다 */
    private List<DocumentDeleteItem> toDocumentKeys(
            // keys: 화면이 넘긴 삭제 키
            List<DraftDeleteItem> keys
    ) {
        if (keys == null || keys.isEmpty()) {
            throw new BizException("삭제할 문서를 선택하세요.");
        }
        List<DocumentDeleteItem> out = new ArrayList<>();
        for (DraftDeleteItem key : keys) {
            DocumentDeleteItem item = new DocumentDeleteItem();
            item.setDocIdx(key.getDocIdx());
            out.add(item);
        }
        return out;
    }
}
