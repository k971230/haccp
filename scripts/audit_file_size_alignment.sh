#!/usr/bin/env bash
# ============================================================
#  파일 크기 3키 정합 — APP_FILE_MAX_BYTES / SIZE / REQUEST_SIZE
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) .env.example 값을 파싱해 byte·MB·request≥file 을 검사한다
#    2) application.yml multipart 기본값과 같은지 본다
#    3) 불일치 시 exit 1 — 소스는 수정하지 않는다
#  호출처: Jenkinsfile.audit · 런북 §19
#  성공: 3키 정합. 실패: 불일치 메시지 + exit 1
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENVF="$ROOT/backend/haccp-api/.env.example"
YML="$ROOT/backend/haccp-api/src/main/resources/application.yml"
fail=0

get_env() {
  local key="$1"
  grep -E "^${key}=" "$ENVF" | head -1 | cut -d= -f2- | tr -d '\r' | tr -d ' '
}

BYTES="$(get_env APP_FILE_MAX_BYTES)"
SIZE="$(get_env APP_FILE_MAX_SIZE)"
REQ="$(get_env APP_FILE_MAX_REQUEST_SIZE)"

echo "env: BYTES=$BYTES SIZE=$SIZE REQUEST=$REQ"

# 20MB = 20971520 (1024^2)
expect_bytes=20971520
if [ "$BYTES" != "$expect_bytes" ]; then
  echo "APP_FILE_MAX_BYTES 기대 $expect_bytes 실제 $BYTES"
  fail=1
fi
if [ "$SIZE" != "20MB" ]; then
  echo "APP_FILE_MAX_SIZE 기대 20MB 실제 $SIZE"
  fail=1
fi
if [ "$REQ" != "25MB" ]; then
  echo "APP_FILE_MAX_REQUEST_SIZE 기대 25MB 실제 $REQ"
  fail=1
fi

# yml 기본값
yml_size="$(grep -E 'max-file-size:' "$YML" | head -1 | grep -Eo '[0-9]+MB' || true)"
yml_req="$(grep -E 'max-request-size:' "$YML" | head -1 | grep -Eo '[0-9]+MB' || true)"
echo "yml: max-file-size=$yml_size max-request-size=$yml_req"
if [ "$yml_size" != "20MB" ] || [ "$yml_req" != "25MB" ]; then
  echo "application.yml multipart 기본값이 env 예제와 다릅니다"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "audit_file_size_alignment FAIL"
  exit 1
fi
echo "audit_file_size_alignment OK"
