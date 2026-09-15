/**
 * errors.test — 413·nginx HTML 을 업무 문구로 바꾸는지.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 토스트에 HTML 원문이 나가면 사용자가 원인을 모른다
 *   2) npm test 로 실행한다
 *   3) 실패하면 413 업로드가 콘솔 Uncaught 로만 남는다
 */
import { describe, expect, it } from "vitest";
import { toUserMessage } from "@/shell/errors";
import { MES } from "@/shell/messages";

const NGINX_413 = `<html>
<head><title>413 Request Entity Too Large</title></head>
<body>
<center><h1>413 Request Entity Too Large</h1></center>
<hr><center>nginx/1.27.5</center>
</body>
</html>`;

describe("toUserMessage", () => {
  it("nginx 413 HTML 은 용량 안내로 바꾼다", () => {
    expect(toUserMessage(NGINX_413)).toBe(MES.fileTooLarge);
    expect(toUserMessage(new Error(NGINX_413))).toBe(MES.fileTooLarge);
    expect(toUserMessage({ response: { status: 413, data: NGINX_413 } })).toBe(MES.fileTooLarge);
  });

  it("그 밖 HTML 은 서버 오류 문구다", () => {
    expect(toUserMessage("<html><title>502 Bad Gateway</title></html>")).toBe(MES.serverError);
  });

  it("Network Error 는 연결 안내로 바꾼다", () => {
    expect(toUserMessage(new Error("Network Error"))).toBe(MES.networkError);
    expect(toUserMessage("ERR_CONNECTION_RESET")).toBe(MES.networkError);
    expect(toUserMessage("net::ERR_CONNECTION_ABORTED")).toBe(MES.networkError);
  });

  it("서버 업무 문구는 그대로 둔다", () => {
    expect(toUserMessage({ response: { data: { message: "사원을 선택하세요." } } })).toBe("사원을 선택하세요.");
  });
});
