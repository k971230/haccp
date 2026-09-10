#!/usr/bin/env bash
# ============================================================
#  HACCP SaaS — PostgreSQL 일괄 적용
#
#  개발자: 박승우
#  일자: 2026-09-10
#  코멘트:
#    1) 7본 시드 + 00_alter(항상) + 주석 블록. 구조 → 스키마 보정 → SP → 주석 → 플랫폼 기준 → 업체
#    2) 스키마 sasshaccp 가 있으면 00_ddl 을 건너뛴다. 00_alter 는 건너뛰지 않는다 —
#       꼬리 ALTER·새 표가 이미 깐 DB 에 안 가는 구멍을 막는다.
#       주석은 00_ddl 하단 마커 블록이 정본이다. 00_alter 다음에 그 블록만 다시 덮는다.
#       00_ddl 을 IF NOT EXISTS 로 개작하지 않는다. 02_seed 는 화면 시드가 있으면 건너뛴다.
#       01_sp 는 CREATE OR REPLACE, 03·05 는 ON CONFLICT, 06·07 은 재실행 안전
#    3) 접속정보는 환경변수로만 받는다 — 비밀번호를 인자나 파일에 적지 않는다
#
#  사용:
#    # 플랫폼 초기화 (0000 만)
#    PGHOST=호스트 PGUSER=계정 PGPASSWORD=*** bash apply-all.sh
#
#    # 같은 DB 에 다시 돌려도 된다 — 스키마가 있으면 00_ddl·02_seed 를 건너뛴다.
#    # 00_alter 는 그때도 돈다.
#    # 새 업체만 얹을 때는 업체분 4본(03·05·06·07)만 직접 돌려도 된다.
#
#  변경
#    2026-08-25 — 번호 마이그레이션 133본을 5본으로 접었다. 04 는 구 DB 전용이라 여기서 안 돌린다
#    2026-08-26 — 06_company_seed(업체 개설) 추가. CO_CD 를 주면 그 업체까지 만든다
#    2026-08-28 — 07_company_forms(회사 지면) 추가. 이게 없으면 새 업체는 작성 화면에
#                 고를 양식이 0건이라 아무것도 못 쓴다. 0001 을 열어 보고 알았다
#    2026-09-07 — 스키마가 있으면 00_ddl·02_seed 를 건너뛴다. 재실행이 죽지 않는다
#    2026-09-07 — 10·11·12 1회성 본은 시험·운영에 적용한 뒤 지웠다. 정본은 7본이다
#    2026-09-08 — 00_alter.sql 을 00_ddl 다음·01_sp 전에 항상 돌린다. 시드 7본은 그대로다
#    2026-09-10 — 새 업체는 06(회사)을 03·05보다 먼저. co_cd FK 가 빈 회사코드를 거부한다
#    2026-09-10 — 00_alter·01_sp 다음 00_ddl 주석 블록. 마커 없으면 중단. 주석만 ON_ERROR_STOP=0
# ============================================================
set -euo pipefail
export PGCLIENTENCODING=UTF8

DIR="$(cd "$(dirname "$0")" && pwd)"
PSQL="${PSQL:-psql}"
DBNAME="${PGDATABASE:-sasshaccp}"
CO_CD="${CO_CD:-0000}"
CO_NM="${CO_NM:-}"
ADMIN_ID="${ADMIN_ID:-}"

run() { "$PSQL" -d "$DBNAME" -v ON_ERROR_STOP=1 -q "$@"; }

# DB가 없으면 만든다 — CREATE DATABASE는 트랜잭션 안에서 못 돌려 postgres DB에 붙어 별도 실행한다
if ! "$PSQL" -d "$DBNAME" -c 'SELECT 1' >/dev/null 2>&1; then
    echo "== DB 생성 $DBNAME"
    "$PSQL" -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"$DBNAME\""
fi

# 스키마가 있을 때(= 이미 깐 DB) 00_ddl 을 건너뛴다 — CREATE SCHEMA/TABLE 에 IF NOT EXISTS 가 없다
HAS_SCHEMA="$("$PSQL" -d "$DBNAME" -t -A -c "SELECT 1 FROM information_schema.schemata WHERE schema_name='sasshaccp'" 2>/dev/null || true)"

# ── 1. 플랫폼 공통 — 회사코드를 안 받는다
if [ "$HAS_SCHEMA" = "1" ]; then
    echo "== 00_ddl.sql 건너뜀 (스키마 sasshaccp 있음)"
