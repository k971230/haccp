#!/usr/bin/env bash
# audit_grid_maxlength — 그리드 입력 상한이 DDL 폭과 같은지 본다.
#
# 개발자: 박승우
# 일자: 2026-09-04
# 코멘트:
#   1) *Rule.ts 의 maxLength 와 00_ddl.sql 의 varchar(N) 을 대조한다
#   2) 야간 감시(haccp-audit)와 커밋 전에 돌린다
#   3) 어긋나거나 상한이 없으면 종료코드 1
#
# 왜 있나: 화면 상한과 표 폭은 같은 수여야 한다. 한쪽만 고치면
# 22001 이 그대로 사용자에게 뜨거나(폭을 좁힌 경우) 쓸 수 있는 칸이 좁아진다(넓힌 경우).
# 이 계열이 이 저장소에서 네 번 났다 — docs/4_명명과_경로.md 10절.
#
# 짝은 scripts/_grid_maxlength_diff.py 의 MAP 에 있다. 편집 가능한 문자 칸을
# 새로 만들면 거기에 한 줄 더한다.
set -u
cd "$(dirname "$0")/.."

python "$(dirname "$0")/_grid_maxlength_diff.py"
RC=$?
if [ $RC -ne 0 ]; then
  echo "audit_grid_maxlength: 화면 상한과 표 폭이 어긋났다 — 둘을 같이 고쳐라"
  exit 1
fi
echo "audit_grid_maxlength OK"
