/**
 * gen_table_layout — 00_ddl.sql 에서 테이블 레이아웃 문서를 만든다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-10
 * 코멘트:
 *   1) 표 정의·주석·제약·인덱스를 DDL 정본 한 곳에서만 읽는다 — 주석은 하단 마커 블록
 *      DB 접속이 필요 없다. 표·컬럼 주석이 비면 --check 가 실패한다
 *   2) 두 벌을 낸다: git 이 검토하는 마크다운, 사람이 여는 스프레드시트
 *   3) 표가 하나 늘면 다시 돌린다. 손으로 표를 고치지 않는다
 *   4) 표제 0.1 · 한글명 · 실제 FK · 스냅샷/앱상수 분석 시트를 같이 낸다
 *
 * 스프레드시트는 SpreadsheetML 2003 (XML) 이다. 라이브러리를 안 쓰려고 고른 형식이고
 * Excel·LibreOffice 가 그대로 연다. 시트 이름은 31자 제한이라 표 이름을 잘라 쓴다.
 *
 * 쓰기
 *   node scripts/gen_table_layout.mjs           다시 만든다
 *   node scripts/gen_table_layout.mjs --check   어긋나면 1 로 끝난다 (CI 용)
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DDL = "db_sasshaccp/00_ddl.sql";
const ALTER = "db_sasshaccp/00_alter.sql";
const OUT_MD = path.join(ROOT, "docs", "10_테이블_레이아웃.md");
const OUT_XLS = path.join(ROOT, "docs", "10_테이블_레이아웃.xls");
const TITLE = "sasshaccp 테이블레이아웃";
const VER = "0.1";
const AUTHOR = "박승우";
const DOC_DATE = "2026-09-10";
const sql = fs.readFileSync(path.join(ROOT, DDL), "utf-8");
const alterSql = fs.readFileSync(path.join(ROOT, ALTER), "utf-8");

/** 스냅샷 — 원본이 없어도 이력이 남아야 해서 CONSTRAINT 를 안 건다 */
const SNAPSHOT = [
  ["tbl_document", "writer_id", "작성자 스냅샷"],
  ["tbl_document", "approver_id", "결재자 스냅샷"],
  ["tbl_document_approval", "approver_id", "결재란 스냅샷"],
  ["tbl_hyg_process", "checker_id", "점검자 스냅샷"],
  ["tbl_hyg_process", "approver_id", "결재자 스냅샷"],
  ["tbl_hyg_process", "confirm_id", "확인자 스냅샷"],
  ["tbl_ccp_verify_check", "checker_id", "점검자 스냅샷"],
  ["tbl_ccp_verify_check", "approver_id", "결재자 스냅샷"],
  ["tbl_ccp_verify_check", "confirm_id", "확인자 스냅샷"],
  ["tbl_approval_line_step", "approver_id", "결재선 지정 스냅샷"],
  ["tbl_audit_log", "user_id", "행위자 이력"],
  ["tbl_audit_log", "tgt_idx", "대상 행 포인터(다형)"],
  ["tbl_login_log", "user_id", "로그인 이력"],
  ["tbl_view_log", "user_id", "조회 이력"],
  ["tbl_corrective_action", "src_doc_idx", "원문서 — DONE 조치는 원문이 없어도 남긴다"],
  ["tbl_corrective_action", "src_row_idx", "원행 포인터"],
  ["tbl_corrective_action", "action_user_id", "조치자 스냅샷"],
  ["tbl_corrective_action", "confirm_user_id", "확인자 스냅샷"],
];
/** 앱상수 — 부모 표를 만들지 않는다 */
const APP_CONST = [
  ["tbl_ccp_pkg_monitor_cell", "item_cd", "PkgLogCells 필드명 temp/min/sec"],
  ["tbl_ccp_htg_monitor_cell", "item_cd", "HtgLogCells 필드명 temp/time"],
];

