# ============================================================
#  haccp-nginx (edge) 컨테이너 이미지 — TLS 종단 · /api 리버스 프록시
#
#  개발자: 박승우
#  일자: 2026-08-10
#  코멘트:
#    1) 브라우저가 만나는 유일한 출입구다 — 정적(web)·API(api)·rhwp 스튜디오를 한 출처로 합친다
#    2) 도메인·인증서 경로는 굽지 않는다 — 기동 시 envsubst 로 주입해 이미지 하나를 전 환경에서 쓴다
#    3) 최종 스테이지는 nginx-unprivileged(uid 101) 라 8080/8443 을 쓴다 (root·80/443 금지)
#
#  빌드: docker build -f nginx/Dockerfile -t haccp-nginx:local nginx
# ============================================================

FROM nginxinc/nginx-unprivileged:1.27-alpine

# templates 에 두면 기동 시 20-envsubst-on-templates.sh 가 치환해
# /etc/nginx/conf.d/default.conf 로 떨군다 (이미지 기본 conf 를 덮어쓴다)
COPY haccp.conf.template /etc/nginx/templates/default.conf.template

# 치환 기본값 — envsubst 는 ${VAR:-기본} 문법을 모르므로 기본값은 여기서만 준다.
# 배포에서는 compose 의 environment 로 덮는다
ENV HACCP_SERVER_NAME=haccp.example.com
ENV HACCP_CERT_DIR=/etc/letsencrypt/live/haccp.example.com
ENV HACCP_ACTUATOR_ALLOW=127.0.0.1
# 도커 사용자 정의 네트워크의 내장 DNS. 이미지가 제공하는 NGINX_LOCAL_RESOLVERS 대신
# 우리 변수를 쓴다 — 그쪽은 envsubst 필터에 걸리지 않아 치환되지 않는 경우가 있었다
ENV HACCP_RESOLVER=127.0.0.11

# 치환 대상을 이 접두어로 제한한다. 필터가 없으면 $host·$remote_addr 같은
# nginx 런타임 변수까지 빈 문자열로 치환돼 conf 가 통째로 망가진다
ENV NGINX_ENVSUBST_FILTER=^HACCP_

# 8080: 평문(호스트 80 매핑, HTTPS 리다이렉트·ACME 챌린지 전용) / 8443: TLS(호스트 443 매핑)
EXPOSE 8080 8443

# 업스트림이 죽어도 edge 자체는 살아 있어야 하므로 프록시 경로가 아닌 자기 응답만 확인한다.
# alpine 에서 localhost 가 ::1 로 풀리면 IPv4 만 리슨하는 nginx 에 닿지 않아 unhealthy 가 된다
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O - http://127.0.0.1:8080/healthz >/dev/null || exit 1
