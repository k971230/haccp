#!/usr/bin/env bash
# ============================================================
#  OPS_DELETE 규약 lint — HTTP DELETE · @DeleteMapping · validate/delete 짝
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) FE 에서 http.delete / method DELETE 를 쓰면 실패한다
#    2) BE 에 @DeleteMapping 이 있으면 실패한다
#    3) validate-delete URL 이 있으면 같은 파일에 /delete URL 이 있어야 한다
#  호출처: Jenkinsfile.audit · 런북 §19
#  성공: 위반 0건. 실패: 히트 목록 + exit 1 (소스 미수정)
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FE="$ROOT/frontend/haccp-web/src"
BE="$ROOT/backend/haccp-api/src/main/java"
fail=0

echo ">>> FE http.delete / method DELETE"
hits="$(grep -RIn --include='*.ts' --include='*.tsx' \
  -E "http\.delete\(|method:\s*['\"]DELETE['\"]" \
  "$FE" 2>/dev/null || true)"
if [ -n "$hits" ]; then
  echo "$hits"
  echo "FE 에 HTTP DELETE 사용이 있습니다"
  fail=1
else
  echo "OK FE DELETE 없음"
fi

echo ">>> BE @DeleteMapping"
hits="$(grep -RIn --include='*Controller.java' '@DeleteMapping' "$BE" 2>/dev/null || true)"
if [ -n "$hits" ]; then
  echo "$hits"
  echo "BE 에 @DeleteMapping 이 있습니다 (OPS_DELETE 위반)"
  fail=1
else
  echo "OK BE @DeleteMapping 없음"
fi

echo ">>> FE validate-delete / delete 짝 (api/*.ts)"
while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  # 공통 클라이언트는 경로 문자열이 아니라 인터셉터만 있다
  [ "$base" = "http.ts" ] && continue
  if grep -q 'validate-delete' "$f"; then
    if ! grep -qE '/delete"|/delete'\''|/delete`|/delete,' "$f"; then
      echo "짝 없음: $f"
      fail=1
    fi
  fi
done < <(find "$FE/api" -type f -name '*.ts' -print0 2>/dev/null)

if [ "$fail" -ne 0 ]; then
  echo "audit_ops_delete FAIL"
  exit 1
fi
echo "audit_ops_delete OK"