else
    echo "== 00_ddl.sql"
    run -f "$DIR/00_ddl.sql"
fi

# 이미 깐 DB 에도 꼬리 ALTER·새 표가 가야 한다. 00_ddl skip 과 무관하게 항상 돈다
echo "== 00_alter.sql"
run -f "$DIR/00_alter.sql"

echo "== 01_sp.sql"
run -f "$DIR/01_sp.sql"

# 주석 정본은 00_ddl 하단 블록. 칸이 생긴 뒤(00_alter 다음)에만 덮는다.
if ! grep -q '^-- START_COMMENT_BLOCK' "$DIR/00_ddl.sql" \
   || ! grep -q '^-- END_COMMENT_BLOCK' "$DIR/00_ddl.sql"; then
    echo "00_ddl.sql 에 주석 블록 마커가 없다" >&2
    exit 1
fi
echo "== 00_ddl.sql 주석 블록"
set +e
cmt_out=$(sed -n '/^-- START_COMMENT_BLOCK/,/^-- END_COMMENT_BLOCK/p' "$DIR/00_ddl.sql" \
  | "$PSQL" -d "$DBNAME" -v ON_ERROR_STOP=0 2>&1)
set -e
printf '%s\n' "$cmt_out"
if printf '%s\n' "$cmt_out" | grep -q '^ERROR:'; then
    echo "   경고: 주석 일부 실패 — 없는 칸 COMMENT 는 무시한다"
fi

# 화면 시드가 있을 때(= 02 를 이미 돌림) 건너뛴다 — ON CONFLICT 0건
HAS_SEED="$("$PSQL" -d "$DBNAME" -t -A -c "SELECT 1 FROM sasshaccp.tbl_screen LIMIT 1" 2>/dev/null || true)"
if [ "$HAS_SEED" = "1" ]; then
    echo "== 02_seed.sql 건너뜀 (플랫폼 시드 있음)"
else
    echo "== 02_seed.sql"
    run -f "$DIR/02_seed.sql"
fi

# ── 2. 업체 개설 — 회사 행이 공통코드·양식보다 먼저. 0000 은 02_seed 가 이미 만들어 두어 건너뛴다
if [ "$CO_CD" != "0000" ]; then
    echo "== 06_company_seed.sql (co_cd=$CO_CD)"
    ARGS=(-v co_cd="$CO_CD")
    [ -n "$CO_NM" ] && ARGS+=(-v co_nm="$CO_NM")
    [ -n "$ADMIN_ID" ] && ARGS+=(-v admin_id="$ADMIN_ID")
    [ -n "${WRITER_ID:-}" ] && ARGS+=(-v writer_id="$WRITER_ID")
    run "${ARGS[@]}" -f "$DIR/06_company_seed.sql"
    echo "   ** 초기 비밀번호는 1234 다. 첫 로그인 후 반드시 바꾼다 **"
fi

# ── 3. 업체별 — 공통코드·양식 표준. 회사 FK 가 살아 있으려면 06 다음이다
for f in 03_code_seed.sql 05_form_seed.sql; do
    echo "== $f (co_cd=$CO_CD)"
    run -v co_cd="$CO_CD" -f "$DIR/$f"
done

# ── 4. 회사 지면 — 06·03·05 까지만 돌리면 작성 화면에 고를 양식이 0건이다.
#      0000 도 필요하다: 시드는 표준 지면까지만 깔고 회사 지면 버전은 안 만든다
echo "== 07_company_forms.sql (co_cd=$CO_CD)"
run -v co_cd="$CO_CD" -f "$DIR/07_company_forms.sql"

echo "== 완료"
"$PSQL" -d "$DBNAME" -t -A -F' ' -c "
SELECT (SELECT count(*) FROM information_schema.tables
         WHERE table_schema='sasshaccp' AND table_type='BASE TABLE'),
       (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='sasshaccp' AND p.proname LIKE 'sp\\_%'),
       (SELECT count(*) FROM sasshaccp.tbl_menu WHERE co_cd='$CO_CD'),
       (SELECT count(*) FROM sasshaccp.tbl_code WHERE co_cd='$CO_CD'),
       (SELECT count(*) FROM sasshaccp.tbl_company_template WHERE co_cd='$CO_CD')"
echo "   (표 SP 메뉴 코드 사용양식)"
