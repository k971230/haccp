#!/usr/bin/env bash
# ============================================================
#  HACCP SaaS — PostgreSQL 일괄 적용
#
#  개발자: 박승우
#  일자: 2026-08-26
#  코멘트:
#    1) 7본을 순서대로 적용한다 — 구조 → SP → 플랫폼 기준 → 공통코드 → 양식 → 업체 개설 → 회사 지면
#    2) 빈 DB 전용이다. 00_ddl(CREATE SCHEMA·CREATE TABLE 에 IF NOT EXISTS 없음)과
#       02_seed(ON CONFLICT 0건)가 재실행을 막는다 — 다시 깔려면 스키마부터 지운다.
#       01_sp 는 CREATE OR REPLACE 라 다시 돌려도 된다
#    3) 접속정보는 환경변수로만 받는다 — 비밀번호를 인자나 파일에 적지 않는다
#
#  사용:
#    # 플랫폼 초기화 (0000 만)
#    PGHOST=호스트 PGUSER=계정 PGPASSWORD=*** bash apply-all.sh
#
#    # 새 업체 개설 — 위를 끝낸 DB 에 업체 하나를 더 얹는다.
#    # 이 스크립트를 다시 부르면 1단계가 00_ddl 을 돌려 42P06 으로 죽는다.
#    # 업체분 4본(03·05·06·07)만 직접 돌린다 — 07-haccp-db.mdc 「파일 순서」의 예시
#
#  변경
#    2026-08-25 — 번호 마이그레이션 133본을 5본으로 접었다. 04 는 구 DB 전용이라 여기서 안 돌린다
#    2026-08-26 — 06_company_seed(업체 개설) 추가. CO_CD 를 주면 그 업체까지 만든다
#    2026-08-28 — 07_company_forms(회사 지면) 추가. 이게 없으면 새 업체는 작성 화면에
#                 고를 양식이 0건이라 아무것도 못 쓴다. 0001 을 열어 보고 알았다
# ============================================================
set -euo pipefail
export PGCLIENTENCODING=UTF8

DIR="$(cd "$(dirname "$0")" && pwd)"
PSQL="${PSQL:-psql}"
DBNAME="${PGDATABASE:-sasshaccp}"
CO_CD="${CO_CD:-0000}"
CO_NM="${CO_NM:-}"
ADMIN_ID="${ADMIN_ID:-}"

run() { $PSQL -d "$DBNAME" -v ON_ERROR_STOP=1 -q "$@"; }

# DB가 없으면 만든다 — CREATE DATABASE는 트랜잭션 안에서 못 돌려 postgres DB에 붙어 별도 실행한다
if ! $PSQL -d "$DBNAME" -c 'SELECT 1' >/dev/null 2>&1; then
    echo "== DB 생성 $DBNAME"
    $PSQL -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"$DBNAME\""
fi

# ── 1. 플랫폼 공통 — 회사코드를 안 받는다
for f in 00_ddl.sql 01_sp.sql 02_seed.sql; do
    echo "== $f"
    run -f "$DIR/$f"
done

# ── 2. 업체별 — 공통코드·양식 표준
for f in 03_code_seed.sql 05_form_seed.sql; do
    echo "== $f (co_cd=$CO_CD)"
    run -v co_cd="$CO_CD" -f "$DIR/$f"
done

# ── 3. 업체 개설 — 0000 은 02_seed 가 이미 만들어 두어 건너뛴다
if [ "$CO_CD" != "0000" ]; then
    echo "== 06_company_seed.sql (co_cd=$CO_CD)"
    ARGS=(-v co_cd="$CO_CD")
    [ -n "$CO_NM" ] && ARGS+=(-v co_nm="$CO_NM")
    [ -n "$ADMIN_ID" ] && ARGS+=(-v admin_id="$ADMIN_ID")
    [ -n "${WRITER_ID:-}" ] && ARGS+=(-v writer_id="$WRITER_ID")
    run "${ARGS[@]}" -f "$DIR/06_company_seed.sql"
    echo "   ** 초기 비밀번호는 1234 다. 첫 로그인 후 반드시 바꾼다 **"
fi

# ── 4. 회사 지면 — 06 까지만 돌리면 작성 화면에 고를 양식이 0건이다.
#      0000 도 필요하다: 시드는 표준 지면까지만 깔고 회사 지면 버전은 안 만든다
echo "== 07_company_forms.sql (co_cd=$CO_CD)"
run -v co_cd="$CO_CD" -f "$DIR/07_company_forms.sql"

echo "== 완료"
$PSQL -d "$DBNAME" -t -A -F' ' -c "
SELECT (SELECT count(*) FROM information_schema.tables
         WHERE table_schema='sasshaccp' AND table_type='BASE TABLE'),
       (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='sasshaccp' AND p.proname LIKE 'sp\\_%'),
       (SELECT count(*) FROM sasshaccp.tbl_menu WHERE co_cd='$CO_CD'),
       (SELECT count(*) FROM sasshaccp.tbl_code WHERE co_cd='$CO_CD'),
       (SELECT count(*) FROM sasshaccp.tbl_company_template WHERE co_cd='$CO_CD')"
echo "   (표 SP 메뉴 코드 사용양식)"
