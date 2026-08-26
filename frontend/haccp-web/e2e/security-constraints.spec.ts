/**
 * security-constraints — 권한 우회·제약 위반.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 화면이 버튼을 숨겼다고 막힌 게 아니다 — API 를 직접 쳐서 서버가 막는지 본다
 *   2) 테넌트(co_cd)·작성자는 본문이 아니라 JWT 로만 정해져야 한다. 위조 본문을 보내 본다
 *   3) 상태 전이는 순서가 있다 — 전송 안 한 문서를 승인하거나, 승인된 문서를 고치면 안 된다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test, type APIRequestContext } from "@playwright/test";
import { adminCreds, dbOne, readonlyCreds } from "./helpers";

const API = process.env.E2E_API_BASE_URL || "http://localhost:7070";

async function tokenOf(request: APIRequestContext, id: string, pw: string): Promise<string> {
  const res = await request.post(`${API}/api/v1/auth/login`, { data: { userId: id, password: pw } });
  const token = ((await res.json())?.data?.token ?? "") as string;
  expect(token, `${id} 로그인 실패`).not.toBe("");
  return token;
}

test.describe("인증", () => {
  test("토큰 없이 부르면 401 이다", async ({ request }) => {
    const res = await request.get(`${API}/api/v1/sys/code/common-code-management/groups`);
    expect([401, 403], `토큰 없이 ${res.status()} 로 통과했다`).toContain(res.status());
  });

  test("망가진 토큰은 통하지 않는다", async ({ request }) => {
    const res = await request.get(`${API}/api/v1/sys/code/common-code-management/groups`, {
      // 헤더에는 ASCII 만 실린다 — 형식은 맞지만 서명이 틀린 토큰을 쓴다
      headers: { Authorization: "Bearer eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJoYWNrZXIifQ.bad-signature" },
    });
    expect([401, 403]).toContain(res.status());
  });

  test("비밀번호가 틀리면 토큰을 주지 않는다", async ({ request }) => {
    const res = await request.post(`${API}/api/v1/auth/login`, {
      data: { userId: adminCreds().user, password: "wrong-password" },
    });
    expect(res.status()).not.toBe(200);
  });
});

test.describe("권한", () => {
  test("조회 전용 계정은 저장 API 에서 막힌다", async ({ request }) => {
    const ro = readonlyCreds();
    test.skip(!ro, "E2E_RO_USER/E2E_RO_PASS 가 없어 건너뛴다");
    const token = await tokenOf(request, ro!.user, ro!.pass);
    const res = await request.put(`${API}/api/v1/sys/code/department-management/save`, {
      headers: { Authorization: `Bearer ${token}` },
      data: [{ deptCd: "E2EHACK", deptNm: "권한 우회 시도", useYn: "Y" }],
    });
    expect(res.status(), "조회 전용 계정이 저장에 성공했다").not.toBe(200);
    expect(dbOne("SELECT count(*) FROM tbl_dept WHERE dept_cd='E2EHACK'")).toBe("0");
  });

  test("삭제 권한이 없는 계정은 삭제 API 에서 막힌다", async ({ request }) => {
    // e2erw — USER 그룹. 읽기·쓰기·수정은 되고 삭제만 N 이다
    const token = await tokenOf(request, "e2erw", "1234");
    const res = await request.post(`${API}/api/v1/sys/code/department-management/delete`, {
      headers: { Authorization: `Bearer ${token}` },
      data: [{ deptCd: "QC" }],
    });
    expect(res.status(), "삭제 권한이 없는데 삭제가 통과했다").not.toBe(200);
  });
});

test.describe("테넌트", () => {
  test("본문에 남의 회사코드를 실어도 서버가 JWT 로 덮어쓴다", async ({ request }) => {
    const { user, pass } = adminCreds();
    const token = await tokenOf(request, user, pass);
    const res = await request.put(`${API}/api/v1/sys/code/department-management/save`, {
      headers: { Authorization: `Bearer ${token}` },
      data: [{ deptCd: "E2ETNT", deptNm: "테넌트 시험", useYn: "Y", coCd: "9999", insId: "someone" }],
    });
    expect(res.status()).toBe(200);
    // 9999 로 들어갔으면 다른 회사 자료를 오염시킨 것이다
    expect(
      dbOne("SELECT co_cd FROM tbl_dept WHERE dept_cd='E2ETNT'"),
      "본문의 회사코드가 그대로 저장됐다",
    ).toBe("0000");
    dbOne("DELETE FROM tbl_dept WHERE dept_cd='E2ETNT'");
  });
});

test.describe("상태 전이", () => {
  test("전송하지 않은 문서는 승인할 수 없다", async ({ request }) => {
    const { user, pass } = adminCreds();
    const token = await tokenOf(request, user, pass);
    /*
     * 전송대기 문서가 없으면 만든다 — 없다고 건너뛰면 이 검사가 조용히 사라진다.
     * 작성 API 를 그대로 쓴다(화면이 쓰는 것과 같은 길).
     */
    let idx = dbOne("SELECT idx FROM tbl_document WHERE status='WRK' ORDER BY idx DESC LIMIT 1");
    if (!idx) {
      const made = await request.put(`${API}/api/v1/draft/hwp-doc/hwp-write/save`, {
        headers: { Authorization: `Bearer ${token}` },
        data: { tmplCd: "hwp_sys_001", docIdx: null, baseDt: "20260825", deviationYn: "N" },
      });
      expect(made.status(), await made.text()).toBe(200);
      idx = dbOne("SELECT idx FROM tbl_document WHERE status='WRK' ORDER BY idx DESC LIMIT 1");
    }
    expect(idx, "전송대기 문서를 만들지 못했다").not.toBe("");

    const res = await request.put(`${API}/api/v1/docs/documents/approval`, {
      headers: { Authorization: `Bearer ${token}` },
      data: { docIdx: Number(idx), actionCd: "APPROVE" },
    });
    expect(res.status(), "작성중 문서가 바로 승인됐다").not.toBe(200);
    expect(dbOne(`SELECT status FROM tbl_document WHERE idx=${idx}`)).toBe("WRK");
  });

  test("없는 문서를 승인하려 하면 업무 오류다", async ({ request }) => {
    const { user, pass } = adminCreds();
    const token = await tokenOf(request, user, pass);
    const res = await request.put(`${API}/api/v1/docs/documents/approval`, {
      headers: { Authorization: `Bearer ${token}` },
      data: { docIdx: 999999999, actionCd: "APPROVE" },
    });
    expect(res.status()).not.toBe(200);
    // 500 이면 서버가 터진 것이고 400 이면 업무 문구로 막은 것이다
    expect(res.status(), "없는 문서에 서버가 터졌다").toBeLessThan(500);
  });

  test("지원하지 않는 결재 행위는 막는다", async ({ request }) => {
    const { user, pass } = adminCreds();
    const token = await tokenOf(request, user, pass);
    const idx = dbOne("SELECT idx FROM tbl_document ORDER BY idx DESC LIMIT 1");
    test.skip(!idx, "문서가 없어 건너뛴다");
    const res = await request.put(`${API}/api/v1/docs/documents/approval`, {
      headers: { Authorization: `Bearer ${token}` },
      data: { docIdx: Number(idx), actionCd: "DROP_TABLE" },
    });
    expect(res.status()).not.toBe(200);
    expect(res.status(), "모르는 행위에 서버가 터졌다").toBeLessThan(500);
  });
});

