# ============================================================
#  haccp-web 컨테이너 이미지 — Vite 5 빌드 산출물을 nginx 로 정적 서빙
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) 빌드(node)와 서빙(nginx)을 나눠 실행 이미지에 소스·node_modules 를 남기지 않는다
#    2) API 는 동일출처 상대경로 — Apache /api/ → edge → api. Vite base=/haccp/ 로 Path 분기
#    3) nginx-unprivileged(uid 101) · 컨테이너 listen 7070 (edge upstream web:7070)
#
#  빌드: docker build -f frontend/haccp-web/Dockerfile -t haccp-web:local frontend/haccp-web
# ============================================================

# ------------------------------------------------------------
# 스테이지 A — 정적 자산 빌드
# ------------------------------------------------------------
FROM node:20-bookworm-slim AS build

WORKDIR /workspace

# 잠금파일 기준 재현 설치 — package.json 만 바뀌지 않으면 이 레이어가 캐시된다
COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# 동일출처 배포 — 빈 값이면 http.ts 의 baseURL 이 "" 가 되어 브라우저가 상대경로로 호출하고,
# Apache/edge 가 /api 를 API 컨테이너로 넘긴다.
ARG VITE_API_BASE_URL=""
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}
# 운영 Path 분기 — Apache /haccp/ 프리픽스. 로컬 npm run dev 는 vite 기본 base=/
ARG VITE_BASE=/haccp/
ENV VITE_BASE=${VITE_BASE}

# 타임아웃·그리드 등 나머지 VITE_* 는 envConfig.ts 에 코드 기본값이 있어 주입하지 않는다
RUN npm run build

# ------------------------------------------------------------
# 스테이지 B — 정적 서빙
# ------------------------------------------------------------
FROM nginxinc/nginx-unprivileged:1.27-alpine

# unprivileged · 컨테이너 내부 7070 (호스트 publish 없음)
COPY --from=build /workspace/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 7070

# alpine busybox wget — localhost(::1) 회피
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O - http://127.0.0.1:7070/ >/dev/null || exit 1
