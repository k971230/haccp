/**
 * gen_index — 저장소 폴더 목차를 INDEX.md 로 만든다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 폴더 트리와 각 폴더 README 의 첫 문장을 읽어 「무엇이 어디 있나」한 장을 낸다
 *   2) 손으로 적으면 곧 거짓말이 된다 — 2026-09-03 검수에서 죽은 링크 57본·틀린 숫자 9종이 그 이유로 나왔다
 *   3) README 없는 폴더를 따로 세운다. 규칙(CLAUDE.md)이 폴더마다 README 를 요구한다
 *
 * 쓰기
 *   node scripts/gen_index.mjs           다시 만든다
 *   node scripts/gen_index.mjs --check   어긋나면 1 로 끝난다 (CI 용)
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT = path.join(ROOT, "INDEX.md");

/** 세지 않는 것 — 빌드 산출물·의존성·로컬 스크래치. .gitignore 와 같은 뜻이다 */
const SKIP = new Set([
  ".git", "node_modules", "target", "dist", "out", "test-results",
  ".tools", ".playwright-mcp", "grokbot", ".vscode", ".idea", "certs",
]);

/** 소스가 든 폴더만 목차에 올린다 — 빈 폴더·자료 폴더는 뺀다 */
const SRC_EXT = /\.(ts|tsx|java|xml|sql|mjs|js|sh|css|yml|yaml)$/;

/** 폴더를 훑어 { rel, readme, files, dirs } 를 모은다 */
function walk(rel, out = []) {
  const abs = path.join(ROOT, rel);
  const entries = fs.readdirSync(abs, { withFileTypes: true });
  const files = entries.filter((e) => e.isFile()).map((e) => e.name);
  const dirs = entries
    .filter((e) => e.isDirectory() && !SKIP.has(e.name))
    .map((e) => e.name)
    .sort();

  out.push({
    rel,
    depth: rel === "." ? 0 : rel.split("/").length,
    readme: files.includes("README.md"),
    srcCount: files.filter((f) => SRC_EXT.test(f)).length,
    mdCount: files.filter((f) => f.endsWith(".md")).length,
  });

  for (const d of dirs) walk(rel === "." ? d : `${rel}/${d}`, out);
  return out;
}

/**
 * README 의 첫 뜻 있는 줄을 한 줄 설명으로 쓴다.
 * 제목(`# `)·인용(`> `)·빈 줄은 건너뛴다 — 제목은 폴더 이름 반복이라 정보가 없다.
 */
function summarize(rel) {
  const p = path.join(ROOT, rel === "." ? "README.md" : `${rel}/README.md`);
  if (!fs.existsSync(p)) return "";
  for (const raw of fs.readFileSync(p, "utf-8").split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("#") || line.startsWith(">") || line.startsWith("|")) continue;
    // 링크 표기를 벗겨 글자만 남긴다 — 목차에서 링크가 겹치면 읽기 나쁘다
    const text = line.replace(/\[([^\]]+)\]\([^)]+\)/g, "$1").replace(/[*`]/g, "");
    return text.length > 110 ? `${text.slice(0, 108)}…` : text;
  }
  return "";
}

const all = walk(".").filter((d) => d.rel !== ".");
/** 목차에 올릴 것 — README 가 있거나 소스가 든 폴더 */
const rows = all.filter((d) => d.readme || d.srcCount > 0);
const noReadme = all.filter((d) => !d.readme && d.srcCount > 0);

const tree = rows
  .map((d) => {
    const indent = "  ".repeat(Math.max(0, d.depth - 1));
    const name = d.rel.split("/").pop();
    const mark = d.readme ? "" : "  ← README 없음";
    const desc = d.readme ? summarize(d.rel) : "";
    return `${indent}${name}/${mark}${desc ? `\n${indent}    ${desc}` : ""}`;
  })
  .join("\n");

const doc = `# INDEX — 무엇이 어디 있나

> 개발자: 박승우 · 일자: ${new Date().toISOString().slice(0, 10)}
> **생성기가 만든다** — \`node scripts/gen_index.mjs\`. 손으로 고치지 않는다.

폴더와 그 폴더 README 의 첫 줄을 실물에서 뽑았다.
규칙·읽기 순서는 [\`CLAUDE.md\`](CLAUDE.md) · [\`AGENTS.md\`](AGENTS.md) 가 정본이다.
지금 상태는 [\`handoff.md\`](handoff.md), 문서 색인은 [\`docs/README.md\`](docs/README.md).

## 숫자

| | |
|---|---|
| 목차에 오른 폴더 | ${rows.length} |
| README 있는 폴더 | ${rows.filter((d) => d.readme).length} |
| **README 없는데 소스가 있는 폴더** | **${noReadme.length}** |

## 트리

\`\`\`
${tree}
\`\`\`
${
  noReadme.length
    ? `
## README 없는 폴더 (${noReadme.length})

\`CLAUDE.md\` 는 폴더를 새로 만들면 README 를 같이 만들라고 한다. 아래가 그 규칙 밖이다.

${noReadme.map((d) => `- \`${d.rel}\` — 소스 ${d.srcCount}본`).join("\n")}
`
    : "\n모든 소스 폴더에 README 가 있다.\n"
}
## 관련

- 읽기 순서: [\`.cursor/rules/00-bootstrap.mdc\`](.cursor/rules/00-bootstrap.mdc)
- 화면 전수: [\`docs/3_화면_지도.md\`](docs/3_화면_지도.md) — 생성기가 만든다
- SP → 표: [\`docs/9_SP_색인.md\`](docs/9_SP_색인.md) — 생성기가 만든다
`;

if (process.argv.includes("--check")) {
  const now = fs.existsSync(OUT) ? fs.readFileSync(OUT, "utf-8") : "";
  // 날짜 줄과 줄바꿈은 어긋남으로 보지 않는다 — git 이 Windows 에서 LF 를 CRLF 로 바꾼다
  const strip = (t) => t.replace(/일자: \d{4}-\d{2}-\d{2}/, "일자: -").replace(/\r\n/g, "\n");
  if (strip(now) !== strip(doc)) {
    console.error("INDEX 가 실물과 어긋났다 — node scripts/gen_index.mjs 로 다시 뽑아라");
    process.exit(1);
  }
  console.log("INDEX 최신");
  process.exit(0);
}

fs.writeFileSync(OUT, doc, "utf-8");
console.log(`INDEX.md — 폴더 ${rows.length} · README 없는 소스 폴더 ${noReadme.length}`);
