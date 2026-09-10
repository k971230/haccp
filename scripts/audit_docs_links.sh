#!/usr/bin/env bash
# ============================================================
#  문서 상대 링크 무결성 — 저장소 전체 *.md
#
#  개발자: 박승우
#  일자: 2026-09-10
#  코멘트:
#    1) git 추적·미무시 *.md 전부. docs/ 국한하지 않는다. grokbot 등 로컬 전용은 제외
#    2) mes-web 경로 세그먼트·옛 파일명 구동.md 만 WARN. 부분 문자열 금지
#    3) 존재하지 않는 저장소 내 링크만 FAIL
#  호출처: Jenkinsfile.audit · 04.배포.md §6
#  성공: 깨진 상대링크 0. 실패: 누락 경로 나열 + exit 1
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python - <<'PY'
import os, re, subprocess, sys
root = os.getcwd()
fail = 0
link_re = re.compile(r'\]\((\.\.?/[^)]+)\)')
skip_prefix = ("http://", "https://", "mailto:")
# 빌드·의존성 조각 — git ls-files 가 이미 무시하지만 경로로 한 번 더 걸른다
skip_dir_names = {
    "node_modules", ".git", "target", "dist",
    "playwright-report", "test-results",
}
# basename 정확 일치만 WARN — "배포.md" 부분일치는 쓰지 않는다
warn_basenames = {"구동.md"}
# 경로 세그먼트 정확 일치만 WARN
warn_segments = {"mes-web"}

# 추적·미무시 미추적만. grokbot 같은 로컬 전용은 .gitignore 로 빠진다
listed = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.md"],
    cwd=root, text=True, encoding="utf-8",
)
files = []
for rel_file in listed.splitlines():
    rel_file = rel_file.strip().replace("\\", "/")
    if not rel_file.endswith(".md"):
        continue
    parts = rel_file.split("/")
    if any(p in skip_dir_names for p in parts):
        continue
    # docs/templates 양식 원문 — README 가 있어도 건너뛴다
    if len(parts) >= 2 and parts[0] == "docs" and parts[1] == "templates":
        continue
    files.append(os.path.join(root, rel_file.replace("/", os.sep)))

def is_warn_only(rel, resolved_posix):
    base = os.path.basename(rel.split("#", 1)[0])
    if base in warn_basenames:
        return True
    parts = resolved_posix.replace("\\", "/").split("/")
    return any(seg in warn_segments for seg in parts)

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
        if is_warn_only(rel, rel_posix):
            print(f"WARN: {os.path.relpath(path, root)} → {rel}")
            continue
        print(f"깨진 링크: {os.path.relpath(path, root)} → {rel}")
        fail += 1

if fail:
    print("audit_docs_links FAIL")
    sys.exit(1)
print("audit_docs_links OK")
PY
