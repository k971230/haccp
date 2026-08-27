/**
 * gen_sp_index — SP 가 어느 매퍼에서 불리고 어느 표를 건드리는지 docs/9_SP_색인.md 로 만든다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 정의는 db_sasshaccp/01_sp.sql, 호출은 backend 매퍼 XML 에서 읽는다 — DB 접속이 필요 없다
 *   2) 「이 화면을 고치면 어느 표가 움직이나」를 검색 없이 알게 하려는 표다
 *   3) 정의 없는 호출·아무도 안 부르는 정의를 같이 뽑는다 — 그게 깨진 자리다
 *
 * 쓰기
 *   node scripts/gen_sp_index.mjs           다시 만든다
 *   node scripts/gen_sp_index.mjs --check   어긋나면 1 로 끝난다 (CI 용)
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT = path.join(ROOT, "docs", "9_SP_색인.md");
const SP_SQL = "db_sasshaccp/01_sp.sql";
const MAPPER_DIR = "backend/haccp-api/src/main/resources/mapper";

/** 폴더 아래 파일을 전부 모은다 — 매퍼가 도메인별로 한 단 더 들어가 있다 */
function walk(dir, out = []) {
  for (const e of fs.readdirSync(path.join(ROOT, dir), { withFileTypes: true })) {
    const rel = `${dir}/${e.name}`;
    if (e.isDirectory()) walk(rel, out);
    else if (e.name.endsWith(".xml")) out.push(rel);
  }
  return out;
}

// ---------------------------------------------------------------- 정의 (01_sp.sql)
const sql = fs.readFileSync(path.join(ROOT, SP_SQL), "utf-8");
/** sp 이름 → { kind, tables } */
const defs = new Map();
/*
 * CREATE OR REPLACE FUNCTION|PROCEDURE sasshaccp.sp_xxx(...) ... AS $태그$ 본문 $태그$;
 *
 * 달러 인용부호 태그를 고정으로 보면 안 된다 — 이 파일은 `$$` 131본과 `$_$` 21본을 섞어 쓴다.
 * `$$` 로만 찾으면 `$_$` 본문이 안 닫혀서 다음 SP 를 통째로 삼키고,
 * 삼켜진 SP 는 「정의 없음」으로 잘못 잡힌다. 실제로 21본이 그렇게 사라졌다.
 * 그래서 여는 태그를 읽어서 같은 태그로 닫는다.
 */
