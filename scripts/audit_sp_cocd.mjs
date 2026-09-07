/**
 * audit_sp_cocd — 쓰기 SP 가 idx 만으로 고치거나 지우는지 본다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) WHERE idx = p_idx 만 있으면 타사 행이 열린다. 규칙은 AND co_cd = p_co_cd
 *   2) 01_sp.sql 쓰기 문과 매퍼 XML 호출을 같이 본다
 *   3) 일탈이 있으면 1 로 끝난다. 고친 뒤 다시 돌린다
 *
 * 쓰기: node scripts/audit_sp_cocd.mjs
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SP_SQL = path.join(ROOT, "db_sasshaccp", "01_sp.sql");
const MAPPER_DIR = path.join(ROOT, "backend/haccp-api/src/main/resources/mapper");

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith(".xml")) out.push(p);
  }
  return out;
}

const sql = fs.readFileSync(SP_SQL, "utf-8");
const hits = [];

for (const m of sql.matchAll(
  /CREATE OR REPLACE (FUNCTION|PROCEDURE) sasshaccp\.(sp_[a-z0-9_]+)\s*\(/g,
)) {
  const name = m[2];
  const start = m.index;
  const next = sql.indexOf("CREATE OR REPLACE", start + 10);
  const chunk = sql.slice(start, next < 0 ? sql.length : next);
  if (!/\b(p_idx|p_doc_idx)\b/.test(chunk)) continue;
  if (!/\b(UPDATE|DELETE)\b/i.test(chunk)) continue;
  const stmts = chunk.split(/;/);
  for (const st of stmts) {
    if (!/\b(UPDATE|DELETE)\b/i.test(st)) continue;
    if (!/\b(p_idx|p_doc_idx|v_doc|v_hdr|v_monitor_idx|v_hdr_idx)\b/.test(st)) continue;
    if (/\bp_co_cd\b/.test(st)) continue;
    if (!/\b(WHERE|USING)\b/i.test(st)) continue;
    hits.push({
      where: name,
      snippet: st.replace(/\s+/g, " ").trim().slice(0, 180),
    });
  }
}

for (const f of walk(MAPPER_DIR)) {
  const text = fs.readFileSync(f, "utf-8");
  for (const m of text.matchAll(/<(update|insert|delete)[\s\S]*?<\/(?:update|insert|delete)>/gi)) {
    const block = m[0];
    if (!/sp_[a-z0-9_]+/.test(block)) continue;
    const hasIdx = /#\{idx|#\{docIdx|#\{p_idx|#\{p_doc_idx/i.test(block);
    const hasCo = /#\{coCd|#\{p_co_cd|#\{co_cd/i.test(block);
    if (hasIdx && !hasCo) {
      hits.push({
        where: path.relative(MAPPER_DIR, f),
        snippet: block.replace(/\s+/g, " ").trim().slice(0, 180),
      });
    }
  }
}

if (hits.length) {
  console.error("co_cd 없는 쓰기 " + hits.length + "건 — WHERE 에 AND co_cd = p_co_cd 를 넣어라");
  for (const h of hits) console.error("- " + h.where + " :: " + h.snippet);
  process.exit(1);
}
console.log("audit_sp_cocd: OK");
