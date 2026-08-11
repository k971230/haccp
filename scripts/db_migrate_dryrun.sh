#!/usr/bin/env bash
# ============================================================
#  DB 마이그레이션 dry-run — 임시 PG 에 apply-all.sh 를 돌려 오류만 확인
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) Jenkins 'DB migrate dry-run' 스테이지 — prod 데이터를 건드리지 않는다
#    2) 호스트 포트 없이 docker network 로만 붙인다 (55432 충돌·노출 방지)
#    3) postgres:16(debian) — apply-all.sh 가 bash 와 GNU ls -v 를 요구한다
#  호출처: Jenkinsfile stage DB migrate dry-run
#  성공: apply-all 종료 0. 실패: SQL/컨테이너 오류 + cleanup 후 exit 1
# ============================================================
set -euo pipefail

export MSYS_NO_PATHCONV=1

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="haccp-migrate-dryrun-$$"
NET="haccp-migrate-dryrun-net-$$"

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo ">>> 임시 네트워크·PG 기동"
docker network create "$NET" >/dev/null
docker run -d --rm --name "$NAME" --network "$NET" \
  -e POSTGRES_PASSWORD=temp \
  -e POSTGRES_DB=sasshaccp \
  postgres:16 >/dev/null

echo ">>> pg_isready 대기"
for i in $(seq 1 40); do
  if docker exec "$NAME" pg_isready -U postgres -d sasshaccp >/dev/null 2>&1; then
    break
  fi
  sleep 1
  if [ "$i" -eq 40 ]; then
    echo "PG ready 시간 초과" >&2
    exit 1
  fi
done

host_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

echo ">>> apply-all.sh (same network)"
# 호스트 bash 대신 debian PG 사이드카로 돌려 Windows/Git Bash 경로 문제를 피한다
docker run --rm --network "$NET" \
  -e PGHOST="$NAME" \
  -e PGPORT=5432 \
  -e PGUSER=postgres \
  -e PGPASSWORD=temp \
  -e PGDATABASE=sasshaccp \
  -v "$(host_path "$ROOT/db_sasshaccp")":/db_sasshaccp:ro \
  postgres:16 bash /db_sasshaccp/apply-all.sh

echo "db_migrate_dryrun OK"