/*
 * 분류 — 「기초코드 → 기초문서 → 업무 → 로그·통계」 순으로 읽는다.
 * 표를 여기 안 적으면 「미분류」로 떨어진다. 조용히 섞이는 것보다 눈에 띄는 편이 낫다.
 */
const GROUPS = [
  {
    key: "기초코드",
    desc: "회사·사람·권한·코드. 업무가 시작되기 전에 있어야 하는 값이다",
    tables: [
      "tbl_company", "tbl_dept", "tbl_user", "tbl_role", "tbl_role_screen",
      "tbl_screen", "tbl_menu", "tbl_code", "tbl_approval_line", "tbl_approval_line_step",
      "tbl_doc_no_rule", "tbl_grid_pref", "tbl_user_noti_pref",
    ],
  },
  {
    key: "기초문서",
    desc: "양식이 무엇이고 어떤 항목을 갖는가. 기록을 담는 그릇의 정의다",
    tables: [
      "tbl_template", "tbl_company_template", "tbl_company_template_file", "tbl_check_item",
      "tbl_html_form_ver", "tbl_html_form_ver_item",
      "tbl_html_hyg_prc_ver", "tbl_html_hyg_prc_ver_item",
      "tbl_html_ccp_chk_ver", "tbl_html_ccp_chk_ver_item",
      "tbl_html_ccp_pkg_ver", "tbl_html_ccp_pkg_ver_item",
      "tbl_html_ccp_htg_ver", "tbl_html_ccp_htg_ver_item",
      "tbl_html_ccp_mtl_ver", "tbl_html_ccp_mtl_ver_item",
      "tbl_schedule_rule", "tbl_schedule_rule_detail",
    ],
  },
  {
    key: "업무",
    desc: "현장이 실제로 쓰는 기록과 그 결재. 법정 서류가 여기 쌓인다",
    tables: [
      "tbl_document", "tbl_document_approval", "tbl_document_file",
      "tbl_document_version",
      "tbl_hyg_process", "tbl_hyg_process_item",
      "tbl_ccp_verify_check", "tbl_ccp_verify_item",
      "tbl_ccp_pkg_monitor", "tbl_ccp_pkg_monitor_row", "tbl_ccp_pkg_monitor_cell",
      "tbl_ccp_htg_monitor", "tbl_ccp_htg_monitor_row", "tbl_ccp_htg_monitor_cell",
      "tbl_ccp_metal_monitor", "tbl_ccp_metal_sens_row", "tbl_ccp_metal_pass_row",
      "tbl_corrective_action", "tbl_schedule_task", "tbl_workday_override",
    ],
  },
  {
    key: "로그·통계",
    desc: "누가 언제 무엇을 했는가. 업무를 만들지 않고 뒤에서 쌓인다",
    tables: ["tbl_login_log", "tbl_view_log", "tbl_view_stat_daily", "tbl_audit_log", "tbl_notification"],
  },
];

// ---------------------------------------------------------------- 파싱
// 표 이름 → { cols, comment, pk, uniques, indexes }
const tables = new Map();

