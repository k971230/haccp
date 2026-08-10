#!/usr/bin/env bash
# ============================================================
#  prod 스모크 공통 상수 — prod_smoke.sh 가 source 한다
#
#  개발자: 박승우
#  일자: 2026-08-10
#  코멘트:
#    1) BASE_URL·curl 옵션·날짜 유틸을 한곳에 둔다
#    2) SMOKE_USER·SMOKE_PASS 는 Jenkins Credentials 또는 셸에서만 주입한다
#    3) 자체 서명 인증서 검증용으로 SMOKE_INSECURE=1 이면 curl -k
# ============================================================

# 호출자가 넘긴 BASE_URL 이 우선 — 없으면 예시 도메인
: "${SMOKE_CURL_MAX_TIME:=30}"
: "${SMOKE_INSECURE:=0}"

smoke_curl() {
  local args=(-fsS --max-time "$SMOKE_CURL_MAX_TIME")
  if [ "${SMOKE_INSECURE}" = "1" ]; then
    args+=(-k)
  fi
  curl "${args[@]}" "$@"
}

# YYYYMMDD — GNU date -d 없이 portable 하게 (Git Bash·busybox)
smoke_ymd() {
  # $1 = days ago (0=오늘)
  local ago="${1:-0}"
  if command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
    local py
    py="$(command -v python3 2>/dev/null || command -v python)"
    "$py" -c "from datetime import date,timedelta; print((date.today()-timedelta(days=int('$ago'))).strftime('%Y%m%d'))"
  elif date -v-"${ago}"d +%Y%m%d >/dev/null 2>&1; then
    date -v-"${ago}"d +%Y%m%d
  else
    # GNU date
    date -d "${ago} days ago" +%Y%m%d 2>/dev/null || date +%Y%m%d
  fi
}
