#!/usr/bin/env bash
# ============================================================
#  HACCP 이미지 3종 빌드 — api · web · nginx
#
#  개발자: 박승우
#  일자: 2026-08-10
#  코멘트:
#    1) Jenkins Build images 스테이지에서 TAG 인자를 받아 로컬에 태그를 단다
#    2) REGISTRY·IMAGE_* 는 호출 환경(Jenkins environment)에서 받는다
#    3) push 는 이 스크립트 밖(Jenkins Push 스테이지)에서 한다
#
#  사용: bash scripts/build_images.sh 1.0.12
# ============================================================
set -euo pipefail

TAG="${1:?usage: build_images.sh <TAG>}"
REGISTRY="${REGISTRY:-ghcr.io/k971230}"
IMAGE_API="${IMAGE_API:-${REGISTRY}/haccp-api}"
IMAGE_WEB="${IMAGE_WEB:-${REGISTRY}/haccp-web}"
IMAGE_NGX="${IMAGE_NGX:-${REGISTRY}/haccp-nginx}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo ">>> build $IMAGE_API:$TAG"
docker build -t "$IMAGE_API:$TAG" -f backend/haccp-api/Dockerfile backend/haccp-api

echo ">>> build $IMAGE_WEB:$TAG"
docker build -t "$IMAGE_WEB:$TAG" -f frontend/haccp-web/Dockerfile frontend/haccp-web

echo ">>> build $IMAGE_NGX:$TAG"
docker build -t "$IMAGE_NGX:$TAG" -f nginx/Dockerfile nginx

echo "build_images OK — TAG=$TAG"
