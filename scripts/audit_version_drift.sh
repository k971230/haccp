#!/usr/bin/env bash
# ============================================================
#  버전 drift — 문서에 적힌 스택 버전 vs package.json / pom.xml
#
#  개발자: 박승우
#  일자: 2026-08-10
#  코멘트:
#    1) React·Vite·Spring Boot 메이저.마이너 가 문서와 코드에서 어긋나면 실패한다
#    2) 소스는 고치지 않는다 — 경고만 내고 exit 1
#    3) nightly Jenkinsfile.audit 에서 호출한다
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
cd "$ROOT"

pkg_react="$(node -p "require('./frontend/haccp-web/package.json').dependencies.react.replace(/^[^\d]*/,'')")"
pkg_vite="$(node -p "require('./frontend/haccp-web/package.json').devDependencies.vite.replace(/^[^\d]*/,'')")"
pom_boot="$(grep -A1 'spring-boot-starter-parent' backend/haccp-api/pom.xml | grep '<version>' | head -1 | sed -E 's/.*<version>([^<]+)<.*/\1/')"

echo "코드: react=$pkg_react vite=$pkg_vite spring-boot=$pom_boot"

react_mm="$(echo "$pkg_react" | grep -Eo '^[0-9]+\.[0-9]+')"
vite_mm="$(echo "$pkg_vite" | grep -Eo '^[0-9]+\.[0-9]+')"
boot_mm="$(echo "$pom_boot" | grep -Eo '^[0-9]+\.[0-9]+')"

check_readme() {
  local label="$1" pattern="$2" mm="$3"
  if ! grep -Eq "$pattern" README.md; then
    echo "README 에 $label 표기 없음 (기대 major.minor=$mm)"
    fail=1
    return
  fi
  echo "OK $label (~$mm)"
}

check_readme "React" 'React[[:space:]]*18' "$react_mm"
check_readme "Vite" 'Vite[[:space:]]*5' "$vite_mm"
check_readme "Spring Boot" 'Spring Boot[[:space:]]*3\.3' "$boot_mm"

# 코드 자체가 기대 major 와 같은지 (문서가 18/5/3.3 을 말할 때)
case "$react_mm" in 18.*) ;; *) echo "react major 예상 18 실제 $react_mm"; fail=1 ;; esac
case "$vite_mm" in 5.*) ;; *) echo "vite major 예상 5 실제 $vite_mm"; fail=1 ;; esac
case "$boot_mm" in 3.3) ;; *) echo "spring-boot 예상 3.3 실제 $boot_mm"; fail=1 ;; esac

if [ "$fail" -ne 0 ]; then
  echo "audit_version_drift FAIL"
  exit 1
fi
echo "audit_version_drift OK"
