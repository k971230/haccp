# ============================================================
#  haccp-nginx (edge) 컨테이너 이미지 — Apache 백엔드 · /api 리버스 프록시
#
#  개발자: 박승우
#  일자: 2026-08-11
#  코멘트:
#    1) 브라우저 공인 입구는 호스트 Apache(80/443)다 — edge 는 루프백 17070→7070 만
#    2) TLS·인증서는 edge 가 아니라 Apache(/etc/ssl/haccp/) 책임이다
#    3) nginx-unprivileged(uid 101) 라 컨테이너 listen 은 7070 이다
#
#  빌드: docker build -f nginx/Dockerfile -t haccp-nginx:local nginx
# ============================================================

FROM nginxinc/nginx-unprivileged:1.27-alpine

# templates → 기동 시 envsubst → /etc/nginx/conf.d/default.conf
COPY haccp.conf.template /etc/nginx/templates/default.conf.template

# 치환 기본값 — 배포에서는 compose environment 로 덮는다
ENV HACCP_SERVER_NAME=haccp.example.com
# edge 는 TLS 를 열지 않지만 기존 compose 변수명 호환을 위해 남겨 둔다
ENV HACCP_CERT_DIR=/etc/letsencrypt/live/haccp.example.com
ENV HACCP_ACTUATOR_ALLOW=127.0.0.1
ENV HACCP_RESOLVER=127.0.0.11

# $host·$remote_addr 등 nginx 변수를 빈 문자열로 지우지 않도록 접두어 제한
ENV NGINX_ENVSUBST_FILTER=^HACCP_

# 호스트 매핑: 127.0.0.1:17070:7070 (공인 8080/8443 CLOSE)
EXPOSE 7070

# 업스트림과 무관하게 edge 자체 /healthz 만 본다
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O - http://127.0.0.1:7070/healthz >/dev/null || exit 1