for (const m of sql.matchAll(/CREATE TABLE sasshaccp\.([a-z0-9_]+) \(\r?\n([\s\S]*?)\r?\n\);/g)) {
  const cols = [];
  const pk = [];
  const uniques = [];
  const checks = [];
  for (const raw of m[2].split("\n")) {
    const line = raw.trim().replace(/,$/, "");
    const uq = line.match(/^CONSTRAINT ([a-z0-9_]+) UNIQUE \(([^)]+)\)/i);
    if (uq) {
      uniques.push({ name: uq[1], cols: uq[2].split(",").map((x) => x.trim()) });
      continue;
    }
    const ck = line.match(/^CONSTRAINT ([a-z0-9_]+) CHECK \((.+)\)$/i);
    if (ck) {
      checks.push({ name: ck[1], expr: ck[2].replace(/\s+/g, " ") });
      continue;
    }
    // 제약 줄은 컬럼이 아니다
    if (/^(CONSTRAINT|PRIMARY|UNIQUE|CHECK|FOREIGN)\b/i.test(line)) continue;
    const c = line.match(/^([a-z0-9_]+)\s+(.+)$/);
    if (!c) continue;
    const rest = c[2];
    const def = rest.match(/DEFAULT\s+(.+?)(?:\s+(?:NOT NULL|PRIMARY KEY|GENERATED)\b|$)/);
    cols.push({
      name: c[1],
      type: rest
        .replace(/\s*DEFAULT[\s\S]*$/, "")
        .replace(/\s*NOT NULL\s*$/, "")
        .replace(/\s*GENERATED ALWAYS AS IDENTITY\s*/i, "")
        .replace(/\s*PRIMARY KEY\s*/i, "")
        .trim(),
      notNull: /\bNOT NULL\b/.test(rest) || /\bPRIMARY KEY\b/i.test(rest),
      def: def ? def[1].trim() : "",
      comment: "",
    });
    if (/\bPRIMARY KEY\b/i.test(rest)) pk.push(c[1]);
  }
  tables.set(m[1], { cols, comment: "", pk, uniques, indexes: [], checks, fks: [] });
}

for (const m of sql.matchAll(/COMMENT ON TABLE sasshaccp\.([a-z0-9_]+) IS '([\s\S]*?)';/g)) {
  const t = tables.get(m[1]);
  if (t) t.comment = m[2].replace(/''/g, "'");
}
for (const m of sql.matchAll(/COMMENT ON COLUMN sasshaccp\.([a-z0-9_]+)\.([a-z0-9_]+) IS '([\s\S]*?)';/g)) {
  const col = tables.get(m[1])?.cols.find((c) => c.name === m[2]);
  if (col) col.comment = m[3].replace(/''/g, "'");
}

for (const m of sql.matchAll(
  /ALTER TABLE (?:ONLY )?sasshaccp\.([a-z0-9_]+)\s*\n?\s*ADD CONSTRAINT ([a-z0-9_]+) (PRIMARY KEY|UNIQUE) \(([^)]*)\)/g,
)) {
  const t = tables.get(m[1]);
  if (!t) continue;
  const cols = m[4].split(",").map((x) => x.trim());
  if (m[3] === "PRIMARY KEY") t.pk = cols;
  else if (!t.uniques.some((u) => u.name === m[2])) t.uniques.push({ name: m[2], cols });
}

for (const src of [sql, alterSql]) {
  for (const m of src.matchAll(
    /ALTER TABLE sasshaccp\.([a-z0-9_]+)\s*\n?\s*ADD CONSTRAINT (fk_[a-z0-9_]+) FOREIGN KEY \(([^)]+)\)\s*\n?\s*REFERENCES sasshaccp\.([a-z0-9_]+)\(([^)]+)\)/g,
  )) {
    const t = tables.get(m[1]);
    if (!t) continue;
    if (t.fks.some((f) => f.name === m[2])) continue;
    t.fks.push({
      name: m[2],
      cols: m[3].replace(/\s+/g, ""),
      ref: m[4],
      refCols: m[5].replace(/\s+/g, ""),
    });
  }
}

for (const m of alterSql.matchAll(/\['(tbl_[a-z0-9_]+)','([a-z0-9_]+)'\]/g)) {
  const t = tables.get(m[1]);
  if (!t) continue;
  const name = "ck_" + m[1] + "_" + m[2];
  if (!t.checks.some((c) => c.name === name)) {
    t.checks.push({ name, expr: m[2] + " IN ('Y','N')" });
  }
}

for (const m of sql.matchAll(
  /CREATE (UNIQUE )?INDEX ([a-z0-9_]+) ON sasshaccp\.([a-z0-9_]+) USING \w+ \(([^)]*)\)([^;]*);/g,
)) {
  const t = tables.get(m[3]);
  if (!t) continue;
  t.indexes.push({
    name: m[2],
    unique: !!m[1],
    cols: m[4].replace(/\s+/g, " ").trim(),
    // 부분 인덱스 조건 — 없으면 빈 문자열
    where: (m[5].match(/WHERE\s*\(([\s\S]*)\)/) || [, ""])[1].replace(/\s+/g, " ").trim(),
  });
}

