#!/usr/bin/env bash
# ============================================================
#  prod 스모크 — 배포 직후 9단계 (조회 전용, 결재·삭제 없음)
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) origin(https://IP) 기준 — FE/healthz 는 /haccp , API 는 /api (Apache Path)
#    2) 루프백 edge 직행 시 SMOKE_WEB_PREFIX= 빈값 + http://127.0.0.1:17070
#    3) JSON 은 python — jq 없이도 Windows/Jenkins 에서 돈다. 단계 실패 시 즉시 exit 1
#  호출처: Jenkinsfile Prod smoke · 런북 §15 · 수동: SMOKE_USER/PASS 주입 후 실행
#  성공: 9단계 모두 HTTP/업무 조건 통과. 실패: 해당 단계 메시지 후 non-zero
#  계정: haccp-smoke-user(조회 전용). 작성·상신은 Jenkinsfile.e2e + haccp-write-user
# ============================================================
set -euo pipefail

BASE_URL="${1:?usage: prod_smoke.sh <base_url>}"
BASE_URL="${BASE_URL%/}"
# Apache Path 분기 기본 프리픽스. edge 루프백 직행 시 SMOKE_WEB_PREFIX= 로 비운다.
# Git Bash(MSYS) 가 "/haccp" 를 Windows 경로로 바꿔 /C:/Program Files/Git/haccp 가 되는 경우가 있어
# 환경값이 이상하면 기본 /haccp 로 되돌린다 (Jenkinsfile 에서도 MSYS_NO_PATHCONV=1).
WEB_PREFIX="${SMOKE_WEB_PREFIX-/haccp}"
WEB_PREFIX="${WEB_PREFIX%/}"
case "$WEB_PREFIX" in
  ""|/haccp) ;;
  /*[Hh][Aa][Cc][Cc][Pp]) WEB_PREFIX="/haccp" ;;
  [Hh][Aa][Cc][Cc][Pp]) WEB_PREFIX="/haccp" ;;
  /*) ;;
  *)
    # MSYS 깨짐·기타 — 운영 Path 기본값으로 복구
    if [[ "$WEB_PREFIX" == *":"* ]] || [[ "$WEB_PREFIX" == *"Program Files"* ]]; then
      WEB_PREFIX="/haccp"
    else
      WEB_PREFIX="/${WEB_PREFIX}"
    fi
    ;;
esac
USER="${SMOKE_USER:?SMOKE_USER not set}"
PASS="${SMOKE_PASS:?SMOKE_PASS not set}"

# Jenkins Credentials 를 Windows 에이전트에서 읽으면 값 끝에 CR 이 붙는다.
# 로그인 화면은 trim 하지만 여기서는 그대로 POST 해서 BCrypt 가 어긋난다 —
# 브라우저로는 되는데 스모크만 LOGIN_FAIL 이 나면 대개 이것이다.
trim() {
  local v="${1//$'\r'/}"
  v="${v#"${v%%[![:space:]]*}"}"
  printf '%s' "${v%"${v##*[![:space:]]}"}"
}
USER="$(trim "$USER")"
PASS="$(trim "$PASS")"

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
elif q == "leaf_len":
    # leaf 화면 수 — scrnCd 가 있는 항목만 센다. 이 값이 0 이면 STEP 03 회귀다
    print(sum(1 for x in d if isinstance(x, dict) and x.get("scrnCd")) if isinstance(d, list) else 0)
elif q == "has_landing":
    # 랜딩 화면은 누구에게나 보인다 — 화면코드가 실려 오는지 이걸로 본다
    ok = isinstance(d, list) and any(
        isinstance(x, dict) and x.get("scrnCd") == "today-tasks" for x in d
    )
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

# 화면 이름 하나를 박아 두면 개명 때마다 스모크가 깨진다 —
# 2026-08-26 에 approval-history(→ sign-ok) 로 실제로 그랬다.
# leaf 가 실려 오는지와, 절대 안 바뀌는 랜딩 화면만 본다.
echo "==> 6) 메뉴 leaf 에 화면코드가 실려 온다 (STEP 03 회귀)"
LEAF="$(jget "$TMP/menu.json" leaf_len)"
[ "${LEAF:-0}" -ge 5 ] || { echo "leaf 화면 ${LEAF:-0}건 — scrnCd 가 안 실린다"; exit 1; }
[ -n "$(jget "$TMP/menu.json" has_landing)" ] || {
  echo "랜딩 화면(today-tasks)이 메뉴에 없다"; exit 1;
}

echo "==> 7) 작성 화면 목록 (화면 API -> SP -> DB)"
FROM_DT="$(smoke_ymd 7)"
TO_DT="$(smoke_ymd 0)"
# SCREEN_PATH · CcpHtgDraftController 와 같다. smoke(VIEWER)가 읽을 수 있는 화면이어야 한다
fetch "$TMP/draft.json" \
  "$BASE_URL/api/v1/draft/ccp-monitoring/ccp-htg/list?fromDt=${FROM_DT}&toDt=${TO_DT}" \
  -H "Authorization: Bearer $TOKEN"
[ "$(jget "$TMP/draft.json" success)" = "true" ] || { echo "ccp-htg 목록 실패"; cat "$TMP/draft.json" >&2; exit 1; }

echo "==> 8) 문서 목록 (여러 화면이 함께 쓰는 문서 허브)"
# 구 /api/v1/bas/company-templates 는 없다. 사용양식관리는 VIEWER read 권한이 없어 403 이다
fetch "$TMP/docs.json" "$BASE_URL/api/v1/docs/documents/list" \
  -H "Authorization: Bearer $TOKEN"
[ "$(jget "$TMP/docs.json" success)" = "true" ] || { echo "문서 목록 실패"; cat "$TMP/docs.json" >&2; exit 1; }

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