for (const m of sql.matchAll(
  /CREATE OR REPLACE (FUNCTION|PROCEDURE) sasshaccp\.(sp_[a-z0-9_]+)\s*\([\s\S]*?\sAS\s+(\$[a-zA-Z_]*\$)/g,
)) {
  const [kind, name, tag] = [m[1], m[2], m[3]];
  const from = m.index;
  const close = sql.indexOf(tag, from + m[0].length);
  // 닫는 태그가 없을 때(= 파일이 잘렸다) 이 정의는 건너뛴다
  if (close < 0) continue;
  const body = sql.slice(from, close + tag.length);
  const tables = new Set();
  // 본문이 건드리는 업무 표 — 읽기(FROM·JOIN)와 쓰기(INSERT·UPDATE·DELETE)를 함께 센다
  for (const t of body.matchAll(/\b(?:FROM|JOIN|INTO|UPDATE)\s+(?:sasshaccp\.)?(tbl_[a-z0-9_]+)/gi)) {
    tables.add(t[1]);
  }
  // 같은 이름이 여러 번 정의될 때(= 인자만 다른 오버로드) 표를 합친다
  const prev = defs.get(name);
  if (prev) for (const t of tables) prev.tables.add(t);
  else defs.set(name, { kind: kind === "FUNCTION" ? "조회" : "쓰기", tables });
}

/*
 * SP 안에서 다른 SP 를 부르는 것 — 「아무도 안 부른다」 오탐을 막는다.
 *
 * 앞 글자를 조건으로 걸지 않는다. `:=` 뒤·`VALUES(` 안·인자 자리 등 형태가 제각각이라
 * 조건을 걸면 놓친다. 정의 줄과 `-- Name:` 주석만 걷어내고 이름이 남아 있는지만 본다.
 */
const sqlBody = sql
  .split("\n")
  .filter((ln) => !/^CREATE OR REPLACE (FUNCTION|PROCEDURE)/.test(ln) && !/^-- Name: sp_/.test(ln))
  .join("\n");
const innerCalls = new Set();
for (const m of sqlBody.matchAll(/(sp_[a-z0-9_]+)\s*\(/g)) innerCalls.add(m[1]);

// ---------------------------------------------------------------- 호출 (매퍼 XML)
/** sp 이름 → 매퍼 파일 목록 */
const calls = new Map();
for (const rel of walk(MAPPER_DIR)) {
  const text = fs.readFileSync(path.join(ROOT, rel), "utf-8");
  for (const m of text.matchAll(/\b(sp_[a-z0-9_]+)\s*\(/g)) {
    if (!calls.has(m[1])) calls.set(m[1], new Set());
    calls.get(m[1]).add(rel.replace(`${MAPPER_DIR}/`, ""));
  }
}

// ---------------------------------------------------------------- 정리
/** 매퍼 경로 첫 칸 = 도메인 (auth · docs/documents …) */
const domainOf = (files) => {
  const f = [...files][0] ?? "";
  const parts = f.split("/");
  return parts.length > 1 ? parts.slice(0, -1).join("/") : "(루트)";
};

const rows = [...calls.entries()]
  .map(([sp, files]) => ({
    domain: domainOf(files),
    sp,
    kind: defs.get(sp)?.kind ?? "**정의 없음**",
    mappers: [...files].sort().join("<br>"),
    tables: [...(defs.get(sp)?.tables ?? [])].sort().join("<br>") || "-",
  }))
  .sort((a, b) => a.domain.localeCompare(b.domain) || a.sp.localeCompare(b.sp));

const missing = rows.filter((r) => r.kind === "**정의 없음**").map((r) => r.sp);
const unused = [...defs.keys()]
  .filter((sp) => !calls.has(sp) && !innerCalls.has(sp))
  .sort();

const doc = `# 9. SP 색인 — 매퍼에서 표까지

> 개발자: 박승우 · 일자: ${new Date().toISOString().slice(0, 10)}
> \`${SP_SQL}\` 의 정의와 \`${MAPPER_DIR}\` 의 호출을 맞춰 뽑았다.

**「이 화면을 고치면 어느 표가 움직이나」를 검색 없이 알려는 표다.**
화면에서 출발할 때는 [\`3_화면_지도.md\`](3_화면_지도.md), 태그에서 출발할 때는
[\`5_PIPELINE_색인.md\`](5_PIPELINE_색인.md) 를 본다. 여기는 **매퍼에서 출발**한다.

**손으로 고치지 않는다.** SP 를 더하거나 매퍼를 옮긴 뒤 다시 뽑는다.

\`\`\`sh
node scripts/gen_sp_index.mjs           # 다시 만든다
node scripts/gen_sp_index.mjs --check   # 어긋나면 실패한다 (CI)
\`\`\`

표 칸은 SP 본문이 \`FROM\`·\`JOIN\`·\`INSERT INTO\`·\`UPDATE\` 로 건드리는 \`tbl_*\` 다.
읽기와 쓰기를 가리지 않는다 — **그 표를 고치면 이 SP 가 영향을 받는다**는 뜻이다.

## 어긋난 자리

${missing.length === 0
  ? "**정의 없는 호출 없음.** 매퍼가 부르는 SP 는 전부 `01_sp.sql` 에 있다."
  : `**정의 없는 호출 ${missing.length}건 — 기동하면 터진다.**\n\n${missing.map((s) => `- \`${s}\``).join("\n")}`}

${unused.length === 0
  ? "**아무도 안 부르는 SP 없음.**"
  : `**아무도 안 부르는 SP ${unused.length}본.** 매퍼도 다른 SP 도 안 부른다 —
지운 화면의 잔재이거나, 시드·배치가 직접 부르는 것이다. 지우기 전에 \`grep\` 로 확인한다.

${unused.map((s) => `- \`${s}\``).join("\n")}`}

## 매퍼 → SP → 표 (${rows.length}건)

| 도메인 | SP | 종류 | 매퍼 | 건드리는 표 |
|---|---|---|---|---|
${rows.map((r) => `| ${r.domain} | \`${r.sp}\` | ${r.kind} | \`${r.mappers}\` | \`${r.tables}\` |`).join("\n")}

## 관련

- 화면에서 출발: [\`3_화면_지도.md\`](3_화면_지도.md)
- 태그에서 출발: [\`5_PIPELINE_색인.md\`](5_PIPELINE_색인.md)
- SP 규약: [\`../db_sasshaccp/README.md\`](../db_sasshaccp/README.md)
`;

if (process.argv.includes("--check")) {
  const now = fs.existsSync(OUT) ? fs.readFileSync(OUT, "utf-8") : "";
  // 날짜 줄과 줄바꿈은 어긋남으로 보지 않는다 — git 이 Windows 에서 LF 를 CRLF 로 바꾼다
  const strip = (t) => t.replace(/일자: \d{4}-\d{2}-\d{2}/, "일자: -").replace(/\r\n/g, "\n");
  if (strip(now) !== strip(doc)) {
    console.error("SP 색인이 소스와 어긋났다 — node scripts/gen_sp_index.mjs 로 다시 뽑아라");
    process.exit(1);
  }
  console.log("SP 색인 최신");
  process.exit(0);
}

fs.writeFileSync(OUT, doc, "utf-8");
console.log(`docs/9_SP_색인.md — 호출 ${rows.length}건 · 정의 없음 ${missing.length} · 미사용 ${unused.length}`);
