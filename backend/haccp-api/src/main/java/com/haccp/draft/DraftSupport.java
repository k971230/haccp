/**
 * DraftSupport — 양식 작성 5화면 공용 판정·정규화 유틸.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 화면 서비스 4개가 같은 검사를 하고 있었다. 한 곳에 모아 한쪽만 고쳐지는 일을 막는다
 *   2) MyBatis·Spring 에 의존하지 않는 순수 함수다 — 매퍼는 호출부가 람다로 넘긴다
 *   3) 업무 오류는 BizException 으로 던진다. 사용자에겐 업무 문구만 나간다
 *
 * 규칙 08 「공유 유틸은 영역 루트에 둔다」에 따라 com.haccp.draft 루트에 둔다.
 *
 * PIPELINE[HB135] 양식 작성 공용 유틸
 */
package com.haccp.draft;

import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteBlocker;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.draft.dto.DraftDeleteItem;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;

public final class DraftSupport {

    private DraftSupport() {
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 이 화면이 다루는 자사 양식코드인지 확인하고 다듬은 값을 돌려준다
     *   2) 상세·저장·삭제 진입에서 호출한다 — 화면 범위 밖 양식을 서버에서 막는 유일한 관문이다
     *   3) 빈값이거나 접두가 다르거나 예시(*_000)면 BizException
     */
    public static String requireUsrTmpl(
            // tmplCd: 화면이 넘긴 양식코드
            String tmplCd,
            // prefix: 이 화면 자사 양식 접두 — html_hyg_prc_ · tml_ccp_chk_ · tml_ccp_pkg_ …
            String prefix,
            // stdTmplCd: 계열 예시코드 — 작성 대상이 아니다
            String stdTmplCd
    ) {
        String tmpl = nvl(tmplCd);
        // 예시 000 이거나 접두가 다를 때(= 이 화면 범위 밖) 거부한다
        if (tmpl.isEmpty() || !tmpl.startsWith(prefix) || tmpl.equals(stdTmplCd)) {
            throw new BizException("작성할 양식을 선택하세요.");
        }
        return tmpl;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 삭제 키를 정규화하고 전송 이후 문서를 차단한다 (OPS_DELETE Double Check)
     *   2) validate-delete 와 delete 양쪽에서 호출한다 — 한쪽만 부르면 검증이 뚫린다
     *   3) 차단 행이 있으면 참조 차단 문구로 BizException. 키를 int 로 다듬어 호출부에 돌려준다
     */
    public static void assertDeletable(
            // keys: [{ docIdx }] — UI 단건이어도 List 로 받아 All-or-Nothing 검증
            List<? extends DraftDeleteItem> keys,
            // blockerOf: 화면별 Mapper.selectDeleteBlocker 를 감싼 람다. 없으면 null 을 돌려준다
            Function<List<Long>, DeleteBlocker> blockerOf
    ) {
        DeleteValidation.requireItems(keys, "삭제할 문서를 선택하세요.");
        List<Long> docIdxs = new ArrayList<>();
        for (DraftDeleteItem key : keys) {
            Long docIdx = DeleteValidation.requirePositive(key.getDocIdx(), "삭제할 문서번호가 올바르지 않습니다.");
            key.setDocIdx(docIdx);
            docIdxs.add(docIdx);
        }
        DeleteValidation.throwIfBlocked(blockerOf.apply(docIdxs), "문서");
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 일자가 YYYYMMDD 8자리인지 본다 — 저장에서 보는 유일한 필수값이다
     *   2) 저장 진입에서 호출한다. 나머지 필수값은 전송 직전 화면이 본다
     *   3) 형식이 아니면 BizException
     */
    public static String requireBaseDt(
            // baseDt: 화면이 넘긴 일자
            String baseDt
    ) {
        String dt = nvl(baseDt);
        if (dt.length() != 8) {
            throw new BizException("일자를 입력하세요.");
        }
        return dt;
    }

    /** null·앞뒤 공백 제거 — 코드·이름처럼 공백이 의미 없는 칸 */
    public static String nvl(
            // value: 원본 문자열
            String value
    ) {
        return value == null ? "" : value.trim();
    }

    /**
     * 개행 보존 — 특이사항·개선조치처럼 사용자가 줄바꿈을 넣는 칸.
     * trim 하면 마지막 줄바꿈이 사라져 원본이 달라진다.
     */
    public static String note(
            // value: 원본 문자열
            String value
    ) {
        return value == null ? "" : value;
    }

    /** DB Map 값 → 문자열. SP 가 null 을 주는 칸이 있다 */
    public static String asText(
            // value: SP 결과 Map 값
            Object value
    ) {
        return value == null ? "" : String.valueOf(value);
    }

    /** DB Map 값 → Long. 숫자로 안 읽히면 null */
    public static Long asLong(
            // value: SP 결과 Map 값
            Object value
    ) {
        if (value == null) return null;
        try {
            return Long.valueOf(String.valueOf(value));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** DB Map 값 → int. 숫자로 안 읽히면 0 */
    public static int asInt(
            // value: SP 결과 Map 값
            Object value
    ) {
        if (value == null) return 0;
        try {
            return Integer.parseInt(String.valueOf(value));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    /** 숫자로 읽히는 값인지 — 기록 셀을 num_val 로 넣을지 txt_val 로 넣을지 가른다 */
    public static boolean isNumeric(
            // value: 지면 입력값
            String value
    ) {
        if (value == null || value.isBlank()) return false;
        try {
            Double.parseDouble(value.trim());
            return true;
        } catch (NumberFormatException e) {
            return false;
        }
    }
}
