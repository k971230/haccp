# ============================================================
#  haccp-api 컨테이너 이미지 — Spring Boot 3.3.4 / Java 17
#
#  개발자: 박승우
#  일자: 2026-08-19
#  코멘트:
#    1) 빌드(JDK)와 실행(JRE)을 나눠 실행 이미지에 컴파일러·소스·메이븐 캐시를 남기지 않는다
#    2) rhwp CLI 바이너리는 라이선스상 이미지에 넣지 않는다 — 실행 환경에서 볼륨으로 마운트한다
#    3) 표준·사용자 HWP 시드는 이미지 /opt/haccp/template-src 에 구워 기동 시 파일 볼륨으로 복사한다
#
#  빌드: docker build -f backend/haccp-api/Dockerfile -t haccp-api:local .
# ============================================================

# ------------------------------------------------------------
# 스테이지 A — 의존성 캐시 후 JAR 패키징
# ------------------------------------------------------------
FROM eclipse-temurin:17-jdk-jammy AS build

WORKDIR /workspace

# pom.xml 을 먼저 복사해 의존성 레이어를 캐시한다 — src 만 고쳤을 때 재다운로드하지 않기 위해서다
COPY backend/haccp-api/.mvn .mvn
COPY backend/haccp-api/mvnw backend/haccp-api/pom.xml ./

# 저장소가 Windows 체크아웃이라 mvnw 가 CRLF 줄바꿈 + 실행비트 없이 들어온다.
# 그대로 실행하면 리눅스에서 "bad interpreter: /bin/sh^M" 으로 빌드가 죽는다
RUN sed -i 's/\r$//' mvnw \
 && chmod +x mvnw \
 && ./mvnw -B -ntp dependency:go-offline

# 소스는 의존성 해석이 끝난 뒤 복사한다 — 위 레이어 캐시를 깨지 않기 위해서다
COPY backend/haccp-api/src src

# 테스트는 CI 단계에서 따로 돌린다 — 이미지 빌드는 패키징만 책임진다
RUN ./mvnw -B -ntp -DskipTests package

# ------------------------------------------------------------
# 스테이지 B — 실행 전용 JRE
# ------------------------------------------------------------
FROM eclipse-temurin:17-jre-jammy

# fonts-nanum: rhwp PDF 한글 렌더링(없으면 글자가 깨진다) / tzdata: Asia/Seoul 배치 기준
# curl: HEALTHCHECK 전용 — 이것 때문에 설치하므로 다른 용도로 늘리지 않는다
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        fonts-nanum \
        tzdata \
        ca-certificates \
        curl \
 && rm -rf /var/lib/apt/lists/*

# 컨테이너 시각 — cron(과제 생성·UV/PV 집계)과 문서 일자가 KST 기준이어야 한다
ENV TZ=Asia/Seoul

# 실행 계정 — 파일 볼륨 소유자와 uid 를 맞춰야 마운트 후 쓰기가 된다
RUN groupadd --gid 1000 haccp \
 && useradd --uid 1000 --gid 1000 --create-home --shell /usr/sbin/nologin haccp

# /var/haccp/files: 업로드 원본·PDF 볼륨 마운트 지점
# /opt/haccp/template-src: 이미지에 구운 표준·사용자 HWP 시드
RUN mkdir -p /app /var/haccp/files /var/haccp/templates /opt/haccp/template-src \
 && chown -R haccp:haccp /app /var/haccp /opt/haccp

# 산출물명은 pom 의 artifactId-version 규칙을 따른다 (haccp-api / 1.0.0)
COPY --from=build --chown=haccp:haccp /workspace/target/haccp-api-1.0.0.jar /app/app.jar

# 시스템 27건 · 사용자추가 시드 — 기동 시 TemplateImportService 가 파일 볼륨으로 복사한다
COPY --chown=haccp:haccp docs/templates/new /opt/haccp/template-src/sys
COPY --chown=haccp:haccp docs/templates/usr /opt/haccp/template-src/usr

# 업로드 볼륨 — 컨테이너를 지워도 문서가 남도록 반드시 마운트해서 쓴다
ENV APP_FILE_ROOT=/var/haccp/files
# rhwp CLI 가 PDF 를 만들 때 참조하는 폰트 경로 — fonts-nanum 설치 위치
ENV APP_RHWP_FONT_PATH=/usr/share/fonts/truetype/nanum

# 이미지 안 시드 경로 — compose 가 같은 값으로 고정한다. 빈 볼륨 /var/haccp/templates 로 덮지 않는다
ENV APP_TEMPLATE_IMPORT_ROOT=/opt/haccp/template-src
# APP_RHWP_CLI_PATH: 바이너리를 이미지에 넣지 않으므로(라이선스) 마운트 경로를 실행 시 지정한다
ENV APP_RHWP_CLI_PATH=""

# 컨테이너 내부 통일 포트 — edge upstream(api:7070). 로컬 mvnw 는 application.yml 기본 8081
ENV SERVER_PORT=7070

USER haccp

EXPOSE 7070

# start-period 를 넉넉히 둔다 — DB 커넥션 풀·MyBatis 초기화까지 기다려야 첫 판정이 의미 있다.
# DB 가 없으면 Actuator 가 DOWN(503) 을 주므로 이 헬스체크는 "앱+DB 준비"를 함께 본다
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://localhost:7070/actuator/health || exit 1

# MaxRAMPercentage: 컨테이너 메모리 제한의 75%를 힙 상한으로 — -Xmx 를 하드코딩하지 않기 위해서다
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75","-Duser.timezone=Asia/Seoul","-jar","/app/app.jar"]
