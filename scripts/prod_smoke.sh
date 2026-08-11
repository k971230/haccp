#!/usr/bin/env bash
# ============================================================
#  prod 스모크 — 배포 직후 9단계 (조회 전용, 결재·삭제 없음)
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) origin(https://IP) 기준 — FE/healthz 는 /haccp , API 는 /api (Apache Path)
#    2) 루프백 edge 직접 검증 시 SMOKE_WEB_PREFIX= 빈값 + http://127.0.0.1:17070
#    3) JSON 파싱은 python — jq 없이도 Windows/Jenkins 에서 돈다
# ============================================================
set -euo pipefail

BASE_URL="${1:?usage: prod_smoke.sh <base_url>}"
BASE_URL="${BASE_URL%/}"
# Apache Path 분기 기본 프리픽스. edge 루프백 직행 시 SMOKE_WEB_PREFIX= 로 비운다
WEB_PREFIX="${SMOKE_WEB_PREFIX-/haccp}"
# 앞 슬래시만 남기고 끝 슬래시는 제거 — "${BASE}${WEB_PREFIX}/healthz" 조립용
WEB_PREFIX="${WEB_PREFIX%/}"
case "$WEB_PREFIX" in
  ""|/*) ;;
  *) WEB_PREFIX="/${WEB_PREFIX}" ;;
esac
USER="${SMOKE_USER:?SMOKE_USER not set}"
PASS="${SMOKE_PASS:?SMOKE_PASS not set}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=smoke_env.sh
source "$ROOT/scripts/smoke_env.sh"

# Ubuntu 등 python 미설치 환경 — python3 만 있을 때 PATH 에 python 별칭을 붙인다
if ! command -v python >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  PATH="$(dirname "$(command -v python3)"):${PATH}"
  # 임시 래퍼 — 동일 디렉터리에 python 이 없으면 mkdir + ln
  if ! command -v python >/dev/null 2>&1; then
    _smoke_bin="${TMPDIR:-/tmp}/haccp-smoke-bin-$$"
    mkdir -p "$_smoke_bin"
    ln -sf "$(command -v python3)" "$_smoke_bin/python"
    PATH="$_smoke_bin:${PATH}"
  fi
fi

# Python(Windows) 이 /d/... MSYS 경로를 못 열므로 저장소 상대 경로만 쓴다
cd "$ROOT"
TMP=".smoke-tmp-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"; rm -rf "${_smoke_bin:-}"' EXIT

fetch() {
  local out="$1"; shift
  local args=(-sS --max-time "${SMOKE_CURL_MAX_TIME}")
  if [ "${SMOKE_INSECURE}" = "1" ]; then args+=(-k); fi
  # Git Bash 에서 curl -o 가 (23) 나는 경우가 있어 stdout 리다이렉션만 쓴다.
  # 마지막 줄에 상태코드를 붙여 본문과 분리한다
  local raw code
  raw="$(curl "${args[@]}" -w "\n__HTTP__%{http_code}" "$@" || true)"
  code="$(printf '%s\n' "$raw" | sed -n 's/^__HTTP__//p' | tail -1)"
  printf '%s\n' "$raw" | sed '/^__HTTP__/d' > "$out"
  case "$code" in
    2*|3*) ;;
    *) echo "HTTP ${code:-000} ← $*"; head -c 300 "$out" >&2; echo >&2; return 1 ;;
  esac
}

jget() {
  python - "$1" "$2" <<'PY'
import json, sys
o = json.load(open(sys.argv[1], encoding="utf-8"))
q = sys.argv[2]
d = o.get("data")
if q == "token":
    print((d or {}).get("token") or "")
elif q == "userId":
    if isinstance(d, dict):
        print(d.get("userId") or (d.get("user") or {}).get("userId") or "")
elif q == "success":
    print("true" if o.get("success") else "false")
elif q == "menu_len":
    print(len(d) if isinstance(d, list) else 0)
elif q == "has_approval_history":
    ok = isinstance(d, list) and any(isinstance(x, dict) and x.get("menuCd") == "approval-history" for x in d)
    print("yes" if ok else "")
else:
    sys.exit(2)
PY
}

echo "==> 1) edge 헬스 (${WEB_PREFIX}/healthz)"
fetch "$TMP/healthz.txt" "${BASE_URL}${WEB_PREFIX}/healthz"
grep -q ok "$TMP/healthz.txt"

echo "==> 2) FE 정적 (${WEB_PREFIX}/)"
fetch "$TMP/index.html" "${BASE_URL}${WEB_PREFIX}/"
grep -qiE '<title>|haccp|root' "$TMP/index.html"

echo "==> 3) 로그인 (JWT)"
fetch "$TMP/login.json" -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"userId\":\"$USER\",\"password\":\"$PASS\"}"
TOKEN="$(jget "$TMP/login.json" token)"
[ -n "$TOKEN" ] || { echo "로그인 실패"; cat "$TMP/login.json" >&2; exit 1; }

echo "==> 4) /auth/me 세션 복구"
fetch "$TMP/me.json" "$BASE_URL/api/v1/auth/me" -H "Authorization: Bearer $TOKEN"
[ -n "$(jget "$TMP/me.json" userId)" ] || { echo "/auth/me 실패"; cat "$TMP/me.json" >&2; exit 1; }

echo "==> 5) 메뉴 로딩"
fetch "$TMP/menu.json" "$BASE_URL/api/v1/menu/list" -H "Authorization: Bearer $TOKEN"
MLEN="$(jget "$TMP/menu.json" menu_len)"
[ "${MLEN:-0}" -ge 5 ] || { echo "메뉴 ${MLEN:-0}건 — 5건 미만"; exit 1; }

echo "==> 6) approval-history leaf (STEP 03 회귀)"
[ -n "$(jget "$TMP/menu.json" has_approval_history)" ] || {
  echo "approval-history 메뉴 부재 — STEP 03 회귀"; exit 1;
}

echo "==> 7) 냉장 CCP 목록"
FROM_DT="$(smoke_ymd 7)"
TO_DT="$(smoke_ymd 0)"
fetch "$TMP/cold.json" \
  "$BASE_URL/api/v1/ccp/cold-monitor/list?fromDt=${FROM_DT}&toDt=${TO_DT}" \
  -H "Authorization: Bearer $TOKEN"
[ "$(jget "$TMP/cold.json" success)" = "true" ] || { echo "cold-monitor 실패"; cat "$TMP/cold.json" >&2; exit 1; }

echo "==> 8) 회사 사용양식 목록"
fetch "$TMP/tmpl.json" "$BASE_URL/api/v1/bas/company-templates/list" \
  -H "Authorization: Bearer $TOKEN"
[ "$(jget "$TMP/tmpl.json" success)" = "true" ] || { echo "company-templates 실패"; cat "$TMP/tmpl.json" >&2; exit 1; }

echo "==> 9) UV/PV collect (HTTP 200만)"
ENTER_DT="$(date +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%S)"
fetch "$TMP/collect.hdr" -D - -X POST "$BASE_URL/api/v1/log/view/collect" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "[{\"scrnCd\":\"today-tasks\",\"enterDt\":\"${ENTER_DT}\"}]" || true
# -D - 는 헤더+바디가 같은 파일에 섞일 수 있어 첫 HTTP 상태만 본다
CODE="$(awk 'BEGIN{c=""} /^HTTP\//{c=$2} END{print c}' "$TMP/collect.hdr")"
echo "$CODE" | grep -qE '^20[0-9]$' || { echo "view/collect HTTP ${CODE:-?}"; head -c 200 "$TMP/collect.hdr" >&2; exit 1; }

if [ "${SMOKE_CHECK_ACTUATOR:-0}" = "1" ]; then
  echo "==> (옵션) actuator health"
  fetch "$TMP/act.json" "$BASE_URL/actuator/health"
fi

echo "PROD SMOKE OK"
