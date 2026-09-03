#!/usr/bin/env bash
# ============================================================
#  audit_generated_docs — 생성 문서가 소스와 어긋났는지 본다
#
#  개발자: 박승우
#  일자: 2026-08-27
#  코멘트:
#    1) 화면 지도·PIPELINE 색인·SP 색인·테이블 레이아웃은 생성기가 만든다 — 손으로 고치면 지워진다
#    2) 소스를 고치고 다시 안 뽑으면 표가 조용히 낡는다. 그걸 여기서 잡는다
#    3) node 가 없으면 건너뛰지 않고 실패한다 — 건너뛰는 검사는 검사가 아니다
#
#  쓰기: bash scripts/audit_generated_docs.sh
# ============================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v node >/dev/null 2>&1; then
    echo "audit_generated_docs: node 가 없다 — 생성 문서를 검사할 수 없다" >&2
    exit 1
fi

fail=0
for gen in gen_screen_map gen_pipeline_index gen_sp_index gen_table_layout gen_index; do
    if ! node "scripts/$gen.mjs" --check; then
        # 어느 생성기가 어긋났는지 그대로 보여 준다 — 고치는 명령이 그 안에 있다
        fail=1
    fi
done

if [ "$fail" -ne 0 ]; then
    echo "audit_generated_docs: 생성 문서가 소스와 어긋났다" >&2
    exit 1
fi
echo "audit_generated_docs: OK"
