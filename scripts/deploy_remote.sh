#!/usr/bin/env bash
# ============================================================
#  prod 원격 배포 — rsync compose/nginx 후 pull && up
#
#  개발자: 박승우
#  일자: 2026-08-10
#  코멘트:
#    1) Jenkins Deploy 스테이지에서 SSH 키·호스트·TAG 를 받아 호출한다
#    2) .env.docker 는 서버에만 둔다 — 이 스크립트가 시크릿을 전송하지 않는다
#    3) conf 는 haccp.conf.template — 이미지 entrypoint 의 envsubst 가 치환한다
#
#  사용:
#    SSH_KEY=~/.ssh/id_rsa bash scripts/deploy_remote.sh deploy 10.0.0.10 /opt/haccp 1.0.12
# ============================================================
set -euo pipefail

USER="${1:?user}"
HOST="${2:?host}"
DIR="${3:?deploy_dir}"
TAG="${4:?tag}"
SSH_KEY="${SSH_KEY:?SSH_KEY not set}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH=(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes)
RSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

echo ">>> rsync compose · nginx template → $USER@$HOST:$DIR"
"${SSH[@]}" "$USER@$HOST" "mkdir -p '$DIR/nginx'"
rsync -az -e "$RSH" \
  "$ROOT/docker-compose.prod.yml" \
  "$USER@$HOST:$DIR/"
rsync -az -e "$RSH" \
  "$ROOT/nginx/haccp.conf.template" \
  "$USER@$HOST:$DIR/nginx/"

echo ">>> remote pull & up TAG=$TAG"
# .env.docker 는 서버 /opt/haccp 에 root:root 0600 으로 미리 배치되어 있어야 한다
"${SSH[@]}" "$USER@$HOST" "cd '$DIR' && \
  export TAG='$TAG' && \
  docker compose --env-file .env.docker -f docker-compose.prod.yml pull && \
  docker compose --env-file .env.docker -f docker-compose.prod.yml up -d && \
  docker image prune -f"

echo "deploy_remote OK — $HOST TAG=$TAG"
