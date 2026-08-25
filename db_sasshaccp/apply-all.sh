#!/usr/bin/env bash
# ============================================================
#  HACCP SaaS — PostgreSQL 일괄 적용
#
#  개발자: 박승우
#  일자: 2026-08-25
#  코멘트:
#    1) 5본을 순서대로 적용한다 — DDL → SP → 기초데이터 → 공통코드 → 양식 표준
#    2) 전 파일이 IF NOT EXISTS / ON CONFLICT 기반이라 몇 번을 다시 돌려도 결과가 같다
#    3) 접속정보는 환경변수로만 받는다 — 비밀번호를 인자나 파일에 적지 않는다
#
#  사용:
#    PGHOST=호스트 PGPORT=5432 PGUSER=계정 PGPASSWORD=*** bash apply-all.sh
#    CO_CD=0001 을 주면 그 업체로 공통코드·양식 표준을 뿌린다 (기본 0000)
#
#  2026-08-25 — 번호 마이그레이션 133본을 5본으로 접었다. 04 는 구 DB 전용이라 여기서 돌리지 않는다.
# ============================================================
set -euo pipefail
export PGCLIENTENCODING=UTF8

DIR="$(cd "$(dirname "$0")" && pwd)"
PSQL="${PSQL:-psql}"
DBNAME="${PGDATABASE:-sasshaccp}"
CO_CD="${CO_CD:-0000}"

# DB가 없으면 만든다 — CREATE DATABASE는 트랜잭션 안에서 못 돌려 postgres DB에 붙어 별도 실행한다
if ! $PSQL -d "$DBNAME" -c 'SELECT 1' >/dev/null 2>&1; then
    echo "== DB 생성 $DBNAME"
    $PSQL -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"$DBNAME\""
fi

# co_cd 를 받지 않는 것과 받는 것을 나눠 돌린다
for f in 00_ddl.sql 01_sp.sql 02_seed.sql; do
    echo "== $f"
    $PSQL -d "$DBNAME" -v ON_ERROR_STOP=1 -q -f "$DIR/$f"
done

for f in 03_code_seed.sql 05_form_seed.sql; do
    echo "== $f (co_cd=$CO_CD)"
    $PSQL -d "$DBNAME" -v ON_ERROR_STOP=1 -v co_cd="$CO_CD" -q -f "$DIR/$f"
done

echo "== 완료"
$PSQL -d "$DBNAME" -t -A -F' ' -c "
SELECT (SELECT count(*) FROM information_schema.tables
         WHERE table_schema='sasshaccp' AND table_type='BASE TABLE'),
       (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='sasshaccp' AND p.proname LIKE 'sp\\_%'),
       (SELECT count(*) FROM sasshaccp.tbl_menu),
       (SELECT count(*) FROM sasshaccp.tbl_code)"
echo "   (표 SP 메뉴 코드)"
