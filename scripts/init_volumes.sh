#!/usr/bin/env bash
# ============================================================
#  HACCP 볼륨 초기화 — 표준 양식 원본 시드 + 소유권 정렬
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) docker compose up 보다 먼저 돌려야 한다 — 양식 볼륨이 비면 api 가 기동 중단된다
#    2) 매니페스트 required=Y 원본을 haccp-templates 볼륨에 원본 파일명 그대로 넣는다
#       (api 가 기동 시 APP_FILE_ROOT/HaccpTemplates/{tmpl_cd}/{target_name} 로 복사한다 — 여기는 평면 보관)
#    3) api uid 1000 non-root 라 볼륨 소유자를 1000:1000 으로 맞춘다
#  호출처: 런북 §9 · compose 선행 · 서버/로컬 수동. 원본 기본 경로: docs/templates/
#  성공: external 볼륨 시드. 실패: SRC·매니페스트 부재 또는 docker 오류
#
#  사용:
#    bash scripts/init_volumes.sh
#    HACCP_TEMPLATE_SRC=/srv/haccp/hwp bash scripts/init_volumes.sh
# ============================================================
set -euo pipefail

# Git Bash(MSYS)가 컨테이너 쪽 경로(/v, /src)까지 Windows 경로로 바꿔 버리는 것을 막는다
export MSYS_NO_PATHCONV=1

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# 원본 HWP 디렉터리 — 기본은 docs/templates (매니페스트 required=Y 만 둔다). 서버는 HACCP_TEMPLATE_SRC 로 덮을 수 있다
SRC="${HACCP_TEMPLATE_SRC:-$ROOT/docs/templates}"
MANIFEST="$ROOT/backend/haccp-api/src/main/resources/templates/manifest.tsv"

# 도커는 MSYS 형식(/d/haccp)을 모른다 — Windows 에서는 D:\haccp 형태로 바꿔 넘긴다
host_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

[ -d "$SRC" ]      || { echo "원본 디렉터리가 없습니다: $SRC" >&2; exit 1; }
[ -f "$MANIFEST" ] || { echo "매니페스트가 없습니다: $MANIFEST" >&2; exit 1; }

# ------------------------------------------------------------
# 1. 사전 점검 — 하나라도 없으면 복사 전에 멈춘다.
#    반쯤 채워진 볼륨으로 up 하면 api 가 기동 도중에 죽어 원인 찾기가 더 어렵다
# ------------------------------------------------------------
echo ">>> 필수 양식 원본 점검: $SRC"
missing=0
required=0
while IFS=$'\t' read -r cd src tgt req; do
  case "$cd" in \#*|"") continue ;; esac
  [ "${req%$'\r'}" = "Y" ] || continue
  required=$((required + 1))
  if [ ! -f "$SRC/$src" ]; then
    echo "    누락 [$cd] $src" >&2
    missing=$((missing + 1))
  fi
done < "$MANIFEST"

if [ "$missing" -gt 0 ]; then
  echo "필수 양식 $missing 건이 없습니다. 원본을 채운 뒤 다시 실행하세요." >&2
  exit 1
fi
echo "    required=Y $required 건 확인"

# ------------------------------------------------------------
# 2. 볼륨 생성 — 이미 있으면 그대로 둔다 (멱등)
# ------------------------------------------------------------
echo ">>> 볼륨 생성"
docker volume create haccp-files     >/dev/null
docker volume create haccp-templates >/dev/null

# ------------------------------------------------------------
# 3. 시드 + 소유권 — 컨테이너 안에서 복사해야 uid 1000 소유로 남길 수 있다
# ------------------------------------------------------------
echo ">>> 양식 원본 복사"
docker run --rm -i \
  -v haccp-templates:/v \
  -v "$(host_path "$SRC")":/src:ro \
  -v "$(host_path "$MANIFEST")":/manifest.tsv:ro \
  busybox sh -s <<'INNER'
set -e
# 매니페스트가 CRLF 로 저장돼도 필드 비교가 깨지지 않게 캐리지리턴을 걷어낸다
tr -d '\r' < /manifest.tsv > /tmp/manifest.tsv
copied=0
while IFS="$(printf '\t')" read -r cd src tgt req; do
  case "$cd" in \#*|"") continue ;; esac
  [ "$req" = "Y" ] || continue
  cp -f "/src/$src" "/v/$src"
  copied=$((copied + 1))
done < /tmp/manifest.tsv
# api 컨테이너의 실행 계정과 맞춘다
chown -R 1000:1000 /v
echo "    복사 완료: ${copied}건"
INNER

echo ">>> 업로드 볼륨 소유권 정렬"
docker run --rm -v haccp-files:/v busybox chown -R 1000:1000 /v

echo "초기화 완료 — haccp-templates · haccp-files"
