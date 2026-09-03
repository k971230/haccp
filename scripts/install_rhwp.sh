#!/usr/bin/env bash
# ============================================================
#  rhwp CLI 설치 — HWP/HWPX → PDF 변환기 (MIT, github.com/edwardkim/rhwp)
#
#  개발자: 박승우
#  일자: 2026-09-03
#  코멘트:
#    1) 바이너리를 이미지에 굽지 않는다 — Docker 는 haccp-rhwp 볼륨, 로컬 IntelliJ 는 tools/rhwp
#    2) 릴리스 SHA256SUMS.txt 로 무결성 검증 후에만 설치한다
#    3) Windows Git Bash 에서는 exe 와 (docker 가 떠 있으면) 리눅스 볼륨을 같이 깐다
#  호출처: DEPLOY.md §1 · 로컬 HWP PDF(문서함 인쇄) 선행
#  성공: 해당 환경에서 rhwp 실행 가능. 실패: 다운로드·SHA·필수 대상 설치 오류
#
#  사용:
#    bash scripts/install_rhwp.sh            # 기본 v0.8.4 (@rhwp/editor 와 같은 태그)
#    bash scripts/install_rhwp.sh v0.9.0     # 버전 지정
# ============================================================
set -euo pipefail

export MSYS_NO_PATHCONV=1

# 버전은 인자 > env > 기본값 순 — 소스에 박지 않는다
VER="${1:-${RHWP_VERSION:-v0.8.4}}"
BASE="https://github.com/edwardkim/rhwp/releases/download/${VER}"
# glibc 2.39+ x86_64 리눅스 빌드 (rhwp v0.8.4). API 실행 이미지는 noble. alpine 이면 musl 이라 불가
LINUX_ASSET="rhwp-${VER}-linux-x86_64.tar.gz"
WIN_ASSET="rhwp-${VER}-windows-x86_64.zip"
# 설치 검증 — 실행 이미지와 같은 glibc. jammy(2.35) 는 v0.8.4 CLI 가 안 뜬다
VERIFY_IMAGE="${RHWP_VERIFY_IMAGE:-eclipse-temurin:17-jre-noble}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST_DIR="${RHWP_HOST_DIR:-$ROOT/tools/rhwp}"

host_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

is_windows() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

docker_ready() {
  command -v docker >/dev/null 2>&1 || return 1
  docker info >/dev/null 2>&1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo ">>> 내려받기: SHA256SUMS.txt (${VER})"
( cd "$TMP" && curl -fLsS -O "$BASE/SHA256SUMS.txt" )

download_verify() {
  # $1 릴리스 자산 파일명 — SHA256SUMS.txt 와 이름이 같아야 한다
  local asset="$1"
  echo ">>> 내려받기: $asset"
  ( cd "$TMP" && curl -fLsS -O "$BASE/$asset" )
  echo ">>> 무결성 검증: $asset"
  ( cd "$TMP" && grep -F "$asset" SHA256SUMS.txt | sha256sum -c - )
}

install_docker_linux() {
  download_verify "$LINUX_ASSET"
  echo ">>> 압축 해제 (linux)"
  tar xzf "$TMP/$LINUX_ASSET" -C "$TMP"
  [ -f "$TMP/rhwp/rhwp" ] || { echo "압축 안에 rhwp 실행 파일이 없습니다." >&2; return 1; }

  echo ">>> 볼륨 설치"
  docker volume create haccp-rhwp >/dev/null
  docker run --rm \
    -v haccp-rhwp:/v \
    -v "$(host_path "$TMP/rhwp")":/src:ro \
    busybox sh -c 'cp -f /src/rhwp /v/rhwp && chmod 0755 /v/rhwp && chown -R 1000:1000 /v'

  echo ">>> 설치 검증 (컨테이너)"
  # 실제 실행까지 확인한다 — 여기서 통과하면 glibc·실행비트 문제는 없다
  docker run --rm -v haccp-rhwp:/opt/rhwp:ro "$VERIFY_IMAGE" /opt/rhwp/rhwp --version
  echo "rhwp ${VER} Docker 설치 완료 — 볼륨 haccp-rhwp (/opt/rhwp/rhwp)"
}

install_host_windows() {
  download_verify "$WIN_ASSET"
  echo ">>> 압축 해제 (windows)"
  # Git Bash tar 는 zip 을 못 푼다. unzip(Git) 또는 PowerShell Expand-Archive
  if command -v unzip >/dev/null 2>&1; then
    unzip -o -q "$TMP/$WIN_ASSET" -d "$TMP"
  else
    powershell.exe -NoProfile -Command \
      "Expand-Archive -Force -Path '$(host_path "$TMP/$WIN_ASSET")' -DestinationPath '$(host_path "$TMP")'"
  fi
  [ -f "$TMP/rhwp/rhwp.exe" ] || { echo "압축 안에 rhwp.exe 가 없습니다." >&2; return 1; }

  echo ">>> 호스트 설치: $HOST_DIR"
  mkdir -p "$HOST_DIR"
  # zip 안의 rhwp/ 전체를 덮어쓴다 — dll 동반 파일이 있을 수 있다
  ( cd "$TMP/rhwp" && tar cf - . ) | ( cd "$HOST_DIR" && tar xf - )
  [ -f "$HOST_DIR/rhwp.exe" ] || { echo "호스트에 rhwp.exe 가 복사되지 않았습니다." >&2; return 1; }

  echo ">>> 설치 검증 (호스트)"
  "$HOST_DIR/rhwp.exe" --version
  echo "rhwp ${VER} 로컬 설치 완료 — $HOST_DIR/rhwp.exe"
  echo "IntelliJ .env 예: APP_RHWP_CLI_PATH=$(host_path "$HOST_DIR/rhwp.exe" | sed 's#\\#/#g')"
}

DOCKER_OK=0
HOST_OK=0

if is_windows; then
  install_host_windows
  HOST_OK=1
  if docker_ready; then
    install_docker_linux
    DOCKER_OK=1
  else
    echo ">>> docker 가 없거나 데몬이 꺼져 있어 컨테이너 CLI 는 건너뛴다"
    echo "    로컬 Docker 로 API 를 띄울 때는 Docker Desktop 기동 후 이 스크립트를 다시 실행한다"
  fi
else
  install_docker_linux
  DOCKER_OK=1
fi

echo "설치 요약 — 호스트=${HOST_OK} Docker=${DOCKER_OK}"
