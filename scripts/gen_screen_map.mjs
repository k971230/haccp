/**
 * gen_screen_map — 소스와 시드에서 docs/3_화면_지도.md 를 만든다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 메뉴 이름·계층은 db_sasshaccp/02_seed.sql 의 tbl_menu 에서 읽는다 — DB 접속이 필요 없다
 *   2) URL 은 tabRoute.ts, FE 는 pages 폴더, BE 는 컨트롤러 @RequestMapping 에서 찾는다
 *   3) 화면이 하나 늘면 다시 돌린다. 손으로 표를 고치지 않는다
 *
 * 쓰기
 *   node scripts/gen_screen_map.mjs           다시 만든다
 *   node scripts/gen_screen_map.mjs --check   어긋나면 1 로 끝난다 (CI 용)
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT = path.join(ROOT, "docs", "3_화면_지도.md");
const read = (p) => fs.readFileSync(path.join(ROOT, p), "utf-8");

// ---------------------------------------------------------------- 메뉴 (02_seed)
// tbl_menu VALUES (idx, co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, ...)
const menus = new Map(); // menu_cd -> { nm, parent, scrn }
for (const m of read("db_sasshaccp/02_seed.sql").matchAll(
  // "OVERRIDING SYSTEM VALUE" 에 V 가 들어 있어 [^V]* 로는 안 걸린다
  /INSERT INTO sasshaccp\.tbl_menu\b.*?VALUES \(\s*\d+,\s*'0000',\s*'([^']*)',\s*'([^']*)',\s*(NULL|'[^']*'),\s*(NULL|'[^']*')/g,
)) {
  const unq = (v) => (v === "NULL" ? null : v.slice(1, -1));
  menus.set(m[1], { nm: m[2], parent: unq(m[3]), scrn: unq(m[4]) });
}
/** 메뉴코드 → 표시명. 없으면 코드 그대로 */
const nameOf = (cd) => (cd && menus.get(cd) ? menus.get(cd).nm : cd ?? "");

// ---------------------------------------------------------------- URL (tabRoute)
const route = read("frontend/haccp-web/src/shell/tabRoute.ts");
const urls = new Map();
for (const m of route.matchAll(/paths\("([^"]+)",\s*\[([^\]]*)\]\)/gs)) {
  for (const cd of m[2].matchAll(/"([a-z0-9-]+)"/g)) urls.set(cd[1], `${m[1]}/${cd[1]}`);
}
for (const m of route.matchAll(/^\s*"([a-z0-9-]+)":\s*"(\/[a-z0-9-]+)",/gm)) urls.set(m[1], m[2]);

// ---------------------------------------------------------------- FE 페이지
/*
 * 파일명을 짐작하지 않는다 — scrnCd 와 컴포넌트를 잇는 정본은 screenRegistry.tsx 다.
 * sign-ready·sign-ok·document-inbox 처럼 한 컴포넌트를 mode 로 나눠 쓰는 화면이 있다.
 */
const registry = read("frontend/haccp-web/src/shell/screenRegistry.tsx");
const feMap = new Map();
for (const m of registry.matchAll(/^\s*"([a-z0-9-]+)":\s*(?:\(\)\s*=>\s*<)?([A-Z][A-Za-z0-9]*)/gm)) {
  feMap.set(m[1], m[2]);
}

/** scrnCd 가 쓰는 화면 컴포넌트 */
function feOf(scrnCd) {
  const name = feMap.get(scrnCd);
  return name ? { name } : null;
}


// ---------------------------------------------------------------- BE 컨트롤러
const controllers = []; // { name, base, file }
(function walkJava(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walkJava(p);
    else if (/Controller\.java$/.test(e.name)) {
      const t = fs.readFileSync(p, "utf-8");
      const base = t.match(/@RequestMapping\("([^"]+)"\)/);
      controllers.push({
        name: e.name.replace(/\.java$/, ""),
        base: base ? base[1] : null,
        // base 가 없으면 메서드에 전체 경로를 적는 컨트롤러다 — 그 경로들도 모은다
        paths: [...t.matchAll(/@(?:Get|Post|Put|Delete)Mapping\((?:value\s*=\s*)?"([^"]+)"/g)].map((x) => x[1]),
        file: path.relative(ROOT, p).replace(/\\/g, "/"),
      });
    }
  }
})(path.join(ROOT, "backend/haccp-api/src/main/java"));

/** 이 화면의 API 를 서빙하는 컨트롤러 — 자기 경로 우선, 없으면 공용 허브 */
function beOf(scrnCd, url) {
  const want = `/api/v1${url}`;
  const own = controllers.find((c) => c.base === want);
  if (own) return own.name;
  const viaMethod = controllers.find((c) => c.paths.some((p) => p.startsWith(want)));
  if (viaMethod) return `${viaMethod.name} (공용)`;
  return "공용 허브";
}