// ---------------------------------------------------------------- 순서
const ordered = [];
const seen = new Set();
for (const g of GROUPS) {
  for (const name of g.tables) {
    if (!tables.has(name)) continue;
    ordered.push({ group: g.key, name, ...tables.get(name) });
    seen.add(name);
  }
}
// 분류에 안 적힌 표 — 뒤에 「미분류」로 붙인다. 조용히 빠지면 아무도 모른다
const missing = [...tables.keys()].filter((n) => !seen.has(n)).sort();
for (const name of missing) ordered.push({ group: "미분류", name, ...tables.get(name) });

const today = DOC_DATE;
const colCount = ordered.reduce((a, t) => a + t.cols.length, 0);
const GROUP_KEYS = [...GROUPS.map((x) => x.key), "미분류"];
const fkCount = ordered.reduce((a, t) => a + t.fks.length, 0);

function hangulOf(c) {
  if (c.name === "idx") return "대리키";
  const i = c.comment.indexOf(" — ");
  return i >= 0 ? c.comment.slice(0, i) : (c.comment || c.name);
}

/** 표의 삭제 의미 — del_yn / use_yn / 물리 DELETE. 컬럼명만 보면 tbl_document 가 거짓이 된다 */
function deleteSemanticsOf(t) {
  if (t.name === "tbl_document") {
    return { kind: "물리 DELETE(WRK·RJT)", recover: "불가 — 전송·결재완료는 차단. del_yn은 목록 숨김" };
  }
  const names = t.cols.map((c) => c.name);
  if (names.includes("del_yn")) return { kind: "del_yn", recover: "가능 — del_yn=N" };
  if (names.includes("use_yn")) return { kind: "use_yn", recover: "가능 — use_yn=Y" };
  return { kind: "물리 DELETE", recover: "불가 — 백업·감사 로그" };
}

/**
 * 삭제 차단 SP → 대상 표.
 * 본문에 나온 참조 표가 아니라 이름에서 고른다 — 부서 차단이 tbl_user 에 붙으면 틀린다.
 */
function loadDeleteBlockers() {
  const spSql = fs.readFileSync(path.join(ROOT, "db_sasshaccp/01_sp.sql"), "utf-8");
  const screenToTable = {
    common_code_management: "tbl_code",
    department_management: "tbl_dept",
    menu_management: "tbl_menu",
    role_management: "tbl_role",
    user_management: "tbl_user",
    schedule_cycle_management: "tbl_schedule_rule",
  };
  const map = new Map();
  for (const m of spSql.matchAll(/\b(sp_[a-z0-9_]*delete_blocker[a-z0-9_]*)\b/g)) {
    const name = m[1];
    const tbl = name.match(/^sp_(tbl_[a-z0-9_]+)_delete_blocker/);
    if (tbl) {
      map.set(tbl[1], name);
      continue;
    }
    const scr = name.match(/^sp_([a-z0-9_]+)_delete_blocker/);
    if (scr && screenToTable[scr[1]]) map.set(screenToTable[scr[1]], name);
  }
  return map;
}

// 설명 — 컬럼이 기본키·유일키에 들어가는지
function markOf(t, col) {
  const m = [];
  if (t.pk.includes(col.name)) m.push("PK");
  if (t.uniques.some((u) => u.cols.includes(col.name))) m.push("UQ");
  if (t.fks.some((f) => f.cols.split(",").includes(col.name))) m.push("FK");
  return m.join("·");
}

