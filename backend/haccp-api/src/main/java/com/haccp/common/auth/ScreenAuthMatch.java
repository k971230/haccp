/**
 * ScreenAuthMatch — 요청 URL 이 가리키는 화면(또는 문서 허브)과 요구 권한.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 화면 API 는 scrnCd 1개. 문서 허브는 여러 화면 중 하나라도 권한이 있으면 통과
 *   2) 허브 삭제는 HWP 계열만 — HTML 작성 권한으로 HWP 문서를 지우는 우회를 막는다
 *   3) 허브 조회·결재는 작성·문서함 화면을 포함한다. 전송 API 가 허브를 쓰기 때문
 *
 * PIPELINE[HB145] 화면 권한 인터셉터
 */
package com.haccp.common.auth;

/** 권한 검사 대상 — 화면 1개 또는 문서 허브 */
public record ScreenAuthMatch(
        // NONE=화면 1개, DOC=작성·문서함 OR, HWP=HWP 계열만 OR
        HubKind hubKind,
        // 화면코드 — hubKind 가 NONE 일 때만 쓴다
        String scrnCd,
        // 이 요청이 요구하는 권한 칸
        ScreenAuthAction action
) {
    public enum HubKind {
        NONE,
        DOC,
        HWP
    }

    public static ScreenAuthMatch screen(String scrnCd, ScreenAuthAction action) {
        return new ScreenAuthMatch(HubKind.NONE, scrnCd, action);
    }

    public static ScreenAuthMatch hubDoc(ScreenAuthAction action) {
        return new ScreenAuthMatch(HubKind.DOC, "", action);
    }

    public static ScreenAuthMatch hubHwp(ScreenAuthAction action) {
        return new ScreenAuthMatch(HubKind.HWP, "", action);
    }

    /** 문서 허브 요청이면 true */
    public boolean hub() {
        return hubKind != HubKind.NONE;
    }
}
