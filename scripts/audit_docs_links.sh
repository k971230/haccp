#!/usr/bin/env bash
# ============================================================
#  문서 상대 링크 무결성 — 루트 docs/ 정본만 검사
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) 루트 docs/1_~n_ · docs/README.md 링크를 본다
#    2) mes-web·분리 잔존 md 로의 링크는 경고만
#    3) 존재하지 않는 저장소 내 링크만 FAIL
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python - <<'PY'
import os, re, sys
root = os.getcwd()
fail = 0
link_re = re.compile(r'\]\((\.\.?/[^)]+)\)')
skip_prefix = ("http://", "https://", "mailto:")

files = []
base = os.path.join(root, "docs")
if os.path.isdir(base):
    for dp, _, fns in os.walk(base):
        if os.path.basename(dp) == "templates":
            continue
        for n in fns:
            if n.endswith(".md"):
                files.append(os.path.join(dp, n))

for path in files:
    text = open(path, encoding="utf-8", errors="replace").read()
    for m in link_re.finditer(text):
        rel = m.group(1).split("#", 1)[0]
        if not rel or rel.startswith(skip_prefix):
            continue
        if not rel.endswith((".md", ".mdc")):
            continue
        resolved = os.path.normpath(os.path.join(os.path.dirname(path), rel))
        if os.path.isfile(resolved):
            continue
        rel_posix = resolved.replace("\\", "/")
        if any(p in rel_posix or p in rel for p in ("mes-web", "구동.md", "배포.md")):
            print(f"WARN: {os.path.relpath(path, root)} → {rel}")
            continue
        print(f"깨진 링크: {os.path.relpath(path, root)} → {rel}")
        fail += 1

if fail:
    print("audit_docs_links FAIL")
    sys.exit(1)
print("audit_docs_links OK")
PY
