#!/usr/bin/env bash
# ============================================================
#  Apache Path 전환 ops — override·CORS·CLOSE 검증 (서버에서 실행)
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) 새 이미지(TAG, 내부 7070) pull 이후에 실행한다
#    2) override 를 17070 단권으로 쓰고 8080/8443 CLOSE 를 확인한다
#    3) Apache conf·cert 는 별도(예: nginx/apache-haccp-gateway.conf.example)
#
#  사용 (서버 /home/ubuntu/haccp):
#    TAG=1.0.14 bash scripts/ops_path_gateway_cutover.sh
# ============================================================
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"
TAG="${TAG:?TAG not set (예: 1.0.14)}"
PUBLIC_IP="${PUBLIC_IP:-180.71.58.87}"

echo ">>> 1) override → 127.0.0.1:17070:7070 단권"
cat > docker-compose.override.yml <<'YAML'
services:
  edge:
    ports: !override
      - "127.0.0.1:17070:7070"
YAML

echo ">>> 2) CORS :8443 제거 (있으면)"
if [ -f .env.docker ]; then
  # 백업 후 비표준 포트 origin 줄만 정리 안내 — 값은 운영자가 최종 확인
  cp -a .env.docker ".env.docker.bak.$(date +%Y%m%d%H%M%S)"
  if grep -q 'CORS_ALLOWED_ORIGINS=' .env.docker; then
    echo "    현재 CORS_ALLOWED_ORIGINS=$(grep '^CORS_ALLOWED_ORIGINS=' .env.docker | head -1)"
    echo "    기대: CORS_ALLOWED_ORIGINS=https://${PUBLIC_IP},http://${PUBLIC_IP}"
    echo "    (.env.docker 를 위 값으로 맞춘 뒤 이 스크립트를 다시 돌리거나 api 를 재기동)"
  fi
fi

echo ">>> 3) compose up TAG=$TAG"
export TAG
COMPOSE=(docker compose --env-file .env.docker -f docker-compose.prod.yml -f docker-compose.override.yml)
"${COMPOSE[@]}" pull
"${COMPOSE[@]}" up -d
"${COMPOSE[@]}" ps

echo ">>> 4) CLOSE 검증 — 8080/8443 에 docker-proxy 없어야 함"
if ss -lntp 2>/dev/null | egrep ':8080|:8443'; then
  echo "FAIL: 8080 또는 8443 이 아직 LISTEN 중" >&2
  exit 1
fi
echo "    ss: 8080/8443 없음 OK"

echo ">>> 5) 루프백 edge healthz"
curl -fsS --max-time 5 "http://127.0.0.1:17070/healthz" | grep -q ok
echo "    17070/healthz OK"

echo ">>> 6) 외부 CLOSE (기대: 실패/거부)"
set +e
curl -vk --connect-timeout 3 "http://${PUBLIC_IP}:8080/" >/tmp/haccp-close-8080.txt 2>&1
c8080=$?
curl -vk --connect-timeout 3 "https://${PUBLIC_IP}:8443/" >/tmp/haccp-close-8443.txt 2>&1
c8443=$?
set -e
echo "    curl :8080 exit=${c8080} · :8443 exit=${c8443} (0 이면 아직 열려 있음 → FAIL)"
if [ "$c8080" -eq 0 ] || [ "$c8443" -eq 0 ]; then
  echo "FAIL: 우회 포트가 외부에서 응답함" >&2
  exit 1
fi

echo "cutover base OK — Apache gateway conf 적용·reload 후 prod_smoke.sh https://${PUBLIC_IP} 실행"
