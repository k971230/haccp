#!/usr/bin/env bash
# ============================================================
#  assert_e2e_pr_safe — PR 게이트 E2E 가 운영을 치는지 막는다
#
#  개발자: 박승우
#  일자: 2026-09-11
#  코멘트:
#    1) Jenkinsfile.verify 의 E2E 단계가 가장 먼저 부른다
#    2) 운영 호스트·운영 쓰기 플래그·시험 DB 가 아닌 이름을 거절한다
#    3) 화면·API 는 localhost/127.0.0.1 만 통과한다
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROD_HOST="180.71.58.87"

base="${E2E_BASE_URL:-http://localhost:4173/haccp/}"
api="${E2E_API_BASE_URL:-http://localhost:7070}"

if [ "${E2E_ALLOW_PROD_WRITES:-}" = "1" ]; then
  echo "PR 게이트 E2E 는 E2E_ALLOW_PROD_WRITES 를 끈다. 운영 쓰기를 열지 않는다."
  exit 1
fi

is_local() {
  echo "$1" | grep -Eiq '^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?([/?#]|$)'
}

if echo "${base} ${api}" | grep -F "${PROD_HOST}" >/dev/null; then
  echo "PR 게이트 E2E 는 운영 호스트(${PROD_HOST})를 거부한다."
  exit 1
fi

if ! is_local "${base}"; then
  echo "PR 게이트 E2E 화면 URL 은 localhost 만 허용한다: ${base}"
  exit 1
fi

if ! is_local "${api}"; then
  echo "PR 게이트 E2E API URL 은 localhost 만 허용한다: ${api}"
  exit 1
fi

db="${E2E_DB_NAME:-}"
if [ -z "${db}" ] && [ -f "${ROOT}/backend/haccp-api/.env" ]; then
  db="$(grep -E '^DB_NAME=' "${ROOT}/backend/haccp-api/.env" | head -n1 | cut -d= -f2- | tr -d '\r' | tr -d '[:space:]')"
fi

if [ -z "${db}" ]; then
  echo "PR 게이트 E2E 는 DB_NAME 이 *_test 여야 한다. backend/.env 또는 E2E_DB_NAME 이 없다."
  exit 1
fi

case "${db}" in
  *_test) ;;
  *)
    echo "PR 게이트 E2E 는 시험 DB(*_test) 만 허용한다. 지금 DB_NAME=${db}"
    exit 1
    ;;
esac

echo "E2E PR 안전: base=${base} api=${api} db=${db}"
