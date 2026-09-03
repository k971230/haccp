# nginx

운영 edge 컨테이너. **TLS 를 여기서 끝내지 않는다** — 호스트 Apache(443)가 종단하고
edge 는 루프백 평문만 받는다.

```
브라우저 ──HTTPS 443──▶ 호스트 Apache ──평문 127.0.0.1:17070──▶ edge(nginx) ──▶ api:7070
                        TLS 종단·Path 분기                       라우팅          web(정적)
```

공인 8080·8443 은 닫혀 있다. edge 가 직접 인터넷에 노출되지 않는다.

---

## 파일

| 파일 | 무엇 |
|---|---|
| `Dockerfile` | edge 이미지. `nginx-unprivileged`(uid 101) 라 컨테이너 listen 이 **7070** 이다 |
| `haccp.conf.template` | 라우팅 정본. 기동 시 `envsubst` 로 `${HACCP_*}` 를 채운다 |
| `apache-haccp-gateway.conf.example` | 호스트 Apache 쪽 예시. 이 저장소가 배포하지 않는다 — 서버 관리자가 손으로 넣는다 |

---

## 치환 변수

`.env.docker` 에서 온다. 비면 기동이 안 되거나 라우팅이 어긋난다.

| 변수 | 무엇 |
|---|---|
| `HACCP_SERVER_NAME` | `server_name`. 인증서 파일명과 짝이다 |
| `HACCP_ACTUATOR_ALLOW` | `/actuator` 를 허용할 대역 하나(CIDR 또는 IP). 기본 루프백 = 사실상 외부 차단 |
| `HACCP_RESOLVER` | 도커 내장 DNS. 업스트림 IP 가 바뀌어도 요청마다 다시 푼다 |

`$host`·`$scheme` 같은 nginx 자체 변수는 `NGINX_ENVSUBST_FILTER` 로 보존한다 —
안 그러면 envsubst 가 빈 값으로 지운다.

---

## 자주 밟는 것

| 증상 | 원인 |
|---|---|
| 502 | api 컨테이너가 안 떴거나 이름이 다르다. `docker compose --env-file .env.docker -f docker-compose.prod.yml ps` |
| 화면은 뜨는데 API 만 404 | Apache 의 Path 분기(`/haccp/`)가 빠졌다 |
| CORS 오류 | `CORS_ALLOWED_ORIGINS` 가 브라우저 Origin 과 스킴·호스트까지 같아야 한다 |
| `/actuator` 가 외부에서 열린다 | `HACCP_ACTUATOR_ALLOW` 가 넓다 |
| 인증서 오류 | edge 가 아니라 **Apache** 쪽이다 (`/etc/letsencrypt/`) |
| 큰 HWP 업로드가 끊긴다 | `haccp.conf.template` 의 파일 location 정규식에 그 경로가 빠졌다. 기본 70s 로 처리된다 |

---

## 관련

- 배포 절차: [`DEPLOY.md`](../DEPLOY.md)
- 장애 대응: [`운영.md`](../운영.md)
- compose: [`docker-compose.prod.yml`](../docker-compose.prod.yml) 의 `edge` 서비스

## 파일 전송 경로

업로드·다운로드·PDF 는 타임아웃 130s 를 따로 준다. 그 목록은
**백엔드 컨트롤러의 multipart·download·pdf 매핑과 같아야 한다.**

```
/api/v1/docs/documents/{idx}/files          첨부 업로드
/api/v1/docs/documents/{idx}/export-pdf     PDF 변환
/api/v1/docs/documents/files/{idx}/download 첨부 내려받기
/api/v1/docs/templates/{tmplCd}/form        양식 파일 업로드
/api/v1/docs/audit-export/preview-pdf       감사자료 미리보기
/api/v1/sys/users/{me|userId}/sign          서명 이미지
```

여기 빠진 경로는 일반 API 로 떨어져 **기본 70s** 로 끊긴다.

## 변경

- 2026-08-26 — 파일 location 정규식이 없어진 경로(`doc/`·`bas/`·`hyg/`)를 가리키고 있어
  지금 URL 로 맞췄다. 그대로 뒀으면 운영에서 큰 HWP 업로드가 끊겼다
- 2026-08-26 — 죽은 문서 링크를 걷어내고 요청이 지나는 길·치환 변수·증상별 원인을 적었다