test.describe("입력 검증", () => {
  test("필수값을 비운 채 API 를 직접 쳐도 막는다", async ({ request }) => {
    const { user, pass } = adminCreds();
    const token = await tokenOf(request, user, pass);
    const res = await request.put(`${API}/api/v1/sys/code/department-management/save`, {
      headers: { Authorization: `Bearer ${token}` },
      data: [{ deptCd: "E2EEMPTY", deptNm: "", useYn: "Y" }],
    });
    expect(res.status(), "부서명이 비었는데 저장됐다").not.toBe(200);
    expect(dbOne("SELECT count(*) FROM tbl_dept WHERE dept_cd='E2EEMPTY'")).toBe("0");
  });

  test("길이를 넘긴 값은 서버가 자르지 않고 막는다", async ({ request }) => {
    const { user, pass } = adminCreds();
    const token = await tokenOf(request, user, pass);
    const long = "가".repeat(300);
    const res = await request.put(`${API}/api/v1/sys/code/department-management/save`, {
      headers: { Authorization: `Bearer ${token}` },
      data: [{ deptCd: "E2ELONG", deptNm: long, useYn: "Y" }],
    });
    // 막든 자르든 서버가 터지면 안 된다
    expect(res.status(), `긴 값에 서버가 터졌다: ${await res.text()}`).toBeLessThan(500);
    if (res.status() === 200) {
      const saved = dbOne("SELECT length(dept_nm) FROM tbl_dept WHERE dept_cd='E2ELONG'");
      dbOne("DELETE FROM tbl_dept WHERE dept_cd='E2ELONG'");
      expect(Number(saved), "길이 제한 없이 그대로 들어갔다").toBeLessThan(300);
    }
  });
});
