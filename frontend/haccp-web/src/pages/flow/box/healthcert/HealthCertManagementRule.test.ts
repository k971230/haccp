/**
 * HealthCertManagementRule.test — 캘린더 칩 위치·합침.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 등록·만료는 항상. 같으면 한 행
 *   2) 1·2·3차는 등록과 만료 사이에만
 *   3) 구간 밖 알림은 칸에 안 나온다
 */
import { describe, expect, it } from "vitest";
import { buildCalChipMap, calChipLabel, calChipTone } from "./HealthCertManagementRule";

const row = {
  userId: "u1",
  userNm: "김보건",
  regDt: "20260101",
  expireDt: "20260131",
};

describe("buildCalChipMap", () => {
  it("등록은 파란 칸, 만료는 빨간 칸에 따로 둔다", () => {
    const map = buildCalChipMap([row], { alarmDay1: 30, alarmDay2: 7, alarmDay3: 1 });
    expect(map.get("20260101")?.[0].kinds).toEqual(["reg"]);
    expect(map.get("20260131")?.[0].kinds).toEqual(["expire"]);
  });

  it("등록일과 만료일이 같으면 한 행이다", () => {
    const map = buildCalChipMap(
      [{ ...row, expireDt: "20260101" }],
      { alarmDay1: 30, alarmDay2: 7, alarmDay3: 1 },
    );
    expect(map.get("20260101")?.[0].kinds).toEqual(["reg", "expire"]);
    expect(map.size).toBe(1);
  });

  it("1·2·3차는 만료-N일이 등록과 만료 사이일 때만", () => {
    const map = buildCalChipMap([row], { alarmDay1: 10, alarmDay2: 7, alarmDay3: 1 });
    expect(map.get("20260121")?.[0].kinds).toEqual(["a1"]);
    expect(map.get("20260124")?.[0].kinds).toEqual(["a2"]);
    expect(map.get("20260130")?.[0].kinds).toEqual(["a3"]);
  });

  it("알림일이 등록 이전이면 그리지 않는다", () => {
    const map = buildCalChipMap([row], { alarmDay1: 40, alarmDay2: 7, alarmDay3: 1 });
    expect(map.get("20251222")).toBeUndefined();
    expect(map.get("20260124")?.[0].kinds).toEqual(["a2"]);
  });

  it("알림일이 등록일·만료일과 같으면 그리지 않는다", () => {
    const map = buildCalChipMap([row], { alarmDay1: 30, alarmDay2: 999, alarmDay3: 999 });
    expect(map.get("20260101")?.[0].kinds).toEqual(["reg"]);
    expect(map.get("20260131")?.[0].kinds).toEqual(["expire"]);
  });
});

describe("calChipTone", () => {
  it("만료가 있으면 빨강, 등록만이면 파랑이다", () => {
    expect(calChipTone(["reg", "expire"])).toContain("bg-rose-300");
    expect(calChipTone(["reg"])).toContain("bg-blue-300");
    expect(calChipTone(["a1"])).toContain("bg-emerald-300");
    expect(calChipTone(["a2"])).toContain("bg-amber-300");
    expect(calChipTone(["a3"])).toContain("bg-orange-300");
  });
});

describe("calChipLabel", () => {
  it("같은 날 등록·만료는 한 줄에 둘 다 적는다", () => {
    expect(calChipLabel({ userId: "u1", userNm: "김보건", kinds: ["reg", "expire"] }))
      .toBe("등록·만료 김보건");
  });
});
