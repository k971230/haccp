/**
 * gen_pipeline_index — 소스의 PIPELINE 태그에서 docs/5_PIPELINE_색인.md 를 만든다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 태그 하나를 여러 파일이 달 수 있다 — 색인도 그 전부를 싣는다 (1:N)
 *   2) 태그를 더하거나 파일을 옮긴 뒤 돌린다. 손으로 표를 고치지 않는다
 *   3) Node 만 있으면 된다 — FE 빌드에 이미 필요하다
 *
 * 쓰기
 *   node scripts/gen_pipeline_index.mjs           다시 만든다
 *   node scripts/gen_pipeline_index.mjs --check   어긋나면 1 로 끝난다 (CI 용)
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT = path.join(ROOT, "docs", "5_PIPELINE_색인.md");

/** 훑을 소스 뿌리 — 빌드 산출물·의존성은 넣지 않는다 */
const ROOTS = [
  "frontend/haccp-web/src",
  "backend/haccp-api/src/main/java",
  "backend/haccp-api/src/main/resources/mapper",
];
const SKIP = new Set(["node_modules", "target", "dist", "out", ".git"]);

/** 태그 줄 — PIPELINE[HF74] 설명 · PIPELINE[HB92, HB88] 연관 모듈 */
const TAG_LINE = /PIPELINE\[([HFB0-9,\s]+)\]([^\n*]*)/g;

/** 파일을 하나씩 준다 */
function* walk(dir) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const e of entries) {
    if (SKIP.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) yield* walk(p);
    else if (/\.(ts|tsx|java|xml)$/.test(e.name)) yield p;
  }
}

// 태그 -> [{ file, note }]
const hits = new Map();
for (const r of ROOTS) {
  for (const file of walk(path.join(ROOT, r))) {
    const text = fs.readFileSync(file, "utf-8");
    for (const m of text.matchAll(TAG_LINE)) {
      const note = m[2].trim().replace(/\s+/g, " ") || "연관 모듈";
      for (const raw of m[1].split(",")) {
        const tag = raw.trim();
        if (!/^H[FB]\d+$/.test(tag)) continue;
        const rel = path.relative(ROOT, file).replace(/\\/g, "/");
        const list = hits.get(tag) ?? [];
        if (!list.some((x) => x.file === rel)) list.push({ file: rel, note });
        hits.set(tag, list);
      }
    }
  }
}

/** HF12 -> 12 로 숫자 정렬 */
const byNum = (a, b) => Number(a.slice(2)) - Number(b.slice(2));
const fe = [...hits.keys()].filter((t) => t.startsWith("HF")).sort(byNum);
const be = [...hits.keys()].filter((t) => t.startsWith("HB")).sort(byNum);

/** 태그 묶음 하나를 표로 */
function table(tags) {
  const lines = ["| 태그 | 파일 | 무엇 |", "|---|---|---|"];
  for (const tag of tags) {
    const list = hits.get(tag);
    list.forEach((x, i) => {
      // 같은 태그를 여러 파일이 달면 태그 칸은 첫 줄에만 적는다
      lines.push(`| ${i === 0 ? "`" + tag + "`" : ""} | \`${x.file}\` | ${x.note} |`);
    });
  }
  return lines.join("\n");
}

const feFiles = fe.reduce((n, t) => n + hits.get(t).length, 0);
const beFiles = be.reduce((n, t) => n + hits.get(t).length, 0);

const doc = `# 5. PIPELINE 색인 — 태그에서 파일로

> 개발자: 박승우 · 일자: ${new Date().toISOString().slice(0, 10)}
> 소스의 \`PIPELINE[HFn]\` / \`PIPELINE[HBn]\` 주석에서 뽑았다.

코드에 태그를 달아 두고 여기서 파일을 찾는다.
「HF130 이 뭐였지」를 검색 없이 알 수 있게 하려는 표다.

**손으로 고치지 않는다.** 태그를 더하거나 파일을 옮긴 뒤 다시 뽑는다.

\`\`\`sh
node scripts/gen_pipeline_index.mjs           # 다시 만든다
node scripts/gen_pipeline_index.mjs --check   # 어긋나면 실패한다 (CI)
\`\`\`

**태그 하나를 여러 파일이 달 수 있다.** 같은 층에 있는 형제들이다 —
표는 그 전부를 싣는다. 태그 칸이 빈 줄은 바로 위 태그에 딸린 파일이다.

업무가 어떤 순서로 흐르는지는 태그가 아니라 파이프라인 문서를 본다 —
[\`backend/haccp-api/PIPELINE.md\`](../backend/haccp-api/PIPELINE.md) ·
[\`frontend/haccp-web/PIPELINE.md\`](../frontend/haccp-web/PIPELINE.md).

## 프론트 (HF) — 태그 ${fe.length}개 · 파일 ${feFiles}곳

${table(fe)}

## 백엔드 (HB) — 태그 ${be.length}개 · 파일 ${beFiles}곳

${table(be)}
`;

if (process.argv.includes("--check")) {
  const now = fs.existsSync(OUT) ? fs.readFileSync(OUT, "utf-8") : "";
  // 날짜 줄만 다른 것은 어긋남으로 보지 않는다
  // 날짜 줄과 줄바꿈(CRLF/LF)은 어긋남으로 보지 않는다 —
  // git 이 Windows 체크아웃에서 LF 를 CRLF 로 바꾼다. 내용이 같으면 통과다
  const strip = (t) =>
    t.replace(/일자: \d{4}-\d{2}-\d{2}/, "일자: -").replace(/\r\n/g, "\n");
  if (strip(now) !== strip(doc)) {
    console.error("PIPELINE 색인이 소스와 어긋났다 — node scripts/gen_pipeline_index.mjs 로 다시 뽑아라");
    process.exit(1);
  }
  console.log("PIPELINE 색인 최신");
  process.exit(0);
}

fs.writeFileSync(OUT, doc, "utf-8");
console.log(`docs/5_PIPELINE_색인.md — HF ${fe.length}태그/${feFiles}파일 · HB ${be.length}태그/${beFiles}파일`);
