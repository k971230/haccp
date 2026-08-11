#!/usr/bin/env bash
# ============================================================
#  시크릿 커밋 차단 — JWT_SECRET 실값이 staged/인자 파일에 있으면 실패
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) public 저장소에 JWT·DB 비밀번호가 올라가는 것을 커밋 직전에 막는다
#    2) .env.example / .env.docker.example 의 changeme·placeholder 는 허용한다
#    3) 인자 없으면 git staged, 있으면 그 파일만 검사한다
#  호출처: README 권장 pre-commit hook · 수동 검사
#  성공: 실값 없음 exit 0. 실패: 파일 경로 출력 + exit 1
#
#  사용:
#    bash scripts/pre-commit-check-secrets.sh
#    bash scripts/pre-commit-check-secrets.sh path/to/file
#    ln -sf ../../scripts/pre-commit-check-secrets.sh .git/hooks/pre-commit
# ============================================================
set -euo pipefail

# 40자 이상 알파숫자(및 흔한 시크릿 문자)면 실값으로 본다 — openssl rand -hex 48 = 96자
SECRET_RE='JWT_SECRET=[A-Za-z0-9+/=_-]{40,}'
# 예제 파일에 허용하는 자리표시자
ALLOW_RE='changeme|placeholder|your-|replace-me|local-verify'

fail=0

scan_stream() {
  local label="$1"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    echo "$line" | grep -Eq "$SECRET_RE" || continue
    if echo "$line" | grep -Eiq "$ALLOW_RE"; then
      continue
    fi
    echo "시크릿 커밋 차단: $label" >&2
    echo "  → JWT_SECRET 실값으로 보이는 줄이 있습니다. .env.docker 는 서버·Jenkins Credentials 로만 두세요." >&2
    fail=1
  done
}

scan_file() {
  local f="$1"
  # 프로세스 치환(/dev/fd/N)·일반 파일 모두 — 읽을 수 없으면 실패로 본다
  if [ ! -e "$f" ] && [ ! -r "$f" ]; then
    echo "검사 대상 없음: $f" >&2
    fail=1
    return
  fi
  scan_stream "$f" < "$f"
}

if [ "$#" -gt 0 ]; then
  for f in "$@"; do scan_file "$f"; done
else
  # staged 변경만 — 이미 커밋된 이력은 이 훅의 범위가 아니다
  while IFS= read -r -d '' f; do
    scan_file "$f"
  done < <(git diff --cached --name-only -z --diff-filter=ACMR 2>/dev/null || true)
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "pre-commit-check-secrets: OK"
exit 0