// ---------------------------------------------------------------- 마크다운
const md = [];
md.push("# 10. 테이블 레이아웃");
md.push("");
md.push("> " + TITLE + " · 버전 " + VER + " · 작성자 " + AUTHOR + " · 작성일자 " + today);
md.push("> `" + DDL + "` 에서 뽑았다. **손으로 고치지 않는다.**");
md.push("");
md.push("표 **" + ordered.length + "개** · 컬럼 **" + colCount + "개** · FK **" + fkCount + "개**");
md.push("");
md.push("```sh");
md.push("node scripts/gen_table_layout.mjs           # 다시 만든다");
md.push("node scripts/gen_table_layout.mjs --check   # 어긋나면 실패한다 (CI)");
md.push("```");
md.push("");
md.push("엑셀본은 이 파일을 뽑을 때 `10_테이블_레이아웃.xls` 로 같이 나온다 —");
md.push("첫 시트가 표제, 둘째가 목차, 셋째부터 표 하나에 시트 하나다.");
md.push("");
md.push("**`.xls` 는 git 에 안 올린다** (`.gitignore` 가 `docs/` 에서 번호 붙은 `.md` 만 추적한다).");
md.push("필요하면 위 명령으로 그때 뽑는다 — 내용은 이 문서와 같다.");
md.push("");
md.push("## 목차");
md.push("");
let seqToc = 0;
for (const g of GROUP_KEYS) {
  const rows = ordered.filter((t) => t.group === g);
  if (rows.length === 0) continue;
  const desc = GROUPS.find((x) => x.key === g)?.desc ?? "분류에 안 적힌 표 — 생성기 GROUPS 에 넣는다";
  md.push("### " + g + " (" + rows.length + ")");
  md.push("");
  md.push(desc);
  md.push("");
  md.push("| 분류 | # | 테이블명 | 테이블설명 | 컬럼 | 컬럼수 |");
  md.push("|---|---:|---|---|---|---:|");
  rows.forEach((t) => {
    seqToc += 1;
    md.push("| " + g + " | " + seqToc + " | `" + t.name + "` | " + (t.comment || "-")
      + " | " + t.cols.map((c) => c.name).join(", ") + " | " + t.cols.length + " |");
  });
  md.push("");
}
md.push("---");
md.push("");
md.push("## 삭제 의미");
md.push("");
md.push("전면 `del_yn` 전환은 하지 않는다. 새 표는 이 표에 한 줄 없이 못 넣는다.");
md.push("");
md.push("| 표 | 삭제 의미 | 차단 SP | 복구 |");
md.push("|---|---|---|---|");
const blockerByTable = loadDeleteBlockers();
for (const t of ordered) {
  const del = deleteSemanticsOf(t);
  const blocker = blockerByTable.get(t.name) || "-";
  md.push("| `" + t.name + "` | " + del.kind + " | " + (blocker === "-" ? "-" : "`" + blocker + "`") + " | " + del.recover + " |");
}
md.push("");
md.push("---");
md.push("");
for (const t of ordered) {
  md.push("## " + t.name);
  md.push("");
  md.push("**" + t.group + "** — " + (t.comment || "(표 주석 없음)"));
  md.push("");
  md.push("| # | 컬럼 | 컬럼명 | 타입 | not null | 기본값 | 키 | 설명 |");
  md.push("|---:|---|---|---|:-:|---|:-:|---|");
  t.cols.forEach((c, i) => {
    md.push("| " + (i + 1) + " | `" + c.name + "` | " + hangulOf(c) + " | " + c.type
      + " | " + (c.notNull ? "N" : "Y") + " | " + (c.def ? "`" + c.def + "`" : "")
      + " | " + markOf(t, c) + " | " + (c.comment || "") + " |");
  });
  md.push("");
  if (t.pk.length) md.push("- 기본키: `" + t.pk.join(", ") + "`");
  for (const u of t.uniques) md.push("- 유일키 `" + u.name + "`: `" + u.cols.join(", ") + "`");
  for (const f of t.fks) md.push("- 포린키 `" + f.name + "`: `" + f.cols + "` → `" + f.ref + "(" + f.refCols + ")`");
  for (const ck of t.checks) md.push("- CHECK `" + ck.name + "`: `" + ck.expr + "`");
  for (const ix of t.indexes) {
    md.push("- 인덱스 `" + ix.name + "`" + (ix.unique ? " (유일)" : "") + ": `" + ix.cols + "`"
      + (ix.where ? " — 조건 `" + ix.where + "`" : ""));
  }
  md.push("");
}
md.push("## FK 분석");
md.push("");
md.push("CONSTRAINT 가 있으면 `FK`. 없으면 사유가 `스냅샷` 또는 `앱상수` 여야 한다.");
md.push("");
md.push("| 구분 | 표 | 컬럼 | 대상·사유 |");
md.push("|---|---|---|---|");
for (const t of ordered) {
  for (const f of t.fks) {
    md.push("| FK | `" + t.name + "` | `" + f.cols + "` | `" + f.ref + "(" + f.refCols + ")` |");
  }
}
for (const [tbl, col, why] of SNAPSHOT) {
  md.push("| 스냅샷 | `" + tbl + "` | `" + col + "` | " + why + " |");
}
for (const [tbl, col, why] of APP_CONST) {
  md.push("| 앱상수 | `" + tbl + "` | `" + col + "` | " + why + " |");
}
md.push("");
md.push("## 관련");
md.push("");
md.push("- SP → 표: [`9_SP_색인.md`](9_SP_색인.md)");
md.push("- 이름·값의 모양: [`4_명명과_경로.md`](4_명명과_경로.md)");
md.push("- DB 규칙: [`../db_sasshaccp/README.md`](../db_sasshaccp/README.md)");
const mdDoc = md.join("\n") + "\n";

