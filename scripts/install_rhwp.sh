#!/usr/bin/env bash
# ============================================================
#  rhwp CLI 설치 — HWP/HWPX → PDF 변환기 (MIT, github.com/edwardkim/rhwp)
#
#  개발자: 박승우
#  일자: 2026-08-10
#  코멘트:
#    1) 바이너리를 이미지에 굽지 않고 haccp-rhwp 볼륨에 넣는다 — 버전 교체를 재빌드 없이 하기 위해서다
#    2) 릴리스의 SHA256SUMS.txt 로 무결성을 검증한 뒤에만 설치한다
#    3) api 컨테이너가 uid 1000 non-root 라 소유자를 1000:1000, 권한을 0755 로 맞춘다
#
#  사용:
#    bash scripts/install_rhwp.sh            # 기본 v0.8.2
#    bash scripts/install_rhwp.sh v0.9.0     # 버전 지정
# ============================================================
set -euo pipefail

export MSYS_NO_PATHCONV=1

# 버전은 인자 > env > 기본값 순 — 소스에 박지 않는다
VER="${1:-${RHWP_VERSION:-v0.8.2}}"
# glibc 기반 x86_64 리눅스 빌드. API 이미지가 jammy 라 그대로 실행된다 (alpine 이면 musl 이라 불가)
ASSET="rhwp-${VER}-linux-x86_64.tar.gz"
BASE="https://github.com/edwardkim/rhwp/releases/download/${VER}"
# 설치 검증에 쓸 이미지 — 이미 로컬에 있는 API 베이스라 추가 pull 이 없다
VERIFY_IMAGE="${RHWP_VERIFY_IMAGE:-eclipse-temurin:17-jre-jammy}"

host_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo ">>> 내려받기: $ASSET"
# -o 로 절대경로를 주면 Windows curl.exe 가 MSYS 경로(/tmp/...)를 못 읽어 실패한다.
# 디렉터리로 먼저 이동해 -O(원격 파일명 그대로 저장)를 쓰면 경로 표기 차이를 타지 않는다
( cd "$TMP" && curl -fLsS -O "$BASE/$ASSET" && curl -fLsS -O "$BASE/SHA256SUMS.txt" )

echo ">>> 무결성 검증"
# sha256sum -c 는 파일명이 목록과 같아야 하므로 자산 이름 그대로 저장해 둔다
( cd "$TMP" && grep -F "$ASSET" SHA256SUMS.txt | sha256sum -c - )

echo ">>> 압축 해제"
tar xzf "$TMP/$ASSET" -C "$TMP"
[ -f "$TMP/rhwp/rhwp" ] || { echo "압축 안에 rhwp 실행 파일이 없습니다." >&2; exit 1; }

echo ">>> 볼륨 설치"
docker volume create haccp-rhwp >/dev/null
docker run --rm \
  -v haccp-rhwp:/v \
  -v "$(host_path "$TMP/rhwp")":/src:ro \
  busybox sh -c 'cp -f /src/rhwp /v/rhwp && chmod 0755 /v/rhwp && chown -R 1000:1000 /v'

echo ">>> 설치 검증"
# 실제 실행까지 확인한다 — 여기서 통과하면 glibc·실행비트 문제는 없다
docker run --rm -v haccp-rhwp:/opt/rhwp:ro "$VERIFY_IMAGE" /opt/rhwp/rhwp --version

echo "rhwp ${VER} 설치 완료 — 볼륨 haccp-rhwp (컨테이너 경로 /opt/rhwp/rhwp)"
