#!/usr/bin/env bash
# ============================================================
#  문서 상대 링크 무결성 — 추적 대상 docs 만 검사
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) FE/BE docs 와 루트 런북(12_배포_런북.md)만 본다 — 로컬 전용 docs/* 는 제외
#    2) mes-web·루트 로컬 md 로의 링크는 경고만 (모노레포 분리 잔존)
#    3) 존재하지 않는 저장소 내 링크만 FAIL
#  호출처: Jenkinsfile.audit · 런북 §19
#  성공: 깨진 상대링크 0. 실패: 누락 경로 나열 + exit 1
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
# 저장소 밖·로컬 전용·분리된 MES 문서
warn_parts = ("mes-web", "구동.md", "배포.md", os.path.join("docs", ""))

files = []
for base in (
    os.path.join(root, "frontend", "haccp-web", "docs"),
    os.path.join(root, "backend", "haccp-api", "docs"),
):
    if os.path.isdir(base):
        for dp, _, fns in os.walk(base):
            for n in fns:
                if n.endswith(".md"):
                    files.append(os.path.join(dp, n))
runbook = os.path.join(root, "docs", "12_배포_런북.md")
if os.path.isfile(runbook):
    files.append(runbook)

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
        if any(p.replace("\\", "/") in rel_posix or p in rel for p in ("mes-web", "구동.md", "배포.md")):
            print(f"WARN: {os.path.relpath(path, root)} → {rel}")
            continue
        # 루트 docs/ 로컬 전용(런북 제외)으로 가는 링크
        docs_dir = os.path.join(root, "docs")
        if resolved.startswith(docs_dir + os.sep) and os.path.basename(resolved) != "12_배포_런북.md":
            print(f"WARN(로컬 docs): {os.path.relpath(path, root)} → {rel}")
            continue
        print(f"깨진 링크: {os.path.relpath(path, root)} → {rel}")
        fail += 1

if fail:
    print("audit_docs_links FAIL")
    sys.exit(1)
print("audit_docs_links OK")
PY
