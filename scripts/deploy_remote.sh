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
# Windows Git Bash 가 /home/... 인자를 로컬 경로로 치환하지 않게 한다
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

USER="${1:?user}"
HOST="${2:?host}"
DIR="${3:?deploy_dir}"
TAG="${4:?tag}"
SSH_KEY="${SSH_KEY:?SSH_KEY not set}"

# Git Bash 경로 변환 회피 — 원격 Linux 절대경로를 // 로 시작한다
REMOTE_DIR="$DIR"
case "$REMOTE_DIR" in
  /home/*|/opt/*) REMOTE_DIR="/${REMOTE_DIR}" ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH=(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes)
RSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

echo ">>> rsync compose · nginx template → $USER@$HOST:$REMOTE_DIR"
"${SSH[@]}" "$USER@$HOST" "mkdir -p '${REMOTE_DIR}/nginx'"
rsync -az -e "$RSH" \
  "$ROOT/docker-compose.prod.yml" \
  "$USER@$HOST:${REMOTE_DIR}/"
rsync -az -e "$RSH" \
  "$ROOT/nginx/haccp.conf.template" \
  "$USER@$HOST:${REMOTE_DIR}/nginx/"

echo ">>> remote pull & up TAG=$TAG"
# .env.docker 는 서버에 미리 배치한다(시크릿 미전송).
# docker-compose.override.yml 이 있으면(= 호스트 :80 점유 우회 등) 함께 넘긴다 — 없으면 prod.yml 만.
"${SSH[@]}" "$USER@$HOST" "cd '${REMOTE_DIR}' && \
  export TAG='$TAG' && \
  COMPOSE_FILES='-f docker-compose.prod.yml' && \
  if [ -f docker-compose.override.yml ]; then COMPOSE_FILES=\"\$COMPOSE_FILES -f docker-compose.override.yml\"; fi && \
  docker compose --env-file .env.docker \$COMPOSE_FILES pull && \
  docker compose --env-file .env.docker \$COMPOSE_FILES up -d && \
  docker image prune -f"

echo "deploy_remote OK — $HOST TAG=$TAG"
