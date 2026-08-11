#!/usr/bin/env bash
# ============================================================
#  자체 서명 인증서 발급 — 도메인·Let's Encrypt 없이 edge 를 띄우기 위한 임시 인증서
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) edge 는 인증서 없으면 기동 불가 — 로컬 검증·certbot 전 서버용
#    2) certbot 과 같은 live/{도메인}/fullchain.pem·privkey.pem 배치로 conf 재사용
#    3) 브라우저 경고는 정상. 운영 도메인 생기면 certbot 으로 교체
#  호출처: 런북 §10 · 로컬 compose 선행
#  성공: CERT_ROOT 아래 pem 생성. 실패: openssl/경로 오류
#
#  사용:
#    HACCP_CERT_HOST_DIR=./certs bash scripts/gen_selfsigned.sh
# ============================================================
set -euo pipefail

export MSYS_NO_PATHCONV=1

# 인증서를 둘 호스트 경로 — compose 가 이 디렉터리를 /etc/letsencrypt 로 마운트한다
CERT_ROOT="${HACCP_CERT_HOST_DIR:-./certs}"
# 인증서 CN·SAN 과 conf 의 server_name 이 같아야 한다
NAME="${HACCP_SERVER_NAME:-haccp.example.com}"
# 자체 서명 유효기간 — 브라우저가 825일을 넘는 인증서를 거부하므로 그 안쪽으로 둔다
DAYS="${HACCP_CERT_DAYS:-825}"

TARGET="$CERT_ROOT/live/$NAME"
mkdir -p "$TARGET"

if [ -f "$TARGET/fullchain.pem" ] && [ -f "$TARGET/privkey.pem" ]; then
  echo "이미 인증서가 있습니다: $TARGET (덮어쓰려면 파일을 지우고 다시 실행)"
  exit 0
fi

# localhost·127.0.0.1 을 SAN 에 함께 넣는다 — 로컬 검증에서 curl 대상이 localhost 이기 때문이다
SAN="subjectAltName=DNS:$NAME,DNS:localhost,IP:127.0.0.1"

if command -v openssl >/dev/null 2>&1; then
  openssl req -x509 -newkey rsa:2048 -nodes -days "$DAYS" \
    -keyout "$TARGET/privkey.pem" -out "$TARGET/fullchain.pem" \
    -subj "/CN=$NAME" -addext "$SAN" 2>/dev/null
else
  # openssl 이 없는 환경(일부 Windows)에서는 컨테이너로 대체한다
  echo ">>> 로컬 openssl 이 없어 컨테이너로 발급합니다"
  host_target="$TARGET"
  command -v cygpath >/dev/null 2>&1 && host_target="$(cygpath -w "$TARGET")"
  docker run --rm -v "$host_target":/out alpine/openssl req -x509 -newkey rsa:2048 -nodes \
    -days "$DAYS" -keyout /out/privkey.pem -out /out/fullchain.pem \
    -subj "/CN=$NAME" -addext "$SAN"
fi

echo "발급 완료: $TARGET"
echo "  HACCP_CERT_HOST_DIR=$CERT_ROOT · HACCP_CERT_DIR=/etc/letsencrypt/live/$NAME 로 맞춰 두세요."
