#!/usr/bin/env bash
# ============================================================
#  prod 원격 배포 — rsync compose/nginx 후 pull && up
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) Jenkins Deploy 스테이지에서 SSH 키·호스트·TAG 를 받아 호출한다
#    2) .env.docker 는 서버에만 둔다 — 이 스크립트가 시크릿을 전송하지 않는다 (gitignore)
#    3) conf 는 haccp.conf.template — 이미지 entrypoint 의 envsubst 가 치환한다
#  호출처: Jenkinsfile Deploy → scripts/deploy_remote.sh
#  성공: 원격 compose pull·up 완료. 실패: SSH/rsync/compose non-zero
#
#  사용:
#    SSH_KEY=~/.ssh/id_rsa bash scripts/deploy_remote.sh deploy 10.0.0.10 /home/ubuntu/haccp 1.0.12
# ============================================================
set -euo pipefail
# Windows Git Bash 가 /home/... 인자를 로컬 경로로 치환하지 않게 한다
export MSYS_NO_PATHCONV=1

USER="${1:?user}"
HOST="${2:?host}"
DIR="${3:?deploy_dir}"
TAG="${4:?tag}"
SSH_KEY="${SSH_KEY:?SSH_KEY not set}"

# Git Bash 가 /home 을 로컬로 바꿀 수 있어, 인자가 //home 또는 /home 이면 //home 으로 정규화한다
REMOTE_DIR="$DIR"
case "$REMOTE_DIR" in
  //home/*|//opt/*) ;;
  /home/*|/opt/*) REMOTE_DIR="/${REMOTE_DIR}" ;;
  *Git/home/*|*Git\\home\\*) REMOTE_DIR="//home/ubuntu/haccp" ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH=(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes)
RSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

echo ">>> sync compose · nginx · override 예시 → $USER@$HOST:$REMOTE_DIR"
"${SSH[@]}" "$USER@$HOST" "mkdir -p '${REMOTE_DIR}/nginx'"
# Windows Git Bash 에는 rsync 가 없는 경우가 많다 — 있으면 rsync, 없으면 scp
if command -v rsync >/dev/null 2>&1; then
  rsync -az -e "$RSH" \
    "$ROOT/docker-compose.prod.yml" \
    "$ROOT/docker-compose.override.example.yml" \
    "$USER@$HOST:${REMOTE_DIR}/"
  rsync -az -e "$RSH" \
    "$ROOT/nginx/haccp.conf.template" \
    "$ROOT/nginx/apache-haccp-gateway.conf.example" \
    "$USER@$HOST:${REMOTE_DIR}/nginx/"
else
  echo ">>> rsync 없음 — scp 로 전송"
  scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
    "$ROOT/docker-compose.prod.yml" \
    "$ROOT/docker-compose.override.example.yml" \
    "$USER@$HOST:${REMOTE_DIR}/"
  scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
    "$ROOT/nginx/haccp.conf.template" \
    "$ROOT/nginx/apache-haccp-gateway.conf.example" \
    "$USER@$HOST:${REMOTE_DIR}/nginx/"
fi

echo ">>> remote pull & up TAG=$TAG"
# .env.docker 는 서버에 미리 배치한다(시크릿 미전송).
# docker-compose.override.yml 이 있으면(= 호스트 :80 점유 우회 등) 함께 넘긴다 — 없으면 prod.yml 만.
# GHCR private 패키지이면 REG_USER/REG_PASS 로 원격 login 후 pull 한다 (비밀번호는 stdin).
if [ -n "${REG_USER:-}" ] && [ -n "${REG_PASS:-}" ]; then
  echo ">>> remote docker login ghcr.io"
  printf '%s' "$REG_PASS" | "${SSH[@]}" "$USER@$HOST" \
    "docker login ghcr.io -u $(printf '%q' "$REG_USER") --password-stdin"
fi
"${SSH[@]}" "$USER@$HOST" "cd '${REMOTE_DIR}' && \
  export TAG='$TAG' && \
  COMPOSE_FILES='-f docker-compose.prod.yml' && \
  if [ -f docker-compose.override.yml ]; then COMPOSE_FILES=\"\$COMPOSE_FILES -f docker-compose.override.yml\"; fi && \
  docker compose --env-file .env.docker \$COMPOSE_FILES pull && \
  docker compose --env-file .env.docker \$COMPOSE_FILES up -d && \
  docker image prune -f"
if [ -n "${REG_USER:-}" ] && [ -n "${REG_PASS:-}" ]; then
  "${SSH[@]}" "$USER@$HOST" "docker logout ghcr.io >/dev/null 2>&1 || true"
fi

echo "deploy_remote OK — $HOST TAG=$TAG"