// ---------------------------------------------------------------- 전용 SP
const sp = read("db_sasshaccp/01_sp.sql");
const spOf = (scrnCd) =>
  [...sp.matchAll(/^CREATE OR REPLACE (?:PROCEDURE|FUNCTION) (?:sasshaccp\.)?sp_([a-z0-9_]+)/gm)]
    .filter((m) => m[1].startsWith(scrnCd.replace(/-/g, "_") + "_")).length;

// ---------------------------------------------------------------- 표
const rows = [...urls.entries()]
  .map(([scrnCd, url]) => {
    const menu = [...menus.values()].find((v) => v.scrn === scrnCd);
    const parent = menu?.parent ?? null;
    const grand = parent && menus.get(parent) ? menus.get(parent).parent : null;
    // 3단: 대=grand 중=parent. 2단(board 바로 아래 leaf): 대=parent 중=빈칸
    const top = grand ?? parent;
    const mid = grand ? parent : null;
    const fe = feOf(scrnCd);
    return {
      top: nameOf(top),
      mid: mid ? nameOf(mid) : "",
      nm: menu?.nm ?? scrnCd,
      scrnCd,
      url,
      fe: fe ? fe.name : "-",
      be: beOf(scrnCd, url),
      sp: spOf(scrnCd),
      sort: menu ? 1 : 0,
    };
  })
  .sort((a, b) => (a.top + a.mid + a.nm).localeCompare(b.top + b.mid + b.nm, "ko"));

const own = rows.filter((r) => !r.be.includes("공용")).length;

const doc = `# 3. 화면 지도

> 개발자: 박승우 · 일자: ${new Date().toISOString().slice(0, 10)}
> **${rows.length}화면**이 각 층에서 어디에 있는지.

화면 하나를 고칠 때 이 표에서 줄을 찾아 그 화면이 걸친 층을 먼저 본다.
만드는 법은 [\`2_화면_추가하기.md\`](2_화면_추가하기.md).

**손으로 고치지 않는다.** 화면이 하나 늘면 다시 뽑는다.

\`\`\`sh
node scripts/gen_screen_map.mjs           # 다시 만든다
node scripts/gen_screen_map.mjs --check   # 어긋나면 실패한다 (CI)
\`\`\`

출처: 메뉴 이름·계층은 \`db_sasshaccp/02_seed.sql\` 의 \`tbl_menu\`,
URL 은 \`tabRoute.ts\`, FE 는 \`pages/\`, BE 는 컨트롤러 \`@RequestMapping\`,
전용 SP 는 \`01_sp.sql\` 에서 읽는다. DB 접속이 필요 없다.

읽는 법

- **전용 SP** 는 \`sp_{scrnCd}_*\` 만 센 것이다. 0 이어도 공용 SP(\`sp_tbl_*\`)를 쓴다
- **BE** 가 「공용」이면 그 화면만의 컨트롤러가 없다는 뜻이다 —
  결재 3화면·문서함은 문서 허브(\`DocumentController\`)를, 양식 원본 5화면은
  \`TemplateController\` 를 나눠 쓴다. 지면 구조만 다르고 동작이 같아서다
- 자기 컨트롤러가 있는 화면은 **${own}개**다. 그 화면들은 URL = 폴더 = 패키지가 같다

---

| 대분류 | 중분류 | 화면 | scrnCd | URL | FE | BE | 전용 SP |
|---|---|---|---|---|---|---|---|
${rows
  .map((r) => `| ${r.top} | ${r.mid} | ${r.nm} | \`${r.scrnCd}\` | \`${r.url}\` | \`${r.fe}\` | \`${r.be}\` | ${r.sp} |`)
  .join("\n")}

## 관련

- 이름·경로 규칙: [\`4_명명과_경로.md\`](4_명명과_경로.md)
- 코드가 도는 순서: [\`../backend/haccp-api/PIPELINE.md\`](../backend/haccp-api/PIPELINE.md) · [\`../frontend/haccp-web/PIPELINE.md\`](../frontend/haccp-web/PIPELINE.md)
- 태그 색인: [\`5_PIPELINE_색인.md\`](5_PIPELINE_색인.md)
`;

if (process.argv.includes("--check")) {
  const now = fs.existsSync(OUT) ? fs.readFileSync(OUT, "utf-8") : "";
  // 날짜 줄과 줄바꿈(CRLF/LF)은 어긋남으로 보지 않는다 —
  // git 이 Windows 체크아웃에서 LF 를 CRLF 로 바꾼다. 내용이 같으면 통과다
  const strip = (t) =>
    t.replace(/일자: \d{4}-\d{2}-\d{2}/, "일자: -").replace(/\r\n/g, "\n");
  if (strip(now) !== strip(doc)) {
    console.error("화면 지도가 소스와 어긋났다 — node scripts/gen_screen_map.mjs 로 다시 뽑아라");
    process.exit(1);
  }
  console.log("화면 지도 최신");
  process.exit(0);
}

fs.writeFileSync(OUT, doc, "utf-8");
console.log(`docs/3_화면_지도.md — ${rows.length}화면 · 자기 컨트롤러 ${own}개`);
