/**
 * seed_test_db — 시험용 DB(sasshaccp_test)에 6본을 순서대로 넣는다. 로컬 전용.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) apply-all.sh 와 같은 순서로 돌린다 — 00 → 01 → 02 → 03 → 05 → 06
 *   2) psql 메타명령(\if·\set·\gset)은 머리말에만 있다. 여기서 psql 과 같은 규칙으로 치환한다
 *   3) 정본은 db_sasshaccp/*.sql 이다 — 이 파일은 그걸 읽어 돌릴 뿐 베끼지 않는다
 *
 * 쓰기
 *   node tools/seed_test_db.mjs                 sasshaccp_test 에 넣는다
 *   node tools/seed_test_db.mjs --db 다른이름     다른 DB 에 넣는다
 */
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(path.join(ROOT, "frontend/haccp-web/package.json"));
const pg = require("pg");

const argv = process.argv.slice(2);
const dbArg = argv.indexOf("--db");
const DB = dbArg >= 0 ? argv[dbArg + 1] : "sasshaccp_test";

if (DB === "sasshaccp") {
  console.error("운영 DB 이름이다 — 시험용 DB 에만 넣는다");
  process.exit(1);
}

function loadDotEnv() {
  const out = {};
  const file = path.join(ROOT, "backend", "haccp-api", ".env");
  for (const line of fs.readFileSync(file, "utf-8").split(/\r?\n/)) {
    const s = line.trim();
    if (!s || s.startsWith("#")) continue;
    const eq = s.indexOf("=");
    if (eq > 0) out[s.slice(0, eq).trim()] = s.slice(eq + 1).trim();
  }
  return out;
}

/** psql 변수를 같은 규칙으로 치환하고 메타명령 줄을 걷어낸다 */
function render(sql, vars) {
  return sql
    .split(/\r?\n/)
    .filter((l) => !/^\s*\\/.test(l))
    .filter((l) => !l.includes("\\gset"))
    .join("\n")
    .replace(/:'([a-z_]+)'/g, (_m, name) => {
      const v = vars[name];
      if (v == null) throw new Error(`시드 변수 ${name} 에 값이 없다`);
      return `'${String(v).replace(/'/g, "''")}'`;
    });
}

/** 표준 업체(0000) 기준 — 신규 업체는 06 이 따로 만든다 */
const VARS = {
  co_cd: "0000",
  co_nm: "데모식품",
  admin_id: "admin",
  admin_pw: "$2a$10$omCFk.XMhqOp5dAmMQ7Me.Rp9c0f87cCPZS3IRg1avF5PVWRzjw4O",
  src_co: "0000",
};

const FILES = [
  ["00_ddl.sql", null],
  ["01_sp.sql", null],
  ["02_seed.sql", null],
  ["03_code_seed.sql", VARS],
  ["05_form_seed.sql", VARS],
];

/*
 * 시드 6본은 표준 지면(tbl_check_item)까지만 깐다 — 회사 지면 버전(tbl_*_ver)은 안 만든다.
 * 그래서 갓 시드한 DB 는 작성 화면에 고를 양식이 없다. 운영에서는 사람이 양식 원본
 * 5화면에서 「행추가(표준 복사)」를 눌러 만든다. 시험용 DB 는 그 상태를 대신 만들어 준다.
 */
const EXTRA = path.join(ROOT, "tools", "seed_test_forms.sql");

const env = loadDotEnv();
const client = new pg.Client({
  host: env.DB_HOST,
  port: Number(env.DB_PORT || 5432),
  database: DB,
  user: env.DB_USERNAME,
  password: env.DB_PASSWORD,
  connectionTimeoutMillis: 15_000,
});

await client.connect();
console.log(`>>> ${env.DB_HOST}/${DB} 에 넣는다`);

// 스키마는 00_ddl 이 만든다 — 여기서 미리 만들면 CREATE SCHEMA 가 충돌한다

for (const [name, vars] of FILES) {
  const raw = fs.readFileSync(path.join(ROOT, "db_sasshaccp", name), "utf-8");
  const sql = vars ? render(raw, vars) : raw;
  process.stdout.write(`  ${name} ... `);
  try {
    await client.query(sql);
    console.log("ok");
  } catch (e) {
    console.log("실패");
    console.error(`  ${e.message}`);
    await client.end();
    process.exit(1);
  }
}

// 회사 지면 버전 — 화면에서 복사를 누른 것과 같은 SP 를 부른다
if (fs.existsSync(EXTRA)) {
  process.stdout.write("  seed_test_forms.sql ... ");
  await client.query(fs.readFileSync(EXTRA, "utf-8"));
  console.log("ok");
}

const { rows } = await client.query(`
  SELECT (SELECT count(*) FROM information_schema.tables
           WHERE table_schema='sasshaccp' AND table_type='BASE TABLE') AS 표,
         (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
           WHERE n.nspname='sasshaccp' AND p.proname LIKE 'sp\\_%') AS sp,
         (SELECT count(*) FROM sasshaccp.tbl_menu WHERE co_cd='0000') AS 메뉴,
         (SELECT count(*) FROM sasshaccp.tbl_code WHERE co_cd='0000') AS 코드,
         (SELECT count(*) FROM sasshaccp.tbl_tml_ccp_htg_ver WHERE co_cd='0000') AS 지면버전`);
const r = rows[0];
console.log(
  `>>> 표 ${r["표"]} · SP ${r.sp} · 메뉴 ${r["메뉴"]} · 코드 ${r["코드"]} · 지면버전 ${r["지면버전"]}`,
);
await client.end();
