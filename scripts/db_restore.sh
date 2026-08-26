#!/usr/bin/env bash
# ============================================================
#  db_restore.sh — pg_dump 덤프를 되돌린다
#
#  개발자: 박승우
#  일자: 2026-08-26
#  코멘트:
#    1) 백업은 있는데 되돌리는 절차가 없었다 — 되돌려 본 적 없는 백업은 백업이 아니다
#    2) compose 의 backup 프로파일이 뜬 -Fc 덤프를 그대로 받는다
#    3) 대상 DB 를 **지우고 다시 만든다.** 그래서 이름을 두 번 확인시킨다
#
#  실제로 겪는 것
#    접속이 하나라도 남아 있으면 DROP DATABASE 가 거절된다 —
#    "database is being accessed by other users". 그래서 먼저 끊는다.
#
#  쓰기
#    bash scripts/db_restore.sh <덤프파일> <대상DB>
#    bash scripts/db_restore.sh ./backup/sasshaccp_20260826.dump sasshaccp_test
#
#  접속정보는 PGHOST·PGUSER·PGPASSWORD 로 준다.
#  없으면 backend/haccp-api/.env 에서 읽는다.
# ============================================================
set -euo pipefail

DUMP="${1:?usage: db_restore.sh <덤프파일> <대상DB>}"
TARGET="${2:?usage: db_restore.sh <덤프파일> <대상DB>}"

[ -f "$DUMP" ] || { echo "덤프 파일이 없다: $DUMP"; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/backend/haccp-api/.env"

# .env 에서 채운다 — 환경변수가 이미 있으면 그것을 쓴다
if [ -f "$ENV_FILE" ]; then
  PGHOST="${PGHOST:-$(grep -m1 '^DB_HOST=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')}"
  PGPORT="${PGPORT:-$(grep -m1 '^DB_PORT=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')}"
  PGUSER="${PGUSER:-$(grep -m1 '^DB_USERNAME=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')}"
  PGPASSWORD="${PGPASSWORD:-$(grep -m1 '^DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')}"
fi
PGPORT="${PGPORT:-5432}"
: "${PGHOST:?PGHOST 가 없다}" "${PGUSER:?PGUSER 가 없다}" "${PGPASSWORD:?PGPASSWORD 가 없다}"
export PGPASSWORD

# 운영 DB 를 실수로 덮는 것을 막는다 — 이름을 그대로 한 번 더 치게 한다
if [ "${RESTORE_CONFIRM:-}" != "$TARGET" ]; then
  cat <<MSG
!! "$TARGET" 를 **지우고 다시 만든다.** 지금 들어 있는 것은 전부 사라진다.

   계속하려면 대상 DB 이름을 RESTORE_CONFIRM 에 그대로 넣어 다시 실행한다.

     RESTORE_CONFIRM=$TARGET bash scripts/db_restore.sh "$DUMP" "$TARGET"
MSG
  exit 1
fi

# psql 이 없는 개발 PC 도 있어 도커로 돈다 — 운영 backup 프로파일과 같은 이미지
PG_IMAGE="${PG_IMAGE:-postgres:16}"
DUMP_NAME="$(basename "$DUMP")"
# Git Bash 에서는 pwd 가 /c/... 를 준다 — 도커 마운트에는 Windows 경로(C:/...)가 필요하다.
# pwd -W 가 있으면 그걸 쓴다 (MSYS 전용). 없으면 그냥 pwd.
DUMP_DIR="$(cd "$(dirname "$DUMP")" && { pwd -W 2>/dev/null || pwd; })"

# Git Bash 가 컨테이너 경로(/backup)를 Windows 경로로 바꾸는 것을 막는다
export MSYS_NO_PATHCONV=1

run_pg() {
  docker run --rm -e PGPASSWORD -v "${DUMP_DIR}:/backup" "$PG_IMAGE" "$@"
}

echo ">>> 1) 남은 접속을 끊는다 — 하나라도 있으면 DROP 이 거절된다"
run_pg psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -v ON_ERROR_STOP=1 -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity
    WHERE datname = '$TARGET' AND pid <> pg_backend_pid();" >/dev/null

echo ">>> 2) $TARGET 를 지우고 다시 만든다"
run_pg psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS $TARGET;" \
  -c "CREATE DATABASE $TARGET WITH ENCODING 'UTF8' TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C';" >/dev/null

echo ">>> 3) 덤프를 되돌린다"
run_pg pg_restore -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$TARGET" \
  --no-owner --no-privileges "/backup/$DUMP_NAME"

echo ">>> 4) 확인 — 표·SP 가 0 이면 되돌아가지 않은 것이다"
run_pg psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$TARGET" -v ON_ERROR_STOP=1 -c \
  "SELECT (SELECT count(*) FROM information_schema.tables
            WHERE table_schema='sasshaccp' AND table_type='BASE TABLE') AS 표,
          (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='sasshaccp' AND p.proname LIKE 'sp\\_%')      AS SP,
          (SELECT count(*) FROM sasshaccp.tbl_document)                   AS 문서,
          (SELECT count(*) FROM sasshaccp.tbl_user)                       AS 사용자;"

cat <<'MSG'

>>> 되돌렸다. 마지막으로 **앱을 띄워서** 확인한다 —
    표 수가 맞는 것과 앱이 도는 것은 다른 이야기다.

      curl -X POST http://<API>/api/v1/auth/login \
        -H "Content-Type: application/json" -d '{"userId":"admin","password":"..."}'
MSG
