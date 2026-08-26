# backend

HACCP API 소스 루트. 실행·빌드는 [`haccp-api/`](haccp-api/) 안에서 한다.

## 하위

| 경로 | 무엇 |
|---|---|
| [`haccp-api/`](haccp-api/) | Spring Boot 3.3.4 · Java 17 · MyBatis 3.0.3 · PostgreSQL |

모듈은 하나다. 늘릴 계획이 없다 — 이 폴더가 남아 있는 것은
프론트(`frontend/`)와 층을 나란히 보기 위해서다.

## 어디를 보나

| 하려는 일 | 볼 곳 |
|---|---|
| 기동 순서·요청이 지나는 길 | [`haccp-api/PIPELINE.md`](haccp-api/PIPELINE.md) |
| 처음 띄우기 | [`docs/1_시작하기.md`](../docs/1_시작하기.md) |
| 화면 하나 추가 | [`docs/2_화면_추가하기.md`](../docs/2_화면_추가하기.md) |
| 패키지·SP 이름 규칙 | [`docs/4_명명과_경로.md`](../docs/4_명명과_경로.md) |
| DB 정본 | [`db_sasshaccp/README.md`](../db_sasshaccp/README.md) |
| 규칙 | `.cursor/rules/08-haccp-backend.mdc` · `07-haccp-db.mdc` |

## 변경

- 2026-08-26 — 죽은 문서 링크를 새 8본으로 옮기고 PIPELINE 을 가리키게 했다
