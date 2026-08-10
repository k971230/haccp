# ============================================================
#  haccp-web 컨테이너 이미지 — Vite 5 빌드 산출물을 nginx 로 정적 서빙
#
#  개발자: 박승우
#  일자: 2026-08-10
#  코멘트:
#    1) 빌드(node)와 서빙(nginx)을 나눠 실행 이미지에 소스·node_modules 를 남기지 않는다
#    2) API 주소는 동일출처로 굽는다 — edge nginx 가 /api 를 haccp-api 로 넘긴다
#    3) 최종 스테이지는 nginx-unprivileged(uid 101) 라 8080 을 쓴다 (root·80 금지)
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
# edge nginx 가 /api 를 API 컨테이너로 넘긴다. 그래서 이미지 하나를 전 환경에서 재사용할 수 있다.
# 환경별로 절대 주소를 굽고 싶으면 --build-arg VITE_API_BASE_URL=https://... 로 덮는다.
# Vite 는 셸 환경변수의 VITE_* 를 .env 파일보다 우선 반영하므로 ENV 만으로 충분하다
ARG VITE_API_BASE_URL=""
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

# 타임아웃·그리드 등 나머지 VITE_* 는 envConfig.ts 에 코드 기본값이 있어 주입하지 않는다
RUN npm run build

# ------------------------------------------------------------
# 스테이지 B — 정적 서빙
# ------------------------------------------------------------
FROM nginxinc/nginx-unprivileged:1.27-alpine

# 공식 nginx 이미지는 80 을 열려고 master 를 root 로 띄운다.
# unprivileged 판은 uid 101 로만 돌아가는 대신 기본 리슨이 8080 이다
COPY --from=build /workspace/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

# alpine busybox wget — 이미지에 curl 을 추가로 넣지 않기 위해서다.
# localhost 는 IPv6(::1)로 풀리는 경우가 있는데 nginx 는 IPv4 만 리슨하므로 127.0.0.1 을 쓴다
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O - http://127.0.0.1:8080/ >/dev/null || exit 1
