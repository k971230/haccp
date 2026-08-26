/**
 * q.mjs — SQL 한 덩어리를 실행하고 결과를 표로 찍는다. 로컬 전용, git 미포함.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) Q.java 를 대신한다 — 질의 하나에 JVM 을 띄우던 것이 원격 DB 에서 1.9초씩 붙었고,
 *      execFileSync 가 물리면 Node 이벤트 루프째 막혀 Playwright 타임아웃도 못 살렸다
 *   2) 출력 형식은 Q.java 와 같다 — 헤더 / 구분선 / 값 / "(n rows)". helpers 파싱을 안 고친다
 *   3) 접속·질의에 각각 타임아웃을 준다. 멈추지 않고 실패해야 원인이 보인다
 *
 * 쓰기
 *   node tools/q.mjs "SELECT 1"
 *   node tools/q.mjs @경로.sql
 */
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
/*
 * pg 는 프론트 node_modules 에 있다. tools/ 는 git 미포함이라 자기 package.json 이 없고,
 * ESM 은 NODE_PATH 를 안 본다 — 그래서 경로를 박아 require 로 가져온다.
 */
const require = createRequire(path.join(ROOT, "frontend/haccp-web/package.json"));
const pg = require("pg");

/** backend/.env 를 읽는다 — DB 접속의 유일한 출처 */
function loadDotEnv() {
  const out = {};
  const file = path.join(ROOT, "backend", "haccp-api", ".env");
  for (const line of fs.readFileSync(file, "utf-8").split(/\r?\n/)) {
    const s = line.trim();
    if (!s || s.startsWith("#")) continue;
    const eq = s.indexOf("=");
    if (eq <= 0) continue;
    out[s.slice(0, eq).trim()] = s.slice(eq + 1).trim();
  }
  return out;
}

/*
 * --db 이름 을 앞에 주면 그 DB 를 본다. 없으면 .env 의 DB_NAME.
 * 시험용 DB(sasshaccp_test)와 운영을 견줄 때 쓴다.
 */
const argv = process.argv.slice(2);
let dbOverride = null;
const at = argv.indexOf("--db");
if (at >= 0) {
  dbOverride = argv[at + 1];
  argv.splice(at, 2);
}
const arg = argv.join(" ");
const sql = arg.startsWith("@")
  ? fs.readFileSync(arg.slice(1), "utf-8")
  : arg;

const env = loadDotEnv();
const client = new pg.Client({
  host: env.DB_HOST,
  port: Number(env.DB_PORT || 5432),
  database: dbOverride || env.DB_NAME || "sasshaccp",
  user: env.DB_USERNAME,
  password: env.DB_PASSWORD,
  options: "-c search_path=sasshaccp",
  // 멈추지 않고 실패한다 — 물린 채 서 있으면 원인을 못 본다
  connectionTimeoutMillis: 15_000,
  query_timeout: 45_000,
  statement_timeout: 45_000,
});

/** Q.java 와 같은 형식으로 찍는다 — helpers 의 파싱을 그대로 쓴다 */
function print(res) {
  const cols = (res.fields || []).map((f) => f.name);
  if (cols.length === 0) {
    console.log(`(${res.rowCount ?? 0} rows affected)`);
    return;
  }
  const head = cols.join(" | ");
  console.log(head);
  console.log("-".repeat(Math.min(head.length, 200)));
  for (const row of res.rows) {
    console.log(
      cols
        .map((c) => {
          const v = row[c];
          if (v == null) return "null";
          const s = typeof v === "object" ? JSON.stringify(v) : String(v);
          return s.length > 90 ? s.slice(0, 90) + "..." : s;
        })
        .join(" | "),
    );
  }
  console.log(`(${res.rows.length} rows)`);
}

try {
  await client.connect();
  const res = await client.query(sql);
  // 여러 문장을 한 번에 보내면 배열로 돌아온다
  for (const r of Array.isArray(res) ? res : [res]) print(r);
} catch (e) {
  console.error(String(e && e.message ? e.message : e));
  process.exitCode = 1;
} finally {
  // 반드시 끊는다 — 안 끊으면 서버에 idle 세션이 쌓인다 (Q.java 가 그랬다)
  await client.end().catch(() => undefined);
}