// ---------------------------------------------------------------- 스프레드시트
// 설명 — XML 특수문자 escape. 컬럼 설명에 < > & 가 들어와도 파일이 안 깨진다
const esc = (s) => String(s ?? "")
  .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const cell = (v, style) =>
  "<Cell" + (style ? " ss:StyleID=\"" + style + "\"" : "") + "><Data ss:Type=\"String\">" + esc(v) + "</Data></Cell>";
const row = (cells) => "<Row>" + cells + "</Row>";

// 시트 이름은 31자 제한이고 중복이면 파일이 안 열린다
const sheetNames = new Set();
function sheetName(base) {
  let n = base.slice(0, 31);
  let i = 2;
  while (sheetNames.has(n)) {
    n = base.slice(0, 28) + "~" + i;
    i += 1;
  }
  sheetNames.add(n);
  return n;
}

const sheets = [];
// 시트 1 — 표제
sheets.push("<Worksheet ss:Name=\"" + sheetName("표제") + "\"><Table>"
  + "<Column ss:Width=\"120\"/><Column ss:Width=\"430\"/>"
  + row(cell(TITLE, "title"))
  + row(cell(""))
  + row(cell("버전", "head") + cell(VER))
  + row(cell("작성자", "head") + cell(AUTHOR))
  + row(cell("작성일자", "head") + cell(today))
  + row(cell("스키마", "head") + cell("sasshaccp"))
  + row(cell("정본", "head") + cell(DDL))
  + row(cell("표 수", "head") + cell(String(ordered.length)))
  + row(cell("컬럼 수", "head") + cell(String(colCount)))
  + row(cell("FK 수", "head") + cell(String(fkCount)))
  + row(cell("뽑은 날", "head") + cell(today))
  + row(cell(""))
  + row(cell("시트 순서", "head") + cell("표제 · 목차 · 표 · FK분석"))
  + row(cell(""))
  + row(cell("이 파일은 생성물이다. 손으로 고치면 다음 생성에 지워진다.", "note"))
  + row(cell("node scripts/gen_table_layout.mjs 로 다시 뽑는다.", "note"))
  + "</Table></Worksheet>");

// 시트 2 — 목차
const tocRows = [row(cell("분류", "head") + cell("#", "head") + cell("테이블명", "head")
  + cell("테이블설명", "head") + cell("컬럼", "head") + cell("컬럼수", "head"))];
