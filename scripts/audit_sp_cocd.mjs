/**
 * audit_sp_cocd — idx 만으로 읽거나 고치거나 지우는지 본다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-10
 * 코멘트:
 *   1) WHERE 에 idx·file_idx·doc_no·tmpl_cd 단건만 있고 co_cd 가 없으면 타사 행이 열린다
 *   2) 쓰기는 예외 없다. 조회는 마스터·플랫폼·배치 전사만 화이트리스트
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

/** 합법 전사·마스터 조회 — idx 누수와 다르다. 여기 없으면 FAIL 되어 스크립트를 끄게 된다 */
const SELECT_WHITELIST = new Set([
  "sp_tbl_company_r_000",
  "sp_tbl_screen_r_000",
  "sp_tbl_template_r_000",
  "sp_tbl_schedule_rule_active_r_000",
  "sp_hwp_template_management_r_000",
]);

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith(".xml")) out.push(p);
  }
  return out;
}

function hasCo(text) {
  // #{coCd} 앞의 # 는 단어 문자가 아니라 \\b 를 붙이면 매퍼가 전부 누락된다
  return /\bp_co_cd\b|\bco_cd\b|#\{coCd\b|#\{p_co_cd\b|#\{co_cd\b/.test(text);
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
  if (!/\b(p_idx|p_doc_idx|p_file_idx|p_doc_no|p_tmpl_cd)\b/.test(chunk)) continue;
  const stmts = chunk.split(/;/);
  for (const st of stmts) {
    if (!/\b(p_idx|p_doc_idx|p_file_idx|p_doc_no|p_tmpl_cd|v_doc|v_hdr|v_monitor_idx|v_hdr_idx)\b/.test(st)) continue;
    if (hasCo(st)) continue;
    if (!/\b(WHERE|USING)\b/i.test(st)) continue;
    const keyed =
      /\b(idx|doc_idx)\s*=\s*(p_idx|p_doc_idx)\b/i.test(st)
      || /\b(idx|file_idx)\s*=\s*p_file_idx\b/i.test(st)
      || /\bdoc_no\s*=\s*p_doc_no\b/i.test(st)
      || /\btmpl_cd\s*=\s*p_tmpl_cd\b/i.test(st);
    const isWrite = /\b(UPDATE|DELETE|INSERT)\b/i.test(st);
    const isSelect = /\bSELECT\b/i.test(st);
    if (isWrite) {
      hits.push({
        where: name,
        snippet: st.replace(/\s+/g, " ").trim().slice(0, 180),
      });
      continue;
    }
    if (isSelect && keyed && !SELECT_WHITELIST.has(name)) {
      hits.push({
        where: name,
        snippet: st.replace(/\s+/g, " ").trim().slice(0, 180),
      });
    }
  }
}

for (const f of walk(MAPPER_DIR)) {
  const text = fs.readFileSync(f, "utf-8");
  const rel = path.relative(MAPPER_DIR, f);
  for (const m of text.matchAll(/<(select|update|insert|delete)[\s\S]*?<\/(?:select|update|insert|delete)>/gi)) {
    const block = m[0];
    const tag = m[1].toLowerCase();
    const hasKey = /#\{idx|#\{docIdx|#\{p_idx|#\{p_doc_idx|#\{fileIdx|#\{p_file_idx|#\{docNo|#\{tmplCd/i.test(block);
    if (!hasKey || hasCo(block)) continue;
    const sp = block.match(/sp_[a-z0-9_]+/);
    if (tag === "select" && sp && SELECT_WHITELIST.has(sp[0])) continue;
    hits.push({
      where: rel,
      snippet: block.replace(/\s+/g, " ").trim().slice(0, 180),
    });
  }
}

if (hits.length) {
  console.error("co_cd 없는 조회·쓰기 " + hits.length + "건 — WHERE 에 AND co_cd = p_co_cd 를 넣거나 SELECT 화이트리스트를 확인해라");
  for (const h of hits) console.error("- " + h.where + " :: " + h.snippet);
  process.exit(1);
}
console.log("audit_sp_cocd: OK");
