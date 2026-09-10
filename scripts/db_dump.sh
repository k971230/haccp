#!/usr/bin/env bash
# ============================================================
#  db_dump.sh — postgres:16 컨테이너로 -Fc 덤프를 뽑는다
#
#  개발자: 박승우
#  일자: 2026-09-10
#  코멘트:
#    1) 로컬 PG 17 클라이언트 pg_dump 는 헤더 1.16 을 만든다 — 16 pg_restore 가 거절한다
#    2) 운영·compose backup·db_restore.sh 와 같은 postgres:16 이미지로만 뽑는다
#    3) 접속은 PGHOST·PGUSER·PGPASSWORD. 없으면 backend/haccp-api/.env 에서 읽는다
#
#  쓰기
#    bash scripts/db_dump.sh <출력파일> [대상DB]
#    bash scripts/db_dump.sh ./backup/sasshaccp.dump
#    bash scripts/db_dump.sh ./backup/sasshaccp.dump sasshaccp_test
#
#  대상 DB 를 빼면 .env 의 DB_NAME 을 쓴다.
# ============================================================
set -euo pipefail

DUMP="${1:?usage: db_dump.sh <출력파일> [대상DB]}"
TARGET="${2:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/backend/haccp-api/.env"

# .env 에서 채운다 — 환경변수가 이미 있으면 그것을 쓴다
if [ -f "$ENV_FILE" ]; then
  PGHOST="${PGHOST:-$(grep -m1 '^DB_HOST=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')}"
  PGPORT="${PGPORT:-$(grep -m1 '^DB_PORT=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')}"
  PGUSER="${PGUSER:-$(grep -m1 '^DB_USERNAME=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')}"
  PGPASSWORD="${PGPASSWORD:-$(grep -m1 '^DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')}"
  if [ -z "$TARGET" ]; then
    TARGET="$(grep -m1 '^DB_NAME=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')"
  fi
fi
PGPORT="${PGPORT:-5432}"
: "${PGHOST:?PGHOST 가 없다}" "${PGUSER:?PGUSER 가 없다}" "${PGPASSWORD:?PGPASSWORD 가 없다}"
: "${TARGET:?대상 DB 를 인자로 주거나 .env 의 DB_NAME 을 두세요}"
export PGPASSWORD

mkdir -p "$(dirname "$DUMP")"
DUMP_NAME="$(basename "$DUMP")"
# Git Bash 에서는 pwd 가 /c/... 를 준다 — 도커 마운트에는 Windows 경로(C:/...)가 필요하다.
DUMP_DIR="$(cd "$(dirname "$DUMP")" && { pwd -W 2>/dev/null || pwd; })"

# 운영 backup 프로파일·db_restore.sh 와 같은 이미지 — 서버를 17 로 올리지 않는다
PG_IMAGE="${PG_IMAGE:-postgres:16}"

# Git Bash 가 컨테이너 경로(/backup)를 Windows 경로로 바꾸는 것을 막는다
export MSYS_NO_PATHCONV=1

echo ">>> postgres:16 으로 $TARGET 를 덤프한다 — 로컬 17 pg_dump 는 쓰지 않는다"
docker run --rm -e PGPASSWORD -v "${DUMP_DIR}:/backup" "$PG_IMAGE" \
  pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$TARGET" -Fc -f "/backup/$DUMP_NAME"

echo ">>> 뽑았다: $DUMP"
echo "    되돌리려면: RESTORE_CONFIRM=<대상DB> bash scripts/db_restore.sh \"$DUMP\" <대상DB>"