let seq = 0;
for (const g of GROUP_KEYS) {
  const rows = ordered.filter((t) => t.group === g);
  if (!rows.length) continue;
  for (const t of rows) {
    seq += 1;
    tocRows.push(row(cell(g) + cell(String(seq)) + cell(t.name) + cell(t.comment)
      + cell(t.cols.map((c) => c.name).join(", ")) + cell(String(t.cols.length))));
  }
}
sheets.push("<Worksheet ss:Name=\"" + sheetName("목차") + "\"><Table>"
  + "<Column ss:Width=\"70\"/><Column ss:Width=\"30\"/><Column ss:Width=\"210\"/>"
  + "<Column ss:Width=\"320\"/><Column ss:Width=\"360\"/><Column ss:Width=\"45\"/>"
  + tocRows.join("") + "</Table></Worksheet>");

// 시트 3+ — 표 하나에 시트 하나
for (const t of ordered) {
  const rows = [
    row(cell(t.name, "title")),
    row(cell(t.group, "group") + cell(t.comment)),
    row(cell("")),
    row(cell("#", "head") + cell("컬럼", "head") + cell("컬럼명", "head") + cell("타입", "head")
      + cell("not null", "head") + cell("기본값", "head") + cell("키", "head") + cell("설명", "head")),
  ];
  t.cols.forEach((c, i) => {
    rows.push(row(cell(String(i + 1)) + cell(c.name) + cell(hangulOf(c)) + cell(c.type)
      + cell(c.notNull ? "N" : "Y") + cell(c.def) + cell(markOf(t, c)) + cell(c.comment)));
  });
  rows.push(row(cell("")));
  if (t.pk.length) rows.push(row(cell("기본키", "head") + cell(t.pk.join(", "))));
  for (const u of t.uniques) rows.push(row(cell("유일키", "head") + cell(u.name) + cell(u.cols.join(", "))));
  for (const f of t.fks) {
    rows.push(row(cell("포린키", "head") + cell(f.name) + cell(f.cols) + cell(f.ref + "(" + f.refCols + ")")));
  }
  for (const ck of t.checks) rows.push(row(cell("CHECK", "head") + cell(ck.name) + cell(ck.expr)));
  for (const ix of t.indexes) {
    rows.push(row(cell(ix.unique ? "인덱스(유일)" : "인덱스", "head") + cell(ix.name) + cell(ix.cols) + cell(ix.where)));
  }
  sheets.push("<Worksheet ss:Name=\"" + sheetName(t.name) + "\"><Table>"
    + "<Column ss:Width=\"30\"/><Column ss:Width=\"160\"/><Column ss:Width=\"140\"/><Column ss:Width=\"175\"/>"
    + "<Column ss:Width=\"50\"/><Column ss:Width=\"140\"/><Column ss:Width=\"40\"/><Column ss:Width=\"430\"/>"
    + rows.join("") + "</Table></Worksheet>");
}

const fkRows = [row(cell("구분", "head") + cell("표", "head") + cell("컬럼", "head") + cell("대상·사유", "head"))];
for (const t of ordered) {
  for (const f of t.fks) {
    fkRows.push(row(cell("FK") + cell(t.name) + cell(f.cols) + cell(f.ref + "(" + f.refCols + ")")));
  }
}
for (const [tbl, col, why] of SNAPSHOT) fkRows.push(row(cell("스냅샷") + cell(tbl) + cell(col) + cell(why)));
for (const [tbl, col, why] of APP_CONST) fkRows.push(row(cell("앱상수") + cell(tbl) + cell(col) + cell(why)));
sheets.push("<Worksheet ss:Name=\"" + sheetName("FK분석") + "\"><Table>"
  + "<Column ss:Width=\"60\"/><Column ss:Width=\"210\"/><Column ss:Width=\"160\"/><Column ss:Width=\"360\"/>"
  + fkRows.join("") + "</Table></Worksheet>");


