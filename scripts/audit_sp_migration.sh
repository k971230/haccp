#!/usr/bin/env bash
# audit_sp_migration — 1회성 마이그레이션이 SP 정본과 어긋났는지 본다.
#
# 개발자: 박승우
# 일자: 2026-09-04
# 코멘트:
#   1) db_sasshaccp/1*_*.sql 의 CREATE OR REPLACE 본문이 01_sp.sql 과 글자 그대로 같은지 본다
#   2) 야간 감시(haccp-audit)와 커밋 전에 돌린다
#   3) 어긋나면 종료코드 1
#
# 왜 있나: 마이그레이션 본을 뽑은 **뒤에** 01_sp.sql 을 더 고치면 둘이 갈라진다.
# 배포 담당이 실제로 돌리는 것은 마이그레이션 본이라, 갈라지면 고친 줄이 라이브에 안 간다.
# 실제로 그렇게 났다 — opinion 자르기가 승인 분기에서만 빠진 채 나갈 뻔했다.
set -u
cd "$(dirname "$0")/.."

CANON=db_sasshaccp/01_sp.sql
[ -f "$CANON" ] || { echo "audit_sp_migration: $CANON 이 없다"; exit 1; }

shopt -s nullglob
FILES=(db_sasshaccp/1*_*.sql)
if [ ${#FILES[@]} -eq 0 ]; then
  echo "audit_sp_migration: 1회성 본이 없다 — OK"
  exit 0
fi

python "$(dirname "$0")/_sp_migration_diff.py" "$CANON" "${FILES[@]}"
RC=$?
if [ $RC -ne 0 ]; then
  echo "audit_sp_migration: 마이그레이션이 01_sp.sql 과 어긋났다 — 정본을 고쳤으면 본을 다시 뽑아라"
  exit 1
fi
echo "audit_sp_migration OK"