const xls = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  + "<?mso-application progid=\"Excel.Sheet\"?>\n"
  + "<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\""
  + " xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\">\n"
  + "<Styles>\n"
  + " <Style ss:ID=\"Default\" ss:Name=\"Normal\"><Alignment ss:Vertical=\"Top\" ss:WrapText=\"1\"/>"
  + "<Font ss:FontName=\"맑은 고딕\" ss:Size=\"10\"/></Style>\n"
  + " <Style ss:ID=\"title\"><Font ss:FontName=\"맑은 고딕\" ss:Size=\"14\" ss:Bold=\"1\"/></Style>\n"
  + " <Style ss:ID=\"head\"><Font ss:FontName=\"맑은 고딕\" ss:Size=\"10\" ss:Bold=\"1\"/>"
  + "<Interior ss:Color=\"#E8EEF7\" ss:Pattern=\"Solid\"/></Style>\n"
  + " <Style ss:ID=\"group\"><Font ss:FontName=\"맑은 고딕\" ss:Size=\"10\" ss:Bold=\"1\" ss:Color=\"#1A3676\"/></Style>\n"
  + " <Style ss:ID=\"note\"><Font ss:FontName=\"맑은 고딕\" ss:Size=\"9\" ss:Color=\"#666666\"/></Style>\n"
  + "</Styles>\n"
  + sheets.join("\n") + "\n</Workbook>\n";

// ---------------------------------------------------------------- 출력
if (process.argv.includes("--check")) {
  const start = sql.search(/^-- START_COMMENT_BLOCK/m);
  const end = sql.search(/^-- END_COMMENT_BLOCK/m);
  if (start < 0 || end < 0 || end <= start) {
    console.error("00_ddl.sql 에 주석 블록 마커가 없다");
    process.exit(1);
  }
  if (/COMMENT ON /.test(sql.slice(0, start))) {
    console.error("00_ddl.sql 마커 밖에 COMMENT ON 이 있다");
    process.exit(1);
  }
  const noTable = ordered.filter((t) => !t.comment).map((t) => t.name);
  const noCol = [];
  for (const t of ordered) {
    for (const c of t.cols) {
      if (!c.comment) noCol.push(t.name + "." + c.name);
    }
  }
  if (noTable.length || noCol.length) {
    if (noTable.length) console.error("표 주석 없음: " + noTable.join(", "));
    if (noCol.length) console.error("컬럼 주석 없음 " + noCol.length + ": " + noCol.join(", "));
    process.exit(1);
  }
  const now = fs.existsSync(OUT_MD) ? fs.readFileSync(OUT_MD, "utf-8") : "";
  // 날짜 줄과 줄바꿈은 어긋남으로 보지 않는다 — git 이 Windows 에서 LF 를 CRLF 로 바꾼다
  const strip = (t) => t.replace(/일자: \d{4}-\d{2}-\d{2}/, "일자: -").replace(/\r\n/g, "\n");
  if (strip(now) !== strip(mdDoc)) {
    console.error("테이블 레이아웃이 DDL 과 어긋났다 — node scripts/gen_table_layout.mjs 로 다시 뽑아라");
    process.exit(1);
  }
  console.log("테이블 레이아웃 최신");
  process.exit(0);
}

fs.writeFileSync(OUT_MD, mdDoc, "utf-8");
try {
  // Excel 이 UTF-8 을 알아보게 BOM 을 붙인다. 파일이 열려 있으면 md 만 남긴다
  fs.writeFileSync(OUT_XLS, "﻿" + xls, "utf-8");
} catch (e) {
  if (e.code !== "EBUSY") throw e;
  console.warn("xls 가 열려 있어 md 만 갱신했다");
}
console.log("docs/10_테이블_레이아웃.md · .xls — 표 " + ordered.length + " · 시트 " + sheets.length
  + (missing.length ? " · 미분류 " + missing.length + "(" + missing.join(", ") + ")" : " · 미분류 없음"));
